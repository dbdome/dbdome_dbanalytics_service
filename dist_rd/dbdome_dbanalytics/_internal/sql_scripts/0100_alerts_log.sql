
create table if not exists alerts.alert_log
(
	row_id serial primary key not null , 
	server varchar(100) not null , 
	root_cause_id varchar(100)  not null  , 
	risk_level  varchar(50) not null , 
	metadata jsonb not null  , 
	metric_query jsonb , 
	login_name text , 
	entry_date timestamp not null default Now()
	
);

ALTER TABLE alerts.alert_log ADD COLUMN IF NOT EXISTS login_name text;
ALTER TABLE alerts.alert_log ADD COLUMN IF NOT EXISTS metric_query jsonb;


ALTER TABLE alerts.mail_alert_log ADD COLUMN IF NOT EXISTS login_name text;
ALTER TABLE alerts.mail_alert_log ADD COLUMN IF NOT EXISTS metric_query jsonb;
