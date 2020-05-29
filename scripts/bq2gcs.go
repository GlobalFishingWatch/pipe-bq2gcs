package main

import (
  "fmt"
)

type Bq2gcs struct{
  Name string,
  JinjaQuery string,
  DateRange string,
  GCSOutputFolder string,
  DestinationFormat string
}


func displayMessage(){
  fmt.Println("\nUsage:\nbq2gcs NAME JINJA_QUERY DATE_RANGE GCS_OUTPUT_FOLDER\n")
  fmt.Println("NAME: Name to locate the kind of export and also used as temporal table name.")
  fmt.Println("JINJA_QUERY: Jinja query to get the data to export.")
  fmt.Println("DATE_RANGE: The date range to be queried. The format will be YYYY-MM-DD,YYYY-MM-DD.")
  fmt.Println("GCS_OUTPUT_FOLDER: The Google Cloud Storage destination folder where will be stored the data.")
  fmt.Println("DESTINATION_FORMAT: Destination format of the file.")
  fmt.Println()
}


