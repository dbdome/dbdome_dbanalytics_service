-- Idempotent install for widget.treeview
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS widget;

CREATE SEQUENCE IF NOT EXISTS widget.treeview_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS widget.treeview (
    parent_row_id integer DEFAULT 0,
    row_id integer NOT NULL,
    item_name character varying(50),
    on_background_image character varying(255),
    off_background_image character varying(255),
    level integer DEFAULT 0,
    report_url character varying(255),
    is_active boolean DEFAULT false,
    item_sequence character varying(20)
);

ALTER TABLE widget.treeview ALTER COLUMN row_id SET DEFAULT nextval('widget.treeview_row_id_seq'::regclass);
ALTER SEQUENCE widget.treeview_row_id_seq OWNED BY widget.treeview.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE widget.treeview);
COPY _stg_load (parent_row_id, row_id, item_name, on_background_image, off_background_image, level, report_url, is_active, item_sequence) FROM stdin;
20	21	Cyber Attacks	\N	\N	1	/dbdome/items/cyber_attack_report	t	1.1
5	25	Sensitivity reports	\N	\N	2	/dbdome/items/sensitive_data_report	t	3.1.1
5	8	Connectivity Reports	on_connectivity_report	off_connectivity_report	2	/dbdome/items/connection_report	t	3.1.3
5	7	Transaction Reports	on_transaction_report	off_transaction_report	2	/dbdome/items/transaction_report	t	3.1.4
1	28	Action to be taken	\N	\N	1	/dbdome/items/action_types	t	2.4
1	29	SIEM Config	\N	\N	1	/dbdome/items/siem_config	t	2.5
6	9	Data activity monitoring Reports	on_dam_reports	off_dam_reports	2	/dbdome/items/DAM_report	t	3.2.1
2	18	User panel	\N	\N	2	/dbdome/items/user_panel	t	2.1.1
3	19	Server panel	\N	\N	2	/dbdome/items/servers	t	2.2.1
5	24	 SQL Injection	\N	\N	2	/dbdome/items/sql_injection_report	t	3.1.2
1	27	Retention policy	\N	\N	1	/dbdome/items/retention_policy	t	2.3
21	26	Cyber Attacks	\N	\N	2	/dbdome/items/cyber_attack_report	t	\N
0	32	Customized reports	\N	\N	2	/dbdome/items/customized_reports	t	4.1
0	33	Customized metrics	\N	\N	2	/dbdome/items/customized_metrics	t	4.2
0	1	management panel	on_management_panel	off_management_panel	0	\N	f	2
1	2	User management	on_user_management	off_user_management	1	\N	f	2.1
1	3	Server management	on_server_management	off_server_management	1	\N	f	2.2
6	10	Compliance  Reports	on_compliance_report	off_compliance_report	2	\N	f	3.2.5
6	11	Vulnerability assesment   Reports	on_vulnerability_report	off_vulnerability_report	2	\N	f	3.2.6
6	12	Entitle Reports	on_entitle_report	off_entitle_report	2	\N	f	3.2.7
6	13	Discovery and classification Reports	off_discovery_report	off_discovery_report	2	\N	f	3.2.8
6	14	Advanced anaylitics & threat detection Reports	on_analytics_report	on_analytics_report	2	\N	f	3.2.9
6	15	Risk spotter Reports	on_risk_report	off_risk_report	2	\N	f	3.2.2
6	16	Executive dashboard Reports	on_executive_report	off_executive_report	2	\N	f	3.2.4
6	17	File activity monitoring (F.A.M) Reports	on_fam_report	off_fam_report	2	\N	f	3.2.3
0	20	Cyber issues	\N	\N	0	\N	f	1
0	4	Reports	on_reports	off_reports	0	\N	f	3
4	5	User Reports	on_user_report	on_user_report	1	\N	f	3.1
21	22	Cyber Attack report	\N	\N	2	\N	f	3.1.5
4	6	Regulatory Reports	on_regulatory_report	off_regulatory_report	1	\N	f	3.2
\.
INSERT INTO widget.treeview (parent_row_id, row_id, item_name, on_background_image, off_background_image, level, report_url, is_active, item_sequence)
SELECT parent_row_id, row_id, item_name, on_background_image, off_background_image, level, report_url, is_active, item_sequence FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM widget.treeview);
DROP TABLE _stg_load;

SELECT setval('widget.treeview_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM widget.treeview),1), (SELECT count(*) FROM widget.treeview) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'widget' AND c.relname = 'treeview'
          AND con.conname = 'treeview_pkey') THEN
        ALTER TABLE ONLY widget.treeview
    ADD CONSTRAINT treeview_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
