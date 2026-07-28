#!/usr/bin/env python3
r"""Build specs/supply_chain.json from SUPPLY_CHAIN_DETECTION.md (area SCP, 36 RCs).

PostgreSQL detection SQL is provided for the catalog-native probes (always-present
catalogs: pg_proc, pg_trigger, pg_language, pg_extension, pg_event_trigger,
pg_default_acl, pg_roles, pg_auth_members, pg_settings, pg_foreign_*). Probes that
need an instrumentation/baseline table (dbx_ddl_audit, dbx_*_baseline) or are
vendor-specific (SQL Server / Oracle / MySQL) are left detect=None (TODO).

Allow-list of deploy principals is a placeholder (postgres/ci_deploy/migrator) —
parameterise per customer.
"""
import json
import os

V = ["postgresql", "sqlserver", "oracle", "mysql"]
ALLOW = "('postgres','ci_deploy','migrator')"
USERSCHEMA = "n.nspname NOT IN ('pg_catalog','information_schema')"


def rc(n, name, slug, desc, topics, risk, resolution, columns, pg):
    return {
        "rc": f"SEC-SQL-SCP-{n:03d}-RC01",
        "issue": f"SEC-SQL-SCP-{n:03d}",
        "name": name, "slug": slug, "description": desc,
        "topics": topics, "risk_level": risk, "resolution": resolution,
        "expected": {"condition": "row_count > 0", "description": name},
        "columns": columns,
        "detect": {"postgresql": pg, "sqlserver": None, "oracle": None, "mysql": None},
    }


T = ["supply-chain", "schema-persistence", "scp"]
RCS = [
    rc(1, "Schema DDL change outside the approved migration window",
       "scp-ddl-outside-window",
       "A CREATE/ALTER landed out-of-window or from a non-deploy principal (MITRE T1505/T1195.002). Needs the dbx_ddl_audit feed.",
       T + ["ddl", "change-control", "provenance"], "high",
       "Enable DDL audit (event trigger / pgAudit), enforce a change window, and review any out-of-window DDL.",
       ["event_time", "principal", "command"], None),
    rc(2, "Hidden trigger created by a non-deploy principal",
       "scp-trigger-nondeploy",
       "A trigger whose backing function owner is off the deploy allow-list, firing on ordinary writes (T1546/T1505.001).",
       T + ["trigger", "persistence"], "high",
       "Review the trigger and its function; drop if unauthorised; restrict trigger creation to the deploy role.",
       ["schema", "table_name", "trigger_name", "function_name", "owner"],
       "SELECT n.nspname AS schema, c.relname AS table_name, t.tgname AS trigger_name, "
       "p.proname AS function_name, r.rolname AS owner FROM pg_trigger t "
       "JOIN pg_class c ON c.oid = t.tgrelid JOIN pg_namespace n ON n.oid = c.relnamespace "
       "JOIN pg_proc p ON p.oid = t.tgfoid JOIN pg_roles r ON r.oid = p.proowner "
       f"WHERE NOT t.tgisinternal AND {USERSCHEMA} AND r.rolname NOT IN {ALLOW} "
       "ORDER BY n.nspname, c.relname"),
    rc(3, "Backdoored stored procedure/function by a non-deploy principal",
       "scp-routine-nondeploy",
       "A routine authored outside change control by an off-allow-list owner (T1505.001).",
       T + ["routine", "persistence"], "high",
       "Review the routine body and provenance; drop if unauthorised; lock routine creation to the deploy role.",
       ["schema", "routine", "owner", "language"],
       "SELECT n.nspname AS schema, p.proname AS routine, r.rolname AS owner, l.lanname AS language "
       "FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace "
       "JOIN pg_roles r ON r.oid = p.proowner JOIN pg_language l ON l.oid = p.prolang "
       f"WHERE {USERSCHEMA} AND r.rolname NOT IN {ALLOW} ORDER BY n.nspname, p.proname"),
    rc(4, "Untrusted procedural language or dangerous extension installed",
       "scp-untrusted-pl-extension",
       "plpythonu/plperlu/plpython3u/plsh, or dblink/http/file_fdw installed — host-code-execution surface (T1505; CIS).",
       T + ["extension", "untrusted-pl"], "high",
       "Remove the untrusted language/extension if not required; restrict who can CREATE EXTENSION.",
       ["kind", "name"],
       "SELECT 'language' AS kind, lanname AS name FROM pg_language "
       "WHERE lanname IN ('plpythonu','plperlu','plpython3u','plsh') "
       "OR (lanispl AND NOT lanpltrusted) "
       "UNION ALL SELECT 'extension', extname FROM pg_extension "
       "WHERE extname IN ('dblink','http','file_fdw','plsh','plpythonu','plperlu','plpython3u')"),
    rc(5, "Routine body references outbound network egress",
       "scp-routine-egress",
       "Routine references dblink/http/UTL_HTTP/UTL_TCP/UTL_SMTP — outbound channel (T1041/T1505.001).",
       T + ["egress", "body-scan"], "high",
       "Confirm whether the egress is a sanctioned integration; otherwise treat as a backdoor and remove.",
       ["schema", "routine", "owner"],
       "SELECT n.nspname AS schema, p.proname AS routine, r.rolname AS owner "
       "FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace JOIN pg_roles r ON r.oid = p.proowner "
       f"WHERE {USERSCHEMA} AND p.prosrc ~* '(dblink|http_get|http_post|utl_http|utl_tcp|utl_smtp|pg_background)' "
       "ORDER BY n.nspname, p.proname"),
    rc(6, "Routine body references OS command execution",
       "scp-routine-os-exec",
       "Routine references xp_cmdshell/sp_OACreate/COPY ... PROGRAM/os.system/DBMS_SCHEDULER (T1059/T1505.001).",
       T + ["os-exec", "body-scan"], "high",
       "Treat as host-command capability; review and remove; restrict COPY PROGRAM and untrusted PLs.",
       ["schema", "routine", "owner"],
       "SELECT n.nspname AS schema, p.proname AS routine, r.rolname AS owner "
       "FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace JOIN pg_roles r ON r.oid = p.proowner "
       f"WHERE {USERSCHEMA} AND p.prosrc ~* '(xp_cmdshell|sp_oacreate|copy[^;]*program|os\\.system|subprocess|dbms_scheduler)' "
       "ORDER BY n.nspname, p.proname"),
    rc(7, "Time-bombed / logic-bomb routine",
       "scp-logic-bomb",
       "A destructive action (DROP/TRUNCATE/DELETE) gated on a date/time comparison (T1485/T1546).",
       T + ["logic-bomb", "destruction"], "high",
       "Inspect the routine; confirm it is not a sanctioned cleanup job; remove the time-gated destruction.",
       ["schema", "routine", "owner"],
       "SELECT n.nspname AS schema, p.proname AS routine, r.rolname AS owner "
       "FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace JOIN pg_roles r ON r.oid = p.proowner "
       f"WHERE {USERSCHEMA} AND p.prosrc ~* '(drop\\s+table|truncate|delete\\s+from)' "
       "AND p.prosrc ~* '(current_date|current_timestamp|now\\(\\)|clock_timestamp|to_date|extract)' "
       "ORDER BY n.nspname, p.proname"),
    rc(8, "SECURITY DEFINER routine owned by a superuser",
       "scp-secdef-superuser",
       "A definer-rights routine owned by a superuser — a standing privilege-escalation primitive (T1548).",
       T + ["security-definer", "privesc"], "high",
       "Re-own to a least-privilege role, pin search_path, and review the body; revoke EXECUTE from PUBLIC.",
       ["schema", "routine", "owner"],
       "SELECT n.nspname AS schema, p.proname AS routine, r.rolname AS owner "
       "FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace JOIN pg_roles r ON r.oid = p.proowner "
       f"WHERE p.prosecdef AND r.rolsuper AND {USERSCHEMA} ORDER BY n.nspname, p.proname"),
    rc(9, "Event / DDL / logon trigger installed for persistence",
       "scp-event-trigger",
       "An event trigger that fires on every login or DDL event — a persistence foothold (T1546).",
       T + ["event-trigger", "persistence"], "high",
       "Review each event trigger and its function; drop unauthorised ones; restrict event-trigger creation.",
       ["event_trigger", "event", "owner", "enabled"],
       "SELECT e.evtname AS event_trigger, e.evtevent AS event, r.rolname AS owner, "
       "e.evtenabled AS enabled FROM pg_event_trigger e JOIN pg_roles r ON r.oid = e.evtowner "
       "ORDER BY e.evtname"),
    rc(10, "Malicious migration performing non-schema actions from CI/CD",
       "scp-migration-nonschema",
       "A migration that creates roles, GRANTs, or alters config (T1195.002). Needs the dbx_ddl_audit feed.",
       T + ["ci-cd", "migration"], "high",
       "Audit CI/CD migrations for role/grant/config statements; require review for non-schema DDL.",
       ["event_time", "principal", "command"], None),
    rc(11, "Untrusted compiled extension, CLR assembly, Java, or UDF",
       "scp-compiled-code",
       "Native/compiled code loaded into the engine — C function (PostgreSQL), UNSAFE CLR, Oracle Java, mysql.func (T1554/T1505).",
       T + ["native-code", "udf"], "high",
       "Verify provenance of compiled code; remove untrusted C functions; restrict who can create them.",
       ["schema", "routine", "owner"],
       "SELECT n.nspname AS schema, p.proname AS routine, r.rolname AS owner "
       "FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace "
       "JOIN pg_language l ON l.oid = p.prolang JOIN pg_roles r ON r.oid = p.proowner "
       f"WHERE l.lanname = 'c' AND {USERSCHEMA} ORDER BY n.nspname, p.proname"),
    rc(12, "ALTER DEFAULT PRIVILEGES auto-grant persistence",
       "scp-default-privileges",
       "A standing default-ACL rule that re-grants on every future object (T1098). PostgreSQL-specific.",
       T + ["default-privileges", "persistence"], "high",
       "Review pg_default_acl rules; revoke any that auto-grant to non-deploy principals.",
       ["schema", "object_type", "grantor", "acl"],
       "SELECT COALESCE(n.nspname,'(global)') AS schema, d.defaclobjtype AS object_type, "
       "pg_get_userbyid(d.defaclrole) AS grantor, d.defaclacl::text AS acl "
       "FROM pg_default_acl d LEFT JOIN pg_namespace n ON n.oid = d.defaclnamespace"),
    rc(13, "Trigger or routine planted on an authentication / system object",
       "scp-auth-object-trigger",
       "Positioned to harvest credentials or re-grant access (T1546/T1556). Vendor-specific (system-object triggers).",
       T + ["auth-object", "credential-harvest"], "high",
       "Identify triggers/routines on auth/system objects; remove; lock down system schema.",
       ["schema", "object_name", "kind"], None),
    rc(14, "Trusted routine tampered while preserving its signature",
       "scp-routine-tamper",
       "Body-hash drift from baseline with identity unchanged — the supply-chain replace (T1554). Needs dbx_routine_baseline.",
       T + ["tamper", "baseline-drift"], "high",
       "Diff routine bodies against the reviewed baseline; restore from source control; investigate the change.",
       ["schema", "routine", "baseline_hash", "current_hash"], None),
    rc(15, "Poisoned DB-driver / package",
       "scp-poisoned-driver",
       "An unexpected client running privileged DDL on first connection — DB-side fingerprint of a trojanized driver (T1195.001). Behavioral.",
       T + ["poisoned-driver", "first-connection"], "high",
       "Correlate first-connection privileged DDL with client/app fingerprints; pin trusted driver versions.",
       ["client", "principal", "command"], None),
    rc(16, "Backdoor superuser role or login created",
       "scp-backdoor-superuser",
       "A privileged principal off the administrative allow-list — rolsuper/rolcreaterole/rolbypassrls (T1136/T1098).",
       T + ["backdoor-account", "privesc"], "high",
       "Verify each privileged role against the admin allow-list; drop/disable unauthorised ones.",
       ["rolname", "rolsuper", "rolcreaterole", "rolbypassrls", "rolcanlogin"],
       "SELECT rolname, rolsuper, rolcreaterole, rolbypassrls, rolcanlogin FROM pg_roles "
       f"WHERE (rolsuper OR rolcreaterole OR rolbypassrls) AND rolname NOT IN {ALLOW} "
       "ORDER BY rolname"),
    rc(17, "Migration-window evasion via object-inventory drift",
       "scp-inventory-drift",
       "Reconciles live catalog vs deploy baseline to catch create-and-drop / back-dated objects. Needs dbx_object_baseline.",
       T + ["inventory-drift", "baseline"], "high",
       "Maintain an object-inventory baseline; investigate any drift not tied to an approved migration.",
       ["object_name", "drift"], None),
    rc(18, "Owner-spoofing — backdoor authored as the deploy role",
       "scp-owner-spoof-body",
       "Scans routine bodies for backdoor signatures regardless of owner (closes the SCP-002/003 owner-check evasion).",
       T + ["owner-spoof", "body-scan"], "high",
       "Body-signature match ignores owner; review every hit even if owned by the deploy role.",
       ["schema", "routine", "owner"],
       "SELECT n.nspname AS schema, p.proname AS routine, r.rolname AS owner "
       "FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace JOIN pg_roles r ON r.oid = p.proowner "
       f"WHERE {USERSCHEMA} AND p.prosrc ~* '(xp_cmdshell|copy[^;]*program|dblink|alter\\s+role|create\\s+role|grant\\s+)' "
       "ORDER BY n.nspname, p.proname"),
    rc(19, "Extension-install evasion via trust-flag flip or disabled audit",
       "scp-trust-flag-flip",
       "An untrusted PL re-flagged lanpltrusted=true, or a DDL-audit event trigger left disabled.",
       T + ["trust-flag", "audit-disable"], "high",
       "Reset the language trust flag; re-enable the disabled DDL-audit event trigger; investigate who changed it.",
       ["issue", "detail"],
       "SELECT 'trusted_flag_flip' AS issue, lanname AS detail FROM pg_language "
       "WHERE lanname IN ('plpythonu','plperlu','plpython3u','plsh') AND lanpltrusted "
       "UNION ALL SELECT 'disabled_event_trigger', evtname FROM pg_event_trigger WHERE evtenabled = 'D'"),
    rc(20, "Egress evasion via indirection (FDW / dblink / nested call)",
       "scp-egress-indirection",
       "Network reach laundered through a foreign-data-wrapper or database link rather than a direct http call (T1041).",
       T + ["egress", "fdw", "indirection"], "high",
       "Inventory foreign servers/wrappers; confirm each endpoint is sanctioned; drop unknown ones.",
       ["foreign_server", "wrapper", "owner"],
       "SELECT s.srvname AS foreign_server, w.fdwname AS wrapper, pg_get_userbyid(s.srvowner) AS owner "
       "FROM pg_foreign_server s JOIN pg_foreign_data_wrapper w ON w.oid = s.srvfdw ORDER BY s.srvname"),
    rc(21, "xp_cmdshell via wrapper or transient re-enable",
       "scp-xpcmdshell-wrapper",
       "SQL Server module bodies invoking xp_cmdshell under a non-xp_/sp_ wrapper name. SQL Server-specific.",
       T + ["xp-cmdshell", "sqlserver"], "high",
       "Scan SQL Server module definitions for wrapped xp_cmdshell; disable the feature; remove wrappers.",
       ["schema", "object_name"], None),
    rc(22, "Obfuscated logic-bomb — trigger date from a config table",
       "scp-logic-bomb-config",
       "Select-then-destroy where the detonation condition is read from a config table or computed at runtime (closes SCP-007 literal-date gap).",
       T + ["logic-bomb", "obfuscation"], "high",
       "Trace runtime-computed destruction conditions; review routines that read a value then DROP/DELETE.",
       ["schema", "routine", "owner"], None),
    rc(23, "Encrypted or wrapped routine body",
       "scp-encrypted-routine",
       "Routine created WITH ENCRYPTION (SQL Server) or wrapped PL/SQL (Oracle) defeats all body scans. Concealment is the finding (T1027). Vendor-specific.",
       T + ["encrypted-body", "obfuscation"], "high",
       "On application routines, treat deliberate concealment as suspicious; obtain and review the source.",
       ["schema", "routine"], None),
    rc(24, "Obfuscated dynamic-execution payload",
       "scp-obfuscated-execute",
       "A routine assembling its statement at runtime via decode(base64)/convert_from/chr()/translate()/|| into EXECUTE (T1027/T1140).",
       T + ["obfuscation", "dynamic-sql"], "high",
       "Review routines combining EXECUTE with decode/convert_from/chr/translate; de-obfuscate and assess.",
       ["schema", "routine", "owner"],
       "SELECT n.nspname AS schema, p.proname AS routine, r.rolname AS owner "
       "FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace JOIN pg_roles r ON r.oid = p.proowner "
       f"WHERE {USERSCHEMA} AND p.prosrc ~* 'execute' "
       "AND p.prosrc ~* '(decode\\(|convert_from|chr\\(|translate\\(|encode\\()' "
       "ORDER BY n.nspname, p.proname"),
    rc(25, "SECURITY DEFINER without a pinned search_path",
       "scp-secdef-no-searchpath",
       "A definer-rights routine with no search_path pinned — hijackable by any caller regardless of owner (T1548).",
       T + ["security-definer", "search-path"], "high",
       "Pin a safe search_path on every SECURITY DEFINER routine; revoke EXECUTE from PUBLIC where possible.",
       ["schema", "routine", "owner"],
       "SELECT n.nspname AS schema, p.proname AS routine, r.rolname AS owner "
       "FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace JOIN pg_roles r ON r.oid = p.proowner "
       f"WHERE p.prosecdef AND {USERSCHEMA} AND (p.proconfig IS NULL "
       "OR NOT EXISTS (SELECT 1 FROM unnest(p.proconfig) c WHERE c ILIKE 'search_path=%')) "
       "ORDER BY n.nspname, p.proname"),
    rc(26, "Privilege backdoor via role membership",
       "scp-priv-role-membership",
       "A principal made a member of pg_read_all_data / pg_execute_server_program / rds_superuser etc. — no rolsuper flag, so SCP-016 misses it (T1098).",
       T + ["role-membership", "privesc"], "high",
       "Review membership in powerful default roles; revoke from principals that don't need it.",
       ["member", "granted_role"],
       "SELECT m.rolname AS member, gr.rolname AS granted_role FROM pg_auth_members am "
       "JOIN pg_roles m ON m.oid = am.member JOIN pg_roles gr ON gr.oid = am.roleid "
       "WHERE gr.rolname IN ('pg_read_all_data','pg_write_all_data','pg_execute_server_program',"
       "'pg_read_server_files','pg_write_server_files','rds_superuser') ORDER BY gr.rolname, m.rolname"),
    rc(27, "Connection-time persistence via preload libraries / GUCs",
       "scp-preload-persistence",
       "A malicious *_preload_libraries setting loads attacker code on every connection — no object to find (T1546/T1574).",
       T + ["preload", "persistence", "guc"], "high",
       "Review preload-library settings; remove unknown libraries; restrict ALTER SYSTEM / superuser GUC changes.",
       ["name", "setting"],
       "SELECT name, setting FROM pg_settings "
       "WHERE name IN ('shared_preload_libraries','session_preload_libraries','local_preload_libraries') "
       "AND setting <> ''"),
    rc(28, "Routine & trigger inventory drift",
       "scp-routine-inventory-drift",
       "A function/trigger present in the live catalog but absent from the deploy baseline (evades owner checks). Needs dbx_routine_inventory_baseline.",
       T + ["inventory-drift", "baseline"], "high",
       "Maintain a routine/trigger inventory baseline; investigate any object not in it.",
       ["object_name", "kind"], None),
    rc(29, "High-privilege DEFINER routine in an app schema (MySQL/MariaDB)",
       "scp-mysql-definer",
       "A routine SQL SECURITY DEFINER with DEFINER=root/admin/mysql.sys living in an app schema (T1548). MySQL/MariaDB-specific.",
       T + ["security-definer", "mysql"], "high",
       "Re-define routines to a least-privilege account; avoid root/admin DEFINER in application schemas.",
       ["schema", "routine", "definer"], None),
    rc(30, "SQL Server startup-procedure persistence",
       "scp-mssql-startup-proc",
       "A procedure flagged via sp_procoption 'startup' auto-runs on every instance restart (T1505.001). SQL Server-specific.",
       T + ["startup-proc", "sqlserver"], "high",
       "List ExecIsStartup procedures; disable any not sanctioned; restrict sp_procoption.",
       ["schema", "procedure"], None),
    rc(31, "PostgreSQL command-executing GUC",
       "scp-command-guc",
       "A shell payload in archive_command/restore_command/etc. runs as the server OS user (T1059/T1546).",
       T + ["guc", "os-exec"], "high",
       "Review archive/recovery command GUCs; remove shell payloads; restrict ALTER SYSTEM.",
       ["name", "setting"],
       "SELECT name, setting FROM pg_settings "
       "WHERE name IN ('archive_command','restore_command','archive_cleanup_command',"
       "'recovery_end_command','ssl_passphrase_command') AND setting <> ''"),
    rc(32, "Self-healing event trigger",
       "scp-self-healing-trigger",
       "An event-trigger function that re-CREATEs the backdoor when dropped — can be deploy-owned (evades owner filters).",
       T + ["event-trigger", "self-heal"], "high",
       "Inspect event-trigger function bodies for re-plant DDL; remove the trigger and the object it recreates.",
       ["event_trigger", "function"],
       "SELECT e.evtname AS event_trigger, p.proname AS function FROM pg_event_trigger e "
       "JOIN pg_proc p ON p.oid = e.evtfoid "
       "WHERE p.prosrc ~* 'create\\s+(or\\s+replace\\s+)?(function|trigger|role|extension|event\\s+trigger)' "
       "ORDER BY e.evtname"),
    rc(33, "MySQL/MariaDB init_connect / init_file",
       "scp-mysql-init",
       "SQL auto-run on every connection or at startup via server variables — no schema object (T1546). MySQL/MariaDB-specific.",
       T + ["init-connect", "mysql"], "high",
       "Review init_connect / init_file values; clear unauthorised payloads; restrict SUPER/SYSTEM_VARIABLES_ADMIN.",
       ["variable", "value"], None),
    rc(34, "Oracle Scheduler-job persistence / time-bomb",
       "scp-oracle-scheduler",
       "A dba_scheduler_jobs entry with job_type=EXECUTABLE or dangerous job_action, optionally future-dated (T1053/T1059). Oracle-specific.",
       T + ["scheduler", "oracle"], "high",
       "Review scheduler jobs for EXECUTABLE/OS actions and future start dates; disable unauthorised jobs.",
       ["job_name", "job_type", "job_action"], None),
    rc(35, "Outbound foreign server / data wrapper",
       "scp-foreign-egress",
       "A foreign-data-wrapper server + user mapping (and foreign tables) to an off-allow-list endpoint — standing egress (T1041).",
       T + ["fdw", "egress"], "high",
       "Inventory foreign tables and their servers; confirm endpoints; drop unsanctioned foreign tables.",
       ["schema", "foreign_table", "foreign_server"],
       "SELECT n.nspname AS schema, c.relname AS foreign_table, s.srvname AS foreign_server "
       "FROM pg_foreign_table ft JOIN pg_class c ON c.oid = ft.ftrelid "
       "JOIN pg_namespace n ON n.oid = c.relnamespace JOIN pg_foreign_server s ON s.oid = ft.ftserver "
       "ORDER BY n.nspname, c.relname"),
    rc(36, "SQL Server Agent CmdExec / PowerShell job",
       "scp-mssql-agent-job",
       "An Agent job step using CmdExec/PowerShell/ActiveScripting/SSIS runs OS commands on a schedule without xp_cmdshell (T1053.005/T1059). SQL Server-specific.",
       T + ["agent-job", "sqlserver", "os-exec"], "high",
       "Review SQL Server Agent job steps for CmdExec/PowerShell subsystems; remove unauthorised jobs.",
       ["job_name", "step_name", "subsystem"], None),
]

# --- Other-vendor detection SQL for the vendor-specific SCP probes ----------
# Keyed by root_cause_id; merges into detect{} and widens the view columns.
VENDOR_FILL = {
    # SCP-021 xp_cmdshell under a wrapper (SQL Server)
    "SEC-SQL-SCP-021-RC01": {
        "columns": ["schema_name", "object_name", "type_desc"],
        "detect": {"sqlserver":
            "SELECT s.name AS schema_name, o.name AS object_name, o.type_desc "
            "FROM sys.sql_modules m JOIN sys.objects o ON o.object_id = m.object_id "
            "JOIN sys.schemas s ON s.schema_id = o.schema_id "
            "WHERE m.definition LIKE '%xp_cmdshell%' AND o.is_ms_shipped = 0 "
            "AND o.name NOT LIKE 'xp[_]%' AND o.name NOT LIKE 'sp[_]%'"}},
    # SCP-023 encrypted / wrapped routine body (SQL Server + Oracle)
    "SEC-SQL-SCP-023-RC01": {
        "columns": ["schema_name", "object_name", "type_desc", "owner", "name", "type"],
        "detect": {
            "sqlserver":
                "SELECT s.name AS schema_name, o.name AS object_name, o.type_desc "
                "FROM sys.objects o JOIN sys.schemas s ON s.schema_id = o.schema_id "
                "LEFT JOIN sys.sql_modules m ON m.object_id = o.object_id "
                "WHERE o.is_ms_shipped = 0 AND o.type IN ('P','FN','TF','IF','V','TR') "
                "AND m.object_id IS NULL",
            "oracle":
                "SELECT owner, name, type FROM dba_source WHERE line = 1 "
                "AND UPPER(text) LIKE '%WRAPPED%' "
                "AND owner NOT IN ('SYS','SYSTEM','SYSAUX')"}},
    # SCP-029 high-privilege DEFINER routine in an app schema (MySQL/MariaDB)
    "SEC-SQL-SCP-029-RC01": {
        "columns": ["schema_name", "routine_name", "definer", "security_type"],
        "detect": {"mysql":
            "SELECT routine_schema AS schema_name, routine_name, definer, security_type "
            "FROM information_schema.routines WHERE security_type = 'DEFINER' "
            "AND definer REGEXP '^(root|admin|mysql.sys)@' "
            "AND routine_schema NOT IN ('sys','mysql','performance_schema','information_schema')"}},
    # SCP-030 SQL Server startup-procedure persistence
    "SEC-SQL-SCP-030-RC01": {
        "columns": ["schema_name", "procedure_name"],
        "detect": {"sqlserver":
            "SELECT s.name AS schema_name, o.name AS procedure_name "
            "FROM sys.procedures p JOIN sys.objects o ON o.object_id = p.object_id "
            "JOIN sys.schemas s ON s.schema_id = o.schema_id "
            "WHERE OBJECTPROPERTY(p.object_id, 'ExecIsStartUp') = 1"}},
    # SCP-033 MySQL/MariaDB init_connect / init_file
    "SEC-SQL-SCP-033-RC01": {
        "columns": ["variable_name", "variable_value"],
        "detect": {"mysql":
            "SELECT variable_name, variable_value FROM performance_schema.global_variables "
            "WHERE variable_name IN ('init_connect','init_file') AND variable_value <> ''"}},
    # SCP-034 Oracle Scheduler-job persistence / time-bomb
    "SEC-SQL-SCP-034-RC01": {
        "columns": ["owner", "job_name", "job_type", "job_action", "start_date"],
        "detect": {"oracle":
            "SELECT owner, job_name, job_type, job_action, TO_CHAR(start_date) AS start_date "
            "FROM dba_scheduler_jobs WHERE owner NOT IN ('SYS','SYSTEM') "
            "AND (job_type = 'EXECUTABLE' OR REGEXP_LIKE(UPPER(job_action), 'HOST|DBMS_SCHEDULER|EXTERNAL'))"}},
    # SCP-036 SQL Server Agent CmdExec / PowerShell job
    "SEC-SQL-SCP-036-RC01": {
        "columns": ["job_name", "step_name", "subsystem", "command"],
        "detect": {"sqlserver":
            "SELECT j.name AS job_name, st.step_name, st.subsystem, st.command "
            "FROM msdb.dbo.sysjobs j JOIN msdb.dbo.sysjobsteps st ON st.job_id = j.job_id "
            "WHERE st.subsystem IN ('CmdExec','PowerShell','ActiveScripting','SSIS')"}},
}

_by_id = {r["rc"]: r for r in RCS}
for rc_id, fill in VENDOR_FILL.items():
    r = _by_id.get(rc_id)
    if not r:
        continue
    if "columns" in fill:
        r["columns"] = fill["columns"]
    r["detect"].update(fill["detect"])

SPEC = {
    "module": "supply_chain",
    "area_code": "SCP",
    "source": "PLANS/SUPPLY_CHAIN_DETECTION.md",
    "vendors": V,
    "root_causes": RCS,
}

if __name__ == "__main__":
    out = os.path.join(os.path.dirname(__file__), "supply_chain.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(SPEC, f, indent=2)
    pg = sum(1 for r in RCS if r["detect"]["postgresql"])
    print(f"wrote {out}: {len(RCS)} root causes, {pg} with PostgreSQL detection SQL, "
          f"{len(RCS) - pg} TODO (baseline/other-vendor)")
