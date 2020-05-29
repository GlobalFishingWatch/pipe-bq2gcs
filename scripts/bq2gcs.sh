#!/bin/bash
set -e

source pipe-tools-utils
THIS_SCRIPT_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )"
ASSETS=${THIS_SCRIPT_DIR}/../assets
source ${THIS_SCRIPT_DIR}/pipeline.sh

PROCESS=$(basename $0 .sh)
ARGS=(\
    NAME \
    JINJA_QUERY \
    DATE_RANGE \
    GCS_OUTPUT_FOLDER \
    DESTINATION_FORMAT \
)

echo -e "\nRunning:\n${PROCESS}.sh $@ \n"

display_usage() {
  echo -e "\nUsage:\nbq2gcs.sh NAME JINJA_QUERY DATE_RANGE GCS_OUTPUT_FOLDER\n"
  echo -e "NAME: Name to locate the kind of export and also used as temporal table name."
  echo -e "JINJA_QUERY: Jinja query to get the data to export."
  echo -e "DATE_RANGE: The date range to be queried. The format will be YYYY-MM-DD,YYYY-MM-DD."
  echo -e "GCS_OUTPUT_FOLDER: The Google Cloud Storage destination folder where will be stored the data."
  echo -e "DESTINATION_FORMAT: Destination format of the file."
  echo
}

if [[ $# -ne ${#ARGS[@]} ]]
then
    display_usage
    exit 1
fi

ARG_VALUES=("$@")
PARAMS=()
for index in ${!ARGS[*]}; do
  echo "${ARGS[$index]}=${ARG_VALUES[$index]}"
  declare "${ARGS[$index]}"="${ARG_VALUES[$index]}"
done


#################################################################
# Run jinja_query and save it in temporal table.
#################################################################
echo "Run jinja_query and save it in temporal table."
IFS=, read START_DATE END_DATE START_DATE_NODASH END_DATE_NODASH <<<"${DATE_RANGE}"
TEMPORAL_DATASET="0_ttl24h"
TEMPORAL_TABLE=${TEMPORAL_DATASET}.${NAME//-/_}
echo "TEMPORAL_TABLE=${TEMPORAL_TABLE}"

echo "=== Evaluation with jinja ==="
echo "${JINJA_QUERY}"
echo "=== Evaluation with jinja ==="

echo "${JINJA_QUERY}" \
   | bq --headless query \
    -n 0 \
    --nouse_legacy_sql \
    --destination_table ${TEMPORAL_TABLE} \
    --append_table
if [ "$?" -ne 0 ]; then
  echo "  Unable to run and store data in the temporal table ${TEMPORAL_TABLE}"
  exit 1
fi
echo "  Inserted results in table ${TEMPORAL_TABLE}"

#################################################################
# Export the results to GCS.
#################################################################
EXTENSION="csv"
EXTRACT_PARAMS=""
if [ "${DESTINATION_FORMAT}" != "CSV" ]
then
  EXTENSION="json"
  EXTRACT_PARAMS="--destination_format ${DESTINATION_FORMAT}"
fi
GCS_PATH=${GCS_OUTPUT_FOLDER}/${NAME}_${START_DATE_NODASH}_${END_DATE_NODASH}.${EXTENSION}
bq extract ${EXTRACT_PARAMS} ${TEMPORAL_TABLE} ${GCS_PATH}
if [ "$?" -ne 0 ]; then
  echo "  Unable to extract data from temporal table ${TEMPORAL_TABLE} to ${GCS_PATH}"
  exit 1
fi
echo "  Data successfully stored in GCS: <${GCS_PATH}>"
