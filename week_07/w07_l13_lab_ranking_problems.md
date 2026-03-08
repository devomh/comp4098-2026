---
title: "Lab: Ranking Problems with Window Functions"
week: 07
type: lab
tags: [sql, duckdb, window-functions, ranking, analytics, python]
difficulty: intermediate
duration: "60 mins"
---

# Lab: Ranking Problems with Window Functions

## Prerequisites & Setup

**Before starting this lab, you should:**
- Review [w07_l13_concept_window_functions.md](w07_l13_concept_window_functions.md) for window function concepts
- Have completed [Lesson 12 Lab](../week_06/w06_l12_lab_summary_reports.md) for aggregation practice
- Understand OVER, PARTITION BY, ORDER BY, and the three ranking functions

**What you'll accomplish:**
In this lab, you'll use window functions on the ShopStream e-commerce dataset to build rankings, running totals, and percentage-of-total calculations — all without collapsing rows. You'll formalize the ROW_NUMBER pattern previewed in Lesson 12.

**Goal:** Master window functions for ranking, cumulative calculations, and the Top-N-per-group pattern.

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

You're still the data analyst at **ShopStream**. Your manager has seen the summary reports from Lesson 12 and now wants **rankings and trends**: Which products rank highest in each category? What is the cumulative revenue month by month? What percentage of regional revenue does each customer represent? These questions require window functions — analytics that keep every row while adding computed insights.

---

## Step 1: Generate & Load the Dataset

Same e-commerce dataset as Lessons 11–12 (self-contained for Colab).

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

## Step 2: Window Functions vs GROUP BY Side by Side

Let's see the difference between GROUP BY and window functions using the same data.

### GROUP BY: Revenue per Category (6 rows)

```python
result = duckdb.sql("""
    SELECT
        p.category,
        ROUND(SUM(oi.quantity * oi.unit_price), 2) AS category_revenue
    FROM order_items AS oi
    JOIN products AS p ON oi.product_id = p.id
    JOIN orders AS o ON oi.order_id = o.id
    WHERE o.status = 'completed'
    GROUP BY p.category
    ORDER BY category_revenue DESC
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌────────────────┬──────────────────┐
│    category    │ category_revenue │
│    varchar     │      double      │
├────────────────┼──────────────────┤
│ Electronics    │      xxxxxxxx.xx │
│ Home & Kitchen │      xxxxxxxx.xx │
│ Sports         │      xxxxxxxx.xx │
│ Clothing       │      xxxxxxxx.xx │
│ Toys           │      xxxxxxxx.xx │
│ Books          │      xxxxxxxx.xx │
└────────────────┴──────────────────┘
~~~

(6 rows — one per category, detail is gone)

</details>

### Window Function: Category Total Next to Each Product (200 rows)

```python
result = duckdb.sql("""
    SELECT
        p.name AS product,
        p.category,
        ROUND(SUM(oi.quantity * oi.unit_price), 2) AS product_revenue,
        ROUND(SUM(SUM(oi.quantity * oi.unit_price)) OVER (PARTITION BY p.category), 2) AS category_total
    FROM order_items AS oi
    JOIN products AS p ON oi.product_id = p.id
    JOIN orders AS o ON oi.order_id = o.id
    WHERE o.status = 'completed'
    GROUP BY p.id, p.name, p.category
    ORDER BY p.category, product_revenue DESC
    LIMIT 12
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌────────────┬──────────┬─────────────────┬────────────────┐
│  product   │ category │ product_revenue │ category_total │
│  varchar   │ varchar  │     double      │     double     │
├────────────┼──────────┼─────────────────┼────────────────┤
│ Product_X  │ Books    │       xxxxx.xx  │    xxxxxxxx.xx │
│ Product_Y  │ Books    │       xxxxx.xx  │    xxxxxxxx.xx │
│ ...        │ ...      │           ...   │           ...  │
└────────────┴──────────┴─────────────────┴────────────────┘
~~~

(Showing first 12 of 200 rows — every product keeps its row, with category total added)

</details>

**Key insight:** The `SUM(SUM(...)) OVER(PARTITION BY)` pattern first aggregates per product (inner SUM via GROUP BY), then computes the category total (outer SUM via window function). Every product row stays visible.

---

## Step 3: Ranking Products Within Categories

Let's apply all three ranking functions to the same data to see how they handle ties differently.

```python
result = duckdb.sql("""
    WITH product_revenue AS (
        SELECT
            p.name AS product,
            p.category,
            ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue
        FROM order_items AS oi
        JOIN products AS p ON oi.product_id = p.id
        JOIN orders AS o ON oi.order_id = o.id
        WHERE o.status = 'completed'
        GROUP BY p.id, p.name, p.category
    )
    SELECT
        product,
        category,
        revenue,
        ROW_NUMBER() OVER (PARTITION BY category ORDER BY revenue DESC) AS row_num,
        RANK()       OVER (PARTITION BY category ORDER BY revenue DESC) AS rank,
        DENSE_RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS dense_rank
    FROM product_revenue
    ORDER BY category, revenue DESC
    LIMIT 15
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌────────────┬──────────┬──────────┬─────────┬───────┬────────────┐
│  product   │ category │ revenue  │ row_num │ rank  │ dense_rank │
│  varchar   │ varchar  │  double  │  int64  │ int64 │   int64    │
├────────────┼──────────┼──────────┼─────────┼───────┼────────────┤
│ Product_X  │ Books    │ xxxxx.xx │       1 │     1 │          1 │
│ Product_Y  │ Books    │ xxxxx.xx │       2 │     2 │          2 │
│ Product_Z  │ Books    │ xxxxx.xx │       3 │     3 │          3 │
│ ...        │ ...      │      ... │     ... │   ... │        ... │
│ Product_A  │ Clothing │ xxxxx.xx │       1 │     1 │          1 │
│ ...        │ ...      │      ... │     ... │   ... │        ... │
└────────────┴──────────┴──────────┴─────────┴───────┴────────────┘
~~~

(First 15 rows — notice ROW_NUMBER resets to 1 for each new category)

</details>

**Observe:** Since revenues are unlikely to be exactly tied with decimal prices, all three functions produce the same numbers here. In Exercise 2, you'll see tie-handling differences with integer counts.

---

## Step 4: Top N Per Group Pattern

This formalizes the pattern previewed in [Lesson 12, Step 4](../week_06/w06_l12_lab_summary_reports.md): using CTE + ROW_NUMBER to get the **top 3 products per category**.

```python
result = duckdb.sql("""
    WITH product_ranked AS (
        SELECT
            p.name AS product,
            p.category,
            SUM(oi.quantity) AS total_units,
            ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue,
            ROW_NUMBER() OVER (
                PARTITION BY p.category
                ORDER BY SUM(oi.quantity * oi.unit_price) DESC
            ) AS rn
        FROM order_items AS oi
        JOIN products AS p ON oi.product_id = p.id
        JOIN orders AS o ON oi.order_id = o.id
        WHERE o.status = 'completed'
        GROUP BY p.id, p.name, p.category
    )
    SELECT product, category, total_units, revenue
    FROM product_ranked
    WHERE rn <= 3
    ORDER BY category, revenue DESC
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌────────────┬────────────────┬─────────────┬──────────┐
│  product   │    category    │ total_units │ revenue  │
│  varchar   │    varchar     │   int128    │  double  │
├────────────┼────────────────┼─────────────┼──────────┤
│ Product_X  │ Books          │         ... │ xxxxx.xx │
│ Product_Y  │ Books          │         ... │ xxxxx.xx │
│ Product_Z  │ Books          │         ... │ xxxxx.xx │
│ Product_A  │ Clothing       │         ... │ xxxxx.xx │
│ Product_B  │ Clothing       │         ... │ xxxxx.xx │
│ Product_C  │ Clothing       │         ... │ xxxxx.xx │
│ ...        │ ...            │         ... │      ... │
└────────────┴────────────────┴─────────────┴──────────┘
~~~

(18 rows — exactly 3 products per category)

</details>

**Why ROW_NUMBER instead of RANK?** ROW_NUMBER guarantees exactly N rows per group. RANK could return more than N if there are ties.

---

## Step 5: Customer Ranking by Region

Rank customers by total spending within their region, then show the top 5 per region.

```python
result = duckdb.sql("""
    WITH customer_spending AS (
        SELECT
            c.name AS customer,
            c.region,
            COUNT(DISTINCT o.id) AS order_count,
            ROUND(SUM(oi.quantity * oi.unit_price), 2) AS total_spent,
            RANK() OVER (
                PARTITION BY c.region
                ORDER BY SUM(oi.quantity * oi.unit_price) DESC
            ) AS region_rank
        FROM customers AS c
        JOIN orders AS o ON c.id = o.customer_id
        JOIN order_items AS oi ON o.id = oi.order_id
        WHERE o.status = 'completed'
        GROUP BY c.id, c.name, c.region
    )
    SELECT customer, region, order_count, total_spent, region_rank
    FROM customer_spending
    WHERE region_rank <= 5
    ORDER BY region, region_rank
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌────────────────┬───────────┬─────────────┬─────────────┬─────────────┐
│    customer    │  region   │ order_count │ total_spent │ region_rank │
│    varchar     │  varchar  │    int64    │   double    │    int64    │
├────────────────┼───────────┼─────────────┼─────────────┼─────────────┤
│ Customer_XXXX  │ Midwest   │         ... │   xxxxx.xx  │           1 │
│ Customer_XXXX  │ Midwest   │         ... │   xxxxx.xx  │           2 │
│ ...            │ ...       │         ... │        ...  │         ... │
│ Customer_XXXX  │ Northeast │         ... │   xxxxx.xx  │           1 │
│ ...            │ ...       │         ... │        ...  │         ... │
└────────────────┴───────────┴─────────────┴─────────────┴─────────────┘
~~~

(30 rows — top 5 customers in each of 6 regions)

</details>

**Note:** We use RANK here because if two customers spent exactly the same amount, they should share the same rank (competition-style ranking).

---

## Step 6: Running Totals

Calculate monthly cumulative revenue — a running total across all months.

```python
result = duckdb.sql("""
    SELECT
        DATE_TRUNC('month', o.order_date) AS month,
        ROUND(SUM(oi.quantity * oi.unit_price), 2) AS monthly_revenue,
        ROUND(SUM(SUM(oi.quantity * oi.unit_price)) OVER (
            ORDER BY DATE_TRUNC('month', o.order_date)
        ), 2) AS cumulative_revenue
    FROM orders AS o
    JOIN order_items AS oi ON o.id = oi.order_id
    WHERE o.status = 'completed'
    GROUP BY DATE_TRUNC('month', o.order_date)
    ORDER BY month
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌────────────┬─────────────────┬────────────────────┐
│   month    │ monthly_revenue │ cumulative_revenue │
│    date    │     double      │       double       │
├────────────┼─────────────────┼────────────────────┤
│ 2023-01-01 │     xxxxxxxx.xx │       xxxxxxxx.xx  │
│ 2023-02-01 │     xxxxxxxx.xx │       xxxxxxxx.xx  │
│ 2023-03-01 │     xxxxxxxx.xx │       xxxxxxxx.xx  │
│ ...        │            ...  │              ...   │
│ 2024-12-01 │     xxxxxxxx.xx │       xxxxxxxx.xx  │
└────────────┴─────────────────┴────────────────────┘
~~~

(24 rows — Jan 2023 through Dec 2024, cumulative total grows each month)

</details>

**The `SUM(SUM(...)) OVER(ORDER BY)` pattern:** The inner `SUM` aggregates line items into monthly totals (via GROUP BY). The outer `SUM ... OVER(ORDER BY month)` computes the running total across those monthly rows. This two-level pattern is essential when combining GROUP BY with window functions.

---

## Step 7: Percentage of Total

Calculate each product's share of its category's revenue.

```python
result = duckdb.sql("""
    WITH product_revenue AS (
        SELECT
            p.name AS product,
            p.category,
            ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue
        FROM order_items AS oi
        JOIN products AS p ON oi.product_id = p.id
        JOIN orders AS o ON oi.order_id = o.id
        WHERE o.status = 'completed'
        GROUP BY p.id, p.name, p.category
    )
    SELECT
        product,
        category,
        revenue,
        SUM(revenue) OVER (PARTITION BY category) AS category_total,
        ROUND(100.0 * revenue / SUM(revenue) OVER (PARTITION BY category), 2) AS pct_of_category,
        ROUND(100.0 * revenue / SUM(revenue) OVER (), 2) AS pct_of_total
    FROM product_revenue
    ORDER BY category, revenue DESC
    LIMIT 15
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌────────────┬──────────┬──────────┬────────────────┬─────────────────┬──────────────┐
│  product   │ category │ revenue  │ category_total │ pct_of_category │ pct_of_total │
│  varchar   │ varchar  │  double  │     double     │     double      │    double    │
├────────────┼──────────┼──────────┼────────────────┼─────────────────┼──────────────┤
│ Product_X  │ Books    │ xxxxx.xx │    xxxxxxxx.xx │            x.xx │         x.xx │
│ Product_Y  │ Books    │ xxxxx.xx │    xxxxxxxx.xx │            x.xx │         x.xx │
│ ...        │ ...      │      ... │           ...  │            ...  │          ... │
└────────────┴──────────┴──────────┴────────────────┴─────────────────┴──────────────┘
~~~

(First 15 of 200 rows — each product shows its share of category and of grand total)

</details>

**Two window scopes in one query:**
- `SUM(revenue) OVER (PARTITION BY category)` — category total (used for pct_of_category)
- `SUM(revenue) OVER ()` — grand total across all categories (used for pct_of_total)

---

## Your Turn! (Exercises)

### Exercise 1: Bottom 3 Products Per Category

**Task:** Find the **bottom 3** products per category by revenue (from completed orders). Use ROW_NUMBER with ascending order.

```python
# TODO: Write your query here
# Hint: ROW_NUMBER() OVER (PARTITION BY ... ORDER BY revenue ASC) AS rn
# result = duckdb.sql("""...""")
# result.show()
```

<details>
<summary>Hint</summary>

~~~sql
WITH product_ranked AS (
    SELECT
        p.name AS product,
        p.category,
        ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue,
        ROW_NUMBER() OVER (
            PARTITION BY p.category
            ORDER BY SUM(oi.quantity * oi.unit_price) ASC
        ) AS rn
    FROM order_items AS oi
    JOIN products AS p ON oi.product_id = p.id
    JOIN orders AS o ON oi.order_id = o.id
    WHERE o.status = 'completed'
    GROUP BY p.id, p.name, p.category
)
SELECT product, category, revenue
FROM product_ranked
WHERE rn <= 3
ORDER BY category, revenue ASC
~~~

</details>

<details>
<summary>Expected Output</summary>

~~~text
┌────────────┬────────────────┬──────────┐
│  product   │    category    │ revenue  │
│  varchar   │    varchar     │  double  │
├────────────┼────────────────┼──────────┤
│ Product_X  │ Books          │ xxxxx.xx │
│ Product_Y  │ Books          │ xxxxx.xx │
│ Product_Z  │ Books          │ xxxxx.xx │
│ Product_A  │ Clothing       │ xxxxx.xx │
│ ...        │ ...            │      ... │
└────────────┴────────────────┴──────────┘
~~~

(18 rows — bottom 3 products per category)

</details>

### Exercise 2: Customer Order Count Rank by Region

**Task:** Rank customers by their **number of completed orders** within each region using DENSE_RANK. Show the top 5 per region. Include the customer name, region, order count, and dense rank.

```python
# TODO: Write your query here
# Hint: DENSE_RANK() OVER (PARTITION BY region ORDER BY order_count DESC)
# result = duckdb.sql("""...""")
# result.show()
```

<details>
<summary>Hint</summary>

~~~sql
WITH customer_orders AS (
    SELECT
        c.name AS customer,
        c.region,
        COUNT(DISTINCT o.id) AS order_count,
        DENSE_RANK() OVER (
            PARTITION BY c.region
            ORDER BY COUNT(DISTINCT o.id) DESC
        ) AS order_rank
    FROM customers AS c
    JOIN orders AS o ON c.id = o.customer_id
    WHERE o.status = 'completed'
    GROUP BY c.id, c.name, c.region
)
SELECT customer, region, order_count, order_rank
FROM customer_orders
WHERE order_rank <= 5
ORDER BY region, order_rank
~~~

</details>

<details>
<summary>Expected Output</summary>

~~~text
┌────────────────┬───────────┬─────────────┬────────────┐
│    customer    │  region   │ order_count │ order_rank │
│    varchar     │  varchar  │    int64    │   int64    │
├────────────────┼───────────┼─────────────┼────────────┤
│ Customer_XXXX  │ Midwest   │          XX │          1 │
│ Customer_XXXX  │ Midwest   │          XX │          2 │
│ ...            │ ...       │         ... │        ... │
└────────────────┴───────────┴─────────────┴────────────┘
~~~

(Note: with DENSE_RANK, ties share ranks so you may get more than 30 rows total)

</details>

### Exercise 3: Monthly Revenue Rank by Category

**Task:** For each month-category combination, calculate the total revenue (completed orders) and rank the categories within each month using RANK. Show all 24 months × 6 categories = 144 rows.

```python
# TODO: Write your query here
# Hint: RANK() OVER (PARTITION BY month ORDER BY revenue DESC)
# result = duckdb.sql("""...""")
# result.show()
```

<details>
<summary>Hint</summary>

~~~sql
SELECT
    DATE_TRUNC('month', o.order_date) AS month,
    p.category,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue,
    RANK() OVER (
        PARTITION BY DATE_TRUNC('month', o.order_date)
        ORDER BY SUM(oi.quantity * oi.unit_price) DESC
    ) AS category_rank
FROM order_items AS oi
JOIN products AS p ON oi.product_id = p.id
JOIN orders AS o ON oi.order_id = o.id
WHERE o.status = 'completed'
GROUP BY DATE_TRUNC('month', o.order_date), p.category
ORDER BY month, category_rank
~~~

</details>

<details>
<summary>Expected Output</summary>

~~~text
┌────────────┬────────────────┬──────────┬───────────────┐
│   month    │    category    │ revenue  │ category_rank │
│    date    │    varchar     │  double  │     int64     │
├────────────┼────────────────┼──────────┼───────────────┤
│ 2023-01-01 │ Electronics    │ xxxxx.xx │             1 │
│ 2023-01-01 │ Home & Kitchen │ xxxxx.xx │             2 │
│ 2023-01-01 │ ...            │      ... │           ... │
│ 2023-02-01 │ ...            │      ... │           ... │
│ ...        │ ...            │      ... │           ... │
└────────────┴────────────────┴──────────┴───────────────┘
~~~

(144 rows — 24 months × 6 categories)

</details>

### Exercise 4: Running Average + 3-Month Moving Average

**Task:** Calculate the monthly revenue (completed orders), a **running average** (average of all months so far), and a **3-month moving average** (average of current month plus 2 prior months). Use `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW` for the moving average.

```python
# TODO: Write your query here
# Hint: AVG(...) OVER (ORDER BY month) for running avg
# Hint: AVG(...) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) for 3-month MA
# result = duckdb.sql("""...""")
# result.show()
```

<details>
<summary>Hint</summary>

~~~sql
SELECT
    DATE_TRUNC('month', o.order_date) AS month,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS monthly_revenue,
    ROUND(AVG(SUM(oi.quantity * oi.unit_price)) OVER (
        ORDER BY DATE_TRUNC('month', o.order_date)
    ), 2) AS running_avg,
    ROUND(AVG(SUM(oi.quantity * oi.unit_price)) OVER (
        ORDER BY DATE_TRUNC('month', o.order_date)
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS moving_avg_3m
FROM orders AS o
JOIN order_items AS oi ON o.id = oi.order_id
WHERE o.status = 'completed'
GROUP BY DATE_TRUNC('month', o.order_date)
ORDER BY month
~~~

</details>

<details>
<summary>Expected Output</summary>

~~~text
┌────────────┬─────────────────┬─────────────┬───────────────┐
│   month    │ monthly_revenue │ running_avg │ moving_avg_3m │
│    date    │     double      │   double    │    double     │
├────────────┼─────────────────┼─────────────┼───────────────┤
│ 2023-01-01 │     xxxxxxxx.xx │ xxxxxxxx.xx │   xxxxxxxx.xx │
│ 2023-02-01 │     xxxxxxxx.xx │ xxxxxxxx.xx │   xxxxxxxx.xx │
│ 2023-03-01 │     xxxxxxxx.xx │ xxxxxxxx.xx │   xxxxxxxx.xx │
│ ...        │            ...  │        ...  │          ...  │
│ 2024-12-01 │     xxxxxxxx.xx │ xxxxxxxx.xx │   xxxxxxxx.xx │
└────────────┴─────────────────┴─────────────┴───────────────┘
~~~

(24 rows — note: for Jan 2023 the moving avg equals the monthly revenue since there are no prior months)

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

In this lab, you applied window functions to the ShopStream e-commerce dataset:

1. **Window vs GROUP BY** — Compared collapsed summaries to row-preserving analytics
2. **Ranking Functions** — Applied ROW_NUMBER, RANK, and DENSE_RANK to product revenue
3. **Top N Per Group** — Used CTE + ROW_NUMBER to get exactly 3 products per category
4. **Customer Rankings** — Ranked customers by spending within their region
5. **Running Totals** — Computed cumulative revenue month by month using SUM OVER(ORDER BY)
6. **Percentage of Total** — Calculated each product's share using two different window scopes

**Key Takeaways:**
- **Window functions preserve rows** — unlike GROUP BY, every input row stays in the output
- **PARTITION BY = independent groups** — each partition's computation is isolated
- **ROW_NUMBER for Top-N** — guarantees exactly N rows per group (use CTE to filter)
- **`SUM(SUM(...)) OVER`** — the essential pattern for combining GROUP BY with window functions
- **Frame clauses** control the window — from running totals to moving averages

**What's Next:**

In **Lesson 14**, you'll learn **CTEs and offset functions** (LEAD/LAG) — building year-over-year growth comparisons, moving averages, and executive dashboard queries that combine everything from Weeks 06–07.
