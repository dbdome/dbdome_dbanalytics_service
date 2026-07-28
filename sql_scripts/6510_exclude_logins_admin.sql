-- =============================================================================
-- 6510_exclude_logins_admin.sql
-- Procedures behind the /exclude_login_set + /api/exclude-logins endpoints
-- (mirrors config.set_webook_alert for the webhook-config flow). The Excluded
-- Logins dashboard toggles is_active via the web app instead of writing from
-- Grafana directly; the /exclude_logins config page adds/removes rows.
-- Idempotent.
-- =============================================================================
CREATE OR REPLACE PROCEDURE metrics.set_exclude_login(p_row_id integer, p_value boolean)
LANGUAGE plpgsql AS $$
BEGIN
    IF p_row_id IS NULL THEN
        RAISE EXCEPTION 'set_exclude_login: p_row_id is required';
    END IF;
    UPDATE metrics.exclude_logins SET is_active = COALESCE(p_value, true)
    WHERE row_id = p_row_id;
END $$;

CREATE OR REPLACE PROCEDURE metrics.add_exclude_login(p_login text)
LANGUAGE plpgsql AS $$
BEGIN
    IF p_login IS NULL OR btrim(p_login) = '' THEN
        RAISE EXCEPTION 'add_exclude_login: p_login is required';
    END IF;
    -- Normalise to lowercase: the login match in analysis/self_activity_filter.py
    -- is case-insensitive, and the UNIQUE(login_name) is case-SENSITIVE, so
    -- storing mixed case would create duplicate rows for the same login. Lower
    -- here keeps one canonical row and matches the filter's comparison.
    INSERT INTO metrics.exclude_logins (login_name, is_active)
    VALUES (lower(btrim(p_login)), true)
    ON CONFLICT (login_name) DO UPDATE SET is_active = true;
END $$;

CREATE OR REPLACE PROCEDURE metrics.delete_exclude_login(p_row_id integer)
LANGUAGE plpgsql AS $$
BEGIN
    IF p_row_id IS NULL THEN
        RAISE EXCEPTION 'delete_exclude_login: p_row_id is required';
    END IF;
    DELETE FROM metrics.exclude_logins WHERE row_id = p_row_id;
END $$;
