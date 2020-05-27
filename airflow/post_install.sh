#!/bin/bash

python $AIRFLOW_HOME/utils/set_default_variables.py \
    --force docker_image=$1 \
    pipe_bq2gcs \
    docker_run="{{ var.value.DOCKER_RUN }}" \
    project_id="{{ var.value.PROJECT_ID }}" \
    pipeline_bucket="{{ var.value.PIPELINE_BUCKET }}" \
    pipeline_dataset="{{ var.value.PIPELINE_DATASET }}" \
    temp_dataset="{{ var.value.TEMP_DATASET }}" \
    export_configurations="ARRAY OF CONFIGURATIONS"

echo "Installation Complete"
