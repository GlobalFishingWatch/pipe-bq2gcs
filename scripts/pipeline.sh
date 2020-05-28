#!/usr/bin/env bash

PIPELINE='pipe_bq2gcs'
PIPELINE_VERSION=$(python -c "import pkg_resources; print(pkg_resources.get_distribution('${PIPELINE}').version)")
