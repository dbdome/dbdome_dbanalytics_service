-- =====================================================================
-- 7310_encrypt_detection_logic.sql
-- ---------------------------------------------------------------------
-- Encrypt rootcause detection logic at rest, and propagate the session key
-- to role defaults so non-app sessions (Grafana datasource, report tools,
-- ad-hoc psql) can also decrypt via rootcause.dec().
--
-- Runs through processes/sql_script_runner.py, whose connection is built by
-- get_connection_string() and therefore carries the per-session key
-- (options=-c rootcause.k=<DBDOME_SECRET_KEY>). That is why enc()/ALTER ROLE
-- work here without any key literal in the file. On a fresh install the seed
-- ships PLAINTEXT product data; this script encrypts it on first service start
-- using that install's own key. Idempotent -- a no-op once data is ciphertext.
--
-- Depends on: 7300_rootcause_content_encryption.sql (enc/dec/is_encrypted, and
-- rootcause._key()). Numbered after 7300 so ordering is guaranteed.
-- =====================================================================

DO $$
DECLARE
    k text := rootcause._key();
    r text;
    n bigint;
BEGIN
    IF k IS NULL THEN
        RAISE NOTICE '7310: rootcause.k not set in this session; skipping '
                     '(app injects it via get_connection_string; nothing to do)';
        RETURN;
    END IF;

    -- 1) Encrypt any plaintext detection logic (content / expected / parameters).
    UPDATE rootcause.detection_steps
       SET content    = rootcause.enc(content),
           expected   = rootcause.enc(expected),
           parameters = rootcause.enc(parameters)
     WHERE NOT rootcause.is_encrypted(content)
        OR (expected   IS NOT NULL AND NOT rootcause.is_encrypted(expected))
        OR (parameters IS NOT NULL AND NOT rootcause.is_encrypted(parameters));
    GET DIAGNOSTICS n = ROW_COUNT;
    RAISE NOTICE '7310: encrypted % detection_steps row(s)', n;

    -- 2) Give the app / reporting roles the key as a role default, so sessions
    --    that bypass the app connection factory still decrypt. NOT applied to
    --    *_grafana_ro (kept unable to decrypt). Wrapped so lack of ALTER ROLE
    --    privilege (e.g. the post-6690 non-superuser engine role) is non-fatal.
    BEGIN
        FOREACH r IN ARRAY ARRAY['dbdome_mon_usr','dbdome_adm','postgres',
                                 'dbexpert_mon_usr','dbexpert_adm','dbdome_engine'] LOOP
            IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
                EXECUTE format('ALTER ROLE %I SET rootcause.k = %L', r, k);
            END IF;
        END LOOP;
        RAISE NOTICE '7310: rootcause.k set as role default on app/report roles';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '7310: no privilege to set role defaults (ok if already set)';
    END;
END $$;
