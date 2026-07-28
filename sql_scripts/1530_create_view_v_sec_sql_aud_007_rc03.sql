DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_007_rc03;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_007_rc03
-- Root cause: SEC-SQL-AUD-007-RC03
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_007_rc03 AS
SELECT
    r.server,
    j.value ->> 'client_net_address' AS client_net_address,
    COALESCE(
        j.value ->> 'usename',
        j.value ->> 'login_name',
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    COALESCE(
        j.value ->> 'application_name',
        j.value ->> 'program_name',
        j.value ->> 'program'
    ) AS application_name,
    COALESCE(
        j.value ->> 'client_addr',
        j.value ->> 'host_name',
        j.value ->> 'machine',
        j.value ->> 'host',
        j.value ->> 'client_hostname'
    ) AS host,
    to_timestamp((j.value ->> 'connect_time')::bigint / 3.0) AS connect_time,
    j.value ->> 'value' AS value,
    j.value ->> 'account_locked' AS account_locked,
    j.value ->> 'password_expired' AS password_expired,
    COALESCE(
        j.value ->> 'pid',
        j.value ->> 'id'
    ) AS session_id,
    j.value ->> 'db' AS db,
    COALESCE(
        j.value ->> 'state',
        j.value ->> 'status',
        j.value ->> 'command',
        j.value ->> 'type'
    ) AS state,
    to_timestamp((j.value ->> 'time')::bigint / 3.0) AS time,
    j.value ->> 'database' AS database,
    j.value ->> 'user_name' AS user_name,
    j.value ->> 'address' AS address,
    j.value ->> 'auth_method' AS auth_method,
    to_timestamp((j.value ->> 'login_time')::bigint / 3.0) AS login_time,
    j.value ->> 'terminal' AS terminal,
    to_timestamp((j.value ->> 'logon_time')::bigint / 3.0) AS logon_time,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-007-RC03'
