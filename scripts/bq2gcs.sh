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
    GCS_OUTPUT \
)

echo -e "\nRunning:\n${PROCESS}.sh $@ \n"

display_usage() {
  echo -e "\nUsage:\nbq2gcs.sh SOURCE_TABLE DATE_TO_QUERY GCS_OUTPUT\n"
  echo -e "NAME: Name to locate the kind of export and also used as temporal table name."
  echo -e "JINJA_QUERY: Jinja query to get the data to export."
  echo -e "DATE_RANGE: The date range to be queried. The format will be YYYY-MM-DD,YYYY-MM-DD."
  echo -e "GCS_OUTPUT: The Google Cloud Storage destination path where will be stored the data."
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
# Save query in a temporal file.
#################################################################
echo "Inserting new records for table ${TRACKS_TABLE}"
echo "${JINJA_QUERY}" > ${ASSETS}/query.j2.sql

#################################################################
# Save query in a temporal file.
#################################################################
IFS=, read START_DATE END_DATE START_DATE_NODASH END_DATE_NODASH <<<"${DATE_RANGE}"
TEMPORAL_DATASET="0_ttl24h"
TEMPORAL_TABLE=${TEMPORAL_DATASET}.${NAME}

jinja2 ${ASSETS}/query.j2.sql \
   -D start_yyyymmdd_nodash=${START_DATE_NODASH} \
   -D end_yyyymmdd_nodash=${END_DATE_NODASH} \
   -D start_yyyymmdd=${START_DATE} \
   -D end_yyyymmdd=${END_DATE} \
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
bq extract -m ${TEMPORAL_TABLE} ${GCS_OUTPUT}
if [ "$?" -ne 0 ]; then
  echo "  Unable to extract data from temporal table ${TEMPORAL_TABLE} to ${GCS_OUTPUT}"
  exit 1
fi
echo "  Data in ${GCS_OUTPUT}"
