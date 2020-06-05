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
  if len(os.Args)<2 {
    informAndExit()
  }

  args:=os.Args[1:]
  switch args[:1][0] {
    case "bq2gcs":
      //Validation
      bq2gcsArgs:=args[1:]
      if len(bq2gcsArgs) != 6 {
        usageMessage()
        os.Exit(1)
      }
      bq2gcs := Bq2gcs{
        bq2gcsArgs[0],
        bq2gcsArgs[1],
        bq2gcsArgs[2],
        bq2gcsArgs[3],
        bq2gcsArgs[4],
        bq2gcsArgs[5]}
      bq2gcs.Run()
    default:
      informAndExit()
  }
}
