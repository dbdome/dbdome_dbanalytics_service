-- View: monitoring.v_hlth_sql_ad_001_rc14

-- DROP VIEW monitoring.v_hlth_sql_ad_001_rc14;

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_001_rc14
 AS
 SELECT r.server,
    (j.value ->> 'host_name'::text) AS host_name,
    (j.value ->> 'idle_hours'::text) AS idle_hours,
    (j.value ->> 'last_request_end_time'::text) AS last_request_end_time,
    (j.value ->> 'login_time'::text) AS login_time,
    (j.value ->> 'program_name'::text) AS program_name,
    (j.value ->> 'session_id'::text) AS session_id,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'HLTH-SQL-AD-001-RC14'::text);

ALTER TABLE IF EXISTS monitoring.v_hlth_sql_ad_001_rc14
    OWNER TO enterprisedb;





-- ============================================================
  -- Auto-generate and execute views for all metrics
  -- in monitoring.general_metric_metadata_results
  -- Run against dbanalytics (EDB AS 17, port 5444)
  -- ============================================================
  DO $$
  DECLARE
      rec RECORD;
      v_sql TEXT;
  BEGIN
      FOR rec IN (
          WITH metric_keys AS (
              SELECT DISTINCT
                  r.metric_name,
                  j.key
              FROM monitoring.general_metric_metadata_results r
              CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata::jsonb) elem(value)
              CROSS JOIN LATERAL jsonb_each_text(elem.value) j(key, value)
              WHERE r.entry_date = (
                  SELECT max(r2.entry_date)
                  FROM monitoring.general_metric_metadata_results r2
                  WHERE r2.metric_name = r.metric_name 
              )
          ),
          view_columns AS (
              SELECT
                  metric_name,
                  string_agg(
                      '    (j.value ->> ' || quote_literal(key) || ') AS ' || quote_ident(key),
                      E',\n'
                      ORDER BY key
                  ) AS col_list
              FROM metric_keys
              GROUP BY metric_name
          )
          SELECT
              metric_name,
              'monitoring.v_' || lower(replace(replace(metric_name, '-', '_'), ' ', '_')) AS vname,
              col_list
          FROM view_columns
          ORDER BY metric_name
      ) LOOP
          v_sql := 'CREATE OR REPLACE VIEW ' || rec.vname || E' AS\n' ||
                   E' SELECT r.server,\n' ||
                   rec.col_list || E',\n' ||
                   E'    r.entry_date\n' ||
                   E'   FROM monitoring.general_metric_metadata_results r\n' ||
                   E'     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata::jsonb) j(value)\n' ||
                   E'  WHERE (r.metric_name)::text = ' || quote_literal(rec.metric_name);

          EXECUTE v_sql;

          EXECUTE 'ALTER TABLE IF EXISTS ' || rec.vname || ' OWNER TO enterprisedb';

          RAISE NOTICE 'Created view: %', rec.vname;
      END LOOP;
  END $$;



   UPDATE rootcause.detection_steps
  SET content = jsonb_set(content::jsonb, '{sql}', to_jsonb(
      'SELECT s1.sid AS sid_a, s1.username AS user_a, s2.sid AS sid_b, s2.username AS user_b, s1.event AS wait_event, sq1.sql_text AS query_a, sq2.sql_text AS query_b FROM v$session s1 JOIN v$session s2 ON
  s1.blocking_session = s2.sid AND s2.blocking_session = s1.sid LEFT JOIN v$sqlarea sq1 ON s1.sql_id = sq1.sql_id LEFT JOIN v$sqlarea sq2 ON s2.sql_id = sq2.sql_id WHERE s1.blocking_session IS NOT NULL AND
  s2.blocking_session IS NOT NULL'::text
  ))
  WHERE id IN (
      SELECT ds.id FROM rootcause.detection_steps ds
      JOIN rootcause.detection_path_steps dps ON dps.detection_step_id = ds.id
      JOIN rootcause.detection_paths dp ON dp.id = dps.detection_path_id
      WHERE ds.content::text LIKE '%INNODB_LOCK_WAITS%'
        AND ds.vendor_slug = 'oracle'
  );
  UPDATE rootcause.detection_steps
  SET content = jsonb_set(content::jsonb, '{sql}', to_jsonb(
      'SELECT value AS isolation_level FROM v$parameter WHERE name = ''transaction_isolation'''::text
  ))
  WHERE id IN (
      SELECT ds.id FROM rootcause.detection_steps ds
      JOIN rootcause.detection_path_steps dps ON dps.detection_step_id = ds.id
      JOIN rootcause.detection_paths dp ON dp.id = dps.detection_path_id
      WHERE ds.content::text LIKE '%information_schema.GLOBAL_VARIABLES%'
        AND ds.vendor_slug = 'oracle'
  );
  
UPDATE rootcause.detection_steps
  SET content = jsonb_set(content::jsonb, '{sql}', to_jsonb(
      'SELECT c.constraint_name, c.owner AS table_schema, c.table_name AS child_table, cc.column_name AS child_column, r.table_name AS parent_table, rc.column_name AS parent_column, c.delete_rule FROM
  all_constraints c JOIN all_cons_columns cc ON cc.constraint_name = c.constraint_name AND cc.owner = c.owner JOIN all_constraints r ON r.constraint_name = c.r_constraint_name AND r.owner = c.r_owner JOIN
  all_cons_columns rc ON rc.constraint_name = r.constraint_name AND rc.owner = r.owner AND rc.position = cc.position WHERE c.constraint_type = ''R'' AND c.owner NOT IN (''SYS'', ''SYSTEM'', ''MDSYS'',
  ''CTXSYS'', ''XDB'') ORDER BY c.table_name'::text
  ))
  WHERE id IN (
      SELECT ds.id FROM rootcause.detection_steps ds
      JOIN rootcause.detection_path_steps dps ON dps.detection_step_id = ds.id
      JOIN rootcause.detection_paths dp ON dp.id = dps.detection_path_id
      WHERE ds.content::text LIKE '%KEY_COLUMN_USAGE%REFERENTIAL_CONSTRAINTS%'
        AND ds.vendor_slug = 'oracle'
  );
   UPDATE rootcause.detection_steps
  SET content = jsonb_set(content::jsonb, '{sql}', to_jsonb(
      'SELECT value AS deadlock_count FROM v$sysstat WHERE name = ''enqueue deadlocks'''::text
  ))
  WHERE id IN (
      SELECT ds.id FROM rootcause.detection_steps ds
      JOIN rootcause.detection_path_steps dps ON dps.detection_step_id = ds.id
      JOIN rootcause.detection_paths dp ON dp.id = dps.detection_path_id
      WHERE ds.content::text LIKE '%GLOBAL_STATUS%Innodb_deadlocks%'
        AND ds.vendor_slug = 'oracle'
  );

  UPDATE rootcause.detection_steps
  SET content = jsonb_set(content::jsonb, '{sql}', to_jsonb(
      'SELECT c.constraint_name, c.owner AS table_schema, c.table_name AS child_table, cc.column_name AS child_column, r.table_name AS parent_table, rc.column_name AS parent_column, c.delete_rule FROM
  all_constraints c JOIN all_cons_columns cc ON cc.constraint_name = c.constraint_name AND cc.owner = c.owner JOIN all_constraints r ON r.constraint_name = c.r_constraint_name AND r.owner = c.r_owner JOIN
  all_cons_columns rc ON rc.constraint_name = r.constraint_name AND rc.owner = r.owner AND rc.position = cc.position WHERE c.constraint_type = ''R'' AND c.owner NOT IN (''SYS'', ''SYSTEM'', ''MDSYS'',
  ''CTXSYS'', ''XDB'') ORDER BY c.table_name'::text
  ))
  WHERE id IN (
      SELECT ds.id FROM rootcause.detection_steps ds
      JOIN rootcause.detection_path_steps dps ON dps.detection_step_id = ds.id
      JOIN rootcause.detection_paths dp ON dp.id = dps.detection_path_id
      WHERE ds.content::text LIKE '%KEY_COLUMN_USAGE%REFERENTIAL_CONSTRAINTS%'
        AND ds.vendor_slug = 'oracle'
  );
   UPDATE rootcause.detection_steps
  SET content = jsonb_set(content::jsonb, '{sql}', to_jsonb(
      'SELECT value AS deadlock_count FROM v$sysstat WHERE name = ''enqueue deadlocks'''::text
  ))
  WHERE id IN (
      SELECT ds.id FROM rootcause.detection_steps ds
      JOIN rootcause.detection_path_steps dps ON dps.detection_step_id = ds.id
      JOIN rootcause.detection_paths dp ON dp.id = dps.detection_path_id
      WHERE ds.content::text LIKE '%GLOBAL_STATUS%Innodb_deadlocks%'
        AND ds.vendor_slug = 'oracle'
  );
  -- 1. Row lock waits/time
  UPDATE rootcause.detection_steps
  SET content = jsonb_set(content::jsonb, '{sql}', to_jsonb(
      'SELECT s1.value AS row_lock_waits, s2.value AS row_lock_time_ms FROM v$sysstat s1, v$sysstat s2 WHERE s1.name = ''enqueue waits'' AND s2.name = ''enqueue timeouts'''::text
  ))
  WHERE id IN (
      SELECT ds.id FROM rootcause.detection_steps ds
      JOIN rootcause.detection_path_steps dps ON dps.detection_step_id = ds.id
      JOIN rootcause.detection_paths dp ON dp.id = dps.detection_path_id
      WHERE ds.content::text LIKE '%Innodb_row_lock_waits%'
        AND ds.vendor_slug = 'oracle'
  );

  -- 2. Lock table/index waiter count
  UPDATE rootcause.detection_steps
  SET content = jsonb_set(content::jsonb, '{sql}', to_jsonb(
      'SELECT o.object_name AS lock_table, l.type AS lock_type, COUNT(*) AS waiter_count FROM v$lock l JOIN dba_objects o ON o.object_id = l.id1 WHERE l.request > 0 GROUP BY o.object_name, l.type ORDER BY
  waiter_count DESC FETCH FIRST 10 ROWS ONLY'::text
  ))
  WHERE id IN (
      SELECT ds.id FROM rootcause.detection_steps ds
      JOIN rootcause.detection_path_steps dps ON dps.detection_step_id = ds.id
      JOIN rootcause.detection_paths dp ON dp.id = dps.detection_path_id
      WHERE ds.content::text LIKE '%INNODB_LOCKS%GROUP BY lock_table, lock_index%'
        AND ds.vendor_slug = 'oracle'
  );

  -- 3. Lock count by table (PRIMARY/TABLE)
  UPDATE rootcause.detection_steps
  SET content = jsonb_set(content::jsonb, '{sql}', to_jsonb(
      'SELECT o.object_name AS lock_table, l.type AS lock_type, COUNT(*) AS lock_count FROM v$lock l JOIN dba_objects o ON o.object_id = l.id1 WHERE l.block > 0 GROUP BY o.object_name, l.type ORDER BY
  lock_count DESC FETCH FIRST 20 ROWS ONLY'::text
  ))
  WHERE id IN (
      SELECT ds.id FROM rootcause.detection_steps ds
      JOIN rootcause.detection_path_steps dps ON dps.detection_step_id = ds.id
      JOIN rootcause.detection_paths dp ON dp.id = dps.detection_path_id
      WHERE ds.content::text LIKE '%INNODB_LOCKS l%PRIMARY%lock_count DESC%'
        AND ds.vendor_slug = 'oracle'
  );

  -- 4. Transactions in LOCK WAIT
  UPDATE rootcause.detection_steps
  SET content = jsonb_set(content::jsonb, '{sql}', to_jsonb(
      'SELECT s.sid AS trx_id, s.status AS trx_state, s.logon_time AS trx_started, s.seconds_in_wait AS wait_seconds, sq.sql_text AS trx_query FROM v$session s LEFT JOIN v$sqlarea sq ON s.sql_id = sq.sql_id
  WHERE s.blocking_session IS NOT NULL AND s.status = ''ACTIVE'' ORDER BY s.seconds_in_wait DESC'::text
  ))
  WHERE id IN (
      SELECT ds.id FROM rootcause.detection_steps ds
      JOIN rootcause.detection_path_steps dps ON dps.detection_step_id = ds.id
      JOIN rootcause.detection_paths dp ON dp.id = dps.detection_path_id
      WHERE ds.content::text LIKE '%INNODB_TRX%LOCK WAIT%'
        AND ds.vendor_slug = 'oracle'
  );

  -- 5. Locks with FK references
  UPDATE rootcause.detection_steps
  SET content = jsonb_set(content::jsonb, '{sql}', to_jsonb(
      'SELECT o.object_name AS lock_table, c.table_name AS fk_table, c.constraint_name, r.table_name AS referenced_table FROM v$lock l JOIN dba_objects o ON o.object_id = l.id1 JOIN all_constraints c ON
  c.table_name = o.object_name AND c.constraint_type = ''R'' JOIN all_constraints r ON r.constraint_name = c.r_constraint_name AND r.owner = c.r_owner WHERE l.block > 0'::text
  ))
  WHERE id IN (
      SELECT ds.id FROM rootcause.detection_steps ds
      JOIN rootcause.detection_path_steps dps ON dps.detection_step_id = ds.id
      JOIN rootcause.detection_paths dp ON dp.id = dps.detection_path_id
      WHERE ds.content::text LIKE '%INNODB_LOCKS%KEY_COLUMN_USAGE%REFERENCED_TABLE_NAME%'
        AND ds.vendor_slug = 'oracle'
  );

update rootcause.resolution_steps set  risk_level = 'Critical' where id in
(
SELECT
--    rc.root_cause_id,
  --  rpst.risk_level , 
	rpst.id
   FROM (((((((((((rootcause.issues i
     JOIN rootcause.domains d ON (((d.code)::text = (i.domain_code)::text)))
     JOIN rootcause.areas a ON (((a.code)::text = (i.area_code)::text)))
     JOIN rootcause.root_causes rc ON (((rc.issue_id)::text = (i.issue_id)::text)))
     JOIN rootcause.detection_paths dp ON (((dp.root_cause_id)::text = (rc.root_cause_id)::text)))
     JOIN rootcause.detection_path_steps stpstp ON ((stpstp.detection_path_id = dp.id)))
     JOIN rootcause.detection_steps stps ON ((stps.id = stpstp.detection_step_id)))
     JOIN rootcause.vendors v ON (((v.slug)::text = (stps.vendor_slug)::text)))
     JOIN rootcause.resolution_paths rp ON (((rp.root_cause_id)::text = (rc.root_cause_id)::text)))
     JOIN rootcause.resolution_path_steps rpstp ON ((rpstp.resolution_path_id = rp.id)))
     JOIN rootcause.resolution_steps rpst ON ((rpst.id = rpstp.resolution_step_id)))
     JOIN rootcause.risk_level rl ON ((rl.risk_level = (rp.risk_level)::bpchar)))
  WHERE ((d.is_enabled IS TRUE) AND (a.is_enabled IS TRUE) and rc.root_cause_id like 'SEC-SQL-AUD-013%')
)
