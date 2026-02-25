---
title: "Lab: Multi-Table Queries with Joins"
week: 06
type: lab
tags: [sql, duckdb, joins, analytics, python]
difficulty: intermediate
duration: "60 mins"
---

# Lab: Multi-Table Queries with Joins

## Prerequisites & Setup

**Before starting this lab, you should:**
- Review [w06_l11_concept_complex_joins.md](w06_l11_concept_complex_joins.md) for join concepts
- Be comfortable with DuckDB basics from [Week 05 Lab](../week_05/w05_l10_lab_duckdb_querying.md)
- Understand SELECT, WHERE, ORDER BY, and LIMIT

**What you'll accomplish:**
In this lab, you'll build an e-commerce analytics dataset with four related tables, then use INNER JOIN, LEFT JOIN, RIGHT JOIN, and FULL OUTER JOIN to answer business questions. You'll chain multi-table joins and learn to spot common pitfalls.

**Goal:** Master SQL joins for multi-table analytical queries using DuckDB.

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
from mermaid import Mermaid
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

You're a data analyst at **ShopStream**, an online retail company. Your manager wants insights into customer behavior, product performance, and order patterns. The data lives in four tables:

```python
from mermaid import Mermaid

Mermaid("""
erDiagram
    customers ||--o{ orders : "places"
    orders ||--|{ order_items : "contains"
    products ||--o{ order_items : "appears in"

    customers {
        int id PK
        string name
        string city
        string region
        date signup_date
    }
    orders {
        int id PK
        int customer_id FK
        date order_date
        string status
    }
    order_items {
        int id PK
        int order_id FK
        int product_id FK
        int quantity
        float unit_price
    }
    products {
        int id PK
        string name
        string category
        float price
    }
""")
```

---

## Step 1: Generate & Load the Dataset

We'll generate a realistic e-commerce dataset and save it as Parquet files.

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

# --- Orders (50,000 rows — only ~4,500 of 5,000 customers order) ---
ordering_customers = random.sample(range(1, 5001), 4500)  # 500 customers never order
statuses = ['completed', 'completed', 'completed', 'completed',
            'pending', 'cancelled']  # ~67% completed, ~17% pending, ~17% cancelled

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

# --- Order Items (120,000 rows — 1-5 items per order) ---
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

print(f"customers:   {len(customers):>7,} rows")
print(f"products:    {len(products):>7,} rows")
print(f"orders:      {len(orders):>7,} rows")
print(f"order_items: {len(order_items):>7,} rows")
```

<details>
<summary>Expected Output</summary>

~~~text
customers:     5,000 rows
products:        200 rows
orders:       50,000 rows
order_items: 149,912 rows
~~~

(order_items count varies slightly due to random 1-5 items per order)

</details>

```python
# Load into DuckDB as named tables for cleaner queries
duckdb.sql("CREATE OR REPLACE TABLE customers AS SELECT * FROM 'ecommerce/customers.parquet'")
duckdb.sql("CREATE OR REPLACE TABLE products AS SELECT * FROM 'ecommerce/products.parquet'")
duckdb.sql("CREATE OR REPLACE TABLE orders AS SELECT * FROM 'ecommerce/orders.parquet'")
duckdb.sql("CREATE OR REPLACE TABLE order_items AS SELECT * FROM 'ecommerce/order_items.parquet'")

duckdb.sql("SHOW TABLES").show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌──────────────┐
│     name     │
│   varchar    │
├──────────────┤
│ customers    │
│ order_items  │
│ orders       │
│ products     │
└──────────────┘
~~~

</details>

---

## Step 2: Explore the Data

Before joining, get familiar with each table.

```python
# Quick look at each table
for table in ['customers', 'products', 'orders', 'order_items']:
    print(f"\n--- {table} ---")
    duckdb.sql(f"SELECT * FROM {table} LIMIT 3").show()
```

```python
# Row counts and column types
for table in ['customers', 'products', 'orders', 'order_items']:
    count = duckdb.sql(f"SELECT COUNT(*) AS rows FROM {table}").fetchone()[0]
    print(f"{table}: {count:,} rows")
```

<details>
<summary>Expected Output</summary>

~~~text
customers: 5,000 rows
products: 200 rows
orders: 50,000 rows
order_items: 149,912 rows
~~~

</details>

---

## Step 3: INNER JOIN — Customers Who Ordered

### Basic INNER JOIN

```python
# Join customers with their orders
result = duckdb.sql("""
    SELECT
        c.id AS customer_id,
        c.name,
        c.region,
        o.id AS order_id,
        o.order_date,
        o.status
    FROM customers AS c
    INNER JOIN orders AS o
        ON c.id = o.customer_id
    ORDER BY c.id, o.order_date
    LIMIT 10
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌─────────────┬────────────┬───────────┬──────────┬────────────┬───────────┐
│ customer_id │    name    │  region   │ order_id │ order_date │  status   │
│    int64    │  varchar   │  varchar  │  int64   │    date    │  varchar  │
├─────────────┼────────────┼───────────┼──────────┼────────────┼───────────┤
│           1 │ Customer_1 │ ...       │    ...   │ 2023-...   │ completed │
│         ... │ ...        │ ...       │    ...   │ ...        │ ...       │
└─────────────┴────────────┴───────────┴──────────┴────────────┴───────────┘
~~~

(10 rows showing customer-order pairs)

</details>

### Row Count Impact

```python
# Compare: how many rows does each side have vs the join result?
duckdb.sql("""
    SELECT
        (SELECT COUNT(*) FROM customers) AS total_customers,
        (SELECT COUNT(*) FROM orders) AS total_orders,
        (SELECT COUNT(*) FROM customers AS c INNER JOIN orders AS o ON c.id = o.customer_id) AS inner_join_rows
""").show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌─────────────────┬──────────────┬─────────────────┐
│ total_customers │ total_orders │ inner_join_rows │
│      int64      │    int64     │      int64      │
├─────────────────┼──────────────┼─────────────────┤
│            5000 │        50000 │           50000 │
└─────────────────┴──────────────┴─────────────────┘
~~~

The INNER JOIN has the same count as orders because every order has a valid customer_id (only 4,500 of 5,000 customers appear, but all 50,000 orders match).

</details>

**Key Insight:** INNER JOIN row count equals the number of matches. It can be less than either table (if some rows don't match) or more than either table (if one-to-many creates duplicates).

---

## Step 4: LEFT JOIN — All Customers, Even Without Orders

### Finding Customers with No Orders

```python
# LEFT JOIN: all customers + their orders (NULL if no orders)
result = duckdb.sql("""
    SELECT
        c.id AS customer_id,
        c.name,
        c.region,
        o.id AS order_id,
        o.status
    FROM customers AS c
    LEFT JOIN orders AS o
        ON c.id = o.customer_id
    WHERE o.id IS NULL
    ORDER BY c.id
    LIMIT 10
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌─────────────┬──────────────┬───────────┬──────────┬─────────┐
│ customer_id │     name     │  region   │ order_id │ status  │
│    int64    │   varchar    │  varchar  │  int64   │ varchar │
├─────────────┼──────────────┼───────────┼──────────┼─────────┤
│         ... │ Customer_... │ ...       │     NULL │ NULL    │
│         ... │ Customer_... │ ...       │     NULL │ NULL    │
│         ... │ ...          │ ...       │     NULL │ NULL    │
└─────────────┴──────────────┴───────────┴──────────┴─────────┘
~~~

(Showing customers who have never placed an order — NULL in order columns)

</details>

```python
# How many customers never ordered?
# Use SELECT DISTINCT in the subquery to deduplicate orders per customer,
# so each customer matches at most one row and COUNT(*) stays accurate.
result = duckdb.sql("""
    SELECT
        COUNT(*) AS total_customers,
        SUM(CASE WHEN o.customer_id IS NULL THEN 1 ELSE 0 END) AS never_ordered,
        SUM(CASE WHEN o.customer_id IS NOT NULL THEN 1 ELSE 0 END) AS ordered_at_least_once
    FROM customers AS c
    LEFT JOIN (
        SELECT DISTINCT customer_id
        FROM orders
    ) AS o ON c.id = o.customer_id
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌─────────────────┬───────────────┬───────────────────────┐
│ total_customers │ never_ordered │ ordered_at_least_once │
│      int64      │    int64      │        int64          │
├─────────────────┼───────────────┼───────────────────────┤
│            5000 │           500 │                  4500 │
└─────────────────┴───────────────┴───────────────────────┘
~~~

500 customers (10%) have never placed an order — these rows only appear in LEFT JOIN, not INNER JOIN.

</details>

### LEFT JOIN vs INNER JOIN — Side by Side

```python
# Compare LEFT vs INNER join counts
duckdb.sql("""
    SELECT
        'INNER JOIN' AS join_type,
        COUNT(DISTINCT c.id) AS unique_customers
    FROM customers AS c
    INNER JOIN orders AS o ON c.id = o.customer_id
    UNION ALL
    SELECT
        'LEFT JOIN' AS join_type,
        COUNT(DISTINCT c.id) AS unique_customers
    FROM customers AS c
    LEFT JOIN orders AS o ON c.id = o.customer_id
""").show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌────────────┬──────────────────┐
│ join_type  │ unique_customers │
│  varchar   │      int64       │
├────────────┼──────────────────┤
│ INNER JOIN │             4500 │
│ LEFT JOIN  │             5000 │
└────────────┴──────────────────┘
~~~

LEFT JOIN preserves all 5,000 customers. INNER JOIN shows only the 4,500 who placed orders.

</details>

---

## Step 5: Multi-Table Joins — The Complete Order Detail

Now let's chain all four tables together to build a complete order detail view.

```python
# Complete order details: customer → order → items → product
result = duckdb.sql("""
    SELECT
        c.name AS customer,
        c.region,
        o.id AS order_id,
        o.order_date,
        o.status,
        p.name AS product,
        p.category,
        oi.quantity,
        oi.unit_price,
        oi.quantity * oi.unit_price AS line_total
    FROM customers AS c
    INNER JOIN orders AS o
        ON c.id = o.customer_id
    INNER JOIN order_items AS oi
        ON o.id = oi.order_id
    INNER JOIN products AS p
        ON oi.product_id = p.id
    ORDER BY o.id, oi.id
    LIMIT 10
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌────────────┬───────────┬──────────┬────────────┬───────────┬────────────┬─────────────┬──────────┬────────────┬────────────┐
│  customer  │  region   │ order_id │ order_date │  status   │  product   │  category   │ quantity │ unit_price │ line_total │
│  varchar   │  varchar  │  int64   │    date    │  varchar  │  varchar   │   varchar   │  int64   │   double   │   double   │
├────────────┼───────────┼──────────┼────────────┼───────────┼────────────┼─────────────┼──────────┼────────────┼────────────┤
│ Customer_… │ ...       │        1 │ 2023-...   │ completed │ Product_…  │ Electronics │        2 │     129.99 │     259.98 │
│ ...        │ ...       │      ... │ ...        │ ...       │ ...        │ ...         │      ... │        ... │        ... │
└────────────┴───────────┴──────────┴────────────┴───────────┴────────────┴─────────────┴──────────┴────────────┴────────────┘
~~~

(10 rows from the 4-table join)

</details>

```python
# How many rows does the 4-table join produce?
result = duckdb.sql("""
    SELECT COUNT(*) AS total_detail_rows
    FROM customers AS c
    INNER JOIN orders AS o ON c.id = o.customer_id
    INNER JOIN order_items AS oi ON o.id = oi.order_id
    INNER JOIN products AS p ON oi.product_id = p.id
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌───────────────────┐
│ total_detail_rows │
│       int64       │
├───────────────────┤
│            149912 │
└───────────────────┘
~~~

The row count matches order_items because each order item maps to exactly one order, one customer, and one product.

</details>

---

## Step 6: RIGHT JOIN and FULL OUTER JOIN

### RIGHT JOIN — Products That Were Never Ordered

With 50,000 orders spanning all 200 products, every existing product has been ordered. Let's simulate a realistic business event: three new products were added to the catalog after the holiday season and have no order history yet.

```python
# Simulate newly launched products — added to catalog after orders were placed
duckdb.sql("""
    INSERT INTO products VALUES
        (201, 'SmartWatch_Pro',    'Electronics',    899.99),
        (202, 'AirPurifier_Home', 'Home & Kitchen', 149.99),
        (203, 'TrailRunner_X',    'Sports',          59.99)
""")

print("3 new products added to catalog (no order history yet).")
```

```python
# RIGHT JOIN: all products, even those with no matching order_items
result = duckdb.sql("""
    SELECT
        p.id AS product_id,
        p.name AS product,
        p.category,
        COUNT(oi.id) AS times_ordered
    FROM order_items AS oi
    RIGHT JOIN products AS p
        ON oi.product_id = p.id
    GROUP BY p.id, p.name, p.category
    HAVING COUNT(oi.id) = 0
    ORDER BY p.id
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌────────────┬──────────────────┬────────────────┬───────────────┐
│ product_id │     product      │    category    │ times_ordered │
│   int64    │     varchar      │    varchar     │     int64     │
├────────────┼──────────────────┼────────────────┼───────────────┤
│        201 │ SmartWatch_Pro   │ Electronics    │             0 │
│        202 │ AirPurifier_Home │ Home & Kitchen │             0 │
│        203 │ TrailRunner_X    │ Sports         │             0 │
└────────────┴──────────────────┴────────────────┴───────────────┘
~~~

The three new products appear because RIGHT JOIN preserves every row from the right table (`products`), even when no `order_items` row matches. `COUNT(oi.id)` returns 0 (not NULL) because `COUNT` ignores NULLs — a useful idiom for "zero vs. missing".

</details>

**Key Insight:** `FROM order_items RIGHT JOIN products` is equivalent to `FROM products LEFT JOIN order_items`. In practice, most teams prefer LEFT JOIN for readability; RIGHT JOIN is useful when you want to emphasize that the right table drives the result set.

### FULL OUTER JOIN — Regional Targets vs. Actual Sales

FULL OUTER JOIN is the right tool when two tables may each contain rows the other lacks. A classic business scenario: comparing a planning table against actual results, where mismatches exist on **both** sides.

```python
# Sales targets by region — two deliberate mismatches:
#   'International' has a target but no customers in ShopStream
#   'Northwest' has customers and real sales but no target was set
duckdb.sql("""
    CREATE OR REPLACE TABLE regional_targets AS
    SELECT * FROM (VALUES
        ('Northeast',    500000),
        ('Southeast',    450000),
        ('Midwest',      400000),
        ('West',         600000),
        ('Southwest',    350000),
        ('International', 200000)
    ) AS t(region, sales_target)
""")
```

```python
# Actual revenue by region — computed from the real ShopStream data
duckdb.sql("""
    CREATE OR REPLACE TABLE actual_regional_sales AS
    SELECT
        c.region,
        ROUND(SUM(oi.quantity * oi.unit_price), 2) AS actual_revenue
    FROM customers AS c
    INNER JOIN orders AS o       ON c.id = o.customer_id
    INNER JOIN order_items AS oi ON o.id = oi.order_id
    GROUP BY c.region
""")

duckdb.sql("SELECT * FROM actual_regional_sales ORDER BY region").show()
```

```python
# FULL OUTER JOIN: match every target row to every sales row — mismatches appear on both sides
result = duckdb.sql("""
    SELECT
        COALESCE(t.region, s.region) AS region,
        t.sales_target,
        s.actual_revenue,
        CASE
            WHEN t.sales_target IS NULL   THEN 'No target set'
            WHEN s.actual_revenue IS NULL THEN 'No sales recorded'
            WHEN s.actual_revenue >= t.sales_target THEN 'On target'
            ELSE 'Below target'
        END AS status
    FROM regional_targets AS t
    FULL OUTER JOIN actual_regional_sales AS s
        ON t.region = s.region
    ORDER BY COALESCE(t.region, s.region)
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌───────────────┬──────────────┬────────────────┬───────────────────┐
│    region     │ sales_target │ actual_revenue │      status       │
│    varchar    │    int64     │    double      │      varchar      │
├───────────────┼──────────────┼────────────────┼───────────────────┤
│ International │       200000 │           NULL │ No sales recorded │
│ Midwest       │       400000 │      ...       │ On target / Below │
│ Northeast     │       500000 │      ...       │ On target / Below │
│ Northwest     │         NULL │      ...       │ No target set     │
│ Southeast     │       450000 │      ...       │ On target / Below │
│ Southwest     │       350000 │      ...       │ On target / Below │
│ West          │       600000 │      ...       │ On target / Below │
└───────────────┴──────────────┴────────────────┴───────────────────┘
~~~

- **International**: has a target but zero customers in ShopStream → `actual_revenue` is NULL (orphan on the left)
- **Northwest**: has real customers and sales but no target was set → `sales_target` is NULL (orphan on the right)
- A LEFT JOIN would drop International; a RIGHT JOIN would drop Northwest. Only FULL OUTER JOIN surfaces both.

</details>

```python
# Clean up intermediate tables
duckdb.sql("DROP TABLE IF EXISTS regional_targets")
duckdb.sql("DROP TABLE IF EXISTS actual_regional_sales")
```

---

## Step 7: Join Pitfalls Demo

### Pitfall: Cartesian Product from Missing ON Clause

```python
# WARNING: This produces a Cartesian product — every customer × every product!
# We'll limit it to demonstrate the problem safely
result = duckdb.sql("""
    SELECT COUNT(*) AS cartesian_count
    FROM (SELECT * FROM customers LIMIT 10) AS c
    CROSS JOIN (SELECT * FROM products LIMIT 10) AS p
""")
result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌─────────────────┐
│ cartesian_count │
│      int64      │
├─────────────────┤
│             100 │
└─────────────────┘
~~~

10 × 10 = 100 rows. At full scale, 5,000 × 200 = 1,000,000 rows! Always use an ON clause.

</details>

### Pitfall: Counting with One-to-Many Joins

```python
# WRONG: Counting rows after a 1:N join overcounts
wrong_count = duckdb.sql("""
    SELECT COUNT(*) AS wrong_customer_count
    FROM customers AS c
    INNER JOIN orders AS o ON c.id = o.customer_id
""").fetchone()[0]

# RIGHT: Use COUNT(DISTINCT ...) or count before joining
right_count = duckdb.sql("""
    SELECT COUNT(DISTINCT c.id) AS correct_customer_count
    FROM customers AS c
    INNER JOIN orders AS o ON c.id = o.customer_id
""").fetchone()[0]

print(f"COUNT(*) after join:          {wrong_count:>6,}  (wrong — counts order rows)")
print(f"COUNT(DISTINCT c.id):         {right_count:>6,}  (correct — counts unique customers)")
```

<details>
<summary>Expected Output</summary>

~~~text
COUNT(*) after join:          50,000  (wrong — counts order rows)
COUNT(DISTINCT c.id):          4,500  (correct — counts unique customers)
~~~

</details>

---

## Your Turn! (Exercises)

### Exercise 1: Customers Who Never Ordered

**Task:** Write a query that returns the `id`, `name`, `city`, and `region` of all customers who have **never placed an order**. Sort by customer id.

*Hint: Use LEFT JOIN + IS NULL pattern.*

```python
# TODO: Write your query here
# result = duckdb.sql("""...""")
# result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌──────┬──────────────┬──────────────┬───────────┐
│  id  │     name     │     city     │  region   │
│ int64│   varchar    │   varchar    │  varchar  │
├──────┼──────────────┼──────────────┼───────────┤
│  ... │ Customer_... │ ...          │ ...       │
│  ... │ ...          │ ...          │ ...       │
└──────┴──────────────┴──────────────┴───────────┘
~~~

(500 rows — the customers who never ordered)

</details>

### Exercise 2: Products with Total Quantity Sold

**Task:** List all products with their `name`, `category`, and `total_quantity_sold`. Include products that were never sold (show 0). Sort by total quantity descending.

*Hint: LEFT JOIN products to order_items, use COALESCE for the zero.*

```python
# TODO: Write your query here
# result = duckdb.sql("""...""")
# result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌────────────┬─────────────────┬─────────────────────┐
│    name    │    category     │ total_quantity_sold  │
│  varchar   │    varchar      │       int64          │
├────────────┼─────────────────┼─────────────────────┤
│ Product_X  │ Electronics     │                3842  │
│ Product_Y  │ Clothing        │                3756  │
│ ...        │ ...             │                 ... │
└────────────┴─────────────────┴─────────────────────┘
~~~

(200 rows — all products)

</details>

### Exercise 3: Complete Order Receipt

**Task:** Build an order receipt for `order_id = 1`. Show: customer name, order date, status, each product name, quantity, unit price, and line total (quantity × unit_price). Also show the order grand total.

*Hint: Join all four tables, filter to order_id = 1.*

```python
# TODO: Write a query for the receipt line items
# result = duckdb.sql("""...""")
# result.show()

# TODO: Write a query for the grand total
# total = duckdb.sql("""...""")
# total.show()
```

<details>
<summary>Expected Output</summary>

~~~text
Receipt for Order #1:
┌────────────┬────────────┬───────────┬────────────┬──────────┬────────────┬────────────┐
│  customer  │ order_date │  status   │  product   │ quantity │ unit_price │ line_total │
│  varchar   │    date    │  varchar  │  varchar   │  int64   │   double   │   double   │
├────────────┼────────────┼───────────┼────────────┼──────────┼────────────┼────────────┤
│ Customer_… │ 2023-...   │ ...       │ Product_…  │        … │      …     │      …     │
│ ...        │ ...        │ ...       │ ...        │      ... │        ... │        ... │
└────────────┴────────────┴───────────┴────────────┴──────────┴────────────┴────────────┘

Grand total: $XXX.XX
~~~

</details>

### Exercise 4: Regional Order Comparison

**Task:** Write a query that shows, for each `region`:
- Total number of orders
- Number of **distinct** customers who ordered
- Average orders per customer (total orders / distinct customers)

Sort by total orders descending.

*Hint: Join customers with orders, GROUP BY region.*

```python
# TODO: Write your query here
# result = duckdb.sql("""...""")
# result.show()
```

<details>
<summary>Expected Output</summary>

~~~text
┌───────────┬──────────────┬───────────────────┬────────────────────┐
│  region   │ total_orders │ unique_customers  │ avg_orders_per_cust│
│  varchar  │    int64     │      int64        │       double       │
├───────────┼──────────────┼───────────────────┼────────────────────┤
│ ...       │         ...  │              ...  │               ...  │
└───────────┴──────────────┴───────────────────┴────────────────────┘
~~~

(6 rows — one per region)

</details>

---

## Summary

In this lab, you practiced:

1. **INNER JOIN** — Matching customers to their orders (only matched rows)
2. **LEFT JOIN** — Finding customers who never ordered (preserving all left rows)
3. **Multi-table joins** — Chaining 4 tables (customers → orders → order_items → products) for complete order details
4. **RIGHT JOIN** — Finding newly launched products with no order history
5. **FULL OUTER JOIN** — Reconciling regional sales targets against actual revenue (surfacing orphans on both sides)
6. **Join pitfalls** — Cartesian products, COUNT(*) overcounting, NULL behavior

**Key Takeaways:**
- **LEFT JOIN + IS NULL** is the standard pattern for "find missing" queries
- **INNER JOIN** reduces row count; **LEFT/RIGHT JOIN** preserves all rows from one side (duplicating when multiple matches exist)
- **FULL OUTER JOIN** is the reconciliation tool: use it when both tables can have rows the other lacks
- **Always use table aliases** and **explicit column prefixes** in multi-table queries
- **COUNT(DISTINCT ...)** is essential after one-to-many joins