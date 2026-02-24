# Week 06: Joins & Aggregation

## Overview

This week builds on the DuckDB foundation from Week 05 and dives into the two most essential analytical SQL skills: **joins** and **aggregation**. You'll learn how to reassemble normalized data by joining multiple tables, then compress those rows into meaningful summaries with GROUP BY and aggregate functions.

By the end of this week, you'll be able to write multi-table joins (INNER, LEFT, RIGHT, FULL OUTER), spot common join pitfalls, and produce management-ready summary reports using COUNT, SUM, AVG, MIN, MAX, GROUP BY, and HAVING.

---

## Lesson 11: Complex Joins

### Learning Objectives

- Distinguish between INNER, LEFT, RIGHT, and FULL OUTER joins and explain when to use each
- Write multi-table joins that chain three or more tables together
- Identify NULL rows produced by outer joins and explain why they appear
- Avoid common join pitfalls such as Cartesian products and duplicate rows
- Choose the correct join type to answer a given analytical question

### Materials

**Concept Notes:**
- [Complex Joins](w06_l11_concept_complex_joins.md)

**Lab Exercise:**
- [Multi-Table Queries with Joins](w06_l11_lab_multi_table_queries.md)

### Interactive Notebook

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/devomh/comp4098-2026/blob/main/week_06/w06_l11_lab_multi_table_queries.ipynb)

---

## Lesson 12: Aggregation & Grouping

### Learning Objectives

- Use the five core aggregate functions: COUNT, SUM, AVG, MIN, MAX
- Explain GROUP BY semantics — how rows are partitioned and aggregated
- Filter groups with HAVING and distinguish it from WHERE
- Write multi-level GROUP BY queries with two or more grouping columns
- Combine JOINs with GROUP BY to produce summary reports from multiple tables

### Materials

**Concept Notes:**
- [Aggregation & Grouping](w06_l12_concept_aggregation_grouping.md)

**Lab Exercise:**
- [Summary Reports with Aggregation](w06_l12_lab_summary_reports.md)

### Interactive Notebook

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/devomh/comp4098-2026/blob/main/week_06/w06_l12_lab_summary_reports.ipynb)

---

## Key Concepts

### Joins
- **INNER JOIN** — Returns only rows with matches in both tables
- **LEFT JOIN** — Preserves all left-side rows; NULLs for unmatched right-side columns
- **RIGHT JOIN** — Mirror of LEFT JOIN; preserves all right-side rows
- **FULL OUTER JOIN** — Preserves all rows from both tables; NULLs on either side for unmatched rows
- **LEFT JOIN + IS NULL** — The standard "find missing" pattern

### Join Pitfalls
- **Cartesian Product** — Missing ON clause creates every possible row combination
- **Duplicate Rows** — One-to-many joins repeat the "one" side; use COUNT(DISTINCT ...) to count correctly
- **NULL Join Keys** — NULL never matches in a join condition; rows with NULL keys are silently excluded
- **Downstream INNER Cancels LEFT** — An INNER JOIN after a LEFT JOIN drops the NULL rows the LEFT JOIN preserved

### Aggregation
- **Aggregate Functions** — COUNT, SUM, AVG, MIN, MAX collapse many rows into one value
- **GROUP BY** — Partitions rows into groups; each group produces one output row
- **HAVING** — Filters groups after aggregation (WHERE filters rows before aggregation)
- **Multi-Level GROUP BY** — Group by two or more columns for finer-grained summaries
- **JOIN → GROUP BY → HAVING** — The core analytical SQL pattern for summary reports

---

## Connection from Previous Weeks

### Week 05 → Week 06: From Architecture to Queries
- **Week 05:** Understood OLTP vs. OLAP, columnar storage, and met DuckDB
- **Week 06:** Apply DuckDB to complex analytical queries — joins across multiple tables and aggregated reports
- **Key Connection:** DuckDB's columnar engine and hash joins make multi-table analytics practical on large datasets

### Week 06 → Week 07: From Aggregation to Advanced Analytics
- **Week 06:** Mastered joins and GROUP BY for summary reports
- **Week 07 Preview:** Window functions (analytics without collapsing rows) and CTEs (readable, composable queries)
- **Key Connection:** Window functions build on GROUP BY intuition — same partitioning concept, but each row keeps its identity

---

## Practical Applications for Data Scientists

### Why Joins Matter
1. **Data is always normalized** — Customer names, order details, and product info live in separate tables
2. **LEFT JOIN preserves completeness** — The most common join in analytics; never silently drops rows
3. **Multi-table joins are the norm** — Real-world queries routinely chain 3-5 tables together

### Why Aggregation Matters
1. **Insights are aggregates** — Nobody reads 50,000 rows; they want totals, averages, and rankings
2. **GROUP BY powers dashboards** — Revenue by region, orders by month, top customers — all GROUP BY queries
3. **HAVING filters the signal** — Find only categories above a threshold, customers with repeat purchases, etc.

### The Analytical SQL Pattern
```
Raw Tables (normalized)
        ↓ (JOINs)
Combined Detail Rows
        ↓ (GROUP BY + aggregates)
Summary Report
        ↓ (HAVING)
Filtered Insights
```

---

## Additional Resources

### Documentation
- [DuckDB JOIN Documentation](https://duckdb.org/docs/sql/query_syntax/from.html#joins) — Join syntax and DuckDB-specific behavior
- [DuckDB Aggregates](https://duckdb.org/docs/sql/aggregates) — Complete aggregate function reference

### Textbook
- **Database Design - 2nd Edition** by Adrienne Watt
  - [Chapter 9: SQL Joins](https://opentextbc.ca/dbdesign01/chapter/chapter-9-sql-joins/)

### Articles
- [Visual Representation of SQL Joins](https://www.codeproject.com/Articles/33052/Visual-Representation-of-SQL-Joins) — Classic visual guide using Venn-style diagrams
- [PostgreSQL JOIN Tutorial](https://www.postgresql.org/docs/current/tutorial-join.html) — Official PostgreSQL guide (syntax transfers to DuckDB)

---

## Questions or Issues?

If you encounter problems with:
- **DuckDB queries** — Ensure tables are created before querying (run setup cells first)
- **Unexpected row counts** — Check your ON clause and join type; use COUNT(DISTINCT ...) after one-to-many joins
- **NULL values in results** — Outer joins produce NULLs for unmatched rows; use COALESCE to handle them
- **HAVING errors** — Remember: HAVING filters groups (after GROUP BY), WHERE filters rows (before GROUP BY)
