# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a
Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## v0.0.2 - 2020-06-28

### Added

* [gfw-eng-tasks#122](https://github.com/GlobalFishingWatch/gfw-eng-tasks/issues/122): Adds
    * Forces metadata for gz files in GCS, set Content-Type:
    * application/octet-stream and Content-Encoding: gzip

### Changed

* [gfw-eng-tasks#104](https://github.com/GlobalFishingWatch/gfw-eng-tasks/issues/104): Changes
    * Run task with go code instead of bash.
    * Uses respective compression file extension.
    * Increments `pipe-tools:v3.1.2` and Google SDK `297.0.1`.

## v0.0.1 - 2020-05-21

### Added

* [gfw-eng-tasks#87](https://github.com/GlobalFishingWatch/gfw-eng-tasks/issues/87): Adds
    * Initial implementation made in bash and go code.
    * Configures Dockerfile for bash and for go code.
    * Define a export_configis to specified the paramaters to share.
