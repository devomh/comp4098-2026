---
title: "Lab: Year-Over-Year Growth & Moving Averages"
week: 07
type: lab
tags: [sql, duckdb, cte, lead, lag, time-series, analytics, python]
difficulty: intermediate
duration: "60 mins"
---

# Lab: Year-Over-Year Growth & Moving Averages

## Prerequisites & Setup

**Before starting this lab, you should:**
- Review [w07_l14_concept_ctes_advanced.md](w07_l14_concept_ctes_advanced.md) for CTE and LEAD/LAG concepts
- Have completed [Lesson 13 Lab](w07_l13_lab_ranking_problems.md) for window function practice
- Understand CTEs, chaining, LEAD/LAG, and frame clauses

**What you'll accomplish:**
In this lab, you'll build a complete time-series analytics pipeline: monthly revenue trends, month-over-month change, year-over-year growth, moving averages, category-level analysis, and an executive dashboard — all using CTEs and offset functions.

**Goal:** Master CTEs + LEAD/LAG for time-series analytics and multi-step query composition.

---

## Environment Setup

Run this setup block first to install required packages.

```python
# Setup: Run this cell first (required for Colab)
!pip install -q duckdb pandas mermaid-py matplotlib
```

```python
import duckdb
import pandas as pd
import matplotlib.pyplot as plt
import random
import os
from datetime import date, timedelta

# Display settings
pd.set_option('display.max_columns', None)
pd.set_option('display.max_rows', 30)

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

## The Scenario

You're the data analyst at **ShopStream**. The VP of Finance is preparing a quarterly board review and needs: monthly revenue trends with year-over-year comparisons, moving averages to smooth seasonal noise, and category-level growth analysis. Everything needs to be in clean, composable SQL that can be turned into a recurring report.

---

## Step 1: Generate & Load the Dataset

Same e-commerce dataset as Lessons 11–13 (self-contained for Colab).

```python
random.seed(42)

# ── Dataset Size Configuration ──────────────────────
# Uncomment one block at a time, then re-run this cell.

# --- Full dataset (original) ---
# N_CUSTOMERS        = 5_000
# N_ACTIVE_CUSTOMERS = 4_500   # customers that actually place orders
# N_PRODUCTS         = 200
# N_ORDERS           = 50_000
# REGIONS    = ['Northeast', 'Southeast', 'Midwest', 'West', 'Southwest', 'Northwest']
# CATEGORIES = ['Electronics', 'Clothing', 'Books', 'Home & Kitchen', 'Sports', 'Toys']
# CITIES = {
#     'Northeast': ['New York', 'Boston', 'Philadelphia', 'Hartford'],
#     'Southeast': ['Miami', 'Atlanta', 'Charlotte', 'Orlando'],
#     'Midwest':   ['Chicago', 'Detroit', 'Minneapolis', 'Columbus'],
#     'West':      ['Los Angeles', 'San Francisco', 'San Diego', 'Portland'],
#     'Southwest': ['Houston', 'Dallas', 'Phoenix', 'San Antonio'],
#     'Northwest': ['Seattle', 'Boise', 'Spokane', 'Eugene'],
# }

# --- Toy dataset (use this to trace examples by hand) ---
N_CUSTOMERS        = 10
N_ACTIVE_CUSTOMERS = 4   # customers that actually place orders
N_PRODUCTS         = 20
N_ORDERS           = 100
REGIONS    = ['Northeast', 'Southeast']
CATEGORIES = ['Electronics', 'Clothing']
CITIES = {
    'Northeast': ['New York', 'Boston', 'Philadelphia', 'Hartford'],
    'Southeast': ['Miami', 'Atlanta', 'Charlotte', 'Orlando'],
}
```

```python
# --- Customers ---
customers = []
for i in range(1, N_CUSTOMERS + 1):
    region = random.choice(REGIONS)
    city = random.choice(CITIES[region])
    signup = date(2021, 1, 1) + timedelta(days=random.randint(0, 1460))
    customers.append({
        'id': i,
        'name': f"Customer_{i}",
        'city': city,
        'region': region,
        'signup_date': signup,
    })

# --- Products ---
products = []
for i in range(1, N_PRODUCTS + 1):
    cat = CATEGORIES[(i - 1) % len(CATEGORIES)]
    price = round(random.uniform(5.0, 500.0), 2)
    products.append({
        'id': i,
        'name': f"Product_{i}",
        'category': cat,
        'price': price,
    })

# --- Orders ---
ordering_customers = random.sample(range(1, N_CUSTOMERS + 1), N_ACTIVE_CUSTOMERS)
statuses = ['completed', 'completed', 'completed', 'completed',
            'pending', 'cancelled']

orders = []
for i in range(1, N_ORDERS + 1):
    cust_id = random.choice(ordering_customers)
    order_date = date(2023, 1, 1) + timedelta(days=random.randint(0, 730))
    status = random.choice(statuses)
    orders.append({
        'id': i,
        'customer_id': cust_id,
        'order_date': order_date,
        'status': status,
    })

# --- Order Items ---
order_items = []
item_id = 1
for order in orders:
    num_items = random.randint(1, min(5, N_PRODUCTS))
    chosen_products = random.sample(range(1, N_PRODUCTS + 1), num_items)
    for prod_id in chosen_products:
        prod = products[prod_id - 1]
        qty = random.randint(1, 4)
        order_items.append({
            'id': item_id,
            'order_id': order['id'],
            'product_id': prod_id,
            'quantity': qty,
            'unit_price': prod['price'],
        })
        item_id += 1

# Save as Parquet
os.makedirs('ecommerce', exist_ok=True)
pd.DataFrame(customers).to_parquet('ecommerce/customers.parquet', index=False)
pd.DataFrame(products).to_parquet('ecommerce/products.parquet', index=False)
pd.DataFrame(orders).to_parquet('ecommerce/orders.parquet', index=False)
pd.DataFrame(order_items).to_parquet('ecommerce/order_items.parquet', index=False)

# Load into DuckDB
duckdb.sql("CREATE OR REPLACE TABLE customers AS SELECT * FROM 'ecommerce/customers.parquet'")
duckdb.sql("CREATE OR REPLACE TABLE products AS SELECT * FROM 'ecommerce/products.parquet'")
duckdb.sql("CREATE OR REPLACE TABLE orders AS SELECT * FROM 'ecommerce/orders.parquet'")
duckdb.sql("CREATE OR REPLACE TABLE order_items AS SELECT * FROM 'ecommerce/order_items.parquet'")

print(f"customers:   {len(customers):>7,} rows")
print(f"products:    {len(products):>7,} rows")
print(f"orders:      {len(orders):>7,} rows")
print(f"order_items: {len(order_items):>7,} rows")
print("\nDataset loaded into DuckDB!")
```

<details>
<summary>Expected Output</summary>

~~~text
customers:     5,000 rows
products:        200 rows
orders:       50,000 rows
order_items: 149,912 rows

Dataset loaded into DuckDB!
~~~

</details>

---

## Step 2: Monthly Revenue CTE

Start with the foundation: a CTE that aggregates revenue by month. This produces 24 rows (Jan 2023 through Dec 2024) — the building block for all subsequent analysis.

```python
result = duckdb.sql("""
    WITH monthly_revenue AS (
        SELECT
            DATE_TRUNC('month', o.order_date) AS month,
            COUNT(DISTINCT o.id) AS order_count,
            ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue
        FROM orders AS o
        JOIN order_items AS oi ON o.id = oi.order_id
        WHERE o.status = 'completed'
        GROUP BY DATE_TRUNC('month', o.order_date)
    )
    SELECT *
    FROM monthly_revenue
    ORDER BY month
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌────────────┬─────────────┬─────────────┐
│   month    │ order_count │   revenue   │
│    date    │    int64    │   double    │
├────────────┼─────────────┼─────────────┤
│ 2023-01-01 │         ... │ xxxxxxxx.xx │
│ 2023-02-01 │         ... │ xxxxxxxx.xx │
│ 2023-03-01 │         ... │ xxxxxxxx.xx │
│ ...        │         ... │        ...  │
│ 2024-11-01 │         ... │ xxxxxxxx.xx │
│ 2024-12-01 │         ... │ xxxxxxxx.xx │
└────────────┴─────────────┴─────────────┘
~~~

(24 rows — one per month, Jan 2023 through Dec 2024)

</details>

**Visualize it:** A line chart makes the trend immediately visible — are revenues climbing, flat, or seasonal?

```python
df = result.df()

fig, ax = plt.subplots(figsize=(10, 4))
ax.plot(df['month'], df['revenue'], marker='o', linewidth=2, color='#2c3e50')
ax.set_title('Monthly Revenue (2023–2024)')
ax.set_ylabel('Revenue ($)')
ax.grid(True, alpha=0.3)
fig.autofmt_xdate()
plt.tight_layout()
plt.show()
```

This CTE will be reused (copied) into every subsequent step. In a production database, you might create a view for this.

---

## Step 3: Month-over-Month with LAG

Add LAG(1) to compare each month to the previous month.

```python
result = duckdb.sql("""
    WITH monthly_revenue AS (
        SELECT
            DATE_TRUNC('month', o.order_date) AS month,
            ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue
        FROM orders AS o
        JOIN order_items AS oi ON o.id = oi.order_id
        WHERE o.status = 'completed'
        GROUP BY DATE_TRUNC('month', o.order_date)
    ),
    with_mom AS (
        SELECT
            month,
            revenue,
            LAG(revenue, 1) OVER (ORDER BY month) AS prev_month_revenue,
            ROUND(revenue - LAG(revenue, 1) OVER (ORDER BY month), 2) AS mom_change,
            ROUND(100.0 * (revenue - LAG(revenue, 1) OVER (ORDER BY month))
                  / LAG(revenue, 1) OVER (ORDER BY month), 1) AS mom_growth_pct
        FROM monthly_revenue
    )
    SELECT *
    FROM with_mom
    ORDER BY month
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌────────────┬─────────────┬────────────────────┬────────────┬─────────────────┐
│   month    │   revenue   │ prev_month_revenue │ mom_change │ mom_growth_pct  │
│    date    │   double    │       double       │   double   │     double      │
├────────────┼─────────────┼────────────────────┼────────────┼─────────────────┤
│ 2023-01-01 │ xxxxxxxx.xx │               NULL │       NULL │            NULL │
│ 2023-02-01 │ xxxxxxxx.xx │        xxxxxxxx.xx │  xxxxxx.xx │            xx.x │
│ 2023-03-01 │ xxxxxxxx.xx │        xxxxxxxx.xx │  xxxxxx.xx │            xx.x │
│ ...        │        ...  │               ...  │       ...  │            ...  │
│ 2024-12-01 │ xxxxxxxx.xx │        xxxxxxxx.xx │  xxxxxx.xx │            xx.x │
└────────────┴─────────────┴────────────────────┴────────────┴─────────────────┘
~~~

(24 rows — first row has NULL for prev_month since there's no prior month)

</details>

**Visualize it:** Green bars = growth, red bars = decline. This makes it easy to spot volatile months at a glance.

```python
df = result.df().dropna(subset=['mom_growth_pct'])

colors = ['#2ecc71' if x >= 0 else '#e74c3c' for x in df['mom_growth_pct']]
fig, ax = plt.subplots(figsize=(10, 4))
ax.bar(df['month'], df['mom_growth_pct'], color=colors, width=20)
ax.axhline(y=0, color='black', linewidth=0.8)
ax.set_title('Month-over-Month Revenue Growth (%)')
ax.set_ylabel('MoM Growth (%)')
ax.grid(True, alpha=0.3, axis='y')
fig.autofmt_xdate()
plt.tight_layout()
plt.show()
```

**Note:** The first row (Jan 2023) has NULL for `prev_month_revenue` because there is no December 2022 data. This is expected behavior for LAG at the boundary.

---

## Step 4: Year-Over-Year with LAG(12)

Now chain CTEs to compute year-over-year growth: compare each month in 2024 to the same month in 2023.

```python
result = duckdb.sql("""
    WITH monthly_revenue AS (
        SELECT
            DATE_TRUNC('month', o.order_date) AS month,
            ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue
        FROM orders AS o
        JOIN order_items AS oi ON o.id = oi.order_id
        WHERE o.status = 'completed'
        GROUP BY DATE_TRUNC('month', o.order_date)
    ),
    yoy AS (
        SELECT
            month,
            revenue AS current_year_revenue,
            LAG(revenue, 12) OVER (ORDER BY month) AS prior_year_revenue,
            ROUND(revenue - LAG(revenue, 12) OVER (ORDER BY month), 2) AS yoy_change,
            ROUND(100.0 * (revenue - LAG(revenue, 12) OVER (ORDER BY month))
                  / LAG(revenue, 12) OVER (ORDER BY month), 1) AS yoy_growth_pct
        FROM monthly_revenue
    )
    SELECT *
    FROM yoy
    WHERE prior_year_revenue IS NOT NULL
    ORDER BY month
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌────────────┬──────────────────────┬──────────────────────┬────────────┬─────────────────┐
│   month    │ current_year_revenue │ prior_year_revenue   │ yoy_change │ yoy_growth_pct  │
│    date    │        double        │        double        │   double   │     double      │
├────────────┼──────────────────────┼──────────────────────┼────────────┼─────────────────┤
│ 2024-01-01 │          xxxxxxxx.xx │          xxxxxxxx.xx │  xxxxxx.xx │            xx.x │
│ 2024-02-01 │          xxxxxxxx.xx │          xxxxxxxx.xx │  xxxxxx.xx │            xx.x │
│ 2024-03-01 │          xxxxxxxx.xx │          xxxxxxxx.xx │  xxxxxx.xx │            xx.x │
│ ...        │                 ...  │                 ...  │       ...  │            ...  │
│ 2024-12-01 │          xxxxxxxx.xx │          xxxxxxxx.xx │  xxxxxx.xx │            xx.x │
└────────────┴──────────────────────┴──────────────────────┴────────────┴─────────────────┘
~~~

(12 rows — only 2024 months, since 2023 months have no prior year data)

</details>

**Key pattern:** `LAG(revenue, 12)` reaches back exactly 12 rows. Since our data is monthly and sorted by month, this gives us the same-month-prior-year value. The `WHERE prior_year_revenue IS NOT NULL` filter removes the 2023 rows that have no 2022 comparison.

---

## Step 5: Moving Averages

Add 3-month and 6-month trailing moving averages to smooth out monthly volatility.

```python
result = duckdb.sql("""
    WITH monthly_revenue AS (
        SELECT
            DATE_TRUNC('month', o.order_date) AS month,
            ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue
        FROM orders AS o
        JOIN order_items AS oi ON o.id = oi.order_id
        WHERE o.status = 'completed'
        GROUP BY DATE_TRUNC('month', o.order_date)
    )
    SELECT
        month,
        revenue,
        ROUND(AVG(revenue) OVER (
            ORDER BY month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ), 2) AS ma_3m,
        ROUND(AVG(revenue) OVER (
            ORDER BY month
            ROWS BETWEEN 5 PRECEDING AND CURRENT ROW
        ), 2) AS ma_6m
    FROM monthly_revenue
    ORDER BY month
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌────────────┬─────────────┬─────────────┬─────────────┐
│   month    │   revenue   │    ma_3m    │    ma_6m    │
│    date    │   double    │   double    │   double    │
├────────────┼─────────────┼─────────────┼─────────────┤
│ 2023-01-01 │ xxxxxxxx.xx │ xxxxxxxx.xx │ xxxxxxxx.xx │
│ 2023-02-01 │ xxxxxxxx.xx │ xxxxxxxx.xx │ xxxxxxxx.xx │
│ 2023-03-01 │ xxxxxxxx.xx │ xxxxxxxx.xx │ xxxxxxxx.xx │
│ ...        │        ...  │        ...  │        ...  │
│ 2024-12-01 │ xxxxxxxx.xx │ xxxxxxxx.xx │ xxxxxxxx.xx │
└────────────┴─────────────┴─────────────┴─────────────┘
~~~

(24 rows — notice ma_3m for Jan 2023 = Jan's revenue since there are no prior months)

</details>

**Visualize it:** Overlaying the raw revenue with both moving averages shows the smoothing effect directly — watch how the 6-month line lags behind real changes while the 3-month line tracks more closely.

```python
df = result.df()

fig, ax = plt.subplots(figsize=(10, 4))
ax.plot(df['month'], df['revenue'], marker='o', linewidth=1, alpha=0.4,
        label='Monthly Revenue', color='#95a5a6')
ax.plot(df['month'], df['ma_3m'], linewidth=2,
        label='3-Month MA', color='#e67e22')
ax.plot(df['month'], df['ma_6m'], linewidth=2,
        label='6-Month MA', color='#2980b9')
ax.set_title('Revenue vs. Moving Averages')
ax.set_ylabel('Revenue ($)')
ax.legend()
ax.grid(True, alpha=0.3)
fig.autofmt_xdate()
plt.tight_layout()
plt.show()
```

**Smoothing vs lag tradeoff:** The 3-month average reacts faster to trends but is noisier. The 6-month average is smoother but lags behind real changes. For financial reporting, 3-month is most common; for strategic planning, 6-month gives a cleaner signal.

---

## Step 6: Category-Level Trends with Chained CTEs

Build a two-step pipeline: first aggregate by category and month, then compute YoY growth **per category** using partitioned LAG.

```python
result = duckdb.sql("""
    WITH category_monthly AS (
        SELECT
            p.category,
            DATE_TRUNC('month', o.order_date) AS month,
            ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue
        FROM orders AS o
        JOIN order_items AS oi ON o.id = oi.order_id
        JOIN products AS p ON oi.product_id = p.id
        WHERE o.status = 'completed'
        GROUP BY p.category, DATE_TRUNC('month', o.order_date)
    ),
    category_yoy AS (
        SELECT
            category,
            month,
            revenue AS current_revenue,
            LAG(revenue, 12) OVER (
                PARTITION BY category
                ORDER BY month
            ) AS prior_year_revenue,
            ROUND(100.0 * (revenue - LAG(revenue, 12) OVER (
                PARTITION BY category ORDER BY month
            )) / LAG(revenue, 12) OVER (
                PARTITION BY category ORDER BY month
            ), 1) AS yoy_growth_pct
        FROM category_monthly
    )
    SELECT *
    FROM category_yoy
    WHERE prior_year_revenue IS NOT NULL
    ORDER BY category, month
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌────────────┬────────────┬─────────────────┬────────────────────┬─────────────────┐
│  category  │   month    │ current_revenue │ prior_year_revenue │ yoy_growth_pct  │
│  varchar   │    date    │     double      │       double       │     double      │
├────────────┼────────────┼─────────────────┼────────────────────┼─────────────────┤
│ Books      │ 2024-01-01 │       xxxxx.xx  │          xxxxx.xx  │            xx.x │
│ Books      │ 2024-02-01 │       xxxxx.xx  │          xxxxx.xx  │            xx.x │
│ Books      │ 2024-03-01 │       xxxxx.xx  │          xxxxx.xx  │            xx.x │
│ ...        │ ...        │           ...   │              ...   │            ...  │
│ Clothing   │ 2024-01-01 │       xxxxx.xx  │          xxxxx.xx  │            xx.x │
│ ...        │ ...        │           ...   │              ...   │            ...  │
└────────────┴────────────┴─────────────────┴────────────────────┴─────────────────┘
~~~

(12 months × 6 categories for 2024 — DuckDB truncates the display for readability)

</details>

**Visualize it:** One line per category reveals which are growing vs. declining — patterns invisible in a 72-row table.

```python
df_cat = result.df()

fig, ax = plt.subplots(figsize=(10, 5))
for cat in df_cat['category'].unique():
    subset = df_cat[df_cat['category'] == cat]
    ax.plot(subset['month'], subset['yoy_growth_pct'],
            marker='o', linewidth=1.5, label=cat)
ax.axhline(y=0, color='black', linewidth=0.8, linestyle='--')
ax.set_title('Year-over-Year Growth by Category (%)')
ax.set_ylabel('YoY Growth (%)')
ax.legend(loc='best', fontsize=9)
ax.grid(True, alpha=0.3)
fig.autofmt_xdate()
plt.tight_layout()
plt.show()
```

**Key insight:** `PARTITION BY category` makes LAG(12) operate independently per category. Each category's January 2024 is compared to its own January 2023, not to another category's data.

---

## Step 7: Executive Dashboard

Combine all the techniques into one comprehensive query: revenue, MoM%, YoY%, 3-month moving average, and revenue rank — for 2024 months.

```python
result = duckdb.sql("""
    WITH monthly_revenue AS (
        SELECT
            DATE_TRUNC('month', o.order_date) AS month,
            ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue
        FROM orders AS o
        JOIN order_items AS oi ON o.id = oi.order_id
        WHERE o.status = 'completed'
        GROUP BY DATE_TRUNC('month', o.order_date)
    ),
    enriched AS (
        SELECT
            month,
            revenue,
            LAG(revenue, 1) OVER (ORDER BY month) AS prev_month,
            LAG(revenue, 12) OVER (ORDER BY month) AS prior_year,
            AVG(revenue) OVER (
                ORDER BY month
                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
            ) AS ma_3m
        FROM monthly_revenue
    ),
    dashboard AS (
        SELECT
            month,
            revenue,
            ROUND(100.0 * (revenue - prev_month) / prev_month, 1) AS mom_pct,
            ROUND(100.0 * (revenue - prior_year) / prior_year, 1) AS yoy_pct,
            ROUND(ma_3m, 2) AS moving_avg_3m,
            RANK() OVER (ORDER BY revenue DESC) AS revenue_rank
        FROM enriched
        WHERE prior_year IS NOT NULL
    )
    SELECT *
    FROM dashboard
    ORDER BY month
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌────────────┬─────────────┬─────────┬─────────┬───────────────┬──────────────┐
│   month    │   revenue   │ mom_pct │ yoy_pct │ moving_avg_3m │ revenue_rank │
│    date    │   double    │ double  │ double  │    double     │    int64     │
├────────────┼─────────────┼─────────┼─────────┼───────────────┼──────────────┤
│ 2024-01-01 │ xxxxxxxx.xx │    xx.x │    xx.x │   xxxxxxxx.xx │           .. │
│ 2024-02-01 │ xxxxxxxx.xx │    xx.x │    xx.x │   xxxxxxxx.xx │           .. │
│ 2024-03-01 │ xxxxxxxx.xx │    xx.x │    xx.x │   xxxxxxxx.xx │           .. │
│ ...        │        ...  │     ... │     ... │          ...  │          ... │
│ 2024-12-01 │ xxxxxxxx.xx │    xx.x │    xx.x │   xxxxxxxx.xx │           .. │
└────────────┴─────────────┴─────────┴─────────┴───────────────┴──────────────┘
~~~

(12 rows — complete 2024 executive dashboard)

</details>

**Visualize it:** A multi-panel figure mirrors what a real executive dashboard looks like.

```python
df = result.df()

fig, axes = plt.subplots(2, 2, figsize=(12, 8))

# Top-left: Revenue with 3-month moving average
axes[0, 0].plot(df['month'], df['revenue'], marker='o', linewidth=1.5, label='Revenue')
axes[0, 0].plot(df['month'], df['moving_avg_3m'], linewidth=2, linestyle='--', label='3M MA')
axes[0, 0].set_title('Revenue & Moving Average')
axes[0, 0].legend(fontsize=8)
axes[0, 0].grid(True, alpha=0.3)
axes[0, 0].tick_params(axis='x', rotation=45)

# Top-right: Month-over-month growth
colors_mom = ['#2ecc71' if x >= 0 else '#e74c3c' for x in df['mom_pct']]
axes[0, 1].bar(df['month'], df['mom_pct'], color=colors_mom, width=20)
axes[0, 1].axhline(y=0, color='black', linewidth=0.8)
axes[0, 1].set_title('Month-over-Month (%)')
axes[0, 1].grid(True, alpha=0.3, axis='y')
axes[0, 1].tick_params(axis='x', rotation=45)

# Bottom-left: Year-over-year growth
colors_yoy = ['#2ecc71' if x >= 0 else '#e74c3c' for x in df['yoy_pct']]
axes[1, 0].bar(df['month'], df['yoy_pct'], color=colors_yoy, width=20)
axes[1, 0].axhline(y=0, color='black', linewidth=0.8)
axes[1, 0].set_title('Year-over-Year (%)')
axes[1, 0].grid(True, alpha=0.3, axis='y')
axes[1, 0].tick_params(axis='x', rotation=45)

# Bottom-right: Revenue rank
df_sorted = df.sort_values('revenue_rank')
axes[1, 1].barh(df_sorted['month'].dt.strftime('%b %Y'), df_sorted['revenue'],
                color='#3498db')
axes[1, 1].set_title('Months Ranked by Revenue')
axes[1, 1].invert_yaxis()

fig.suptitle('2024 Executive Dashboard', fontsize=14, fontweight='bold')
plt.tight_layout()
plt.show()
```

**What makes this powerful:** Three chained CTEs build a pipeline:
1. `monthly_revenue` — aggregates raw data into monthly totals
2. `enriched` — adds LAG values and moving average (raw metrics)
3. `dashboard` — computes percentage changes and ranking (presentation metrics)

Each step is readable, testable, and modifiable independently.

---

## Your Turn! (Exercises)

### Exercise 1: Quarterly Revenue with YoY

**Task:** Calculate **quarterly** revenue (completed orders) and year-over-year growth by quarter. Use `DATE_TRUNC('quarter', ...)` for grouping and `LAG(revenue, 4)` for the prior year's same quarter. Show only quarters that have prior-year data.

```python
# TODO: Write your query here
# Hint: DATE_TRUNC('quarter', o.order_date) groups by quarter
# Hint: LAG(revenue, 4) reaches back 4 quarters = 1 year
# result = duckdb.sql("""...""")
# result.show()
```

<details>
<summary>Hint</summary>

~~~sql
WITH quarterly_revenue AS (
    SELECT
        DATE_TRUNC('quarter', o.order_date) AS quarter,
        ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue
    FROM orders AS o
    JOIN order_items AS oi ON o.id = oi.order_id
    WHERE o.status = 'completed'
    GROUP BY DATE_TRUNC('quarter', o.order_date)
),
qtr_yoy AS (
    SELECT
        quarter,
        revenue,
        LAG(revenue, 4) OVER (ORDER BY quarter) AS prior_year_revenue,
        ROUND(100.0 * (revenue - LAG(revenue, 4) OVER (ORDER BY quarter))
              / LAG(revenue, 4) OVER (ORDER BY quarter), 1) AS yoy_growth_pct
    FROM quarterly_revenue
)
SELECT *
FROM qtr_yoy
WHERE prior_year_revenue IS NOT NULL
ORDER BY quarter
~~~

</details>

<details>
<summary>Expected Output</summary>

~~~text
┌────────────┬─────────────┬────────────────────┬─────────────────┐
│  quarter   │   revenue   │ prior_year_revenue │ yoy_growth_pct  │
│    date    │   double    │       double       │     double      │
├────────────┼─────────────┼────────────────────┼─────────────────┤
│ 2024-01-01 │ xxxxxxxx.xx │        xxxxxxxx.xx │            xx.x │
│ 2024-04-01 │ xxxxxxxx.xx │        xxxxxxxx.xx │            xx.x │
│ 2024-07-01 │ xxxxxxxx.xx │        xxxxxxxx.xx │            xx.x │
│ 2024-10-01 │ xxxxxxxx.xx │        xxxxxxxx.xx │            xx.x │
└────────────┴─────────────┴────────────────────┴─────────────────┘
~~~

(4 rows — 2024 quarters with YoY comparison)

</details>

### Exercise 2: Category Moving Average

**Task:** Calculate the **3-month moving average** of revenue per category. Use `PARTITION BY category` with `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW`. Show results for 2024 only.

```python
# TODO: Write your query here
# Hint: AVG(revenue) OVER (PARTITION BY category ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)
# result = duckdb.sql("""...""")
# result.show()
```

<details>
<summary>Hint</summary>

~~~sql
WITH category_monthly AS (
    SELECT
        p.category,
        DATE_TRUNC('month', o.order_date) AS month,
        ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue
    FROM orders AS o
    JOIN order_items AS oi ON o.id = oi.order_id
    JOIN products AS p ON oi.product_id = p.id
    WHERE o.status = 'completed'
    GROUP BY p.category, DATE_TRUNC('month', o.order_date)
),
with_ma AS (
    SELECT
        category,
        month,
        revenue,
        ROUND(AVG(revenue) OVER (
            PARTITION BY category
            ORDER BY month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ), 2) AS ma_3m
    FROM category_monthly
)
SELECT *
FROM with_ma
WHERE month >= '2024-01-01'
ORDER BY category, month
~~~

</details>

<details>
<summary>Expected Output</summary>

~~~text
┌────────────────┬────────────┬──────────┬───────────┐
│    category    │   month    │ revenue  │   ma_3m   │
│    varchar     │    date    │  double  │  double   │
├────────────────┼────────────┼──────────┼───────────┤
│ Books          │ 2024-01-01 │ xxxxx.xx │  xxxxx.xx │
│ Books          │ 2024-02-01 │ xxxxx.xx │  xxxxx.xx │
│ ...            │ ...        │      ... │       ... │
│ Toys           │ 2024-12-01 │ xxxxx.xx │  xxxxx.xx │
└────────────────┴────────────┴──────────┴───────────┘
~~~

(72 rows — 12 months × 6 categories)

</details>

### Exercise 3: LEAD for Forward-Looking Analysis

**Task:** Use LEAD to find months where the **next month's** revenue dropped by more than 10%. Show the month, current revenue, next month's revenue, and the percentage change.

```python
# TODO: Write your query here
# Hint: LEAD(revenue, 1) OVER (ORDER BY month) for next month
# Hint: Filter WHERE pct_change < -10
# result = duckdb.sql("""...""")
# result.show()
```

<details>
<summary>Hint</summary>

~~~sql
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', o.order_date) AS month,
        ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue
    FROM orders AS o
    JOIN order_items AS oi ON o.id = oi.order_id
    WHERE o.status = 'completed'
    GROUP BY DATE_TRUNC('month', o.order_date)
),
with_lead AS (
    SELECT
        month,
        revenue,
        LEAD(revenue, 1) OVER (ORDER BY month) AS next_month_revenue,
        ROUND(100.0 * (LEAD(revenue, 1) OVER (ORDER BY month) - revenue)
              / revenue, 1) AS pct_change
    FROM monthly_revenue
)
SELECT *
FROM with_lead
WHERE pct_change < -10
ORDER BY pct_change ASC
~~~

</details>

<details>
<summary>Expected Output</summary>

~~~text
┌────────────┬─────────────┬────────────────────┬────────────┐
│   month    │   revenue   │ next_month_revenue │ pct_change │
│    date    │   double    │       double       │   double   │
├────────────┼─────────────┼────────────────────┼────────────┤
│ ...        │ xxxxxxxx.xx │        xxxxxxxx.xx │      -xx.x │
│ ...        │ xxxxxxxx.xx │        xxxxxxxx.xx │      -xx.x │
└────────────┴─────────────┴────────────────────┴────────────┘
~~~

(Months where the following month had a >10% revenue drop — count depends on random data)

</details>

### Exercise 4: Best and Worst YoY Growth Months

**Task:** Using chained CTEs, find the **3 best** and **3 worst** months by YoY growth percentage. Use ROW_NUMBER with two different orderings to identify the top and bottom 3.

```python
# TODO: Write your query here
# Hint: Chain 3 CTEs: monthly_revenue → yoy → ranked
# Hint: ROW_NUMBER() OVER (ORDER BY yoy_growth_pct DESC) for best
# Hint: ROW_NUMBER() OVER (ORDER BY yoy_growth_pct ASC) for worst
# result = duckdb.sql("""...""")
# result.show()
```

<details>
<summary>Hint</summary>

~~~sql
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', o.order_date) AS month,
        ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue
    FROM orders AS o
    JOIN order_items AS oi ON o.id = oi.order_id
    WHERE o.status = 'completed'
    GROUP BY DATE_TRUNC('month', o.order_date)
),
yoy AS (
    SELECT
        month,
        revenue,
        LAG(revenue, 12) OVER (ORDER BY month) AS prior_year,
        ROUND(100.0 * (revenue - LAG(revenue, 12) OVER (ORDER BY month))
              / LAG(revenue, 12) OVER (ORDER BY month), 1) AS yoy_growth_pct
    FROM monthly_revenue
),
ranked AS (
    SELECT
        month,
        revenue,
        yoy_growth_pct,
        ROW_NUMBER() OVER (ORDER BY yoy_growth_pct DESC) AS best_rank,
        ROW_NUMBER() OVER (ORDER BY yoy_growth_pct ASC) AS worst_rank
    FROM yoy
    WHERE prior_year IS NOT NULL
)
SELECT
    month,
    revenue,
    yoy_growth_pct,
    CASE WHEN best_rank <= 3 THEN 'Best #' || best_rank
         WHEN worst_rank <= 3 THEN 'Worst #' || worst_rank
    END AS label
FROM ranked
WHERE best_rank <= 3 OR worst_rank <= 3
ORDER BY yoy_growth_pct DESC
~~~

</details>

<details>
<summary>Expected Output</summary>

~~~text
┌────────────┬─────────────┬─────────────────┬───────────┐
│   month    │   revenue   │ yoy_growth_pct  │   label   │
│    date    │   double    │     double      │  varchar  │
├────────────┼─────────────┼─────────────────┼───────────┤
│ 2024-XX-01 │ xxxxxxxx.xx │            xx.x │ Best #1   │
│ 2024-XX-01 │ xxxxxxxx.xx │            xx.x │ Best #2   │
│ 2024-XX-01 │ xxxxxxxx.xx │            xx.x │ Best #3   │
│ 2024-XX-01 │ xxxxxxxx.xx │           -xx.x │ Worst #3  │
│ 2024-XX-01 │ xxxxxxxx.xx │           -xx.x │ Worst #2  │
│ 2024-XX-01 │ xxxxxxxx.xx │           -xx.x │ Worst #1  │
└────────────┴─────────────┴─────────────────┴───────────┘
~~~

(6 rows — 3 best and 3 worst YoY growth months)

</details>

---

## Summary

In this lab, you built a complete time-series analytics pipeline using CTEs and offset functions:

1. **Monthly Revenue CTE** — Foundation aggregation (24 rows for 2 years)
2. **Month-over-Month** — LAG(1) for sequential comparison
3. **Year-over-Year** — LAG(12) for same-month-prior-year comparison
4. **Moving Averages** — 3-month and 6-month trailing averages with frame clauses
5. **Category Trends** — PARTITION BY for independent LAG per category
6. **Executive Dashboard** — All metrics combined in one chained CTE pipeline

**Key Takeaways:**
- **CTEs make complex queries readable** — name each step, build a pipeline
- **LAG(N) is the YoY workhorse** — LAG(1) for MoM, LAG(12) for YoY, LAG(4) for quarterly YoY
- **PARTITION BY with LAG** — each group gets its own independent offset computation
- **Frame clauses control moving averages** — 3-month trailing is the business standard
- **Chained CTEs + window functions** — the complete toolkit for time-series SQL analytics