package main

import (
  "context"
  "fmt"
  "log"

  "cloud.google.com/go/bigquery"
)

type Bq2gcs struct{
  Name string
  JinjaQuery string
  GCSOutputFolder string
  DestinationFormat string
}

const ProjectId = "world-fishing-827"
const TemporalDataset = "0_ttl24h"

func usageMessage() {
  fmt.Println("\nUsage:\nbq2gcs NAME JINJA_QUERY GCS_OUTPUT_FOLDER DESTINATION_FORMAT\n")
  fmt.Println("NAME: Name to locate the kind of export and also used as temporal table name.")
  fmt.Println("JINJA_QUERY: Jinja query to get the data to export.")
  fmt.Println("GCS_OUTPUT_FOLDER: The Google Cloud Storage destination folder where will be stored the data.")
  fmt.Println("DESTINATION_FORMAT: Destination format of the file.")
  fmt.Println()
}

func (bq2gcs Bq2gcs) String() string {
  return fmt.Sprintf("%v", bq2gcs)
}

func (bq2gcs *Bq2gcs) Run() {
  fmt.Println("This is the Run method")

  fmt.Println("Run the Jinja query and save it in a temporal table.")
  fmt.Printf("temporalTable=%v.%s\n", TemporalDataset, bq2gcs.Name)

  fmt.Println("=== Evaluation of the jinja ===")
  fmt.Println(bq2gcs.JinjaQuery)
  fmt.Println("=== Evaluation of the jinja ===")

  err := makeQuery(bq2gcs.JinjaQuery, bq2gcs.Name)
  if err != nil {
    fmt.Println("Unable to run the query and store the data in the temporal table. %v", err)
  }

  return
  if bq2gcs.DestinationFormat == "JSON" {
    exportTableAsJSON(TemporalDataset, bq2gcs.Name, bq2gcs.GCSOutputFolder)
  } else {
    exportTableAsCSV(TemporalDataset, bq2gcs.Name, bq2gcs.GCSOutputFolder)
  }
}

func makeQuery(sql, dstTableID string) error {
  // Initializing the BigQuery Client
  ctx := context.Background()

  client, err := bigquery.NewClient(ctx, ProjectId)
  if err != nil {
    log.Fatalf("bigquery.NewClient: %v", err)
  }
  defer client.Close()

  return nil
  // Running the query
  q := client.Query(sql)
  q.QueryConfig.Dst = client.Dataset(TemporalDataset).Table(dstTableID)

  // Start the job.
  job, err := q.Run(ctx)
  if err != nil {
    return err
  }

  _, err = job.Wait(ctx)
  if err != nil {
    return err
  }

  return nil
}

func exportTableAsCSV(srcDataset, srcTable, gcsURI string) error {
  ctx := context.Background()
  client, err := bigquery.NewClient(ctx, ProjectId)
  if err != nil {
    return fmt.Errorf("bigquery.NewClient: %v", err)
  }
  defer client.Close()

  gcsRef := bigquery.NewGCSReference(gcsURI + srcTable + ".csv")
  gcsRef.FieldDelimiter = ","

  extractor := client.DatasetInProject(ProjectId, srcDataset).Table(srcTable).ExtractorTo(gcsRef)
  extractor.DisableHeader = true

  extractor.Location = "US"

  job, err := extractor.Run(ctx)
  if err != nil {
    return err
  }
  status, err := job.Wait(ctx)
  if err != nil {
    return err
  }
  if err := status.Err(); err != nil {
    return err
  }
  return nil
}

func exportTableAsJSON(srcDataset, srcTable, gcsURI string) error {
  ctx := context.Background()
  client, err := bigquery.NewClient(ctx, ProjectId)
  if err != nil {
    return fmt.Errorf("bigquery.NewClient: %v", err)
  }
  defer client.Close()

  gcsRef := bigquery.NewGCSReference(gcsURI + srcTable + ".json")
  gcsRef.DestinationFormat = "JSON"

  extractor := client.DatasetInProject(ProjectId, srcDataset).Table(srcTable).ExtractorTo(gcsRef)
  extractor.DisableHeader = true

  extractor.Location = "US"

  job, err := extractor.Run(ctx)
  if err != nil {
    return err
  }
  status, err := job.Wait(ctx)
  if err != nil {
    return err
  }
  if err := status.Err(); err != nil {
    return err
  }
  return nil
}
