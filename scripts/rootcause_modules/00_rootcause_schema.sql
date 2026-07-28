-- =============================================================================
-- rootcause schema — table scaffolding (idempotent)
-- =============================================================================
-- These tables already exist on the live SaaS/analytics DB; this file is for
-- FRESH/DEV databases so the generated insert_<module>_rootcause.sql scripts
-- have something to insert into. CREATE TABLE IF NOT EXISTS => no-op where the
-- tables already exist. Column types are inferred from the existing
-- insert_*_rootcause.sql usage; adjust if the live schema differs.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS rootcause;

-- One row per root cause (the catalog entry).
CREATE TABLE IF NOT EXISTS rootcause.root_causes (
    root_cause_id       text PRIMARY KEY,
    issue_id            text,
    name                text NOT NULL,
    slug                text,
    description         text,
    topics              text[],
    vendors_applicable  text[]
);

-- A reusable detection step: the actual vendor SQL lives in content->>'sql'.
CREATE TABLE IF NOT EXISTS rootcause.detection_steps (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    vendor_slug text NOT NULL,
    step_type   text NOT NULL DEFAULT 'query',
    name        text NOT NULL,
    content     jsonb NOT NULL,          -- {"sql": "..."}
    expected    jsonb                    -- {"condition": "...", "description": "..."}
);

-- A detection path ties a root cause (per vendor) to one or more steps.
CREATE TABLE IF NOT EXISTS rootcause.detection_paths (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    root_cause_id text NOT NULL REFERENCES rootcause.root_causes(root_cause_id) ON DELETE CASCADE,
    vendor_slug   text NOT NULL,
    name          text NOT NULL,
    description   text,
    path_type     text DEFAULT 'diagnostic',
    is_active     boolean DEFAULT true
);

CREATE TABLE IF NOT EXISTS rootcause.detection_path_steps (
    id                 bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    detection_path_id  bigint NOT NULL REFERENCES rootcause.detection_paths(id) ON DELETE CASCADE,
    detection_step_id  bigint NOT NULL REFERENCES rootcause.detection_steps(id),
    sequence           int DEFAULT 1,
    on_match_action    text DEFAULT 'confirmed',
    on_no_match_action text DEFAULT 'ruled_out'
);

CREATE TABLE IF NOT EXISTS rootcause.resolution_steps (
    id                    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    vendor_slug           text NOT NULL,
    step_type             text NOT NULL DEFAULT 'recommendation',
    name                  text NOT NULL,
    content               jsonb NOT NULL,   -- {"action": "..."}
    risk_level            text DEFAULT 'medium',
    requires_confirmation boolean DEFAULT false,
    is_reversible         boolean DEFAULT true
);

CREATE TABLE IF NOT EXISTS rootcause.resolution_paths (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    root_cause_id text NOT NULL REFERENCES rootcause.root_causes(root_cause_id) ON DELETE CASCADE,
    vendor_slug   text NOT NULL,
    name          text NOT NULL,
    slug          text,
    description   text,
    execution_mode text DEFAULT 'supervised',
    risk_level    text DEFAULT 'medium',
    is_active     boolean DEFAULT true
);

CREATE TABLE IF NOT EXISTS rootcause.resolution_path_steps (
    id                 bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    resolution_path_id bigint NOT NULL REFERENCES rootcause.resolution_paths(id) ON DELETE CASCADE,
    resolution_step_id bigint NOT NULL REFERENCES rootcause.resolution_steps(id),
    step_order         int DEFAULT 1
);

CREATE INDEX IF NOT EXISTS ix_rc_detection_paths_rc  ON rootcause.detection_paths (root_cause_id, vendor_slug);
CREATE INDEX IF NOT EXISTS ix_rc_resolution_paths_rc ON rootcause.resolution_paths (root_cause_id, vendor_slug);

-- NOTE: rootcause.v_rootcauses already exists on the live DB and is NOT created
-- here (its exact definition is environment-owned). The generated scripts only
-- SELECT from it in their verify section.
