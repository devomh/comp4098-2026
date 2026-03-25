---
title: "Lab: Generating & Loading Large Datasets"
week: 08
type: lab
tags: [performance, data-generation, bulk-loading, csv, parquet, postgresql, duckdb, numpy, python]
difficulty: intermediate
duration: "60 mins"
---

# Lab: Generating & Loading Large Datasets

## Prerequisites & Setup

**Before starting this lab, you should:**
- Review [w08_l15_concept_data_at_scale.md](w08_l15_concept_data_at_scale.md) for data generation and loading concepts
- Be familiar with NumPy basics (arrays, random generation)
- Understand the difference between CSV and Parquet formats

**What you'll accomplish:**
In this lab, you'll generate a 5-million-row sales dataset using NumPy, save it in both CSV and Parquet formats, load it into PostgreSQL (via COPY) and DuckDB (via Parquet), and verify data integrity across both engines.

**Goal:** Build the dataset infrastructure for the Lesson 16 performance benchmark.

---

## Environment Setup

Each Google Colab session starts with a clean VM. Run all setup cells before anything else.

```python
# 1. Install Python packages
!pip install -q duckdb pandas numpy psycopg2-binary jupysql mermaid-py
```

```python
# 2. Install and start PostgreSQL
!sudo apt-get -y -qq update > /dev/null
!sudo apt-get -y -qq install postgresql postgresql-contrib > /dev/null
!service postgresql start
```

```python
# 3. Create the database and set credentials
!sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'postgres';"
!sudo -u postgres psql -c "CREATE DATABASE benchmark_db;"
```

```python
# 4. Import libraries and connect SQL Magic to PostgreSQL
import numpy as np
import pandas as pd
import duckdb
import time
import os
import warnings
warnings.filterwarnings('ignore')

%load_ext sql
%config SqlMagic.autocommit = True
%config SqlMagic.feedback = True
%config SqlMagic.displaycon = False
%sql postgresql://postgres:postgres@localhost:5432/benchmark_db

print("Setup complete!")
```

<details>
<summary>Expected Output</summary>

~~~text
Setup complete!
~~~

</details>

---

## Step 1: Generate the Dataset with NumPy

We'll create a flat `sales_transactions` table — a single wide table with millions of rows. This design is intentional: a flat table isolates the impact of the storage engine architecture without adding JOIN complexity.

```python
# ── Dataset Size Configuration ──────────────────────
# Uncomment one block to select your scale.

# --- Quick test (verify queries work) ---
# N_ROWS = 100_000

# --- Performance benchmark (default) ---
N_ROWS = 5_000_000

# --- Full benchmark (syllabus target) ---
# N_ROWS = 10_000_000
```

### Why NumPy?

Python loops create one value at a time. NumPy creates entire columns at once using optimized C code. For 5M rows, this is the difference between **2 minutes** and **3 seconds**.

```python
np.random.seed(42)

# ── Column definitions ──────────────────────────────
CATEGORIES      = ['Electronics', 'Clothing', 'Books', 'Home & Kitchen', 'Sports', 'Toys']
REGIONS         = ['Northeast', 'Southeast', 'Midwest', 'West', 'Southwest']
PAYMENT_METHODS = ['Credit Card', 'Debit Card', 'Cash', 'Digital Wallet']

print(f"Generating {N_ROWS:,} rows...")
start = time.perf_counter()

# Vectorized generation — all columns at once
transaction_id   = np.arange(1, N_ROWS + 1)
customer_id      = np.random.randint(1, 100_001, N_ROWS)
product_id       = np.random.randint(1, 5_001, N_ROWS)
category         = np.random.choice(CATEGORIES, N_ROWS)
quantity         = np.random.randint(1, 11, N_ROWS)
unit_price       = np.round(np.random.uniform(5.0, 500.0, N_ROWS), 2)
total_amount     = np.round(quantity * unit_price, 2)
region           = np.random.choice(REGIONS, N_ROWS)
store_id         = np.random.randint(1, 51, N_ROWS)
payment_method   = np.random.choice(PAYMENT_METHODS, N_ROWS)

# Generate dates spanning 3 years (2022-01-01 to 2024-12-30)
base_date    = np.datetime64('2022-01-01')
days_offset  = np.random.randint(0, 1095, N_ROWS)   # 3 years = 1,095 days
transaction_date = base_date + days_offset.astype('timedelta64[D]')

gen_time = time.perf_counter() - start
print(f"Generated {N_ROWS:,} rows in {gen_time:.2f} seconds")
```

<details>
<summary>Expected Output</summary>

~~~text
Generating 5,000,000 rows...
Generated 5,000,000 rows in 2.XX seconds
~~~

NumPy generates 5M rows in ~2–3 seconds. A Python loop would take ~2 minutes for the same data.

</details>

```python
# Create the DataFrame
df = pd.DataFrame({
    'transaction_id':   transaction_id,
    'transaction_date': transaction_date,
    'customer_id':      customer_id,
    'product_id':       product_id,
    'category':         category,
    'quantity':         quantity,
    'unit_price':       unit_price,
    'total_amount':     total_amount,
    'region':           region,
    'store_id':         store_id,
    'payment_method':   payment_method,
})

print(f"DataFrame shape: {df.shape}")
print(f"Memory usage:    {df.memory_usage(deep=True).sum() / 1e6:.1f} MB")
print(f"\nColumn types:")
print(df.dtypes)
print(f"\nFirst 5 rows:")
df.head()
```

<details>
<summary>Expected Output</summary>

~~~text
DataFrame shape: (5000000, 11)
Memory usage:    ~650.0 MB

Column types:
transaction_id             int64
transaction_date    datetime64[ns]
customer_id                int64
product_id                 int64
category                  object
quantity                   int64
unit_price               float64
total_amount             float64
region                    object
store_id                   int64
payment_method            object
dtype: object
~~~

</details>

---

## Step 2: Save as CSV and Parquet

Now we'll save the data in both formats and compare file sizes.

```python
os.makedirs('benchmark_data', exist_ok=True)

# ── Save as CSV ──────────────────────────────────────
start = time.perf_counter()
csv_path = 'benchmark_data/sales_transactions.csv'
df.to_csv(csv_path, index=False)
csv_time = time.perf_counter() - start
csv_size = os.path.getsize(csv_path) / 1e6

# ── Save as Parquet ──────────────────────────────────
start = time.perf_counter()
parquet_path = 'benchmark_data/sales_transactions.parquet'
df.to_parquet(parquet_path, index=False, engine='pyarrow')
parquet_time = time.perf_counter() - start
parquet_size = os.path.getsize(parquet_path) / 1e6

print(f"{'Format':<10} {'Size (MB)':>12} {'Write Time (s)':>16}")
print(f"{'-'*40}")
print(f"{'CSV':<10} {csv_size:>12.1f} {csv_time:>16.2f}")
print(f"{'Parquet':<10} {parquet_size:>12.1f} {parquet_time:>16.2f}")
print(f"\nParquet is {csv_size / parquet_size:.1f}x smaller than CSV")
```

<details>
<summary>Expected Output</summary>

~~~text
Format       Size (MB)   Write Time (s)
----------------------------------------
CSV               480.0            25.00
Parquet             85.0             5.00

Parquet is 5.6x smaller than CSV
~~~

Exact numbers vary by Colab instance. Parquet should be 4–6x smaller than CSV.

</details>

**Why is Parquet so much smaller?**
- **Dictionary encoding:** Strings like "Electronics" (repeated ~833K times) are stored once, then referenced by a compact integer ID
- **Compression:** Snappy compression is applied per-column — similar values in the same column compress well
- **Binary format:** Numbers are stored as binary (8 bytes for a float64) instead of variable-length text

### Compression Algorithm Comparison

Parquet's default compression is Snappy, but other algorithms trade file size for CPU time. Let's measure the difference.

```python
# ── Parquet Compression Comparison ────────────────────
print(f"\n{'Compression':<14} {'Size (MB)':>10} {'Write Time (s)':>16}")
print(f"{'-' * 42}")

for comp in [None, 'snappy', 'zstd']:
    start = time.perf_counter()
    path = f'benchmark_data/sales_{comp}.parquet'
    df.to_parquet(path, index=False, compression=comp)
    write_time = time.perf_counter() - start
    size_mb = os.path.getsize(path) / 1e6
    label = str(comp) if comp else 'None'
    print(f"{label:<14} {size_mb:>10.1f} {write_time:>16.2f}")
```

<details>
<summary>Expected Output</summary>

~~~text
Compression     Size (MB)   Write Time (s)
------------------------------------------
None                200.0             2.50
snappy               85.0             5.00
zstd                 50.0             7.00
~~~

Exact numbers vary by Colab instance. The pattern is consistent: no compression is fastest to write but largest; ZSTD is smallest but slowest to write; Snappy sits in the middle.

</details>

Snappy is the default for good reason — it compresses well with minimal CPU cost. ZSTD is better when file size matters more than write speed (e.g., shipping data over a network).

```python
# Clean up — keep only the default Parquet file for the rest of the lab
for comp in [None, 'snappy', 'zstd']:
    path = f'benchmark_data/sales_{comp}.parquet'
    if os.path.exists(path):
        os.remove(path)
```

---

## Step 3: Load into PostgreSQL

### Create the Table

```python
%%sql
DROP TABLE IF EXISTS sales_transactions;

CREATE TABLE sales_transactions (
    transaction_id   INTEGER PRIMARY KEY,
    transaction_date DATE NOT NULL,
    customer_id      INTEGER NOT NULL,
    product_id       INTEGER NOT NULL,
    category         VARCHAR(20) NOT NULL,
    quantity         INTEGER NOT NULL,
    unit_price       NUMERIC(10, 2) NOT NULL,
    total_amount     NUMERIC(12, 2) NOT NULL,
    region           VARCHAR(20) NOT NULL,
    store_id         INTEGER NOT NULL,
    payment_method   VARCHAR(20) NOT NULL
);
```

### Load with COPY

PostgreSQL's `COPY` command reads the CSV file directly — bypassing the SQL parser for maximum speed. We use `\COPY` via `psql` which reads from the client filesystem (no superuser file access needed).

```python
# Load via \COPY (fastest method for PostgreSQL)
start = time.perf_counter()

!sudo -u postgres psql -d benchmark_db \
  -c "\COPY sales_transactions FROM '/content/benchmark_data/sales_transactions.csv' WITH (FORMAT csv, HEADER true)"

pg_load_time = time.perf_counter() - start
print(f"\nPostgreSQL COPY: {pg_load_time:.1f} seconds")
```

<details>
<summary>Expected Output</summary>

~~~text
COPY 5000000

PostgreSQL COPY: 40-80 seconds
~~~

Loading time varies by Colab instance. 40–80 seconds is typical for 5M rows.

</details>

### Verify the Load

```python
%%sql
SELECT COUNT(*) AS row_count FROM sales_transactions;
```

<details>
<summary>Expected Output</summary>

| row_count |
|-----------|
| 5000000 |

</details>

```python
%%sql
SELECT
    MIN(transaction_date) AS earliest,
    MAX(transaction_date) AS latest,
    COUNT(DISTINCT category) AS n_categories,
    COUNT(DISTINCT region) AS n_regions
FROM sales_transactions;
```

<details>
<summary>Expected Output</summary>

| earliest | latest | n_categories | n_regions |
|----------|--------|--------------|-----------|
| 2022-01-01 | 2024-12-30 | 6 | 5 |

</details>

---

## Step 4: Index Overhead Experiment

In Step 3, PostgreSQL's COPY loaded 5M rows into a table with a PRIMARY KEY — meaning the B-tree index was updated for every row. How much overhead does that index maintenance add? Let's find out by loading the same data into a table *without* a primary key, then adding the key afterward.

```python
%%sql
-- Create an identical table but WITHOUT the primary key constraint
DROP TABLE IF EXISTS sales_no_index;

CREATE TABLE sales_no_index (
    transaction_id   INTEGER,
    transaction_date DATE NOT NULL,
    customer_id      INTEGER NOT NULL,
    product_id       INTEGER NOT NULL,
    category         VARCHAR(20) NOT NULL,
    quantity         INTEGER NOT NULL,
    unit_price       NUMERIC(10, 2) NOT NULL,
    total_amount     NUMERIC(12, 2) NOT NULL,
    region           VARCHAR(20) NOT NULL,
    store_id         INTEGER NOT NULL,
    payment_method   VARCHAR(20) NOT NULL
);
```

```python
# COPY without any index overhead
start = time.perf_counter()

!sudo -u postgres psql -d benchmark_db \
  -c "\COPY sales_no_index FROM '/content/benchmark_data/sales_transactions.csv' WITH (FORMAT csv, HEADER true)"

pg_copy_no_index = time.perf_counter() - start
print(f"\nCOPY without index: {pg_copy_no_index:.1f} seconds")

# Now add the primary key (single-pass B-tree build)
start = time.perf_counter()

!sudo -u postgres psql -d benchmark_db \
  -c "ALTER TABLE sales_no_index ADD PRIMARY KEY (transaction_id);"

pg_pk_create = time.perf_counter() - start
print(f"PK creation after:  {pg_pk_create:.1f} seconds")
```

<details>
<summary>Expected Output</summary>

~~~text
COPY 5000000

COPY without index: 35-50 seconds
PK creation after:  10-15 seconds
~~~

</details>

```python
# ── Index Overhead Comparison ─────────────────────────
no_index_total = pg_copy_no_index + pg_pk_create

print(f"\nIndex Overhead Comparison ({N_ROWS:,} rows)")
print(f"{'─' * 46}")
print(f"  {'COPY with PK active:':<30} {pg_load_time:>8.1f} s")
print(f"  {'COPY without index:':<30} {pg_copy_no_index:>8.1f} s")
print(f"  {'+ PK creation after:':<30} {pg_pk_create:>8.1f} s")
print(f"  {'Total (no-index path):':<30} {no_index_total:>8.1f} s")
print(f"{'─' * 46}")
diff = pg_load_time - no_index_total
print(f"  {'Difference:':<30} {diff:>8.1f} s")
```

<details>
<summary>Expected Output</summary>

~~~text
Index Overhead Comparison (5,000,000 rows)
──────────────────────────────────────────────
  COPY with PK active:              65.0 s
  COPY without index:               42.0 s
  + PK creation after:              12.0 s
  Total (no-index path):            54.0 s
──────────────────────────────────────────────
  Difference:                       11.0 s
~~~

The no-index path is faster because PostgreSQL builds the B-tree in a single sorted pass after the data is loaded, rather than doing incremental index maintenance for each of the 5M rows.

</details>

```python
%%sql
-- Clean up — we only need the original sales_transactions table going forward
DROP TABLE IF EXISTS sales_no_index;
```

**Want to see a bigger difference?** Try adding 3 secondary indexes to `sales_transactions` (on `category`, `transaction_date`, and `region`), then reload. Each additional index multiplies the per-row overhead during COPY.

---

## Step 5: Load into DuckDB

DuckDB reads Parquet files natively — no explicit table creation or COPY step needed.

```python
# Load from Parquet into DuckDB
start = time.perf_counter()

duckdb.sql("""
    CREATE OR REPLACE TABLE sales_transactions
    AS SELECT * FROM 'benchmark_data/sales_transactions.parquet'
""")

duck_load_time = time.perf_counter() - start
print(f"DuckDB from Parquet: {duck_load_time:.2f} seconds")
```

<details>
<summary>Expected Output</summary>

~~~text
DuckDB from Parquet: 2-5 seconds
~~~

DuckDB loads 5M rows from Parquet in seconds — significantly faster than PostgreSQL's COPY.

</details>

### Verify the Load

```python
result = duckdb.sql("SELECT COUNT(*) AS row_count FROM sales_transactions")
print(result)
```

<details>
<summary>Expected Output</summary>

~~~text
┌───────────┐
│ row_count │
│   int64   │
├───────────┤
│   5000000 │
└───────────┘
~~~

</details>

---

## Step 6: Loading Performance Summary

```python
print(f"\n{'=' * 55}")
print(f"  Loading Performance Summary ({N_ROWS:,} rows)")
print(f"{'=' * 55}")
print(f"  {'Method':<35} {'Time (s)':>10}")
print(f"  {'-' * 45}")
print(f"  {'PostgreSQL COPY (from CSV)':<35} {pg_load_time:>10.1f}")
print(f"  {'DuckDB CREATE TABLE (from Parquet)':<35} {duck_load_time:>10.1f}")
print(f"  {'-' * 45}")
speedup = pg_load_time / duck_load_time if duck_load_time > 0 else 0
print(f"  DuckDB loaded {speedup:.1f}x faster")
print(f"{'=' * 55}")
```

<details>
<summary>Expected Output</summary>

~~~text
=======================================================
  Loading Performance Summary (5,000,000 rows)
=======================================================
  Method                                Time (s)
  ---------------------------------------------
  PostgreSQL COPY (from CSV)                55.0
  DuckDB CREATE TABLE (from Parquet)         3.5
  ---------------------------------------------
  DuckDB loaded 15.7x faster
=======================================================
~~~

</details>

**Why is DuckDB so much faster?**
1. **Parquet is smaller** — 85 MB vs 480 MB means less data to read from disk
2. **Parquet is pre-typed** — no need to parse strings into numbers/dates
3. **Parquet is columnar** — DuckDB's internal format is also columnar, so the data maps directly
4. **No index overhead** — DuckDB doesn't build a B-tree index (unlike PostgreSQL's PRIMARY KEY)

---

## Step 7: Quick Data Profile

Before moving to the benchmark in Lesson 16, let's verify the data distribution looks reasonable.

```python
# Profile using DuckDB (fast)
duckdb.sql("""
    SELECT
        category,
        COUNT(*) AS transactions,
        ROUND(AVG(total_amount), 2) AS avg_amount,
        ROUND(SUM(total_amount), 2) AS total_revenue
    FROM sales_transactions
    GROUP BY category
    ORDER BY total_revenue DESC
""").show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌────────────────┬──────────────┬────────────┬──────────────────┐
│   category     │ transactions │ avg_amount │  total_revenue   │
├────────────────┼──────────────┼────────────┼──────────────────┤
│ Home & Kitchen │      ~833K   │    ~1390   │  ~1.16 billion   │
│ Electronics    │      ~833K   │    ~1390   │  ~1.16 billion   │
│ Sports         │      ~833K   │    ~1390   │  ~1.16 billion   │
│ Toys           │      ~833K   │    ~1390   │  ~1.16 billion   │
│ Books          │      ~833K   │    ~1390   │  ~1.16 billion   │
│ Clothing       │      ~833K   │    ~1390   │  ~1.16 billion   │
└────────────────┴──────────────┴────────────┴──────────────────┘
~~~

With uniform random data, each of the 6 categories gets roughly 1/6 of the 5M rows (~833K). Revenue per category is similar because `unit_price` and `quantity` are also uniformly distributed.

</details>

```python
# Verify the date distribution by year
duckdb.sql("""
    SELECT
        EXTRACT(YEAR FROM transaction_date) AS year,
        COUNT(*) AS transactions,
        ROUND(SUM(total_amount), 2) AS revenue
    FROM sales_transactions
    GROUP BY year
    ORDER BY year
""").show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌──────┬──────────────┬──────────────────┐
│ year │ transactions │    revenue       │
├──────┼──────────────┼──────────────────┤
│ 2022 │    ~1.67M    │  ~2.3 billion    │
│ 2023 │    ~1.67M    │  ~2.3 billion    │
│ 2024 │    ~1.67M    │  ~2.3 billion    │
└──────┴──────────────┴──────────────────┘
~~~

Dates span 3 years with roughly equal distribution.

</details>

---

## Your Turn! (Exercises)

### Exercise 1: Measure INSERT Speed

**Task:** Insert 10,000 rows into PostgreSQL using Python's `executemany()` and compare the time to COPY. Use a separate temporary table so you don't affect the main dataset.

**Hint:** Use `psycopg2` to connect directly and `cursor.executemany()` to batch insert.

```python
import psycopg2

# TODO: Connect to benchmark_db using psycopg2
# TODO: Create a test_insert table (transaction_id INTEGER, category VARCHAR, quantity INTEGER, total_amount NUMERIC)
# TODO: Generate 10,000 rows of test data
# TODO: Time executemany() for 10K rows
# TODO: Print the time and project how long 5M rows would take
```

<details>
<summary>Solution</summary>

~~~python
import psycopg2

conn = psycopg2.connect("dbname=benchmark_db user=postgres password=postgres host=localhost")
cur = conn.cursor()

# Create temp table
cur.execute("DROP TABLE IF EXISTS test_insert")
cur.execute("""
    CREATE TABLE test_insert (
        transaction_id INTEGER,
        category VARCHAR(20),
        quantity INTEGER,
        total_amount NUMERIC(12, 2)
    )
""")
conn.commit()

# Generate 10K rows
test_data = [
    (i, np.random.choice(CATEGORIES), int(np.random.randint(1, 11)), float(round(np.random.uniform(5, 2500), 2)))
    for i in range(10_000)
]

# Time the INSERT
start = time.perf_counter()
cur.executemany(
    "INSERT INTO test_insert VALUES (%s, %s, %s, %s)",
    test_data
)
conn.commit()
insert_time = time.perf_counter() - start

print(f"executemany for 10K rows: {insert_time:.2f} seconds")
print(f"Projected for 5M rows:   {insert_time * 500:.0f} seconds ({insert_time * 500 / 60:.0f} minutes)")
print(f"\nCOPY loaded 5M rows in:  {pg_load_time:.0f} seconds")

cur.execute("DROP TABLE test_insert")
conn.commit()
cur.close()
conn.close()
~~~

</details>

### Exercise 2: Compare CSV vs Parquet Read Speed in DuckDB

**Task:** Time how long DuckDB takes to run a GROUP BY aggregation directly on the CSV file vs. the Parquet file — without loading data into a table first.

```python
# TODO: Time the query on CSV: SELECT category, SUM(total_amount) FROM 'benchmark_data/sales_transactions.csv' GROUP BY category
# TODO: Time the same query on Parquet
# TODO: Print comparison
```

<details>
<summary>Solution</summary>

~~~python
# CSV query
start = time.perf_counter()
duckdb.sql("SELECT category, SUM(total_amount) FROM 'benchmark_data/sales_transactions.csv' GROUP BY category")
csv_query_time = time.perf_counter() - start

# Parquet query
start = time.perf_counter()
duckdb.sql("SELECT category, SUM(total_amount) FROM 'benchmark_data/sales_transactions.parquet' GROUP BY category")
parquet_query_time = time.perf_counter() - start

print(f"DuckDB on CSV:     {csv_query_time:.3f}s")
print(f"DuckDB on Parquet: {parquet_query_time:.3f}s")
print(f"Parquet is {csv_query_time / parquet_query_time:.1f}x faster")
~~~

</details>

### Exercise 3: Explore Data Distribution

**Task:** Write a DuckDB query that shows the number of transactions per month per year, to verify the data is evenly distributed across the date range.

```python
# TODO: Use EXTRACT(YEAR ...) and EXTRACT(MONTH ...) with GROUP BY
# TODO: ORDER BY year, month
```

<details>
<summary>Solution</summary>

~~~python
duckdb.sql("""
    SELECT
        EXTRACT(YEAR FROM transaction_date) AS year,
        EXTRACT(MONTH FROM transaction_date) AS month,
        COUNT(*) AS transactions
    FROM sales_transactions
    GROUP BY year, month
    ORDER BY year, month
""").show(max_rows=40)
~~~

You should see roughly equal counts (~139K) for each of the 36 months.

</details>

### Exercise 4: Binary COPY Format (Optional)

**Task:** PostgreSQL's COPY supports a binary format (`FORMAT binary`) that skips text parsing entirely. Export the `sales_transactions` table to binary format, create a fresh table, and import from binary. Compare the loading time against the CSV COPY time from Step 3.

**Hints:**
- Use `COPY sales_transactions TO '/tmp/sales.bin' WITH (FORMAT binary);` to export
- Use `CREATE TABLE sales_binary (LIKE sales_transactions INCLUDING ALL);` to create the target table
- Use `COPY sales_binary FROM '/tmp/sales.bin' WITH (FORMAT binary);` to import

```python
# TODO: Export sales_transactions to binary format (via psql)
# TODO: Create sales_binary table
# TODO: Time the binary COPY import
# TODO: Compare with pg_load_time from Step 3
# TODO: Clean up (DROP TABLE sales_binary, remove /tmp/sales.bin)
```

<details>
<summary>Solution</summary>

~~~python
# Export to binary format
!sudo -u postgres psql -d benchmark_db \
  -c "COPY sales_transactions TO '/tmp/sales.bin' WITH (FORMAT binary);"

# Create target table (copies schema including PK)
!sudo -u postgres psql -d benchmark_db \
  -c "DROP TABLE IF EXISTS sales_binary;" \
  -c "CREATE TABLE sales_binary (LIKE sales_transactions INCLUDING ALL);"

# Time the binary import
start = time.perf_counter()
!sudo -u postgres psql -d benchmark_db \
  -c "COPY sales_binary FROM '/tmp/sales.bin' WITH (FORMAT binary);"
binary_load_time = time.perf_counter() - start

print(f"CSV COPY time:    {pg_load_time:.1f} s")
print(f"Binary COPY time: {binary_load_time:.1f} s")
print(f"Speedup:          {pg_load_time / binary_load_time:.2f}x")

# Clean up
!sudo -u postgres psql -d benchmark_db -c "DROP TABLE IF EXISTS sales_binary;"
!sudo -u postgres rm -f /tmp/sales.bin
~~~

Binary COPY should be moderately faster than CSV COPY — it skips all text parsing — but the difference is less dramatic than CSV-vs-Parquet since both still go through PostgreSQL's row-oriented storage engine.

</details>

---

## Step 8: Multi-Scale Benchmark

In Steps 1–7, you ran each operation once at 5M rows. But *how* do these operations scale? Does PostgreSQL COPY time grow linearly with data size, or worse? Is DuckDB's advantage constant or does it widen?

This step provides a helper function that runs the key timed operations at any dataset size and appends results to a CSV file. You'll call it at several sizes and compare.

### Define the Helper Function

```python
import subprocess, csv
from datetime import datetime

def run_benchmark(n_rows, results_path='benchmark_data/timing_results.csv'):
    """Run timed operations at a given scale and append results to CSV."""

    os.makedirs('benchmark_data', exist_ok=True)
    tmp_csv = 'benchmark_data/_bench_sales.csv'
    tmp_parquet = 'benchmark_data/_bench_sales.parquet'

    def psql(sql):
        """Run a SQL command via psql."""
        subprocess.run(
            ['sudo', '-u', 'postgres', 'psql', '-d', 'benchmark_db', '-c', sql],
            capture_output=True, text=True
        )

    # ── 1. Generate data ──────────────────────────────────
    CATEGORIES      = ['Electronics', 'Clothing', 'Books', 'Home & Kitchen', 'Sports', 'Toys']
    REGIONS         = ['Northeast', 'Southeast', 'Midwest', 'West', 'Southwest']
    PAYMENT_METHODS = ['Credit Card', 'Debit Card', 'Cash', 'Digital Wallet']

    rng = np.random.default_rng(42)
    start = time.perf_counter()

    bench_df = pd.DataFrame({
        'transaction_id':   np.arange(1, n_rows + 1),
        'transaction_date': np.datetime64('2022-01-01') + rng.integers(0, 1095, n_rows).astype('timedelta64[D]'),
        'customer_id':      rng.integers(1, 100_001, n_rows),
        'product_id':       rng.integers(1, 5_001, n_rows),
        'category':         rng.choice(CATEGORIES, n_rows),
        'quantity':         rng.integers(1, 11, n_rows),
        'unit_price':       np.round(rng.uniform(5.0, 500.0, n_rows), 2),
        'total_amount':     0.0,  # computed below
        'region':           rng.choice(REGIONS, n_rows),
        'store_id':         rng.integers(1, 51, n_rows),
        'payment_method':   rng.choice(PAYMENT_METHODS, n_rows),
    })
    bench_df['total_amount'] = np.round(bench_df['quantity'] * bench_df['unit_price'], 2)
    gen_time = time.perf_counter() - start

    # ── 2. Save CSV ───────────────────────────────────────
    start = time.perf_counter()
    bench_df.to_csv(tmp_csv, index=False)
    csv_write = time.perf_counter() - start
    csv_size = os.path.getsize(tmp_csv) / 1e6

    # ── 3. Save Parquet (Snappy) ──────────────────────────
    start = time.perf_counter()
    bench_df.to_parquet(tmp_parquet, index=False, engine='pyarrow')
    parquet_write = time.perf_counter() - start
    parquet_size = os.path.getsize(tmp_parquet) / 1e6

    # ── 4. PostgreSQL COPY with PK ────────────────────────
    table_ddl_pk = """
        CREATE TABLE _bench_with_pk (
            transaction_id   INTEGER PRIMARY KEY,
            transaction_date DATE NOT NULL, customer_id INTEGER NOT NULL,
            product_id INTEGER NOT NULL, category VARCHAR(20) NOT NULL,
            quantity INTEGER NOT NULL, unit_price NUMERIC(10,2) NOT NULL,
            total_amount NUMERIC(12,2) NOT NULL, region VARCHAR(20) NOT NULL,
            store_id INTEGER NOT NULL, payment_method VARCHAR(20) NOT NULL
        )
    """
    abs_csv = os.path.abspath(tmp_csv)

    psql("DROP TABLE IF EXISTS _bench_with_pk")
    psql(table_ddl_pk)
    start = time.perf_counter()
    psql(f"\\COPY _bench_with_pk FROM '{abs_csv}' WITH (FORMAT csv, HEADER true)")
    pg_copy_pk = time.perf_counter() - start

    # ── 5. PostgreSQL COPY without PK + PK creation ───────
    table_ddl_no_pk = """
        CREATE TABLE _bench_no_pk (
            transaction_id   INTEGER,
            transaction_date DATE NOT NULL, customer_id INTEGER NOT NULL,
            product_id INTEGER NOT NULL, category VARCHAR(20) NOT NULL,
            quantity INTEGER NOT NULL, unit_price NUMERIC(10,2) NOT NULL,
            total_amount NUMERIC(12,2) NOT NULL, region VARCHAR(20) NOT NULL,
            store_id INTEGER NOT NULL, payment_method VARCHAR(20) NOT NULL
        )
    """
    psql("DROP TABLE IF EXISTS _bench_no_pk")
    psql(table_ddl_no_pk)
    start = time.perf_counter()
    psql(f"\\COPY _bench_no_pk FROM '{abs_csv}' WITH (FORMAT csv, HEADER true)")
    pg_copy_no_pk = time.perf_counter() - start

    start = time.perf_counter()
    psql("ALTER TABLE _bench_no_pk ADD PRIMARY KEY (transaction_id)")
    pg_pk_create = time.perf_counter() - start

    # ── 6. DuckDB load from Parquet ───────────────────────
    start = time.perf_counter()
    duckdb.sql(f"CREATE OR REPLACE TABLE _bench_duck AS SELECT * FROM '{tmp_parquet}'")
    duckdb_load = time.perf_counter() - start

    # ── 7. Clean up ───────────────────────────────────────
    psql("DROP TABLE IF EXISTS _bench_with_pk")
    psql("DROP TABLE IF EXISTS _bench_no_pk")
    duckdb.sql("DROP TABLE IF EXISTS _bench_duck")
    if os.path.exists(tmp_csv):
        os.remove(tmp_csv)
    if os.path.exists(tmp_parquet):
        os.remove(tmp_parquet)

    # ── 8. Append results to CSV ──────────────────────────
    row = {
        'n_rows':             n_rows,
        'timestamp':          datetime.now().isoformat(timespec='seconds'),
        'gen_time_s':         round(gen_time, 3),
        'csv_write_s':        round(csv_write, 3),
        'csv_size_mb':        round(csv_size, 1),
        'parquet_write_s':    round(parquet_write, 3),
        'parquet_size_mb':    round(parquet_size, 1),
        'pg_copy_with_pk_s':  round(pg_copy_pk, 3),
        'pg_copy_no_pk_s':    round(pg_copy_no_pk, 3),
        'pg_pk_create_s':     round(pg_pk_create, 3),
        'duckdb_load_s':      round(duckdb_load, 3),
    }

    file_exists = os.path.exists(results_path)
    with open(results_path, 'a', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=row.keys())
        if not file_exists:
            writer.writeheader()
        writer.writerow(row)

    # ── 9. Print summary ─────────────────────────────────
    print(f"  {n_rows:>10,} rows  |  PG+PK: {pg_copy_pk:.1f}s  "
          f"|  PG no-PK: {pg_copy_no_pk:.1f}s + {pg_pk_create:.1f}s  "
          f"|  DuckDB: {duckdb_load:.2f}s  |  saved")
```

### Run at Small Sizes First

These complete in seconds — watch the timings grow.

```python
run_benchmark(50_000)
```

```python
run_benchmark(500_000)
```

Watch the PostgreSQL COPY times — they should be growing faster than linearly relative to the DuckDB times.

### Run at Larger Sizes

These take longer. Observe the gap widen between engines.

```python
run_benchmark(2_000_000)
```

```python
run_benchmark(5_000_000)
```

### Analyze Results

```python
results = pd.read_csv('benchmark_data/timing_results.csv')

# Full timing table
print(results[['n_rows', 'pg_copy_with_pk_s', 'pg_copy_no_pk_s',
               'pg_pk_create_s', 'duckdb_load_s']].to_string(index=False))

# Scaling ratios relative to the smallest run
if len(results) > 1:
    base = results.iloc[0]
    print(f"\n{'n_rows':>12}  {'PG+PK scale':>12}  {'DuckDB scale':>13}")
    print(f"{'-' * 40}")
    for _, r in results.iterrows():
        pg_ratio = r['pg_copy_with_pk_s'] / base['pg_copy_with_pk_s']
        duck_ratio = r['duckdb_load_s'] / base['duckdb_load_s']
        print(f"{int(r['n_rows']):>12,}  {pg_ratio:>12.1f}x  {duck_ratio:>13.1f}x")
```

<details>
<summary>Expected Output</summary>

~~~text
  n_rows  pg_copy_with_pk_s  pg_copy_no_pk_s  pg_pk_create_s  duckdb_load_s
   50000              1.200            0.800           0.300          0.050
  500000             12.500            8.500           2.800          0.350
 2000000             52.000           35.000          10.500          1.200
 5000000            135.000           90.000          28.000          3.500

      n_rows   PG+PK scale   DuckDB scale
----------------------------------------
      50,000          1.0x           1.0x
     500,000         10.4x           7.0x
   2,000,000         43.3x          24.0x
   5,000,000        112.5x          70.0x
~~~

Exact numbers vary by Colab instance. The pattern is what matters: PostgreSQL with active indexes scales worse than linearly, while DuckDB stays closer to linear.

</details>

Notice that PostgreSQL COPY scales worse than linearly — it does more work per row as the dataset grows (B-tree index depth increases, buffer pool pressure rises). DuckDB scales more linearly because columnar ingestion from Parquet is sequential with no index overhead. The gap between the two engines *widens* at scale — this is exactly why engine choice becomes critical for large analytical workloads.

**Want finer-grained scaling?** Run `run_benchmark(100_000)` or `run_benchmark(1_000_000)`. Results append to the same CSV — re-run the analysis cell to see the updated table. The function never touches your main `sales_transactions` table, so it's safe to run as many times as you like.

---

## Summary

In this lab, you have successfully:

1. ✅ Generated a 5M-row dataset using NumPy vectorized operations (~2–3 seconds)
2. ✅ Saved data in CSV and Parquet formats, and compared compression algorithms (Snappy vs ZSTD vs None)
3. ✅ Loaded data into PostgreSQL using COPY (~40–80 seconds)
4. ✅ Measured index overhead — COPY with vs without active indexes
5. ✅ Loaded data into DuckDB from Parquet (~3–5 seconds)
6. ✅ Verified row counts and data integrity across both engines
7. ✅ Profiled the data distribution for benchmark readiness
8. ✅ Ran a multi-scale benchmark to observe how operations scale from 50K to 5M rows

**Key Takeaways:**

- **NumPy vectorized generation** is 50x faster than Python loops for large datasets
- **Parquet files** are 4–6x smaller than CSV with no loss of information — and compression choice (Snappy vs ZSTD) trades file size for CPU time
- **PostgreSQL COPY** is orders of magnitude faster than row-by-row INSERT
- **Dropping indexes before bulk loading** and recreating them afterward is faster than loading with active indexes
- **DuckDB's native Parquet support** makes loading nearly instant
- **The performance gap widens at scale** — operations that look similar at 50K rows diverge dramatically at 5M rows
- The data is now ready for the **Lesson 16 performance benchmark**

