-- ============================================================
-- Procedures for managing config.mail_config and config.mail_groups
-- ============================================================

-- ------------------------------------------------------------
-- MAIL_CONFIG: insert or update (upsert by row_id)
-- p_row_id NULL  -> insert new, returns new id in p_row_id
-- p_row_id given -> update existing
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE config.save_mail_config(
    INOUT p_row_id        integer,
    IN    p_smtp_server   varchar,
    IN    p_smtp_port     integer,
    IN    p_smtp_user     varchar,
    IN    p_smtp_password varchar,
    IN    p_tls           boolean,
    IN    p_mail_sender   text
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_row_id IS NULL THEN
        INSERT INTO config.mail_config
            (smtp_server, smtp_port, smtp_user, smtp_password, tls, mail_sender)
        VALUES
            (p_smtp_server, p_smtp_port, p_smtp_user, p_smtp_password,
             COALESCE(p_tls, true), p_mail_sender)
        RETURNING row_id INTO p_row_id;
    ELSE
        UPDATE config.mail_config
           SET smtp_server   = p_smtp_server,
               smtp_port     = p_smtp_port,
               smtp_user     = p_smtp_user,
               smtp_password = p_smtp_password,
               tls           = COALESCE(p_tls, tls),
               mail_sender   = p_mail_sender
         WHERE row_id = p_row_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'mail_config row_id % not found', p_row_id;
        END IF;
    END IF;
END;
$$;

-- ------------------------------------------------------------
-- MAIL_CONFIG: delete (blocks if any group still references it)
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE config.delete_mail_config(
    IN p_row_id integer,
    IN p_force  boolean DEFAULT false
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_group_count integer;
BEGIN
    SELECT COUNT(*) INTO v_group_count
      FROM config.mail_groups
     WHERE mail_config_id = p_row_id;

    IF v_group_count > 0 THEN
        IF p_force THEN
            DELETE FROM config.mail_groups WHERE mail_config_id = p_row_id;
        ELSE
            RAISE EXCEPTION
                'mail_config % is referenced by % mail_groups; pass p_force=>true to cascade',
                p_row_id, v_group_count;
        END IF;
    END IF;

    DELETE FROM config.mail_config WHERE row_id = p_row_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'mail_config row_id % not found', p_row_id;
    END IF;
END;
$$;

-- ------------------------------------------------------------
-- MAIL_GROUPS: insert or update
-- p_row_id NULL  -> insert
-- p_row_id given -> update
-- Validates that mail_config_id exists.
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE config.save_mail_group(
    INOUT p_row_id         integer,
    IN    p_mail_config_id integer,
    IN    p_group_name     text,
    IN    p_recipients     text,
    IN    p_is_active      boolean
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_mail_config_id IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM config.mail_config WHERE row_id = p_mail_config_id)
    THEN
        RAISE EXCEPTION 'mail_config_id % does not exist', p_mail_config_id;
    END IF;

    IF p_row_id IS NULL THEN
        INSERT INTO config.mail_groups
            (mail_config_id, group_name, recipients, is_active)
        VALUES
            (p_mail_config_id, p_group_name, p_recipients, COALESCE(p_is_active, true))
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
$$;

-- ------------------------------------------------------------
-- MAIL_GROUPS: delete
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE config.delete_mail_group(
    IN p_row_id integer
)
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM config.mail_groups WHERE row_id = p_row_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'mail_groups row_id % not found', p_row_id;
    END IF;
END;
$$;

-- ------------------------------------------------------------
-- Combined: save SMTP config + group in one call
-- Creates/updates the SMTP config, then creates/updates a group
-- linked to it. Both ids are INOUT.
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE config.save_mail_details(
    INOUT p_config_id     integer,
    INOUT p_group_id      integer,
    IN    p_smtp_server   varchar,
    IN    p_smtp_port     integer,
    IN    p_smtp_user     varchar,
    IN    p_smtp_password varchar,
    IN    p_tls           boolean,
    IN    p_mail_sender   text,
    IN    p_group_name    text,
    IN    p_recipients    text,
    IN    p_is_active     boolean
)
LANGUAGE plpgsql
AS $$
BEGIN
    CALL config.save_mail_config(
        p_config_id, p_smtp_server, p_smtp_port,
        p_smtp_user, p_smtp_password, p_tls, p_mail_sender
    );

    CALL config.save_mail_group(
        p_group_id, p_config_id, p_group_name, p_recipients, p_is_active
    );
END;
$$;
