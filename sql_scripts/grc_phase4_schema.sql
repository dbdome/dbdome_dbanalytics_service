-- GRC Phase 4: Data masking rules, token vault, and coverage views
-- Run after grc_phase1_schema.sql and grc_phase3_schema.sql

-- ──────────────────────────────────────────────────────────────
-- 1. PII type classification on existing sensitive_schema
--    (non-destructive: adds column only if absent)
-- ──────────────────────────────────────────────────────────────
ALTER TABLE monitoring.sensitive_schema
    ADD COLUMN IF NOT EXISTS pii_type   VARCHAR(50),   -- SSN|CREDIT_CARD|EMAIL|PHONE|DOB|NAME|ADDRESS|PASSWORD|SALARY|GENERIC
    ADD COLUMN IF NOT EXISTS mask_type  VARCHAR(20),   -- REDACT|PARTIAL|HASH|TOKENIZE
    ADD COLUMN IF NOT EXISTS is_masked  BOOLEAN NOT NULL DEFAULT FALSE;

-- Back-fill pii_type and default mask_type from column name patterns
UPDATE monitoring.sensitive_schema SET
    pii_type = CASE
        WHEN lower(column_name) ~ '(ssn|social_sec|national_id|tax_id|id_card|identity|passport|driver_licen)'
            THEN 'SSN'
        WHEN lower(column_name) ~ '(credit_card|card_num|cvv|ccv|card_number)'
            THEN 'CREDIT_CARD'
        WHEN lower(column_name) ~ '(email|e_mail|mail_address)'
            THEN 'EMAIL'
        WHEN lower(column_name) ~ '(phone|mobile|cell|fax|telephone)'
            THEN 'PHONE'
        WHEN lower(column_name) ~ '(birth_date|dob|date_of_birth|birthday)'
            THEN 'DOB'
        WHEN lower(column_name) ~ '(first_name|last_name|full_name|surname|family_name|given_name)'
            THEN 'NAME'
        WHEN lower(column_name) ~ '(address|street|city|zip|postal)'
            THEN 'ADDRESS'
        WHEN lower(column_name) ~ '(salary|income|wage|compensation)'
            THEN 'SALARY'
        WHEN lower(column_name) ~ '(password|pwd|secret|token|api_key|bank_account|iban|routing|swift)'
            THEN 'PASSWORD'
        WHEN lower(column_name) ~ '(medical|diagnosis|prescription|patient|health)'
            THEN 'MEDICAL'
        ELSE 'GENERIC'
    END,
    mask_type = CASE
        WHEN lower(column_name) ~ '(ssn|social_sec|national_id|tax_id|id_card|identity|passport|driver_licen)'
            THEN 'PARTIAL'
        WHEN lower(column_name) ~ '(credit_card|card_num|cvv|ccv|card_number)'
            THEN 'PARTIAL'
        WHEN lower(column_name) ~ '(email|e_mail|mail_address)'
            THEN 'PARTIAL'
        WHEN lower(column_name) ~ '(phone|mobile|cell|fax|telephone)'
            THEN 'PARTIAL'
        WHEN lower(column_name) ~ '(password|pwd|secret|token|api_key|bank_account|iban|routing|swift)'
            THEN 'REDACT'
        WHEN lower(column_name) ~ '(salary|income|wage|compensation)'
            THEN 'REDACT'
        WHEN lower(column_name) ~ '(birth_date|dob|date_of_birth|birthday)'
            THEN 'PARTIAL'
        ELSE 'HASH'
    END
WHERE pii_type IS NULL;

-- ──────────────────────────────────────────────────────────────
-- 2. Masking rules table (one rule per column, per server)
--    Auto-populated from sensitive_schema; overridable per policy
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS config.masking_rules (
    rule_id         SERIAL          PRIMARY KEY,
    server_name     VARCHAR(200)    NOT NULL,
    database_name   VARCHAR(200),
    schema_name     VARCHAR(200),
    table_name      VARCHAR(200)    NOT NULL,
    column_name     VARCHAR(200)    NOT NULL,
    pii_type        VARCHAR(50)     NOT NULL DEFAULT 'GENERIC',
    mask_type       VARCHAR(20)     NOT NULL DEFAULT 'HASH', -- REDACT|PARTIAL|HASH|TOKENIZE
    allowed_roles   TEXT[]          NOT NULL DEFAULT '{}',   -- roles that see clear text
    regulation      VARCHAR(50),                             -- PCI-DSS|HIPAA|GDPR|SOC2
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    UNIQUE (server_name, table_name, column_name)
);

CREATE INDEX IF NOT EXISTS idx_masking_rules_server_table
    ON config.masking_rules (server_name, table_name, column_name)
    WHERE is_active = TRUE;

-- ──────────────────────────────────────────────────────────────
-- 3. Token vault (consistent tokenisation across sessions)
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS config.masking_tokens (
    token_id        BIGSERIAL       PRIMARY KEY,
    pii_type        VARCHAR(50)     NOT NULL,
    original_hash   VARCHAR(64)     NOT NULL,   -- SHA-256 of original value
    token           VARCHAR(100)    NOT NULL,   -- stable surrogate
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    UNIQUE (pii_type, original_hash)
);

CREATE INDEX IF NOT EXISTS idx_masking_tokens_lookup
    ON config.masking_tokens (pii_type, original_hash);

-- ──────────────────────────────────────────────────────────────
-- 4. Populate masking rules from sensitive_schema (initial seed)
-- ──────────────────────────────────────────────────────────────
INSERT INTO config.masking_rules
    (server_name, database_name, table_name, column_name, pii_type, mask_type, regulation)
SELECT
    ss.server,
    ss.database_name,
    ss.table_name,
    ss.column_name,
    COALESCE(ss.pii_type, 'GENERIC'),
    COALESCE(ss.mask_type, 'HASH'),
    CASE
        WHEN ss.pii_type IN ('CREDIT_CARD','SSN')   THEN 'PCI-DSS'
        WHEN ss.pii_type IN ('MEDICAL')              THEN 'HIPAA'
        WHEN ss.pii_type IN ('EMAIL','NAME','DOB','ADDRESS','SALARY') THEN 'GDPR'
        ELSE 'internal'
    END
FROM monitoring.sensitive_schema ss
ON CONFLICT (server_name, table_name, column_name) DO UPDATE
    SET pii_type    = EXCLUDED.pii_type,
        mask_type   = EXCLUDED.mask_type,
        updated_at  = NOW();

-- ──────────────────────────────────────────────────────────────
-- 5. Masking coverage views
-- ──────────────────────────────────────────────────────────────

-- Summary: how many columns are masked per server / regulation
CREATE OR REPLACE VIEW config.v_masking_coverage AS
SELECT
    server_name,
    regulation,
    COUNT(*)                                        AS total_sensitive_columns,
    SUM(CASE WHEN is_active THEN 1 ELSE 0 END)     AS actively_masked,
    array_agg(DISTINCT pii_type ORDER BY pii_type)  AS pii_types_covered
FROM config.masking_rules
GROUP BY server_name, regulation
ORDER BY server_name, regulation;

-- Detail: all active masking rules per server
CREATE OR REPLACE VIEW config.v_masking_rules_detail AS
SELECT
    mr.server_name,
    mr.database_name,
    mr.table_name,
    mr.column_name,
    mr.pii_type,
    mr.mask_type,
    mr.allowed_roles,
    mr.regulation,
    mr.is_active,
    mr.updated_at
FROM config.masking_rules mr
ORDER BY mr.server_name, mr.table_name, mr.column_name;

-- Unmasked sensitive columns (risk gap report)
CREATE OR REPLACE VIEW config.v_unmasked_sensitive_columns AS
SELECT
    ss.server,
    ss.database_name,
    ss.table_name,
    ss.column_name,
    ss.pii_type,
    ss.data_type
FROM monitoring.sensitive_schema ss
LEFT JOIN config.masking_rules mr
    ON  mr.server_name  = ss.server
    AND mr.table_name   = ss.table_name
    AND mr.column_name  = ss.column_name
    AND mr.is_active    = TRUE
WHERE mr.rule_id IS NULL
ORDER BY ss.server, ss.table_name;

-- ──────────────────────────────────────────────────────────────
-- 6. Register sync job
-- ──────────────────────────────────────────────────────────────
INSERT INTO metrics.registered_processes (process_name, interval, is_active, description)
VALUES ('sync_masking_rules', 3600, TRUE,
        'GRC Phase 4: sync config.masking_rules from monitoring.sensitive_schema (hourly)')
ON CONFLICT (process_name) DO UPDATE
    SET interval    = EXCLUDED.interval,
        is_active   = EXCLUDED.is_active,
        description = EXCLUDED.description;
