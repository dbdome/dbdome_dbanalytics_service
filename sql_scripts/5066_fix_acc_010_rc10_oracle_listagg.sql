-- =============================================================================
-- 5066_fix_acc_010_rc10_oracle_listagg.sql
-- SEC-SQL-ACC-010-RC10 (oracle) "Detect same login active from multiple hosts"
-- used LISTAGG(DISTINCT ...), which Oracle only supports on 19c+ -> ORA-30482 on
-- older releases. Rewrite to de-duplicate in subqueries and use plain LISTAGG, so
-- it runs on Oracle 11g/12c+ as well. Output columns/semantics unchanged
-- (login_name, host_count, hosts, session_count, queries). No '--' comments in
-- the stored SQL, no trailing ';'. Idempotent.
-- =============================================================================
UPDATE rootcause.detection_steps
SET content = jsonb_set(content, '{sql}', to_jsonb($ora$WITH sess AS (
  SELECT s.username, s.machine, SUBSTR(q.sql_text, 1, 500) AS sql_snip
  FROM gv$session s
  LEFT JOIN gv$sql q ON q.sql_id = s.sql_id AND q.inst_id = s.inst_id
  WHERE s.username IS NOT NULL AND s.type = 'USER' AND s.machine IS NOT NULL
),
agg AS (
  SELECT username, COUNT(DISTINCT machine) AS host_count, COUNT(*) AS session_count
  FROM sess
  GROUP BY username
  HAVING COUNT(DISTINCT machine) > 1
),
hosts AS (
  SELECT username, LISTAGG(machine, ', ') WITHIN GROUP (ORDER BY machine) AS hosts
  FROM (SELECT DISTINCT username, machine FROM sess)
  GROUP BY username
),
qrys AS (
  SELECT username, LISTAGG(sql_snip, ' | ') WITHIN GROUP (ORDER BY sql_snip) AS queries
  FROM (SELECT DISTINCT username, sql_snip FROM sess WHERE sql_snip IS NOT NULL)
  GROUP BY username
)
SELECT a.username AS login_name,
       a.host_count,
       h.hosts,
       a.session_count,
       q.queries
FROM agg a
JOIN hosts h ON h.username = a.username
LEFT JOIN qrys q ON q.username = a.username
ORDER BY a.host_count DESC$ora$::text))
WHERE vendor_slug = 'oracle'
  AND name = 'Detect same login active from multiple hosts';

-- VERIFY: no LISTAGG(DISTINCT remains for this oracle step
SELECT name,
       CASE WHEN content->>'sql' ~* 'listagg\s*\(\s*distinct' THEN 'STILL-HAS-LISTAGG-DISTINCT' ELSE 'fixed' END AS state
FROM rootcause.detection_steps
WHERE vendor_slug='oracle' AND name='Detect same login active from multiple hosts';
