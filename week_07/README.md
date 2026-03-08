# Week 07: Window Functions & CTEs

## Overview

This week marks the transition from **collapsing rows** (GROUP BY) to **computing across rows without collapsing them** (window functions). In Lesson 12, you learned to compress 50,000 orders into 6 regional totals. That's powerful — but what if you need each row to keep its identity while also showing its rank, running total, or percentage of the group? That's exactly what window functions do.

The second half of the week introduces **Common Table Expressions (CTEs)** and **offset functions** (LEAD/LAG) for composable, multi-step analytics. Together, window functions and CTEs unlock the most common patterns in analytical SQL: rankings, year-over-year growth, moving averages, and executive dashboards — all without leaving SQL.

---

## Lesson 13: Window Functions

### Learning Objectives

- Explain the OVER clause and how it defines a "window" of rows for computation
- Use PARTITION BY and ORDER BY within OVER to control grouping and sequencing
- Apply RANK, DENSE_RANK, and ROW_NUMBER to produce rankings
- Distinguish between ranking functions and explain when to use each
- Compute running totals and running averages using SUM/AVG with OVER

### Materials

**Concept Notes:**
- [Window Functions](w07_l13_concept_window_functions.md)

**Lab Exercise:**
- [Ranking Problems with Window Functions](w07_l13_lab_ranking_problems.md)

### Interactive Notebook

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/devomh/comp4098-2026/blob/main/week_07/w07_l13_lab_ranking_problems.ipynb)

---

## Lesson 14: CTEs & Advanced Analytics

### Learning Objectives

- Write Common Table Expressions (CTEs) using the WITH clause
- Chain multiple CTEs into readable, multi-step analytical pipelines
- Use LEAD and LAG to access previous and next rows without self-joins
- Calculate year-over-year (YoY) growth using LAG with chained CTEs
- Combine CTEs with window functions for moving averages and trend analysis

### Materials

**Concept Notes:**
- [CTEs & Advanced Analytics](w07_l14_concept_ctes_advanced.md)

**Lab Exercise:**
- [Year-Over-Year Growth & Moving Averages](w07_l14_lab_yoy_growth.md)

### Interactive Notebook

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/devomh/comp4098-2026/blob/main/week_07/w07_l14_lab_yoy_growth.ipynb)

---

## Key Concepts

### Window Functions
- **OVER Clause** — Defines the "window" of rows a function operates on; every window function requires OVER
- **PARTITION BY** — Divides rows into groups (like GROUP BY) but keeps every row in the output
- **ORDER BY (in OVER)** — Controls the sequence of rows within each partition for ranking and running calculations
- **RANK / DENSE_RANK / ROW_NUMBER** — Three ranking functions with different tie-handling behavior
- **Running Aggregates** — SUM, AVG, COUNT with OVER(ORDER BY) for cumulative calculations

### CTEs (Common Table Expressions)
- **WITH Clause** — Creates a temporary named result set that exists for the duration of one query
- **Chained CTEs** — Multiple CTEs separated by commas, forming a readable data pipeline
- **Forward Reference Only** — Each CTE can reference CTEs defined before it, never after

### Offset Functions
- **LAG(column, N)** — Access the value N rows *before* the current row
- **LEAD(column, N)** — Access the value N rows *after* the current row
- **YoY Pattern** — LAG(value, 12) compares each month to the same month in the prior year

---

## Connection from Previous Weeks

### Week 06 → Week 07: From Aggregation to Analytics
- **Week 06:** Mastered JOINs (assemble data) and GROUP BY (collapse rows into summaries)
- **Week 07:** Window functions preserve every row while adding computed columns — rankings, running totals, row comparisons
- **Key Connection:** PARTITION BY uses the same grouping intuition as GROUP BY, but the output keeps all rows instead of collapsing them

### Week 07 → Week 08: From Analytics to Performance
- **Week 07:** Built complex analytical queries with window functions, CTEs, and offset functions
- **Week 08 Preview:** Benchmark PostgreSQL vs. DuckDB on these same analytical patterns
- **Key Connection:** The queries you write this week become the test cases for comparing OLTP vs. OLAP engine performance

---

## Practical Applications for Data Scientists

### Why Window Functions Matter
1. **Rankings without losing detail** — Show each product's rank within its category while keeping all product-level data visible
2. **Running totals and cumulative metrics** — Track cumulative revenue, user growth, or inventory levels over time
3. **Percentage of total** — Calculate each row's contribution to its group without a separate query

### Why CTEs Matter
1. **Readable multi-step analytics** — Break complex queries into named, testable steps instead of deeply nested subqueries
2. **Year-over-year and period comparisons** — LAG/LEAD with CTEs is the standard pattern for time-series analysis in SQL
3. **Dashboard queries** — Combine multiple metrics (revenue, growth, rank, moving average) in one composable query

### The Advanced Analytical SQL Pattern
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
```

---

## Additional Resources

### Documentation
- [DuckDB Window Functions](https://duckdb.org/docs/sql/window_functions) — Complete window function reference including frame clauses
- [DuckDB Common Table Expressions](https://duckdb.org/docs/sql/query_syntax/with.html) — CTE syntax and examples

### Textbook
- **Database Design - 2nd Edition** by Adrienne Watt
  - [Chapter 9: SQL Queries](https://opentextbc.ca/dbdesign01/chapter/chapter-9-sql-queries/) — Foundational SQL patterns

### Articles
- [PostgreSQL Window Function Tutorial](https://www.postgresql.org/docs/current/tutorial-window.html) — Official PostgreSQL guide (syntax transfers to DuckDB)
- [SQL Window Functions — Mode Analytics](https://mode.com/sql-tutorial/sql-window-functions/) — Interactive tutorial with visual explanations

---

## Questions or Issues?

If you encounter problems with:
- **Window function errors** — Ensure OVER() is present; window functions cannot appear in WHERE clauses
- **Ranking ties** — Use RANK (gaps after ties), DENSE_RANK (no gaps), or ROW_NUMBER (arbitrary tiebreak) depending on your need
- **CTE reference errors** — CTEs can only reference CTEs defined *before* them in the WITH clause
- **LAG/LEAD returning NULL** — The first/last rows have no previous/next values; use the third argument for a default value
