-- =============================================================================
-- 7460_pgvector_vec_detections.sql
--
-- pgvector detections + resolutions for the VEC (vector-database) taxonomy.
-- Makes 27 PERF-VEC / SEC-VEC / HLTH-VEC root causes visible to
-- rootcause.v_rootcauses -> metrics.v_custom_metrics, and collectable by the
-- existing PostgreSQL generic collector.
--
-- VENDOR IS 'postgresql', NOT A STANDALONE VECTOR ENGINE. That matches the 4
-- VEC detection paths already in the catalog (SEC-VEC-LOG-001/002,
-- SEC-VEC-AUTH-002, SEC-VEC-DAT-002), which are all postgresql: the VEC tier is
-- authored against pgvector. No new vendor row and no new collector is needed --
-- rootcause.vendors' chromadb/milvus/qdrant/weaviate rows stay untouched and
-- uncovered, since dbdiagnostics has no connector for those engines.
--
-- Before this file, VEC had 4 of 872 root causes carrying detection logic, and
-- NONE carried a resolution path -- and v_rootcauses INNER JOINs both chains, so
-- even those 4 were invisible end-to-end.
--
-- ROOT-CAUSE RESOLUTION IS DONE HERE, NOT AT AUTHORING TIME: each entry names an
-- ISSUE, and the DO block below binds it to the first root cause under that issue
-- which does not already carry a postgresql detection path. So the 4 existing
-- paths are never disturbed, and the file adapts to catalogs whose root-cause
-- numbering differs.
--
-- Every query was executed against a live PostgreSQL 18.4 + pgvector 0.8.6
-- database holding real 384-dimension embeddings with HNSW and IVFFlat indexes,
-- passed processes/sql_safety.validate_readonly under the postgres dialect, and
-- every column-level condition evaluated to a definite verdict.
--
-- Add-only and idempotent: an issue is skipped once it has a postgresql path
-- created by this file, so re-runs are no-ops.
-- =============================================================================
-- NOTE: `\set ON_ERROR_STOP on` removed. It is a psql CLIENT directive; this file is
-- applied by processes/sql_script_runner.py through psycopg2, which cannot parse a
-- backslash command and failed the whole script on it ("syntax error at or near \"\\\"").
-- The behaviour it asked for is already guaranteed: the runner executes each file in one
-- transaction and rolls the whole file back on the first error.

BEGIN;

CREATE TEMP TABLE _vec_seed (
    issue_id text, sql text, cond text, descr text,
    risk text, res_name text, res_text text
);

INSERT INTO _vec_seed VALUES ($vec$PERF-VEC-IDX-005$vec$,$vec$SELECT n.nspname AS schema_name, c.relname AS table_name, a.attname AS column_name,
            a.atttypmod AS dimensions
       FROM pg_attribute a
       JOIN pg_class c ON c.oid = a.attrelid
       JOIN pg_namespace n ON n.oid = c.relnamespace
       JOIN pg_type t ON t.oid = a.atttypid
      WHERE t.typname = 'vector' AND a.attnum > 0 AND NOT a.attisdropped
        AND c.relkind = 'r' AND n.nspname NOT IN ('pg_catalog','information_schema')
      ORDER BY 1,2,3$vec$,$vec$row_count > 0$vec$,$vec$Vector columns and their dimensionality - differing dimensions across tables break shared embedding pipelines$vec$,$vec$medium$vec$,$vec$Standardise embedding dimensionality$vec$,$vec$Every column fed by the same embedding model must declare the same dimension. A mismatch means either a second model in use or a migration that was never finished; re-embed the divergent table rather than casting at query time.$vec$);
INSERT INTO _vec_seed VALUES ($vec$PERF-VEC-IDX-002$vec$,$vec$SELECT n.nspname AS schema_name, c.relname AS table_name, i.relname AS index_name,
            c.reltuples::bigint AS approx_rows,
            substring(pg_get_indexdef(i.oid) from 'lists\s*=\s*([0-9]+)') AS lists
       FROM pg_class i
       JOIN pg_index x ON x.indexrelid = i.oid
       JOIN pg_class c ON c.oid = x.indrelid
       JOIN pg_namespace n ON n.oid = c.relnamespace
       JOIN pg_am am ON am.oid = i.relam
      WHERE am.amname = 'ivfflat'
        AND c.reltuples > 1000
        AND COALESCE(substring(pg_get_indexdef(i.oid) from 'lists\s*=\s*([0-9]+)')::int, 1)
            < GREATEST(1, (c.reltuples / 1000)::int)
      ORDER BY 4 DESC$vec$,$vec$row_count > 0$vec$,$vec$IVFFlat indexes with too few lists for their row count - recall collapses because each probe scans a huge partition$vec$,$vec$high$vec$,$vec$Rebuild the IVFFlat index with a proper list count$vec$,$vec$The usual starting point is rows/1000 lists for up to a million rows, then sqrt(rows) beyond that. Too few lists makes every probe scan an oversized partition; too many starves each one. Rebuild with REINDEX after changing it, and retune ivfflat.probes to match.$vec$);
INSERT INTO _vec_seed VALUES ($vec$PERF-VEC-IDX-001$vec$,$vec$SELECT n.nspname AS schema_name, c.relname AS table_name, i.relname AS index_name,
            COALESCE(substring(pg_get_indexdef(i.oid) from 'm\s*=\s*([0-9]+)'), '16') AS m,
            COALESCE(substring(pg_get_indexdef(i.oid) from 'ef_construction\s*=\s*([0-9]+)'), '64') AS ef_construction,
            c.reltuples::bigint AS approx_rows
       FROM pg_class i
       JOIN pg_index x ON x.indexrelid = i.oid
       JOIN pg_class c ON c.oid = x.indrelid
       JOIN pg_namespace n ON n.oid = c.relnamespace
       JOIN pg_am am ON am.oid = i.relam
      WHERE am.amname = 'hnsw'
      ORDER BY 6 DESC$vec$,$vec$row_count > 0$vec$,$vec$HNSW indexes with their m / ef_construction - low values give a sparse graph and poor recall$vec$,$vec$medium$vec$,$vec$Raise m / ef_construction where recall is short$vec$,$vec$m controls graph connectivity and ef_construction the build-time search width. Defaults (16/64) suit moderate sets; high-dimensional or large collections usually need m=32 and ef_construction=128+. Both are build-time only, so changing them means a REINDEX.$vec$);
INSERT INTO _vec_seed VALUES ($vec$PERF-VEC-IDX-004$vec$,$vec$SELECT s.schemaname, s.relname AS table_name, s.n_mod_since_analyze,
            s.n_live_tup, s.last_analyze, s.last_autoanalyze
       FROM pg_stat_user_tables s
      WHERE EXISTS (
              SELECT 1 FROM pg_attribute a JOIN pg_type t ON t.oid = a.atttypid
               WHERE a.attrelid = s.relid AND t.typname = 'vector'
                 AND a.attnum > 0 AND NOT a.attisdropped)
        AND s.n_mod_since_analyze > GREATEST(1000, s.n_live_tup / 10)
      ORDER BY s.n_mod_since_analyze DESC$vec$,$vec$row_count > 0$vec$,$vec$Vector tables modified far beyond their last ANALYZE - the planner is costing vector scans on stale estimates$vec$,$vec$medium$vec$,$vec$ANALYZE the vector tables$vec$,$vec$Run ANALYZE on the listed tables and tighten autovacuum_analyze_scale_factor for them. Stale statistics make the planner mis-cost the index scan and fall back to a sequential scan over every embedding.$vec$);
INSERT INTO _vec_seed VALUES ($vec$PERF-VEC-QRY-002$vec$,$vec$SELECT s.schemaname, s.relname AS table_name, s.seq_scan, s.idx_scan,
            s.n_live_tup, s.seq_tup_read
       FROM pg_stat_user_tables s
      WHERE EXISTS (
              SELECT 1 FROM pg_attribute a JOIN pg_type t ON t.oid = a.atttypid
               WHERE a.attrelid = s.relid AND t.typname = 'vector'
                 AND a.attnum > 0 AND NOT a.attisdropped)
        AND s.seq_scan > COALESCE(s.idx_scan, 0)
      ORDER BY s.seq_scan DESC$vec$,$vec$row_count > 0$vec$,$vec$Vector tables read more often by sequential scan than by index - pre-filtering or a missing index is defeating the ANN path$vec$,$vec$high$vec$,$vec$Restore the index path for these searches$vec$,$vec$A selective WHERE clause applied before the ANN search makes PostgreSQL prefer a sequential scan. Add a matching partial or composite index, or raise the candidate list (hnsw.ef_search / ivfflat.probes) and filter afterwards instead.$vec$);
INSERT INTO _vec_seed VALUES ($vec$PERF-VEC-QRY-003$vec$,$vec$SELECT name, setting, unit, boot_val, reset_val FROM pg_settings WHERE name LIKE 'ivfflat%' OR name LIKE 'hnsw%'$vec$,$vec$row_count > 0$vec$,$vec$pgvector search-time settings (ivfflat.probes / hnsw.ef_search) that trade recall against latency$vec$,$vec$medium$vec$,$vec$Tune probes / ef_search to the recall you need$vec$,$vec$ivfflat.probes defaults to 1, which searches a single partition and usually under-recalls. Raise it toward sqrt(lists), and raise hnsw.ef_search above the default 40 where recall matters more than latency. Both are session-settable, so they can be tuned per workload.$vec$);
INSERT INTO _vec_seed VALUES ($vec$PERF-VEC-DIM-001$vec$,$vec$SELECT n.nspname AS schema_name, c.relname AS table_name, a.attname AS column_name,
            a.atttypmod AS dimensions, c.reltuples::bigint AS approx_rows
       FROM pg_attribute a
       JOIN pg_class c ON c.oid = a.attrelid
       JOIN pg_namespace n ON n.oid = c.relnamespace
       JOIN pg_type t ON t.oid = a.atttypid
      WHERE t.typname = 'vector' AND a.attnum > 0 AND NOT a.attisdropped
        AND a.atttypmod > 1024
      ORDER BY a.atttypmod DESC$vec$,$vec$row_count > 0$vec$,$vec$Vector columns above 1024 dimensions - distance cost grows linearly and index quality degrades$vec$,$vec$medium$vec$,$vec$Reduce dimensionality$vec$,$vec$Above roughly 1024 dimensions both distance computation and graph quality suffer, and pgvector cannot index beyond 2000. Use a model with fewer dimensions, or apply Matryoshka truncation / PCA before storing.$vec$);
INSERT INTO _vec_seed VALUES ($vec$PERF-VEC-MEM-001$vec$,$vec$SELECT n.nspname AS schema_name, c.relname AS table_name, i.relname AS index_name,
            pg_relation_size(i.oid) AS index_bytes,
            (SELECT setting::bigint * 8192 FROM pg_settings WHERE name = 'shared_buffers') AS shared_buffers_bytes
       FROM pg_class i
       JOIN pg_index x ON x.indexrelid = i.oid
       JOIN pg_class c ON c.oid = x.indrelid
       JOIN pg_namespace n ON n.oid = c.relnamespace
       JOIN pg_am am ON am.oid = i.relam
      WHERE am.amname IN ('hnsw','ivfflat')
      ORDER BY 4 DESC$vec$,$vec$row_count > 0$vec$,$vec$Vector index sizes against shared_buffers - an index larger than cache is read from disk on every probe$vec$,$vec$high$vec$,$vec$Size cache to the vector indexes$vec$,$vec$HNSW in particular assumes the graph is resident. Where the index exceeds shared_buffers, either raise shared_buffers, shard the collection, or move to a quantised index so the working structure fits.$vec$);
INSERT INTO _vec_seed VALUES ($vec$PERF-VEC-MEM-003$vec$,$vec$SELECT s.schemaname, s.tablename, s.attname, s.n_distinct, s.null_frac
       FROM pg_stats s
      WHERE EXISTS (
              SELECT 1 FROM pg_class c
               JOIN pg_namespace n ON n.oid = c.relnamespace
               JOIN pg_attribute a ON a.attrelid = c.oid
               JOIN pg_type t ON t.oid = a.atttypid
               WHERE c.relname = s.tablename AND n.nspname = s.schemaname
                 AND t.typname = 'vector' AND a.attnum > 0 AND NOT a.attisdropped)
        AND s.n_distinct > 10000
      ORDER BY s.n_distinct DESC$vec$,$vec$row_count > 0$vec$,$vec$Very high-cardinality metadata columns alongside embeddings - filtered ANN search degrades as selectivity rises$vec$,$vec$medium$vec$,$vec$Reshape high-cardinality filters$vec$,$vec$Filtering ANN search on a near-unique column forces the planner away from the vector index. Partition by that column, or pre-filter into a materialised subset and run the vector search within it.$vec$);
INSERT INTO _vec_seed VALUES ($vec$PERF-VEC-ING-002$vec$,$vec$SELECT l.locktype, l.mode, l.granted, c.relname AS table_name, a.state, a.wait_event_type
       FROM pg_locks l
       JOIN pg_class c ON c.oid = l.relation
       JOIN pg_stat_activity a ON a.pid = l.pid
      WHERE NOT l.granted
        AND EXISTS (
              SELECT 1 FROM pg_attribute at JOIN pg_type t ON t.oid = at.atttypid
               WHERE at.attrelid = c.oid AND t.typname = 'vector'
                 AND at.attnum > 0 AND NOT at.attisdropped)$vec$,$vec$row_count > 0$vec$,$vec$Ungranted locks on vector tables - writers are serialising behind index maintenance$vec$,$vec$high$vec$,$vec$Break up the write path$vec$,$vec$HNSW insert holds the graph while linking, so heavy concurrent writes serialise. Batch inserts, or build the index after a bulk load rather than inserting into a live index.$vec$);
INSERT INTO _vec_seed VALUES ($vec$SEC-VEC-ACC-001$vec$,$vec$SELECT n.nspname AS schema_name, c.relname AS table_name, a.attname AS tenant_column,
            c.relrowsecurity AS rls_enabled
       FROM pg_class c
       JOIN pg_namespace n ON n.oid = c.relnamespace
       JOIN pg_attribute a ON a.attrelid = c.oid
      WHERE c.relkind = 'r' AND NOT c.relrowsecurity
        AND a.attname ~* '(tenant|customer|org|account)(_?id)?$'
        AND a.attnum > 0 AND NOT a.attisdropped
        AND EXISTS (
              SELECT 1 FROM pg_attribute av JOIN pg_type t ON t.oid = av.atttypid
               WHERE av.attrelid = c.oid AND t.typname = 'vector'
                 AND av.attnum > 0 AND NOT av.attisdropped)
      ORDER BY 1,2$vec$,$vec$row_count > 0$vec$,$vec$Multi-tenant embedding tables without row-level security - one missing WHERE clause returns another tenant's vectors$vec$,$vec$critical$vec$,$vec$Enforce tenant isolation with RLS$vec$,$vec$ENABLE ROW LEVEL SECURITY on the table and add a policy keyed on the tenant column, so isolation no longer depends on every query remembering its filter. Similarity search ranks by distance alone and will happily cross tenants without it.$vec$);
INSERT INTO _vec_seed VALUES ($vec$SEC-VEC-ACC-002$vec$,$vec$SELECT n.nspname AS schema_name, c.relname AS table_name,
            acl.privilege_type AS privilege
       FROM pg_class c
       JOIN pg_namespace n ON n.oid = c.relnamespace
       CROSS JOIN LATERAL aclexplode(c.relacl) AS acl
      WHERE c.relkind = 'r' AND c.relacl IS NOT NULL
        AND acl.grantee = 0
        AND EXISTS (
              SELECT 1 FROM pg_attribute a JOIN pg_type t ON t.oid = a.atttypid
               WHERE a.attrelid = c.oid AND t.typname = 'vector'
                 AND a.attnum > 0 AND NOT a.attisdropped)$vec$,$vec$row_count > 0$vec$,$vec$Embedding tables carrying grants to PUBLIC - every role in the cluster can read them$vec$,$vec$critical$vec$,$vec$Revoke PUBLIC access to embedding tables$vec$,$vec$REVOKE the PUBLIC grant and re-grant to the specific application role. Embeddings are recoverable to an approximation of their source text, so treat a PUBLIC grant on them as a data exposure.$vec$);
INSERT INTO _vec_seed VALUES ($vec$SEC-VEC-AUTH-003$vec$,$vec$SELECT name, setting FROM pg_settings WHERE name IN ('ssl','ssl_min_protocol_version','ssl_cert_file','password_encryption') ORDER BY name$vec$,$vec$row_count > 0$vec$,$vec$Transport and password settings - ssl=off means embeddings and credentials cross the network in clear text$vec$,$vec$critical$vec$,$vec$Enable TLS and modern password encryption$vec$,$vec$Set ssl=on with a certificate, require it in pg_hba, and set ssl_min_protocol_version to TLSv1.2 or higher. Confirm password_encryption is scram-sha-256 rather than md5.$vec$);
INSERT INTO _vec_seed VALUES ($vec$SEC-VEC-NET-001$vec$,$vec$SELECT name, setting FROM pg_settings WHERE name IN ('listen_addresses','port') ORDER BY name$vec$,$vec$row_count > 0$vec$,$vec$Listen address configuration - '*' binds every interface$vec$,$vec$high$vec$,$vec$Bind only the interfaces that must serve clients$vec$,$vec$Narrow listen_addresses to the specific private address, and pair it with pg_hba rules restricted to the application subnet rather than a wide CIDR.$vec$);
INSERT INTO _vec_seed VALUES ($vec$SEC-VEC-NET-002$vec$,$vec$SELECT s.pid, s.usename, s.client_addr, s.application_name, l.ssl, l.version AS tls_version
       FROM pg_stat_activity s
       LEFT JOIN pg_stat_ssl l ON l.pid = s.pid
      WHERE s.backend_type = 'client backend'
        AND s.client_addr IS NOT NULL
        AND COALESCE(l.ssl, false) = false$vec$,$vec$row_count > 0$vec$,$vec$Remote client connections not using TLS$vec$,$vec$high$vec$,$vec$Require TLS for remote connections$vec$,$vec$Change the relevant pg_hba lines from host to hostssl so the server refuses plaintext, after confirming every listed client can negotiate TLS.$vec$);
INSERT INTO _vec_seed VALUES ($vec$SEC-VEC-DAT-003$vec$,$vec$SELECT n.nspname AS schema_name, c.relname AS table_name, a.attname AS column_name,
            format_type(a.atttypid, a.atttypmod) AS data_type
       FROM pg_attribute a
       JOIN pg_class c ON c.oid = a.attrelid
       JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE a.attnum > 0 AND NOT a.attisdropped AND c.relkind = 'r'
        AND a.attname ~* '(email|phone|ssn|passport|birth|address|full_?name|credit)'
        AND EXISTS (
              SELECT 1 FROM pg_attribute av JOIN pg_type t ON t.oid = av.atttypid
               WHERE av.attrelid = c.oid AND t.typname = 'vector'
                 AND av.attnum > 0 AND NOT av.attisdropped)
      ORDER BY 1,2,3$vec$,$vec$row_count > 0$vec$,$vec$Columns whose names suggest personal data stored in the same table as embeddings$vec$,$vec$high$vec$,$vec$Classify and protect the metadata$vec$,$vec$Metadata travels with every retrieval result, so PII here reaches the model context and any downstream log. Encrypt, tokenise, or move it out of the retrieval payload.$vec$);
INSERT INTO _vec_seed VALUES ($vec$SEC-VEC-AUTH-001$vec$,$vec$SELECT n.nspname AS schema_name, c.relname AS table_name, a.attname AS column_name
       FROM pg_attribute a
       JOIN pg_class c ON c.oid = a.attrelid
       JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE a.attnum > 0 AND NOT a.attisdropped AND c.relkind = 'r'
        AND a.attname ~* '(api_?key|secret|token|password|credential)'
        AND EXISTS (
              SELECT 1 FROM pg_attribute av JOIN pg_type t ON t.oid = av.atttypid
               WHERE av.attrelid = c.oid AND t.typname = 'vector'
                 AND av.attnum > 0 AND NOT av.attisdropped)
      ORDER BY 1,2,3$vec$,$vec$row_count > 0$vec$,$vec$Credential-looking columns stored alongside embeddings$vec$,$vec$critical$vec$,$vec$Move secrets out of the vector store$vec$,$vec$API keys and tokens do not belong in a retrieval corpus - they leak into model context and logs. Move them to a secrets manager and rotate anything already stored.$vec$);
INSERT INTO _vec_seed VALUES ($vec$SEC-VEC-ATK-003$vec$,$vec$SELECT n.nspname AS schema_name, c.relname AS table_name, a.attname AS column_name,
            a.atttypmod AS dimensions
       FROM pg_attribute a
       JOIN pg_class c ON c.oid = a.attrelid
       JOIN pg_namespace n ON n.oid = c.relnamespace
       JOIN pg_type t ON t.oid = a.atttypid
      WHERE t.typname = 'vector' AND a.attnum > 0 AND NOT a.attisdropped
        AND (a.atttypmod > 2000 OR a.atttypmod < 0)
      ORDER BY 4 DESC$vec$,$vec$row_count > 0$vec$,$vec$Vector columns above pgvector's 2000-dimension index limit, or with no declared dimension at all$vec$,$vec$high$vec$,$vec$Constrain vector dimensionality$vec$,$vec$An undeclared or over-long vector column cannot be indexed, so every search degrades to a full scan - which is a cheap denial-of-service for an attacker who controls the input. Declare an explicit dimension within the indexable limit.$vec$);
INSERT INTO _vec_seed VALUES ($vec$HLTH-VEC-IDX-002$vec$,$vec$SELECT s.schemaname, s.relname AS table_name, s.n_dead_tup, s.n_live_tup,
            s.last_vacuum, s.last_autovacuum
       FROM pg_stat_user_tables s
      WHERE EXISTS (
              SELECT 1 FROM pg_attribute a JOIN pg_type t ON t.oid = a.atttypid
               WHERE a.attrelid = s.relid AND t.typname = 'vector'
                 AND a.attnum > 0 AND NOT a.attisdropped)
        AND s.n_dead_tup > GREATEST(1000, s.n_live_tup / 5)
      ORDER BY s.n_dead_tup DESC$vec$,$vec$row_count > 0$vec$,$vec$Vector tables carrying substantial dead tuples - deleted vectors still occupy the index graph$vec$,$vec$medium$vec$,$vec$VACUUM the vector tables$vec$,$vec$Dead tuples stay reachable in an HNSW graph until vacuumed, so recall drifts and the index keeps growing. VACUUM the listed tables and lower autovacuum_vacuum_scale_factor for them.$vec$);
INSERT INTO _vec_seed VALUES ($vec$HLTH-VEC-IDX-001$vec$,$vec$SELECT n.nspname AS schema_name, c.relname AS table_name, i.relname AS index_name,
            x.indisvalid, x.indisready
       FROM pg_index x
       JOIN pg_class i ON i.oid = x.indexrelid
       JOIN pg_class c ON c.oid = x.indrelid
       JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE (NOT x.indisvalid OR NOT x.indisready)$vec$,$vec$row_count > 0$vec$,$vec$Indexes left invalid or not ready - usually a failed CREATE INDEX CONCURRENTLY, and they are not used by queries$vec$,$vec$high$vec$,$vec$Drop and rebuild the invalid index$vec$,$vec$An invalid index is dead weight: maintained on write, ignored on read. DROP it and re-create, watching for the original failure (commonly a conflicting lock or exhausted maintenance_work_mem on a vector build).$vec$);
INSERT INTO _vec_seed VALUES ($vec$HLTH-VEC-INT-002$vec$,$vec$SELECT s.schemaname, s.tablename, s.attname AS vector_column,
            s.null_frac, c.reltuples::bigint AS approx_rows
       FROM pg_stats s
       JOIN pg_class c ON c.relname = s.tablename
       JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = s.schemaname
       JOIN pg_attribute a ON a.attrelid = c.oid AND a.attname = s.attname
       JOIN pg_type t ON t.oid = a.atttypid
      WHERE t.typname = 'vector' AND s.null_frac > 0
      ORDER BY s.null_frac DESC$vec$,$vec$row_count > 0$vec$,$vec$Rows present in the corpus with no embedding - invisible to every similarity search$vec$,$vec$medium$vec$,$vec$Backfill or remove the unembedded rows$vec$,$vec$A row with a NULL embedding can never be retrieved, so the corpus silently under-serves. Re-run the embedding pipeline for them, and add a NOT NULL constraint once backfilled.$vec$);
INSERT INTO _vec_seed VALUES ($vec$HLTH-VEC-UPG-002$vec$,$vec$SELECT e.extname, e.extversion AS installed_version, a.default_version
       FROM pg_extension e
       JOIN pg_available_extensions a ON a.name = e.extname
      WHERE e.extname = 'vector' AND e.extversion <> a.default_version$vec$,$vec$row_count > 0$vec$,$vec$pgvector is running an older version than the binary on disk provides$vec$,$vec$medium$vec$,$vec$ALTER EXTENSION vector UPDATE$vec$,$vec$The package was upgraded but the extension in this database was not. Run ALTER EXTENSION vector UPDATE; newer versions carry index and recall fixes that only take effect after it.$vec$);
INSERT INTO _vec_seed VALUES ($vec$HLTH-VEC-STG-001$vec$,$vec$SELECT n.nspname AS schema_name, c.relname AS table_name,
            pg_total_relation_size(c.oid) AS total_bytes,
            pg_relation_size(c.oid) AS heap_bytes,
            pg_indexes_size(c.oid) AS index_bytes,
            c.reltuples::bigint AS approx_rows
       FROM pg_class c
       JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE c.relkind = 'r'
        AND EXISTS (
              SELECT 1 FROM pg_attribute a JOIN pg_type t ON t.oid = a.atttypid
               WHERE a.attrelid = c.oid AND t.typname = 'vector'
                 AND a.attnum > 0 AND NOT a.attisdropped)
      ORDER BY 3 DESC$vec$,$vec$row_count > 0$vec$,$vec$Total storage per vector table, split between heap and indexes$vec$,$vec$medium$vec$,$vec$Plan capacity from the index side$vec$,$vec$Vector indexes routinely exceed the heap they cover. Track the split as the corpus grows, and consider halfvec or quantisation once index size dominates.$vec$);
INSERT INTO _vec_seed VALUES ($vec$HLTH-VEC-REP-001$vec$,$vec$SELECT application_name, state, sync_state,
            pg_wal_lsn_diff(sent_lsn, replay_lsn) AS replay_lag_bytes,
            write_lag, flush_lag, replay_lag
       FROM pg_stat_replication$vec$,$vec$row_count > 0$vec$,$vec$Connected replicas and how far each is behind$vec$,$vec$high$vec$,$vec$Close the replication gap$vec$,$vec$A replica serving reads while behind returns stale vectors, so retrieval quality silently varies by which node answered. Investigate the lag before routing reads to it.$vec$);
INSERT INTO _vec_seed VALUES ($vec$HLTH-VEC-RES-002$vec$,$vec$SELECT n.nspname AS schema_name, count(DISTINCT c.oid) AS vector_tables
       FROM pg_class c
       JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE c.relkind = 'r' AND n.nspname NOT IN ('pg_catalog','information_schema')
        AND EXISTS (
              SELECT 1 FROM pg_attribute a JOIN pg_type t ON t.oid = a.atttypid
               WHERE a.attrelid = c.oid AND t.typname = 'vector'
                 AND a.attnum > 0 AND NOT a.attisdropped)
      GROUP BY 1 ORDER BY 2 DESC$vec$,$vec$row_count > 0$vec$,$vec$Vector tables per schema - the inventory namespace sprawl is judged against$vec$,$vec$low$vec$,$vec$Keep the collection inventory deliberate$vec$,$vec$Track which schema owns which corpus. Sprawl usually means abandoned experiments still consuming storage and autovacuum budget; drop what nothing queries.$vec$);
INSERT INTO _vec_seed VALUES ($vec$HLTH-VEC-SYS-001$vec$,$vec$SELECT name, setting, unit FROM pg_settings WHERE name IN ('max_files_per_process','max_connections','superuser_reserved_connections') ORDER BY name$vec$,$vec$row_count > 0$vec$,$vec$Descriptor and connection limits - vector index scans hold many file handles at once$vec$,$vec$medium$vec$,$vec$Give the process descriptor headroom$vec$,$vec$Large HNSW indexes span many segment files, so a low max_files_per_process forces constant reopening. Raise it together with the OS ulimit rather than in isolation.$vec$);
INSERT INTO _vec_seed VALUES ($vec$HLTH-VEC-MNT-002$vec$,$vec$SELECT n.nspname AS schema_name, c.relname AS table_name, a.attname AS column_name
       FROM pg_attribute a
       JOIN pg_class c ON c.oid = a.attrelid
       JOIN pg_namespace n ON n.oid = c.relnamespace
       JOIN pg_type t ON t.oid = a.atttypid
      WHERE t.typname = 'vector' AND a.attnum > 0 AND NOT a.attisdropped
        AND a.atttypmod < 0
      ORDER BY 1,2,3$vec$,$vec$row_count > 0$vec$,$vec$Vector columns declared without a dimension - nothing prevents rows of differing length$vec$,$vec$high$vec$,$vec$Pin the dimension in the column type$vec$,$vec$An unconstrained vector column accepts any length, so a pipeline change silently mixes dimensionalities and the column can never be indexed. Declare vector(N) and re-embed anything that does not match.$vec$);

DO $do$
DECLARE
    r         record;
    v_rc      text;
    lstep     bigint;
    lpath     bigint;
    lres_step bigint;
    lres_path bigint;
    n_added   integer := 0;
    has_is_enabled boolean;
    t         text;
    seqname   text;
BEGIN
    SELECT EXISTS (SELECT 1 FROM information_schema.columns
                    WHERE table_schema='rootcause' AND table_name='root_causes'
                      AND column_name='is_enabled') INTO has_is_enabled;

    -- Catalogs predating migration 127 have no sequence default on these id columns.
    FOREACH t IN ARRAY ARRAY['detection_steps','detection_paths','detection_path_steps',
                             'resolution_steps','resolution_paths','resolution_path_steps'] LOOP
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                        WHERE table_schema='rootcause' AND table_name=t
                          AND column_name='id' AND column_default IS NOT NULL) THEN
            seqname := format('rootcause.%I', t || '_id_seq');
            EXECUTE format('CREATE SEQUENCE IF NOT EXISTS %s', seqname);
            EXECUTE format('SELECT setval(%L, COALESCE((SELECT max(id) FROM rootcause.%I), 0) + 1, false)',
                           seqname, t);
            EXECUTE format('ALTER TABLE rootcause.%I ALTER COLUMN id SET DEFAULT nextval(%L)', t, seqname);
            RAISE NOTICE 'attached missing id sequence to rootcause.% (pre-127 catalog)', t;
        END IF;
    END LOOP;

    FOR r IN SELECT * FROM _vec_seed ORDER BY issue_id LOOP
        -- Idempotency is per ISSUE, not per root cause. The binding below picks whichever root
        -- cause is still uncovered, so a naive re-run would bind the NEXT one and duplicate the
        -- same signal under a sibling. Skip the issue once this file has already covered it.
        IF EXISTS (SELECT 1 FROM rootcause.detection_paths dp
                     JOIN rootcause.root_causes rc2 ON rc2.root_cause_id = dp.root_cause_id
                    WHERE rc2.issue_id = r.issue_id
                      AND dp.vendor_slug = 'postgresql'
                      AND dp.name LIKE '%(pgvector)') THEN
            CONTINUE;
        END IF;

        -- Bind the issue to a root cause that is not already covered for postgresql.
        SELECT rc.root_cause_id INTO v_rc
          FROM rootcause.root_causes rc
         WHERE rc.issue_id = r.issue_id
           AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths dp
                            WHERE dp.root_cause_id = rc.root_cause_id
                              AND dp.vendor_slug = 'postgresql')
         ORDER BY rc.root_cause_id
         LIMIT 1;

        IF v_rc IS NULL THEN
            RAISE NOTICE 'skip % - no uncovered root cause under this issue (or issue absent)', r.issue_id;
            CONTINUE;
        END IF;

        INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
             VALUES ('postgresql', 'query', format('Detect %s (pgvector)', v_rc),
                     jsonb_build_object('sql', r.sql),
                     jsonb_build_object('condition', r.cond, 'description', r.descr))
          RETURNING id INTO lstep;

        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
             VALUES (v_rc, 'postgresql', format('Detect %s (pgvector)', v_rc), r.descr, 'diagnostic', true)
          RETURNING id INTO lpath;

        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence,
                                                    on_match_action, on_no_match_action)
             VALUES (lpath, lstep, 1, 'confirmed', 'ruled_out');

        -- v_rootcauses INNER JOINs the resolution chain, so this is mandatory.
        IF NOT EXISTS (SELECT 1 FROM rootcause.resolution_paths
                        WHERE root_cause_id = v_rc AND vendor_slug = 'postgresql') THEN
            -- rootcause.resolution_steps carries UNIQUE (vendor_slug, name). A blind INSERT would
            -- abort the migration on a name collision, and apply_migrations is best-effort, so it
            -- would ship as a SILENT no-op (docs/RELEASING.md, the v0.12.0 failure mode). Reuse.
            SELECT id INTO lres_step
              FROM rootcause.resolution_steps
             WHERE vendor_slug = 'postgresql' AND name = r.res_name
             ORDER BY id LIMIT 1;

            IF lres_step IS NULL THEN
                INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content,
                                                        risk_level, requires_confirmation,
                                                        is_reversible, estimated_duration)
                     VALUES ('postgresql', 'recommendation', r.res_name,
                             jsonb_build_object('text', r.res_text),
                             r.risk, true, true, '00:30:00')
                  RETURNING id INTO lres_step;
            END IF;

            INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description,
                                                    execution_mode, risk_level, status, is_active)
                 VALUES (v_rc, 'postgresql', r.res_name, v_rc || '-postgresql-vec', r.res_text,
                         'manual', r.risk, 'authored', true)
              RETURNING id INTO lres_path;

            INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order)
                 VALUES (lres_path, lres_step, 1);
        END IF;

        UPDATE rootcause.root_causes
           SET vendors_applicable = (SELECT array(SELECT DISTINCT unnest(coalesce(vendors_applicable, ARRAY[]::text[]) || ARRAY['postgresql']) ORDER BY 1))
         WHERE root_cause_id = v_rc;

        IF has_is_enabled THEN
            EXECUTE 'UPDATE rootcause.root_causes SET is_enabled = true WHERE root_cause_id = $1' USING v_rc;
            EXECUTE 'UPDATE rootcause.issues SET is_enabled = true WHERE issue_id = $1' USING r.issue_id;
        END IF;

        n_added := n_added + 1;
    END LOOP;

    RAISE NOTICE 'pgvector VEC detections seeded: % root cause(s)', n_added;
END $do$;

DROP TABLE _vec_seed;

COMMIT;
