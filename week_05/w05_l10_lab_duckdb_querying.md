---
title: "Lab: Querying Local Files with DuckDB"
week: 05
type: lab
tags: [duckdb, csv, parquet, sql, analytics, python]
difficulty: intermediate
duration: "60 mins"
---

# Lab: Querying Local Files with DuckDB

## Prerequisites & Setup

**Before starting this lab, you should:**
- Review [w05_l10_concept_intro_duckdb.md](w05_l10_concept_intro_duckdb.md) for DuckDB concepts
- Understand SQL basics from Week 04 (SELECT, WHERE, ORDER BY)
- Be familiar with CSV and Parquet file formats

**What you'll accomplish:**
In this lab, you'll use DuckDB to query CSV and Parquet files directly with SQL — no database server, no table creation, no ETL. You'll generate a dataset, explore it with DuckDB, compare CSV vs. Parquet performance, and bridge DuckDB with Pandas.

**Goal:** Master DuckDB as your go-to analytical SQL engine for local data exploration.

---

## Environment Setup

Run this setup block first to install required packages.

```python
# Setup: Run this cell first (required for Colab)
!pip install -q duckdb pandas mermaid-py
```

```python
import duckdb
import pandas as pd
import time
import os

# Display settings
pd.set_option('display.max_columns', None)
pd.set_option('display.max_rows', 20)

print(f"DuckDB version: {duckdb.__version__}")
print("Setup complete!")
```

<details>
<summary>Expected Output</summary>

~~~text
DuckDB version: 1.x.x
Setup complete!
~~~

</details>

---

## Step 1: Generate a Dataset

We'll create a realistic university dataset with 100,000 records, save it as both CSV and Parquet, then query it with DuckDB.

```python
import random
random.seed(42)

NUM_STUDENTS = 100_000

# Generate data
departments = ['CS', 'Math', 'Physics', 'English', 'Biology', 'Chemistry']
years = [2020, 2021, 2022, 2023, 2024, 2025]

data = {
    'student_id': list(range(1, NUM_STUDENTS + 1)),
    'name': [f"Student_{i}" for i in range(1, NUM_STUDENTS + 1)],
    'department': [random.choice(departments) for _ in range(NUM_STUDENTS)],
    'gpa': [round(random.uniform(0.0, 4.0), 2) for _ in range(NUM_STUDENTS)],
    'credits_completed': [random.randint(0, 150) for _ in range(NUM_STUDENTS)],
    'enrollment_year': [random.choice(years) for _ in range(NUM_STUDENTS)],
    'is_active': [random.choice([True, True, True, False]) for _ in range(NUM_STUDENTS)],
}

df = pd.DataFrame(data)
print(f"Generated {len(df):,} records")
df.head()
```

<details>
<summary>Expected Output</summary>

~~~text
Generated 100,000 records
~~~

| | student_id | name | department | gpa | credits_completed | enrollment_year | is_active |
|---|---|---|---|---|---|---|---|
| 0 | 1 | Student_1 | Biology | 2.50 | 109 | 2021 | True |
| 1 | 2 | Student_2 | Math | 0.89 | 83 | 2023 | True |
| 2 | 3 | Student_3 | CS | 1.08 | 80 | 2020 | False |
| 3 | 4 | Student_4 | English | 3.45 | 42 | 2024 | True |
| 4 | 5 | Student_5 | Physics | 2.11 | 127 | 2022 | True |

</details>

### Save as CSV and Parquet

```python
# Save as CSV
df.to_csv('students.csv', index=False)

# Save as Parquet
df.to_parquet('students.parquet', index=False)

# Compare file sizes
csv_size = os.path.getsize('students.csv')
parquet_size = os.path.getsize('students.parquet')

print(f"CSV file size:     {csv_size / 1_000_000:.2f} MB")
print(f"Parquet file size: {parquet_size / 1_000_000:.2f} MB")
print(f"Compression ratio: {csv_size / parquet_size:.1f}×")
```

<details>
<summary>Expected Output</summary>

~~~text
CSV file size:     4.52 MB
Parquet file size: 1.23 MB
Compression ratio: 3.7×
~~~

(Parquet is significantly smaller due to columnar compression)

</details>

---

## Step 2: Query CSV Files with DuckDB

### Your First DuckDB Query

```python
# Query a CSV file directly — no CREATE TABLE needed!
result = duckdb.sql("SELECT * FROM 'students.csv' LIMIT 5")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌────────────┬───────────┬────────────┬──────┬───────────────────┬─────────────────┬───────────┐
│ student_id │   name    │ department │ gpa  │ credits_completed │ enrollment_year │ is_active │
│   int64    │  varchar  │  varchar   │ float│      int64        │      int64      │  boolean  │
├────────────┼───────────┼────────────┼──────┼───────────────────┼─────────────────┼───────────┤
│          1 │ Student_1 │ Biology    │ 2.50 │               109 │            2021 │ true      │
│          2 │ Student_2 │ Math       │ 0.89 │                83 │            2023 │ true      │
│          3 │ Student_3 │ CS         │ 1.08 │                80 │            2020 │ false     │
│          4 │ Student_4 │ English    │ 3.45 │                42 │            2024 │ true      │
│          5 │ Student_5 │ Physics    │ 2.11 │               127 │            2022 │ true      │
└────────────┴───────────┴────────────┴──────┴───────────────────┴─────────────────┴───────────┘
~~~

</details>

**Key Insight:** DuckDB automatically inferred column names from the CSV header and detected data types. No schema definition needed!

### Analytical Queries on CSV

```python
# Average GPA by department
result = duckdb.sql("""
    SELECT
        department,
        COUNT(*) AS student_count,
        ROUND(AVG(gpa), 2) AS avg_gpa,
        ROUND(MIN(gpa), 2) AS min_gpa,
        ROUND(MAX(gpa), 2) AS max_gpa
    FROM 'students.csv'
    GROUP BY department
    ORDER BY avg_gpa DESC
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌────────────┬───────────────┬─────────┬─────────┬─────────┐
│ department │ student_count │ avg_gpa │ min_gpa │ max_gpa │
│  varchar   │    int64      │ double  │ double  │ double  │
├────────────┼───────────────┼─────────┼─────────┼─────────┤
│ Chemistry  │         16668 │    2.01 │    0.00 │    4.00 │
│ Physics    │         16651 │    2.00 │    0.00 │    4.00 │
│ CS         │         16583 │    2.00 │    0.00 │    4.00 │
│ Biology    │         16745 │    2.00 │    0.00 │    4.00 │
│ Math       │         16778 │    1.99 │    0.00 │    4.00 │
│ English    │         16575 │    1.99 │    0.00 │    4.00 │
└────────────┴───────────────┴─────────┴─────────┴─────────┘
~~~

(Values approximate due to random generation)

</details>

### Filtering and Sorting

```python
# Find the top 10 students by GPA in the CS department
result = duckdb.sql("""
    SELECT student_id, name, gpa, credits_completed
    FROM 'students.csv'
    WHERE department = 'CS' AND is_active = true
    ORDER BY gpa DESC
    LIMIT 10
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌────────────┬────────────────┬──────┬───────────────────┐
│ student_id │     name       │ gpa  │ credits_completed │
│   int64    │   varchar      │float │      int64        │
├────────────┼────────────────┼──────┼───────────────────┤
│      xxxxx │ Student_xxxxx  │ 4.00 │               xxx │
│      ...   │ ...            │ 3.99 │               ... │
│      ...   │ ...            │ 3.99 │               ... │
└────────────┴────────────────┴──────┴───────────────────┘
~~~

(10 rows showing top CS students)

</details>

---

## Step 3: Query Parquet Files with DuckDB

### Parquet Queries

```python
# Exact same SQL — just change the file extension
result = duckdb.sql("""
    SELECT
        department,
        COUNT(*) AS student_count,
        ROUND(AVG(gpa), 2) AS avg_gpa
    FROM 'students.parquet'
    GROUP BY department
    ORDER BY avg_gpa DESC
""")
result.show()
```

<details>
<summary>Expected Output</summary>

Same results as the CSV query — DuckDB produces identical output regardless of the source format.

</details>

### Inspect Parquet Metadata

```python
# DuckDB can show you the Parquet file's schema
result = duckdb.sql("DESCRIBE SELECT * FROM 'students.parquet'")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌───────────────────┬─────────────┬──────┬─────┬─────────┬───────┐
│    column_name    │ column_type │ null │ key │ default │ extra │
├───────────────────┼─────────────┼──────┼─────┼─────────┼───────┤
│ student_id        │ BIGINT      │ YES  │     │         │       │
│ name              │ VARCHAR     │ YES  │     │         │       │
│ department        │ VARCHAR     │ YES  │     │         │       │
│ gpa               │ DOUBLE      │ YES  │     │         │       │
│ credits_completed │ BIGINT      │ YES  │     │         │       │
│ enrollment_year   │ BIGINT      │ YES  │     │         │       │
│ is_active         │ BOOLEAN     │ YES  │     │         │       │
└───────────────────┴─────────────┴──────┴─────┴─────────┴───────┘
~~~

</details>

### Parquet Column Pruning in Action

```python
# When querying only 1 column from Parquet, DuckDB reads ONLY that column
# Let's verify by profiling the query

result = duckdb.sql("""
    EXPLAIN ANALYZE
    SELECT AVG(gpa) FROM 'students.parquet'
""")
result.show()
```

---

## Step 4: Performance Comparison — CSV vs. Parquet

### Benchmark: Full Aggregation

```python
def benchmark(query, label, runs=5):
    """Run a query multiple times and return average time."""
    times = []
    for _ in range(runs):
        start = time.perf_counter()
        duckdb.sql(query).fetchall()
        times.append(time.perf_counter() - start)
    avg_time = sum(times) / len(times)
    print(f"  {label}: {avg_time*1000:.2f} ms (avg of {runs} runs)")
    return avg_time

print("Query: SELECT department, AVG(gpa) GROUP BY department")
csv_time_1 = benchmark(
    "SELECT department, AVG(gpa) FROM 'students.csv' GROUP BY department",
    "CSV"
)
parquet_time_1 = benchmark(
    "SELECT department, AVG(gpa) FROM 'students.parquet' GROUP BY department",
    "Parquet"
)
print(f"  Parquet speedup: {csv_time_1/parquet_time_1:.1f}×")
```

<details>
<summary>Expected Output</summary>

~~~text
Query: SELECT department, AVG(gpa) GROUP BY department
  CSV:     12.34 ms (avg of 5 runs)
  Parquet:  2.56 ms (avg of 5 runs)
  Parquet speedup: 4.8×
~~~

(Parquet is faster because it reads only the columns needed and uses compressed binary data)

</details>

### Benchmark: Filtered Query

```python
print("\nQuery: SELECT * WHERE department = 'CS' AND gpa > 3.5")
csv_time_2 = benchmark(
    "SELECT * FROM 'students.csv' WHERE department = 'CS' AND gpa > 3.5",
    "CSV"
)
parquet_time_2 = benchmark(
    "SELECT * FROM 'students.parquet' WHERE department = 'CS' AND gpa > 3.5",
    "Parquet"
)
print(f"  Parquet speedup: {csv_time_2/parquet_time_2:.1f}×")
```

<details>
<summary>Expected Output</summary>

~~~text
Query: SELECT * WHERE department = 'CS' AND gpa > 3.5
  CSV:     8.45 ms (avg of 5 runs)
  Parquet: 3.12 ms (avg of 5 runs)
  Parquet speedup: 2.7×
~~~

</details>

### Benchmark: Single Column Aggregation

```python
print("\nQuery: SELECT AVG(gpa) — single column")
csv_time_3 = benchmark(
    "SELECT AVG(gpa) FROM 'students.csv'",
    "CSV"
)
parquet_time_3 = benchmark(
    "SELECT AVG(gpa) FROM 'students.parquet'",
    "Parquet"
)
print(f"  Parquet speedup: {csv_time_3/parquet_time_3:.1f}×")
```

<details>
<summary>Expected Output</summary>

~~~text
Query: SELECT AVG(gpa) — single column
  CSV:     6.78 ms (avg of 5 runs)
  Parquet: 0.89 ms (avg of 5 runs)
  Parquet speedup: 7.6×
~~~

(Parquet shines most when reading few columns — it only reads the gpa column chunk)

</details>

### Summarize Results

```python
summary = pd.DataFrame({
    'Query': [
        'GROUP BY department',
        'Filtered SELECT *',
        'Single column AVG'
    ],
    'CSV (ms)': [round(csv_time_1*1000, 2), round(csv_time_2*1000, 2), round(csv_time_3*1000, 2)],
    'Parquet (ms)': [round(parquet_time_1*1000, 2), round(parquet_time_2*1000, 2), round(parquet_time_3*1000, 2)],
})
summary['Speedup'] = (summary['CSV (ms)'] / summary['Parquet (ms)']).round(1).astype(str) + '×'
print(summary.to_string(index=False))
```

---

## Step 5: DuckDB + Pandas Integration

### Query a Pandas DataFrame with SQL

```python
# 'df' is the Pandas DataFrame we created earlier
# DuckDB can query it directly by name!
result = duckdb.sql("""
    SELECT
        enrollment_year,
        COUNT(*) AS total_students,
        ROUND(AVG(gpa), 2) AS avg_gpa,
        SUM(CASE WHEN is_active THEN 1 ELSE 0 END) AS active_count
    FROM df
    GROUP BY enrollment_year
    ORDER BY enrollment_year
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌─────────────────┬────────────────┬─────────┬──────────────┐
│ enrollment_year │ total_students │ avg_gpa │ active_count │
│      int64      │     int64      │ double  │    int128    │
├─────────────────┼────────────────┼─────────┼──────────────┤
│            2020 │          16666 │    2.00 │        12510 │
│            2021 │          16616 │    2.00 │        12450 │
│            2022 │          16755 │    2.00 │        12575 │
│            2023 │          16667 │    2.01 │        12485 │
│            2024 │          16653 │    2.00 │        12495 │
│            2025 │          16643 │    2.00 │        12495 │
└─────────────────┴────────────────┴─────────┴──────────────┘
~~~

</details>

**Key Insight:** DuckDB can reference Python variables (DataFrames) directly in SQL queries. No import/export step needed.

### Convert DuckDB Results to Pandas

```python
# Convert DuckDB result to Pandas for plotting
result_df = duckdb.sql("""
    SELECT
        department,
        ROUND(AVG(gpa), 2) AS avg_gpa,
        COUNT(*) AS count
    FROM df
    WHERE is_active = true
    GROUP BY department
    ORDER BY avg_gpa DESC
""").df()  # .df() converts to Pandas DataFrame

print(type(result_df))
print(result_df)
```

<details>
<summary>Expected Output</summary>

~~~text
<class 'pandas.core.frame.DataFrame'>
  department  avg_gpa  count
0  Chemistry     2.01  12510
1    Physics     2.00  12475
2         CS     2.00  12430
3    Biology     2.00  12556
4       Math     1.99  12585
5    English     1.99  12440
~~~

</details>

### DuckDB vs. Pandas: Same Query, Different Syntax

```python
# --- Pandas approach ---
start = time.perf_counter()
pandas_result = (
    df[df['is_active'] == True]
    .groupby('department')
    .agg(
        student_count=('student_id', 'count'),
        avg_gpa=('gpa', 'mean'),
        avg_credits=('credits_completed', 'mean')
    )
    .round(2)
    .sort_values('avg_gpa', ascending=False)
)
pandas_time = time.perf_counter() - start

# --- DuckDB approach ---
start = time.perf_counter()
duckdb_result = duckdb.sql("""
    SELECT
        department,
        COUNT(*) AS student_count,
        ROUND(AVG(gpa), 2) AS avg_gpa,
        ROUND(AVG(credits_completed), 2) AS avg_credits
    FROM df
    WHERE is_active = true
    GROUP BY department
    ORDER BY avg_gpa DESC
""").df()
duckdb_time = time.perf_counter() - start

print(f"Pandas:  {pandas_time*1000:.2f} ms")
print(f"DuckDB:  {duckdb_time*1000:.2f} ms")
print(f"DuckDB speedup: {pandas_time/duckdb_time:.1f}×")
print("\nDuckDB result:")
print(duckdb_result)
```

<details>
<summary>Expected Output</summary>

~~~text
Pandas:  15.23 ms
DuckDB:   3.45 ms
DuckDB speedup: 4.4×

DuckDB result:
  department  student_count  avg_gpa  avg_credits
0  Chemistry          12510     2.01        75.12
1    Physics          12475     2.00        74.89
2         CS          12430     2.00        75.34
3    Biology          12556     2.00        74.95
4       Math          12585     1.99        75.21
5    English          12440     1.99        75.07
~~~

</details>

---

## Step 6: Multi-File Queries

DuckDB can query multiple files at once using glob patterns.

### Create Multiple Files

```python
# Split data by department and save as separate Parquet files
os.makedirs('data_by_dept', exist_ok=True)

for dept in df['department'].unique():
    dept_df = df[df['department'] == dept]
    dept_df.to_parquet(f'data_by_dept/{dept}.parquet', index=False)

# List files
for f in sorted(os.listdir('data_by_dept')):
    size = os.path.getsize(f'data_by_dept/{f}')
    print(f"  {f}: {size/1024:.1f} KB")
```

<details>
<summary>Expected Output</summary>

~~~text
  Biology.parquet: 210.5 KB
  CS.parquet: 208.3 KB
  Chemistry.parquet: 209.8 KB
  English.parquet: 208.1 KB
  Math.parquet: 210.9 KB
  Physics.parquet: 209.2 KB
~~~

</details>

### Query All Files with Glob

```python
# Query ALL department files at once
result = duckdb.sql("""
    SELECT
        department,
        COUNT(*) AS count,
        ROUND(AVG(gpa), 2) AS avg_gpa
    FROM 'data_by_dept/*.parquet'
    GROUP BY department
    ORDER BY count DESC
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌────────────┬───────┬─────────┐
│ department │ count │ avg_gpa │
│  varchar   │ int64 │ double  │
├────────────┼───────┼─────────┤
│ Math       │ 16778 │    1.99 │
│ Biology    │ 16745 │    2.00 │
│ Chemistry  │ 16668 │    2.01 │
│ Physics    │ 16651 │    2.00 │
│ CS         │ 16583 │    2.00 │
│ English    │ 16575 │    1.99 │
└────────────┴───────┴─────────┘
~~~

</details>

**Use Case:** In real data pipelines, data is often partitioned into separate files by date, region, or category. DuckDB's glob support lets you query all partitions with a single SQL statement.

---

## Step 7: Creating Persistent Tables

So far, we've queried files directly. You can also create persistent tables in a DuckDB database file.

```python
# Create a persistent database
conn = duckdb.connect('university.duckdb')

# Load CSV into a table
conn.sql("CREATE TABLE students AS SELECT * FROM 'students.csv'")

# Verify
conn.sql("SELECT COUNT(*) AS total FROM students").show()

# Query the persistent table
conn.sql("""
    SELECT department, ROUND(AVG(gpa), 2) AS avg_gpa
    FROM students
    GROUP BY department
    ORDER BY avg_gpa DESC
""").show()
```

```python
# Show all tables
conn.sql("SHOW TABLES").show()

# Describe a table
conn.sql("DESCRIBE students").show()
```

```python
# Clean up: close connection
conn.close()

# The database file persists on disk
print(f"Database file size: {os.path.getsize('university.duckdb') / 1_000_000:.2f} MB")
```

<details>
<summary>Expected Output</summary>

~~~text
Database file size: 1.45 MB
~~~

</details>

---

## Your Turn! (Exercises)

### Exercise 1: Enrollment Year Analysis

**Task:** Using DuckDB on `students.parquet`, write a query that shows for each enrollment year:
- Total number of students
- Number of active students
- Percentage of active students (rounded to 1 decimal)
- Average GPA of active students

```python
# TODO: Write your DuckDB SQL query here
# result = duckdb.sql("""...""")
# result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌─────────────────┬───────┬────────┬────────────┬─────────┐
│ enrollment_year │ total │ active │ pct_active │ avg_gpa │
├─────────────────┼───────┼────────┼────────────┼─────────┤
│            2020 │ 16666 │  12510 │       75.0 │    2.00 │
│            2021 │ 16616 │  12450 │       74.9 │    2.00 │
│            ...  │  ...  │   ...  │       ...  │    ...  │
└─────────────────┴───────┴────────┴────────────┴─────────┘
~~~

</details>

### Exercise 2: GPA Distribution

**Task:** Create GPA buckets and count students in each range. Use CASE to categorize:
- `'A (3.5-4.0)'`, `'B (3.0-3.5)'`, `'C (2.0-3.0)'`, `'D (1.0-2.0)'`, `'F (0.0-1.0)'`

```python
# TODO: Write a query using CASE WHEN to create GPA buckets
# and COUNT students in each bucket, ordered by bucket
```

<details>
<summary>Hint</summary>

Use `CASE WHEN gpa >= 3.5 THEN 'A (3.5-4.0)' WHEN gpa >= 3.0 THEN 'B (3.0-3.5)' ... END AS gpa_bucket`

</details>

<details>
<summary>Expected Output</summary>

~~~text
┌──────────────┬───────┬─────────┐
│  gpa_bucket  │ count │ pct     │
├──────────────┼───────┼─────────┤
│ A (3.5-4.0)  │ 12500 │   12.5% │
│ B (3.0-3.5)  │ 12500 │   12.5% │
│ C (2.0-3.0)  │ 25000 │   25.0% │
│ D (1.0-2.0)  │ 25000 │   25.0% │
│ F (0.0-1.0)  │ 25000 │   25.0% │
└──────────────┴───────┴─────────┘
~~~

(Approximate — uniform random distribution)

</details>

### Exercise 3: Export Filtered Data

**Task:** Export all active CS students with GPA > 3.0 to a new Parquet file called `cs_honors.parquet`. Then read it back and verify the count.

```python
# TODO: Use COPY ... TO ... (FORMAT PARQUET) to export
# Then read the file back with SELECT COUNT(*)
```

<details>
<summary>Solution</summary>

~~~python
# Export
duckdb.sql("""
    COPY (
        SELECT student_id, name, gpa, credits_completed
        FROM 'students.parquet'
        WHERE department = 'CS' AND is_active = true AND gpa > 3.0
    ) TO 'cs_honors.parquet' (FORMAT PARQUET)
""")

# Verify
result = duckdb.sql("SELECT COUNT(*) AS count FROM 'cs_honors.parquet'")
result.show()

# Check file size
print(f"File size: {os.path.getsize('cs_honors.parquet') / 1024:.1f} KB")
~~~

</details>

### Exercise 4: DuckDB vs. Pandas Challenge

**Task:** Write the same query in both Pandas and DuckDB, then compare execution time:
- "For each department, find the student with the highest GPA and return their name, GPA, and department"

```python
# TODO: Implement in Pandas using .groupby() + .idxmax() or similar
# TODO: Implement in DuckDB using a subquery or window function
# Compare execution times
```

<details>
<summary>Hint</summary>

DuckDB approach — use a subquery:
~~~sql
SELECT student_id, name, department, gpa
FROM 'students.parquet'
WHERE (department, gpa) IN (
    SELECT department, MAX(gpa)
    FROM 'students.parquet'
    GROUP BY department
)
~~~

</details>

### Exercise 5: Create a Summary Report

**Task:** Build a comprehensive summary report using DuckDB that shows:
1. Total students, active students, inactive students
2. Department with highest average GPA
3. Most popular enrollment year
4. Overall GPA statistics (mean, median, stddev)

```python
# TODO: Write multiple DuckDB queries to build a summary
# Hint: DuckDB supports MEDIAN() and STDDEV() aggregate functions
```

---

## Summary

In this lab, you have successfully:

1. Generated a 100,000-row dataset and saved it as CSV and Parquet
2. Queried CSV files directly with DuckDB SQL — no table creation needed
3. Queried Parquet files and observed column pruning benefits
4. Benchmarked CSV vs. Parquet performance (Parquet 3-8x faster)
5. Integrated DuckDB with Pandas — querying DataFrames with SQL
6. Used glob patterns to query multiple files at once
7. Created a persistent DuckDB database
8. Compared DuckDB and Pandas for the same analytical tasks

**Key Takeaways:**

- **DuckDB queries files directly** — `SELECT * FROM 'file.csv'` is all you need
- **Parquet is the preferred format for analytics** — compressed, columnar, schema-aware
- **DuckDB + Pandas** is a powerful combination — SQL for aggregations, Pandas for data manipulation
- **DuckDB uses PostgreSQL-compatible SQL** — your Week 04 knowledge transfers directly
- **No server needed** — DuckDB runs in-process, ideal for notebooks and local analysis