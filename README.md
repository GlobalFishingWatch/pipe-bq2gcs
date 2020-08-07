# pipe-bq2gcs
Easy way to read from GlobalFishingWatch Biquery tables and share them through gcs.

# Requirements

## Setup

Use an external named volume so that we can share gcp auth across containers
Before first use, this volume must be manually created with
  `docker volume create --name=gcp`

# Instalation

This project requires to complete the export-configs variable in Airflow Variables.


## keywords for jinja
We have availble the following keywords that we can use in the jinja queries and depends on the schedule interval we choose.

* `start_yyyymmdd` it refeers to the start date of the schedule interval you chose and will have the value of the first day. Example, we want to run the 20th of October 2020, this value will be for schedule interval daily `2020-08-20` , for monthly `2020-08-01` and for yearly `2020-01-01`. The format will be `YYYY-MM-DD`.
* `end_yyyymmdd` it refeers to the end date of the schedule interval you chose and will have the value of the last day. Example, we want to run the 20th of October 2020, this value will be for schedule interval daily `2020-08-20` , for monthly `2020-08-31` and for yearly `2020-12-31`. The format will be `YYYY-MM-DD`.
* `start_yyyymmdd_nodash` it refeers to the start date of the schedule interval you chose and will have the value of the first day. Example, we want to run the 20th of October 2020, this value will be for schedule interval daily `20200820` , for monthly `20200801` and for yearly `20200101`. The format will be `YYYYMMDD`.
* `end_yyyymmdd_nodash` it refeers to the end date of the schedule interval you chose and will have the value of the last day. Example, we want to run the 20th of October 2020, this value will be for schedule interval daily `20200820` , for monthly `20200831` and for yearly `20201231`. The format will be `YYYYMMDD`.

This are the most used. we can add more if anyone needs it.

## Main structure

The main structure needed is:

* `days_to_retry`: [OPTIONAL] let us configure how many days to retry the task for a particular configuration before report with an alert of failure.
* `compression`: [OPTIONAL] let us configure the output from BigQuery to GCS in a compressed file instead of a raw file. The options available are ["GZIP", "DEFLATE", "SNAPPY", "NONE"].
* `gcs_output_folder`: This is the GCS path output folder where you want to put the extracted files. Example `gs://scratch-matias/bq2gcs`.
* `jinja_query`: This is the dynamic jinja query that get the results you want to share with the rest. Here you can used the `kewords` mentioned and they will vary depending on the schedule interval you chose to run.
* `name`: This is the name to identify easily the bq2gcs transformation we want.
* `sensor_jinja_query`: This fields depends exculsively of what we put in `sensor_type`. It could have the value patter of `dataset.table` for sharded tables, the  patter of `dataset.table` for partitioning table or for custom this is the dynamic jinja query that lets check the existence of a value in a column or maybe the table itself before running the query to get the results. Here you can used the `kewords` mentioned and they will vary depending on the schedule interval you chose to run.
* `sensor_type`: let us configure the kind of source query we want to do. There are only 3 kinds: `sharded`, `partitioning` and `custom`.
* `output_format`: [OPTIONAL] let configure the output format of the file to share, the options are ["CSV", "NEWLINE_DELIMITED_JSON"]. It is set by default as CSV.


## kind of sensor types

These are the kind of sensor types and once we decide what to use, it will affect the field `sensor_jinja_query` on how to write it.

* `sharded`: It expect a dataset and a table in this format `DATASET.TABLE` in `sensor_jinja_query` field and uses it to sensor with BigQuerySensorOperator. Have into account that will concat the wildcard char `*` at the end of the value to get all the sharded tables. Example: `scratch_matias_ttl_60_days.20200325_features_`.
* `partitioning`: It expect a dataset and a table in this format `DATASET.TABLE` in `sensor_jinja_query` field and uses it to sensor with BigQueryCheckOperator. Example: `scratch_matias_ttl_60_days.vms_chile_raw_chile_aquaculture_naf_processed_partitioned`.
* `custom`: Let you run a dynamic jinja query to validate existance or any other purpose that let us validate before running the main query. It uses the field `sensor_jinja_query` as the query. Example: `select count(*) from `pipe_indonesia_production_v20200320.messages_scored_*` where timestamp >= TIMESTAMP(\"{{ start_yyyymmdd }}\") and timestamp <= TIMESTAMP(\"{{ end_yyyymmdd }}\") and nnet_score != 0"`.



# Examples

These are examples to configure:

## Example 1 - For SHARDED tables. source_type: SHARDED.

```json
{
	"export_configs": [{
		"gcs_output_folder": "gs://scratch-matias/bq2gcs",
		"jinja_query": "select * from scratch_matias_ttl_60_days.20200325_features_{{ start_yyyymmdd_nodash }}",
		"name": "matias_test",
		"sensor_jinja_query": "scratch_matias_ttl_60_days.20200325_features_",
		"sensor_type": "sharded"
	}]
```

Here the `sensor_type` is sharded.
This means that the table mentioned in `sensor_jinja_table` is a sharded table.
There will be a task inside the DAG assigned to check this sensor and if it works well, then is going to run the `jinja_query` replacing the jinja keywords and exported the results in a file under the `gcs_output_folder` path and who name is the schedule interval mode and the date that begins (`gs://scratch-matias/bq2gcs/daily_20200701.json.gz`).

Airflow Output
```
DAG
 Lsource_exist_scratch_matias_ttl_60_days.20200325_features_
  Lexporter_matias_test
```

output:
```
$ gsutil ls gs://scratch-matias/bq2gcs
gs://scratch-matias/bq2gcs/matias_test_daily_20170101.csv
```


## Example 2 - For PARTITIONED tables. source_type: PARTITIONING.

```json
{
	"export_configs": [{
		"gcs_output_folder": "gs://scratch-matias/bq2gcs",
		"jinja_query": "select * from scratch_matias_ttl_60_days.vms_chile_raw_chile_aquaculture_naf_processed_partitioned where timestamp = TIMESTAMP(\"{{ start_yyyymmdd }}\")",
		"name": "matias_partitioning_test",
		"sensor_jinja_query": "scratch_matias_ttl_60_days.vms_chile_raw_chile_aquaculture_naf_processed_partitioned",
		"sensor_type": "partitioning"
	}
```

Here the `sensor_type` is partitioning.
This means that the table mentioned in `sensor_jinja_table` is a partitioned table.
There will be a task inside the DAG assigned to check this sensor and if it works well, then is going to run the `jinja_query` replacing the jinja keywords and exported the results in a file under the `gcs_output_folder` path and who name is the schedule interval mode and the date that begins (`gs://scratch-matias/bq2gcs/daily_20200701.json.gz`).

Airflow Output
```
DAG
 Lpartition_check_vms_chile_raw_chile_aquaculture_naf_processed_partitioned
  Lexporter_matias_partitioning_test
```

output:
```
$ gsutil ls gs://scratch-matias/bq2gcs
gs://scratch-matias/bq2gcs/matias_partitioning_test_daily_20170101.csv
```


## Example 3 - for CUSTOM queries. source_type: custom.

```json
{
	"export_configs": [{
		"compression": "GZIP",
		"gcs_output_folder": "gs://data-download-portal-development/indonesia_v20200320/monthly",
		"jinja_query": "select * from `pipe_indonesia_production_v20200320.messages_scored_*` where timestamp >= TIMESTAMP(\"{{ start_yyyymmdd }}\") and timestamp <= TIMESTAMP(\"{{ end_yyyymmdd }}\") and nnet_score != 0",
		"name": "indonesia_v20200320",
		"output_format": "NEWLINE_DELIMITED_JSON",
		"sensor_jinja_query": "select count(*) from `pipe_indonesia_production_v20200320.messages_scored_*` where timestamp >= TIMESTAMP(\"{{ start_yyyymmdd }}\") and timestamp <= TIMESTAMP(\"{{ end_yyyymmdd }}\") and nnet_score != 0",
		"sensor_type": "custom"
	}]
}
```

Here the `sensor_type` is custom.
This means that the field `sensor_jinja_table` is a custom sensor jinja query.
There will be a task inside the DAG assigned to check this sensor and if it works well, then is going to run the `jinja_query` replacing the jinja keywords and exported the results in a file under the `gcs_output_folder` path and who name is the schedule interval mode and the date that begins (`gs://data-download-portal-development/indonesia_v20200320/monthly/monthly_20200701.json.gz`).
Check that also there is a field `output_format` that can have CSV and NEWLINE_DELIMITED_JSON as values, NEWLINE_DELIMITED_JSON is useful for nested schemas like this example.
The optional field `compression` let us save it in a GZIP compressed file or one of the following list ["GZIP", "DEFLATE", "SNAPPY", "NONE"].

Airflow Output
```
DAG
 Lcustom_check
  Lexporter_indonesia_v20200320
```

output:
```
$ gsutil ls gs://scratch-matias/bq2gcs
gs://scratch-matias/bq2gcs/indonesia_v20200320_daily_20140101.json
```
