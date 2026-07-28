-- 5960: audit every change to metrics.servers into metrics.server_log.
-- AFTER INSERT/UPDATE/DELETE trigger captures who/when/what (old + new row as
-- jsonb, with the password masked). No-op UPDATEs are skipped. Idempotent.

CREATE TABLE IF NOT EXISTS metrics.server_log (
    log_id      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    operation   text        NOT NULL,             -- INSERT | UPDATE | DELETE
    changed_at  timestamptz NOT NULL DEFAULT now(),
    changed_by  text        NOT NULL DEFAULT current_user,
    server_id   uuid,
    servername  text,
    old_data    jsonb,                            -- row before (UPDATE/DELETE), password removed
    new_data    jsonb                             -- row after  (INSERT/UPDATE), password removed
);
CREATE INDEX IF NOT EXISTS ix_server_log_changed_at ON metrics.server_log (changed_at DESC);
CREATE INDEX IF NOT EXISTS ix_server_log_server     ON metrics.server_log (servername, changed_at DESC);

CREATE OR REPLACE FUNCTION metrics.log_server_change()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    v_server_id  uuid;
    v_servername text;
    v_old        jsonb;
    v_new        jsonb;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_server_id  := OLD.server_id;
        v_servername := OLD.servername;
        v_old        := to_jsonb(OLD) - 'password';
    ELSIF TG_OP = 'INSERT' THEN
        v_server_id  := NEW.server_id;
        v_servername := NEW.servername;
        v_new        := to_jsonb(NEW) - 'password';
    ELSE  -- UPDATE
        IF to_jsonb(OLD) IS NOT DISTINCT FROM to_jsonb(NEW) THEN
            RETURN NULL;                          -- nothing actually changed
        END IF;
        v_server_id  := NEW.server_id;
        v_servername := NEW.servername;
        v_old        := to_jsonb(OLD) - 'password';
        v_new        := to_jsonb(NEW) - 'password';
    END IF;

    INSERT INTO metrics.server_log (operation, changed_by, server_id, servername, old_data, new_data)
    VALUES (TG_OP, current_user, v_server_id, v_servername, v_old, v_new);

    RETURN NULL;  -- AFTER trigger: return value ignored
END;
$$;

DROP TRIGGER IF EXISTS trg_servers_audit ON metrics.servers;
CREATE TRIGGER trg_servers_audit
    AFTER INSERT OR UPDATE OR DELETE ON metrics.servers
    FOR EACH ROW EXECUTE FUNCTION metrics.log_server_change();
