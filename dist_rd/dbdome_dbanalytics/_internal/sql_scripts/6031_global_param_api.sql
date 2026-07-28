-- ============================================================
-- Procedure behind the /global_param_set API. Used by the Webhook Alerts Config
-- dashboard to toggle the blocker global dry-run switch through the web app
-- (same pattern as set_webook_alert / server_activate).
--
-- Key is WHITELISTED so the API can only touch safe, dashboard-exposed params
-- (never credentials/paths). Idempotent.
-- ============================================================
CREATE OR REPLACE PROCEDURE config.set_global_param(p_key text, p_value text)
LANGUAGE plpgsql AS $$
BEGIN
    IF p_key NOT IN ('blocker_dry_run', 'masking_dry_run', 'encryption_dry_run') THEN
        RAISE EXCEPTION 'set_global_param: key % not allowed via API', p_key;
    END IF;
    IF EXISTS (SELECT 1 FROM config.global_params WHERE key = p_key) THEN
        UPDATE config.global_params SET value = p_value, entry_date = now() WHERE key = p_key;
    ELSE
        INSERT INTO config.global_params (key, value) VALUES (p_key, p_value);
    END IF;
END $$;
