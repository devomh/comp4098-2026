---
title: "Lab: Summary Reports with Aggregation"
week: 06
type: lab
tags: [sql, duckdb, aggregation, groupby, having, analytics, python]
difficulty: intermediate
duration: "60 mins"
---

# Lab: Summary Reports with Aggregation

## Prerequisites & Setup

**Before starting this lab, you should:**
- Review [w06_l12_concept_aggregation_grouping.md](w06_l12_concept_aggregation_grouping.md) for aggregation concepts
- Have completed [Lesson 11 Lab](w06_l11_lab_multi_table_queries.md) for join practice
- Understand GROUP BY, HAVING, and the five core aggregate functions

**What you'll accomplish:**
In this lab, you'll build management reports from an e-commerce dataset — total revenue, sales by category, customer segmentation, and a complete dashboard query. You'll combine JOINs with GROUP BY, HAVING, and ORDER BY to answer real business questions.

**Goal:** Master the JOIN → GROUP BY → HAVING pattern for analytical SQL.

---

## Environment Setup

Run this setup block first to install required packages.

```python
# Setup: Run this cell first (required for Colab)
!pip install -q duckdb pandas mermaid-py

import duckdb
import pandas as pd
import random
import os
from datetime import date, timedelta

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

## The Scenario

You're still the data analyst at **ShopStream**. Your manager needs weekly management reports: revenue summaries, top performers, and customer segmentation. In Lesson 11, you assembled data with JOINs. Now you'll **aggregate** it into actionable insights.

---

## Step 1: Generate & Load the Dataset

Same e-commerce dataset as Lesson 11 (self-contained for Colab).

```python
random.seed(42)

# --- Customers (5,000 rows, some will have no orders) ---
regions = ['Northeast', 'Southeast', 'Midwest', 'West', 'Southwest', 'Northwest']
cities = {
    'Northeast': ['New York', 'Boston', 'Philadelphia', 'Hartford'],
    'Southeast': ['Miami', 'Atlanta', 'Charlotte', 'Orlando'],
    'Midwest': ['Chicago', 'Detroit', 'Minneapolis', 'Columbus'],
    'West': ['Los Angeles', 'San Francisco', 'San Diego', 'Portland'],
    'Southwest': ['Houston', 'Dallas', 'Phoenix', 'San Antonio'],
    'Northwest': ['Seattle', 'Boise', 'Spokane', 'Eugene'],
}

customers = []
for i in range(1, 5001):
    region = random.choice(regions)
    city = random.choice(cities[region])
    signup = date(2021, 1, 1) + timedelta(days=random.randint(0, 1460))
    customers.append({
        'id': i,
        'name': f"Customer_{i}",
        'city': city,
        'region': region,
        'signup_date': signup,
    })

# --- Products (200 rows) ---
categories = ['Electronics', 'Clothing', 'Books', 'Home & Kitchen', 'Sports', 'Toys']
products = []
for i in range(1, 201):
    cat = categories[(i - 1) % len(categories)]
    price = round(random.uniform(5.0, 500.0), 2)
    products.append({
        'id': i,
        'name': f"Product_{i}",
        'category': cat,
        'price': price,
    })

# --- Orders (50,000 rows) ---
ordering_customers = random.sample(range(1, 5001), 4500)
statuses = ['completed', 'completed', 'completed', 'completed',
            'pending', 'cancelled']

orders = []
for i in range(1, 50001):
    cust_id = random.choice(ordering_customers)
    order_date = date(2023, 1, 1) + timedelta(days=random.randint(0, 730))
    status = random.choice(statuses)
    orders.append({
        'id': i,
        'customer_id': cust_id,
        'order_date': order_date,
        'status': status,
    })

# --- Order Items (120,000+ rows) ---
order_items = []
item_id = 1
for order in orders:
    num_items = random.randint(1, 5)
    chosen_products = random.sample(range(1, 201), num_items)
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

## Step 2: Simple Aggregates (No GROUP BY)

Start with whole-table aggregates to get a big-picture overview. These queries intentionally include **all order statuses** to show the full scope of the data. Later sections filter to completed orders only for management reporting.

```python
# Overall business metrics
result = duckdb.sql("""
    SELECT
        COUNT(DISTINCT o.id) AS total_orders,
        COUNT(DISTINCT o.customer_id) AS unique_customers,
        ROUND(SUM(oi.quantity * oi.unit_price), 2) AS total_revenue,
        ROUND(AVG(oi.quantity * oi.unit_price), 2) AS avg_line_total,
        MIN(o.order_date) AS first_order,
        MAX(o.order_date) AS last_order
    FROM orders AS o
    JOIN order_items AS oi ON o.id = oi.order_id
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌──────────────┬──────────────────┬───────────────┬────────────────┬─────────────┬────────────┐
│ total_orders │ unique_customers │ total_revenue │ avg_line_total │ first_order │ last_order │
│    int64     │      int64       │    double     │     double     │    date     │    date    │
├──────────────┼──────────────────┼───────────────┼────────────────┼─────────────┼────────────┤
│        50000 │             4500 │  xxxxxxxx.xx  │         xxx.xx │  2023-01-01 │ 2024-12-31 │
└──────────────┴──────────────────┴───────────────┴────────────────┴─────────────┴────────────┘
~~~

A single row summarizing the entire business.

</details>

```python
# Order status breakdown
result = duckdb.sql("""
    SELECT
        status,
        COUNT(*) AS order_count,
        ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM orders), 1) AS percentage
    FROM orders
    GROUP BY status
    ORDER BY order_count DESC
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌───────────┬─────────────┬────────────┐
│  status   │ order_count │ percentage │
│  varchar  │    int64    │   double   │
├───────────┼─────────────┼────────────┤
│ completed │       33333 │       66.7 │
│ pending   │        8333 │       16.7 │
│ cancelled │        8334 │       16.7 │
└───────────┴─────────────┴────────────┘
~~~

(Approximate — ~67% completed, ~17% each for pending/cancelled)

</details>

---

## Step 3: GROUP BY Basics

These queries also include all order statuses to show the GROUP BY pattern without extra filters. From Step 5 onward, we add `WHERE o.status = 'completed'` — the standard for management reports.

### Revenue by Product Category

```python
result = duckdb.sql("""
    SELECT
        p.category,
        COUNT(*) AS items_sold,
        SUM(oi.quantity) AS total_units,
        ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue,
        ROUND(AVG(oi.unit_price), 2) AS avg_price
    FROM order_items AS oi
    JOIN products AS p ON oi.product_id = p.id
    GROUP BY p.category
    ORDER BY revenue DESC
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌────────────────┬────────────┬─────────────┬─────────────┬───────────┐
│    category    │ items_sold │ total_units │   revenue   │ avg_price │
│    varchar     │   int64    │    int128   │   double    │  double   │
├────────────────┼────────────┼─────────────┼─────────────┼───────────┤
│ Electronics    │      ...   │        ...  │ xxxxxxxx.xx │    xxx.xx │
│ Home & Kitchen │      ...   │        ...  │ xxxxxxxx.xx │    xxx.xx │
│ ...            │      ...   │        ...  │        ...  │       ... │
└────────────────┴────────────┴─────────────┴─────────────┴───────────┘
~~~

(6 rows — one per category, sorted by revenue)

</details>

### Order Count by Region

```python
result = duckdb.sql("""
    SELECT
        c.region,
        COUNT(DISTINCT c.id) AS customers,
        COUNT(*) AS total_orders,
        ROUND(1.0 * COUNT(*) / COUNT(DISTINCT c.id), 1) AS orders_per_customer
    FROM customers AS c
    JOIN orders AS o ON c.id = o.customer_id
    GROUP BY c.region
    ORDER BY total_orders DESC
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌───────────┬───────────┬──────────────┬─────────────────────┐
│  region   │ customers │ total_orders │ orders_per_customer │
│  varchar  │   int64   │    int64     │       double        │
├───────────┼───────────┼──────────────┼─────────────────────┤
│ ...       │       ... │         ...  │                ...  │
└───────────┴───────────┴──────────────┴─────────────────────┘
~~~

(6 rows — one per region)

</details>

---

## Step 4: Multi-Level GROUP BY

### Revenue by Region AND Category

```python
result = duckdb.sql("""
    SELECT
        c.region,
        p.category,
        COUNT(DISTINCT o.id) AS orders,
        ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue
    FROM customers AS c
    JOIN orders AS o ON c.id = o.customer_id
    JOIN order_items AS oi ON o.id = oi.order_id
    JOIN products AS p ON oi.product_id = p.id
    GROUP BY c.region, p.category
    ORDER BY c.region, revenue DESC
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌───────────┬────────────────┬────────┬─────────────┐
│  region   │    category    │ orders │   revenue   │
│  varchar  │    varchar     │ int64  │   double    │
├───────────┼────────────────┼────────┼─────────────┤
│ Midwest   │ Electronics    │    ... │ xxxxxxxx.xx │
│ Midwest   │ Home & Kitchen │    ... │ xxxxxxxx.xx │
│ Midwest   │ ...            │    ... │        ...  │
│ Northeast │ Electronics    │    ... │ xxxxxxxx.xx │
│ ...       │ ...            │    ... │        ...  │
└───────────┴────────────────┴────────┴─────────────┘
~~~

(36 rows — 6 regions × 6 categories)

</details>

### Top Category per Region

```python
# Which category generates the most revenue in each region?
result = duckdb.sql("""
    WITH region_category AS (
        SELECT
            c.region,
            p.category,
            ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue,
            ROW_NUMBER() OVER (PARTITION BY c.region ORDER BY SUM(oi.quantity * oi.unit_price) DESC) AS rn
        FROM customers AS c
        JOIN orders AS o ON c.id = o.customer_id
        JOIN order_items AS oi ON o.id = oi.order_id
        JOIN products AS p ON oi.product_id = p.id
        GROUP BY c.region, p.category
    )
    SELECT region, category, revenue
    FROM region_category
    WHERE rn = 1
    ORDER BY revenue DESC
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌───────────┬────────────┬─────────────┐
│  region   │  category  │   revenue   │
│  varchar  │  varchar   │   double    │
├───────────┼────────────┼─────────────┤
│ ...       │ ...        │ xxxxxxxx.xx │
│ ...       │ ...        │ xxxxxxxx.xx │
│ ...       │ ...        │ xxxxxxxx.xx │
│ ...       │ ...        │ xxxxxxxx.xx │
│ ...       │ ...        │ xxxxxxxx.xx │
│ ...       │ ...        │ xxxxxxxx.xx │
└───────────┴────────────┴─────────────┘
~~~

(6 rows — the top-selling category in each region)

</details>

**Note:** This query uses a **window function** (ROW_NUMBER) as a preview of Week 07 topics. For now, focus on the GROUP BY pattern inside the CTE.

---

## Step 5: HAVING — Filtering Groups

### Categories with Revenue Above a Threshold

```python
# Only show categories with revenue > $5,000,000
result = duckdb.sql("""
    SELECT
        p.category,
        ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue,
        COUNT(DISTINCT o.id) AS order_count
    FROM order_items AS oi
    JOIN orders AS o ON oi.order_id = o.id
    JOIN products AS p ON oi.product_id = p.id
    WHERE o.status = 'completed'
    GROUP BY p.category
    HAVING SUM(oi.quantity * oi.unit_price) > 5000000
    ORDER BY revenue DESC
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌────────────┬─────────────┬─────────────┐
│  category  │   revenue   │ order_count │
│  varchar   │   double    │    int64    │
├────────────┼─────────────┼─────────────┤
│ ...        │ xxxxxxxx.xx │        ...  │
│ ...        │ xxxxxxxx.xx │        ...  │
└────────────┴─────────────┴─────────────┘
~~~

(Only categories with revenue above the threshold)

</details>

### High-Volume Customers

```python
# Customers with more than 20 orders
result = duckdb.sql("""
    SELECT
        c.id,
        c.name,
        c.region,
        COUNT(DISTINCT o.id) AS order_count,
        ROUND(SUM(oi.quantity * oi.unit_price), 2) AS total_spent
    FROM customers AS c
    JOIN orders AS o ON c.id = o.customer_id
    JOIN order_items AS oi ON o.id = oi.order_id
    GROUP BY c.id, c.name, c.region
    HAVING COUNT(DISTINCT o.id) > 20
    ORDER BY total_spent DESC
    LIMIT 10
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌───────┬──────────────┬───────────┬─────────────┬─────────────┐
│  id   │     name     │  region   │ order_count │ total_spent │
│ int64 │   varchar    │  varchar  │    int64    │   double    │
├───────┼──────────────┼───────────┼─────────────┼─────────────┤
│   ... │ Customer_... │ ...       │         ... │ xxxxxxxx.xx │
│   ... │ Customer_... │ ...       │         ... │ xxxxxxxx.xx │
│   ... │ ...          │ ...       │         ... │        ...  │
└───────┴──────────────┴───────────┴─────────────┴─────────────┘
~~~

(Top 10 highest-spending customers who placed > 20 orders)

</details>

---

## Step 6: JOINs + Aggregations — Full Pattern

### Top-Selling Products

```python
result = duckdb.sql("""
    SELECT
        p.name AS product,
        p.category,
        SUM(oi.quantity) AS total_units_sold,
        ROUND(SUM(oi.quantity * oi.unit_price), 2) AS total_revenue,
        COUNT(DISTINCT o.customer_id) AS unique_buyers
    FROM order_items AS oi
    JOIN orders AS o ON oi.order_id = o.id
    JOIN products AS p ON oi.product_id = p.id
    WHERE o.status = 'completed'
    GROUP BY p.id, p.name, p.category
    ORDER BY total_revenue DESC
    LIMIT 10
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌────────────┬─────────────────┬──────────────────┬───────────────┬───────────────┐
│  product   │    category     │ total_units_sold │ total_revenue │ unique_buyers │
│  varchar   │    varchar      │      int128      │    double     │     int64     │
├────────────┼─────────────────┼──────────────────┼───────────────┼───────────────┤
│ Product_X  │ Electronics     │              ... │   xxxxxxxx.xx │           ... │
│ Product_Y  │ Home & Kitchen  │              ... │   xxxxxxxx.xx │           ... │
│ ...        │ ...             │              ... │          ...  │           ... │
└────────────┴─────────────────┴──────────────────┴───────────────┴───────────────┘
~~~

(Top 10 products by revenue from completed orders)

</details>

### Best-Selling Products per Category

```python
result = duckdb.sql("""
    WITH product_sales AS (
        SELECT
            p.id AS product_id,
            p.name AS product,
            p.category,
            SUM(oi.quantity) AS total_units,
            ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue,
            ROW_NUMBER() OVER (PARTITION BY p.category ORDER BY SUM(oi.quantity * oi.unit_price) DESC) AS rank
        FROM order_items AS oi
        JOIN orders AS o ON oi.order_id = o.id
        JOIN products AS p ON oi.product_id = p.id
        WHERE o.status = 'completed'
        GROUP BY p.id, p.name, p.category
    )
    SELECT product, category, total_units, revenue
    FROM product_sales
    WHERE rank <= 3
    ORDER BY category, revenue DESC
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌────────────┬─────────────────┬─────────────┬─────────────┐
│  product   │    category     │ total_units │   revenue   │
│  varchar   │    varchar      │   int128    │   double    │
├────────────┼─────────────────┼─────────────┼─────────────┤
│ Product_X  │ Books           │         ... │ xxxxxxxx.xx │
│ Product_Y  │ Books           │         ... │ xxxxxxxx.xx │
│ Product_Z  │ Books           │         ... │ xxxxxxxx.xx │
│ Product_A  │ Clothing        │         ... │ xxxxxxxx.xx │
│ ...        │ ...             │         ... │        ...  │
└────────────┴─────────────────┴─────────────┴─────────────┘
~~~

(18 rows — top 3 products per category)

</details>

---

## Step 7: Building a Dashboard Query

Combine everything into one comprehensive management report.

```python
# Executive Dashboard: Revenue summary by region
result = duckdb.sql("""
    SELECT
        c.region,
        COUNT(DISTINCT c.id) AS customers,
        COUNT(DISTINCT o.id) AS orders,
        ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue,
        ROUND(SUM(oi.quantity * oi.unit_price) / COUNT(DISTINCT o.id), 2) AS avg_order_value,
        ROUND(SUM(oi.quantity * oi.unit_price) / COUNT(DISTINCT c.id), 2) AS revenue_per_customer,
        ROUND(100.0 * SUM(oi.quantity * oi.unit_price) /
              (SELECT SUM(oi2.quantity * oi2.unit_price)
               FROM order_items AS oi2
               JOIN orders AS o2 ON oi2.order_id = o2.id
               WHERE o2.status = 'completed'), 1) AS pct_of_total
    FROM customers AS c
    JOIN orders AS o ON c.id = o.customer_id
    JOIN order_items AS oi ON o.id = oi.order_id
    WHERE o.status = 'completed'
    GROUP BY c.region
    ORDER BY revenue DESC
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌───────────┬───────────┬────────┬─────────────┬─────────────────┬──────────────────────┬──────────────┐
│  region   │ customers │ orders │   revenue   │ avg_order_value │ revenue_per_customer │ pct_of_total │
│  varchar  │   int64   │ int64  │   double    │     double      │       double         │    double    │
├───────────┼───────────┼────────┼─────────────┼─────────────────┼──────────────────────┼──────────────┤
│ ...       │       ... │    ... │ xxxxxxxx.xx │         xxx.xx  │           xxxxxxx.xx │         xx.x │
│ ...       │       ... │    ... │ xxxxxxxx.xx │         xxx.xx  │           xxxxxxx.xx │         xx.x │
│ ...       │       ... │    ... │ xxxxxxxx.xx │         xxx.xx  │           xxxxxxx.xx │         xx.x │
│ ...       │       ... │    ... │ xxxxxxxx.xx │         xxx.xx  │           xxxxxxx.xx │         xx.x │
│ ...       │       ... │    ... │ xxxxxxxx.xx │         xxx.xx  │           xxxxxxx.xx │         xx.x │
│ ...       │       ... │    ... │ xxxxxxxx.xx │         xxx.xx  │           xxxxxxx.xx │         xx.x │
└───────────┴───────────┴────────┴─────────────┴─────────────────┴──────────────────────┴──────────────┘
~~~

(6 rows — complete regional performance dashboard)

</details>

**What makes this a "dashboard query":** It combines JOINs (3 tables), WHERE (completed orders only), GROUP BY (by region), computed metrics (avg order value, revenue per customer), and percentage-of-total calculations — all in one SQL statement.

---

## Your Turn! (Exercises)

### Exercise 1: Revenue by Month

**Task:** Calculate total revenue and order count by **month** for completed orders. Use DuckDB's `DATE_TRUNC('month', order_date)` to group by month. Sort chronologically.

```python
# TODO: Write your query here
# Hint: DATE_TRUNC('month', o.order_date) AS month
# result = duckdb.sql("""...""")
# result.show()
```

<details>
<summary>Hint</summary>

~~~sql
SELECT
    DATE_TRUNC('month', o.order_date) AS month,
    COUNT(DISTINCT o.id) AS orders,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue
FROM ...
WHERE o.status = 'completed'
GROUP BY DATE_TRUNC('month', o.order_date)
ORDER BY month
~~~

</details>

<details>
<summary>Expected Output</summary>

~~~text
┌────────────┬────────┬─────────────┐
│   month    │ orders │   revenue   │
│    date    │ int64  │   double    │
├────────────┼────────┼─────────────┤
│ 2023-01-01 │    ... │ xxxxxxxx.xx │
│ 2023-02-01 │    ... │ xxxxxxxx.xx │
│ ...        │    ... │        ...  │
│ 2024-12-01 │    ... │ xxxxxxxx.xx │
└────────────┴────────┴─────────────┘
~~~

(24 rows — one per month from Jan 2023 to Dec 2024)

</details>

### Exercise 2: Categories with High Average Price

**Task:** Find product categories where the **average catalog price** of products in the category is greater than $250. Show category, number of products, average catalog price, and total revenue from completed orders.

```python
# TODO: Write your query using HAVING
# result = duckdb.sql("""...""")
# result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌──────────┬──────────┬───────────┬─────────────┐
│ category │ products │ avg_price │   revenue   │
│ varchar  │  int64   │  double   │   double    │
├──────────┼──────────┼───────────┼─────────────┤
│ ...      │      ... │    xxx.xx │ xxxxxxxx.xx │
└──────────┴──────────┴───────────┴─────────────┘
~~~

(Categories where average product price > $250)

</details>

### Exercise 3: Customer Spending Tiers

**Task:** Classify customers into spending tiers based on their total spending on completed orders:
- **Platinum:** > $50,000
- **Gold:** $20,000 – $50,000
- **Silver:** $5,000 – $20,000
- **Bronze:** < $5,000

Show the tier, number of customers, and total revenue per tier. Include the 500 customers who never ordered as a "No Orders" tier.

```python
# TODO: Write your query using CASE WHEN and LEFT JOIN
# Hint: LEFT JOIN customers to orders, then use CASE to classify
# result = duckdb.sql("""...""")
# result.show()
```

<details>
<summary>Hint</summary>

~~~sql
WITH customer_spending AS (
    SELECT
        c.id,
        -- Detect whether the customer has ANY orders at all
        COUNT(DISTINCT o.id) AS total_orders,
        -- Spending is based on completed orders only
        COALESCE(SUM(CASE WHEN o.status = 'completed'
                      THEN oi.quantity * oi.unit_price END), 0) AS total_spent
    FROM customers AS c
    LEFT JOIN orders AS o ON c.id = o.customer_id
    LEFT JOIN order_items AS oi ON o.id = oi.order_id
    GROUP BY c.id
)
SELECT
    CASE
        WHEN total_orders = 0 THEN 'No Orders'
        WHEN total_spent < 5000 THEN 'Bronze'
        WHEN total_spent < 20000 THEN 'Silver'
        WHEN total_spent < 50000 THEN 'Gold'
        ELSE 'Platinum'
    END AS tier,
    COUNT(*) AS customers,
    ROUND(SUM(total_spent), 2) AS tier_revenue
FROM customer_spending
GROUP BY tier
ORDER BY tier_revenue DESC
~~~

</details>

<details>
<summary>Expected Output</summary>

~~~text
┌───────────┬───────────┬──────────────┐
│   tier    │ customers │ tier_revenue │
│  varchar  │   int64   │    double    │
├───────────┼───────────┼──────────────┤
│ Gold      │       ... │ xxxxxxxxx.xx │
│ Silver    │       ... │ xxxxxxxxx.xx │
│ Platinum  │       ... │ xxxxxxxxx.xx │
│ Bronze    │       ... │  xxxxxxxx.xx │
│ No Orders │       500 │         0.00 │
└───────────┴───────────┴──────────────┘
~~~

(5 rows — one per spending tier)

</details>

### Exercise 4: Product Performance Report

**Task:** Build a product performance report that shows for each product:
- Product name and category
- Total units sold
- Total revenue
- Number of unique customers who bought it
- Average quantity per order

Only include products from completed orders. Sort by revenue descending, show top 15.

```python
# TODO: Write your query joining order_items, orders, and products
# result = duckdb.sql("""...""")
# result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌────────────┬─────────────────┬────────────┬─────────────┬───────────────┬──────────────────┐
│  product   │    category     │ units_sold │   revenue   │ unique_buyers │ avg_qty_per_order│
│  varchar   │    varchar      │   int128   │   double    │     int64     │      double      │
├────────────┼─────────────────┼────────────┼─────────────┼───────────────┼──────────────────┤
│ Product_X  │ Electronics     │        ... │ xxxxxxxx.xx │           ... │             x.xx │
│ ...        │ ...             │        ... │        ...  │           ... │              ... │
└────────────┴─────────────────┴────────────┴─────────────┴───────────────┴──────────────────┘
~~~

(15 rows — top products by revenue)

</details>

---

## Cleanup

```python
# Remove generated files
import shutil
if os.path.exists('ecommerce'):
    shutil.rmtree('ecommerce')

print("Cleanup complete!")
```

---

## Summary

In this lab, you built management reports using the full analytical SQL pattern:

1. **Simple Aggregates** — Overall business metrics with COUNT, SUM, AVG
2. **GROUP BY** — Revenue by category, orders by region
3. **Multi-Level GROUP BY** — Revenue by region × category
4. **HAVING** — Filtering to high-revenue categories and high-volume customers
5. **JOINs + Aggregations** — Top-selling products, best per category
6. **Dashboard Query** — Complete regional performance report in one statement

**Key Takeaways:**
- **JOIN to assemble, GROUP BY to summarize** — this pattern drives 90% of analytical SQL
- **WHERE filters rows, HAVING filters groups** — use both in the same query
- **COUNT(DISTINCT ...)** is essential when joining one-to-many relationships
- **Multi-level GROUP BY** creates hierarchical summaries (region → category)
- **DuckDB handles complex aggregations efficiently** — no indexes needed

**What's Next:**

In **Week 07**, you'll learn **Window Functions** — aggregations that run across rows **without collapsing them**. This enables rankings, running totals, moving averages, and row-level comparisons that GROUP BY can't do.
