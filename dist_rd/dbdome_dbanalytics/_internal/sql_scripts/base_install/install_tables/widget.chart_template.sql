-- Idempotent install for widget.chart_template
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS widget;

CREATE SEQUENCE IF NOT EXISTS widget.chart_template_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS widget.chart_template (
    row_id integer NOT NULL,
    chart_type text NOT NULL,
    chart_template text NOT NULL,
    chart_example text NOT NULL,
    date_entry timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE widget.chart_template ALTER COLUMN row_id SET DEFAULT nextval('widget.chart_template_row_id_seq'::regclass);
ALTER SEQUENCE widget.chart_template_row_id_seq OWNED BY widget.chart_template.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE widget.chart_template);
COPY _stg_load (row_id, chart_type, chart_template, chart_example, date_entry) FROM stdin;
1	secure	   {\n\t"charts": {\n\t\t\t\t"Secure": "<secure_text>"\n\t\t\t   }\n }	"charts": {\n "Secure": "Perimeter is clear",\n "Insecure": "Vulnerability detected!",\n "Safe": "All is well",\n "Unsafe": "Some checks failed",\n "Warning": "be careful",\n "Alert": "critical issue!"\n }\n }	2025-04-17 06:32:45.391217
2	risk	{\n\t\t"charts": \n\t\t\t{\n\t\t\t\t"Risk": \n\t\t\t\t\t{\n\t\t\t\t\t\t"level": <level_no>,\n\t\t\t\t\t\t"text": "<level_text>"\n\t\t\t\t\t}\n\t\t\t}\n }	{\n "charts": {\n "Risk": {\n "level": 2,\n "text": "Risk is looming (text)"\n }\n }\n }	2025-04-17 06:40:53.381994
3	gauge	{\n\t"charts": {\n\t"Gauge": {\n\t"percent": <gauge_percentage>,\n\t"text": "<gauge_text>"\n }\n }\n }	{\n "charts": {\n "Gauge": {\n "percent": 0.3,\n "text": "Storage Saving Impact"\n }\n }\n }\n	2025-04-17 06:41:43.039309
4	column	{\n "charts": {\n "Column": {\n "series": <series_array>,\n "categories": <series_categories_array>,\n "text": "<series_text>"\n }\n }\n }	{\n  "charts": {\n "Column": {\n "series": 40, 23, 58,\n "categories": "Series &", "Categories", "Same Length",\n "text": "Some column names and values"\n }\n }\n }	2025-04-17 06:42:29.025286
5	line	{\n "charts": {\n "Line": {\n "categories": <categories_series>,\n "series": <complex_series>,\n "text": "<complex_series_text>"\n }\n }\n }	{\n "charts": {\n "Line": {\n "categories": "Monday", "Tuesday", "Wednesday", "Thursday", "Friday",\n "series": \n {"name": "Dogs", "data": 10, 12, 9, 10, 11},\n {"name": "Cats", "data": 6, 7, 9, 18, 21},\n {"name": "Horses", "data": 3, 3, 4, 2, 1}\n ,\n "text": "All kind of animals over time"\n }\n }\n }	2025-04-17 06:43:35.257343
6	bar	{\n "charts": {\n "Bar": {\n "series": \n {\n "name": "<bar_name1>",\n "data": <bar_data_array1>\n },\n {\n "name": "<bar_name2>",\n "data": <bar_data_array2>\n },\n {\n"name": "<bar_name3>",\n "data": <bar_data_array3> \n }\n ,\n "categories": <categories_array>,\n "text": "<bar_text>"\n }\n }\n}	{\n\t "charts": {\n "Bar": {\n "series": \n {\n "name": "CPU",\n "data": 30, 40, 60\n },\n {\n "name": "Memory",\n "data": 10, 15, 22\n },\n {\n "name": "Network",\n "data": 17, 10, 30\n }\n ,\n "categories": "Yesterday", "Today", "Tomorrow",\n "text": "Optional Caption, daily chart"\n }\n }\n\n}\n	2025-04-17 06:44:38.400904
7	area	{\n "charts": {\n "Area": {\n "series": <series_array>\n "categories": <category_array>,\n "text": "<area_text>"\n }\n }\n}	{\n "charts": {\n "Area": {\n "series": \n {\n "name": "series1",\n "data": 31, 40, 28, 51, 42, 109, 100\n },\n {\n "name": "series2",\n "data": 11, 32, 45, 32, 34, 52, 41\n },\n "categories": "9", "10", "11", "12", "13", "14", "15",\n "text": "Nice numbers"\n }\n }\n }	2025-04-17 06:45:53.074666
8	pie	{\n  "charts": {\n "Pie": {\n "series": <pie_array>,\n "labels": <label_array>,\n "text": ""\n }\n } )	\n {\n "charts": {\n "Pie": {\n "series": 40, 30, 25, 5,\n "labels": "Queries", "Latencies", "Indexes", "Procedures",\n "text": "Performance optimization opportunities"\n }\n }\n  }	2025-04-17 06:46:59.402599
9	table	{"charts": {},"table":<table>}	{"charts": {},"table":<table>}	2025-04-17 06:47:53.901408
10	insecure	{\n\t"charts": {\t\t\t\t\n\t\t\t\t"Insecure": "<insecure_text>"\n\t\t\t   }\n }	   {\n\t"charts": {\t\t\t\t\n\t\t\t\t"Insecure": "<insecure_text>"\n\t\t\t   }\n }	2025-04-17 06:48:53.962219
11	safe	   {\n\t"charts": {\t\t\t\n\t\t\t\t\n\t\t\t\t"Safe": "<safe_text>"\n\t\t\t   }\n }	   {\n\t"charts": {\t\t\t\n\t\t\t\t\n\t\t\t\t"Safe": "<safe_text>"\n\t\t\t   }\n }	2025-04-17 12:45:56.557021
12	unsafe	   {\n\t"charts": {\t\t\t\n\t\t\t\t\n\t\t\t\n\t\t\t\t"Unsafe": "<unsafe_text>"\n\t\t\t   }\n }	   {\n\t"charts": {\t\t\t\n\t\t\t\t\n\t\t\t\n\t\t\t\t"Unsafe": "<unsafe_text>"\n\t\t\t   }\n }	2025-04-17 15:05:23.020464
13	warning	   {\n\t"charts": {\t\t\t\n\t\t\t\t"Warning": "<warning_text>"\n\t\t\t   }\n }	   {\n\t"charts": {\t\t\t\n\t\t\t\t"Warning": "<warning_text>"\n\t\t\t   }\n }	2025-04-17 15:06:21.219289
14	alert	   {\n\t"charts": {\t\t\t\n\t\t\t\t"Alert": "<alert_text>"\n\t\t\t   }\n }	   {\n\t"charts": {\t\t\t\n\t\t\t\t"Alert": "<alert_text>"\n\t\t\t   }\n }	2025-04-17 15:23:38.974579
\.
INSERT INTO widget.chart_template (row_id, chart_type, chart_template, chart_example, date_entry)
SELECT row_id, chart_type, chart_template, chart_example, date_entry FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM widget.chart_template);
DROP TABLE _stg_load;

SELECT setval('widget.chart_template_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM widget.chart_template),1), (SELECT count(*) FROM widget.chart_template) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'widget' AND c.relname = 'chart_template'
          AND con.conname = 'chart_template_pkey') THEN
        ALTER TABLE ONLY widget.chart_template
    ADD CONSTRAINT chart_template_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
