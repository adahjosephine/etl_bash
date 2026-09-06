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

## Design Decision: Extract compared with Transform Scope

The Extract stage is built to support **one or more** source URLs 
(via space-separated `CSV_URLS` in `.env`), looping through each and 
saving it independently to `raw/`. This reflects Extract's general 
purpose: pulling in whatever raw source data is needed, however many 
files that may be.

The Transform stage, by contrast, is intentionally scoped to **one specific file** — the Annual Enterprise Survey dataset — because the 
assignment specifies a single named output file 
(`Transformed/2023_year_finance.csv`) with a fixed transformation 
(rename `Variable_code`, select four specific columns). Rather than 
building speculative generality Transform doesn't currently need, 
this stage targets exactly the dataset it's meant to process.

**This is a deliberate scope decision, not an oversight**: if this 
pipeline needs to transform multiple distinct datasets in the future, 
Transform would be extended at that point — for now, it stays simple 
and directly matches the actual requirement.

### Future Extension: Multi-File Transform (not implemented)

If Transform needed to process every file downloaded by Extract 
(rather than one named dataset), the hardcoded `RAW_INPUT_FILE` could 
be replaced with a loop over everything in `raw/`, mirroring Extract's 
own loop structure:

\`\`\`bash
for RAW_FILE in raw/*.csv; do
    DATASET_NAME=$(basename "$RAW_FILE" .csv)
    TRANSFORMED_FILE="Transformed/${DATASET_NAME}_transformed.csv"

    awk '
        BEGIN { FPAT = "([^,]*)|(\"[^\"]*\")" }
        NR == 1 {
            for (i = 1; i <= NF; i++) {
                if ($i == "Year")          col_year = i
                if ($i == "Value")         col_value = i
                if ($i == "Units")         col_units = i
                if ($i == "Variable_code") col_varcode = i
            }
            print "year,Value,Units,variable_code"
            next
        }
        { print $col_year "," $col_value "," $col_units "," $col_varcode }
    ' "$RAW_FILE" > "$TRANSFORMED_FILE"
done
\`\`\`

This was not implemented because the assignment specifies a single, 
fixed output filename (\`2023_year_finance.csv\`), and every raw file 
may not share the same column names — this loop assumes identical 
structure across all source files, which isn't guaranteed and would 
need additional validation before being production-ready.

## Scheduling (Cron)

The ETL pipeline (`etl.sh`) is scheduled to run automatically every day 
at 12:00 AM (midnight) using `cron`, Linux's built-in time-based job 
scheduler. Other schedulers like Apache airflow exists

### The cron entry

Cron requires the **absolute path** to the script it should run, rather than a relative path such as `./etl.sh`. This is because cron runs the script independently of an interactive terminal session, so the script should not rely on the directory from which it was manually executed.

The script's output and error messages are **appended** to a log file using `>>`, rather than overwritten using `>`. Since the pipeline runs automatically every night, appending preserves a history of previous runs in `etl.log`, allowing past results to be reviewed rather than erased each time the job runs.

For example:

\`\`\`
0 0 * * * /home/josephine_adah/dataEngineeringETL/etl.sh >> /home/josephine_adah/dataEngineeringETL/etl.log 2>&1
\`\`\`

This cron entry runs the script at **midnight every day**.

- `0 0 * * *` — Run at 00:00 every day.
- `/home/jadah/coredataengineers/etl.sh` — The absolute path to the Bash script.
- `>>` — Append the script's standard output to the log file.
- `/home/jadah/coredataengineers/etl.log` — The log file where output is stored.
- `2>&1` — Redirect standard error to the same destination as standard output, so errors are also appended to the log.

### How the schedule works

Cron schedules are defined using five time fields, in this order:

\`\`\`
minute  hour  day-of-month  month  day-of-week   command
\`\`\`

Each field can hold a specific number, or \`*\` (meaning "every" — 
i.e. no restriction on that field). For "every day at 12:00 AM":

| Field | Value | Meaning |
|---|---|---|
| minute | \`0\` | at the top of the hour |
| hour | \`0\` | midnight (24-hour clock) |
| day-of-month | \`*\` | every day of the month |
| month | \`*\` | every month |
| day-of-week | \`*\` | every day of the week |


### Why the crontab itself is not committed to this repository

Unlike \`etl.sh\`, the crontab is not a file that lives inside this 
project's folder — it's a separate, per-user system configuration 
file managed entirely through the \`crontab\` command (\`crontab -e\` to 
edit, \`crontab -l\` to view), stored by cron in a system-managed 
location outside any Git-tracked directory. It cannot be meaningfully 
version-controlled the way a project file can, since it's tied to a 
specific user account on a specific machine, not to this codebase.

Instead, this section of the README documents the exact schedule and 
command used, so the cron setup can be reproduced identically on any 
machine by running \`crontab -e\` and adding the line shown above.


[^1]: The 12-factor app methodology provides principles for building
reliable, maintainable, and portable software applications.

