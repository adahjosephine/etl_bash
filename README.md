# Implementing an Extract-Transform-Load Process with Git and Bash

## Task description

This project implements an Extract-Transform-Load (ETL) pipeline for CoreDataEngineers using Bash.

The pipeline downloads a public CSV dataset, the NZ Stats Annual Enterprise Survey, cleans and reshapes the data, and saves the processed output to a designated folder.

The project also uses Git for version control and cron to schedule the pipeline to run automatically every 24 hours, at midnight.

The objective is to demonstrate how a simple data engineering workflow can be automated, made reproducible, and maintained using standard software engineering practices.

## Pipeline overview

The pipeline consists of three main stages:

1. **Extract:** Download the raw dataset from its public source.
2. **Transform:** Clean and reshape the downloaded data.
3. **Load:** Save the processed data to the output directory.

Git is used to track changes to the project, while cron automates the execution of the pipeline.

## Extract

The extraction stage downloads the NZ Stats Annual Enterprise Survey CSV dataset using `curl`.

The following principles were used in the design of the pipeline,
informed by the [12-factor app](https://12factor.net/) methodology
and general software engineering practices.[^1]

### 1. Reproducibility

The pipeline should produce the same outcome whenever it is run
with the same inputs and configuration, without requiring manual
intervention.

This is achieved by having the script download the dataset itself
using `curl`, rather than requiring the user to download the file
manually through a browser and place it in a folder.

### 2. Configuration over hardcoding

The pipeline should separate configuration from the script's logic
wherever practical. This makes the process easier to repeat and 
reduces the risk of missing or incorrectly placed input files.

For example, the dataset URL, input directory, and output directory
should be defined as variables rather than repeatedly written
directly into the commands.
```bash
DATA_URL="https://example.com/dataset.csv"
OUTPUT_DIR="./data/processed"
```
### 3. Fail loudly, not silently
The pipeline is designed to report errors clearly and stop when a critical operation fails, rather than continuing with incomplete or invalid data. 

This is important because a pipeline that appears to complete successfully may still produce incorrect results if an earlier stage has failed. For example, if the download fails, the transformation stage should not continue as though the data had been successfully extracted. This reduces the risk of silent failures and downstream data corruption.

The script uses `set -euo pipefail` to make Bash error handling stricter:

- `set -e` causes the script to exit when a command fails.
- `set -u` treats the use of an unset variable as an error.
- `set -o pipefail` ensures that a pipeline fails if any command within it fails.

### 4. Idempotency

The pipeline is designed so that running the same operation multiple times does not create duplicate output files or append the same records repeatedly to an existing output. This is important for automation because scheduled jobs may be rerun after a failure, or a user may execute the script manually more than once.
This is implemented using attributes `-p`(parent directories without failing if they already exist) and `-o` (allows for overwriting). 

### 5. Separation of code and data

The pipeline is designed such that the code used to process the data is separate from the data itself.
The GitHub repository should not store generated data files or sensitive information such as secret keys.

In this project:

- The Bash script is stored in the repository.
- The `.env` file is stored locally and is not committed to Git.
- The input and output folders are generated when the script runs.
- Generated data folders and sensitive files are excluded through `.gitignore`.

### 6. Verifiability

The pipeline is designed to verify that each stage has produced the expected result, rather than relying only on the absence of an error. This means checking that the correct file exists, has the expected name and file type, and is available for the next stage of the pipeline using an `if` statement.


[^1]: The 12-factor app methodology provides principles for building
reliable, maintainable, and portable software applications.

