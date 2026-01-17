---
title: "Lab: Environment Setup & The Micro-Lifecycle"
week: 01
type: lab
tags: [setup, duckdb, etl]
difficulty: introductory
duration: "45 mins"
---

# Lab: The Micro-Lifecycle Simulation

## 1. Prerequisites & Setup
*   **Goal:** Configure Google Colab and run a complete data lifecycle (Capture -> Archive) in one script.
*   **Tools:** Python, DuckDB.

### Environment Setup (Colab)
Run this block to install the necessary libraries. This is the standard block we will use for most Analytical labs.

```python
# Install DuckDB and JupySQL for SQL magic in Notebooks
!pip install duckdb duckdb-engine jupysql pandas

import duckdb
import pandas as pd

# Configure SqlMagic to use DuckDB
%load_ext sql
%config SqlMagic.autopandas = True
%config SqlMagic.feedback = False
%config SqlMagic.displaycon = False

# Connect to an in-memory DuckDB database
%sql duckdb:///:memory:
```

---

## 2. Stage 1: Capture (Ingest)
We will simulate "Capturing" data by reading a raw CSV file. This represents raw data arriving from an external source.

*We will use the `weather_raw.csv` file provided in the course data folder.*

```python
# Simulating 'Capture' - Reading raw text data
# (In a real scenario, this might be an API call or a log file)
url = "https://raw.githubusercontent.com/username/repo/main/week_01/data/weather_raw.csv" 
# NOTE: For local dev, use the relative path:
file_path = "week_01/data/weather_raw.csv"

# We use DuckDB to read the CSV directly into a relation
# This is fast and efficient
%sql SELECT * FROM read_csv_auto('week_01/data/weather_raw.csv');
```

**Observation:** Notice the `NULL` values and the potential errors in the data? That is normal for the "Capture" stage.

---

## 3. Stage 2: Store (Persist)
Now we "Store" this data into a structured table. In a full architecture, this would be PostgreSQL, but we will use a DuckDB table to simulate the structure.

```sql
%%sql
-- Create a table with defined types (Schema)
CREATE TABLE weather_staging (
    date DATE,
    city VARCHAR,
    temp_c DOUBLE,
    humidity INTEGER,
    status VARCHAR
);

-- Load the raw data into our table
INSERT INTO weather_staging 
SELECT * FROM read_csv_auto('week_01/data/weather_raw.csv');

-- Verify storage
SELECT count(*) as total_rows FROM weather_staging;
```

---

## 4. Stage 3 & 4: Process & Analyze
Now we clean the data (Process) and find insights (Analyze).
We want to remove errors and calculate the average temperature.

### The "Naive" Approach (Python Loop)
*Inefficient for millions of rows, but easy to read.*
```python
# Fetch data to Pandas
df = %sql SELECT * FROM weather_staging
df_clean = df[df['status'] == 'active'].copy()
print(f"Average Temp (Python): {df_clean['temp_c'].mean():.2f}")
```

### The "Better" Approach (SQL Pushdown)
*We let the database engine do the work. This is faster and scales.*

```sql
%%sql
-- Filter (Process) and Aggregate (Analyze) in one go
SELECT 
    city,
    AVG(temp_c) as avg_temp,
    MAX(humidity) as max_humid
FROM weather_staging
WHERE status = 'active'
GROUP BY city
ORDER BY avg_temp DESC;
```

---

## 5. Stage 5: Archive
Finally, we save our valuable insights to a format optimized for long-term storage and other data science tools: **Parquet**.

```sql
%%sql
-- Export the cleaned data to a Parquet file
COPY (
    SELECT * FROM weather_staging WHERE status = 'active'
) TO 'cleaned_weather.parquet' (FORMAT 'PARQUET');
```

**Verification:**
You should see a `cleaned_weather.parquet` file appear in your file browser. This file is smaller and faster to read than the original CSV.

---

## 6. Your Turn! (Exercises)

### Exercise 1: Ingest JSON
**Task:** DuckDB can also read JSON. Try to read the provided `weather_raw.json` file.
**Hint:** Look up `read_json_auto` in the DuckDB documentation.

```python
# TODO: Write a query to read the 'week_01/data/weather_raw.json' file
# %sql SELECT * FROM ...
```

### Exercise 2: Add a Filter
**Task:** Modify the Analytical Query in Stage 4 to only show cities with an average temperature > 5.0.

```sql
-- TODO: Write your SQL here
```

---

## 7. Summary
You just simulated the entire Data Engineering lifecycle in 10 minutes!
1.  **Captured** raw CSV.
2.  **Stored** it in a Table.
3.  **Processed** it by filtering 'active' status.
4.  **Analyzed** it with Aggregations.
5.  **Archived** the result to Parquet.
