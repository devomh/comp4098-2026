---
title: "Lab: PostgreSQL vs DuckDB — The Performance Benchmark"
week: 08
type: lab
tags: [performance, benchmark, postgresql, duckdb, explain, analytics, visualization, python]
difficulty: intermediate
duration: "60 mins"
---

# Lab: PostgreSQL vs DuckDB — The Performance Benchmark

## Prerequisites & Setup

**Before starting this lab, you should:**
- Review [w08_l16_concept_query_performance.md](w08_l16_concept_query_performance.md) for EXPLAIN and benchmarking concepts
- Have completed [Lesson 15 Lab](w08_l15_lab_dataset_preparation.md) for data generation context
- Understand analytical SQL: GROUP BY (L12), Window Functions (L13), CTEs + LAG (L14)

**What you'll accomplish:**
In this lab, you'll run identical analytical queries on both PostgreSQL and DuckDB, measure execution times, analyze PostgreSQL's EXPLAIN output, and visualize the results to understand when each engine excels.

**Goal:** Empirically demonstrate the performance differences between row-oriented (OLTP) and column-oriented (OLAP) engines on analytical workloads.

---

## Environment Setup

This lab is self-contained — it generates the dataset and loads both engines from scratch.

```python
# 1. Install Python packages
!pip install -q duckdb pandas numpy psycopg2-binary jupysql matplotlib mermaid-py
```

```python
# 2. Install and start PostgreSQL
!sudo apt-get -y -qq update > /dev/null
!sudo apt-get -y -qq install postgresql postgresql-contrib > /dev/null
!service postgresql start
```

```python
# 3. Create the database
!sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'postgres';"
!sudo -u postgres psql -c "DROP DATABASE IF EXISTS benchmark_db;"
!sudo -u postgres psql -c "CREATE DATABASE benchmark_db;"
```

```python
# 4. Import libraries
import numpy as np
import pandas as pd
import duckdb
import psycopg2
import time
import os
import matplotlib.pyplot as plt
import warnings
warnings.filterwarnings('ignore')

# Connect SQL Magic (for EXPLAIN queries later)
%load_ext sql
%config SqlMagic.autocommit = True
%config SqlMagic.feedback = False
%config SqlMagic.displaycon = False
%config SqlMagic.displaylimit = 30
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

## Step 1: Generate & Load the Dataset

Compact data generation — same dataset structure as Lesson 15, self-contained for this lab.

```python
# ── Dataset Size Configuration ──────────────────────
# Uncomment one block to select your scale.

# --- Quick test (verify queries work) ---
# N_ROWS = 100_000

# --- Default benchmark ---
N_ROWS = 5_000_000

# --- Full benchmark (syllabus target) ---
# N_ROWS = 10_000_000
```

```python
np.random.seed(42)

CATEGORIES      = ['Electronics', 'Clothing', 'Books', 'Home & Kitchen', 'Sports', 'Toys']
REGIONS         = ['Northeast', 'Southeast', 'Midwest', 'West', 'Southwest']
PAYMENT_METHODS = ['Credit Card', 'Debit Card', 'Cash', 'Digital Wallet']

print(f"Generating {N_ROWS:,} rows...")
start = time.perf_counter()

df = pd.DataFrame({
    'transaction_id':   np.arange(1, N_ROWS + 1),
    'transaction_date': (np.datetime64('2022-01-01')
                         + np.random.randint(0, 1095, N_ROWS).astype('timedelta64[D]')),
    'customer_id':      np.random.randint(1, 100_001, N_ROWS),
    'product_id':       np.random.randint(1, 5_001, N_ROWS),
    'category':         np.random.choice(CATEGORIES, N_ROWS),
    'quantity':         np.random.randint(1, 11, N_ROWS),
    'unit_price':       np.round(np.random.uniform(5.0, 500.0, N_ROWS), 2),
    'region':           np.random.choice(REGIONS, N_ROWS),
    'store_id':         np.random.randint(1, 51, N_ROWS),
    'payment_method':   np.random.choice(PAYMENT_METHODS, N_ROWS),
})
df['total_amount'] = np.round(df['quantity'] * df['unit_price'], 2)

gen_time = time.perf_counter() - start
print(f"Generated in {gen_time:.1f}s")

# Save as CSV (for PostgreSQL) and Parquet (for DuckDB)
os.makedirs('benchmark_data', exist_ok=True)
df.to_csv('benchmark_data/sales_transactions.csv', index=False)
df.to_parquet('benchmark_data/sales_transactions.parquet', index=False)

csv_mb = os.path.getsize('benchmark_data/sales_transactions.csv') / 1e6
pq_mb  = os.path.getsize('benchmark_data/sales_transactions.parquet') / 1e6
print(f"Saved CSV ({csv_mb:.0f} MB) and Parquet ({pq_mb:.0f} MB)")
```

<details>
<summary>Expected Output</summary>

~~~text
Generating 5,000,000 rows...
Generated in 2.5s
Saved CSV (480 MB) and Parquet (85 MB)
~~~

</details>

### Load into PostgreSQL

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
    region           VARCHAR(20) NOT NULL,
    store_id         INTEGER NOT NULL,
    payment_method   VARCHAR(20) NOT NULL,
    total_amount     NUMERIC(12, 2) NOT NULL
);
```

```python
print("Loading into PostgreSQL (COPY)...")
start = time.perf_counter()

pg_conn = psycopg2.connect("dbname=benchmark_db user=postgres password=postgres host=localhost")
cur = pg_conn.cursor()
with open('benchmark_data/sales_transactions.csv', 'r') as f:
    next(f)  # skip header
    cur.copy_expert("COPY sales_transactions FROM STDIN WITH (FORMAT csv)", f)
pg_conn.commit()
cur.close()
pg_conn.close()

pg_load = time.perf_counter() - start
print(f"PostgreSQL: {pg_load:.1f}s")
```

### Load into DuckDB

```python
print("Loading into DuckDB (Parquet)...")
start = time.perf_counter()

duckdb.sql("CREATE OR REPLACE TABLE sales_transactions AS SELECT * FROM 'benchmark_data/sales_transactions.parquet'")

duck_load = time.perf_counter() - start
print(f"DuckDB: {duck_load:.1f}s")
```

### Verify Row Counts

```python
pg_count = %sql SELECT COUNT(*) FROM sales_transactions
duck_count = duckdb.sql("SELECT COUNT(*) FROM sales_transactions").fetchone()[0]
print(f"PostgreSQL: {pg_count.DataFrame().iloc[0, 0]:,} rows")
print(f"DuckDB:     {duck_count:,} rows")
```

---

## Step 2: The Benchmarking Framework

We need a consistent way to time queries on both engines. This function implements the methodology from the concept lesson: warm-up run, multiple iterations, median timing.

```python
def benchmark_query(query, label, n_runs=3):
    """
    Run a query on both PostgreSQL and DuckDB.
    Returns a dict with median execution times and speedup factor.
    """
    # ── PostgreSQL ──────────────────────────────────
    pg_conn = psycopg2.connect(
        "dbname=benchmark_db user=postgres password=postgres host=localhost"
    )

    # Warm-up run (discard — primes query-specific caches)
    cur = pg_conn.cursor()
    cur.execute(query)
    cur.fetchall()
    cur.close()

    pg_times = []
    for _ in range(n_runs):
        cur = pg_conn.cursor()
        start = time.perf_counter()
        cur.execute(query)
        cur.fetchall()
        elapsed = time.perf_counter() - start
        pg_times.append(elapsed)
        cur.close()
    pg_conn.close()

    # ── DuckDB ──────────────────────────────────────
    # Warm-up run (discard)
    duckdb.sql(query).fetchall()

    duck_times = []
    for _ in range(n_runs):
        start = time.perf_counter()
        duckdb.sql(query).fetchall()
        elapsed = time.perf_counter() - start
        duck_times.append(elapsed)

    # ── Compute median ──────────────────────────────
    pg_median   = sorted(pg_times)[len(pg_times) // 2]
    duck_median = sorted(duck_times)[len(duck_times) // 2]
    speedup     = pg_median / duck_median if duck_median > 0 else float('inf')

    return {
        'query':        label,
        'pg_seconds':   round(pg_median, 4),
        'duck_seconds': round(duck_median, 4),
        'speedup':      round(speedup, 2),
    }
```

```python
# Warm-up run — prime the OS file cache so the first benchmark
# query isn't unfairly penalized by cold disk reads.
print("Warming up caches...")
_ = %sql SELECT COUNT(*) FROM sales_transactions
_ = duckdb.sql("SELECT COUNT(*) FROM sales_transactions")
print("Ready to benchmark!")
```

<details>
<summary>Expected Output</summary>

~~~text
Warming up caches...
Ready to benchmark!
~~~

</details>

---

## Step 3: Run the Benchmark Suite

We'll test 6 queries that represent common analytical patterns — the same patterns you learned in Weeks 6–7.

### Benchmark 1: Simple COUNT

The most basic analytical operation — count all rows.

```python
q1 = "SELECT COUNT(*) FROM sales_transactions"

r1 = benchmark_query(q1, "COUNT(*)")
print(f"COUNT(*)  →  PG: {r1['pg_seconds']}s  |  DuckDB: {r1['duck_seconds']}s  |  Speedup: {r1['speedup']}x")
```

<details>
<summary>Expected Output</summary>

~~~text
COUNT(*)  →  PG: 0.8-1.5s  |  DuckDB: 0.01-0.05s  |  Speedup: 20-80x
~~~

DuckDB can answer COUNT(*) almost instantly from column metadata without scanning data. PostgreSQL must scan the entire table because MVCC requires checking row visibility.

</details>

### Benchmark 2: Filtered Aggregation

Aggregate with a WHERE clause — filters on category and date.

```python
q2 = """
    SELECT COUNT(*) AS n,
           SUM(total_amount) AS revenue,
           AVG(total_amount) AS avg_order
    FROM sales_transactions
    WHERE category = 'Electronics'
      AND transaction_date >= '2024-01-01'
"""

r2 = benchmark_query(q2, "Filtered Agg")
print(f"Filtered Agg  →  PG: {r2['pg_seconds']}s  |  DuckDB: {r2['duck_seconds']}s  |  Speedup: {r2['speedup']}x")
```

<details>
<summary>Expected Output</summary>

~~~text
Filtered Agg  →  PG: 1.0-2.0s  |  DuckDB: 0.02-0.10s  |  Speedup: 15-40x
~~~

</details>

### Benchmark 3: GROUP BY Aggregation

The classic analytical pattern — revenue breakdown by category (Lesson 12).

```python
q3 = """
    SELECT category,
           COUNT(*) AS transactions,
           SUM(total_amount) AS revenue,
           AVG(total_amount) AS avg_order
    FROM sales_transactions
    GROUP BY category
    ORDER BY revenue DESC
"""

r3 = benchmark_query(q3, "GROUP BY")
print(f"GROUP BY  →  PG: {r3['pg_seconds']}s  |  DuckDB: {r3['duck_seconds']}s  |  Speedup: {r3['speedup']}x")
```

<details>
<summary>Expected Output</summary>

~~~text
GROUP BY  →  PG: 1.5-3.0s  |  DuckDB: 0.05-0.15s  |  Speedup: 15-30x
~~~

</details>

### Benchmark 4: Multi-Dimension GROUP BY

Revenue by region, category, and year — a typical dashboard query.

```python
q4 = """
    SELECT region,
           category,
           EXTRACT(YEAR FROM transaction_date) AS year,
           COUNT(*) AS transactions,
           SUM(total_amount) AS revenue
    FROM sales_transactions
    GROUP BY region, category, EXTRACT(YEAR FROM transaction_date)
    ORDER BY region, category, year
"""

r4 = benchmark_query(q4, "Multi-Dim GROUP BY")
print(f"Multi-Dim GROUP BY  →  PG: {r4['pg_seconds']}s  |  DuckDB: {r4['duck_seconds']}s  |  Speedup: {r4['speedup']}x")
```

<details>
<summary>Expected Output</summary>

~~~text
Multi-Dim GROUP BY  →  PG: 2.0-4.0s  |  DuckDB: 0.10-0.30s  |  Speedup: 10-25x
~~~

</details>

### Benchmark 5: Window Function (Ranking)

Rank stores by revenue within each category — uses the window functions from Lesson 13.

```python
q5 = """
    SELECT category, store_id, revenue,
           RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS rnk
    FROM (
        SELECT category,
               store_id,
               SUM(total_amount) AS revenue
        FROM sales_transactions
        GROUP BY category, store_id
    ) sub
    ORDER BY category, rnk
"""

r5 = benchmark_query(q5, "Window (RANK)")
print(f"Window (RANK)  →  PG: {r5['pg_seconds']}s  |  DuckDB: {r5['duck_seconds']}s  |  Speedup: {r5['speedup']}x")
```

<details>
<summary>Expected Output</summary>

~~~text
Window (RANK)  →  PG: 2.0-4.0s  |  DuckDB: 0.10-0.30s  |  Speedup: 10-20x
~~~

</details>

### Benchmark 6: CTE with LAG (Month-over-Month)

Monthly revenue trend with month-over-month change — uses CTEs + LAG from Lesson 14.

```python
q6 = """
    WITH monthly AS (
        SELECT
            DATE_TRUNC('month', transaction_date) AS month,
            SUM(total_amount) AS revenue
        FROM sales_transactions
        GROUP BY DATE_TRUNC('month', transaction_date)
    )
    SELECT
        month,
        revenue,
        LAG(revenue) OVER (ORDER BY month) AS prev_month,
        ROUND(
            (revenue - LAG(revenue) OVER (ORDER BY month))
            / LAG(revenue) OVER (ORDER BY month) * 100,
            2
        ) AS mom_change_pct
    FROM monthly
    ORDER BY month
"""

r6 = benchmark_query(q6, "CTE + LAG (MoM)")
print(f"CTE + LAG (MoM)  →  PG: {r6['pg_seconds']}s  |  DuckDB: {r6['duck_seconds']}s  |  Speedup: {r6['speedup']}x")
```

<details>
<summary>Expected Output</summary>

~~~text
CTE + LAG (MoM)  →  PG: 1.5-3.0s  |  DuckDB: 0.05-0.20s  |  Speedup: 10-25x
~~~

</details>

---

## Step 4: Results Summary

```python
# Collect all results into a DataFrame
results = [r1, r2, r3, r4, r5, r6]
results_df = pd.DataFrame(results)

print(f"\n{'=' * 65}")
print(f"  BENCHMARK RESULTS — {N_ROWS:,} rows")
print(f"{'=' * 65}")
print(results_df.to_string(index=False))
print(f"{'=' * 65}")
print(f"\n  Average speedup: {results_df['speedup'].mean():.1f}x")
print(f"  Max speedup:     {results_df['speedup'].max():.1f}x ({results_df.loc[results_df['speedup'].idxmax(), 'query']})")
```

<details>
<summary>Expected Output</summary>

~~~text
=====================================================================
  BENCHMARK RESULTS — 5,000,000 rows
=====================================================================
              query  pg_seconds  duck_seconds  speedup
           COUNT(*)      1.0000        0.0200     50.0
       Filtered Agg      1.5000        0.0500     30.0
           GROUP BY      2.0000        0.1000     20.0
 Multi-Dim GROUP BY      3.0000        0.1500     20.0
      Window (RANK)      3.0000        0.2000     15.0
    CTE + LAG (MoM)      2.0000        0.1000     20.0
=====================================================================

  Average speedup: 25.8x
  Max speedup:     50.0x (COUNT(*))
~~~

Exact numbers vary by Colab instance. The pattern should be consistent: DuckDB is 10–50x faster for analytical queries.

</details>

---

## Step 5: Visualize the Results

```python
fig, ax = plt.subplots(figsize=(8, 5))

x = range(len(results_df))
width = 0.35

ax.bar([i - width/2 for i in x], results_df['pg_seconds'],
       width, label='PostgreSQL', color='#336791')
ax.bar([i + width/2 for i in x], results_df['duck_seconds'],
       width, label='DuckDB', color='#FFC107')
ax.set_xlabel('Query')
ax.set_ylabel('Execution Time (seconds)')
ax.set_title('PostgreSQL vs DuckDB — Execution Time')
ax.set_xticks(x)
ax.set_xticklabels(results_df['query'], rotation=45, ha='right')
ax.legend()

plt.tight_layout()
plt.savefig('benchmark_results.png', dpi=150, bbox_inches='tight')
plt.show()
print("Chart saved to benchmark_results.png")
```

<details>
<summary>Expected Output</summary>

A side-by-side bar chart — PostgreSQL bars are dramatically taller than DuckDB bars for analytical queries. DuckDB bars may be barely visible, which is the point.

</details>

---

## Step 6: Analyze PostgreSQL Query Plans

Let's look at *why* PostgreSQL is slower by examining its query plans with `EXPLAIN ANALYZE`.

### Plan for GROUP BY Aggregation

```python
%%sql
EXPLAIN ANALYZE
SELECT category, COUNT(*), SUM(total_amount)
FROM sales_transactions
GROUP BY category
ORDER BY SUM(total_amount) DESC;
```

<details>
<summary>Expected Output</summary>

~~~text
Sort  (cost=... rows=6 ...)  (actual time=...ms)
  Sort Key: (sum(total_amount)) DESC
  Sort Method: quicksort  Memory: 25kB
  ->  HashAggregate  (cost=... rows=6 ...)  (actual time=...ms)
        Group Key: category
        Batches: 1  Memory Usage: ...
        ->  Seq Scan on sales_transactions  (cost=... rows=5000000 ...)  (actual time=...ms)
Planning Time: X.XX ms
Execution Time: XXXX.XX ms
~~~

**Key observations:**
- **Seq Scan** reads all 5M rows — there's no way around it for a full-table aggregation
- **HashAggregate** is efficient (only 6 groups), so grouping itself is fast
- Most time is spent in the Seq Scan — reading row-by-row through the entire table

</details>

**Why is the Seq Scan slow?** PostgreSQL stores data in rows. To read just the `category` and `total_amount` columns, it must read *every column* of *every row* — including `transaction_id`, `customer_id`, `product_id`, `region`, `payment_method`, etc. That's wasted I/O. DuckDB reads only the 2 columns it needs.

### Plan for Filtered Query

```python
%%sql
EXPLAIN ANALYZE
SELECT COUNT(*), SUM(total_amount)
FROM sales_transactions
WHERE category = 'Electronics'
  AND transaction_date >= '2024-01-01';
```

<details>
<summary>Expected Output</summary>

~~~text
Aggregate  (cost=... rows=1 ...)  (actual time=...ms)
  ->  Seq Scan on sales_transactions  (cost=... rows=... ...)  (actual time=...ms)
        Filter: ((category = 'Electronics'::text) AND (transaction_date >= '2024-01-01'::date))
        Rows Removed by Filter: XXXXXXX
Planning Time: X.XX ms
Execution Time: XXXX.XX ms
~~~

**Key observation:** Even though only ~277K rows match the filter (~1/18th of the data), PostgreSQL still performs a **Seq Scan** of all 5M rows. Without an index on `category` or `transaction_date`, it has no way to skip non-matching rows.

</details>

---

## Step 7: DuckDB Query Profiling

In Step 6, you saw PostgreSQL's plans with `EXPLAIN ANALYZE`. Now let's see the same queries from DuckDB's perspective — this makes column pruning and vectorized execution visible rather than theoretical.

### DuckDB Plan for GROUP BY Aggregation

```python
# DuckDB's EXPLAIN ANALYZE for the same GROUP BY query
result = duckdb.sql("""
    EXPLAIN ANALYZE
    SELECT category, COUNT(*), SUM(total_amount)
    FROM sales_transactions
    GROUP BY category
    ORDER BY SUM(total_amount) DESC
""")
print(result.fetchone()[1])
```

<details>
<summary>Expected Output</summary>

~~~text
┌─────────────────────────────────────────┐
│┌───────────────────────────────────────┐│
││    Query Profiling Information        ││
│└───────────────────────────────────────┘│
│┌───────────────────────────────────────┐│
││         EXPLAIN ANALYZE              ││
│├───────────────────────────────────────┤│
││ ORDER_BY                             ││
││ HASH_GROUP_BY                        ││
││   Groups: 6                          ││
││ TABLE_SCAN  sales_transactions       ││
││   Columns: category, total_amount    ││
││   Rows: 5000000                      ││
│└───────────────────────────────────────┘│
└─────────────────────────────────────────┘
~~~

The exact format varies by DuckDB version. Key things to notice:
- **TABLE_SCAN** lists only `category` and `total_amount` — column pruning in action (2 of 11 columns)
- **HASH_GROUP_BY** processes data in vectorized batches
- Total execution time is dramatically less than PostgreSQL's equivalent plan

</details>

### Side-by-Side Comparison

```python
print("""
PostgreSQL (EXPLAIN ANALYZE)                DuckDB (EXPLAIN ANALYZE)
────────────────────────────────────────    ────────────────────────────────────────
Seq Scan: reads ALL 11 columns              TABLE_SCAN: reads only 2 columns
  → ~500 MB of I/O                            → ~60 MB of I/O
HashAggregate: processes row by row          HASH_GROUP_BY: vectorized batches
  → one row at a time                          → 2,048 values at a time
Execution Time: ~1500 ms                    Execution Time: ~50-100 ms
""")
```

### DuckDB Plan for Filtered Query

```python
result = duckdb.sql("""
    EXPLAIN ANALYZE
    SELECT COUNT(*), SUM(total_amount)
    FROM sales_transactions
    WHERE category = 'Electronics'
      AND transaction_date >= '2024-01-01'
""")
print(result.fetchone()[1])
```

<details>
<summary>Expected Output</summary>

~~~text
The plan should show:
- TABLE_SCAN with a filter applied, reading only the needed columns
- Far fewer rows processed than the full 5M (the filter reduces the scan)
- Total time significantly less than PostgreSQL's Seq Scan of all 5M rows
~~~

</details>

DuckDB's plan confirms what the concept lesson described: column pruning means it reads only the columns it needs, and vectorized execution means it processes them in batches. PostgreSQL's Seq Scan reads every column of every row regardless. This I/O difference is the primary reason for the 10–50x speedup you measured in Step 3.

---

## Step 8: The Point Lookup — Where PostgreSQL Shines

Not all queries favor column stores. Let's test a single-row lookup by primary key.

```python
q_lookup = "SELECT * FROM sales_transactions WHERE transaction_id = 2500000"

# ── PostgreSQL (with primary key index) ──
pg_conn = psycopg2.connect(
    "dbname=benchmark_db user=postgres password=postgres host=localhost"
)
pg_times = []
for _ in range(5):
    cur = pg_conn.cursor()
    start = time.perf_counter()
    cur.execute(q_lookup)
    cur.fetchall()
    pg_times.append(time.perf_counter() - start)
    cur.close()
pg_conn.close()
pg_lookup = sorted(pg_times)[2]  # median of 5

# ── DuckDB ──
duck_times = []
for _ in range(5):
    start = time.perf_counter()
    duckdb.sql(q_lookup).fetchall()
    duck_times.append(time.perf_counter() - start)
duck_lookup = sorted(duck_times)[2]  # median of 5

print(f"Point Lookup (1 row by Primary Key):")
print(f"  PostgreSQL: {pg_lookup * 1000:.2f} ms")
print(f"  DuckDB:     {duck_lookup * 1000:.2f} ms")
if pg_lookup < duck_lookup:
    print(f"  → PostgreSQL is {duck_lookup / pg_lookup:.1f}x faster!")
else:
    print(f"  → DuckDB is {pg_lookup / duck_lookup:.1f}x faster")
```

<details>
<summary>Expected Output</summary>

~~~text
Point Lookup (1 row by Primary Key):
  PostgreSQL: 0.20 - 1.00 ms
  DuckDB:     3.00 - 10.00 ms
  → PostgreSQL is 5-20x faster!
~~~

PostgreSQL uses its primary key **B-tree index** to locate the row instantly. DuckDB must scan column chunks to find the matching row — it has no index.

</details>

### Why PostgreSQL Wins Here

```python
%%sql
EXPLAIN ANALYZE
SELECT * FROM sales_transactions WHERE transaction_id = 2500000;
```

<details>
<summary>Expected Output</summary>

~~~text
Index Scan using sales_transactions_pkey on sales_transactions  (cost=0.43..8.45 rows=1 width=70)
  Index Cond: (transaction_id = 2500000)
  (actual time=0.020..0.022 rows=1 loops=1)
Planning Time: 0.05 ms
Execution Time: 0.04 ms
~~~

**Index Scan** — PostgreSQL jumps directly to the row via the B-tree index on `transaction_id`. No table scan needed. This is exactly what OLTP databases are built for.

</details>

---

## Your Turn! (Exercises)

### Exercise 1: Add Your Own Benchmark Query

**Task:** Write and benchmark a query that finds the **top 3 products by revenue for each region** using `ROW_NUMBER()` (Lesson 13 technique).

```python
# TODO: Write the query using a CTE with ROW_NUMBER() OVER (PARTITION BY region ...)
# TODO: Run it through benchmark_query()
# TODO: Print results
```

<details>
<summary>Hint</summary>

Use a CTE that groups by `region, product_id`, computes `SUM(total_amount)`, and applies `ROW_NUMBER() OVER (PARTITION BY region ORDER BY SUM(total_amount) DESC)`. Then filter for `rn <= 3` in the outer query.

</details>

<details>
<summary>Solution</summary>

~~~python
q_exercise1 = """
    WITH product_revenue AS (
        SELECT region,
               product_id,
               SUM(total_amount) AS revenue,
               ROW_NUMBER() OVER (
                   PARTITION BY region
                   ORDER BY SUM(total_amount) DESC
               ) AS rn
        FROM sales_transactions
        GROUP BY region, product_id
    )
    SELECT region, product_id, revenue
    FROM product_revenue
    WHERE rn <= 3
    ORDER BY region, revenue DESC
"""

r_ex1 = benchmark_query(q_exercise1, "Top 3 Products/Region")
print(f"Top 3/Region  →  PG: {r_ex1['pg_seconds']}s  |  DuckDB: {r_ex1['duck_seconds']}s  |  Speedup: {r_ex1['speedup']}x")
~~~

</details>

### Exercise 2: Index Impact Test

**Task:** Create an index on `category` in PostgreSQL, then re-run the filtered aggregation (Benchmark 2). Does the index help?

```python
# TODO: Create the index: CREATE INDEX idx_category ON sales_transactions(category);
# TODO: Re-run benchmark_query with q2 (the filtered aggregation query)
# TODO: Compare the before/after times
```

<details>
<summary>Hint</summary>

After creating the index, re-run the benchmark. The index may NOT help much here because ~1/6 of all rows match `'Electronics'` — the optimizer may still prefer a Seq Scan over an Index Scan when so many rows qualify.

</details>

<details>
<summary>Solution</summary>

~~~python
# Create the index
%sql CREATE INDEX idx_category ON sales_transactions(category);

# Re-benchmark
r2_indexed = benchmark_query(q2, "Filtered Agg (indexed)")

print(f"Without index: {r2['pg_seconds']}s")
print(f"With index:    {r2_indexed['pg_seconds']}s")

# Check if the optimizer even uses the index
%sql EXPLAIN ANALYZE SELECT COUNT(*), SUM(total_amount) FROM sales_transactions WHERE category = 'Electronics' AND transaction_date >= '2024-01-01';

# Observation: The optimizer likely STILL chooses Seq Scan because
# ~16% of rows match 'Electronics' — too many for an index to help.
# Indexes shine when < ~10% of rows match.
~~~

</details>

### Exercise 3: Interpret an EXPLAIN Plan

**Task:** Run the EXPLAIN ANALYZE below and answer the questions that follow.

```python
%%sql
EXPLAIN ANALYZE
SELECT region, payment_method,
       COUNT(*) AS transactions,
       SUM(total_amount) AS revenue
FROM sales_transactions
WHERE transaction_date BETWEEN '2023-06-01' AND '2023-12-31'
GROUP BY region, payment_method
ORDER BY revenue DESC;
```

**Questions** (write your answers as comments):

```python
# Q1: What scan type does PostgreSQL use? Why?
# TODO: Your answer

# Q2: Approximately how many rows were removed by the filter?
# TODO: Your answer

# Q3: What percentage of execution time is spent on the scan vs. the aggregation?
# TODO: Your answer
```

<details>
<summary>Solution</summary>

~~~python
# Q1: Seq Scan — PostgreSQL has no index on transaction_date,
#     so it must read every row and apply the filter.

# Q2: About 4,050,000 rows removed. The date range covers ~7 months
#     out of 36 months, so ~19% of rows match (~950K), and ~81% are
#     removed by the filter.

# Q3: Most time (~70-80%) is spent on the Seq Scan. The HashAggregate
#     and Sort are fast because they operate on the ~950K filtered rows,
#     not the full 5M.
~~~

</details>

### Exercise 4: work_mem Impact on Query Plans

**Task:** PostgreSQL's `work_mem` controls how much memory is available for sort and hash operations. Run the Multi-Dimension GROUP BY query (Benchmark 4) with two different `work_mem` settings and compare the `Sort Method` in EXPLAIN ANALYZE.

**Hints:**
- Use `SET work_mem = '1MB';` for low memory, `SET work_mem = '256MB';` for high memory
- Look for `Sort Method: external merge Disk` vs `Sort Method: quicksort Memory`
- Reset with `SET work_mem = '4MB';` when done

```python
# TODO: SET work_mem = '1MB'
# TODO: Run EXPLAIN ANALYZE on the Multi-Dim GROUP BY query (q4)
# TODO: Note the Sort Method
```

```python
# TODO: SET work_mem = '256MB'
# TODO: Run the same EXPLAIN ANALYZE
# TODO: Compare Sort Method and execution time
```

```python
# TODO: Reset work_mem to default
# SET work_mem = '4MB';
```

<details>
<summary>Solution</summary>

~~~python
%%sql
SET work_mem = '1MB';
EXPLAIN ANALYZE
SELECT region, category,
       EXTRACT(YEAR FROM transaction_date) AS year,
       COUNT(*) AS transactions,
       SUM(total_amount) AS revenue
FROM sales_transactions
GROUP BY region, category, EXTRACT(YEAR FROM transaction_date)
ORDER BY revenue DESC;
-- Look for: Sort Method: external merge  Disk: XXXXkB
~~~

~~~python
%%sql
SET work_mem = '256MB';
EXPLAIN ANALYZE
SELECT region, category,
       EXTRACT(YEAR FROM transaction_date) AS year,
       COUNT(*) AS transactions,
       SUM(total_amount) AS revenue
FROM sales_transactions
GROUP BY region, category, EXTRACT(YEAR FROM transaction_date)
ORDER BY revenue DESC;
-- Look for: Sort Method: quicksort  Memory: XXkB
~~~

~~~python
%%sql
-- Reset to default
SET work_mem = '4MB';
~~~

The key difference: `external merge Disk` means PostgreSQL ran out of memory and spilled to disk. `quicksort Memory` means everything fit in RAM. The execution time difference can be 2–5x. This shows that performance tuning isn't always about rewriting queries — sometimes it's a configuration change.

</details>

### Exercise 5: Stale Statistics and ANALYZE

**Task:** Check whether PostgreSQL's row count estimates are accurate after the bulk load. If they're stale, run `ANALYZE` and see how the estimates improve.

```python
# TODO: Check estimated vs actual row counts
# SELECT relname, reltuples::bigint AS estimated_rows,
#        (SELECT COUNT(*) FROM sales_transactions) AS actual_rows
# FROM pg_class WHERE relname = 'sales_transactions';
```

```python
# TODO: Run EXPLAIN (not ANALYZE) and note the rows= estimate
# EXPLAIN SELECT category, COUNT(*) FROM sales_transactions
# WHERE category = 'Electronics' GROUP BY category;
```

```python
# TODO: Update statistics
# ANALYZE sales_transactions;
```

```python
# TODO: Re-run EXPLAIN and compare the rows= estimate
```

<details>
<summary>Solution</summary>

~~~python
%%sql
-- Check estimated vs actual
SELECT relname, reltuples::bigint AS estimated_rows,
       (SELECT COUNT(*) FROM sales_transactions) AS actual_rows
FROM pg_class WHERE relname = 'sales_transactions';
~~~

~~~python
%%sql
-- EXPLAIN before ANALYZE — note the rows= estimate
EXPLAIN
SELECT category, COUNT(*)
FROM sales_transactions
WHERE category = 'Electronics'
GROUP BY category;
~~~

~~~python
%%sql
-- Update statistics
ANALYZE sales_transactions;
~~~

~~~python
%%sql
-- EXPLAIN after ANALYZE — rows= should now be ~833,333
EXPLAIN
SELECT category, COUNT(*)
FROM sales_transactions
WHERE category = 'Electronics'
GROUP BY category;
~~~

If the estimates were already accurate, PostgreSQL's `autovacuum` ran `ANALYZE` automatically — which is the usual case. But immediately after a large bulk load (like the COPY in Step 1), you may catch it before autovacuum fires. The key insight: bad statistics → bad plans → bad performance, even with good indexes. This is a common production debugging scenario.

</details>

---

## Step 9: Multi-Scale Query Benchmark

In the main benchmark (Steps 3–5), you ran all queries at a single scale (5M rows). But how does the PostgreSQL vs DuckDB speedup ratio change as data grows? At 50K rows the gap may be small; at 5M it may be 30x. This step uses the same helper-function pattern from Lesson 15 to run the query suite at multiple sizes.

### Define the Helper Function

```python
import subprocess, csv
from datetime import datetime

def run_query_benchmark(n_rows, results_path='benchmark_data/query_timing_results.csv'):
    """Run the query benchmark suite at a given scale and append results to CSV."""

    os.makedirs('benchmark_data', exist_ok=True)
    tmp_csv = 'benchmark_data/_qbench_sales.csv'
    tmp_parquet = 'benchmark_data/_qbench_sales.parquet'

    def psql(sql):
        subprocess.run(
            ['sudo', '-u', 'postgres', 'psql', '-d', 'benchmark_db', '-c', sql],
            capture_output=True, text=True
        )

    # ── 1. Generate & load data at this scale ─────────────
    rng = np.random.default_rng(42)
    CATEGORIES      = ['Electronics', 'Clothing', 'Books', 'Home & Kitchen', 'Sports', 'Toys']
    REGIONS         = ['Northeast', 'Southeast', 'Midwest', 'West', 'Southwest']
    PAYMENT_METHODS = ['Credit Card', 'Debit Card', 'Cash', 'Digital Wallet']

    bench_df = pd.DataFrame({
        'transaction_id':   np.arange(1, n_rows + 1),
        'transaction_date': np.datetime64('2022-01-01') + rng.integers(0, 1095, n_rows).astype('timedelta64[D]'),
        'customer_id':      rng.integers(1, 100_001, n_rows),
        'product_id':       rng.integers(1, 5_001, n_rows),
        'category':         rng.choice(CATEGORIES, n_rows),
        'quantity':         rng.integers(1, 11, n_rows),
        'unit_price':       np.round(rng.uniform(5.0, 500.0, n_rows), 2),
        'total_amount':     0.0,
        'region':           rng.choice(REGIONS, n_rows),
        'store_id':         rng.integers(1, 51, n_rows),
        'payment_method':   rng.choice(PAYMENT_METHODS, n_rows),
    })
    bench_df['total_amount'] = np.round(bench_df['quantity'] * bench_df['unit_price'], 2)

    bench_df.to_csv(tmp_csv, index=False)
    bench_df.to_parquet(tmp_parquet, index=False, engine='pyarrow')

    # Load into PostgreSQL
    table_ddl = """
        CREATE TABLE _qbench_sales (
            transaction_id INTEGER PRIMARY KEY,
            transaction_date DATE NOT NULL, customer_id INTEGER NOT NULL,
            product_id INTEGER NOT NULL, category VARCHAR(20) NOT NULL,
            quantity INTEGER NOT NULL, unit_price NUMERIC(10,2) NOT NULL,
            total_amount NUMERIC(12,2) NOT NULL, region VARCHAR(20) NOT NULL,
            store_id INTEGER NOT NULL, payment_method VARCHAR(20) NOT NULL
        )
    """
    abs_csv = os.path.abspath(tmp_csv)
    psql("DROP TABLE IF EXISTS _qbench_sales")
    psql(table_ddl)
    psql(f"\\COPY _qbench_sales FROM '{abs_csv}' WITH (FORMAT csv, HEADER true)")
    psql("ANALYZE _qbench_sales")

    # Load into DuckDB
    duckdb.sql(f"CREATE OR REPLACE TABLE _qbench_sales AS SELECT * FROM '{tmp_parquet}'")

    # ── 2. Define query suite ─────────────────────────────
    queries = {
        'COUNT':        "SELECT COUNT(*) FROM _qbench_sales",
        'Filtered_Agg': "SELECT COUNT(*), SUM(total_amount) FROM _qbench_sales WHERE category = 'Electronics' AND transaction_date >= '2024-01-01'",
        'GROUP_BY':     "SELECT category, COUNT(*), SUM(total_amount) FROM _qbench_sales GROUP BY category ORDER BY SUM(total_amount) DESC",
        'Multi_Dim':    "SELECT region, category, EXTRACT(YEAR FROM transaction_date) AS yr, COUNT(*), SUM(total_amount) FROM _qbench_sales GROUP BY region, category, yr ORDER BY region, category, yr",
    }

    # ── 3. Run benchmarks (3 iterations, median) ─────────
    row = {'n_rows': n_rows, 'timestamp': datetime.now().isoformat(timespec='seconds')}

    for label, sql in queries.items():
        pg_conn = psycopg2.connect("dbname=benchmark_db user=postgres password=postgres host=localhost")
        pg_times = []
        for _ in range(3):
            cur = pg_conn.cursor()
            start = time.perf_counter()
            cur.execute(sql)
            cur.fetchall()
            pg_times.append(time.perf_counter() - start)
            cur.close()
        pg_conn.close()

        duck_times = []
        for _ in range(3):
            start = time.perf_counter()
            duckdb.sql(sql).fetchall()
            duck_times.append(time.perf_counter() - start)

        pg_med = sorted(pg_times)[1]
        duck_med = sorted(duck_times)[1]

        row[f'pg_{label}_s'] = round(pg_med, 4)
        row[f'duck_{label}_s'] = round(duck_med, 4)
        row[f'speedup_{label}'] = round(pg_med / duck_med, 1) if duck_med > 0 else 0

    # ── 4. Clean up ───────────────────────────────────────
    psql("DROP TABLE IF EXISTS _qbench_sales")
    duckdb.sql("DROP TABLE IF EXISTS _qbench_sales")
    if os.path.exists(tmp_csv):
        os.remove(tmp_csv)
    if os.path.exists(tmp_parquet):
        os.remove(tmp_parquet)

    # ── 5. Append to CSV ─────────────────────────────────
    file_exists = os.path.exists(results_path)
    with open(results_path, 'a', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=row.keys())
        if not file_exists:
            writer.writeheader()
        writer.writerow(row)

    # ── 6. Print summary ─────────────────────────────────
    speedups = [v for k, v in row.items() if k.startswith('speedup_')]
    avg_speedup = sum(speedups) / len(speedups) if speedups else 0
    print(f"  {n_rows:>10,} rows  |  Avg speedup: {avg_speedup:.1f}x  |  saved")
```

### Run at Small Sizes First

```python
run_query_benchmark(50_000)
```

```python
run_query_benchmark(500_000)
```

### Run at Larger Sizes

```python
run_query_benchmark(2_000_000)
```

```python
run_query_benchmark(5_000_000)
```

### Analyze Results

```python
qresults = pd.read_csv('benchmark_data/query_timing_results.csv')

# Show speedup columns
speedup_cols = ['n_rows'] + [c for c in qresults.columns if c.startswith('speedup_')]
print(qresults[speedup_cols].to_string(index=False))
```

<details>
<summary>Expected Output</summary>

~~~text
  n_rows  speedup_COUNT  speedup_Filtered_Agg  speedup_GROUP_BY  speedup_Multi_Dim
   50000            3.0                   2.5               2.0                1.5
  500000           10.0                   8.0               7.0                5.0
 2000000           25.0                  18.0              15.0               12.0
 5000000           50.0                  30.0              20.0               15.0
~~~

Exact numbers vary. The pattern is what matters: speedup ratios grow with data size.

</details>

At 50K rows, the speedup is modest (2–5x) — both engines finish in milliseconds, and overhead from connection setup and query parsing is a significant fraction of total time. At 5M rows, the speedup grows to 15–50x — actual I/O and computation dominate, revealing the architectural advantage of columnar storage. This is why performance testing at toy scale gives misleading results.

**Want finer-grained results?** Run `run_query_benchmark(100_000)` or `run_query_benchmark(1_000_000)`. Results append to the same CSV. The function never touches your main `sales_transactions` table.

---

## Step 10: Conclusions

```python
from mermaid import Mermaid

Mermaid("""
graph TD
    A{What is your<br/>workload?} -->|Analytics & Reporting| B["Use DuckDB<br/>(Column Store)"]
    A -->|Transactions & Lookups| C["Use PostgreSQL<br/>(Row Store)"]
    A -->|Both| D["Use Both Together"]

    B --> B1["✓ GROUP BY, SUM, AVG"]
    B --> B2["✓ Window Functions"]
    B --> B3["✓ CTEs, Time-Series"]
    B --> B4["✓ Parquet/CSV Files"]

    C --> C1["✓ INSERT/UPDATE/DELETE"]
    C --> C2["✓ WHERE id = ?"]
    C --> C3["✓ Concurrent Users"]
    C --> C4["✓ ACID Transactions"]

    D --> D1["PostgreSQL → App DB"]
    D --> D2["DuckDB → Analytics"]

    style B fill:#FFC107,color:black
    style C fill:#336791,color:white
    style D fill:#4CAF50,color:white
""")
```

```python
print("""
╔══════════════════════════════════════════════════════════════════╗
║                    BENCHMARK CONCLUSIONS                        ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                 ║
║  1. DuckDB is 10-50x faster for ANALYTICAL queries:             ║
║     • Full-table aggregations (GROUP BY, SUM, COUNT)            ║
║     • Window functions (RANK, ROW_NUMBER)                       ║
║     • Time-series analysis (CTEs + LAG/LEAD)                    ║
║                                                                 ║
║  2. PostgreSQL is faster for TRANSACTIONAL operations:          ║
║     • Single-row lookups via index (WHERE id = ?)               ║
║     • INSERT/UPDATE/DELETE operations                           ║
║     • Concurrent multi-user access                              ║
║                                                                 ║
║  3. WHY the difference:                                         ║
║     • Column pruning — DuckDB reads only needed columns         ║
║     • Compression — similar values in a column compress well    ║
║     • Vectorized execution — process batches, not rows          ║
║     • PostgreSQL reads ALL columns even when only 2 are needed  ║
║                                                                 ║
║  4. CHOOSE the right engine for the workload:                   ║
║     • OLTP (transactions, web apps) → PostgreSQL                ║
║     • OLAP (analytics, reports, ML) → DuckDB                   ║
║     • Many production systems use BOTH together                 ║
║                                                                 ║
╚══════════════════════════════════════════════════════════════════╝
""")
```

---

## Additional Activity: NYC Taxi Data

The main benchmark uses a flat synthetic table — intentional for isolating engine architecture. But real analytical data has **fact tables** joined with **dimension tables** (star schema). This activity uses the NYC Taxi dataset to demonstrate joins, real-world data quality, and filter placement — things impossible with a single flat table.

**Note:** This activity requires downloading ~45 MB from the internet. If the download fails (network issues on Colab), you can skip it — the main benchmark (Steps 1–10) is complete with locally generated data.

```python
from mermaid import Mermaid

Mermaid("""
erDiagram
    trips ||--o{ zones : "PULocationID → LocationID"
    trips ||--o{ zones : "DOLocationID → LocationID"
    trips ||--o{ rate_codes : "RatecodeID"
    trips ||--o{ payment_types : "payment_type"

    trips {
        INTEGER VendorID
        TIMESTAMP tpep_pickup_datetime
        TIMESTAMP tpep_dropoff_datetime
        FLOAT passenger_count
        FLOAT trip_distance
        FLOAT RatecodeID FK
        INTEGER PULocationID FK
        INTEGER DOLocationID FK
        INTEGER payment_type FK
        FLOAT fare_amount
        FLOAT total_amount
    }

    zones {
        INTEGER LocationID PK
        TEXT Borough
        TEXT Zone
        TEXT service_zone
    }

    rate_codes {
        INTEGER RatecodeID PK
        TEXT rate_description
    }

    payment_types {
        INTEGER payment_type PK
        TEXT payment_description
    }
""")
```

### Download the Data

```python
import urllib.request

# 1 month of yellow taxi data (~3M rows, ~45 MB Parquet)
taxi_url = 'https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2024-01.parquet'
zones_url = 'https://d37ci6vzurychx.cloudfront.net/misc/taxi_zone_lookup.csv'

os.makedirs('taxi_data', exist_ok=True)

print("Downloading taxi trip data (~45 MB)...")
urllib.request.urlretrieve(taxi_url, 'taxi_data/trips.parquet')

print("Downloading zone lookup (~5 KB)...")
urllib.request.urlretrieve(zones_url, 'taxi_data/zones.csv')

trips_mb = os.path.getsize('taxi_data/trips.parquet') / 1e6
print(f"Done! Trips: {trips_mb:.1f} MB")
```

<details>
<summary>Expected Output</summary>

~~~text
Downloading taxi trip data (~45 MB)...
Downloading zone lookup (~5 KB)...
Done! Trips: 45.2 MB
~~~

</details>

### Create Dimension Tables

```python
# Zone lookup (downloaded CSV, 265 rows)
zones_df = pd.read_csv('taxi_data/zones.csv')
print(f"Zones: {len(zones_df)} rows")
print(zones_df.head())
```

```python
# Rate code lookup (manual, 6 rows)
rate_codes = pd.DataFrame({
    'RatecodeID': [1, 2, 3, 4, 5, 6],
    'rate_description': ['Standard rate', 'JFK', 'Newark',
                         'Nassau or Westchester', 'Negotiated fare', 'Group ride']
})

# Payment type lookup (manual, 6 rows)
payment_types = pd.DataFrame({
    'payment_type': [1, 2, 3, 4, 5, 6],
    'payment_description': ['Credit card', 'Cash', 'No charge',
                            'Dispute', 'Unknown', 'Voided trip']
})

print(f"Rate codes:    {len(rate_codes)} rows")
print(f"Payment types: {len(payment_types)} rows")
```

### Load into DuckDB

```python
# DuckDB loads Parquet and CSV natively
duckdb.sql("CREATE OR REPLACE TABLE trips AS SELECT * FROM 'taxi_data/trips.parquet'")
duckdb.sql("CREATE OR REPLACE TABLE zones AS SELECT * FROM 'taxi_data/zones.csv'")
duckdb.sql("CREATE OR REPLACE TABLE rate_codes AS SELECT * FROM rate_codes")
duckdb.sql("CREATE OR REPLACE TABLE payment_types AS SELECT * FROM payment_types")

trip_count = duckdb.sql("SELECT COUNT(*) FROM trips").fetchone()[0]
zone_count = duckdb.sql("SELECT COUNT(*) FROM zones").fetchone()[0]
print(f"DuckDB loaded: {trip_count:,} trips, {zone_count} zones")
```

<details>
<summary>Expected Output</summary>

~~~text
DuckDB loaded: ~2,900,000 trips, 265 zones
~~~

Post-pandemic months have ~3M rows. The exact count depends on the month downloaded.

</details>

### Load into PostgreSQL

```python
# Export trips to CSV for PostgreSQL COPY (DuckDB handles the Parquet → CSV conversion)
duckdb.sql("COPY trips TO 'taxi_data/trips.csv' (HEADER, DELIMITER ',')")
print("Exported trips to CSV")
```

```python
%%sql
DROP TABLE IF EXISTS trips;
DROP TABLE IF EXISTS zones;
DROP TABLE IF EXISTS rate_codes;
DROP TABLE IF EXISTS payment_types;

CREATE TABLE trips (
    VendorID              INTEGER,
    tpep_pickup_datetime  TIMESTAMP,
    tpep_dropoff_datetime TIMESTAMP,
    passenger_count       FLOAT,
    trip_distance         FLOAT,
    RatecodeID            FLOAT,
    store_and_fwd_flag    TEXT,
    PULocationID          INTEGER,
    DOLocationID          INTEGER,
    payment_type          INTEGER,
    fare_amount           FLOAT,
    extra                 FLOAT,
    mta_tax               FLOAT,
    tip_amount            FLOAT,
    tolls_amount          FLOAT,
    improvement_surcharge FLOAT,
    total_amount          FLOAT,
    congestion_surcharge  FLOAT,
    airport_fee           FLOAT
);

CREATE TABLE zones (
    LocationID   INTEGER PRIMARY KEY,
    Borough      TEXT,
    Zone         TEXT,
    service_zone TEXT
);

CREATE TABLE rate_codes (
    RatecodeID       INTEGER PRIMARY KEY,
    rate_description TEXT
);

CREATE TABLE payment_types (
    payment_type        INTEGER PRIMARY KEY,
    payment_description TEXT
);
```

**Note on column types:** The Parquet file uses FLOAT for columns like `passenger_count` and `RatecodeID` that look like integers. This is a real data quality issue — we use FLOAT in PostgreSQL to match. Real data is messy.

```python
# Load via COPY
print("Loading trips into PostgreSQL...")
start = time.perf_counter()
pg_conn = psycopg2.connect("dbname=benchmark_db user=postgres password=postgres host=localhost")
cur = pg_conn.cursor()
with open('taxi_data/trips.csv', 'r') as f:
    next(f)  # skip header
    cur.copy_expert("COPY trips FROM STDIN WITH (FORMAT csv)", f)
pg_conn.commit()
cur.close()
pg_conn.close()
pg_taxi_time = time.perf_counter() - start
print(f"Trips loaded in {pg_taxi_time:.1f}s")

# Load dimension tables (small — use psycopg2)
pg_conn = psycopg2.connect("dbname=benchmark_db user=postgres password=postgres host=localhost")
cur = pg_conn.cursor()

# Zones from CSV
import io
zones_df.to_csv('/tmp/zones.csv', index=False)
with open('/tmp/zones.csv', 'r') as f:
    next(f)  # skip header
    cur.copy_from(f, 'zones', sep=',', null='')
pg_conn.commit()

# Rate codes and payment types
for _, r in rate_codes.iterrows():
    cur.execute("INSERT INTO rate_codes VALUES (%s, %s)", (r['RatecodeID'], r['rate_description']))
for _, r in payment_types.iterrows():
    cur.execute("INSERT INTO payment_types VALUES (%s, %s)", (r['payment_type'], r['payment_description']))
pg_conn.commit()

cur.close()
pg_conn.close()
print("All dimension tables loaded")
```

```python
# Update statistics for the query planner
!sudo -u postgres psql -d benchmark_db -c "ANALYZE trips; ANALYZE zones;"
print("Statistics updated")
```

### Analytical Queries with JOINs

These queries join the fact table (trips) with dimension tables (zones, payment_types) — something impossible with the flat synthetic data.

```python
# Query 1: Revenue by Borough
q_borough = """
    SELECT z.Borough,
           COUNT(*) AS trips,
           ROUND(AVG(t.fare_amount)::numeric, 2) AS avg_fare,
           ROUND(SUM(t.total_amount)::numeric, 2) AS total_revenue
    FROM trips t
    JOIN zones z ON t.PULocationID = z.LocationID
    GROUP BY z.Borough
    ORDER BY trips DESC
"""
r_borough = benchmark_query(q_borough, "Revenue by Borough")
print(f"Revenue by Borough  →  PG: {r_borough['pg_seconds']}s  |  DuckDB: {r_borough['duck_seconds']}s  |  Speedup: {r_borough['speedup']}x")
```

<details>
<summary>Expected Output</summary>

~~~text
Revenue by Borough  →  PG: 1.5-3.0s  |  DuckDB: 0.05-0.15s  |  Speedup: 15-30x
~~~

</details>

```python
# Query 2: Busiest Pickup Zones (top 10)
q_zones = """
    SELECT z.Zone, z.Borough, COUNT(*) AS pickups
    FROM trips t
    JOIN zones z ON t.PULocationID = z.LocationID
    GROUP BY z.Zone, z.Borough
    ORDER BY pickups DESC
    LIMIT 10
"""
r_zones = benchmark_query(q_zones, "Top 10 Pickup Zones")
print(f"Top 10 Zones  →  PG: {r_zones['pg_seconds']}s  |  DuckDB: {r_zones['duck_seconds']}s  |  Speedup: {r_zones['speedup']}x")
```

```python
# Query 3: Revenue by Payment Type
q_payment = """
    SELECT pt.payment_description,
           COUNT(*) AS trips,
           ROUND(SUM(t.total_amount)::numeric, 2) AS total_revenue
    FROM trips t
    JOIN payment_types pt ON t.payment_type = pt.payment_type
    GROUP BY pt.payment_description
    ORDER BY total_revenue DESC
"""
r_payment = benchmark_query(q_payment, "Revenue by Payment Type")
print(f"Revenue by Payment  →  PG: {r_payment['pg_seconds']}s  |  DuckDB: {r_payment['duck_seconds']}s  |  Speedup: {r_payment['speedup']}x")
```

These queries demonstrate the **star schema pattern** used in data warehouses: a large fact table (trips) joined with small dimension tables (zones, payment types) to produce human-readable analytical results.

### Join Order & Filter Placement

Now let's examine how filter placement affects query plans. Use `EXPLAIN ANALYZE` to see what PostgreSQL does under the hood.

#### Late Filtering vs Early Filtering

```python
%%sql
-- Late filtering: join everything, then filter on Borough
EXPLAIN ANALYZE
SELECT t.fare_amount, z.Borough, z.Zone
FROM trips t
JOIN zones z ON t.PULocationID = z.LocationID
WHERE z.Borough = 'Manhattan';
```

```python
%%sql
-- Early filtering: reduce the dimension table first
EXPLAIN ANALYZE
SELECT t.fare_amount, mz.Borough, mz.Zone
FROM trips t
JOIN (SELECT * FROM zones WHERE Borough = 'Manhattan') mz
  ON t.PULocationID = mz.LocationID;
```

<details>
<summary>What to Look For</summary>

Compare both EXPLAIN ANALYZE plans. If they're identical — and they often are — that means PostgreSQL's optimizer pushed the `Borough = 'Manhattan'` predicate down into the join automatically. The optimizer rewrites your SQL. This is called **predicate pushdown**, and it's one reason why writing "optimized" SQL by hand often doesn't help — the database is already doing it.

</details>

#### Pre-Filtering the Fact Table

```python
%%sql
-- No pre-filtering: join all trips, then filter on fare
EXPLAIN ANALYZE
SELECT z.Borough, COUNT(*), ROUND(AVG(t.fare_amount)::numeric, 2)
FROM trips t
JOIN zones z ON t.PULocationID = z.LocationID
WHERE t.fare_amount > 100
GROUP BY z.Borough;
```

```python
%%sql
-- Pre-filter with CTE: reduce the fact table before joining
EXPLAIN ANALYZE
WITH expensive_trips AS (
    SELECT PULocationID, fare_amount
    FROM trips
    WHERE fare_amount > 100
)
SELECT z.Borough, COUNT(*), ROUND(AVG(et.fare_amount)::numeric, 2)
FROM expensive_trips et
JOIN zones z ON et.PULocationID = z.LocationID
GROUP BY z.Borough;
```

<details>
<summary>What to Look For</summary>

This case is more likely to show a real difference. The CTE explicitly projects only 2 columns and filters first, reducing the data flowing into the join. Compare:
- The `rows=` estimates in both plans
- The actual execution times
- Whether the optimizer applies the filter before or after the join

Even if both plans end up similar, the exercise teaches you to read join plans and understand predicate pushdown — a critical skill for diagnosing slow queries in production.

</details>

---

## Summary

In this lab, you have successfully:

1. ✅ Generated and loaded a 5M-row dataset into both PostgreSQL and DuckDB
2. ✅ Built a benchmarking framework with warm-up and median timing
3. ✅ Benchmarked 6 analytical queries across both engines
4. ✅ Visualized performance differences (10–50x DuckDB speedup on analytics)
5. ✅ Analyzed PostgreSQL EXPLAIN plans to understand *why* it's slower
6. ✅ Compared DuckDB's query plans side by side — column pruning and vectorized execution made visible
7. ✅ Demonstrated PostgreSQL's advantage on point lookups (Index Scan)
8. ✅ Ran a multi-scale benchmark to see how speedup ratios grow with data size
9. ✅ Drew actionable conclusions about engine selection
10. ✅ (Additional Activity) Worked with real NYC Taxi data — joins, star schema, filter placement

**Key Takeaways:**

- **Column stores dominate analytical workloads** — they read less data, compress better, and process in vectorized batches
- **Row stores dominate transactional workloads** — they locate and modify individual rows efficiently via indexes
- **EXPLAIN ANALYZE is your debugging superpower** — it reveals exactly where execution time is spent, in both PostgreSQL *and* DuckDB
- **The speedup grows with scale** — differences barely visible at 50K rows become 30x+ at 5M rows
- **Join order and filter placement matter** — but the optimizer often rewrites your SQL via predicate pushdown
- **No single engine is best for everything** — production systems often pair PostgreSQL (app database) with DuckDB or BigQuery (analytics)
- **Fair benchmarking requires methodology** — same data, same queries, warm cache, median timing, multiple scales

**Module 2 Complete!** You've progressed from basic SQL (Week 4) through analytical SQL (Weeks 5–7) to performance benchmarking (Week 8). Next: Module 3 introduces NoSQL databases for data that doesn't fit neatly into rows and columns.
