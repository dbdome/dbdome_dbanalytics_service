-- =============================================================================
-- 7410_save_mail_group_upsert.sql
-- Make config.save_mail_group UPSERT by group_name when no row_id is supplied.
--
-- The /submit-mailconfiguration form posts no group_id, so the procedure always
-- took the INSERT branch — and config.mail_groups.group_name is UNIQUE
-- (mail_groups_group_name_key). Net effect: the FIRST save of a group name
-- (e.g. the default group) worked, and EVERY later save raised UniqueViolation.
-- With the pre-7410 handler (single transaction + swallowed exception) that
-- also rolled back the config.save_mail_config insert and still logged
-- "mail_config succeeded" — the empty-mail_config-with-advanced-sequence
-- signature diagnosed live on 181.214.214.9 on 2026-08-04.
--
-- Fix: when p_row_id IS NULL, INSERT ... ON CONFLICT (group_name) DO UPDATE —
-- re-saving a group refreshes its recipients/config link/active flag instead
-- of erroring. Explicit-row_id updates keep their existing semantics.
-- Idempotent (CREATE OR REPLACE); guarded owner re-assert.
-- =============================================================================

CREATE OR REPLACE PROCEDURE config.save_mail_group(
    INOUT p_row_id        integer,
    IN    p_mail_config_id integer,
    IN    p_group_name    text,
    IN    p_recipients    text,
    IN    p_is_active     boolean)
LANGUAGE plpgsql
AS $procedure$
BEGIN
    IF p_mail_config_id IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM config.mail_config WHERE row_id = p_mail_config_id)
    THEN
        RAISE EXCEPTION 'mail_config_id % does not exist', p_mail_config_id;
    END IF;

    IF p_row_id IS NULL THEN
        -- Upsert by the natural key: the form has no group id, so a re-save of
        -- an existing group name must update it, not raise UniqueViolation.
        INSERT INTO config.mail_groups
            (mail_config_id, group_name, recipients, is_active)
        VALUES
            (p_mail_config_id, p_group_name, p_recipients, COALESCE(p_is_active, true))
        ON CONFLICT (group_name) DO UPDATE
           SET mail_config_id = EXCLUDED.mail_config_id,
               recipients     = EXCLUDED.recipients,
               is_active      = EXCLUDED.is_active
        RETURNING row_id INTO p_row_id;
    ELSE
        UPDATE config.mail_groups
           SET mail_config_id = p_mail_config_id,
               group_name     = p_group_name,
               recipients     = p_recipients,
               is_active      = COALESCE(p_is_active, is_active)
         WHERE row_id = p_row_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'mail_groups row_id % not found', p_row_id;
        END IF;
    END IF;
END;
$procedure$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_adm') THEN
        EXECUTE 'ALTER PROCEDURE config.save_mail_group(integer, integer, text, text, boolean) OWNER TO dbdome_adm';
    END IF;
END $$;
