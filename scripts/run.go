package main

import (
  "fmt"
  "os"
)

func displayMessage() {
  fmt.Println(
    "Available Commands\n",
    "  bq2gcs   Read query from BigQuery tables and save result to GCS.")
}

func informAndExit() {
    displayMessage()
    os.Exit(1)
}

func main() {
  //Read arguments
  args:=os.Args[1:]
  if len(args)<0 {
    informAndExit()
  }
  fmt.Println(args)
  switch args[:1][0] {
    case "bq2gcs":
      fmt.Println("Run bq2gcs",args[1:])
    default:
      informAndExit()
  }
}
