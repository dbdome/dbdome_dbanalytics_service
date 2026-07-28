-- =============================================================================
-- 6490_fix_update_siem_config.sql
-- siem_config.update_siem_config: the UPDATE branch referenced p_api_key, but
-- the parameter is named p_siem_api_key -> every re-submit of an existing SIEM
-- vendor failed at runtime. Recreate with the correct parameter name.
-- Idempotent (CREATE OR REPLACE).
-- =============================================================================
CREATE OR REPLACE PROCEDURE siem_config.update_siem_config(
    p_siem_vendor  character varying,
    p_siem_url     character varying,
    p_siem_api_key character varying
)
LANGUAGE plpgsql
AS $proc$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM siem_config.sime_interface WHERE siem_vendor = p_siem_vendor) THEN
        INSERT INTO siem_config.sime_interface (siem_vendor, siem_url, api_key)
        SELECT p_siem_vendor, p_siem_url, p_siem_api_key;
    ELSE
        UPDATE siem_config.sime_interface
        SET siem_url = p_siem_url, api_key = p_siem_api_key
        WHERE siem_vendor = p_siem_vendor;
    END IF;
END;
$proc$;
