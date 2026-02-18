# Week 05: Analytical Architectures

## Overview

This week marks the transition from **transactional databases** (OLTP) to **analytical engines** (OLAP). You'll learn why the PostgreSQL database you built in Week 04 — while excellent for capturing and managing data — is not the optimal tool for large-scale analysis. You'll explore the architectural principles behind column-oriented storage and meet DuckDB, an in-process OLAP engine designed for the data science workflow.

By the end of this week, you'll understand how row-oriented and column-oriented storage differ at the physical level, why columnar compression and vectorized execution make analytical queries orders of magnitude faster, and how to use DuckDB to query CSV and Parquet files directly with SQL — no server required.

---

## Lesson 09: OLTP vs. OLAP

### Learning Objectives

- Distinguish between OLTP and OLAP workloads and explain when each is appropriate
- Compare row-oriented and column-oriented storage layouts at the physical level
- Explain how columnar compression techniques (RLE, Dictionary Encoding) reduce storage and accelerate queries
- Describe how vectorized execution achieves higher throughput than row-at-a-time processing
- Justify why data scientists need both PostgreSQL (OLTP) and DuckDB (OLAP) in their toolkit

### Materials

**Concept Notes:**
- [OLTP vs. OLAP: Analytical Architectures](w05_l09_concept_oltp_vs_olap.md)

**Lab Exercise:**
- [Comparing Storage Layouts](w05_l09_lab_storage_comparison.md)

### Interactive Notebook

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/devomh/comp4098-2026/blob/main/week_05/w05_l09_lab_storage_comparison.ipynb)

*Note: Replace `USERNAME` with your GitHub username once the repository is set up.*

---

## Lesson 10: Introduction to DuckDB

### Learning Objectives

- Explain DuckDB's in-process architecture and how it differs from PostgreSQL's client-server model
- Read and query data directly from CSV and Parquet files using DuckDB SQL
- Compare Parquet and CSV file formats in terms of performance, compression, and schema enforcement
- Write analytical SQL queries in DuckDB and understand its relationship to PostgreSQL syntax
- Describe when to use DuckDB vs. PostgreSQL in a data science workflow

### Materials

**Concept Notes:**
- [Introduction to DuckDB](w05_l10_concept_intro_duckdb.md)

**Lab Exercise:**
- [Querying Local Files with DuckDB](w05_l10_lab_duckdb_querying.md)

### Interactive Notebook

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/devomh/comp4098-2026/blob/main/week_05/w05_l10_lab_duckdb_querying.ipynb)

*Note: Replace `USERNAME` with your GitHub username once the repository is set up.*

---

## Key Concepts

### OLTP vs. OLAP
- **OLTP (Online Transaction Processing)** — Many small read/write operations (INSERT, UPDATE, DELETE); PostgreSQL
- **OLAP (Online Analytical Processing)** — Few large read-heavy operations (aggregations, scans); DuckDB
- **Row-Oriented Storage** — All columns of a row stored together; fast for single-row access
- **Column-Oriented Storage** — All values of a column stored together; fast for analytical scans

### Columnar Advantages
- **Column Pruning** — Read only the columns needed by the query, skip the rest
- **Compression** — Run-Length Encoding, Dictionary Encoding, Bit Packing reduce storage 5-100x
- **Vectorized Execution** — Process batches of ~2,048 values instead of one row at a time
- **SIMD** — Modern CPUs can process 4-8 values in a single instruction

### DuckDB
- **In-Process Architecture** — Runs inside your Python process, no server needed
- **File Querying** — `SELECT * FROM 'file.csv'` queries files directly
- **Parquet Support** — Native columnar file format with compression and schema
- **PostgreSQL-Compatible SQL** — Same syntax you learned in Week 04
- **Pandas Integration** — Query DataFrames with SQL using `duckdb.sql("SELECT * FROM df")`

### File Formats
- **CSV** — Human-readable, no schema, no compression, universal compatibility
- **Parquet** — Binary columnar format, embedded schema, built-in compression, 3-10x smaller than CSV

---

## Connection from Previous Weeks

### Week 04 → Week 05: From OLTP to OLAP
- **Week 04:** Built a PostgreSQL database for OLTP — INSERT, UPDATE, DELETE on individual records
- **Week 05:** Learned why OLTP databases struggle with analytical queries and how OLAP engines solve this
- **Key Connection:** Data is captured in OLTP (PostgreSQL), then extracted and analyzed in OLAP (DuckDB)

### Week 05 → Week 06: From Architecture to Queries
- **Week 05:** Understood the architectural foundations (storage layouts, compression, vectorization)
- **Week 06 Preview:** Apply these foundations to complex analytical SQL — JOINs, aggregations, GROUP BY
- **Key Connection:** DuckDB's columnar engine makes the advanced SQL techniques in Weeks 06-07 practical on large datasets

---

## Practical Applications for Data Scientists

### Why Storage Architecture Matters
1. **Choosing the right tool** — Use PostgreSQL for transactional workloads, DuckDB for analytical workloads
2. **Understanding performance** — Know why `SELECT AVG(gpa)` is fast in DuckDB but slow in PostgreSQL
3. **File format decisions** — Use Parquet for analytical pipelines, CSV for data exchange with non-technical users

### Why DuckDB Matters
1. **No infrastructure needed** — `pip install duckdb` and you're ready for analytics
2. **SQL on files** — Query CSV/Parquet files without loading into a database
3. **Faster than Pandas** — DuckDB outperforms Pandas for aggregations, JOINs, and window functions
4. **Notebook-friendly** — Perfect for Google Colab and Jupyter workflows

### Real-World Workflow
```
Production App → PostgreSQL (OLTP)
                      ↓ (ETL / Export)
                CSV / Parquet files
                      ↓
                DuckDB (OLAP) ← You are here
                      ↓
                Pandas / Matplotlib
                      ↓
                Insights & Models
```

---

## Additional Resources

### Documentation
- [DuckDB Documentation](https://duckdb.org/docs/) — Official reference
- [DuckDB Python API](https://duckdb.org/docs/api/python/overview) — Python integration
- [Apache Parquet](https://parquet.apache.org/docs/overview/) — Parquet format specification

### Textbook
- **Database Design - 2nd Edition** by Adrienne Watt
  - [Chapter 13: Database Development](https://opentextbc.ca/dbdesign01/chapter/chapter-13-database-development/)

### Articles
- [DuckDB: Why DuckDB?](https://duckdb.org/why_duckdb) — Design philosophy
- [DuckDB vs. Pandas Performance](https://duckdb.org/2021/05/14/sql-on-pandas.html) — Benchmark comparison
- [Column-Oriented Databases (CMU)](https://15721.courses.cs.cmu.edu/spring2024/slides/03-storage1.pdf) — Academic overview

---

## Lab Requirements

### Prerequisites
- Google Colab account (free)
- No database server needed — DuckDB runs in-process

### Software Packages
All labs use the following Python packages (installed automatically in notebooks):
- `duckdb` — In-process OLAP engine
- `pandas` — Data analysis
- `mermaid-py` — Diagram generation

---

## Questions or Issues?

If you encounter problems with:
- **DuckDB installation** — Ensure `pip install duckdb` completes successfully
- **File not found errors** — Verify file paths match your working directory
- **CSV parsing issues** — Check delimiter and header settings
- **Parquet read errors** — Ensure files were written with a compatible library (Pandas, pyarrow)

For additional help, refer to the troubleshooting sections in each lab file.
