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
* `start_yyyymmdd` or `end_yyyymmdd` to define the start and end of dates in format YYYY-MM-DD
* `start_yyyymmdd_nodash` or `end_yyyymmdd_nodash` to define the start and end of dates as YYYYMMDD.


## Main structure

The main structure needed is:

* `gcs_output_folder`: This is the output folder where you want to put the extracted files.
* `jinja_query`: This is the dynamic jinja where you can use * `name`: This is the output name of the file and also is used as a table name. As table will be parsed to use `_` instead of `-`.
* `sensor_jinja_query`: This is the dynamic jinja where you can use the keywords already mentioned. Useful to put the query to sensor the next extraction.
* `sensor_type`: There are only 3 kinds: `sharded`, `partitioning` and `custom`.
* `output_format`: [OPTIONAL] set CSV as a default output format. It also accepts the `NEWLINE_DELIMITED_JSON` format (useful to download nested schemas).


## sensor types

* `sharded`: It expect a dataset and a table in this format `DATASET.TABLE` in `sensor_jinja_query` field and uses it to sensor with BigQuerySensorOperator.
* `partitioning`: It expect a dataset and a table in this format `DATASET.TABLE` in `sensor_jinja_query` field and uses it to sensor with BigQueryCheckOperator.
* `custom`: Let you run a dynamic jinja query using `sensor_jinja_query` field as the query to be run.



# Examples

These are examples to configure:

## Example 1 - SHARDED

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

Here the `sensor_type` is sharded, this means that the table mentioned in `sensor_jinja_table` is a sharded table. There will be a task inside the DAG assigned to check this sensor and if it works well, then is going to run the `jinja_query` replacing the jinja keywords and exported the results in a file under the `gcs_output_folder` path and who name is the property `name` plus the schedule interval mode and the date that begins.
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


## Example 2 - PARTITIONING

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

Here the `sensor_type` is partitioning, this means that the table mentioned in `sensor_jinja_table` is a partitioned table. There will be a task inside the DAG assigned to check this sensor and if it works well, then is going to run the `jinja_query` replacing the jinja keywords and exported the results in a file under the `gcs_output_folder` path and who name is the property `name` plus the schedule interval mode and the date that begins.
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


## Example 3 - CUSTOM

```json
{
	"export_configs": [{
		"gcs_output_folder": "gs://data-download-portal-development/indonesia_v20200320/monthly",
		"jinja_query": "select * from `pipe_indonesia_production_v20200320.messages_scored_*` where timestamp >= TIMESTAMP(\"{{ start_yyyymmdd }}\") and timestamp <= TIMESTAMP(\"{{ end_yyyymmdd }}\") and nnet_score != 0",
		"name": "indonesia_v20200320",
		"output_format": "NEWLINE_DELIMITED_JSON",
		"sensor_jinja_query": "select count(*) from `pipe_indonesia_production_v20200320.messages_scored_*` where timestamp >= TIMESTAMP(\"{{ start_yyyymmdd }}\") and timestamp <= TIMESTAMP(\"{{ end_yyyymmdd }}\") and nnet_score != 0",
		"sensor_type": "custom"
	}]
}
```

Here the `sensor_type` is custom, this means that the field `sensor_jinja_table` is a custom sensor jinja query. There will be a task inside the DAG assigned to check this sensor and if it works well, then is going to run the `jinja_query` replacing the jinja keywords and exported the results in a file under the `gcs_output_folder` path and who name is the property `name` plus the schedule interval mode and the date that begins. Check that also there is a field `output_format` that can have CSV and NEWLINE_DELIMITED_JSON as values, NEWLINE_DELIMITED_JSON is useful for nested schemas like this example.
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
