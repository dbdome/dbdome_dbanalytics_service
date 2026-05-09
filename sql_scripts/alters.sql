alter table rootcause.issue_domains add severity text ;
alter table flowchart.visual_objects add alert_mail boolean default false;
alter table flowchart.visual_objects add alert_report boolean default false;
alter table flowchart.visual_objects add alert_siem boolean default false;
alter table rootcause.issue_root_causes add is_active boolean default true;
alter table rootcause.root_causes add is_active boolean default true;
alter table flowchart.visual_objects add metric_name text;
alter table metrics.servers add server_id UUID ;
alter table rootcause.domains add is_enabled boolean not null default true;
alter table rootcause.areas add is_enabled boolean not null default true;
update rootcause.domains set is_enabled = false where code != 'SEC';
CREATE OR REPLACE VIEW rootcause.v_rootcauses
 AS
 SELECT d.code AS domain_code,
    d.name AS domain_name,
    a.code AS area_code,
    a.name AS area_name,
    i.name AS issue_name,
    i.issue_id,
    rc.root_cause_id,
    rc.name AS root_cause_name,
    rc.description AS root_cause_desc,
    dp.name AS detection_name,
    dp.description AS detection_desc,
    stps.name AS step_name,
    stps.name,
    stps.content,
    stps.expected,
    dp.is_active,
    v.name AS vendor_name
   FROM (((((((rootcause.issues i
     JOIN rootcause.domains d ON (((d.code)::text = (i.domain_code)::text)))
     JOIN rootcause.areas a ON (((a.code)::text = (i.area_code)::text)))
     JOIN rootcause.root_causes rc ON (((rc.issue_id)::text = (i.issue_id)::text)))
     JOIN rootcause.detection_paths dp ON (((dp.root_cause_id)::text = (rc.root_cause_id)::text)))
     JOIN rootcause.detection_path_steps stpstp ON ((stpstp.detection_path_id = dp.id)))
     JOIN rootcause.detection_steps stps ON ((stps.id = stpstp.detection_step_id)))
     JOIN rootcause.vendors v ON (((v.slug)::text = (stps.vendor_slug)::text)))
	where (d.is_enabled is true and a.is_enabled is true);
ALTER TABLE IF EXISTS rootcause.v_rootcauses
    OWNER TO enterprisedb;


-- View: metrics.v_custom_metrics

-- DROP VIEW metrics.v_custom_metrics;

CREATE OR REPLACE VIEW metrics.v_custom_metrics
 AS
 SELECT custom_metrics.query,
    custom_metrics.category_id,
    custom_metrics.metric_name,
    custom_metrics.is_active,
    custom_metrics.db_vendor
   FROM metrics.custom_metrics
UNION ALL
 SELECT DISTINCT replace((v_rootcauses.content ->> 'sql'::text), '\n'::text, ' '::text) AS query,
    '-1'::integer AS category_id,
    v_rootcauses.root_cause_id AS metric_name,
    v_rootcauses.is_active,
    v_rootcauses.vendor_name AS db_vendor
   FROM rootcause.v_rootcauses;

ALTER TABLE IF EXISTS metrics.v_custom_metrics
    OWNER TO enterprisedb;


create table config.webook_alerts 
(
	row_id  serial primary key , 
	metric_type varchar(50) , 
	send_mail_alert  boolean  not null default true , 
	send_siem_alert  boolean  not null default true , 
	send_diagnosis_evidence boolean  not null default true  , 
	entry_date  timestamp  not null default   Now()
)




insert into config.webook_alerts ( metric_type , send_mail_alert , send_siem_alert , send_diagnosis_evidence ) 
select 'Security' , true , true , true

create table rootcause.severity 
(
	row_id serial primary key , 
	severity  text  not null , 
	is_enabled boolean default true
)
insert into rootcause.severity (severity)
select distinct risk_level from rootcause.v_root_cause_alerts where execute_numeric_query != 0;



-- View: rootcause.v_root_cause_alerts

-- DROP VIEW rootcause.v_root_cause_alerts;

CREATE OR REPLACE VIEW rootcause.v_root_cause_alerts
 AS
 SELECT DISTINCT raqrs.server,
    rc.domain_name,
    rc.area_name,
    rc.issue_name,
    rc.root_cause_id,
    rc.root_cause_name,
    rc.root_cause_desc,
    rc.detection_name,
    rc.detection_desc,
    rc.step_name,
    raqrs.query_result AS execute_numeric_query,
    rc.risk_level
   FROM (((rootcause.v_rootcauses rc
     JOIN rootcause.rootcause_alert_query raq ON ((raq.root_cause_id = (rc.root_cause_id)::text)))
     JOIN rootcause.rootcause_alert_query_result_server raqrs ON ((raqrs.root_cause_id = (rc.root_cause_id)::text)))
     JOIN metrics.servers s ON ((s.server = raqrs.server)))
  WHERE ((lower((rc.vendor_name)::text) = lower(s.db_vendor)) OR (lower((rc.vendor_name)::text) = 'sqlserver'::text));

ALTER TABLE IF EXISTS rootcause.v_root_cause_alerts
    OWNER TO enterprisedb;



CREATE EXTENSION IF NOT EXISTS "pgcrypto";





create schema processes
create table processes.organization 
(
	row_id  serial not null , 
	organization_name  text not null  , 
	api_url text not null , 
	api_key UUID DEFAULT gen_random_uuid() , 
	activity text not null , 
	entry_date timestamp not null default now() , 
	constraint pk_organization   primary key 
	(
		organization_name  
	)
)
create table processes.process
(
	row_id serial   not null  , 
	organization_id  int not null , 
	process_name    TEXT  NOT NULL , 
	category      TEXT  NOT NULL , 
	schedule_type  TEXT  NOT NULL , 
	schedule_expr  TEXT  NOT NULL , 
	expected_duration_ms	TEXT  NOT NULL , 
	entry_date  timestamp default Now() , 
	constraint pk_process   primary key 
	(
		organization_id ,   process_name
	)
)


create table processes.steps 
(
	row_id serial not null , 
	process_id  int not null , 
	step_name	text not null  , 
	step_type 	text  not null  , 
	step_order text  not null  , 
	expected_ms text  not null  , 
	expected_rows text  not null   , 
constraint  pk_steps primary key 
(
	step_name , process_id 
)
)

CREATE EXTENSION IF NOT EXISTS "pgcrypto";



CREATE OR REPLACE VIEW processes.v_processes_steps
 AS
 SELECT o.activity,
    o.api_key,
    o.api_url,
    o.organization_name,
    o.row_id AS org_id,
    p.category,
    p.schedule_type,
    p.expected_duration_ms AS process_expected_duration_ms,
    p.process_name,
    p.schedule_expr,    
	p.process_id  ,
    p.description,
    s.step_name,
    s.step_order,
    s.step_type,
    s.expected_ms AS step_expected_ms,
    s.expected_rows AS step_expected_rows
   FROM ((processes.organization o
     JOIN processes.process p ON ((p.organization_id = o.row_id)))
     JOIN processes.steps s ON ((s.process_id = p.row_id)));

ALTER TABLE IF EXISTS processes.v_processes_steps
    OWNER TO enterprisedb;


alter table processes.process add process_id  UUID DEFAULT gen_random_uuid() 



CREATE OR REPLACE VIEW processes.v_processes_steps_json
 AS
 SELECT org_id,
    organization_name,
    api_key,
    api_url,
    jsonb_agg(jsonb_build_object('id', process_id, 'name', process_name, 'description', description, 'category', category, 'schedule_type', schedule_type, 'schedule_expr', schedule_expr, 'expected_duration_ms', process_expected_duration_ms, 'steps', steps) ORDER BY process_id) AS processes
   FROM ( SELECT v_processes_steps.api_url,
            v_processes_steps.api_key,
            v_processes_steps.org_id,
            v_processes_steps.organization_name,
            v_processes_steps.process_id,
            v_processes_steps.process_name,
            v_processes_steps.description,
            v_processes_steps.category,
            v_processes_steps.schedule_type,
            v_processes_steps.schedule_expr,
            v_processes_steps.process_expected_duration_ms,
            jsonb_agg(jsonb_build_object('name', v_processes_steps.step_name, 'type', v_processes_steps.step_type, 'order', v_processes_steps.step_order, 'expected_ms', v_processes_steps.step_expected_ms, 'expected_rows', v_processes_steps.step_expected_rows) ORDER BY v_processes_steps.step_order) AS steps
           FROM processes.v_processes_steps
          GROUP BY v_processes_steps.api_url, v_processes_steps.api_key, v_processes_steps.org_id, v_processes_steps.organization_name, v_processes_steps.process_id, v_processes_steps.process_name, v_processes_steps.description, v_processes_steps.category, v_processes_steps.schedule_type, v_processes_steps.schedule_expr, v_processes_steps.process_expected_duration_ms) t
  GROUP BY api_url, api_key, org_id, organization_name;

ALTER TABLE IF EXISTS processes.v_processes_steps_json
    OWNER TO enterprisedb;



create schema reports
CREATE TABLE reports.pdf_reports (
    report_id serial PRIMARY KEY,
    file_name text,
    created_at timestamp default now(),
    pdf_data bytea
);


CREATE TABLE reports.html_reports (
    report_id serial PRIMARY KEY,
    file_name text,
    created_at timestamp DEFAULT now(),
    html_content text
);


create table  processes.executions
(
	row_id serial   not null , 
	process_id int not null  , 
	step_id UUID not null , 
	status text not null , 
	started_at timestamp not null default Now() , 
    completed_at timestamp not null default Now() , 
    duration_ms int   not null default 0 , 
	row_count int  not null default 0 , 
    error_message text not null , 
	entry_date  timestamp not null default now()
)




alter table processes.steps add id UUID DEFAULT gen_random_uuid() 
alter table processes.steps add id UUID DEFAULT gen_random_uuid() ;
alter table processes.steps add timeout_ms int not null DEFAULT 0 ;
alter table processes.steps add duration_warn_pct numeric not null DEFAULT 0 ;
alter table processes.steps add row_count_drift_pct numeric not null DEFAULT 0 ;
alter table  processes.steps			 add step_query TEXT 
alter table processes.executions add execution_key text 