# pipe-bq2gcs
Easy way to read from GlobalFishingWatch Biquery tables and share them through gcs.

# Requirements

## Setup

Use an external named volume so that we can share gcp auth across containers
Before first use, this volume must be manually created with
  `docker volume create --name=gcp`


