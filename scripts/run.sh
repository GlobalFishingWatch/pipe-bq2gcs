#!/usr/bin/env bash

THIS_SCRIPT_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )"

display_usage() {
  echo "Available Commands"
  echo "  bq2gcs  Read from Bigquery tables and save data to gcs."
}


if [[ $# -le 0 ]]
then
    display_usage
    exit 1
fi


case $1 in

  bq2gcs)
    ${THIS_SCRIPT_DIR}/bq2gcs.sh "${@:2}"
    ;;

  *)
    display_usage
    exit 1
    ;;
esac
