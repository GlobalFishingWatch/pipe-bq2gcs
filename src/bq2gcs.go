package main

import (
  "context"
  "encoding/json"
  "fmt"
  "log"
  "strings"

  "cloud.google.com/go/bigquery"
  "github.com/google/uuid"
)

type Bq2gcs struct{
  Name string
  JinjaQuery string
  GCSOutputFolder string
  DestinationFormat string
  TemporalDataset string
  Compression string
}

const ProjectId = "world-fishing-827"

var CompressionLookup = map[string]bigquery.Compression{
"NONE":    bigquery.None,
"GZIP":    bigquery.Gzip,
"DEFLATE": bigquery.Deflate,
"SNAPPY":  bigquery.Snappy,
}

func usageMessage() {
  fmt.Println("\nUsage:\nbq2gcs NAME JINJA_QUERY GCS_OUTPUT_FOLDER DESTINATION_FORMAT TEMPORAL_DATASET COMPRESSION\n")
  fmt.Println("NAME: Name to locate the kind of export and also used as temporal table name.")
  fmt.Println("JINJA_QUERY: Jinja query to get the data to export.")
  fmt.Println("GCS_OUTPUT_FOLDER: The Google Cloud Storage destination folder where will be stored the data.")
  fmt.Println("DESTINATION_FORMAT: Destination format of the file.")
  fmt.Println("TEMPORAL_DATASET: Temporal dataset used to store the results of the jinja query.")
  fmt.Println("COMPRESSION: Kind of compression applied to the output file.")
  fmt.Println()
}

func (bq2gcs *Bq2gcs) Run() {
  fmt.Println("This is the Run method")
  bq2gcs.Name = strings.ReplaceAll(bq2gcs.Name, "-", "_")

  bq2gcsJson, _ := json.Marshal(bq2gcs)
  fmt.Println(string(bq2gcsJson))
  fmt.Println("Run the Jinja query and save it in a temporal table.")
  uuidInstance := strings.ReplaceAll(uuid.New().String(), "-", "_")
  fmt.Printf("temporalTable=%v.%s\n", bq2gcs.TemporalDataset, uuidInstance)

  fmt.Println("=== Evaluation of the jinja ===")
  fmt.Println(bq2gcs.JinjaQuery)
  fmt.Println("=== Evaluation of the jinja ===")

  err := makeQuery(bq2gcs.JinjaQuery, bq2gcs.TemporalDataset, uuidInstance)
  if err != nil {
    fmt.Println("Unable to run the query and store the data in the temporal table. %v", err)
  }

  var filename string
  if bq2gcs.DestinationFormat == "JSON" {
    filename, err = exportTableAsJSON(bq2gcs, uuidInstance)
  } else {
    filename, err = exportTableAsCSV(bq2gcs, uuidInstance)
  }
  if err != nil {
    log.Fatalf("Error get while extracting the data %v", err)
  }
  fmt.Printf("The data was extracted successfully in %v\n", filename)
}

func makeQuery(sql, dstDataset, dstTableID string) error {
  // Initializing the BigQuery Client
  ctx := context.Background()

  client, err := bigquery.NewClient(ctx, ProjectId)
  if err != nil {
    log.Fatalf("bigquery.NewClient: %v", err)
  }
  defer client.Close()

  // Running the query
  q := client.Query(sql)
  q.QueryConfig.Dst = client.Dataset(dstDataset).Table(dstTableID)

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

func exportTableAsCSV(bq2gcs *Bq2gcs, srcTable string) (string, error) {
  ctx := context.Background()
  client, err := bigquery.NewClient(ctx, ProjectId)
  if err != nil {
    return "",fmt.Errorf("bigquery.NewClient: %v", err)
  }
  defer client.Close()

  name := bq2gcs.GCSOutputFolder + "/" + bq2gcs.Name + ".csv"
  if bq2gcs.Compression != "NONE" {
    name+="."+strings.ToLower(bq2gcs.Compression)
  }
  gcsRef := bigquery.NewGCSReference(name)
  gcsRef.FieldDelimiter = ","
  gcsRef.Compression = CompressionLookup[bq2gcs.Compression]

  extractor := client.DatasetInProject(ProjectId, bq2gcs.TemporalDataset).Table(srcTable).ExtractorTo(gcsRef)
  extractor.DisableHeader = false

  extractor.Location = "US"

  job, err := extractor.Run(ctx)
  if err != nil {
    return "",err
  }
  status, err := job.Wait(ctx)
  if err != nil {
    return "",err
  }
  if err := status.Err(); err != nil {
    return "",err
  }
  return name, nil
}

func exportTableAsJSON(bq2gcs *Bq2gcs, srcTable string) (string, error) {
  ctx := context.Background()
  client, err := bigquery.NewClient(ctx, ProjectId)
  if err != nil {
    return "",fmt.Errorf("bigquery.NewClient: %v", err)
  }
  defer client.Close()

  name := bq2gcs.GCSOutputFolder + "/" + bq2gcs.Name + ".json"
  if bq2gcs.Compression != "NONE" {
    name+="."+strings.ToLower(bq2gcs.Compression)
  }
  gcsRef := bigquery.NewGCSReference(name)
  gcsRef.DestinationFormat = bigquery.JSON
  gcsRef.Compression = CompressionLookup[bq2gcs.Compression]

  extractor := client.DatasetInProject(ProjectId, bq2gcs.TemporalDataset).Table(srcTable).ExtractorTo(gcsRef)
  extractor.DisableHeader = false

  extractor.Location = "US"

  job, err := extractor.Run(ctx)
  if err != nil {
    return "",err
  }
  status, err := job.Wait(ctx)
  if err != nil {
    return "",err
  }
  if err := status.Err(); err != nil {
    return "",err
  }
  return name, nil
}
