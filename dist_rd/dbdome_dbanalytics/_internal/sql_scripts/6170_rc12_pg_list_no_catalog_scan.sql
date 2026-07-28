-- =============================================================================
-- 6170_rc12_pg_list_no_catalog_scan.sql
-- SEC-SQL-PRI-001-RC12 (sqlserver) times out (HYT00) for the same reason RC15
-- did: it builds #sensitive_cols by looping `USE <db>; ... sys.columns` across
-- every database, every cycle, inside the 5s SEC sweep. RC12 is pure INVENTORY
-- (it just returns the sensitive-column list) -- so it should read the list
-- from Postgres, not rescan the target's catalogs.
--
-- Fix: seed #sensitive_cols from the collector-injected PG list
-- (metrics.v_sensitive_columns_all = curated UNION auto-discovered) via the
-- /*__SENSITIVE_COLS_VALUES__*/ placeholder -- the same mechanism as 6160. No
-- catalog scan runs. data_type / max_length are not carried by the PG list, so
-- they are returned as NULL (output column shape is preserved).
--
-- Fail-safe: the VALUES list has a sentinel first row + the injection comment.
-- If the collector hook is not deployed (or the list is empty) the SQL is still
-- valid T-SQL and returns zero rows (sentinel filtered out) -- never a scan,
-- never a timeout.
--
-- Targeted portably via the detection-path chain (the step is named
-- "Discover sensitive columns in schema (sqlserver)", not "...RC12", and
-- detection_steps.id is per-install), scoped to the catalog-scan step only.
-- No '--' comments inside the stored SQL (v_custom_metrics flattens \n->space).
-- Idempotent.
-- =============================================================================
UPDATE rootcause.detection_steps ds
SET content = ds.content || jsonb_build_object('sql', $rc12sql$SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#sensitive_cols') IS NOT NULL DROP TABLE #sensitive_cols;
CREATE TABLE #sensitive_cols (
    db_name      nvarchar(128) NULL,
    schema_name  nvarchar(128) NULL,
    table_name   nvarchar(128) NULL,
    column_name  nvarchar(128) NULL,
    data_type    sysname       NULL,
    max_length   smallint      NULL,
    pii_category nvarchar(50)  NULL
);

INSERT INTO #sensitive_cols (db_name, schema_name, table_name, column_name, pii_category)
SELECT db_name, schema_name, table_name, column_name, pii_category
FROM (VALUES
    (CAST(NULL AS nvarchar(128)), CAST(NULL AS nvarchar(128)), CAST(N'~~no_sensitive_list~~' AS nvarchar(128)), CAST(N'~~' AS nvarchar(128)), CAST(NULL AS nvarchar(50)))
    /*__SENSITIVE_COLS_VALUES__*/
) v(db_name, schema_name, table_name, column_name, pii_category)
WHERE table_name IS NOT NULL;

SELECT db_name, schema_name, table_name, column_name, data_type, max_length, pii_category
FROM #sensitive_cols
WHERE table_name <> N'~~no_sensitive_list~~'
ORDER BY pii_category, db_name, schema_name, table_name, column_name;$rc12sql$)
FROM rootcause.detection_paths dp
JOIN rootcause.detection_path_steps dps ON dps.detection_path_id = dp.id
WHERE dps.detection_step_id = ds.id
  AND dp.root_cause_id = 'SEC-SQL-PRI-001-RC12'
  AND ds.vendor_slug   = 'sqlserver'
  AND ds.content->>'sql' LIKE '%sys.databases%';
