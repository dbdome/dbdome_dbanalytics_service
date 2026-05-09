alter table  config.webook_alerts add risk_level char(10)
alter table  config.webook_alerts add is_active boolean default  true
alter table config.webook_alerts  add recurrency_hours int default 0 