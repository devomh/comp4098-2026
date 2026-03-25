# Week 08: Performance Benchmarking

## Overview

This week is the capstone of **Module 2: Analytical SQL & Architecture**. You've spent Weeks 5–7 learning analytical SQL techniques — aggregations, window functions, CTEs, and offset functions. Now you'll put them to the test at scale.

The central question: **Does the choice of database engine matter?** You'll generate a 5-million-row dataset, load it into both PostgreSQL (row-oriented) and DuckDB (column-oriented), and run the same analytical queries on both. The results will demonstrate — empirically — why column-oriented engines dominate analytical workloads.

---

## Lesson 15: Data at Scale — Generation & Loading

### Learning Objectives

- Explain why query behavior changes at scale (thousands vs millions of rows)
- Compare data generation strategies (loops vs NumPy vectorization)
- Distinguish loading methods (INSERT, batch INSERT, COPY, Parquet ingestion)
- Compare CSV and Parquet storage formats for analytical workloads

### Materials

**Concept Notes:**
- [Data at Scale: Generation & Loading Strategies](w08_l15_concept_data_at_scale.md)

**Lab Exercise:**
- [Generating & Loading Large Datasets](w08_l15_lab_dataset_preparation.md)

### Interactive Notebook

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/devomh/comp4098-2026/blob/main/week_08/w08_l15_lab_dataset_preparation.ipynb)

---

## Lesson 16: The Performance Benchmark

### Learning Objectives

- Interpret PostgreSQL EXPLAIN and EXPLAIN ANALYZE output
- Identify common query plan operations (Seq Scan, Index Scan, Hash Aggregate)
- Explain why column stores outperform row stores for analytical queries
- Design a fair benchmark with proper methodology (warm-up, multiple runs, median)

### Materials

**Concept Notes:**
- [Query Plans & Performance Benchmarking](w08_l16_concept_query_performance.md)

**Lab Exercise:**
- [PostgreSQL vs DuckDB — The Performance Benchmark](w08_l16_lab_performance_benchmark.md)

### Interactive Notebook

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/devomh/comp4098-2026/blob/main/week_08/w08_l16_lab_performance_benchmark.ipynb)

---

## Key Concepts

### Data at Scale
- **Vectorized generation** — NumPy generates millions of rows in seconds vs minutes for Python loops
- **COPY command** — PostgreSQL's bulk loader bypasses the SQL parser for maximum speed
- **Parquet format** — Column-oriented, compressed binary files; 4–6x smaller than CSV
- **Format-engine match** — CSV → PostgreSQL (via COPY); Parquet → DuckDB (native read)

### Query Performance
- **EXPLAIN** — Shows the query plan without execution (estimated costs and row counts)
- **EXPLAIN ANALYZE** — Shows the plan AND actual execution metrics (real times)
- **Seq Scan** — Full table scan; reads every row — used when no helpful index exists
- **Index Scan** — Uses B-tree index for fast single-row lookup
- **HashAggregate** — Groups results using an in-memory hash table

### Engine Comparison
- **PostgreSQL (OLTP)** — Row-oriented; excels at transactions, lookups, concurrent access
- **DuckDB (OLAP)** — Column-oriented; excels at aggregations, analytics, batch processing
- **Column pruning** — Column stores read only the columns needed by the query
- **Vectorized execution** — Process batches of 2,048 values instead of one row at a time

---

## Connection from Previous Weeks

### Week 07 → Week 08: From Analytics to Performance
- **Week 07:** Built complex analytical queries with window functions, CTEs, and offset functions
- **Week 08:** Run those same query patterns against 5M rows on two different engines
- **Key Connection:** The queries you wrote in Weeks 6–7 become the benchmark test cases

### Week 08 → Week 09: From SQL to NoSQL
- **Week 08:** Concluded Module 2 with a clear picture of when row vs column stores excel
- **Week 09 Preview:** Module 3 introduces data that doesn't fit tables at all — documents, key-value pairs
- **Key Connection:** Understanding storage architecture trade-offs (this week) prepares you to evaluate NoSQL trade-offs (CAP theorem)

---

## Practical Applications for Data Scientists

### Why Performance Benchmarking Matters
1. **Engine selection** — Choose PostgreSQL for your web app's database, DuckDB for your analytics pipeline
2. **Query optimization** — EXPLAIN ANALYZE shows exactly where time is spent, guiding optimization efforts
3. **Capacity planning** — Understanding how queries scale helps predict infrastructure needs

### The Module 2 Analytical SQL Pattern (Complete)
```
Raw Tables (normalized)
        ↓ (JOINs — Week 06)
Combined Detail Rows
        ↓ (GROUP BY — Week 06)
Summary by Period/Category
        ↓ (Window Functions — Week 07)
Rankings + Running Totals + Comparisons
        ↓ (CTEs — Week 07)
Composable Multi-Step Pipelines
        ↓ (Benchmarking — Week 08)
Right Engine for the Right Workload
```

---

## Additional Resources

### Documentation
- [PostgreSQL: Using EXPLAIN](https://www.postgresql.org/docs/current/using-explain.html) — Official guide to reading query plans
- [PostgreSQL: COPY](https://www.postgresql.org/docs/current/sql-copy.html) — Bulk loading reference
- [DuckDB: Why DuckDB?](https://duckdb.org/why_duckdb.html) — Architectural advantages explained

### Articles
- [Use The Index, Luke](https://use-the-index-luke.com/) — The definitive guide to database performance
- [Fastest Way to Load Data into PostgreSQL — Haki Benita](https://hakibenita.com/fast-load-data-python-postgresql) — INSERT vs COPY benchmarks

---

## Questions or Issues?

If you encounter problems with:
- **PostgreSQL not starting** — Run `!service postgresql start` and verify with `!service postgresql status`
- **Out of memory** — Switch to the Quick Test scale (100K rows) instead of 5M
- **COPY permission errors** — Use `\COPY` (with backslash) via `psql` instead of plain `COPY`
- **DuckDB version issues** — Run `!pip install -q duckdb --upgrade` to get the latest version
- **Slow generation** — Ensure you're using the NumPy vectorized approach, not Python loops
