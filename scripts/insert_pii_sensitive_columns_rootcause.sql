-- =============================================================================
-- PII Root Causes: Sensitive Column Discovery + Sensitive Columns In Use
-- =============================================================================
-- SEC-SQL-PRI-001-RC12 — Sensitive columns discovered in schema
-- SEC-SQL-PRI-001-RC13 — Sensitive columns actively queried / in use
--
-- All vendors: sqlserver, oracle, postgresql, mysql
--
-- Detects columns whose names suggest PII/sensitive data:
--   ssn, social_security, credit_card, card_number, cvv, password, passwd,
--   secret, token, api_key, email, phone, mobile, birth_date, dob,
--   salary, income, bank_account, iban, routing_number, national_id,
--   passport, driver_license, tax_id, medical_record, diagnosis,
--   ip_address, mac_address, biometric
-- =============================================================================

BEGIN;

-- ═══════════════════════════════════════════════════════════════
-- 1. ROOT CAUSES
-- ═══════════════════════════════════════════════════════════════

INSERT INTO rootcause.root_causes (
    root_cause_id, issue_id, name, slug, description,
    topics, vendors_applicable
) VALUES (
    'SEC-SQL-PRI-001-RC12',
    'SEC-SQL-PRI-001',
    'Sensitive columns discovered in schema (PII)',
    'sensitive-columns-discovered-pii',
    'Database schema contains columns with names that strongly suggest PII or sensitive data (SSN, credit card, password, email, salary, etc.) that may not be encrypted, masked, or otherwise protected. These columns represent a compliance risk under GDPR, HIPAA, PCI-DSS, and similar regulations.',
    ARRAY['pii', 'sensitive data', 'schema discovery', 'gdpr', 'hipaa', 'pci-dss', 'compliance', 'data classification', 'sensitive columns'],
    ARRAY['sqlserver', 'oracle', 'postgresql', 'mysql']
);

INSERT INTO rootcause.root_causes (
    root_cause_id, issue_id, name, slug, description,
    topics, vendors_applicable
) VALUES (
    'SEC-SQL-PRI-001-RC13',
    'SEC-SQL-PRI-001',
    'Sensitive columns actively queried (PII in use)',
    'sensitive-columns-in-use-pii',
    'Columns identified as containing PII or sensitive data are actively being accessed by queries. This indicates live exposure risk — sensitive data is not just stored but actively read, potentially by applications, reports, or ad-hoc queries without proper masking or access controls.',
    ARRAY['pii', 'sensitive data', 'data in use', 'active queries', 'exposure', 'gdpr', 'hipaa', 'data access', 'column access'],
    ARRAY['sqlserver', 'oracle', 'postgresql', 'mysql']
);

-- ═══════════════════════════════════════════════════════════════
-- 2. DETECTION STEPS
-- ═══════════════════════════════════════════════════════════════

-- The sensitive column name patterns (shared across all vendors)
-- Matches: ssn, social_security, credit_card, card_number, cvv, cvc,
-- password, passwd, secret, token, api_key, email, phone, mobile,
-- birth_date, dob, date_of_birth, salary, income, bank_account,
-- iban, routing, national_id, passport, driver_license, tax_id,
-- medical, diagnosis, ip_address, mac_address, biometric

-- ─────────────────────────────────────────────────────────────
-- RC12: Sensitive columns in schema — DISCOVERY
-- ─────────────────────────────────────────────────────────────

-- SQL Server
INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Discover sensitive columns in schema (sqlserver)',
'{"sql": "SELECT s.name AS schema_name, t.name AS table_name, c.name AS column_name, ty.name AS data_type, c.max_length, CASE WHEN c.name LIKE ''%ssn%'' OR c.name LIKE ''%social_security%'' THEN ''SSN'' WHEN c.name LIKE ''%credit_card%'' OR c.name LIKE ''%card_number%'' OR c.name LIKE ''%cvv%'' OR c.name LIKE ''%cvc%'' OR c.name LIKE ''%card_num%'' THEN ''Credit Card'' WHEN c.name LIKE ''%password%'' OR c.name LIKE ''%passwd%'' OR c.name LIKE ''%secret%'' OR c.name LIKE ''%api_key%'' OR c.name LIKE ''%apikey%'' THEN ''Credential'' WHEN c.name LIKE ''%email%'' OR c.name LIKE ''%e_mail%'' THEN ''Email'' WHEN c.name LIKE ''%phone%'' OR c.name LIKE ''%mobile%'' OR c.name LIKE ''%cell%'' THEN ''Phone'' WHEN c.name LIKE ''%birth%'' OR c.name LIKE ''%dob%'' OR c.name LIKE ''%date_of_birth%'' THEN ''Date of Birth'' WHEN c.name LIKE ''%salary%'' OR c.name LIKE ''%income%'' OR c.name LIKE ''%wage%'' THEN ''Financial'' WHEN c.name LIKE ''%bank_account%'' OR c.name LIKE ''%iban%'' OR c.name LIKE ''%routing%'' THEN ''Bank Account'' WHEN c.name LIKE ''%national_id%'' OR c.name LIKE ''%passport%'' OR c.name LIKE ''%driver_license%'' OR c.name LIKE ''%tax_id%'' OR c.name LIKE ''%id_number%'' THEN ''Government ID'' WHEN c.name LIKE ''%medical%'' OR c.name LIKE ''%diagnosis%'' OR c.name LIKE ''%health%'' THEN ''Medical'' WHEN c.name LIKE ''%ip_address%'' OR c.name LIKE ''%mac_address%'' OR c.name LIKE ''%biometric%'' THEN ''Technical PII'' ELSE ''Other Sensitive'' END AS pii_category FROM sys.columns c JOIN sys.tables t ON t.object_id = c.object_id JOIN sys.schemas s ON s.schema_id = t.schema_id JOIN sys.types ty ON ty.user_type_id = c.user_type_id WHERE t.is_ms_shipped = 0 AND (c.name LIKE ''%ssn%'' OR c.name LIKE ''%social_security%'' OR c.name LIKE ''%credit_card%'' OR c.name LIKE ''%card_number%'' OR c.name LIKE ''%cvv%'' OR c.name LIKE ''%cvc%'' OR c.name LIKE ''%password%'' OR c.name LIKE ''%passwd%'' OR c.name LIKE ''%secret%'' OR c.name LIKE ''%api_key%'' OR c.name LIKE ''%email%'' OR c.name LIKE ''%phone%'' OR c.name LIKE ''%mobile%'' OR c.name LIKE ''%birth%'' OR c.name LIKE ''%dob%'' OR c.name LIKE ''%salary%'' OR c.name LIKE ''%income%'' OR c.name LIKE ''%bank_account%'' OR c.name LIKE ''%iban%'' OR c.name LIKE ''%national_id%'' OR c.name LIKE ''%passport%'' OR c.name LIKE ''%driver_license%'' OR c.name LIKE ''%tax_id%'' OR c.name LIKE ''%medical%'' OR c.name LIKE ''%diagnosis%'' OR c.name LIKE ''%ip_address%'' OR c.name LIKE ''%biometric%'') ORDER BY pii_category, s.name, t.name, c.name"}'::jsonb,
'{"condition": "row_count > 0", "description": "Columns with names suggesting PII/sensitive data found in database schema"}'::jsonb);

-- Oracle
INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('oracle', 'query', 'Discover sensitive columns in schema (oracle)',
'{"sql": "SELECT owner AS schema_name, table_name, column_name, data_type, data_length, CASE WHEN LOWER(column_name) LIKE ''%ssn%'' OR LOWER(column_name) LIKE ''%social_security%'' THEN ''SSN'' WHEN LOWER(column_name) LIKE ''%credit_card%'' OR LOWER(column_name) LIKE ''%card_number%'' OR LOWER(column_name) LIKE ''%cvv%'' THEN ''Credit Card'' WHEN LOWER(column_name) LIKE ''%password%'' OR LOWER(column_name) LIKE ''%passwd%'' OR LOWER(column_name) LIKE ''%secret%'' OR LOWER(column_name) LIKE ''%api_key%'' THEN ''Credential'' WHEN LOWER(column_name) LIKE ''%email%'' THEN ''Email'' WHEN LOWER(column_name) LIKE ''%phone%'' OR LOWER(column_name) LIKE ''%mobile%'' THEN ''Phone'' WHEN LOWER(column_name) LIKE ''%birth%'' OR LOWER(column_name) LIKE ''%dob%'' THEN ''Date of Birth'' WHEN LOWER(column_name) LIKE ''%salary%'' OR LOWER(column_name) LIKE ''%income%'' THEN ''Financial'' WHEN LOWER(column_name) LIKE ''%bank_account%'' OR LOWER(column_name) LIKE ''%iban%'' THEN ''Bank Account'' WHEN LOWER(column_name) LIKE ''%national_id%'' OR LOWER(column_name) LIKE ''%passport%'' OR LOWER(column_name) LIKE ''%tax_id%'' THEN ''Government ID'' WHEN LOWER(column_name) LIKE ''%medical%'' OR LOWER(column_name) LIKE ''%diagnosis%'' THEN ''Medical'' ELSE ''Other Sensitive'' END AS pii_category FROM all_tab_columns WHERE owner NOT IN (''SYS'',''SYSTEM'',''DBSNMP'',''OUTLN'',''MDSYS'',''ORDSYS'',''CTXSYS'',''XDB'',''WMSYS'') AND (LOWER(column_name) LIKE ''%ssn%'' OR LOWER(column_name) LIKE ''%social_security%'' OR LOWER(column_name) LIKE ''%credit_card%'' OR LOWER(column_name) LIKE ''%card_number%'' OR LOWER(column_name) LIKE ''%cvv%'' OR LOWER(column_name) LIKE ''%password%'' OR LOWER(column_name) LIKE ''%passwd%'' OR LOWER(column_name) LIKE ''%secret%'' OR LOWER(column_name) LIKE ''%api_key%'' OR LOWER(column_name) LIKE ''%email%'' OR LOWER(column_name) LIKE ''%phone%'' OR LOWER(column_name) LIKE ''%mobile%'' OR LOWER(column_name) LIKE ''%birth%'' OR LOWER(column_name) LIKE ''%dob%'' OR LOWER(column_name) LIKE ''%salary%'' OR LOWER(column_name) LIKE ''%income%'' OR LOWER(column_name) LIKE ''%bank_account%'' OR LOWER(column_name) LIKE ''%iban%'' OR LOWER(column_name) LIKE ''%national_id%'' OR LOWER(column_name) LIKE ''%passport%'' OR LOWER(column_name) LIKE ''%tax_id%'' OR LOWER(column_name) LIKE ''%medical%'' OR LOWER(column_name) LIKE ''%diagnosis%'' OR LOWER(column_name) LIKE ''%ip_address%'' OR LOWER(column_name) LIKE ''%biometric%'') ORDER BY pii_category, owner, table_name"}'::jsonb,
'{"condition": "row_count > 0", "description": "Columns with names suggesting PII/sensitive data found in database schema"}'::jsonb);

-- PostgreSQL
INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('postgresql', 'query', 'Discover sensitive columns in schema (postgresql)',
'{"sql": "SELECT table_schema AS schema_name, table_name, column_name, data_type, character_maximum_length, CASE WHEN column_name ~ ''(ssn|social_security)'' THEN ''SSN'' WHEN column_name ~ ''(credit_card|card_number|cvv|cvc)'' THEN ''Credit Card'' WHEN column_name ~ ''(password|passwd|secret|api_key|apikey)'' THEN ''Credential'' WHEN column_name ~ ''(email|e_mail)'' THEN ''Email'' WHEN column_name ~ ''(phone|mobile|cell)'' THEN ''Phone'' WHEN column_name ~ ''(birth|dob|date_of_birth)'' THEN ''Date of Birth'' WHEN column_name ~ ''(salary|income|wage)'' THEN ''Financial'' WHEN column_name ~ ''(bank_account|iban|routing)'' THEN ''Bank Account'' WHEN column_name ~ ''(national_id|passport|driver_license|tax_id|id_number)'' THEN ''Government ID'' WHEN column_name ~ ''(medical|diagnosis|health)'' THEN ''Medical'' WHEN column_name ~ ''(ip_address|mac_address|biometric)'' THEN ''Technical PII'' ELSE ''Other Sensitive'' END AS pii_category FROM information_schema.columns WHERE table_schema NOT IN (''information_schema'', ''pg_catalog'', ''pg_toast'') AND column_name ~ ''(ssn|social_security|credit_card|card_number|cvv|cvc|password|passwd|secret|api_key|email|phone|mobile|birth|dob|salary|income|bank_account|iban|national_id|passport|driver_license|tax_id|medical|diagnosis|ip_address|biometric)'' ORDER BY pii_category, table_schema, table_name"}'::jsonb,
'{"condition": "row_count > 0", "description": "Columns with names suggesting PII/sensitive data found in database schema"}'::jsonb);

-- MySQL
INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('mysql', 'query', 'Discover sensitive columns in schema (mysql)',
'{"sql": "SELECT table_schema AS schema_name, table_name, column_name, data_type, character_maximum_length, CASE WHEN column_name LIKE ''%ssn%'' OR column_name LIKE ''%social_security%'' THEN ''SSN'' WHEN column_name LIKE ''%credit_card%'' OR column_name LIKE ''%card_number%'' OR column_name LIKE ''%cvv%'' THEN ''Credit Card'' WHEN column_name LIKE ''%password%'' OR column_name LIKE ''%passwd%'' OR column_name LIKE ''%secret%'' OR column_name LIKE ''%api_key%'' THEN ''Credential'' WHEN column_name LIKE ''%email%'' THEN ''Email'' WHEN column_name LIKE ''%phone%'' OR column_name LIKE ''%mobile%'' THEN ''Phone'' WHEN column_name LIKE ''%birth%'' OR column_name LIKE ''%dob%'' THEN ''Date of Birth'' WHEN column_name LIKE ''%salary%'' OR column_name LIKE ''%income%'' THEN ''Financial'' WHEN column_name LIKE ''%bank_account%'' OR column_name LIKE ''%iban%'' THEN ''Bank Account'' WHEN column_name LIKE ''%national_id%'' OR column_name LIKE ''%passport%'' OR column_name LIKE ''%tax_id%'' THEN ''Government ID'' WHEN column_name LIKE ''%medical%'' OR column_name LIKE ''%diagnosis%'' THEN ''Medical'' ELSE ''Other Sensitive'' END AS pii_category FROM information_schema.columns WHERE table_schema NOT IN (''information_schema'', ''mysql'', ''performance_schema'', ''sys'') AND (column_name LIKE ''%ssn%'' OR column_name LIKE ''%social_security%'' OR column_name LIKE ''%credit_card%'' OR column_name LIKE ''%card_number%'' OR column_name LIKE ''%cvv%'' OR column_name LIKE ''%password%'' OR column_name LIKE ''%passwd%'' OR column_name LIKE ''%secret%'' OR column_name LIKE ''%api_key%'' OR column_name LIKE ''%email%'' OR column_name LIKE ''%phone%'' OR column_name LIKE ''%mobile%'' OR column_name LIKE ''%birth%'' OR column_name LIKE ''%dob%'' OR column_name LIKE ''%salary%'' OR column_name LIKE ''%income%'' OR column_name LIKE ''%bank_account%'' OR column_name LIKE ''%iban%'' OR column_name LIKE ''%national_id%'' OR column_name LIKE ''%passport%'' OR column_name LIKE ''%tax_id%'' OR column_name LIKE ''%medical%'' OR column_name LIKE ''%diagnosis%'' OR column_name LIKE ''%ip_address%'' OR column_name LIKE ''%biometric%'') ORDER BY pii_category, table_schema, table_name"}'::jsonb,
'{"condition": "row_count > 0", "description": "Columns with names suggesting PII/sensitive data found in database schema"}'::jsonb);

-- ─────────────────────────────────────────────────────────────
-- RC13: Sensitive columns IN USE — actively queried
-- ─────────────────────────────────────────────────────────────

-- SQL Server
INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect sensitive columns actively queried (sqlserver)',
'{"sql": "SELECT s.name AS schema_name, t.name AS table_name, c.name AS column_name, ius.user_seeks + ius.user_scans + ius.user_lookups AS total_reads, ius.last_user_seek, ius.last_user_scan, CASE WHEN c.name LIKE ''%ssn%'' OR c.name LIKE ''%social_security%'' THEN ''SSN'' WHEN c.name LIKE ''%credit_card%'' OR c.name LIKE ''%card_number%'' OR c.name LIKE ''%cvv%'' THEN ''Credit Card'' WHEN c.name LIKE ''%password%'' OR c.name LIKE ''%passwd%'' OR c.name LIKE ''%secret%'' OR c.name LIKE ''%api_key%'' THEN ''Credential'' WHEN c.name LIKE ''%email%'' THEN ''Email'' WHEN c.name LIKE ''%phone%'' OR c.name LIKE ''%mobile%'' THEN ''Phone'' WHEN c.name LIKE ''%salary%'' OR c.name LIKE ''%income%'' THEN ''Financial'' WHEN c.name LIKE ''%bank_account%'' OR c.name LIKE ''%iban%'' THEN ''Bank Account'' WHEN c.name LIKE ''%national_id%'' OR c.name LIKE ''%passport%'' OR c.name LIKE ''%tax_id%'' THEN ''Government ID'' WHEN c.name LIKE ''%medical%'' OR c.name LIKE ''%diagnosis%'' THEN ''Medical'' ELSE ''Other Sensitive'' END AS pii_category FROM sys.columns c JOIN sys.tables t ON t.object_id = c.object_id JOIN sys.schemas s ON s.schema_id = t.schema_id JOIN sys.dm_db_index_usage_stats ius ON ius.object_id = t.object_id AND ius.database_id = DB_ID() WHERE t.is_ms_shipped = 0 AND (ius.user_seeks + ius.user_scans + ius.user_lookups) > 0 AND (c.name LIKE ''%ssn%'' OR c.name LIKE ''%credit_card%'' OR c.name LIKE ''%password%'' OR c.name LIKE ''%email%'' OR c.name LIKE ''%phone%'' OR c.name LIKE ''%salary%'' OR c.name LIKE ''%bank_account%'' OR c.name LIKE ''%national_id%'' OR c.name LIKE ''%passport%'' OR c.name LIKE ''%tax_id%'' OR c.name LIKE ''%medical%'' OR c.name LIKE ''%diagnosis%'' OR c.name LIKE ''%birth%'' OR c.name LIKE ''%dob%'' OR c.name LIKE ''%ip_address%'' OR c.name LIKE ''%biometric%'' OR c.name LIKE ''%secret%'' OR c.name LIKE ''%api_key%'' OR c.name LIKE ''%iban%'' OR c.name LIKE ''%income%'') ORDER BY total_reads DESC"}'::jsonb,
'{"condition": "row_count > 0", "description": "Tables with sensitive columns are being actively read — PII data is in use"}'::jsonb);

-- Oracle
INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('oracle', 'query', 'Detect sensitive columns actively queried (oracle)',
'{"sql": "SELECT c.owner AS schema_name, c.table_name, c.column_name, s.num_rows, s.last_analyzed, CASE WHEN LOWER(c.column_name) LIKE ''%ssn%'' THEN ''SSN'' WHEN LOWER(c.column_name) LIKE ''%credit_card%'' OR LOWER(c.column_name) LIKE ''%card_number%'' THEN ''Credit Card'' WHEN LOWER(c.column_name) LIKE ''%password%'' OR LOWER(c.column_name) LIKE ''%secret%'' THEN ''Credential'' WHEN LOWER(c.column_name) LIKE ''%email%'' THEN ''Email'' WHEN LOWER(c.column_name) LIKE ''%phone%'' OR LOWER(c.column_name) LIKE ''%mobile%'' THEN ''Phone'' WHEN LOWER(c.column_name) LIKE ''%salary%'' OR LOWER(c.column_name) LIKE ''%income%'' THEN ''Financial'' WHEN LOWER(c.column_name) LIKE ''%national_id%'' OR LOWER(c.column_name) LIKE ''%passport%'' THEN ''Government ID'' WHEN LOWER(c.column_name) LIKE ''%medical%'' OR LOWER(c.column_name) LIKE ''%diagnosis%'' THEN ''Medical'' ELSE ''Other Sensitive'' END AS pii_category FROM all_tab_columns c JOIN all_tables s ON s.owner = c.owner AND s.table_name = c.table_name WHERE c.owner NOT IN (''SYS'',''SYSTEM'',''DBSNMP'',''OUTLN'',''MDSYS'',''ORDSYS'',''CTXSYS'',''XDB'') AND s.num_rows > 0 AND (LOWER(c.column_name) LIKE ''%ssn%'' OR LOWER(c.column_name) LIKE ''%credit_card%'' OR LOWER(c.column_name) LIKE ''%password%'' OR LOWER(c.column_name) LIKE ''%email%'' OR LOWER(c.column_name) LIKE ''%phone%'' OR LOWER(c.column_name) LIKE ''%salary%'' OR LOWER(c.column_name) LIKE ''%bank_account%'' OR LOWER(c.column_name) LIKE ''%national_id%'' OR LOWER(c.column_name) LIKE ''%passport%'' OR LOWER(c.column_name) LIKE ''%tax_id%'' OR LOWER(c.column_name) LIKE ''%medical%'' OR LOWER(c.column_name) LIKE ''%diagnosis%'' OR LOWER(c.column_name) LIKE ''%birth%'' OR LOWER(c.column_name) LIKE ''%secret%'' OR LOWER(c.column_name) LIKE ''%api_key%'' OR LOWER(c.column_name) LIKE ''%iban%'' OR LOWER(c.column_name) LIKE ''%income%'' OR LOWER(c.column_name) LIKE ''%biometric%'') ORDER BY s.num_rows DESC"}'::jsonb,
'{"condition": "row_count > 0", "description": "Tables with sensitive columns contain data and are in active use"}'::jsonb);

-- PostgreSQL
INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('postgresql', 'query', 'Detect sensitive columns actively queried (postgresql)',
'{"sql": "SELECT n.nspname AS schema_name, c.relname AS table_name, a.attname AS column_name, pg_stat_get_tuples_returned(c.oid) + pg_stat_get_tuples_fetched(c.oid) AS total_reads, pg_stat_get_last_autovacuum_time(c.oid) AS last_activity, CASE WHEN a.attname ~ ''(ssn|social_security)'' THEN ''SSN'' WHEN a.attname ~ ''(credit_card|card_number|cvv)'' THEN ''Credit Card'' WHEN a.attname ~ ''(password|passwd|secret|api_key)'' THEN ''Credential'' WHEN a.attname ~ ''(email)'' THEN ''Email'' WHEN a.attname ~ ''(phone|mobile)'' THEN ''Phone'' WHEN a.attname ~ ''(salary|income)'' THEN ''Financial'' WHEN a.attname ~ ''(national_id|passport|tax_id)'' THEN ''Government ID'' WHEN a.attname ~ ''(medical|diagnosis)'' THEN ''Medical'' ELSE ''Other Sensitive'' END AS pii_category FROM pg_attribute a JOIN pg_class c ON c.oid = a.attrelid JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname NOT IN (''information_schema'', ''pg_catalog'', ''pg_toast'') AND a.attnum > 0 AND NOT a.attisdropped AND c.relkind = ''r'' AND (pg_stat_get_tuples_returned(c.oid) + pg_stat_get_tuples_fetched(c.oid)) > 0 AND a.attname ~ ''(ssn|social_security|credit_card|card_number|cvv|password|passwd|secret|api_key|email|phone|mobile|birth|dob|salary|income|bank_account|iban|national_id|passport|tax_id|medical|diagnosis|ip_address|biometric)'' ORDER BY total_reads DESC"}'::jsonb,
'{"condition": "row_count > 0", "description": "Tables with sensitive columns are being actively read — PII data is in use"}'::jsonb);

-- MySQL
INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('mysql', 'query', 'Detect sensitive columns actively queried (mysql)',
'{"sql": "SELECT c.table_schema AS schema_name, c.table_name, c.column_name, s.table_rows, s.update_time AS last_activity, CASE WHEN c.column_name LIKE ''%ssn%'' THEN ''SSN'' WHEN c.column_name LIKE ''%credit_card%'' OR c.column_name LIKE ''%card_number%'' THEN ''Credit Card'' WHEN c.column_name LIKE ''%password%'' OR c.column_name LIKE ''%secret%'' THEN ''Credential'' WHEN c.column_name LIKE ''%email%'' THEN ''Email'' WHEN c.column_name LIKE ''%phone%'' OR c.column_name LIKE ''%mobile%'' THEN ''Phone'' WHEN c.column_name LIKE ''%salary%'' OR c.column_name LIKE ''%income%'' THEN ''Financial'' WHEN c.column_name LIKE ''%national_id%'' OR c.column_name LIKE ''%passport%'' THEN ''Government ID'' WHEN c.column_name LIKE ''%medical%'' OR c.column_name LIKE ''%diagnosis%'' THEN ''Medical'' ELSE ''Other Sensitive'' END AS pii_category FROM information_schema.columns c JOIN information_schema.tables s ON s.table_schema = c.table_schema AND s.table_name = c.table_name WHERE c.table_schema NOT IN (''information_schema'', ''mysql'', ''performance_schema'', ''sys'') AND s.table_rows > 0 AND (c.column_name LIKE ''%ssn%'' OR c.column_name LIKE ''%credit_card%'' OR c.column_name LIKE ''%password%'' OR c.column_name LIKE ''%email%'' OR c.column_name LIKE ''%phone%'' OR c.column_name LIKE ''%salary%'' OR c.column_name LIKE ''%bank_account%'' OR c.column_name LIKE ''%national_id%'' OR c.column_name LIKE ''%passport%'' OR c.column_name LIKE ''%tax_id%'' OR c.column_name LIKE ''%medical%'' OR c.column_name LIKE ''%diagnosis%'' OR c.column_name LIKE ''%birth%'' OR c.column_name LIKE ''%secret%'' OR c.column_name LIKE ''%api_key%'' OR c.column_name LIKE ''%iban%'' OR c.column_name LIKE ''%income%'' OR c.column_name LIKE ''%biometric%'') ORDER BY s.table_rows DESC"}'::jsonb,
'{"condition": "row_count > 0", "description": "Tables with sensitive columns contain data and are in active use"}'::jsonb);

-- ═══════════════════════════════════════════════════════════════
-- 3. DETECTION PATHS + PATH STEPS + RESOLUTION (all vendors)
-- ═══════════════════════════════════════════════════════════════

DO $$
DECLARE
    v_vendors TEXT[] := ARRAY['sqlserver', 'oracle', 'postgresql', 'mysql'];
    v_vendor TEXT;
    v_step_id INT;
    v_path_id INT;
    v_res_step_id INT;
    v_res_path_id INT;
    v_rcs TEXT[] := ARRAY['SEC-SQL-PRI-001-RC12', 'SEC-SQL-PRI-001-RC13'];
    v_rc TEXT;
    v_step_name TEXT;
    v_res_text TEXT;
BEGIN
    FOREACH v_rc IN ARRAY v_rcs
    LOOP
        FOREACH v_vendor IN ARRAY v_vendors
        LOOP
            -- Find the detection step
            IF v_rc = 'SEC-SQL-PRI-001-RC12' THEN
                v_step_name := 'Discover sensitive columns in schema (' || v_vendor || ')';
                v_res_text := 'Review discovered sensitive columns. Apply encryption (TDE, column-level), dynamic data masking, or role-based access controls. Classify columns per GDPR/HIPAA/PCI-DSS requirements. Consider using Always Encrypted (SQL Server), DBMS_CRYPTO (Oracle), pgcrypto (PostgreSQL), or AES_ENCRYPT (MySQL).';
            ELSE
                v_step_name := 'Detect sensitive columns actively queried (' || v_vendor || ')';
                v_res_text := 'Sensitive columns are actively being read. Audit which applications and users access these columns. Implement column-level permissions, dynamic data masking for non-privileged users, and ensure query logging captures access to sensitive tables. Review if all accessing applications truly need unmasked PII.';
            END IF;

            SELECT id INTO v_step_id FROM rootcause.detection_steps
            WHERE vendor_slug = v_vendor AND name = v_step_name
            ORDER BY id DESC LIMIT 1;

            IF v_step_id IS NULL THEN
                RAISE NOTICE 'Step not found: % / %', v_vendor, v_step_name;
                CONTINUE;
            END IF;

            -- Detection path (high)
            INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
            VALUES (v_rc, v_vendor, v_step_name || ' - high', 'Detects PII columns via schema analysis', 'diagnostic', true)
            RETURNING id INTO v_path_id;

            INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
            VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');

            -- Detection path (medium)
            INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
            VALUES (v_rc, v_vendor, v_step_name || ' - medium', 'Detects PII columns via schema analysis', 'diagnostic', true)
            RETURNING id INTO v_path_id;

            INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
            VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');

            -- Resolution step
            INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
            VALUES (v_vendor, 'recommendation', 'Resolve: ' || v_step_name,
                    json_build_object('action', v_res_text)::jsonb, 'high', false, true)
            RETURNING id INTO v_res_step_id;

            -- Resolution path
            INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
            VALUES (v_rc, v_vendor, 'Resolve: ' || v_step_name,
                    'resolve-pii-' || replace(lower(v_rc), '-', '_') || '-' || v_vendor,
                    v_res_text, 'supervised', 'high', true)
            RETURNING id INTO v_res_path_id;

            INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order)
            VALUES (v_res_path_id, v_res_step_id, 1);

            RAISE NOTICE 'Created % / %: step=%, path OK, resolution OK', v_rc, v_vendor, v_step_id;
        END LOOP;
    END LOOP;
END;
$$;

-- ═══════════════════════════════════════════════════════════════
-- 4. VERIFY
-- ═══════════════════════════════════════════════════════════════

SELECT '=== Root Causes ===' AS section;
SELECT root_cause_id, name, vendors_applicable
FROM rootcause.root_causes
WHERE root_cause_id IN ('SEC-SQL-PRI-001-RC12', 'SEC-SQL-PRI-001-RC13');

SELECT '=== Detection Paths ===' AS section;
SELECT dp.root_cause_id, dp.vendor_slug, dp.name
FROM rootcause.detection_paths dp
WHERE dp.root_cause_id IN ('SEC-SQL-PRI-001-RC12', 'SEC-SQL-PRI-001-RC13')
ORDER BY dp.root_cause_id, dp.vendor_slug;

SELECT '=== In v_rootcauses ===' AS section;
SELECT root_cause_id, root_cause_name, vendor_name, risk_level
FROM rootcause.v_rootcauses
WHERE root_cause_id IN ('SEC-SQL-PRI-001-RC12', 'SEC-SQL-PRI-001-RC13')
ORDER BY root_cause_id, vendor_name;

COMMIT;



-- View: monitoring.v_sec_sql_pri_001_rc12

-- DROP VIEW monitoring.v_sec_sql_pri_001_rc12;

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_001_rc12
 AS
 SELECT r.server,
    (j.value ->> 'schema_name'::text) AS schema_name,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'column_name'::text) AS column_name,
    (j.value ->> 'data_type'::text) AS data_type,
    (j.value ->> 'pii_category'::text) AS pii_category,
    (j.value ->> 'max_length'::text) AS max_length,
    (j.value ->> 'character_maximum_length'::text) AS character_maximum_length,
    (j.value ->> 'data_length'::text) AS data_length,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-PRI-001-RC12'::text);

ALTER TABLE IF EXISTS monitoring.v_sec_sql_pri_001_rc12
    OWNER TO enterprisedb;

-- View: monitoring.v_sec_sql_pri_001_rc13

-- DROP VIEW monitoring.v_sec_sql_pri_001_rc13;

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_001_rc13
 AS
 SELECT r.server,
    (j.value ->> 'schema_name'::text) AS schema_name,
    (j.value ->> 'table_name'::text) AS table_name,
    (j.value ->> 'column_name'::text) AS column_name,
    (j.value ->> 'pii_category'::text) AS pii_category,
    (j.value ->> 'total_reads'::text) AS total_reads,
    (j.value ->> 'table_rows'::text) AS table_rows,
    (j.value ->> 'num_rows'::text) AS num_rows,
    (j.value ->> 'last_user_seek'::text) AS last_user_seek,
    (j.value ->> 'last_user_scan'::text) AS last_user_scan,
    (j.value ->> 'last_activity'::text) AS last_activity,
    (j.value ->> 'last_analyzed'::text) AS last_analyzed,
    r.entry_date
   FROM (monitoring.general_metric_metadata_results r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
  WHERE ((r.metric_name)::text = 'SEC-SQL-PRI-001-RC13'::text);

ALTER TABLE IF EXISTS monitoring.v_sec_sql_pri_001_rc13
    OWNER TO enterprisedb;

