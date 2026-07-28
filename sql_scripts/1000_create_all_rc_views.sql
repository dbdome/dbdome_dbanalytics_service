DROP VIEW IF EXISTS monitoring.v_sec_sql_acc_010_rc12;

-- ============================================================
-- View: monitoring.v_sec_sql_acc_010_rc12
-- Root cause: SEC-SQL-ACC-010-RC12
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_acc_010_rc12 AS
SELECT
    r.server,
    j.value ->> 'login_name' AS username,
    j.value ->> 'host_name' AS host,
    j.value ->> 'program_name' AS application_name,
    to_timestamp((j.value ->> 'login_time')::bigint / 3.0) AS login_time,
    to_timestamp((j.value ->> 'last_request_start_time')::bigint / 3.0) AS last_request_start_time,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    to_timestamp((j.value ->> 'days_since_modified')::bigint / 3.0) AS days_since_modified,
    COALESCE(
        j.value ->> 'sid',
        j.value ->> 'trx_id',
        j.value ->> 'trx_mysql_thread_id'
    ) AS session_id,
    COALESCE(
        j.value ->> 'status',
        j.value ->> 'trx_state'
    ) AS state,
    to_timestamp((j.value ->> 'logon_time')::bigint / 3.0) AS logon_time,
    j.value ->> 'seconds_in_wait' AS seconds_in_wait,
    j.value ->> 'sql_text' AS query_text,
    j.value ->> 'table_schema' AS table_schema,
    j.value ->> 'total_size_bytes' AS total_size_bytes,
    j.value ->> 'free_space_bytes' AS free_space_bytes,
    j.value ->> 'open_seconds' AS open_seconds,
    j.value ->> 'trx_query' AS trx_query,
    j.value ->> 'trx_rows_locked' AS trx_rows_locked,
    to_timestamp((j.value ->> 'trx_rows_modified')::bigint / 3.0) AS trx_rows_modified,
    j.value ->> 'trx_isolation_level' AS trx_isolation_level,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ACC-010-RC12'
  AND j.value ->> 'host_name' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_acc_010_rc13;

-- ============================================================
-- View: monitoring.v_sec_sql_acc_010_rc13
-- Root cause: SEC-SQL-ACC-010-RC13
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_acc_010_rc13 AS
SELECT
    r.server,
    j.value ->> 'object_name' AS object_name,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'constraint_name' AS constraint_name,
    j.value ->> 'variable_value' AS variable_value,
    j.value ->> 'variable_name' AS variable_name,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'login_name' AS username,
    j.value ->> 'host_name' AS host,
    j.value ->> 'program_name' AS application_name,
    j.value ->> 'transaction_id' AS transaction_id,
    to_timestamp((j.value ->> 'transaction_begin_time')::bigint / 3.0) AS transaction_begin_time,
    j.value ->> 'duration_seconds' AS duration_seconds,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ACC-010-RC13'
  AND j.value ->> 'host_name' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_au_001_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_au_001_rc01
-- Root cause: SEC-SQL-AU-001-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc01 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'host' AS host,
    j.value ->> 'account_locked' AS account_locked,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolsuper' AS rolsuper,
    j.value ->> 'rolcreaterole' AS rolcreaterole,
    j.value ->> 'rolcreatedb' AS rolcreatedb,
    j.value ->> 'rolcanlogin' AS rolcanlogin,
    j.value ->> 'rolvaliduntil' AS rolvaliduntil,
    j.value ->> 'usertype' AS usertype,
    j.value ->> 'password_expired' AS password_expired,
    to_timestamp((j.value ->> 'password_last_changed')::bigint / 3.0) AS password_last_changed,
    j.value ->> 'account_status' AS account_status,
    j.value ->> 'profile' AS profile,
    j.value ->> 'resource_name' AS resource_name,
    j.value ->> 'limit' AS limit,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'days_until_expiration' AS days_until_expiration,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-001-RC01'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_au_001_rc02;

-- ============================================================
-- View: monitoring.v_sec_sql_au_001_rc02
-- Root cause: SEC-SQL-AU-001-RC02
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc02 AS
SELECT
    r.server,
    j.value ->> 'banner' AS banner,
    COALESCE(
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'host' AS host,
    j.value ->> 'plugin' AS plugin,
    j.value ->> 'authentication_string' AS authentication_string,
    j.value ->> 'parameter' AS parameter,
    j.value ->> 'value' AS value_val,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolsuper' AS rolsuper,
    j.value ->> 'rolcanlogin' AS rolcanlogin,
    j.value ->> 'rolpassword_is_not_null' AS rolpassword_is_not_null,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'is_disabled' AS is_disabled,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'bad_password_count' AS bad_password_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-001-RC02'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_au_001_rc03;

-- ============================================================
-- View: monitoring.v_sec_sql_au_001_rc03
-- Root cause: SEC-SQL-AU-001-RC03
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc03 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'login_name',
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    COALESCE(
        j.value ->> 'host_name',
        j.value ->> 'host'
    ) AS host,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolsuper' AS rolsuper,
    j.value ->> 'rolcanlogin' AS rolcanlogin,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'client_net_address' AS client_net_address,
    COALESCE(
        j.value ->> 'program_name',
        j.value ->> 'program'
    ) AS application_name,
    to_timestamp((j.value ->> 'login_time')::bigint / 3.0) AS login_time,
    j.value ->> 'machine' AS machine,
    j.value ->> 'connection_count' AS connection_count,
    j.value ->> 'value' AS value_val,
    j.value ->> 'protocol_desc' AS protocol_desc,
    j.value ->> 'state_desc' AS state_desc,
    j.value ->> 'port' AS port,
    j.value ->> 'is_dynamic_port' AS is_dynamic_port,
    j.value ->> 'is_admin_endpoint' AS is_admin_endpoint,
    j.value ->> 'setting' AS setting,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-001-RC03';

DROP VIEW IF EXISTS monitoring.v_sec_sql_au_001_rc04;

-- ============================================================
-- View: monitoring.v_sec_sql_au_001_rc04
-- Root cause: SEC-SQL-AU-001-RC04
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc04 AS
SELECT
    r.server,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolsuper' AS rolsuper,
    j.value ->> 'rolcreaterole' AS rolcreaterole,
    j.value ->> 'rolcreatedb' AS rolcreatedb,
    j.value ->> 'rolcanlogin' AS rolcanlogin,
    j.value ->> 'default_passwords' AS default_passwords,
    j.value ->> 'issue_count' AS issue_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-001-RC04';

DROP VIEW IF EXISTS monitoring.v_sec_sql_au_001_rc05;

-- ============================================================
-- View: monitoring.v_sec_sql_au_001_rc05
-- Root cause: SEC-SQL-AU-001-RC05
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc05 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'host' AS host,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolsuper' AS rolsuper,
    j.value ->> 'rolcreaterole' AS rolcreaterole,
    j.value ->> 'rolcreatedb' AS rolcreatedb,
    j.value ->> 'rolreplication' AS rolreplication,
    j.value ->> 'rolcanlogin' AS rolcanlogin,
    j.value ->> 'rolconnlimit' AS rolconnlimit,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'is_disabled' AS is_disabled,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    j.value ->> 'account_purpose' AS account_purpose,
    j.value ->> 'plugin' AS plugin,
    j.value ->> 'account_locked' AS account_locked,
    j.value ->> 'password_expired' AS password_expired,
    j.value ->> 'password_lifetime' AS password_lifetime,
    j.value ->> 'account_type' AS account_type,
    j.value ->> 'account_status' AS account_status,
    j.value ->> 'profile' AS profile,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    j.value ->> 'default_tablespace' AS default_tablespace,
    j.value ->> 'oracle_maintained' AS oracle_maintained,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-001-RC05'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_au_001_rc06;

-- ============================================================
-- View: monitoring.v_sec_sql_au_001_rc06
-- Root cause: SEC-SQL-AU-001-RC06
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc06 AS
SELECT
    r.server,
    j.value ->> 'name' AS username,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    j.value ->> 'is_disabled' AS is_disabled,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolsuper' AS rolsuper,
    j.value ->> 'rolcanlogin' AS rolcanlogin,
    j.value ->> 'rolcreatedb' AS rolcreatedb,
    j.value ->> 'mixed_audit_modes' AS mixed_audit_modes,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-001-RC06';

DROP VIEW IF EXISTS monitoring.v_sec_sql_au_001_rc07;

-- ============================================================
-- View: monitoring.v_sec_sql_au_001_rc07
-- Root cause: SEC-SQL-AU-001-RC07
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc07 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'user',
        j.value ->> 'grantee',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'host' AS host,
    j.value ->> 'account_locked' AS account_locked,
    j.value ->> 'password_expired' AS password_expired,
    j.value ->> 'plugin' AS plugin,
    j.value ->> 'active_sa_sessions' AS active_sa_sessions,
    j.value ->> 'most_recent_sa_login' AS most_recent_sa_login,
    j.value ->> 'guarantee_flashback_database' AS guarantee_flashback_database,
    j.value ->> 'storage_size' AS storage_size,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'bad_password_count' AS bad_password_count,
    to_timestamp((j.value ->> 'lockout_time')::bigint / 3.0) AS lockout_time,
    j.value ->> 'privilege_type' AS privilege_type,
    j.value ->> 'privilege' AS privilege,
    j.value ->> 'line_number' AS line_number,
    j.value ->> 'type' AS state,
    j.value ->> 'database' AS database,
    j.value ->> 'user_name' AS user_name,
    j.value ->> 'address' AS address,
    j.value ->> 'auth_method' AS auth_method,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-001-RC07'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_au_001_rc08;

-- ============================================================
-- View: monitoring.v_sec_sql_au_001_rc08
-- Root cause: SEC-SQL-AU-001-RC08
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc08 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'owner',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'account_status' AS account_status,
    j.value ->> 'authentication_type' AS authentication_type,
    to_timestamp((j.value ->> 'last_login')::bigint / 3.0) AS last_login,
    j.value ->> 'days_inactive' AS days_inactive,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolsuper' AS rolsuper,
    j.value ->> 'rolcanlogin' AS rolcanlogin,
    j.value ->> 'auth_method' AS auth_method,
    j.value ->> 'address' AS address,
    j.value ->> 'db_link' AS db_link,
    j.value ->> 'host' AS host,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'password_age_days' AS password_age_days,
    j.value ->> 'enabled_sql_logins' AS enabled_sql_logins,
    j.value ->> 'enabled_windows_logins' AS enabled_windows_logins,
    j.value ->> 'enabled_windows_groups' AS enabled_windows_groups,
    j.value ->> 'enabled_external_logins' AS enabled_external_logins,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-001-RC08'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_au_001_rc09;

-- ============================================================
-- View: monitoring.v_sec_sql_au_001_rc09
-- Root cause: SEC-SQL-AU-001-RC09
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc09 AS
SELECT
    r.server,
    j.value ->> 'authentication_type' AS authentication_type,
    j.value ->> 'account_count' AS account_count,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolsuper' AS rolsuper,
    j.value ->> 'rolcanlogin' AS rolcanlogin,
    j.value ->> 'login_audit_specs' AS login_audit_specs,
    j.value ->> 'name' AS username,
    j.value ->> 'value' AS value,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'password_age_days' AS password_age_days,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-001-RC09';

DROP VIEW IF EXISTS monitoring.v_sec_sql_au_001_rc10;

-- ============================================================
-- View: monitoring.v_sec_sql_au_001_rc10
-- Root cause: SEC-SQL-AU-001-RC10
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc10 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    to_timestamp((j.value ->> 'last_login')::bigint / 3.0) AS last_login,
    j.value ->> 'host' AS host,
    j.value ->> 'select_priv' AS select_priv,
    j.value ->> 'insert_priv' AS insert_priv,
    j.value ->> 'update_priv' AS update_priv,
    j.value ->> 'delete_priv' AS delete_priv,
    j.value ->> 'create_priv' AS create_priv,
    j.value ->> 'drop_priv' AS drop_priv,
    j.value ->> 'grant_priv' AS grant_priv,
    j.value ->> 'super_priv' AS super_priv,
    j.value ->> 'create_user_priv' AS create_user_priv,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'server_roles' AS server_roles,
    j.value ->> 'nspname' AS nspname,
    j.value ->> 'object_count' AS object_count,
    j.value ->> 'db' AS db,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-001-RC10'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_au_001_rc11;

-- ============================================================
-- View: monitoring.v_sec_sql_au_001_rc11
-- Root cause: SEC-SQL-AU-001-RC11
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc11 AS
SELECT
    r.server,
    j.value ->> 'change_audit_specs' AS change_audit_specs,
    j.value ->> 'policy_name' AS policy_name,
    j.value ->> 'audit_option' AS audit_option,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolsuper' AS rolsuper,
    j.value ->> 'rolcanlogin' AS rolcanlogin,
    j.value ->> 'rolvaliduntil' AS rolvaliduntil,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'name'
    ) AS username,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    to_timestamp((j.value ->> 'last_login')::bigint / 3.0) AS last_login,
    j.value ->> 'account_status' AS account_status,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    to_timestamp((j.value ->> 'days_since_modified')::bigint / 3.0) AS days_since_modified,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-001-RC11';

DROP VIEW IF EXISTS monitoring.v_sec_sql_au_002_rc02;

-- ============================================================
-- View: monitoring.v_sec_sql_au_002_rc02
-- Root cause: SEC-SQL-AU-002-RC02
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_002_rc02 AS
SELECT
    r.server,
    j.value ->> 'windows_auth_only' AS windows_auth_only,
    j.value ->> 'name' AS username,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-002-RC02';

DROP VIEW IF EXISTS monitoring.v_sec_sql_au_003_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_au_003_rc01
-- Root cause: SEC-SQL-AU-003-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc01 AS
SELECT
    r.server,
    j.value ->> 'name' AS username,
    j.value ->> 'setting' AS setting,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    j.value ->> 'resource_name' AS resource_name,
    j.value ->> 'limit' AS limit,
    j.value ->> 'total_sql_logins' AS total_sql_logins,
    j.value ->> 'no_policy' AS no_policy,
    j.value ->> 'no_expiration' AS no_expiration,
    j.value ->> 'no_both' AS no_both,
    j.value ->> 'pct_no_policy' AS pct_no_policy,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'is_sysadmin' AS is_sysadmin,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-003-RC01';

DROP VIEW IF EXISTS monitoring.v_sec_sql_au_003_rc02;

-- ============================================================
-- View: monitoring.v_sec_sql_au_003_rc02
-- Root cause: SEC-SQL-AU-003-RC02
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc02 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'is_sysadmin' AS is_sysadmin,
    j.value ->> 'is_securityadmin' AS is_securityadmin,
    j.value ->> 'status' AS state,
    j.value ->> 'profile' AS profile,
    j.value ->> 'limit' AS limit,
    j.value ->> 'is_blank' AS is_blank,
    j.value ->> 'is_password' AS is_password,
    j.value ->> 'is_password1' AS is_password1,
    j.value ->> 'is_123456' AS is_123456,
    j.value ->> 'is_same_as_login' AS is_same_as_login,
    j.value ->> 'is_passw0rd' AS is_passw0rd,
    j.value ->> 'is_admin' AS is_admin,
    j.value ->> 'is_sa' AS is_sa,
    j.value ->> 'resource_name' AS resource_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-003-RC02';

DROP VIEW IF EXISTS monitoring.v_sec_sql_au_003_rc05;

-- ============================================================
-- View: monitoring.v_sec_sql_au_003_rc05
-- Root cause: SEC-SQL-AU-003-RC05
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc05 AS
SELECT
    r.server,
    j.value ->> 'name' AS username,
    j.value ->> 'setting' AS setting,
    j.value ->> 'profile' AS profile,
    j.value ->> 'resource_name' AS resource_name,
    j.value ->> 'limit' AS limit,
    j.value ->> 'object_name' AS object_name,
    j.value ->> 'object_type' AS object_type,
    j.value ->> 'status' AS state,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'login_name_length' AS login_name_length,
    j.value ->> 'is_blank' AS is_blank,
    j.value ->> 'is_same_as_login' AS is_same_as_login,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-003-RC05';

DROP VIEW IF EXISTS monitoring.v_sec_sql_au_003_rc07;

-- ============================================================
-- View: monitoring.v_sec_sql_au_003_rc07
-- Root cause: SEC-SQL-AU-003-RC07
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc07 AS
SELECT
    r.server,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolvaliduntil' AS rolvaliduntil,
    j.value ->> 'profile' AS profile,
    j.value ->> 'resource_name' AS resource_name,
    j.value ->> 'limit' AS limit,
    COALESCE(
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'password_age_days' AS password_age_days,
    j.value ->> 'host' AS host,
    to_timestamp((j.value ->> 'password_last_changed')::bigint / 3.0) AS password_last_changed,
    j.value ->> 'days_since_change' AS days_since_change,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'hash_algorithm' AS hash_algorithm,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-003-RC07'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_au_003_rc08;

-- ============================================================
-- View: monitoring.v_sec_sql_au_003_rc08
-- Root cause: SEC-SQL-AU-003-RC08
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc08 AS
SELECT
    r.server,
    j.value ->> 'profile' AS profile,
    j.value ->> 'resource_name' AS resource_name,
    j.value ->> 'limit' AS limit,
    j.value ->> 'line_number' AS line_number,
    j.value ->> 'type' AS state,
    j.value ->> 'database' AS database,
    j.value ->> 'user_name' AS user_name,
    j.value ->> 'address' AS address,
    j.value ->> 'auth_method' AS auth_method,
    j.value ->> 'name' AS username,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'is_blank' AS is_blank,
    j.value ->> 'matches_login_name' AS matches_login_name,
    j.value ->> 'is_common_password' AS is_common_password,
    j.value ->> 'is_common_dev_password' AS is_common_dev_password,
    j.value ->> 'is_common_complex_password' AS is_common_complex_password,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'bad_password_count' AS bad_password_count,
    j.value ->> 'is_locked' AS is_locked,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-003-RC08';

DROP VIEW IF EXISTS monitoring.v_sec_sql_au_003_rc09;

-- ============================================================
-- View: monitoring.v_sec_sql_au_003_rc09
-- Root cause: SEC-SQL-AU-003-RC09
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc09 AS
SELECT
    r.server,
    j.value ->> 'plugin' AS plugin,
    j.value ->> 'account_count' AS account_count,
    j.value ->> 'auth_method' AS auth_method,
    j.value ->> 'rule_count' AS rule_count,
    j.value ->> 'total_sql_logins' AS total_sql_logins,
    j.value ->> 'policy_enforced_count' AS policy_enforced_count,
    j.value ->> 'policy_not_enforced_count' AS policy_not_enforced_count,
    j.value ->> 'expiration_enforced_count' AS expiration_enforced_count,
    j.value ->> 'expiration_not_enforced_count' AS expiration_not_enforced_count,
    j.value ->> 'pct_without_policy' AS pct_without_policy,
    j.value ->> 'profile' AS profile,
    j.value ->> 'user_count' AS user_count,
    j.value ->> 'active_users' AS active_users,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    j.value ->> 'resource_name' AS resource_name,
    j.value ->> 'limit' AS limit,
    j.value ->> 'name' AS username,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'password_age_days' AS password_age_days,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-003-RC09';

DROP VIEW IF EXISTS monitoring.v_sec_sql_au_003_rc11;

-- ============================================================
-- View: monitoring.v_sec_sql_au_003_rc11
-- Root cause: SEC-SQL-AU-003-RC11
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc11 AS
SELECT
    r.server,
    j.value ->> 'name' AS username,
    j.value ->> 'bad_password_count' AS bad_password_count,
    to_timestamp((j.value ->> 'last_bad_password_time')::bigint / 3.0) AS last_bad_password_time,
    j.value ->> 'is_locked' AS is_locked,
    to_timestamp((j.value ->> 'lockout_time')::bigint / 3.0) AS lockout_time,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'policy_name' AS policy_name,
    j.value ->> 'enabled_option' AS enabled_option,
    j.value ->> 'entity_name' AS entity_name,
    j.value ->> 'entity_type' AS entity_type,
    j.value ->> 'parameter_name' AS parameter_name,
    j.value ->> 'parameter_value' AS parameter_value,
    j.value ->> 'setting' AS setting,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-003-RC11';

DROP VIEW IF EXISTS monitoring.v_sec_sql_au_003_rc12;

-- ============================================================
-- View: monitoring.v_sec_sql_au_003_rc12
-- Root cause: SEC-SQL-AU-003-RC12
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc12 AS
SELECT
    r.server,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'login_count' AS login_count,
    j.value ->> 'logins' AS logins,
    j.value ->> 'extname' AS extname,
    j.value ->> 'min_password_age_days' AS min_password_age_days,
    j.value ->> 'max_password_age_days' AS max_password_age_days,
    j.value ->> 'avg_password_age_days' AS avg_password_age_days,
    j.value ->> 'stdev_password_age_days' AS stdev_password_age_days,
    j.value ->> 'total_logins' AS total_logins,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-003-RC12';

DROP VIEW IF EXISTS monitoring.v_sec_sql_au_003_rc13;

-- ============================================================
-- View: monitoring.v_sec_sql_au_003_rc13
-- Root cause: SEC-SQL-AU-003-RC13
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc13 AS
SELECT
    r.server,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolcanlogin' AS rolcanlogin,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    to_timestamp((j.value ->> 'creation_date')::bigint / 3.0) AS creation_date,
    to_timestamp((j.value ->> 'accounts_created')::bigint / 3.0) AS accounts_created,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'secs_between_create_and_pwdset' AS secs_between_create_and_pwdset,
    to_timestamp((j.value ->> 'logins_created')::bigint / 3.0) AS logins_created,
    j.value ->> 'no_policy_count' AS no_policy_count,
    j.value ->> 'no_expiration_count' AS no_expiration_count,
    j.value ->> 'profile' AS profile,
    j.value ->> 'account_status' AS account_status,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    j.value ->> 'authentication_type' AS authentication_type,
    j.value ->> 'limit' AS limit,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-003-RC13';

DROP VIEW IF EXISTS monitoring.v_sec_sql_au_004_rc04;

-- ============================================================
-- View: monitoring.v_sec_sql_au_004_rc04
-- Root cause: SEC-SQL-AU-004-RC04
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_004_rc04 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'host' AS host,
    j.value ->> 'plugin' AS plugin,
    j.value ->> 'authentication_type' AS authentication_type,
    j.value ->> 'external_name' AS external_name,
    j.value ->> 'account_status' AS account_status,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'domain_name' AS domain_name,
    j.value ->> 'is_sysadmin' AS is_sysadmin,
    j.value ->> 'is_securityadmin' AS is_securityadmin,
    j.value ->> 'is_dbcreator' AS is_dbcreator,
    j.value ->> 'value' AS value,
    j.value ->> 'is_disabled' AS is_disabled,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'default_database_name' AS default_database_name,
    j.value ->> 'line_number' AS line_number,
    j.value ->> 'type' AS state,
    j.value ->> 'database' AS database,
    j.value ->> 'user_name' AS user_name,
    j.value ->> 'address' AS address,
    j.value ->> 'auth_method' AS auth_method,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-004-RC04'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_au_004_rc12;

-- ============================================================
-- View: monitoring.v_sec_sql_au_004_rc12
-- Root cause: SEC-SQL-AU-004-RC12
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_004_rc12 AS
SELECT
    r.server,
    j.value ->> 'os_auth_audit_count' AS os_auth_audit_count,
    j.value ->> 'name' AS username,
    j.value ->> 'setting' AS setting,
    j.value ->> 'policy_name' AS policy_name,
    j.value ->> 'audit_option' AS audit_option,
    j.value ->> 'audit_condition' AS audit_condition,
    j.value ->> 'plugin' AS plugin,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-004-RC12';

DROP VIEW IF EXISTS monitoring.v_sec_sql_au_005_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_au_005_rc01
-- Root cause: SEC-SQL-AU-005-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_005_rc01 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'login_name',
        j.value ->> 'username'
    ) AS username,
    j.value ->> 'authentication_type' AS authentication_type,
    j.value ->> 'account_status' AS account_status,
    j.value ->> 'profile' AS profile,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    to_timestamp((j.value ->> 'last_login')::bigint / 3.0) AS last_login,
    j.value ->> 'common' AS common,
    j.value ->> 'program_name' AS application_name,
    j.value ->> 'host_name' AS host,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'session_count' AS session_count,
    j.value ->> 'windows_auth_only' AS windows_auth_only,
    j.value ->> 'auth_mode' AS auth_mode,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-005-RC01'
  AND j.value ->> 'host_name' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_au_005_rc02;

-- ============================================================
-- View: monitoring.v_sec_sql_au_005_rc02
-- Root cause: SEC-SQL-AU-005-RC02
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_005_rc02 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'distinct_machines' AS distinct_machines,
    j.value ->> 'distinct_programs' AS distinct_programs,
    j.value ->> 'session_count' AS session_count,
    j.value ->> 'windows_auth_only' AS windows_auth_only,
    j.value ->> 'default_database_name' AS default_database_name,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'account_status' AS account_status,
    j.value ->> 'profile' AS profile,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    j.value ->> 'common' AS common,
    to_timestamp((j.value ->> 'last_login')::bigint / 3.0) AS last_login,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-005-RC02';

DROP VIEW IF EXISTS monitoring.v_sec_sql_au_005_rc05;

-- ============================================================
-- View: monitoring.v_sec_sql_au_005_rc05
-- Root cause: SEC-SQL-AU-005-RC05
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_005_rc05 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'account_status' AS account_status,
    j.value ->> 'profile' AS profile,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    to_timestamp((j.value ->> 'last_login')::bigint / 3.0) AS last_login,
    j.value ->> 'authentication_type' AS authentication_type,
    to_timestamp((j.value ->> 'expiry_date')::bigint / 3.0) AS expiry_date,
    j.value ->> 'windows_auth_only' AS windows_auth_only,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'resource_name' AS resource_name,
    j.value ->> 'limit' AS limit,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-005-RC05';

DROP VIEW IF EXISTS monitoring.v_sec_sql_au_005_rc06;

-- ============================================================
-- View: monitoring.v_sec_sql_au_005_rc06
-- Root cause: SEC-SQL-AU-005-RC06
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_005_rc06 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'account_status' AS account_status,
    j.value ->> 'profile' AS profile,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    to_timestamp((j.value ->> 'last_login')::bigint / 3.0) AS last_login,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'windows_auth_only' AS windows_auth_only,
    j.value ->> 'server_name' AS server_name,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-005-RC06';

DROP VIEW IF EXISTS monitoring.v_sec_sql_au_005_rc10;

-- ============================================================
-- View: monitoring.v_sec_sql_au_005_rc10
-- Root cause: SEC-SQL-AU-005-RC10
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_005_rc10 AS
SELECT
    r.server,
    j.value ->> 'windows_auth_only' AS windows_auth_only,
    j.value ->> 'name' AS username,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'is_sysadmin' AS is_sysadmin,
    j.value ->> 'is_securityadmin' AS is_securityadmin,
    j.value ->> 'is_serveradmin' AS is_serveradmin,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'profile' AS profile,
    j.value ->> 'resource_name' AS resource_name,
    j.value ->> 'limit' AS limit,
    j.value ->> 'distinct_hosts' AS distinct_hosts,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-005-RC10';

DROP VIEW IF EXISTS monitoring.v_sec_sql_au_005_rc13;

-- ============================================================
-- View: monitoring.v_sec_sql_au_005_rc13
-- Root cause: SEC-SQL-AU-005-RC13
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_005_rc13 AS
SELECT
    r.server,
    j.value ->> 'policy_name' AS policy_name,
    j.value ->> 'enabled_option' AS enabled_option,
    j.value ->> 'entity_name' AS entity_name,
    j.value ->> 'entity_type' AS entity_type,
    j.value ->> 'success' AS success,
    j.value ->> 'failure' AS failure,
    j.value ->> 'windows_auth_only' AS windows_auth_only,
    j.value ->> 'sql_version' AS sql_version,
    j.value ->> 'parameter' AS parameter,
    j.value ->> 'value' AS value,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-005-RC13';

DROP VIEW IF EXISTS monitoring.v_sec_sql_au_006_rc08;

-- ============================================================
-- View: monitoring.v_sec_sql_au_006_rc08
-- Root cause: SEC-SQL-AU-006-RC08
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_006_rc08 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    j.value ->> 'is_disabled' AS is_disabled,
    to_timestamp((j.value ->> 'days_since_modified')::bigint / 3.0) AS days_since_modified,
    j.value ->> 'auth_method' AS auth_method,
    j.value ->> 'rule_count' AS rule_count,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    j.value ->> 'profile' AS profile,
    j.value ->> 'authentication_type' AS authentication_type,
    j.value ->> 'external_name' AS external_name,
    j.value ->> 'local_accounts' AS local_accounts,
    j.value ->> 'value' AS value,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-006-RC08';

DROP VIEW IF EXISTS monitoring.v_sec_sql_au_006_rc12;

-- ============================================================
-- View: monitoring.v_sec_sql_au_006_rc12
-- Root cause: SEC-SQL-AU-006-RC12
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_006_rc12 AS
SELECT
    r.server,
    j.value ->> 'extname' AS extname,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'name'
    ) AS username,
    to_timestamp((j.value ->> 'last_login')::bigint / 3.0) AS last_login,
    j.value ->> 'account_status' AS account_status,
    j.value ->> 'days_inactive' AS days_inactive,
    j.value ->> 'dormant_count' AS dormant_count,
    j.value ->> 'profile' AS profile,
    j.value ->> 'resource_name' AS resource_name,
    j.value ->> 'limit' AS limit,
    j.value ->> 'setting' AS setting,
    j.value ->> 'enabled' AS enabled,
    to_timestamp((j.value ->> 'date_created')::bigint / 3.0) AS date_created,
    j.value ->> 'step_name' AS step_name,
    j.value ->> 'command' AS state,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-006-RC12';

DROP VIEW IF EXISTS monitoring.v_sec_sql_au_006_rc14;

-- ============================================================
-- View: monitoring.v_sec_sql_au_006_rc14
-- Root cause: SEC-SQL-AU-006-RC14
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_006_rc14 AS
SELECT
    r.server,
    j.value ->> 'name' AS username,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'status' AS state,
    j.value ->> 'on_failure_desc' AS on_failure_desc,
    j.value ->> 'queue_delay' AS queue_delay,
    j.value ->> 'log_file_path' AS log_file_path,
    j.value ->> 'max_file_size' AS max_file_size,
    j.value ->> 'max_rollover_files' AS max_rollover_files,
    j.value ->> 'setting' AS setting,
    j.value ->> 'value' AS value,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    j.value ->> 'policy_name' AS policy_name,
    j.value ->> 'enabled_option' AS enabled_option,
    j.value ->> 'entity_name' AS entity_name,
    j.value ->> 'entity_type' AS entity_type,
    j.value ->> 'success' AS success,
    j.value ->> 'failure' AS failure,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-006-RC14';

DROP VIEW IF EXISTS monitoring.v_sec_sql_au_006_rc15;

-- ============================================================
-- View: monitoring.v_sec_sql_au_006_rc15
-- Root cause: SEC-SQL-AU-006-RC15
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_006_rc15 AS
SELECT
    r.server,
    j.value ->> 'total_users' AS total_users,
    j.value ->> 'value' AS value_val,
    j.value ->> 'name' AS username,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'role_membership' AS role_membership,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolcanlogin' AS rolcanlogin,
    j.value ->> 'owned_objects' AS owned_objects,
    j.value ->> 'total_active_logins' AS total_active_logins,
    j.value ->> 'logins_no_current_session' AS logins_no_current_session,
    j.value ->> 'logins_stale_password' AS logins_stale_password,
    j.value ->> 'logins_older_than_1yr' AS logins_older_than_1yr,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-006-RC15';

DROP VIEW IF EXISTS monitoring.v_sec_sql_au_007_rc14;

-- ============================================================
-- View: monitoring.v_sec_sql_au_007_rc14
-- Root cause: SEC-SQL-AU-007-RC14
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_007_rc14 AS
SELECT
    r.server,
    j.value ->> 'empty_passwords' AS empty_passwords,
    j.value ->> 'anonymous_users' AS anonymous_users,
    j.value ->> 'remote_root' AS remote_root,
    j.value ->> 'socket_auth' AS socket_auth,
    j.value ->> 'name' AS username,
    j.value ->> 'is_state_enabled' AS is_state_enabled,
    j.value ->> 'audit_action_name' AS audit_action_name,
    j.value ->> 'value' AS value,
    j.value ->> 'isdefault' AS isdefault,
    j.value ->> 'ismodified' AS ismodified,
    j.value ->> 'line_number' AS line_number,
    j.value ->> 'type' AS state,
    j.value ->> 'database' AS database,
    j.value ->> 'user_name' AS user_name,
    j.value ->> 'address' AS address,
    j.value ->> 'auth_method' AS auth_method,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-007-RC14';

DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_001_rc04;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_001_rc04
-- Root cause: SEC-SQL-AUD-001-RC04
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_001_rc04 AS
SELECT
    r.server,
    j.value ->> 'audit_count' AS audit_count,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    j.value ->> 'banner' AS banner,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-001-RC04';

DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_002_rc05;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_002_rc05
-- Root cause: SEC-SQL-AUD-002-RC05
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_002_rc05 AS
SELECT
    r.server,
    j.value ->> 'file_audit_count' AS file_audit_count,
    j.value ->> 'name' AS username,
    j.value ->> 'setting' AS setting,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'is_state_enabled' AS is_state_enabled,
    j.value ->> 'on_failure_desc' AS on_failure_desc,
    j.value ->> 'retention_risk' AS retention_risk,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-002-RC05';

DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_004_rc02;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_004_rc02
-- Root cause: SEC-SQL-AUD-004-RC02
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_004_rc02 AS
SELECT
    r.server,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    j.value ->> 'name' AS username,
    j.value ->> 'setting' AS setting,
    j.value ->> 'policy_name' AS policy_name,
    j.value ->> 'enabled_option' AS enabled_option,
    j.value ->> 'success' AS success,
    j.value ->> 'failure' AS failure,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-004-RC02';

DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_004_rc04;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_004_rc04
-- Root cause: SEC-SQL-AUD-004-RC04
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_004_rc04 AS
SELECT
    r.server,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    j.value ->> 'policy_name' AS policy_name,
    j.value ->> 'extname' AS extname,
    j.value ->> 'extversion' AS extversion,
    j.value ->> 'name' AS username,
    j.value ->> 'setting' AS setting,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-004-RC04';

DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_005_rc06;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_005_rc06
-- Root cause: SEC-SQL-AUD-005-RC06
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_005_rc06 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'owner',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'temporary' AS temporary,
    j.value ->> 'setting' AS setting,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-005-RC06';

DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_005_rc07;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_005_rc07
-- Root cause: SEC-SQL-AUD-005-RC07
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_005_rc07 AS
SELECT
    r.server,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_version' AS plugin_version,
    j.value ->> 'plugin_type_version' AS plugin_type_version,
    j.value ->> 'plugin_library' AS plugin_library,
    COALESCE(
        j.value ->> 'grantee',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'setting' AS setting,
    j.value ->> 'policy_name' AS policy_name,
    j.value ->> 'audit_option' AS audit_option,
    j.value ->> 'extname' AS extname,
    j.value ->> 'extversion' AS extversion,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'privilege' AS privilege,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-005-RC07';

DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_006_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_006_rc01
-- Root cause: SEC-SQL-AUD-006-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_006_rc01 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'usename',
        j.value ->> 'login_name',
        j.value ->> 'username',
        j.value ->> 'user'
    ) AS username,
    COALESCE(
        j.value ->> 'state',
        j.value ->> 'status',
        j.value ->> 'command'
    ) AS state_val,
    to_timestamp((j.value ->> 'start_time')::bigint / 3.0) AS start_time,
    to_timestamp((j.value ->> 'start_hour')::bigint / 3.0) AS start_hour,
    COALESCE(
        j.value ->> 'pid',
        j.value ->> 'session_id',
        j.value ->> 'sid',
        j.value ->> 'id'
    ) AS session_id,
    COALESCE(
        j.value ->> 'client_addr',
        j.value ->> 'host_name',
        j.value ->> 'machine',
        j.value ->> 'host'
    ) AS host,
    j.value ->> 'db' AS db,
    to_timestamp((j.value ->> 'time')::bigint / 3.0) AS time_val,
    COALESCE(
        j.value ->> 'query',
        j.value ->> 'info',
        j.value ->> 'sql_text',
        j.value ->> 'text'
    ) AS query_text,
    j.value ->> 'serial' AS serial,
    j.value ->> 'osuser' AS osuser,
    to_timestamp((j.value ->> 'logon_time')::bigint / 3.0) AS logon_time,
    COALESCE(
        j.value ->> 'application_name',
        j.value ->> 'program_name'
    ) AS application_name,
    j.value ->> 'current_hour' AS current_hour,
    to_timestamp((j.value ->> 'query_start')::bigint / 3.0) AS query_start,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-006-RC01';

DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_006_rc02;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_006_rc02
-- Root cause: SEC-SQL-AUD-006-RC02
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_006_rc02 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'usename',
        j.value ->> 'login_name',
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'owner',
        j.value ->> 'schema_name',
        j.value ->> 'name'
    ) AS username,
    COALESCE(
        j.value ->> 'query',
        j.value ->> 'info',
        j.value ->> 'sql_text',
        j.value ->> 'text'
    ) AS query_text,
    COALESCE(
        j.value ->> 'client_addr',
        j.value ->> 'host_name',
        j.value ->> 'machine',
        j.value ->> 'host'
    ) AS host,
    to_timestamp((j.value ->> 'logon_time')::bigint / 3.0) AS logon_time,
    COALESCE(
        j.value ->> 'pid',
        j.value ->> 'id'
    ) AS session_id,
    j.value ->> 'db' AS db,
    to_timestamp((j.value ->> 'time')::bigint / 3.0) AS time,
    j.value ->> 'table_schema' AS table_schema,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'table_comment' AS table_comment,
    j.value ->> 'object_name' AS object_name,
    j.value ->> 'column_name' AS column_name,
    j.value ->> 'sensitive_type' AS sensitive_type,
    to_timestamp((j.value ->> 'query_start')::bigint / 3.0) AS query_start,
    j.value ->> 'relname' AS relname,
    j.value ->> 'nspname' AS nspname,
    j.value ->> 'comment' AS comment,
    to_timestamp((j.value ->> 'start_time')::bigint / 3.0) AS start_time,
    j.value ->> 'value' AS value,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-006-RC02';

DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_006_rc03;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_006_rc03
-- Root cause: SEC-SQL-AUD-006-RC03
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_006_rc03 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'usename',
        j.value ->> 'login_name',
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'grantee',
        j.value ->> 'owner',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'db_name' AS db_name,
    COALESCE(
        j.value ->> 'query',
        j.value ->> 'info',
        j.value ->> 'sql_text',
        j.value ->> 'text'
    ) AS query_text,
    to_timestamp((j.value ->> 'start_time')::bigint / 3.0) AS start_time,
    j.value ->> 'table_schema' AS table_schema,
    j.value ->> 'privilege_type' AS privilege_type,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'privilege' AS privilege,
    COALESCE(
        j.value ->> 'pid',
        j.value ->> 'id'
    ) AS session_id,
    j.value ->> 'db' AS db,
    j.value ->> 'host' AS host,
    to_timestamp((j.value ->> 'time')::bigint / 3.0) AS time_val,
    j.value ->> 'schemaname' AS schemaname,
    j.value ->> 'tablename' AS tablename,
    j.value ->> 'tableowner' AS tableowner,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'query_start')::bigint / 3.0) AS query_start,
    j.value ->> 'search_path' AS search_path,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-006-RC03'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_006_rc04;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_006_rc04
-- Root cause: SEC-SQL-AUD-006-RC04
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_006_rc04 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'usename',
        j.value ->> 'login_name',
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'grantee',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'privilege_type' AS privilege_type,
    j.value ->> 'is_grantable' AS is_grantable,
    COALESCE(
        j.value ->> 'pid',
        j.value ->> 'id'
    ) AS session_id,
    COALESCE(
        j.value ->> 'client_addr',
        j.value ->> 'host_name',
        j.value ->> 'machine',
        j.value ->> 'host'
    ) AS host,
    COALESCE(
        j.value ->> 'state',
        j.value ->> 'status',
        j.value ->> 'command'
    ) AS state,
    to_timestamp((j.value ->> 'time')::bigint / 3.0) AS time,
    COALESCE(
        j.value ->> 'query',
        j.value ->> 'info'
    ) AS query_text,
    COALESCE(
        j.value ->> 'application_name',
        j.value ->> 'program_name',
        j.value ->> 'program'
    ) AS application_name,
    j.value ->> 'client_interface_name' AS client_interface_name,
    to_timestamp((j.value ->> 'login_time')::bigint / 3.0) AS login_time,
    j.value ->> 'terminal' AS terminal,
    to_timestamp((j.value ->> 'logon_time')::bigint / 3.0) AS logon_time,
    to_timestamp((j.value ->> 'granted_role')::bigint / 3.0) AS granted_role,
    j.value ->> 'admin_option' AS admin_option,
    j.value ->> 'default_role' AS default_role,
    to_timestamp((j.value ->> 'backend_start')::bigint / 3.0) AS backend_start,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'description' AS description,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-006-RC04';

DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_006_rc05;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_006_rc05
-- Root cause: SEC-SQL-AUD-006-RC05
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_006_rc05 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'pid',
        j.value ->> 'session_id',
        j.value ->> 'id'
    ) AS session_id,
    COALESCE(
        j.value ->> 'usename',
        j.value ->> 'login_name',
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'grantee'
    ) AS username,
    COALESCE(
        j.value ->> 'client_addr',
        j.value ->> 'host'
    ) AS host,
    j.value ->> 'db' AS db,
    to_timestamp((j.value ->> 'time')::bigint / 3.0) AS time,
    COALESCE(
        j.value ->> 'query',
        j.value ->> 'info',
        j.value ->> 'sql_text',
        j.value ->> 'text'
    ) AS query_text,
    j.value ->> 'privilege_type' AS privilege_type,
    j.value ->> 'is_grantable' AS is_grantable,
    to_timestamp((j.value ->> 'logon_time')::bigint / 3.0) AS logon_time,
    j.value ->> 'status' AS state,
    j.value ->> 'original_login_name' AS original_login_name,
    to_timestamp((j.value ->> 'start_time')::bigint / 3.0) AS start_time,
    j.value ->> 'db_user' AS db_user,
    j.value ->> 'action_name' AS action_name,
    j.value ->> 'obj_name' AS obj_name,
    j.value ->> 'timestamp' AS timestamp,
    j.value ->> 'return_code' AS return_code,
    to_timestamp((j.value ->> 'query_start')::bigint / 3.0) AS query_start,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-006-RC05';

DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_007_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_007_rc01
-- Root cause: SEC-SQL-AUD-007-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_007_rc01 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'pid',
        j.value ->> 'session_id'
    ) AS session_id,
    COALESCE(
        j.value ->> 'usename',
        j.value ->> 'login_name',
        j.value ->> 'username',
        j.value ->> 'user'
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
        j.value ->> 'host'
    ) AS host,
    j.value ->> 'client_interface_name' AS client_interface_name,
    j.value ->> 'current_connections' AS current_connections,
    j.value ->> 'total_connections' AS total_connections,
    j.value ->> 'db' AS db,
    COALESCE(
        j.value ->> 'state',
        j.value ->> 'command'
    ) AS state,
    j.value ->> 'info' AS query_text,
    j.value ->> 'client_info' AS client_info,
    j.value ->> 'sessions' AS sessions,
    j.value ->> 'module' AS module,
    to_timestamp((j.value ->> 'logon_time')::bigint / 3.0) AS logon_time,
    j.value ->> 'session_count' AS session_count,
    to_timestamp((j.value ->> 'query_start')::bigint / 3.0) AS query_start,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-007-RC01';

DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_007_rc02;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_007_rc02
-- Root cause: SEC-SQL-AUD-007-RC02
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_007_rc02 AS
SELECT
    r.server,
    j.value ->> 'digest_text' AS digest_text,
    j.value ->> 'count_star' AS count_star,
    j.value ->> 'avg_timer_wait_1000000000' AS avg_timer_wait_1000000000,
    j.value ->> 'sum_rows_examined' AS sum_rows_examined,
    j.value ->> 'sum_rows_sent' AS sum_rows_sent,
    j.value ->> 'sql_id' AS sql_id,
    COALESCE(
        j.value ->> 'query',
        j.value ->> 'sql_text',
        j.value ->> 'text'
    ) AS query_text,
    j.value ->> 'executions' AS executions,
    j.value ->> 'buffer_gets' AS buffer_gets,
    j.value ->> 'disk_reads' AS disk_reads,
    to_timestamp((j.value ->> 'first_load_time')::bigint / 3.0) AS first_load_time,
    to_timestamp((j.value ->> 'last_active_time')::bigint / 3.0) AS last_active_time,
    j.value ->> 'digest' AS digest,
    j.value ->> 'query_sql_text' AS query_sql_text,
    j.value ->> 'count_executions' AS count_executions,
    j.value ->> 'avg_duration' AS avg_duration,
    j.value ->> 'query_plan' AS query_plan,
    j.value ->> 'calls' AS calls,
    to_timestamp((j.value ->> 'total_exec_time')::bigint / 3.0) AS total_exec_time,
    j.value ->> 'rows' AS rows_val,
    j.value ->> 'userid' AS userid,
    to_timestamp((j.value ->> 'elapsed_time_total')::bigint / 3.0) AS elapsed_time_total,
    j.value ->> 'executions_total' AS executions_total,
    j.value ->> 'buffer_gets_total' AS buffer_gets_total,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'queryid' AS queryid,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-007-RC02';

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
WHERE r.metric_name = 'SEC-SQL-AUD-007-RC03';

DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_007_rc04;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_007_rc04
-- Root cause: SEC-SQL-AUD-007-RC04
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_007_rc04 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'usename',
        j.value ->> 'login_name',
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'owner',
        j.value ->> 'name'
    ) AS username,
    COALESCE(
        j.value ->> 'application_name',
        j.value ->> 'program_name',
        j.value ->> 'program'
    ) AS application_name,
    COALESCE(
        j.value ->> 'host_name',
        j.value ->> 'machine',
        j.value ->> 'host'
    ) AS host,
    to_timestamp((j.value ->> 'login_time')::bigint / 3.0) AS login_time,
    COALESCE(
        j.value ->> 'state',
        j.value ->> 'status',
        j.value ->> 'command'
    ) AS state,
    j.value ->> 'utc_hour' AS utc_hour,
    COALESCE(
        j.value ->> 'pid',
        j.value ->> 'id'
    ) AS session_id,
    j.value ->> 'db' AS db,
    to_timestamp((j.value ->> 'time')::bigint / 3.0) AS time,
    j.value ->> 'info' AS query_text,
    to_timestamp((j.value ->> 'query_start')::bigint / 3.0) AS query_start,
    j.value ->> 'event_schema' AS event_schema,
    j.value ->> 'event_name' AS event_name,
    to_timestamp((j.value ->> 'execute_at')::bigint / 3.0) AS execute_at,
    j.value ->> 'interval_value' AS interval_value,
    j.value ->> 'interval_field' AS interval_field,
    j.value ->> 'definer' AS definer,
    j.value ->> 'job_name' AS job_name,
    to_timestamp((j.value ->> 'last_run_duration')::bigint / 3.0) AS last_run_duration,
    to_timestamp((j.value ->> 'next_run_date')::bigint / 3.0) AS next_run_date,
    to_timestamp((j.value ->> 'logon_time')::bigint / 3.0) AS logon_time,
    to_timestamp((j.value ->> 'active_start_time')::bigint / 3.0) AS active_start_time,
    to_timestamp((j.value ->> 'active_end_time')::bigint / 3.0) AS active_end_time,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolcanlogin' AS rolcanlogin,
    j.value ->> 'rolvaliduntil' AS rolvaliduntil,
    j.value ->> 'comment' AS comment,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-007-RC04';

DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_008_rc03;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_008_rc03
-- Root cause: SEC-SQL-AUD-008-RC03
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_008_rc03 AS
SELECT
    r.server,
    j.value ->> 'rolname' AS rolname,
    COALESCE(
        j.value ->> 'usename',
        j.value ->> 'login_name',
        j.value ->> 'user',
        j.value ->> 'grantee',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'privilege' AS privilege,
    j.value ->> 'admin_option' AS admin_option,
    COALESCE(
        j.value ->> 'pid',
        j.value ->> 'id'
    ) AS session_id,
    COALESCE(
        j.value ->> 'client_addr',
        j.value ->> 'host'
    ) AS host,
    j.value ->> 'db' AS db,
    to_timestamp((j.value ->> 'time')::bigint / 3.0) AS time,
    COALESCE(
        j.value ->> 'query',
        j.value ->> 'info',
        j.value ->> 'text'
    ) AS query_text,
    j.value ->> 'command' AS state,
    to_timestamp((j.value ->> 'start_time')::bigint / 3.0) AS start_time,
    j.value ->> 'db_name' AS db_name,
    j.value ->> 'role_principal_id' AS role_principal_id,
    j.value ->> 'table_schema' AS table_schema,
    j.value ->> 'privilege_type' AS privilege_type,
    to_timestamp((j.value ->> 'query_start')::bigint / 3.0) AS query_start,
    j.value ->> 'db_user' AS db_user,
    j.value ->> 'action_name' AS action_name,
    j.value ->> 'obj_owner' AS obj_owner,
    j.value ->> 'obj_name' AS obj_name,
    j.value ->> 'timestamp' AS timestamp,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-008-RC03';

DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_008_rc04;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_008_rc04
-- Root cause: SEC-SQL-AUD-008-RC04
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_008_rc04 AS
SELECT
    r.server,
    j.value ->> 'relname' AS relname,
    j.value ->> 'nspname' AS nspname,
    j.value ->> 'comment' AS comment,
    COALESCE(
        j.value ->> 'usename',
        j.value ->> 'login_name',
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    COALESCE(
        j.value ->> 'query',
        j.value ->> 'info',
        j.value ->> 'sql_text',
        j.value ->> 'text'
    ) AS query_text,
    to_timestamp((j.value ->> 'start_time')::bigint / 3.0) AS start_time,
    j.value ->> 'executions' AS executions,
    COALESCE(
        j.value ->> 'state',
        j.value ->> 'status'
    ) AS state,
    COALESCE(
        j.value ->> 'pid',
        j.value ->> 'id'
    ) AS session_id,
    j.value ->> 'host' AS host,
    j.value ->> 'db' AS db,
    to_timestamp((j.value ->> 'time')::bigint / 3.0) AS time,
    j.value ->> 'symmetric_key_id' AS symmetric_key_id,
    j.value ->> 'key_algorithm' AS key_algorithm,
    j.value ->> 'key_length' AS key_length,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    j.value ->> 'plugin_type' AS plugin_type,
    to_timestamp((j.value ->> 'query_start')::bigint / 3.0) AS query_start,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-008-RC04'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_008_rc05;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_008_rc05
-- Root cause: SEC-SQL-AUD-008-RC05
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_008_rc05 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'pid',
        j.value ->> 'id'
    ) AS session_id,
    COALESCE(
        j.value ->> 'usename',
        j.value ->> 'login_name',
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'schema_name',
        j.value ->> 'name'
    ) AS username,
    COALESCE(
        j.value ->> 'query',
        j.value ->> 'info',
        j.value ->> 'sql_text',
        j.value ->> 'text'
    ) AS query_text,
    to_timestamp((j.value ->> 'query_start')::bigint / 3.0) AS query_start,
    j.value ->> 'nspname' AS nspname,
    j.value ->> 'default_character_set_name' AS default_character_set_name,
    to_timestamp((j.value ->> 'start_time')::bigint / 3.0) AS start_time,
    j.value ->> 'db' AS db,
    j.value ->> 'host' AS host,
    to_timestamp((j.value ->> 'time')::bigint / 3.0) AS time,
    j.value ->> 'executions' AS executions,
    to_timestamp((j.value ->> 'last_active_time')::bigint / 3.0) AS last_active_time,
    j.value ->> 'account_status' AS account_status,
    j.value ->> 'profile' AS profile,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    j.value ->> 'object_count' AS object_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-008-RC05'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_014_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_014_rc01
-- Root cause: SEC-SQL-AUD-014-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_014_rc01 AS
SELECT
    r.server,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolcanlogin' AS rolcanlogin,
    j.value ->> 'rolcreatedb' AS rolcreatedb,
    j.value ->> 'rolcreaterole' AS rolcreaterole,
    j.value ->> 'rolsuper' AS rolsuper,
    j.value ->> 'oid' AS oid,
    COALESCE(
        j.value ->> 'usename',
        j.value ->> 'login_name',
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'is_disabled' AS is_disabled,
    COALESCE(
        j.value ->> 'client_addr',
        j.value ->> 'host'
    ) AS host,
    j.value ->> 'plugin' AS plugin,
    to_timestamp((j.value ->> 'password_changed_time')::bigint / 3.0) AS password_changed_time,
    j.value ->> 'account_locked' AS account_locked,
    COALESCE(
        j.value ->> 'pid',
        j.value ->> 'sid',
        j.value ->> 'id'
    ) AS session_id,
    COALESCE(
        j.value ->> 'query',
        j.value ->> 'info',
        j.value ->> 'sql_text',
        j.value ->> 'text'
    ) AS query_text,
    to_timestamp((j.value ->> 'query_start')::bigint / 3.0) AS query_start,
    to_timestamp((j.value ->> 'last_active_time')::bigint / 3.0) AS last_active_time,
    j.value ->> 'account_status' AS account_status,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    j.value ->> 'profile' AS profile,
    j.value ->> 'db' AS db,
    to_timestamp((j.value ->> 'time')::bigint / 3.0) AS time,
    to_timestamp((j.value ->> 'start_time')::bigint / 3.0) AS start_time,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-014-RC01';

DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_014_rc02;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_014_rc02
-- Root cause: SEC-SQL-AUD-014-RC02
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_014_rc02 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'usename',
        j.value ->> 'login_name',
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'grantee',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    COALESCE(
        j.value ->> 'client_addr',
        j.value ->> 'host'
    ) AS host,
    j.value ->> 'super_priv' AS super_priv,
    j.value ->> 'grant_priv' AS grant_priv,
    j.value ->> 'create_user_priv' AS create_user_priv,
    j.value ->> 'system_user_priv' AS system_user_priv,
    to_timestamp((j.value ->> 'granted_role')::bigint / 3.0) AS granted_role,
    j.value ->> 'admin_option' AS admin_option,
    j.value ->> 'default_role' AS default_role,
    COALESCE(
        j.value ->> 'pid',
        j.value ->> 'sid',
        j.value ->> 'id'
    ) AS session_id,
    j.value ->> 'db' AS db,
    to_timestamp((j.value ->> 'time')::bigint / 3.0) AS time,
    COALESCE(
        j.value ->> 'query',
        j.value ->> 'info',
        j.value ->> 'sql_text',
        j.value ->> 'text'
    ) AS query_text,
    to_timestamp((j.value ->> 'start_time')::bigint / 3.0) AS start_time,
    to_timestamp((j.value ->> 'last_active_time')::bigint / 3.0) AS last_active_time,
    j.value ->> 'rolname' AS rolname,
    to_timestamp((j.value ->> 'query_start')::bigint / 3.0) AS query_start,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-014-RC02';

DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_014_rc03;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_014_rc03
-- Root cause: SEC-SQL-AUD-014-RC03
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_014_rc03 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'usename',
        j.value ->> 'login_name',
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    COALESCE(
        j.value ->> 'client_addr',
        j.value ->> 'host'
    ) AS host,
    to_timestamp((j.value ->> 'password_changed_time')::bigint / 3.0) AS password_changed_time,
    j.value ->> 'plugin' AS plugin,
    j.value ->> 'account_locked' AS account_locked,
    j.value ->> 'passwd' AS passwd,
    j.value ->> 'valuntil' AS valuntil,
    COALESCE(
        j.value ->> 'pid',
        j.value ->> 'sid',
        j.value ->> 'id'
    ) AS session_id,
    COALESCE(
        j.value ->> 'query',
        j.value ->> 'info',
        j.value ->> 'sql_text',
        j.value ->> 'text'
    ) AS query_text,
    to_timestamp((j.value ->> 'query_start')::bigint / 3.0) AS query_start,
    to_timestamp((j.value ->> 'start_time')::bigint / 3.0) AS start_time,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'is_disabled' AS is_disabled,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    j.value ->> 'default_database_name' AS default_database_name,
    j.value ->> 'account_status' AS account_status,
    to_timestamp((j.value ->> 'expiry_date')::bigint / 3.0) AS expiry_date,
    to_timestamp((j.value ->> 'last_login')::bigint / 3.0) AS last_login,
    j.value ->> 'profile' AS profile,
    j.value ->> 'db' AS db,
    to_timestamp((j.value ->> 'time')::bigint / 3.0) AS time,
    to_timestamp((j.value ->> 'last_active_time')::bigint / 3.0) AS last_active_time,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-014-RC03';

DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_014_rc04;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_014_rc04
-- Root cause: SEC-SQL-AUD-014-RC04
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_014_rc04 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'usename',
        j.value ->> 'login_name',
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'owner',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'db_link' AS db_link,
    COALESCE(
        j.value ->> 'client_addr',
        j.value ->> 'host'
    ) AS host,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    COALESCE(
        j.value ->> 'pid',
        j.value ->> 'sid',
        j.value ->> 'id'
    ) AS session_id,
    j.value ->> 'db' AS db,
    to_timestamp((j.value ->> 'time')::bigint / 3.0) AS time_val,
    COALESCE(
        j.value ->> 'query',
        j.value ->> 'info',
        j.value ->> 'sql_text',
        j.value ->> 'text'
    ) AS query_text,
    j.value ->> 'data_source' AS data_source,
    j.value ->> 'provider' AS provider,
    j.value ->> 'catalog' AS catalog,
    j.value ->> 'is_linked' AS is_linked,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    j.value ->> 'srvname' AS srvname,
    j.value ->> 'srvowner' AS srvowner,
    j.value ->> 'umuser' AS umuser,
    j.value ->> 'srvoptions' AS srvoptions,
    j.value ->> 'table_schema' AS table_schema,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'engine' AS engine,
    to_timestamp((j.value ->> 'create_time')::bigint / 3.0) AS create_time,
    j.value ->> 'table_comment' AS table_comment,
    to_timestamp((j.value ->> 'last_active_time')::bigint / 3.0) AS last_active_time,
    to_timestamp((j.value ->> 'start_time')::bigint / 3.0) AS start_time,
    to_timestamp((j.value ->> 'query_start')::bigint / 3.0) AS query_start,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-014-RC04';

DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_014_rc05;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_014_rc05
-- Root cause: SEC-SQL-AUD-014-RC05
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_014_rc05 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'usename',
        j.value ->> 'login_name',
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    COALESCE(
        j.value ->> 'client_addr',
        j.value ->> 'host'
    ) AS host,
    j.value ->> 'account_locked' AS account_locked,
    to_timestamp((j.value ->> 'password_changed_time')::bigint / 3.0) AS password_changed_time,
    j.value ->> 'password_expired' AS password_expired,
    COALESCE(
        j.value ->> 'pid',
        j.value ->> 'sid',
        j.value ->> 'id'
    ) AS session_id,
    j.value ->> 'db' AS db,
    to_timestamp((j.value ->> 'time')::bigint / 3.0) AS time,
    COALESCE(
        j.value ->> 'query',
        j.value ->> 'info',
        j.value ->> 'sql_text',
        j.value ->> 'text'
    ) AS query_text,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolcanlogin' AS rolcanlogin,
    j.value ->> 'rolvaliduntil' AS rolvaliduntil,
    j.value ->> 'oid' AS oid,
    j.value ->> 'is_disabled' AS is_disabled,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'last_active_time')::bigint / 3.0) AS last_active_time,
    to_timestamp((j.value ->> 'query_start')::bigint / 3.0) AS query_start,
    to_timestamp((j.value ->> 'start_time')::bigint / 3.0) AS start_time,
    j.value ->> 'account_status' AS account_status,
    to_timestamp((j.value ->> 'expiry_date')::bigint / 3.0) AS expiry_date,
    to_timestamp((j.value ->> 'lock_date')::bigint / 3.0) AS lock_date,
    to_timestamp((j.value ->> 'last_login')::bigint / 3.0) AS last_login,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-014-RC05';

DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_015_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_015_rc01
-- Root cause: SEC-SQL-AUD-015-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_015_rc01 AS
SELECT
    r.server,
    to_timestamp((j.value ->> 'event_time')::bigint / 3.0) AS event_time,
    COALESCE(
        j.value ->> 'login_name',
        j.value ->> 'schema_name'
    ) AS username,
    j.value ->> 'database_name' AS db,
    j.value ->> 'null' AS null_val,
    j.value ->> 'action_id' AS action_id,
    j.value ->> 'action' AS action_val,
    j.value ->> 'change_kind' AS change_kind,
    COALESCE(
        j.value ->> 'sql_text',
        j.value ->> 'statement'
    ) AS query_text,
    j.value ->> 'setup_ok' AS setup_ok,
    j.value ->> 'enabled_server_audits' AS enabled_server_audits,
    j.value ->> 'enabled_server_specs' AS enabled_server_specs,
    j.value ->> 'dbdome_dml_pol' AS dbdome_dml_pol,
    j.value ->> 'dbdome_ddl_pol' AS dbdome_ddl_pol,
    j.value ->> 'unified_audit_trail' AS unified_audit_trail,
    j.value ->> 'error_message' AS error_message,
    j.value ->> 'col_1' AS col_1,
    j.value ->> 'dbusername' AS dbusername,
    j.value ->> 'object_schema' AS object_schema,
    j.value ->> 'object_name' AS object_name,
    j.value ->> 'action_name' AS action_name,
    j.value ->> 'client_program_name' AS client_program_name,
    j.value ->> 'event_time_at_time_zone__utc__at_time_zone__asia_jerusalem' AS event_time_at_time_zone__utc__at_time_zone__asia_jerusalem,
    j.value ->> 'client_ip' AS client_ip,
    j.value ->> 'application_name' AS application_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-015-RC01';

DROP VIEW IF EXISTS monitoring.v_sec_sql_az_001_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_az_001_rc01
-- Root cause: SEC-SQL-AZ-001-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_001_rc01 AS
SELECT
    r.server,
    j.value ->> 'role_grants' AS role_grants,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'grantee'
    ) AS username,
    j.value ->> 'usertype' AS usertype,
    j.value ->> 'direct_user_grants' AS direct_user_grants,
    j.value ->> 'total_grants' AS total_grants,
    j.value ->> 'host' AS host,
    j.value ->> 'super_users' AS super_users,
    j.value ->> 'direct_privs' AS direct_privs,
    j.value ->> 'direct_grants' AS direct_grants,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-001-RC01'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_az_001_rc08;

-- ============================================================
-- View: monitoring.v_sec_sql_az_001_rc08
-- Root cause: SEC-SQL-AZ-001-RC08
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_001_rc08 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'user'
    ) AS username,
    j.value ->> 'host' AS host,
    j.value ->> 'super_priv' AS super_priv,
    j.value ->> 'create_priv' AS create_priv,
    j.value ->> 'grant_priv' AS grant_priv,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolsuper' AS rolsuper,
    j.value ->> 'rolcreatedb' AS rolcreatedb,
    j.value ->> 'rolvaliduntil' AS rolvaliduntil,
    to_timestamp((j.value ->> 'password_last_changed')::bigint / 3.0) AS password_last_changed,
    j.value ->> 'days_since_change' AS days_since_change,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    j.value ->> 'account_status' AS account_status,
    to_timestamp((j.value ->> 'last_login')::bigint / 3.0) AS last_login,
    j.value ->> 'days_since_login' AS days_since_login,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-001-RC08'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_az_001_rc12;

-- ============================================================
-- View: monitoring.v_sec_sql_az_001_rc12
-- Root cause: SEC-SQL-AZ-001-RC12
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_001_rc12 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'grantee',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'host' AS host,
    j.value ->> 'authentication_string' AS authentication_string,
    j.value ->> 'profile' AS profile,
    j.value ->> 'resource_name' AS resource_name,
    j.value ->> 'limit' AS limit,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolsuper' AS rolsuper,
    j.value ->> 'rolcanlogin' AS rolcanlogin,
    j.value ->> 'rolvaliduntil' AS rolvaliduntil,
    j.value ->> 'rolconnlimit' AS rolconnlimit,
    j.value ->> 'current_value' AS current_value,
    j.value ->> 'hardened_value' AS hardened_value,
    j.value ->> 'status' AS state,
    j.value ->> 'account_status' AS account_status,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    j.value ->> 'authentication_type' AS authentication_type,
    j.value ->> 'privilege' AS privilege,
    j.value ->> 'test_db_exists' AS test_db_exists,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-001-RC12'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_az_001_rc13;

-- ============================================================
-- View: monitoring.v_sec_sql_az_001_rc13
-- Root cause: SEC-SQL-AZ-001-RC13
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_001_rc13 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'authentication_type' AS authentication_type,
    j.value ->> 'external_name' AS external_name,
    j.value ->> 'plugin' AS plugin,
    j.value ->> 'user_count' AS user_count,
    j.value ->> 'auth_method' AS auth_method,
    j.value ->> 'rule_count' AS rule_count,
    j.value ->> 'sql_logins' AS sql_logins,
    j.value ->> 'windows_logins' AS windows_logins,
    j.value ->> 'windows_groups' AS windows_groups,
    j.value ->> 'azure_ad_principals' AS azure_ad_principals,
    j.value ->> 'windows_only_auth' AS windows_only_auth,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    j.value ->> 'value' AS value,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-001-RC13';

DROP VIEW IF EXISTS monitoring.v_sec_sql_az_002_rc04;

-- ============================================================
-- View: monitoring.v_sec_sql_az_002_rc04
-- Root cause: SEC-SQL-AZ-002-RC04
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_002_rc04 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'compatibility_level' AS compatibility_level,
    j.value ->> 'compat_version' AS compat_version,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'nspname' AS nspname,
    j.value ->> 'proname' AS proname,
    j.value ->> 'proacl' AS proacl,
    COALESCE(
        j.value ->> 'db',
        j.value ->> 'database_name'
    ) AS db,
    j.value ->> 'host' AS host,
    j.value ->> 'select_priv' AS select_priv,
    j.value ->> 'insert_priv' AS insert_priv,
    j.value ->> 'update_priv' AS update_priv,
    j.value ->> 'delete_priv' AS delete_priv,
    j.value ->> 'create_priv' AS create_priv,
    j.value ->> 'drop_priv' AS drop_priv,
    j.value ->> 'permission_name' AS permission_name,
    j.value ->> 'class_desc' AS class_desc,
    j.value ->> 'object_name' AS object_name,
    j.value ->> 'grant_count' AS grant_count,
    to_timestamp((j.value ->> 'granted_role')::bigint / 3.0) AS granted_role,
    j.value ->> 'admin_option' AS admin_option,
    j.value ->> 'default_role' AS default_role,
    j.value ->> 'nspacl' AS nspacl,
    j.value ->> 'total_public_grants' AS total_public_grants,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-002-RC04'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_az_002_rc05;

-- ============================================================
-- View: monitoring.v_sec_sql_az_002_rc05
-- Root cause: SEC-SQL-AZ-002-RC05
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_002_rc05 AS
SELECT
    r.server,
    j.value ->> 'event_timestamp' AS event_timestamp,
    j.value ->> 'dbusername' AS dbusername,
    j.value ->> 'action_name' AS action_name,
    j.value ->> 'object_schema' AS object_schema,
    j.value ->> 'object_name' AS object_name,
    j.value ->> 'sql_text' AS query_text,
    j.value ->> 'policy_name' AS policy_name,
    j.value ->> 'audit_option' AS audit_option,
    COALESCE(
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'is_state_enabled' AS is_state_enabled,
    j.value ->> 'audit_action_name' AS audit_action_name,
    j.value ->> 'broad_grant_users' AS broad_grant_users,
    j.value ->> 'permission_name' AS permission_name,
    j.value ->> 'class_desc' AS class_desc,
    j.value ->> 'grant_count' AS grant_count,
    j.value ->> 'host' AS host,
    to_timestamp((j.value ->> 'password_last_changed')::bigint / 3.0) AS password_last_changed,
    j.value ->> 'schema_val' AS schema_val,
    j.value ->> 'nspname' AS nspname,
    j.value ->> 'nspacl' AS nspacl,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-002-RC05'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_az_002_rc06;

-- ============================================================
-- View: monitoring.v_sec_sql_az_002_rc06
-- Root cause: SEC-SQL-AZ-002-RC06
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_002_rc06 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'user',
        j.value ->> 'owner',
        j.value ->> 'schema_name'
    ) AS username,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'privilege' AS privilege,
    j.value ->> 'host' AS host,
    j.value ->> 'db' AS db,
    j.value ->> 'select_priv' AS select_priv,
    j.value ->> 'insert_priv' AS insert_priv,
    j.value ->> 'permission_name' AS permission_name,
    j.value ->> 'class_desc' AS class_desc,
    j.value ->> 'object_name' AS object_name,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'schemaname' AS schemaname,
    j.value ->> 'tablename' AS tablename,
    j.value ->> 'scope' AS scope,
    j.value ->> 'state_desc' AS state_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-002-RC06'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_az_003_rc04;

-- ============================================================
-- View: monitoring.v_sec_sql_az_003_rc04
-- Root cause: SEC-SQL-AZ-003-RC04
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_003_rc04 AS
SELECT
    r.server,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    j.value ->> 'name' AS username,
    j.value ->> 'value' AS value,
    j.value ->> 'plugin' AS plugin,
    j.value ->> 'user_count' AS user_count,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'authentication_type_desc' AS authentication_type_desc,
    j.value ->> 'auth_category' AS auth_category,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    j.value ->> 'database_name' AS db,
    j.value ->> 'auth_method' AS auth_method,
    j.value ->> 'rule_count' AS rule_count,
    j.value ->> 'sql_logins' AS sql_logins,
    j.value ->> 'windows_logins' AS windows_logins,
    j.value ->> 'windows_groups' AS windows_groups,
    j.value ->> 'total_logins' AS total_logins,
    j.value ->> 'pct_sql_auth' AS pct_sql_auth,
    j.value ->> 'authentication_type' AS authentication_type,
    j.value ->> 'local_login_roles' AS local_login_roles,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-003-RC04';

DROP VIEW IF EXISTS monitoring.v_sec_sql_az_003_rc07;

-- ============================================================
-- View: monitoring.v_sec_sql_az_003_rc07
-- Root cause: SEC-SQL-AZ-003-RC07
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_003_rc07 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'host' AS host,
    j.value ->> 'password_expired' AS password_expired,
    j.value ->> 'password_lifetime' AS password_lifetime,
    to_timestamp((j.value ->> 'password_last_changed')::bigint / 3.0) AS password_last_changed,
    j.value ->> 'days_since_change' AS days_since_change,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolvaliduntil' AS rolvaliduntil,
    j.value ->> 'rolcreatedb' AS rolcreatedb,
    j.value ->> 'rolcreaterole' AS rolcreaterole,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'account_age_days' AS account_age_days,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    j.value ->> 'days_until_expiration' AS days_until_expiration,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'account_status' AS account_status,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    to_timestamp((j.value ->> 'expiry_date')::bigint / 3.0) AS expiry_date,
    j.value ->> 'profile' AS profile,
    j.value ->> 'limit' AS limit,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-003-RC07'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_az_003_rc08;

-- ============================================================
-- View: monitoring.v_sec_sql_az_003_rc08
-- Root cause: SEC-SQL-AZ-003-RC08
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_003_rc08 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'usename',
        j.value ->> 'login_name',
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'source_hosts' AS source_hosts,
    j.value ->> 'current_conns' AS current_conns,
    j.value ->> 'distinct_machines' AS distinct_machines,
    j.value ->> 'distinct_programs' AS distinct_programs,
    j.value ->> 'current_sessions' AS current_sessions,
    j.value ->> 'total_sessions' AS total_sessions,
    j.value ->> 'distinct_hosts' AS distinct_hosts,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'distinct_sources' AS distinct_sources,
    j.value ->> 'source_ips' AS source_ips,
    j.value ->> 'host' AS host,
    j.value ->> 'select_priv' AS select_priv,
    j.value ->> 'insert_priv' AS insert_priv,
    j.value ->> 'super_priv' AS super_priv,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-003-RC08'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_az_003_rc10;

-- ============================================================
-- View: monitoring.v_sec_sql_az_003_rc10
-- Root cause: SEC-SQL-AZ-003-RC10
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_003_rc10 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'host' AS host,
    to_timestamp((j.value ->> 'password_last_changed')::bigint / 3.0) AS password_last_changed,
    j.value ->> 'password_age_days' AS password_age_days,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'account_age_days' AS account_age_days,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolvaliduntil' AS rolvaliduntil,
    j.value ->> 'description' AS description,
    j.value ->> 'account_status' AS account_status,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    to_timestamp((j.value ->> 'last_login')::bigint / 3.0) AS last_login,
    j.value ->> 'profile' AS profile,
    j.value ->> 'authentication_type' AS authentication_type,
    j.value ->> 'age_days' AS age_days,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-003-RC10'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_az_003_rc11;

-- ============================================================
-- View: monitoring.v_sec_sql_az_003_rc11
-- Root cause: SEC-SQL-AZ-003-RC11
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_003_rc11 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'schema_name',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'host' AS host,
    j.value ->> 'db' AS db,
    j.value ->> 'account_status' AS account_status,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    to_timestamp((j.value ->> 'last_login')::bigint / 3.0) AS last_login,
    j.value ->> 'profile' AS profile,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'sid' AS session_id,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-003-RC11'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_az_003_rc12;

-- ============================================================
-- View: monitoring.v_sec_sql_az_003_rc12
-- Root cause: SEC-SQL-AZ-003-RC12
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_003_rc12 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'grantee',
        j.value ->> 'name'
    ) AS username,
    to_timestamp((j.value ->> 'granted_role')::bigint / 3.0) AS granted_role,
    j.value ->> 'admin_option' AS admin_option,
    j.value ->> 'delegate_option' AS delegate_option,
    j.value ->> 'default_role' AS default_role,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    j.value ->> 'role_membership' AS role_membership,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolvaliduntil' AS rolvaliduntil,
    j.value ->> 'rolconnlimit' AS rolconnlimit,
    j.value ->> 'description' AS description,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-003-RC12';

DROP VIEW IF EXISTS monitoring.v_sec_sql_az_003_rc15;

-- ============================================================
-- View: monitoring.v_sec_sql_az_003_rc15
-- Root cause: SEC-SQL-AZ-003-RC15
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_003_rc15 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'schema_name',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'host' AS host,
    j.value ->> 'select_priv' AS select_priv,
    j.value ->> 'insert_priv' AS insert_priv,
    j.value ->> 'update_priv' AS update_priv,
    j.value ->> 'delete_priv' AS delete_priv,
    to_timestamp((j.value ->> 'password_last_changed')::bigint / 3.0) AS password_last_changed,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolvaliduntil' AS rolvaliduntil,
    j.value ->> 'account_status' AS account_status,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    to_timestamp((j.value ->> 'last_login')::bigint / 3.0) AS last_login,
    j.value ->> 'roles' AS roles,
    j.value ->> 'class_desc' AS class_desc,
    j.value ->> 'object_name' AS object_name,
    j.value ->> 'permission_name' AS permission_name,
    j.value ->> 'state_desc' AS state_desc,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-003-RC15'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_az_004_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_az_004_rc01
-- Root cause: SEC-SQL-AZ-004-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_004_rc01 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'user',
        j.value ->> 'grantee',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'permission_name' AS permission_name,
    j.value ->> 'state_desc' AS state_desc,
    j.value ->> 'object_name' AS object_name,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolsuper' AS rolsuper,
    j.value ->> 'roleid' AS roleid,
    j.value ->> 'host' AS host,
    j.value ->> 'file_priv' AS file_priv,
    j.value ->> 'privilege' AS privilege,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'is_enabled' AS is_enabled,
    j.value ->> 'description' AS description,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-004-RC01'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_az_004_rc03;

-- ============================================================
-- View: monitoring.v_sec_sql_az_004_rc03
-- Root cause: SEC-SQL-AZ-004-RC03
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_004_rc03 AS
SELECT
    r.server,
    j.value ->> 'directory_name' AS directory_name,
    j.value ->> 'directory_path' AS directory_path,
    COALESCE(
        j.value ->> 'user',
        j.value ->> 'grantee',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'privilege' AS privilege,
    COALESCE(
        j.value ->> 'host_name',
        j.value ->> 'host'
    ) AS host,
    j.value ->> 'file_priv' AS file_priv,
    j.value ->> 'select_priv' AS select_priv,
    j.value ->> 'db_access' AS db_access,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'program_name' AS application_name,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolsuper' AS rolsuper,
    to_timestamp((j.value ->> 'granted_roles')::bigint / 3.0) AS granted_roles,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-004-RC03';

DROP VIEW IF EXISTS monitoring.v_sec_sql_az_004_rc07;

-- ============================================================
-- View: monitoring.v_sec_sql_az_004_rc07
-- Root cause: SEC-SQL-AZ-004-RC07
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_004_rc07 AS
SELECT
    r.server,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'text' AS query_text,
    j.value ->> 'execution_count' AS execution_count,
    to_timestamp((j.value ->> 'last_execution_time')::bigint / 3.0) AS last_execution_time,
    COALESCE(
        j.value ->> 'user',
        j.value ->> 'grantee',
        j.value ->> 'owner',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'host' AS host,
    j.value ->> 'file_priv' AS file_priv,
    j.value ->> 'super_priv' AS super_priv,
    to_timestamp((j.value ->> 'password_last_changed')::bigint / 3.0) AS password_last_changed,
    j.value ->> 'is_enabled' AS is_enabled,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'privilege' AS privilege,
    j.value ->> 'grantor' AS grantor,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-004-RC07'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_az_004_rc08;

-- ============================================================
-- View: monitoring.v_sec_sql_az_004_rc08
-- Root cause: SEC-SQL-AZ-004-RC08
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_004_rc08 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'user',
        j.value ->> 'grantee',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'privilege' AS privilege,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'directory_path' AS directory_path,
    j.value ->> 'host' AS host,
    j.value ->> 'file_priv' AS file_priv,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolsuper' AS rolsuper,
    to_timestamp((j.value ->> 'granted_roles')::bigint / 3.0) AS granted_roles,
    j.value ->> 'product' AS product,
    j.value ->> 'provider' AS provider,
    j.value ->> 'data_source' AS data_source,
    j.value ->> 'is_data_access_enabled' AS is_data_access_enabled,
    j.value ->> 'is_rpc_out_enabled' AS is_rpc_out_enabled,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-004-RC08'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_az_004_rc09;

-- ============================================================
-- View: monitoring.v_sec_sql_az_004_rc09
-- Root cause: SEC-SQL-AZ-004-RC09
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_004_rc09 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'user',
        j.value ->> 'grantee',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'privilege' AS privilege,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'directory_val' AS directory_val,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'account_age_days' AS account_age_days,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolvaliduntil' AS rolvaliduntil,
    j.value ->> 'description' AS description,
    j.value ->> 'host' AS host,
    j.value ->> 'file_priv' AS file_priv,
    to_timestamp((j.value ->> 'password_last_changed')::bigint / 3.0) AS password_last_changed,
    j.value ->> 'password_age_days' AS password_age_days,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-004-RC09'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_az_004_rc10;

-- ============================================================
-- View: monitoring.v_sec_sql_az_004_rc10
-- Root cause: SEC-SQL-AZ-004-RC10
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_004_rc10 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'grantee',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'privilege' AS privilege,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    j.value ->> 'file_users' AS file_users,
    j.value ->> 'audit_option' AS audit_option,
    j.value ->> 'success' AS success,
    j.value ->> 'failure' AS failure,
    j.value ->> 'setting' AS setting,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-004-RC10';

DROP VIEW IF EXISTS monitoring.v_sec_sql_az_006_rc12;

-- ============================================================
-- View: monitoring.v_sec_sql_az_006_rc12
-- Root cause: SEC-SQL-AZ-006-RC12
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_006_rc12 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'grantee',
        j.value ->> 'owner'
    ) AS username,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'privilege' AS privilege,
    j.value ->> 'any_priv_count' AS any_priv_count,
    j.value ->> 'any_privileges' AS any_privileges,
    j.value ->> 'total_grantable' AS total_grantable,
    j.value ->> 'distinct_delegators' AS distinct_delegators,
    j.value ->> 'windows_auth_only' AS windows_auth_only,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-006-RC12';

DROP VIEW IF EXISTS monitoring.v_sec_sql_cfg_001_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_cfg_001_rc01
-- Root cause: SEC-SQL-CFG-001-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_001_rc01 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'schema_name',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'is_enabled' AS is_enabled,
    j.value ->> 'description' AS description,
    j.value ->> 'compatibility_level' AS compatibility_level,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'age_years' AS age_years,
    j.value ->> 'stored_procedure' AS stored_procedure,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-CFG-001-RC01';

DROP VIEW IF EXISTS monitoring.v_sec_sql_cfg_001_rc03;

-- ============================================================
-- View: monitoring.v_sec_sql_cfg_001_rc03
-- Root cause: SEC-SQL-CFG-001-RC03
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_001_rc03 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'grantee',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'enabled' AS enabled,
    j.value ->> 'privilege' AS privilege,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolsuper' AS rolsuper,
    j.value ->> 'value' AS value,
    j.value ->> 'isdefault' AS isdefault,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-CFG-001-RC03';

DROP VIEW IF EXISTS monitoring.v_sec_sql_cfg_001_rc04;

-- ============================================================
-- View: monitoring.v_sec_sql_cfg_001_rc04
-- Root cause: SEC-SQL-CFG-001-RC04
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_001_rc04 AS
SELECT
    r.server,
    j.value ->> 'name' AS username,
    j.value ->> 'value' AS value,
    j.value ->> 'isdefault' AS isdefault,
    j.value ->> 'ismodified' AS ismodified,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolsuper' AS rolsuper,
    j.value ->> 'configured_value' AS configured_value,
    j.value ->> 'runtime_value' AS runtime_value,
    j.value ->> 'drift_status' AS drift_status,
    j.value ->> 'policy_name' AS policy_name,
    j.value ->> 'audit_option' AS audit_option,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-CFG-001-RC04';

DROP VIEW IF EXISTS monitoring.v_sec_sql_cfg_001_rc05;

-- ============================================================
-- View: monitoring.v_sec_sql_cfg_001_rc05
-- Root cause: SEC-SQL-CFG-001-RC05
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_001_rc05 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'grantee',
        j.value ->> 'owner',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'auth_type' AS auth_type,
    j.value ->> 'days_until_expiration' AS days_until_expiration,
    j.value ->> 'xp_cmdshell_enabled' AS xp_cmdshell_enabled,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'admin_status' AS admin_status,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolsuper' AS rolsuper,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'privilege' AS privilege,
    j.value ->> 'type' AS state,
    j.value ->> 'line' AS line,
    j.value ->> 'text' AS query_text,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-CFG-001-RC05';

DROP VIEW IF EXISTS monitoring.v_sec_sql_cfg_001_rc06;

-- ============================================================
-- View: monitoring.v_sec_sql_cfg_001_rc06
-- Root cause: SEC-SQL-CFG-001-RC06
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_001_rc06 AS
SELECT
    r.server,
    j.value ->> 'servicename' AS servicename,
    j.value ->> 'service_account' AS service_account,
    j.value ->> 'status_desc' AS status_desc,
    j.value ->> 'privilege_assessment' AS privilege_assessment,
    j.value ->> 'xp_cmdshell_enabled' AS xp_cmdshell_enabled,
    j.value ->> 'server_name' AS server_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-CFG-001-RC06';

DROP VIEW IF EXISTS monitoring.v_sec_sql_cfg_001_rc08;

-- ============================================================
-- View: monitoring.v_sec_sql_cfg_001_rc08
-- Root cause: SEC-SQL-CFG-001-RC08
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_001_rc08 AS
SELECT
    r.server,
    j.value ->> 'xp_cmdshell_enabled' AS xp_cmdshell_enabled,
    j.value ->> 'name' AS username,
    j.value ->> 'value' AS value,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'member_count' AS member_count,
    j.value ->> 'usage_pattern' AS usage_pattern,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-CFG-001-RC08';

DROP VIEW IF EXISTS monitoring.v_sec_sql_cfg_001_rc11;

-- ============================================================
-- View: monitoring.v_sec_sql_cfg_001_rc11
-- Root cause: SEC-SQL-CFG-001-RC11
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_001_rc11 AS
SELECT
    r.server,
    j.value ->> 'xp_cmdshell_enabled' AS xp_cmdshell_enabled,
    COALESCE(
        j.value ->> 'owner',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'enabled' AS enabled,
    to_timestamp((j.value ->> 'date_created')::bigint / 3.0) AS date_created,
    to_timestamp((j.value ->> 'date_modified')::bigint / 3.0) AS date_modified,
    j.value ->> 'step_name' AS step_name,
    j.value ->> 'subsystem' AS subsystem,
    j.value ->> 'cmdshell_pattern' AS cmdshell_pattern,
    j.value ->> 'job_name' AS job_name,
    j.value ->> 'job_type' AS job_type,
    COALESCE(
        j.value ->> 'state',
        j.value ->> 'status',
        j.value ->> 'command'
    ) AS state,
    j.value ->> 'repeat_interval' AS repeat_interval,
    j.value ->> 'job_action' AS job_action,
    j.value ->> 'lanname' AS lanname,
    j.value ->> 'lanpltrusted' AS lanpltrusted,
    j.value ->> 'extname' AS extname,
    j.value ->> 'trigger_name' AS trigger_name,
    j.value ->> 'trigger_type' AS trigger_type,
    j.value ->> 'triggering_event' AS triggering_event,
    j.value ->> 'recency' AS recency,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-CFG-001-RC11';

DROP VIEW IF EXISTS monitoring.v_sec_sql_cfg_003_rc06;

-- ============================================================
-- View: monitoring.v_sec_sql_cfg_003_rc06
-- Root cause: SEC-SQL-CFG-003-RC06
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_003_rc06 AS
SELECT
    r.server,
    j.value ->> 'nspname' AS nspname,
    j.value ->> 'nspowner' AS nspowner,
    j.value ->> 'username' AS username,
    j.value ->> 'account_status' AS account_status,
    j.value ->> 'authentication_type' AS authentication_type,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-CFG-003-RC06';

DROP VIEW IF EXISTS monitoring.v_sec_sql_cfg_003_rc14;

-- ============================================================
-- View: monitoring.v_sec_sql_cfg_003_rc14
-- Root cause: SEC-SQL-CFG-003-RC14
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_003_rc14 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'user_access_desc' AS user_access_desc,
    j.value ->> 'is_db_chaining_on' AS is_db_chaining_on,
    j.value ->> 'is_trustworthy_on' AS is_trustworthy_on,
    j.value ->> 'common' AS common,
    j.value ->> 'account_status' AS account_status,
    j.value ->> 'authentication_type' AS authentication_type,
    j.value ->> 'user_db_count' AS user_db_count,
    j.value ->> 'datname' AS datname,
    j.value ->> 'numbackends' AS numbackends,
    j.value ->> 'stats_reset' AS stats_reset,
    j.value ->> 'datdba' AS datdba,
    j.value ->> 'table_schema' AS table_schema,
    to_timestamp((j.value ->> 'last_update')::bigint / 3.0) AS last_update,
    j.value ->> 'value' AS value_val,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-CFG-003-RC14';

DROP VIEW IF EXISTS monitoring.v_sec_sql_cfg_004_rc13;

-- ============================================================
-- View: monitoring.v_sec_sql_cfg_004_rc13
-- Root cause: SEC-SQL-CFG-004-RC13
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_004_rc13 AS
SELECT
    r.server,
    j.value ->> 'value_in_use' AS value_in_use,
    j.value ->> 'name' AS username,
    j.value ->> 'setting' AS setting,
    j.value ->> 'policy_name' AS policy_name,
    j.value ->> 'enabled_option' AS enabled_option,
    j.value ->> 'entity_name' AS entity_name,
    j.value ->> 'success' AS success,
    j.value ->> 'failure' AS failure,
    j.value ->> 'parameter' AS parameter,
    j.value ->> 'value' AS value,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-CFG-004-RC13';

DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_001_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_001_rc01
-- Root cause: SEC-SQL-ENC-001-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_001_rc01 AS
SELECT
    r.server,
    j.value ->> 'unencrypted_connections' AS unencrypted_connections,
    j.value ->> 'encrypt_option' AS encrypt_option,
    j.value ->> 'connection_count' AS connection_count,
    j.value ->> 'pct' AS pct,
    j.value ->> 'name' AS username,
    j.value ->> 'setting' AS setting,
    j.value ->> 'cf_name' AS cf_name,
    j.value ->> 'cf_effective' AS cf_effective,
    j.value ->> 'value' AS value,
    j.value ->> 'network_service_banner' AS network_service_banner,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-001-RC01';

DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_001_rc10;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_001_rc10
-- Root cause: SEC-SQL-ENC-001-RC10
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_001_rc10 AS
SELECT
    r.server,
    j.value ->> 'unencrypted_connections' AS unencrypted_connections,
    j.value ->> 'name' AS username,
    j.value ->> 'value' AS value,
    j.value ->> 'type' AS state,
    j.value ->> 'rule_count' AS rule_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-001-RC10';

DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_001_rc11;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_001_rc11
-- Root cause: SEC-SQL-ENC-001-RC11
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_001_rc11 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'application_name',
        j.value ->> 'program_name',
        j.value ->> 'program'
    ) AS application_name,
    COALESCE(
        j.value ->> 'client_addr',
        j.value ->> 'host_name',
        j.value ->> 'machine'
    ) AS host,
    j.value ->> 'login_name' AS username,
    j.value ->> 'encrypt_option' AS encrypt_option,
    j.value ->> 'auth_scheme' AS auth_scheme,
    j.value ->> 'connection_count' AS connection_count,
    j.value ->> 'encrypted_count' AS encrypted_count,
    j.value ->> 'unencrypted_count' AS unencrypted_count,
    j.value ->> 'variable_name' AS variable_name,
    j.value ->> 'variable_value' AS variable_value,
    j.value ->> 'connection_type' AS connection_type,
    j.value ->> 'conn_count' AS conn_count,
    j.value ->> 'session_count' AS session_count,
    j.value ->> 'encryption_info' AS encryption_info,
    j.value ->> 'ssl' AS ssl,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-001-RC11';

DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_001_rc12;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_001_rc12
-- Root cause: SEC-SQL-ENC-001-RC12
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_001_rc12 AS
SELECT
    r.server,
    j.value ->> 'require_secure_transport' AS require_secure_transport,
    j.value ->> 'no_ssl_users' AS no_ssl_users,
    j.value ->> 'name' AS username,
    j.value ->> 'value' AS value_val,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-001-RC12';

DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_001_rc13;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_001_rc13
-- Root cause: SEC-SQL-ENC-001-RC13
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_001_rc13 AS
SELECT
    r.server,
    j.value ->> 'name' AS username,
    j.value ->> 'is_state_enabled' AS is_state_enabled,
    j.value ->> 'audit_action_name' AS audit_action_name,
    j.value ->> 'class_desc' AS class_desc,
    j.value ->> 'unencrypted_connections' AS unencrypted_connections,
    j.value ->> 'setting' AS setting,
    j.value ->> 'require_secure_transport' AS require_secure_transport,
    j.value ->> 'total' AS total,
    j.value ->> 'encrypted' AS encrypted,
    j.value ->> 'plaintext' AS plaintext,
    j.value ->> 'policy_name' AS policy_name,
    j.value ->> 'audit_condition' AS audit_condition,
    j.value ->> 'trigger_name' AS trigger_name,
    j.value ->> 'trigger_type' AS trigger_type,
    j.value ->> 'triggering_event' AS triggering_event,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-001-RC13';

DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_002_rc06;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_002_rc06
-- Root cause: SEC-SQL-ENC-002-RC06
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_002_rc06 AS
SELECT
    r.server,
    j.value ->> 'name' AS username,
    j.value ->> 'setting' AS setting,
    j.value ->> 'check__etc_crypto_policies_state_current_on_rhel_centos' AS check__etc_crypto_policies_state_current_on_rhel_centos,
    j.value ->> 'cnf_for_minprotocol' AS cnf_for_minprotocol,
    j.value ->> 'value' AS value_val,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-002-RC06';

DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_003_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_003_rc01
-- Root cause: SEC-SQL-ENC-003-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_003_rc01 AS
SELECT
    r.server,
    j.value ->> 'name' AS username,
    j.value ->> 'database_id' AS database_id,
    j.value ->> 'is_encrypted' AS is_encrypted,
    j.value ->> 'state_desc' AS state_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'encrypted_count' AS encrypted_count,
    j.value ->> 'encryption_state' AS encryption_state,
    j.value ->> 'encryption_state_desc' AS encryption_state_desc,
    j.value ->> 'key_algorithm' AS key_algorithm,
    j.value ->> 'key_length' AS key_length,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    j.value ->> 'tablespace_name' AS tablespace_name,
    j.value ->> 'encrypted' AS encrypted,
    j.value ->> 'setting' AS setting,
    j.value ->> 'extname' AS extname,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'column_name' AS column_name,
    j.value ->> 'encryption_alg' AS encryption_alg,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-003-RC01';

DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_003_rc02;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_003_rc02
-- Root cause: SEC-SQL-ENC-003-RC02
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_003_rc02 AS
SELECT
    r.server,
    j.value ->> 'banner' AS banner,
    j.value ->> 'name' AS username,
    j.value ->> 'is_encrypted' AS is_encrypted,
    j.value ->> 'encrypted_count' AS encrypted_count,
    j.value ->> 'comp_name' AS comp_name,
    j.value ->> 'status' AS state,
    j.value ->> 'version' AS version,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-003-RC02';

DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_003_rc03;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_003_rc03
-- Root cause: SEC-SQL-ENC-003-RC03
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_003_rc03 AS
SELECT
    r.server,
    j.value ->> 'unencrypted_db_count' AS unencrypted_db_count,
    j.value ->> 'name' AS username,
    j.value ->> 'detected_usages' AS detected_usages,
    j.value ->> 'currently_used' AS currently_used,
    to_timestamp((j.value ->> 'first_usage_date')::bigint / 3.0) AS first_usage_date,
    to_timestamp((j.value ->> 'last_usage_date')::bigint / 3.0) AS last_usage_date,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-003-RC03';

DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_003_rc04;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_003_rc04
-- Root cause: SEC-SQL-ENC-003-RC04
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_003_rc04 AS
SELECT
    r.server,
    j.value ->> 'wrl_type' AS wrl_type,
    j.value ->> 'wrl_parameter' AS wrl_parameter,
    j.value ->> 'status' AS state,
    j.value ->> 'wallet_type' AS wallet_type,
    j.value ->> 'keystore_mode' AS keystore_mode,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    j.value ->> 'plugin_type' AS plugin_type,
    j.value ->> 'extname' AS extname,
    j.value ->> 'name' AS username,
    j.value ->> 'is_encrypted' AS is_encrypted,
    j.value ->> 'encryption_state' AS encryption_state,
    j.value ->> 'setting' AS setting,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-003-RC04';

DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_003_rc10;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_003_rc10
-- Root cause: SEC-SQL-ENC-003-RC10
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_003_rc10 AS
SELECT
    r.server,
    j.value ->> 'tablespace_name' AS tablespace_name,
    j.value ->> 'encrypted' AS encrypted,
    j.value ->> 'contents' AS contents,
    j.value ->> 'status' AS state,
    j.value ->> 'encrypted_count' AS encrypted_count,
    j.value ->> 'user_objects_mb' AS user_objects_mb,
    j.value ->> 'internal_objects_mb' AS internal_objects_mb,
    j.value ->> 'version_store_mb' AS version_store_mb,
    j.value ->> 'free_mb' AS free_mb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-003-RC10';

DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_003_rc15;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_003_rc15
-- Root cause: SEC-SQL-ENC-003-RC15
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_003_rc15 AS
SELECT
    r.server,
    j.value ->> 'tablespace_name' AS tablespace_name,
    j.value ->> 'encrypted' AS encrypted,
    j.value ->> 'name' AS username,
    j.value ->> 'default_version' AS default_version,
    j.value ->> 'encryption_state' AS encryption_state,
    j.value ->> 'state_desc' AS state_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'key_algorithm' AS key_algorithm,
    j.value ->> 'key_length' AS key_length,
    j.value ->> 'wrl_type' AS wrl_type,
    j.value ->> 'wrl_parameter' AS wrl_parameter,
    j.value ->> 'status' AS state,
    j.value ->> 'wallet_type' AS wallet_type,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-003-RC15';

DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_003_rc16;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_003_rc16
-- Root cause: SEC-SQL-ENC-003-RC16
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_003_rc16 AS
SELECT
    r.server,
    j.value ->> 'name' AS username,
    j.value ->> 'subject' AS subject,
    to_timestamp((j.value ->> 'start_date')::bigint / 3.0) AS start_date,
    to_timestamp((j.value ->> 'expiry_date')::bigint / 3.0) AS expiry_date,
    j.value ->> 'pvt_key_encryption_type_desc' AS pvt_key_encryption_type_desc,
    j.value ->> 'days_expired' AS days_expired,
    j.value ->> 'setting' AS setting,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    j.value ->> 'wrl_type' AS wrl_type,
    j.value ->> 'wrl_parameter' AS wrl_parameter,
    j.value ->> 'status' AS state,
    j.value ->> 'wallet_type' AS wallet_type,
    j.value ->> 'wallet_order' AS wallet_order,
    j.value ->> 'key_id' AS key_id,
    to_timestamp((j.value ->> 'activation_time')::bigint / 3.0) AS activation_time,
    j.value ->> 'backed_up' AS backed_up,
    j.value ->> 'creator_dbname' AS creator_dbname,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-003-RC16';

DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_004_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_004_rc01
-- Root cause: SEC-SQL-ENC-004-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_004_rc01 AS
SELECT
    r.server,
    j.value ->> 'name' AS username,
    j.value ->> 'setting' AS setting,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    j.value ->> 'conf' AS conf,
    j.value ->> 'value' AS value_val,
    j.value ->> 'database_name' AS db,
    to_timestamp((j.value ->> 'backup_start_date')::bigint / 3.0) AS backup_start_date,
    COALESCE(
        j.value ->> 'status',
        j.value ->> 'type'
    ) AS state_val,
    j.value ->> 'compressed_backup_size___1024___1024' AS compressed_backup_size___1024___1024,
    j.value ->> 'encryption_status' AS encryption_status,
    j.value ->> 'key_algorithm' AS key_algorithm,
    j.value ->> 'encryptor_type' AS encryptor_type,
    j.value ->> 'is_encrypted' AS is_encrypted,
    j.value ->> 'input_type' AS input_type,
    to_timestamp((j.value ->> 'start_time')::bigint / 3.0) AS start_time,
    j.value ->> 'output_bytes_display' AS output_bytes_display,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-004-RC01';

DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_004_rc06;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_004_rc06
-- Root cause: SEC-SQL-ENC-004-RC06
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_004_rc06 AS
SELECT
    r.server,
    j.value ->> 'name' AS username,
    j.value ->> 'limit_gb' AS limit_gb,
    j.value ->> 'used_gb' AS used_gb,
    j.value ->> 'setting' AS setting,
    j.value ->> 'database_name' AS db,
    to_timestamp((j.value ->> 'backup_start_date')::bigint / 3.0) AS backup_start_date,
    j.value ->> 'type' AS state_val,
    j.value ->> 'compressed_backup_size___1024___1024' AS compressed_backup_size___1024___1024,
    j.value ->> 'encryption_status' AS encryption_status,
    j.value ->> 'key_algorithm' AS key_algorithm,
    j.value ->> 'encryptor_type' AS encryptor_type,
    j.value ->> 'is_encrypted' AS is_encrypted,
    j.value ->> 'conf' AS conf,
    j.value ->> 'value' AS value_val,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-004-RC06';

DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_004_rc08;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_004_rc08
-- Root cause: SEC-SQL-ENC-004-RC08
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_004_rc08 AS
SELECT
    r.server,
    j.value ->> 'conf' AS conf,
    j.value ->> 'name' AS username,
    j.value ->> 'value' AS value_val,
    j.value ->> 'database_name' AS db,
    to_timestamp((j.value ->> 'backup_start_date')::bigint / 3.0) AS backup_start_date,
    j.value ->> 'type' AS state_val,
    j.value ->> 'compressed_backup_size___1024___1024' AS compressed_backup_size___1024___1024,
    j.value ->> 'encryption_status' AS encryption_status,
    j.value ->> 'key_algorithm' AS key_algorithm,
    j.value ->> 'encryptor_type' AS encryptor_type,
    j.value ->> 'is_encrypted' AS is_encrypted,
    j.value ->> 'setting' AS setting,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-004-RC08';

DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_004_rc10;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_004_rc10
-- Root cause: SEC-SQL-ENC-004-RC10
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_004_rc10 AS
SELECT
    r.server,
    j.value ->> 'name' AS username,
    j.value ->> 'setting' AS setting,
    j.value ->> 'key_id' AS key_id,
    to_timestamp((j.value ->> 'activation_time')::bigint / 3.0) AS activation_time,
    j.value ->> 'key_age_days' AS key_age_days,
    j.value ->> 'backed_up' AS backed_up,
    j.value ->> 'creator_dbname' AS creator_dbname,
    j.value ->> 'database_name' AS db,
    to_timestamp((j.value ->> 'backup_start_date')::bigint / 3.0) AS backup_start_date,
    j.value ->> 'type' AS state_val,
    j.value ->> 'compressed_backup_size___1024___1024' AS compressed_backup_size___1024___1024,
    j.value ->> 'encryption_status' AS encryption_status,
    j.value ->> 'key_algorithm' AS key_algorithm,
    j.value ->> 'encryptor_type' AS encryptor_type,
    j.value ->> 'is_encrypted' AS is_encrypted,
    j.value ->> 'extname' AS extname,
    to_timestamp((j.value ->> 'expiry_date')::bigint / 3.0) AS expiry_date,
    j.value ->> 'days_until_expiry' AS days_until_expiry,
    j.value ->> 'pvt_key_encryption_type_desc' AS pvt_key_encryption_type_desc,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-004-RC10';

DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_004_rc11;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_004_rc11
-- Root cause: SEC-SQL-ENC-004-RC11
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_004_rc11 AS
SELECT
    r.server,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    j.value ->> 'tde_wallet' AS tde_wallet,
    j.value ->> 'setting' AS setting,
    j.value ->> 'encrypted_tablespaces' AS encrypted_tablespaces,
    j.value ->> 'database_name' AS db,
    to_timestamp((j.value ->> 'backup_start_date')::bigint / 3.0) AS backup_start_date,
    j.value ->> 'type' AS state_val,
    j.value ->> 'compressed_backup_size___1024___1024' AS compressed_backup_size___1024___1024,
    j.value ->> 'encryption_status' AS encryption_status,
    j.value ->> 'key_algorithm' AS key_algorithm,
    j.value ->> 'encryptor_type' AS encryptor_type,
    j.value ->> 'is_encrypted' AS is_encrypted,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-004-RC11';

DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_004_rc13;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_004_rc13
-- Root cause: SEC-SQL-ENC-004-RC13
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_004_rc13 AS
SELECT
    r.server,
    j.value ->> 'device_type' AS device_type,
    to_timestamp((j.value ->> 'completion_time')::bigint / 3.0) AS completion_time,
    j.value ->> 'encrypted' AS encrypted,
    COALESCE(
        j.value ->> 'status',
        j.value ->> 'type'
    ) AS state_val,
    j.value ->> 'conf' AS conf,
    j.value ->> 'name' AS username,
    j.value ->> 'value' AS value_val,
    j.value ->> 'database_name' AS db,
    to_timestamp((j.value ->> 'backup_start_date')::bigint / 3.0) AS backup_start_date,
    j.value ->> 'compressed_backup_size___1024___1024' AS compressed_backup_size___1024___1024,
    j.value ->> 'encryption_status' AS encryption_status,
    j.value ->> 'key_algorithm' AS key_algorithm,
    j.value ->> 'encryptor_type' AS encryptor_type,
    j.value ->> 'is_encrypted' AS is_encrypted,
    j.value ->> 'setting' AS setting,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-004-RC13';

DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_004_rc15;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_004_rc15
-- Root cause: SEC-SQL-ENC-004-RC15
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_004_rc15 AS
SELECT
    r.server,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'datname' AS datname,
    j.value ->> 'database_name' AS db,
    to_timestamp((j.value ->> 'backup_start_date')::bigint / 3.0) AS backup_start_date,
    COALESCE(
        j.value ->> 'status',
        j.value ->> 'type'
    ) AS state_val,
    j.value ->> 'compressed_backup_size___1024___1024' AS compressed_backup_size___1024___1024,
    j.value ->> 'encryption_status' AS encryption_status,
    j.value ->> 'key_algorithm' AS key_algorithm,
    j.value ->> 'encryptor_type' AS encryptor_type,
    j.value ->> 'is_encrypted' AS is_encrypted,
    j.value ->> 'owner' AS username,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'column_name' AS column_name,
    j.value ->> 'encryption_alg' AS encryption_alg,
    j.value ->> 'salt' AS salt,
    j.value ->> 'wrl_type' AS wrl_type,
    j.value ->> 'wrl_parameter' AS wrl_parameter,
    j.value ->> 'wallet_type' AS wallet_type,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-004-RC15';

DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_004_rc16;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_004_rc16
-- Root cause: SEC-SQL-ENC-004-RC16
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_004_rc16 AS
SELECT
    r.server,
    j.value ->> 'name' AS username,
    j.value ->> 'setting' AS setting,
    j.value ->> 'conf' AS conf,
    j.value ->> 'value' AS value_val,
    j.value ->> 'step_name' AS step_name,
    COALESCE(
        j.value ->> 'command',
        j.value ->> 'type'
    ) AS state_val,
    to_timestamp((j.value ->> 'date_created')::bigint / 3.0) AS date_created,
    to_timestamp((j.value ->> 'date_modified')::bigint / 3.0) AS date_modified,
    j.value ->> 'database_name' AS db,
    to_timestamp((j.value ->> 'backup_start_date')::bigint / 3.0) AS backup_start_date,
    j.value ->> 'compressed_backup_size___1024___1024' AS compressed_backup_size___1024___1024,
    j.value ->> 'encryption_status' AS encryption_status,
    j.value ->> 'key_algorithm' AS key_algorithm,
    j.value ->> 'encryptor_type' AS encryptor_type,
    j.value ->> 'is_encrypted' AS is_encrypted,
    j.value ->> 'total_backups' AS total_backups,
    j.value ->> 'unencrypted' AS unencrypted,
    j.value ->> 'encrypted' AS encrypted,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-004-RC16';

DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_005_rc03;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_005_rc03
-- Root cause: SEC-SQL-ENC-005-RC03
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_005_rc03 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'host' AS host,
    j.value ->> 'plugin' AS plugin,
    j.value ->> 'setting' AS setting,
    j.value ->> 'algorithm_desc' AS algorithm_desc,
    j.value ->> 'key_length' AS key_length,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'password_versions' AS password_versions,
    j.value ->> 'tablespace_name' AS tablespace_name,
    j.value ->> 'encrypted' AS encrypted,
    j.value ->> 'database_name' AS db,
    to_timestamp((j.value ->> 'backup_start_date')::bigint / 3.0) AS backup_start_date,
    j.value ->> 'type' AS state_val,
    j.value ->> 'compressed_backup_size___1024___1024' AS compressed_backup_size___1024___1024,
    j.value ->> 'encryption_status' AS encryption_status,
    j.value ->> 'key_algorithm' AS key_algorithm,
    j.value ->> 'encryptor_type' AS encryptor_type,
    j.value ->> 'is_encrypted' AS is_encrypted,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-005-RC03'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_005_rc13;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_005_rc13
-- Root cause: SEC-SQL-ENC-005-RC13
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_005_rc13 AS
SELECT
    r.server,
    j.value ->> 'wrl_type' AS wrl_type,
    j.value ->> 'status' AS state,
    j.value ->> 'wallet_type' AS wallet_type,
    j.value ->> 'keystore_mode' AS keystore_mode,
    j.value ->> 'name' AS username,
    j.value ->> 'setting' AS setting,
    j.value ->> 'algorithm_desc' AS algorithm_desc,
    j.value ->> 'key_length' AS key_length,
    j.value ->> 'pvt_key_encryption_type_desc' AS pvt_key_encryption_type_desc,
    j.value ->> 'strength_assessment' AS strength_assessment,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-005-RC13';

DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_005_rc14;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_005_rc14
-- Root cause: SEC-SQL-ENC-005-RC14
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_005_rc14 AS
SELECT
    r.server,
    j.value ->> 'name' AS username,
    j.value ->> 'setting' AS setting,
    j.value ->> 'event_name' AS event_name,
    j.value ->> 'cipher_count' AS cipher_count,
    j.value ->> 'ssl_connections' AS ssl_connections,
    j.value ->> 'encrypted_connections' AS encrypted_connections,
    j.value ->> 'extname' AS extname,
    j.value ->> 'is_state_enabled' AS is_state_enabled,
    j.value ->> 'audit_action_name' AS audit_action_name,
    j.value ->> 'class_desc' AS class_desc,
    j.value ->> 'policy_name' AS policy_name,
    j.value ->> 'audit_option' AS audit_option,
    j.value ->> 'network_service_banner' AS network_service_banner,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-005-RC14';

DROP VIEW IF EXISTS monitoring.v_sec_sql_inj_001_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_inj_001_rc01
-- Root cause: SEC-SQL-INJ-001-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_001_rc01 AS
SELECT
    r.server,
    j.value ->> 'routine_schema' AS routine_schema,
    j.value ->> 'routine_name' AS routine_name,
    COALESCE(
        j.value ->> 'owner',
        j.value ->> 'schema_name',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'type' AS state,
    j.value ->> 'line' AS line,
    j.value ->> 'text' AS query_text,
    j.value ->> 'routine_type' AS routine_type,
    j.value ->> 'proc_name' AS proc_name,
    j.value ->> 'definition_length' AS definition_length,
    j.value ->> 'object_id' AS object_id,
    j.value ->> 'nspname' AS nspname,
    j.value ->> 'proname' AS proname,
    j.value ->> 'function_def' AS function_def,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-INJ-001-RC01';

DROP VIEW IF EXISTS monitoring.v_sec_sql_inj_001_rc04;

-- ============================================================
-- View: monitoring.v_sec_sql_inj_001_rc04
-- Root cause: SEC-SQL-INJ-001-RC04
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_001_rc04 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'owner',
        j.value ->> 'schema_name'
    ) AS username,
    j.value ->> 'object_name' AS object_name,
    j.value ->> 'object_type' AS object_type,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    to_timestamp((j.value ->> 'last_ddl_time')::bigint / 3.0) AS last_ddl_time,
    j.value ->> 'age_days' AS age_days,
    j.value ->> 'routine_schema' AS routine_schema,
    j.value ->> 'routine_name' AS routine_name,
    to_timestamp((j.value ->> 'last_altered')::bigint / 3.0) AS last_altered,
    j.value ->> 'nspname' AS nspname,
    j.value ->> 'proname' AS proname,
    j.value ->> 'lanname' AS lanname,
    j.value ->> 'proc_name' AS proc_name,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    j.value ->> 'age_years' AS age_years,
    j.value ->> 'parameterization_status' AS parameterization_status,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-INJ-001-RC04';

DROP VIEW IF EXISTS monitoring.v_sec_sql_inj_001_rc07;

-- ============================================================
-- View: monitoring.v_sec_sql_inj_001_rc07
-- Root cause: SEC-SQL-INJ-001-RC07
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_001_rc07 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'owner',
        j.value ->> 'schema_name',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'type' AS state,
    j.value ->> 'line' AS line,
    j.value ->> 'text' AS query_text,
    j.value ->> 'nspname' AS nspname,
    j.value ->> 'proname' AS proname,
    j.value ->> 'routine_schema' AS routine_schema,
    j.value ->> 'routine_name' AS routine_name,
    j.value ->> 'proc_name' AS proc_name,
    j.value ->> 'has_exec_concat' AS has_exec_concat,
    j.value ->> 'mixed_pattern_count' AS mixed_pattern_count,
    j.value ->> 'unprotected_mixed_count' AS unprotected_mixed_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-INJ-001-RC07';

DROP VIEW IF EXISTS monitoring.v_sec_sql_inj_001_rc08;

-- ============================================================
-- View: monitoring.v_sec_sql_inj_001_rc08
-- Root cause: SEC-SQL-INJ-001-RC08
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_001_rc08 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'owner',
        j.value ->> 'schema_name',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'type' AS state,
    j.value ->> 'dynamic_sql_lines' AS dynamic_sql_lines,
    j.value ->> 'nspname' AS nspname,
    j.value ->> 'proname' AS proname,
    j.value ->> 'proc_name' AS proc_name,
    j.value ->> 'definition_length' AS definition_length,
    j.value ->> 'approx_concat_count' AS approx_concat_count,
    j.value ->> 'approx_if_count' AS approx_if_count,
    j.value ->> 'routine_schema' AS routine_schema,
    j.value ->> 'routine_name' AS routine_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-INJ-001-RC08';

DROP VIEW IF EXISTS monitoring.v_sec_sql_inj_001_rc10;

-- ============================================================
-- View: monitoring.v_sec_sql_inj_001_rc10
-- Root cause: SEC-SQL-INJ-001-RC10
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_001_rc10 AS
SELECT
    r.server,
    j.value ->> 'query_hash' AS query_hash,
    j.value ->> 'plan_count' AS plan_count,
    j.value ->> 'sample_query' AS sample_query,
    j.value ->> 'nspname' AS nspname,
    j.value ->> 'proname' AS proname,
    j.value ->> 'adhoc_plans' AS adhoc_plans,
    j.value ->> 'prepared_plans' AS prepared_plans,
    j.value ->> 'proc_plans' AS proc_plans,
    j.value ->> 'total_plans' AS total_plans,
    j.value ->> 'adhoc_pct' AS adhoc_pct,
    j.value ->> 'total_cursors' AS total_cursors,
    j.value ->> 'distinct_patterns' AS distinct_patterns,
    j.value ->> 'avg_versions' AS avg_versions,
    j.value ->> 'name' AS username,
    j.value ->> 'value' AS value,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-INJ-001-RC10';

DROP VIEW IF EXISTS monitoring.v_sec_sql_inj_001_rc15;

-- ============================================================
-- View: monitoring.v_sec_sql_inj_001_rc15
-- Root cause: SEC-SQL-INJ-001-RC15
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_001_rc15 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'owner',
        j.value ->> 'schema_name',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'type' AS state,
    j.value ->> 'line' AS line,
    j.value ->> 'text' AS query_text,
    j.value ->> 'proc_name' AS proc_name,
    j.value ->> 'object_id' AS object_id,
    j.value ->> 'routine_schema' AS routine_schema,
    j.value ->> 'routine_name' AS routine_name,
    j.value ->> 'has_quotename' AS has_quotename,
    j.value ->> 'definition_length' AS definition_length,
    j.value ->> 'nspname' AS nspname,
    j.value ->> 'proname' AS proname,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-INJ-001-RC15';

DROP VIEW IF EXISTS monitoring.v_sec_sql_inj_002_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_inj_002_rc01
-- Root cause: SEC-SQL-INJ-002-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc01 AS
SELECT
    r.server,
    j.value ->> 'xproc_name' AS xproc_name,
    j.value ->> 'execution_count' AS execution_count,
    to_timestamp((j.value ->> 'last_execution_time')::bigint / 3.0) AS last_execution_time,
    to_timestamp((j.value ->> 'days_since_last_exec')::bigint / 3.0) AS days_since_last_exec,
    COALESCE(
        j.value ->> 'schema_name',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-INJ-002-RC01';

DROP VIEW IF EXISTS monitoring.v_sec_sql_inj_002_rc02;

-- ============================================================
-- View: monitoring.v_sec_sql_inj_002_rc02
-- Root cause: SEC-SQL-INJ-002-RC02
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc02 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'owner',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'object_name' AS object_name,
    j.value ->> 'object_type' AS object_type,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    to_timestamp((j.value ->> 'last_ddl_time')::bigint / 3.0) AS last_ddl_time,
    j.value ->> 'age_days' AS age_days,
    j.value ->> 'nspname' AS nspname,
    j.value ->> 'proname' AS proname,
    j.value ->> 'lanname' AS lanname,
    j.value ->> 'prosecdef' AS prosecdef,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'is_enabled' AS is_enabled,
    j.value ->> 'compatibility_level' AS compatibility_level,
    j.value ->> 'compat_version' AS compat_version,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-INJ-002-RC02';

DROP VIEW IF EXISTS monitoring.v_sec_sql_inj_002_rc06;

-- ============================================================
-- View: monitoring.v_sec_sql_inj_002_rc06
-- Root cause: SEC-SQL-INJ-002-RC06
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc06 AS
SELECT
    r.server,
    j.value ->> 'event_schema' AS event_schema,
    j.value ->> 'event_name' AS event_name,
    j.value ->> 'event_definition' AS event_definition,
    j.value ->> 'routine_schema' AS routine_schema,
    j.value ->> 'routine_name' AS routine_name,
    COALESCE(
        j.value ->> 'owner',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'job_name' AS job_name,
    j.value ->> 'job_type' AS job_type,
    j.value ->> 'job_action' AS job_action,
    j.value ->> 'enabled' AS enabled,
    COALESCE(
        j.value ->> 'state',
        j.value ->> 'command'
    ) AS state,
    to_timestamp((j.value ->> 'last_start_date')::bigint / 3.0) AS last_start_date,
    to_timestamp((j.value ->> 'next_run_date')::bigint / 3.0) AS next_run_date,
    j.value ->> 'nspname' AS nspname,
    j.value ->> 'proname' AS proname,
    j.value ->> 'lanname' AS lanname,
    j.value ->> 'step_name' AS step_name,
    j.value ->> 'subsystem' AS subsystem,
    j.value ->> 'xproc_used' AS xproc_used,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-INJ-002-RC06';

DROP VIEW IF EXISTS monitoring.v_sec_sql_inj_002_rc07;

-- ============================================================
-- View: monitoring.v_sec_sql_inj_002_rc07
-- Root cause: SEC-SQL-INJ-002-RC07
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc07 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'user',
        j.value ->> 'grantee',
        j.value ->> 'owner',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'host' AS host,
    j.value ->> 'super_priv' AS super_priv,
    j.value ->> 'credential_id' AS credential_id,
    j.value ->> 'credential_identity' AS credential_identity,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'file_priv' AS file_priv,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'permission_name' AS permission_name,
    j.value ->> 'state_desc' AS state_desc,
    j.value ->> 'xproc_name' AS xproc_name,
    j.value ->> 'privilege' AS privilege,
    j.value ->> 'nspname' AS nspname,
    j.value ->> 'proname' AS proname,
    j.value ->> 'lanname' AS lanname,
    j.value ->> 'proacl' AS proacl,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-INJ-002-RC07'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_inj_002_rc08;

-- ============================================================
-- View: monitoring.v_sec_sql_inj_002_rc08
-- Root cause: SEC-SQL-INJ-002-RC08
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc08 AS
SELECT
    r.server,
    j.value ->> 'name' AS username,
    j.value ->> 'event_name' AS event_name,
    j.value ->> 'extname' AS extname,
    j.value ->> 'extversion' AS extversion,
    j.value ->> 'is_enabled' AS is_enabled,
    j.value ->> 'is_state_enabled' AS is_state_enabled,
    j.value ->> 'audit_action_name' AS audit_action_name,
    j.value ->> 'class_desc' AS class_desc,
    j.value ->> 'policy_name' AS policy_name,
    j.value ->> 'enabled_option' AS enabled_option,
    j.value ->> 'setting' AS setting,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    j.value ->> 'non_bind_sql_count' AS non_bind_sql_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-INJ-002-RC08';

DROP VIEW IF EXISTS monitoring.v_sec_sql_inj_002_rc09;

-- ============================================================
-- View: monitoring.v_sec_sql_inj_002_rc09
-- Root cause: SEC-SQL-INJ-002-RC09
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc09 AS
SELECT
    r.server,
    j.value ->> 'sql_firewall' AS sql_firewall,
    j.value ->> 'value' AS value_val,
    j.value ->> 'client_net_address' AS client_net_address,
    COALESCE(
        j.value ->> 'login_name',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'program_name' AS application_name,
    j.value ->> 'auth_scheme' AS auth_scheme,
    j.value ->> 'is_enabled' AS is_enabled,
    j.value ->> 'setting' AS setting,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-INJ-002-RC09';

DROP VIEW IF EXISTS monitoring.v_sec_sql_inj_002_rc10;

-- ============================================================
-- View: monitoring.v_sec_sql_inj_002_rc10
-- Root cause: SEC-SQL-INJ-002-RC10
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc10 AS
SELECT
    r.server,
    j.value ->> 'audit_enabled' AS audit_enabled,
    j.value ->> 'status' AS state_val,
    j.value ->> 'name' AS username,
    j.value ->> 'is_enabled' AS is_enabled,
    j.value ->> 'lanname' AS lanname,
    j.value ->> 'lanpltrusted' AS lanpltrusted,
    j.value ->> 'rolname' AS rolname,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-INJ-002-RC10';

DROP VIEW IF EXISTS monitoring.v_sec_sql_inj_002_rc11;

-- ============================================================
-- View: monitoring.v_sec_sql_inj_002_rc11
-- Root cause: SEC-SQL-INJ-002-RC11
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc11 AS
SELECT
    r.server,
    j.value ->> 'servicename' AS servicename,
    j.value ->> 'service_account' AS service_account,
    j.value ->> 'startup_type_desc' AS startup_type_desc,
    j.value ->> 'status_desc' AS status_desc,
    j.value ->> 'privilege_assessment' AS privilege_assessment,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-INJ-002-RC11';

DROP VIEW IF EXISTS monitoring.v_sec_sql_inj_002_rc12;

-- ============================================================
-- View: monitoring.v_sec_sql_inj_002_rc12
-- Root cause: SEC-SQL-INJ-002-RC12
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc12 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'login_name',
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'grantee',
        j.value ->> 'owner'
    ) AS username,
    COALESCE(
        j.value ->> 'program_name',
        j.value ->> 'program'
    ) AS application_name,
    j.value ->> 'module' AS module,
    j.value ->> 'one_exec_sql' AS one_exec_sql,
    j.value ->> 'wasted_mb' AS wasted_mb,
    COALESCE(
        j.value ->> 'host_name',
        j.value ->> 'host'
    ) AS host,
    j.value ->> 'super_priv' AS super_priv,
    j.value ->> 'file_priv' AS file_priv,
    j.value ->> 'create_routine_priv' AS create_routine_priv,
    j.value ->> 'execute_priv' AS execute_priv,
    j.value ->> 'nspname' AS nspname,
    j.value ->> 'proname' AS proname,
    j.value ->> 'lanname' AS lanname,
    j.value ->> 'privilege_type' AS privilege_type,
    j.value ->> 'is_grantable' AS is_grantable,
    j.value ->> 'active_sessions' AS active_sessions,
    to_timestamp((j.value ->> 'last_activity')::bigint / 3.0) AS last_activity,
    COALESCE(
        j.value ->> 'text',
        j.value ->> 'query_preview'
    ) AS query_text,
    j.value ->> 'execution_count' AS execution_count,
    to_timestamp((j.value ->> 'last_execution_time')::bigint / 3.0) AS last_execution_time,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-INJ-002-RC12';

DROP VIEW IF EXISTS monitoring.v_sec_sql_inj_002_rc14;

-- ============================================================
-- View: monitoring.v_sec_sql_inj_002_rc14
-- Root cause: SEC-SQL-INJ-002-RC14
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc14 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'schema_name',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'permission_set_desc' AS permission_set_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'is_user_defined' AS is_user_defined,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'definition' AS definition,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-INJ-002-RC14';

DROP VIEW IF EXISTS monitoring.v_sec_sql_inj_002_rc15;

-- ============================================================
-- View: monitoring.v_sec_sql_inj_002_rc15
-- Root cause: SEC-SQL-INJ-002-RC15
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc15 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'schema_name',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'proc_name' AS proc_name,
    j.value ->> 'injection_risk_level' AS injection_risk_level,
    j.value ->> 'is_enabled' AS is_enabled,
    j.value ->> 'state_desc' AS state_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-INJ-002-RC15';

DROP VIEW IF EXISTS monitoring.v_sec_sql_inj_002_rc16;

-- ============================================================
-- View: monitoring.v_sec_sql_inj_002_rc16
-- Root cause: SEC-SQL-INJ-002-RC16
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc16 AS
SELECT
    r.server,
    j.value ->> 'routine_schema' AS routine_schema,
    j.value ->> 'routine_name' AS routine_name,
    j.value ->> 'routine_type' AS routine_type,
    j.value ->> 'no_sql_firewall' AS no_sql_firewall,
    j.value ->> 'tgname' AS tgname,
    j.value ->> 'relname' AS relname,
    j.value ->> 'proname' AS proname,
    j.value ->> 'lanname' AS lanname,
    COALESCE(
        j.value ->> 'schema_name',
        j.value ->> 'name'
    ) AS username,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'event_schema' AS event_schema,
    j.value ->> 'event_name' AS event_name,
    j.value ->> 'event' AS event,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-INJ-002-RC16';

DROP VIEW IF EXISTS monitoring.v_sec_sql_net_001_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_net_001_rc01
-- Root cause: SEC-SQL-NET-001-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_001_rc01 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    COALESCE(
        j.value ->> 'machine',
        j.value ->> 'host'
    ) AS host,
    j.value ->> 'listener_id' AS listener_id,
    j.value ->> 'ip_address' AS ip_address,
    j.value ->> 'port' AS port,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'state_desc' AS state_desc,
    to_timestamp((j.value ->> 'start_time')::bigint / 3.0) AS start_time,
    j.value ->> 'value' AS value_val,
    j.value ->> 'connections' AS connections,
    j.value ->> 'local_net_address' AS local_net_address,
    j.value ->> 'local_tcp_port' AS local_tcp_port,
    j.value ->> 'connection_count' AS connection_count,
    j.value ->> 'setting' AS setting,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-NET-001-RC01';

DROP VIEW IF EXISTS monitoring.v_sec_sql_net_001_rc02;

-- ============================================================
-- View: monitoring.v_sec_sql_net_001_rc02
-- Root cause: SEC-SQL-NET-001-RC02
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_001_rc02 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'login_name',
        j.value ->> 'user'
    ) AS username,
    COALESCE(
        j.value ->> 'host_name',
        j.value ->> 'host'
    ) AS host,
    j.value ->> 'source_host' AS source_host,
    COALESCE(
        j.value ->> 'program_name',
        j.value ->> 'program'
    ) AS application_name,
    j.value ->> 'session_count' AS session_count,
    to_timestamp((j.value ->> 'event_time')::bigint / 3.0) AS event_time,
    j.value ->> 'error_number' AS error_number,
    j.value ->> 'error_message' AS error_message,
    j.value ->> 'authentication_string' AS authentication_string,
    j.value ->> 'line_number' AS line_number,
    j.value ->> 'type' AS state_val,
    j.value ->> 'database' AS database_val,
    j.value ->> 'user_name' AS user_name,
    j.value ->> 'address' AS address,
    j.value ->> 'netmask' AS netmask,
    j.value ->> 'auth_method' AS auth_method,
    j.value ->> 'client_net_address' AS client_net_address,
    j.value ->> 'auth_scheme' AS auth_scheme,
    j.value ->> 'encrypt_option' AS encrypt_option,
    to_timestamp((j.value ->> 'login_time')::bigint / 3.0) AS login_time,
    j.value ->> 'connection_count' AS connection_count,
    j.value ->> 'ip_address' AS ip_address,
    j.value ->> 'port' AS port,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'state_desc' AS state_desc,
    j.value ->> 'userhost' AS userhost,
    j.value ->> 'failed_attempts' AS failed_attempts,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-NET-001-RC02';

DROP VIEW IF EXISTS monitoring.v_sec_sql_net_001_rc03;

-- ============================================================
-- View: monitoring.v_sec_sql_net_001_rc03
-- Root cause: SEC-SQL-NET-001-RC03
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_001_rc03 AS
SELECT
    r.server,
    j.value ->> 'listener_id' AS listener_id,
    j.value ->> 'ip_address' AS ip_address,
    j.value ->> 'port' AS port,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'state_desc' AS state_desc,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'client_net_address' AS client_net_address,
    j.value ->> 'local_net_address' AS local_net_address,
    to_timestamp((j.value ->> 'connect_time')::bigint / 3.0) AS connect_time,
    j.value ->> 'login_name' AS username,
    j.value ->> 'host_name' AS host,
    COALESCE(
        j.value ->> 'program_name',
        j.value ->> 'program'
    ) AS application_name,
    j.value ->> 'host_pattern' AS host_pattern,
    j.value ->> 'connection_count' AS connection_count,
    j.value ->> 'extname' AS extname,
    j.value ->> 'machine' AS machine,
    j.value ->> 'osuser' AS osuser,
    j.value ->> 'setting' AS setting,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-NET-001-RC03'
  AND j.value ->> 'host_name' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_net_001_rc12;

-- ============================================================
-- View: monitoring.v_sec_sql_net_001_rc12
-- Root cause: SEC-SQL-NET-001-RC12
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_001_rc12 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'days_until_expiration' AS days_until_expiration,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'is_expired' AS is_expired,
    j.value ->> 'is_locked' AS is_locked,
    j.value ->> 'must_change' AS must_change,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    j.value ->> 'is_disabled' AS is_disabled,
    to_timestamp((j.value ->> 'days_since_created')::bigint / 3.0) AS days_since_created,
    j.value ->> 'host' AS host,
    j.value ->> 'account_status' AS account_status,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    j.value ->> 'days_active' AS days_active,
    j.value ->> 'profile' AS profile,
    j.value ->> 'line_number' AS line_number,
    j.value ->> 'type' AS state,
    j.value ->> 'database' AS database,
    j.value ->> 'user_name' AS user_name,
    j.value ->> 'address' AS address,
    j.value ->> 'auth_method' AS auth_method,
    j.value ->> 'super_priv' AS super_priv,
    j.value ->> 'grant_priv' AS grant_priv,
    j.value ->> 'create_user_priv' AS create_user_priv,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-NET-001-RC12'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_net_002_rc02;

-- ============================================================
-- View: monitoring.v_sec_sql_net_002_rc02
-- Root cause: SEC-SQL-NET-002-RC02
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_002_rc02 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'host' AS host,
    j.value ->> 'default_count' AS default_count,
    j.value ->> 'port' AS port,
    j.value ->> 'value' AS value,
    j.value ->> 'isdefault' AS isdefault,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-NET-002-RC02'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_net_002_rc06;

-- ============================================================
-- View: monitoring.v_sec_sql_net_002_rc06
-- Root cause: SEC-SQL-NET-002-RC06
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_002_rc06 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'program_name',
        j.value ->> 'program'
    ) AS application_name,
    j.value ->> 'machine' AS host,
    j.value ->> 'connection_count' AS connection_count,
    j.value ->> 'setting' AS setting,
    j.value ->> 'source' AS source,
    j.value ->> 'port' AS port,
    j.value ->> 'ip_address' AS ip_address,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'local_tcp_port' AS local_tcp_port,
    j.value ->> 'distinct_hosts' AS distinct_hosts,
    j.value ->> 'distinct_programs' AS distinct_programs,
    j.value ->> 'distinct_machines' AS distinct_machines,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-NET-002-RC06'
  AND j.value ->> 'machine' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_net_002_rc08;

-- ============================================================
-- View: monitoring.v_sec_sql_net_002_rc08
-- Root cause: SEC-SQL-NET-002-RC08
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_002_rc08 AS
SELECT
    r.server,
    j.value ->> 'name' AS username,
    j.value ->> 'value' AS value_val,
    j.value ->> 'servicename' AS servicename,
    j.value ->> 'status_desc' AS status_desc,
    j.value ->> 'startup_type_desc' AS startup_type_desc,
    j.value ->> 'local_tcp_port' AS local_tcp_port,
    j.value ->> 'setting' AS setting,
    j.value ->> 'source' AS source,
    j.value ->> 'port' AS port,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-NET-002-RC08';

DROP VIEW IF EXISTS monitoring.v_sec_sql_net_002_rc13;

-- ============================================================
-- View: monitoring.v_sec_sql_net_002_rc13
-- Root cause: SEC-SQL-NET-002-RC13
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_002_rc13 AS
SELECT
    r.server,
    j.value ->> 'failed_login_count' AS failed_login_count,
    j.value ->> 'earliest_failure' AS earliest_failure,
    j.value ->> 'latest_failure' AS latest_failure,
    j.value ->> 'port' AS port,
    j.value ->> 'max_connect_errors' AS max_connect_errors,
    j.value ->> 'policy_name' AS policy_name,
    j.value ->> 'name' AS username,
    j.value ->> 'setting' AS setting,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    j.value ->> 'profile' AS profile,
    j.value ->> 'resource_name' AS resource_name,
    j.value ->> 'limit' AS limit_val,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-NET-002-RC13';

DROP VIEW IF EXISTS monitoring.v_sec_sql_net_002_rc14;

-- ============================================================
-- View: monitoring.v_sec_sql_net_002_rc14
-- Root cause: SEC-SQL-NET-002-RC14
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_002_rc14 AS
SELECT
    r.server,
    j.value ->> 'instance_name' AS instance_name,
    to_timestamp((j.value ->> 'startup_time')::bigint / 3.0) AS startup_time,
    j.value ->> 'uptime_days' AS uptime_days,
    j.value ->> 'version' AS version,
    j.value ->> 'setting' AS setting,
    j.value ->> 'source' AS source,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-NET-002-RC14';

DROP VIEW IF EXISTS monitoring.v_sec_sql_pat_001_rc02;

-- ============================================================
-- View: monitoring.v_sec_sql_pat_001_rc02
-- Root cause: SEC-SQL-PAT-001-RC02
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pat_001_rc02 AS
SELECT
    r.server,
    j.value ->> 'dbid' AS dbid,
    j.value ->> 'name' AS username,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    j.value ->> 'log_mode' AS log_mode,
    j.value ->> 'open_mode' AS open_mode,
    j.value ->> 'banner_full' AS banner_full,
    j.value ->> 'con_id' AS con_id,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-PAT-001-RC02';

DROP VIEW IF EXISTS monitoring.v_sec_sql_pat_001_rc12;

-- ============================================================
-- View: monitoring.v_sec_sql_pat_001_rc12
-- Root cause: SEC-SQL-PAT-001-RC12
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pat_001_rc12 AS
SELECT
    r.server,
    to_timestamp((j.value ->> 'last_patch_date')::bigint / 3.0) AS last_patch_date,
    j.value ->> 'days_since_patch' AS days_since_patch,
    j.value ->> 'banner_full' AS banner_full,
    to_timestamp((j.value ->> 'sqlserver_start_time')::bigint / 3.0) AS sqlserver_start_time,
    j.value ->> 'days_since_restart' AS days_since_restart,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-PAT-001-RC12';

DROP VIEW IF EXISTS monitoring.v_sec_sql_pri_001_rc03;

-- ============================================================
-- View: monitoring.v_sec_sql_pri_001_rc03
-- Root cause: SEC-SQL-PRI-001-RC03
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_001_rc03 AS
SELECT
    r.server,
    j.value ->> 'relname' AS relname,
    j.value ->> 'idx_scan' AS idx_scan,
    j.value ->> 'n_tup_upd' AS n_tup_upd,
    j.value ->> 'table_schema' AS table_schema,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'column_name' AS column_name,
    j.value ->> 'data_type' AS data_type,
    j.value ->> 'tablespace_name' AS tablespace_name,
    j.value ->> 'encrypted' AS encrypted,
    j.value ->> 'contents' AS contents,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-PRI-001-RC03';

DROP VIEW IF EXISTS monitoring.v_sec_sql_pri_001_rc12;

-- ============================================================
-- View: monitoring.v_sec_sql_pri_001_rc12
-- Root cause: SEC-SQL-PRI-001-RC12
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_001_rc12 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'owner',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'max_length' AS max_length,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'column_name' AS column_name,
    j.value ->> 'data_type' AS data_type,
    j.value ->> 'data_length' AS data_length,
    j.value ->> 'pii_category' AS pii_category,
    j.value ->> 'table_schema' AS table_schema,
    j.value ->> 'character_maximum_length' AS character_maximum_length,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-PRI-001-RC12';

DROP VIEW IF EXISTS monitoring.v_sec_sql_pri_001_rc15;

-- ============================================================
-- View: monitoring.v_sec_sql_pri_001_rc15
-- Root cause: SEC-SQL-PRI-001-RC15
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_001_rc15 AS
SELECT
    r.server,
    j.value ->> 'table_schema' AS table_schema,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'column_name' AS column_name,
    j.value ->> 'pii_category' AS pii_category,
    COALESCE(
        j.value ->> 'owner',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'nspname' AS nspname,
    j.value ->> 'relname' AS relname,
    j.value ->> 'attname' AS attname,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-PRI-001-RC15';

DROP VIEW IF EXISTS monitoring.v_sec_sql_pri_003_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_pri_003_rc01
-- Root cause: SEC-SQL-PRI-003-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_003_rc01 AS
SELECT
    r.server,
    j.value ->> 'database_name' AS db,
    j.value ->> 'missing_ppl_security_level_parameter' AS missing_ppl_security_level_parameter,
    j.value ->> 'missing_ppl_security_level_option' AS missing_ppl_security_level_option,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-PRI-003-RC01';

DROP VIEW IF EXISTS monitoring.v_sec_sql_pri_003_rc03;

-- ============================================================
-- View: monitoring.v_sec_sql_pri_003_rc03
-- Root cause: SEC-SQL-PRI-003-RC03
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_003_rc03 AS
SELECT
    r.server,
    j.value ->> 'variable_name' AS variable_name,
    j.value ->> 'variable_value' AS variable_value,
    j.value ->> 'name' AS username,
    j.value ->> 'setting' AS setting,
    j.value ->> 'value_in_use' AS value_in_use,
    j.value ->> 'value' AS value,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-PRI-003-RC03';

DROP VIEW IF EXISTS monitoring.v_sec_sql_pri_004_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_pri_004_rc01
-- Root cause: SEC-SQL-PRI-004-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_004_rc01 AS
SELECT
    r.server,
    j.value ->> 'database_name' AS db,
    j.value ->> 'encryption_state' AS encryption_state,
    j.value ->> 'key_algorithm' AS key_algorithm,
    j.value ->> 'variable_name' AS variable_name,
    j.value ->> 'variable_value' AS variable_value,
    j.value ->> 'tablespace_name' AS tablespace_name,
    j.value ->> 'encrypted' AS encrypted,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-PRI-004-RC01';

DROP VIEW IF EXISTS monitoring.v_sec_sql_pri_004_rc03;

-- ============================================================
-- View: monitoring.v_sec_sql_pri_004_rc03
-- Root cause: SEC-SQL-PRI-004-RC03
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_004_rc03 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'pid',
        j.value ->> 'session_id'
    ) AS session_id,
    j.value ->> 'encrypt_option' AS encrypt_option,
    COALESCE(
        j.value ->> 'usename',
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'value' AS value,
    j.value ->> 'host' AS host,
    j.value ->> 'ssl_type' AS ssl_type,
    j.value ->> 'ssl' AS ssl,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-PRI-004-RC03'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_pri_005_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_pri_005_rc01
-- Root cause: SEC-SQL-PRI-005-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_005_rc01 AS
SELECT
    r.server,
    j.value ->> 'variable_name' AS variable_name,
    j.value ->> 'variable_value' AS variable_value,
    j.value ->> 'name' AS username,
    j.value ->> 'value' AS value,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-PRI-005-RC01';

DROP VIEW IF EXISTS monitoring.v_sec_sql_pri_006_rc02;

-- ============================================================
-- View: monitoring.v_sec_sql_pri_006_rc02
-- Root cause: SEC-SQL-PRI-006-RC02
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_006_rc02 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'user',
        j.value ->> 'grantee',
        j.value ->> 'name'
    ) AS username,
    to_timestamp((j.value ->> 'granted_role')::bigint / 3.0) AS granted_role,
    j.value ->> 'host' AS host,
    j.value ->> 'rolname' AS rolname,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-PRI-006-RC02'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_pri_006_rc03;

-- ============================================================
-- View: monitoring.v_sec_sql_pri_006_rc03
-- Root cause: SEC-SQL-PRI-006-RC03
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_006_rc03 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'host' AS host,
    to_timestamp((j.value ->> 'password_last_changed')::bigint / 3.0) AS password_last_changed,
    to_timestamp((j.value ->> 'last_login')::bigint / 3.0) AS last_login,
    j.value ->> 'rolname' AS rolname,
    to_timestamp((j.value ->> 'last_seen')::bigint / 3.0) AS last_seen,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-PRI-006-RC03'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_pri_007_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_pri_007_rc01
-- Root cause: SEC-SQL-PRI-007-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_007_rc01 AS
SELECT
    r.server,
    j.value ->> 'variable_name' AS variable_name,
    j.value ->> 'variable_value' AS variable_value,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'profile' AS profile,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-PRI-007-RC01';

DROP VIEW IF EXISTS monitoring.v_sec_sql_pri_008_rc02;

-- ============================================================
-- View: monitoring.v_sec_sql_pri_008_rc02
-- Root cause: SEC-SQL-PRI-008-RC02
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_008_rc02 AS
SELECT
    r.server,
    j.value ->> 'variable_name' AS variable_name,
    j.value ->> 'variable_value' AS variable_value,
    j.value ->> 'bs_key' AS bs_key,
    to_timestamp((j.value ->> 'completion_time')::bigint / 3.0) AS completion_time,
    j.value ->> 'encrypted' AS encrypted,
    j.value ->> 'database_name' AS db,
    j.value ->> 'database_name' AS database_name,
    to_timestamp((j.value ->> 'backup_finish_date')::bigint / 3.0) AS backup_finish_date,
    j.value ->> 'encryptor_type' AS encryptor_type,
    j.value ->> 'has_backup_checksums' AS has_backup_checksums,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-PRI-008-RC02';

DROP VIEW IF EXISTS monitoring.v_sec_sql_pri_010_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_pri_010_rc01
-- Root cause: SEC-SQL-PRI-010-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_010_rc01 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'client_addr',
        j.value ->> 'host'
    ) AS host,
    j.value ->> 'conn_count' AS conn_count,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'user'
    ) AS username,
    j.value ->> 'failed_count' AS failed_count,
    j.value ->> 'os_username' AS os_username,
    to_timestamp((j.value ->> 'last_failure')::bigint / 3.0) AS last_failure,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-PRI-010-RC01';

DROP VIEW IF EXISTS monitoring.v_sec_sql_pri_010_rc02;

-- ============================================================
-- View: monitoring.v_sec_sql_pri_010_rc02
-- Root cause: SEC-SQL-PRI-010-RC02
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_010_rc02 AS
SELECT
    r.server,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolsuper' AS rolsuper,
    j.value ->> 'rolcreaterole' AS rolcreaterole,
    j.value ->> 'rolcreatedb' AS rolcreatedb,
    COALESCE(
        j.value ->> 'user',
        j.value ->> 'grantee',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'host' AS host,
    j.value ->> 'super_priv' AS super_priv,
    j.value ->> 'grant_priv' AS grant_priv,
    to_timestamp((j.value ->> 'granted_role')::bigint / 3.0) AS granted_role,
    j.value ->> 'default_role' AS default_role,
    j.value ->> 'admin_option' AS admin_option,
    j.value ->> 'role_principal_id' AS role_principal_id,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-PRI-010-RC02'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';

DROP VIEW IF EXISTS monitoring.v_sec_sql_pri_010_rc03;

-- ============================================================
-- View: monitoring.v_sec_sql_pri_010_rc03
-- Root cause: SEC-SQL-PRI-010-RC03
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_010_rc03 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'pid',
        j.value ->> 'session_id',
        j.value ->> 'sid',
        j.value ->> 'id'
    ) AS session_id,
    COALESCE(
        j.value ->> 'usename',
        j.value ->> 'login_name',
        j.value ->> 'username',
        j.value ->> 'user'
    ) AS username,
    COALESCE(
        j.value ->> 'client_addr',
        j.value ->> 'host_name',
        j.value ->> 'machine',
        j.value ->> 'host'
    ) AS host,
    COALESCE(
        j.value ->> 'application_name',
        j.value ->> 'program_name',
        j.value ->> 'program'
    ) AS application_name,
    to_timestamp((j.value ->> 'query_start')::bigint / 3.0) AS query_start,
    to_timestamp((j.value ->> 'start_time')::bigint / 3.0) AS start_time,
    j.value ->> 'db' AS db,
    j.value ->> 'command' AS state,
    to_timestamp((j.value ->> 'time')::bigint / 3.0) AS time,
    j.value ->> 'info' AS query_text,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-PRI-010-RC03'
