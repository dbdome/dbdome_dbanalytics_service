-- 5930: extend SEC-SQL-AUTHZ-001-RC01 (access inventory) to ALL db_vendors.
-- Each vendor query returns the same shape: server, database_name, login_name,
-- database_user, principal_type, roles, permissions, login_status.
-- Idempotent: step upserts on (vendor_slug,name); path inserted only if absent.
-- NOTE: non-sqlserver queries are best-effort (assume modern versions) and should
--       be validated against a live instance of each vendor.


INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content)
VALUES ('postgresql', 'query', 'Detect SEC-SQL-AUTHZ-001-RC01 (postgresql)', $j_postgresql${"sql": "SELECT\n  coalesce(host(inet_server_addr()), 'localhost')          AS server,\n  current_database()                                       AS database_name,\n  CASE WHEN r.rolcanlogin THEN r.rolname END               AS login_name,\n  r.rolname                                                AS database_user,\n  CASE WHEN r.rolsuper THEN 'SUPERUSER'\n       WHEN r.rolcanlogin THEN 'LOGIN' ELSE 'ROLE' END     AS principal_type,\n  (SELECT string_agg(g.rolname, ', ' ORDER BY g.rolname)\n     FROM pg_auth_members m JOIN pg_roles g ON g.oid = m.roleid\n    WHERE m.member = r.oid)                                AS roles,\n  (SELECT string_agg(DISTINCT tp.privilege_type, ', ')\n     FROM information_schema.role_table_grants tp\n    WHERE tp.grantee = r.rolname)                          AS permissions,\n  CASE WHEN r.rolcanlogin THEN 'login' ELSE 'no-login' END AS login_status\nFROM pg_roles r\nWHERE r.rolname NOT LIKE 'pg\\_%'\nORDER BY r.rolname", "condition": "row_count > 0", "description": "Database access & privilege inventory (logins, roles, grants)"}$j_postgresql$::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET content = EXCLUDED.content;

INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
SELECT 'SEC-SQL-AUTHZ-001-RC01', 'postgresql', 'Detect SEC-SQL-AUTHZ-001-RC01 (postgresql)', 'Database access & privilege inventory (logins, roles, grants)', 'diagnostic', true
WHERE NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
                  WHERE root_cause_id='SEC-SQL-AUTHZ-001-RC01' AND vendor_slug='postgresql');


INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content)
VALUES ('oracle', 'query', 'Detect SEC-SQL-AUTHZ-001-RC01 (oracle)', $j_oracle${"sql": "SELECT\n  sys_context('USERENV','SERVER_HOST')  AS server,\n  sys_context('USERENV','DB_NAME')      AS database_name,\n  u.username                            AS login_name,\n  u.username                            AS database_user,\n  'USER'                                AS principal_type,\n  (SELECT LISTAGG(rp.granted_role, ', ') WITHIN GROUP (ORDER BY rp.granted_role)\n     FROM dba_role_privs rp WHERE rp.grantee = u.username) AS roles,\n  (SELECT LISTAGG(sp.privilege, ', ') WITHIN GROUP (ORDER BY sp.privilege)\n     FROM dba_sys_privs sp WHERE sp.grantee = u.username)  AS permissions,\n  u.account_status                      AS login_status\nFROM dba_users u\nWHERE u.oracle_maintained = 'N'\nORDER BY u.username", "condition": "row_count > 0", "description": "Database access & privilege inventory (logins, roles, grants)"}$j_oracle$::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET content = EXCLUDED.content;

INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
SELECT 'SEC-SQL-AUTHZ-001-RC01', 'oracle', 'Detect SEC-SQL-AUTHZ-001-RC01 (oracle)', 'Database access & privilege inventory (logins, roles, grants)', 'diagnostic', true
WHERE NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
                  WHERE root_cause_id='SEC-SQL-AUTHZ-001-RC01' AND vendor_slug='oracle');


INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content)
VALUES ('mysql', 'query', 'Detect SEC-SQL-AUTHZ-001-RC01 (mysql)', $j_mysql${"sql": "SELECT\n  @@hostname                                          AS server,\n  NULL                                                AS database_name,\n  CONCAT(u.User, '@', u.Host)                         AS login_name,\n  CONCAT(u.User, '@', u.Host)                         AS database_user,\n  'USER'                                              AS principal_type,\n  (SELECT GROUP_CONCAT(CONCAT(re.FROM_USER,'@',re.FROM_HOST) ORDER BY re.FROM_USER SEPARATOR ', ')\n     FROM mysql.role_edges re WHERE re.TO_USER=u.User AND re.TO_HOST=u.Host) AS roles,\n  (SELECT GROUP_CONCAT(DISTINCT up.PRIVILEGE_TYPE ORDER BY up.PRIVILEGE_TYPE SEPARATOR ', ')\n     FROM information_schema.USER_PRIVILEGES up\n    WHERE up.GRANTEE = CONCAT(\"'\", u.User, \"'@'\", u.Host, \"'\")) AS permissions,\n  CASE WHEN u.account_locked='Y' THEN 'locked' ELSE 'active' END AS login_status\nFROM mysql.user u\nORDER BY u.User, u.Host", "condition": "row_count > 0", "description": "Database access & privilege inventory (logins, roles, grants)"}$j_mysql$::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET content = EXCLUDED.content;

INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
SELECT 'SEC-SQL-AUTHZ-001-RC01', 'mysql', 'Detect SEC-SQL-AUTHZ-001-RC01 (mysql)', 'Database access & privilege inventory (logins, roles, grants)', 'diagnostic', true
WHERE NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
                  WHERE root_cause_id='SEC-SQL-AUTHZ-001-RC01' AND vendor_slug='mysql');


INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content)
VALUES ('mariadb', 'query', 'Detect SEC-SQL-AUTHZ-001-RC01 (mariadb)', $j_mariadb${"sql": "SELECT\n  @@hostname                                          AS server,\n  NULL                                                AS database_name,\n  CONCAT(u.User, '@', u.Host)                         AS login_name,\n  CONCAT(u.User, '@', u.Host)                         AS database_user,\n  CASE WHEN u.is_role='Y' THEN 'ROLE' ELSE 'USER' END AS principal_type,\n  (SELECT GROUP_CONCAT(rm.Role ORDER BY rm.Role SEPARATOR ', ')\n     FROM mysql.roles_mapping rm WHERE rm.User=u.User AND rm.Host=u.Host) AS roles,\n  (SELECT GROUP_CONCAT(DISTINCT up.PRIVILEGE_TYPE ORDER BY up.PRIVILEGE_TYPE SEPARATOR ', ')\n     FROM information_schema.USER_PRIVILEGES up\n    WHERE up.GRANTEE = CONCAT(\"'\", u.User, \"'@'\", u.Host, \"'\")) AS permissions,\n  'active'                                            AS login_status\nFROM mysql.user u\nORDER BY u.User, u.Host", "condition": "row_count > 0", "description": "Database access & privilege inventory (logins, roles, grants)"}$j_mariadb$::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET content = EXCLUDED.content;

INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
SELECT 'SEC-SQL-AUTHZ-001-RC01', 'mariadb', 'Detect SEC-SQL-AUTHZ-001-RC01 (mariadb)', 'Database access & privilege inventory (logins, roles, grants)', 'diagnostic', true
WHERE NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
                  WHERE root_cause_id='SEC-SQL-AUTHZ-001-RC01' AND vendor_slug='mariadb');


INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content)
VALUES ('informix', 'query', 'Detect SEC-SQL-AUTHZ-001-RC01 (informix)', $j_informix${"sql": "SELECT\n  DBINFO('dbname')   AS server,\n  DBINFO('dbname')   AS database_name,\n  TRIM(u.username)   AS login_name,\n  TRIM(u.username)   AS database_user,\n  CASE u.usertype WHEN 'D' THEN 'DBA' WHEN 'R' THEN 'RESOURCE'\n       WHEN 'C' THEN 'CONNECT' ELSE u.usertype END AS principal_type,\n  CAST(NULL AS VARCHAR(255)) AS roles,\n  u.usertype         AS permissions,\n  'active'           AS login_status\nFROM sysusers u\nORDER BY u.username", "condition": "row_count > 0", "description": "Database access & privilege inventory (logins, roles, grants)"}$j_informix$::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET content = EXCLUDED.content;

INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
SELECT 'SEC-SQL-AUTHZ-001-RC01', 'informix', 'Detect SEC-SQL-AUTHZ-001-RC01 (informix)', 'Database access & privilege inventory (logins, roles, grants)', 'diagnostic', true
WHERE NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
                  WHERE root_cause_id='SEC-SQL-AUTHZ-001-RC01' AND vendor_slug='informix');

-- Link each vendor's detection_path to its detection_step (the junction the view needs).
INSERT INTO rootcause.detection_path_steps
    (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
SELECT dp.id, ds.id, 1, 'confirmed', 'ruled_out'
FROM rootcause.detection_paths dp
JOIN rootcause.detection_steps ds ON ds.vendor_slug = dp.vendor_slug AND ds.name = dp.name
WHERE dp.root_cause_id = 'SEC-SQL-AUTHZ-001-RC01'
  AND NOT EXISTS (SELECT 1 FROM rootcause.detection_path_steps x
                  WHERE x.detection_path_id = dp.id AND x.detection_step_id = ds.id);
