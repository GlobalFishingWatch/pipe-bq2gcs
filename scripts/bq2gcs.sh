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
    GCS_OUTPUT_FOLDER \
    DESTINATION_FORMAT \
    TEMPORAL_DATASET \
    COMPRESSION \
)

echo -e "\nRunning:\n${PROCESS}.sh $@ \n"

display_usage() {
  echo -e "\nUsage:\nbq2gcs.sh NAME JINJA_QUERY GCS_OUTPUT_FOLDER DESTINATION_FORMAT TEMPORAL_DATASET COMPRESSION\n"
  echo -e "NAME: Name to locate the kind of export and also used as temporal table name."
  echo -e "JINJA_QUERY: Jinja query to get the data to export."
  echo -e "GCS_OUTPUT_FOLDER: The Google Cloud Storage destination folder where will be stored the data."
  echo -e "DESTINATION_FORMAT: Destination format of the file."
  echo -e "TEMPORAL_DATASET: Temporal dataset used to store the results of the jinja query."
  echo -e "COMPRESSION: kind of compression applied to the output file."
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
UUID=$(uuidgen)
TEMPORAL_TABLE=${TEMPORAL_DATASET}.${UUID//-/_}
echo "TEMPORAL_TABLE=${TEMPORAL_TABLE}"

echo "=== Evaluation with jinja ==="
echo "${JINJA_QUERY}"
echo "=== Evaluation with jinja ==="

echo "${JINJA_QUERY}" \
   | bq --headless query \
    -n 0 \
    --nouse_legacy_sql \
    --destination_table ${TEMPORAL_TABLE}
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
if [ "${COMPRESSION}" != "NONE" ]
then
  EXTRACT_PARAMS="${EXTRACT_PARAMS} --compression ${COMPRESSION}"
  EXTENSION="${EXTENSION}.${COMPRESSION,,}"
fi
GCS_PATH=${GCS_OUTPUT_FOLDER}/${NAME}.${EXTENSION}
bq extract ${EXTRACT_PARAMS} ${TEMPORAL_TABLE} ${GCS_PATH}
if [ "$?" -ne 0 ]; then
  echo "  Unable to extract data from temporal table ${TEMPORAL_TABLE} to ${GCS_PATH}"
  exit 1
fi
echo "  Data successfully stored in GCS: <${GCS_PATH}>"
