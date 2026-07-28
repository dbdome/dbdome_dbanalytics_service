-- ============================================================
-- Seed config.dump_metrics with every metric_name currently present in
-- monitoring.general_metric_metadata_results, at the default 12-month retention.
--
-- Idempotent: ON CONFLICT (metric_name) DO NOTHING, so re-running picks up
-- newly-appearing metrics without overwriting any per-metric retention you've
-- already customised.
-- ============================================================
INSERT INTO config.dump_metrics (metric_name, retention_months)
SELECT DISTINCT metric_name, 12
FROM monitoring.general_metric_metadata_results
WHERE metric_name IS NOT NULL AND metric_name <> ''
ON CONFLICT (metric_name) DO NOTHING;
