from airflow import DAG
from airflow.contrib.operators.bigquery_check_operator import BigQueryCheckOperator
from airflow.models import Variable

from airflow_ext.gfw import config as config_tools
from airflow_ext.gfw.models import DagFactory

from datetime import timedelta, date

from jinja2 import Template

from jsonschema import validate

import json
import os
import re

PIPELINE = "pipe_bq2gcs"

def table_partition_check(project_id, dataset_id, table_id, date):
    return BigQueryCheckOperator(
        task_id='partition_check_{}'.format(table_id),
        project_id=project_id,
        dataset_id=dataset_id,
        sql='SELECT COUNT(*) FROM [{}.{}${}]'.format(dataset_id, table_id, date),
        retries=2*24*3,                        # Retries 3 days with 30 minutes.
        execution_timeout=timedelta(days=3),   # TimeOut of 3 days.
        retry_delay=timedelta(minutes=30),     # Delay in retries 30 minutes.
        max_retry_delay=timedelta(minutes=30), # Max Delay in retries 30 minutes
        on_failure_callback=config_tools.failure_callback_gfw
    )

def table_custom_check(jinja_query):
    return BigQueryCheckOperator(
        task_id='custom_check',
        sql=jinja_query,
        retries=2*24*3,                        # Retries 3 days with 30 minutes.
        execution_timeout=timedelta(days=3),   # TimeOut of 3 days.
        retry_delay=timedelta(minutes=30),     # Delay in retries 30 minutes.
        max_retry_delay=timedelta(minutes=30), # Max Delay in retries 30 minutes
        on_failure_callback=config_tools.failure_callback_gfw
    )

# def is_partitioned_table(project_id, dataset_id, table_id):
#     return BigQueryCheckOperator(
#         task_id='is_partitioned_table',
#         project_id=project_id,
#         dataset_id=dataset_id,
#         sql='SELECT'
#               'is_partitioning_column'
#             'FROM'
#               '${dataset_id}.INFORMATION_SCHEMA.COLUMNS'
#             'WHERE'
#               'table_name = ${table_id}'
#               'AND is_partitioning_column = "YES"'
#         .format(dataset_id, table_id),
#         retries=2*24*1,                        # Retries 3 days with 30 minutes.
#         execution_timeout=timedelta(days=1),   # TimeOut of 3 days.
#         retry_delay=timedelta(minutes=30),     # Delay in retries 30 minutes.
#         max_retry_delay=timedelta(minutes=30), # Max Delay in retries 30 minutes
#         on_failure_callback=config_tools.failure_callback_gfw
#     )

class PipeBq2GcsDagFactory(DagFactory):

    def __init__(self, pipeline=PIPELINE, **kwargs):
        super(PipeBq2GcsDagFactory, self).__init__(pipeline, **kwargs)
        self.pipeline = '{}_{name}'.format(self.pipeline,**self.config['export_config'])

    def source_date_range(self):
        """
        Gives the date range separated by a comma.
        :param nodash if we need that value in nodash.
        :type nodash bool.
        """
        date_range_map={
            '@daily':'{{ ds }},{{ tomorrow_ds }}',
            '@monthly':'{{ first_day_of_month }},{{ last_day_of_month }}',
            '@yearly':'{{ first_day_of_year }},{{ last_day_of_year }}'
        }
        date_range=date_range_map[self.schedule_interval]
        return '{},{}'.format(date_range, re.sub('{{ ([^ ]*) }}','{{ \\1_nodash }}', date_range))

    def jinja_eval(self, message, date_ranges):
        return Template(message).render(
            start_yyyymmdd=date_ranges[0],
            end_yyyymmdd=date_ranges[1],
            start_yyyymmdd_nodash=date_ranges[2],
            end_yyyymmdd_nodash=date_ranges[3]
        )

    def build(self, mode):
        dag_id = '{}_{}'.format(self.pipeline, mode)
        date_ranges=self.source_date_range()
        export_config=self.config['export_config']
        export_config['jinja_query_parsed']=self.jinja_eval(export_config['jinja_query'], date_ranges.split(","))
        table_path=export_config['sensor_jinja_query'].split('.')

        with DAG(dag_id, schedule_interval=self.schedule_interval, default_args=self.default_args) as dag:

            # Replace this if with a simple detect if the table is partitioned or not.
            if export_config['sensor_type']=='custom':
                export_config['sensor_jinja_query_parsed']=self.jinja_eval(export_config['sensor_jinja_query'], date_ranges.split(","))
                sensor = table_custom_check('{sensor_jinja_query_parsed}'.format(**export_config))
            elif export_config['sensor_type'] == 'partitioning':
                # Sharded expect to pass a dataset.table as sensor_jinja_query.
                # Remind than later append the '$dsnodash' and make the query
                sensor = table_partition_check(
                    '{project_id}'.format(**self.config),
                    '{}'.format(table_path[0]),
                    '{}'.format(table_path[1]),
                    '{ds_nodash}'.format(**self.config))
            else:
                # Sharded expect to pass a dataset.table as sensor_jinja_query.
                sensor = self.table_sensor(
                    dag=dag,
                    task_id='sharded_exists_{}'.format(table_path[1]),
                    project='{project_id}'.format(**self.config),
                    dataset='{}'.format(table_path[0]),
                    table='{}'.format(table_path[1]),
                    date='{ds_nodash}'.format(**self.config))

            exporter = self.build_docker_task({
                'task_id':'exporter_{name}'.format(**export_config),
                'pool':'k8operators_limit',
                'docker_run':'{docker_run}'.format(**self.config),
                'image':'{docker_image}'.format(**self.config),
                'name':'bq2gcs-{name}'.format(**export_config),
                'dag':dag,
                'arguments':['bq2gcs',
                             '{name}'.format(**export_config),
                             '{jinja_query_parsed}'.format(**export_config),
                             '{}'.format(date_ranges),
                             '{gcs_output_folder}'.format(**export_config)]
            })


            sensor >> exporter

            return dag

def validateJson(data):
    folder=os.path.abspath(os.path.dirname(__file__))
    with open('{}/{}'.format(folder,"schemas/bq2gcs_schema.json")) as bq2gcs_schema:
        validate(instance=data, schema=json.loads(bq2gcs_schema.read()))

variable_values = config_tools.load_config(PIPELINE)
validateJson(variable_values)
for export_config in variable_values['export_configs']:
    for mode in ['daily', 'monthly', 'yearly']: # TODO smpiano restrict to daily in first implementation then open it
        dag_instance = PipeBq2GcsDagFactory(schedule_interval='@{}'.format(mode), extra_config={'export_config':export_config}).build(mode)
        globals()[dag_instance.dag_id] = dag_instance
