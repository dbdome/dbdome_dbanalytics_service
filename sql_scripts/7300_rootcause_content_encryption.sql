-- =====================================================================
-- 7300_rootcause_content_encryption.sql
-- ---------------------------------------------------------------------
-- Phase 1 of securing the rootcause schema: encrypt the detection LOGIC
-- (detection_steps.content / .expected / .parameters, all jsonb) at rest
-- with pgcrypto, so a pg_dump / stolen datafile yields ciphertext only.
--
-- KEY MANAGEMENT
--   The symmetric passphrase is the host-side DBDOME_SECRET_KEY (the same
--   key used by utils/secrets_crypto.py). It is injected PER SESSION by the
--   application as a libpq startup option:
--        options=-c rootcause.k=<DBDOME_SECRET_KEY>
--   so the key is NEVER stored in the catalog, a role setting, or any dump.
--   A session without rootcause.k set cannot decrypt (dec() returns NULL).
--
--   Threat coverage: defeats logical dumps, stolen datafiles/backups, and the
--   read-only monitoring / Grafana roles. It does NOT defeat a local admin who
--   can read .env and set the key themselves -- that is the inherent limit of
--   any on-box decryption (see the Phase 4 roadmap item, SaaS-fetched logic).
--
-- STORAGE SHAPE
--   A plaintext value (jsonb object, e.g. {"sql": "..."}) is encrypted to a
--   jsonb STRING SCALAR holding the ASCII-armored PGP message:
--        {"sql": "..."}   ->   "-----BEGIN PGP MESSAGE----- ... "
--   dec() reverses it back to the original jsonb. Both functions are idempotent
--   and pass plaintext through unchanged, so partial/mixed states are safe.
--
-- Idempotent: safe to re-run. Depends on: rootcause schema, pgcrypto.
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------------------------------------------------------------------
-- is_encrypted(): true iff val is a jsonb string scalar carrying a PGP blob.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION rootcause.is_encrypted(val jsonb)
RETURNS boolean
LANGUAGE sql IMMUTABLE
AS $$
    SELECT val IS NOT NULL
       AND jsonb_typeof(val) = 'string'
       AND left(val #>> '{}', 27) = '-----BEGIN PGP MESSAGE-----';
$$;

-- ---------------------------------------------------------------------
-- _key(): the per-session passphrase injected by the app via
--   options=-c rootcause.k=<key>. NULL when unset (no decryption possible).
-- The second arg 'true' to current_setting means "return NULL, don't error,
-- if the GUC was never set in this session".
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION rootcause._key()
RETURNS text
LANGUAGE sql STABLE
AS $$ SELECT nullif(current_setting('rootcause.k', true), '') $$;

-- ---------------------------------------------------------------------
-- enc(): plaintext jsonb -> armored jsonb string scalar. Idempotent.
-- VOLATILE because pgp_sym_encrypt uses a random session key / IV.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION rootcause.enc(val jsonb)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE
AS $$
DECLARE k text := rootcause._key();
BEGIN
    IF val IS NULL THEN RETURN NULL; END IF;
    IF rootcause.is_encrypted(val) THEN RETURN val; END IF;   -- already ciphertext
    IF k IS NULL THEN
        RAISE EXCEPTION 'rootcause.enc: session key rootcause.k is not set '
                        '(app must connect with options=-c rootcause.k=<DBDOME_SECRET_KEY>)';
    END IF;
    RETURN to_jsonb(armor(pgp_sym_encrypt(val::text, k, 'cipher-algo=aes256')));
END $$;

-- ---------------------------------------------------------------------
-- dec(): armored jsonb string scalar -> original jsonb. Plaintext passes
-- through unchanged. Withholds (NULL) when the key is absent or wrong, so a
-- keyless session (dump, wrong install, monitoring role) never sees plaintext.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION rootcause.dec(val jsonb)
RETURNS jsonb
LANGUAGE plpgsql STABLE
AS $$
DECLARE k text := rootcause._key();
BEGIN
    IF val IS NULL THEN RETURN NULL; END IF;
    IF NOT rootcause.is_encrypted(val) THEN RETURN val; END IF; -- plaintext passthrough
    IF k IS NULL THEN RETURN NULL; END IF;                      -- no key -> withhold
    RETURN pgp_sym_decrypt(dearmor(val #>> '{}'), k)::jsonb;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;                                                -- wrong key / corrupt -> withhold
END $$;

-- ---------------------------------------------------------------------
-- Grants. The detection engine (dbdome_engine, post-6690 cutover) is the
-- intended principal. dbdome_mon_usr is granted transitionally so live reads
-- through the rewritten views keep working until the Phase 0 cutover moves the
-- app onto dbdome_engine (after which 6690 revokes mon_usr's rootcause USAGE).
-- ---------------------------------------------------------------------
DO $$
DECLARE r text;
BEGIN
    FOREACH r IN ARRAY ARRAY['dbdome_engine','dbdome_mon_usr','dbexpert_mon_usr'] LOOP
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
            EXECUTE format('GRANT EXECUTE ON FUNCTION rootcause.is_encrypted(jsonb) TO %I', r);
            EXECUTE format('GRANT EXECUTE ON FUNCTION rootcause._key()             TO %I', r);
            EXECUTE format('GRANT EXECUTE ON FUNCTION rootcause.dec(jsonb)         TO %I', r);
        END IF;
    END LOOP;
    -- enc() is a write-path helper: engine / migration only.
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        EXECUTE 'GRANT EXECUTE ON FUNCTION rootcause.enc(jsonb) TO dbdome_engine';
    END IF;
END $$;

COMMENT ON FUNCTION rootcause.dec(jsonb) IS
  'Decrypt a detection_steps logic column using the per-session key rootcause.k; plaintext passes through, keyless sessions get NULL.';
COMMENT ON FUNCTION rootcause.enc(jsonb) IS
  'Encrypt a detection_steps logic column (pgcrypto/AES-256, armored) using the per-session key rootcause.k; idempotent.';

-- ---------------------------------------------------------------------
-- Auto-encrypt on write. This is what keeps NEW content encrypted: any INSERT
-- or UPDATE of content/expected/parameters -- from a numbered detection script,
-- the rootcause admin API, or manual SQL -- is stored ciphertext without the
-- writer calling enc() itself. enc() is idempotent (already-armored values pass
-- through), so re-inserts and no-op updates are safe. If the writing session has
-- no key, the row is left as-is (7310 / next maintenance encrypts it) so a write
-- is NEVER blocked. Every app/runner connection injects the key, so in practice
-- writes are always encrypted immediately.
--
-- NOTE: a writer that MUTATES existing content (e.g. jsonb_set(content,...)) must
-- run while content is still plaintext -- jsonb operators fail on the encrypted
-- string scalar. Numbered scripts satisfy this because inserts/fixes are ordered
-- BEFORE 7300/7310; new fix scripts on an already-encrypted DB must decrypt first
-- (rootcause.enc(jsonb_set(rootcause.dec(content), ...))).
CREATE OR REPLACE FUNCTION rootcause.trg_encrypt_detection() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF rootcause._key() IS NULL THEN
        RETURN NEW;                       -- no key in session: leave as-is
    END IF;
    NEW.content    := rootcause.enc(NEW.content);
    NEW.expected   := rootcause.enc(NEW.expected);
    NEW.parameters := rootcause.enc(NEW.parameters);
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_00_encrypt_detection ON rootcause.detection_steps;
CREATE TRIGGER trg_00_encrypt_detection
    BEFORE INSERT OR UPDATE OF content, expected, parameters
    ON rootcause.detection_steps
    FOR EACH ROW EXECUTE FUNCTION rootcause.trg_encrypt_detection();

-- ---------------------------------------------------------------------
-- Rewrite rootcause.v_rootcauses so SQL consumers (reports, admin UI) see
-- DECRYPTED content/expected/parameters, provided their session carries the
-- key. Column names/types/order are unchanged, so CREATE OR REPLACE succeeds
-- and downstream consumers are unaffected.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW rootcause.v_rootcauses AS
 SELECT DISTINCT d.code AS domain_code,
    d.name AS domain_name,
    a.code AS area_code,
    a.name AS area_name,
    i.name AS issue_name,
    rootcause.dec(stps.parameters) AS parameters,
    i.issue_id,
    rc.root_cause_id,
    rc.name AS root_cause_name,
    rc.description AS root_cause_desc,
    dp.name AS detection_name,
    dp.description AS detection_desc,
    stps.name AS step_name,
    stps.name,
    rootcause.dec(stps.content) AS content,
    rootcause.dec(stps.expected) AS expected,
    dp.is_active,
    v.slug AS vendor_name,
    rpst.risk_level
   FROM rootcause.issues i
     JOIN rootcause.domains d ON d.code::text = i.domain_code::text
     JOIN rootcause.areas a ON a.code::text = i.area_code::text
     JOIN rootcause.root_causes rc ON rc.issue_id::text = i.issue_id::text
     JOIN rootcause.detection_paths dp ON dp.root_cause_id::text = rc.root_cause_id::text
     JOIN rootcause.detection_path_steps stpstp ON stpstp.detection_path_id = dp.id
     JOIN rootcause.detection_steps stps ON stps.id = stpstp.detection_step_id
     JOIN rootcause.vendors v ON v.slug::text = stps.vendor_slug::text
     JOIN rootcause.resolution_paths rp ON rp.root_cause_id::text = rc.root_cause_id::text
     JOIN rootcause.resolution_path_steps rpstp ON rpstp.resolution_path_id = rp.id
     JOIN rootcause.resolution_steps rpst ON rpst.id = rpstp.resolution_step_id
     JOIN rootcause.risk_level rl ON rl.risk_level = rp.risk_level::bpchar
  WHERE d.is_enabled IS TRUE AND a.is_enabled IS TRUE;

-- ---------------------------------------------------------------------
-- v_issue_decision_tree reads the gate condition out of detection_steps.expected
-- (ds.expected ->> 'condition'). Once expected is encrypted that -> yields NULL,
-- so the gate must decrypt first. Same column set/order -> CREATE OR REPLACE ok.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW rootcause.v_issue_decision_tree AS
 SELECT t.issue_id,
    t.vendor_slug,
    t.name AS tree_name,
    n.id AS node_id,
    n.parent_node_id,
    n.tier,
    n.sequence,
    n.gate_label,
    n.gate_question,
    n.gate_detection_step_id,
    ds.name AS detection_step_name,
    rootcause.dec(ds.expected) ->> 'condition'::text AS gate_condition,
    n.on_match_rc_id,
    rc.name AS on_match_rc_name,
    n.on_match_terminate,
    n.on_match_drill_rc_ids,
    n.notes,
    n.is_active,
    n.on_no_match_terminate
   FROM rootcause.issue_decision_trees t
     JOIN rootcause.issue_decision_tree_nodes n ON n.tree_id = t.id
     LEFT JOIN rootcause.detection_steps ds ON ds.id = n.gate_detection_step_id
     LEFT JOIN rootcause.root_causes rc ON rc.root_cause_id::text = n.on_match_rc_id::text
  WHERE t.is_active AND n.is_active
  ORDER BY t.issue_id, t.vendor_slug, n.tier, n.sequence;
