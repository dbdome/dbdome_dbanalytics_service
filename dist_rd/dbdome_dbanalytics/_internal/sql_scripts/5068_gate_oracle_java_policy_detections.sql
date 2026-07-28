-- =============================================================================
-- 5068_gate_oracle_java_policy_detections.sql
-- CFG-004-RC07 (ora_check_dangerous_java_permissions) and
-- VS-002-RC09  (ora_check_java_permissions_grants) query DBA_JAVA_POLICY, which
-- only exists when the Oracle JVM (OJVM) is installed. On instances without it
-- the static reference fails at PARSE time -> ORA-00942 every collection cycle.
--
-- Gate: never reference DBA_JAVA_POLICY statically. Build the real query as a
-- dynamic string only when the view/synonym is present (ALL_OBJECTS check),
-- otherwise a 0-row dual query; run it through DBMS_XMLGEN.getXML and reshape
-- back to the original columns with XMLTABLE. Result:
--   * OJVM absent  -> 0 rows (no error, no false finding)
--   * OJVM present -> identical rows/columns as before
-- DBMS_XMLGEN executes as a plain SELECT (pandas read_sql_query compatible).
-- No '--' in the stored SQL, no trailing ';'. Idempotent.
-- =============================================================================

-- CFG-004-RC07 ---------------------------------------------------------------
UPDATE rootcause.detection_steps
SET content = jsonb_set(content, '{sql}', to_jsonb($q$SELECT x.grantee, x.type_name, x.name, x.action, x.enabled
FROM XMLTABLE('/ROWSET/ROW' PASSING
  XMLTYPE(NVL(DBMS_XMLGEN.getxml(
    CASE WHEN (SELECT COUNT(*) FROM all_objects WHERE object_name = 'DBA_JAVA_POLICY' AND object_type IN ('VIEW','SYNONYM')) > 0
         THEN q'[SELECT grantee, type_name, name, action, enabled FROM dba_java_policy WHERE type_name IN ('java.lang.RuntimePermission', 'java.io.FilePermission', 'java.net.SocketPermission') AND grantee NOT IN ('SYS','SYSTEM','JAVASYSPRIV') AND enabled = 'ENABLED' ORDER BY grantee, type_name]'
         ELSE q'[SELECT NULL AS grantee, NULL AS type_name, NULL AS name, NULL AS action, NULL AS enabled FROM dual WHERE 1=0]'
    END), '<ROWSET/>'))
  COLUMNS grantee   VARCHAR2(128)  PATH 'GRANTEE',
          type_name VARCHAR2(256)  PATH 'TYPE_NAME',
          name      VARCHAR2(4000) PATH 'NAME',
          action    VARCHAR2(256)  PATH 'ACTION',
          enabled   VARCHAR2(40)   PATH 'ENABLED') x$q$::text))
WHERE vendor_slug='oracle' AND name='ora_check_dangerous_java_permissions';

-- VS-002-RC09 ----------------------------------------------------------------
UPDATE rootcause.detection_steps
SET content = jsonb_set(content, '{sql}', to_jsonb($q$SELECT x.grantee, x.type_name, x.name, x.action
FROM XMLTABLE('/ROWSET/ROW' PASSING
  XMLTYPE(NVL(DBMS_XMLGEN.getxml(
    CASE WHEN (SELECT COUNT(*) FROM all_objects WHERE object_name = 'DBA_JAVA_POLICY' AND object_type IN ('VIEW','SYNONYM')) > 0
         THEN q'[SELECT grantee, type_name, name, action FROM dba_java_policy WHERE grantee NOT IN ('SYS', 'SYSTEM', 'PUBLIC') AND type_name IN ('java.io.FilePermission', 'java.net.SocketPermission', 'java.lang.RuntimePermission') AND action NOT LIKE '%read%' ORDER BY grantee, type_name]'
         ELSE q'[SELECT NULL AS grantee, NULL AS type_name, NULL AS name, NULL AS action FROM dual WHERE 1=0]'
    END), '<ROWSET/>'))
  COLUMNS grantee   VARCHAR2(128)  PATH 'GRANTEE',
          type_name VARCHAR2(256)  PATH 'TYPE_NAME',
          name      VARCHAR2(4000) PATH 'NAME',
          action    VARCHAR2(256)  PATH 'ACTION') x$q$::text))
WHERE vendor_slug='oracle' AND name='ora_check_java_permissions_grants';

-- VERIFY: both now gate via ALL_OBJECTS + XMLTABLE (no static DBA_JAVA_POLICY FROM)
SELECT name,
       CASE WHEN content->>'sql' ~* 'xmltable' AND content->>'sql' ~* 'all_objects'
            THEN 'gated' ELSE 'NOT-GATED' END AS state
FROM rootcause.detection_steps
WHERE vendor_slug='oracle'
  AND name IN ('ora_check_dangerous_java_permissions','ora_check_java_permissions_grants')
ORDER BY name;
