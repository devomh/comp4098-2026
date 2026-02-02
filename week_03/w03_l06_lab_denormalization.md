---
title: "Lab: Trade-offs and Star Schema Design"
week: 03
type: lab
tags: [denormalization, star schema, performance]
difficulty: intermediate
duration: "60 mins"
---

# Lab: Trade-offs and Star Schema Design

## 1. Prerequisites & Setup
*   **Context:** This lab explores the practical trade-offs between normalized and denormalized designs.
*   **Goal:** Analyze query performance differences and design a star schema.
*   **Concept Review:** Ensure you have read `w03_l06_concept_denormalization.md`.

### Environment Setup
Run this block first to set up the environment and create sample data.
```python
# Setup: Run this cell first (required for Colab)
# NOTE: Run cells in order. Variables from earlier sections are used later.
!pip install -q pandas duckdb mermaid-py

import pandas as pd
import duckdb
import time
from mermaid import Mermaid

pd.set_option('display.max_columns', None)
print("Setup complete! Ready for trade-off analysis.")
```

---

## 2. The Scenario: E-Commerce Analytics
You're a Data Scientist at an e-commerce company. The operational database is normalized (from Lesson 5). Now the business wants a dashboard showing:

1.  Total revenue by product category
2.  Top customers by purchase volume
3.  Monthly sales trends

Your job: decide whether to query the normalized tables directly or create a denormalized analytical layer.

### Create the Normalized Tables
```python
# Initialize DuckDB in-memory database
conn = duckdb.connect(':memory:')

# Create normalized tables
conn.execute("""
    CREATE TABLE customers (
        customer_id INTEGER PRIMARY KEY,
        name VARCHAR,
        email VARCHAR,
        city VARCHAR,
        segment VARCHAR  -- 'Consumer', 'Corporate', 'Home Office'
    )
""")

conn.execute("""
    CREATE TABLE products (
        product_id VARCHAR PRIMARY KEY,
        name VARCHAR,
        category VARCHAR,
        unit_price DECIMAL(10,2)
    )
""")

conn.execute("""
    CREATE TABLE orders (
        order_id INTEGER PRIMARY KEY,
        order_date DATE,
        customer_id INTEGER REFERENCES customers(customer_id)
    )
""")

conn.execute("""
    CREATE TABLE order_items (
        order_id INTEGER REFERENCES orders(order_id),
        product_id VARCHAR REFERENCES products(product_id),
        quantity INTEGER,
        PRIMARY KEY (order_id, product_id)
    )
""")

print("Normalized schema created!")
```

### Populate with Sample Data
```python
import random
from datetime import date, timedelta

# Seed for reproducibility
random.seed(42)

# Insert customers
customers = [
    (i, f"Customer_{i}", f"cust{i}@email.com",
     random.choice(['New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix']),
     random.choice(['Consumer', 'Corporate', 'Home Office']))
    for i in range(1, 1001)
]
conn.executemany("INSERT INTO customers VALUES (?, ?, ?, ?, ?)", customers)

# Insert products
categories = ['Electronics', 'Clothing', 'Home & Garden', 'Sports', 'Books']
products = [
    (f"P{i:04d}", f"Product_{i}", random.choice(categories), round(random.uniform(5, 500), 2))
    for i in range(1, 201)
]
conn.executemany("INSERT INTO products VALUES (?, ?, ?, ?)", products)

# Insert orders and order_items
start_date = date(2023, 1, 1)
order_id = 1

for _ in range(5000):  # 5000 orders
    order_date = start_date + timedelta(days=random.randint(0, 729))  # 2 years of data
    customer_id = random.randint(1, 1000)
    conn.execute("INSERT INTO orders VALUES (?, ?, ?)", (order_id, order_date, customer_id))

    # Each order has 1-5 items
    num_items = random.randint(1, 5)
    selected_products = random.sample(range(1, 201), num_items)
    for prod_num in selected_products:
        product_id = f"P{prod_num:04d}"
        quantity = random.randint(1, 10)
        conn.execute("INSERT INTO order_items VALUES (?, ?, ?)", (order_id, product_id, quantity))

    order_id += 1

print(f"Inserted 1000 customers, 200 products, 5000 orders")
print(f"Total order_items: {conn.execute('SELECT COUNT(*) FROM order_items').fetchone()[0]}")
```

<details>
<summary>Expected Output</summary>

~~~text
Inserted 1000 customers, 200 products, 5000 orders
Total order_items: ~15000 (varies due to random 1-5 items per order)
~~~

</details>

---

## 3. Step 1: Query the Normalized Schema

Let's run the business queries on the normalized tables.

> **Performance Note:** With only ~15K rows, both normalized and star schema queries will complete in milliseconds. DuckDB is highly optimized and the performance difference at this scale is minimal. In production systems with **millions of rows**, the star schema advantage becomes significant (10x+ speedup is common). We use this small dataset to demonstrate the *pattern*, not to prove performance claims.

### Query 1: Revenue by Category
```python
query_normalized = """
SELECT
    p.category,
    SUM(oi.quantity * p.unit_price) AS total_revenue
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
GROUP BY p.category
ORDER BY total_revenue DESC
"""

start = time.time()
result = conn.execute(query_normalized).df()
normalized_time = time.time() - start

print(f"Query time (normalized): {normalized_time:.4f} seconds")
print(result)

# Note: For more reliable timing with small queries, you could run multiple iterations:
# times = [timeit.timeit(lambda: conn.execute(query_normalized).df(), number=1) for _ in range(100)]
# print(f"Average time: {sum(times)/len(times):.4f} seconds")
```

<details>
<summary>Expected Output</summary>

~~~text
Query time (normalized): ~0.01-0.05 seconds
        category  total_revenue
0    Electronics      XXXXXX.XX
1       Clothing      XXXXXX.XX
2  Home & Garden      XXXXXX.XX
3         Sports      XXXXXX.XX
4          Books      XXXXXX.XX
~~~

</details>

### Query 2: Top 10 Customers by Revenue
```python
query_top_customers = """
SELECT
    c.customer_id,
    c.name,
    c.segment,
    SUM(oi.quantity * p.unit_price) AS total_spent
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
GROUP BY c.customer_id, c.name, c.segment
ORDER BY total_spent DESC
LIMIT 10
"""

start = time.time()
result = conn.execute(query_top_customers).df()
normalized_time_2 = time.time() - start

print(f"Query time (normalized): {normalized_time_2:.4f} seconds")
print(result)
```

<details>
<summary>Expected Output</summary>

~~~text
Query time (normalized): ~0.01-0.05 seconds
   customer_id          name      segment  total_spent
0          XXX  Customer_XXX  XXXXXXXXXX     XXXXX.XX
1          XXX  Customer_XXX  XXXXXXXXXX     XXXXX.XX
...
~~~

</details>

---

## 4. Step 2: Create a Denormalized Fact Table

Now let's create a star schema with a pre-joined fact table.

### Design the Star Schema
```python
# Note: dim_date will be added in Exercise 2
Mermaid("""
erDiagram
    fact_sales {
        int sale_id PK
        int order_id
        int date_key FK
        int customer_id FK
        varchar product_id FK
        int quantity
        decimal unit_price
        decimal line_total
    }
    dim_date {
        int date_key PK
        date full_date
        int year
        int month
        varchar month_name
        int quarter
    }
    dim_customer {
        int customer_id PK
        varchar name
        varchar city
        varchar segment
    }
    dim_product {
        varchar product_id PK
        varchar name
        varchar category
    }

    fact_sales }|--|| dim_date : "date_key"
    fact_sales }|--|| dim_customer : "customer_id"
    fact_sales }|--|| dim_product : "product_id"
""")
```

### Build the Fact Table
```python
# Create fact_sales with pre-computed values
conn.execute("""
    CREATE TABLE fact_sales AS
    SELECT
        ROW_NUMBER() OVER () AS sale_id,
        o.order_id,
        o.order_date,
        o.customer_id,
        oi.product_id,
        oi.quantity,
        p.unit_price,
        (oi.quantity * p.unit_price) AS line_total,
        EXTRACT(YEAR FROM o.order_date) AS year,
        EXTRACT(MONTH FROM o.order_date) AS month
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
""")

# Create dimension tables (simplified from normalized tables)
conn.execute("""
    CREATE TABLE dim_customer AS
    SELECT customer_id, name, city, segment
    FROM customers
""")

conn.execute("""
    CREATE TABLE dim_product AS
    SELECT product_id, name, category
    FROM products
""")

print("Star schema created!")
print(f"fact_sales rows: {conn.execute('SELECT COUNT(*) FROM fact_sales').fetchone()[0]}")
```

<details>
<summary>Expected Output</summary>

~~~text
Star schema created!
fact_sales rows: ~15000
~~~

</details>

---

## 5. Step 3: Compare Query Performance

### Revenue by Category (Star Schema)
```python
query_star = """
SELECT
    dp.category,
    SUM(fs.line_total) AS total_revenue
FROM fact_sales fs
JOIN dim_product dp ON fs.product_id = dp.product_id
GROUP BY dp.category
ORDER BY total_revenue DESC
"""

start = time.time()
result = conn.execute(query_star).df()
star_time = time.time() - start

print(f"Query time (star schema): {star_time:.4f} seconds")
print(f"Query time (normalized):  {normalized_time:.4f} seconds")
print(f"Speedup: {normalized_time/star_time:.2f}x" if star_time > 0 else "N/A")
print(result)
```

<details>
<summary>Expected Output</summary>

~~~text
Query time (star schema): ~0.005-0.02 seconds
Query time (normalized):  ~0.01-0.05 seconds
Speedup: 1.5-3x
~~~

With larger datasets, the difference becomes more pronounced.

</details>

### Top Customers (Star Schema)
```python
query_star_customers = """
SELECT
    dc.customer_id,
    dc.name,
    dc.segment,
    SUM(fs.line_total) AS total_spent
FROM fact_sales fs
JOIN dim_customer dc ON fs.customer_id = dc.customer_id
GROUP BY dc.customer_id, dc.name, dc.segment
ORDER BY total_spent DESC
LIMIT 10
"""

start = time.time()
result = conn.execute(query_star_customers).df()
star_time_2 = time.time() - start

print(f"Query time (star schema): {star_time_2:.4f} seconds")
print(f"Query time (normalized):  {normalized_time_2:.4f} seconds")
```

---

## 6. Step 4: Analyze the Trade-offs

### Storage Comparison
```python
# Compare storage (approximate via row counts and columns)
normalized_size = conn.execute("""
    SELECT
        (SELECT COUNT(*) FROM customers) AS customers,
        (SELECT COUNT(*) FROM products) AS products,
        (SELECT COUNT(*) FROM orders) AS orders,
        (SELECT COUNT(*) FROM order_items) AS order_items
""").df()

star_size = conn.execute("""
    SELECT
        (SELECT COUNT(*) FROM dim_customer) AS dim_customer,
        (SELECT COUNT(*) FROM dim_product) AS dim_product,
        (SELECT COUNT(*) FROM fact_sales) AS fact_sales
""").df()

print("Normalized schema row counts:")
print(normalized_size)
print("\nStar schema row counts:")
print(star_size)
```

<details>
<summary>Expected Output</summary>

~~~text
Normalized schema row counts:
   customers  products  orders  order_items
0       1000       200    5000        ~15000

Star schema row counts:
   dim_customer  dim_product  fact_sales
0          1000          200      ~15000
~~~

Row counts are similar, but `fact_sales` has more columns (redundant `unit_price`, pre-computed `line_total`, `year`, `month`).

**Column comparison:**
- Normalized: 4 tables × ~4 columns each = ~16 columns total
- Star: 3 tables, but `fact_sales` alone has 10 columns (including redundant data)

The storage overhead is the *price* of denormalization. Worth it when queries are frequent and updates are rare.

</details>

### Update Scenario Analysis
```python
# Scenario: Product P0001's price changes from $X to $Y
# How many rows need updating?

print("If Product P0001's price changes:")
print(f"  Normalized: 1 row (products table)")

p0001_orders = conn.execute("""
    SELECT COUNT(*) FROM fact_sales WHERE product_id = 'P0001'
""").fetchone()[0]
print(f"  Star Schema: {p0001_orders} rows (fact_sales) OR keep historical prices")
```

<details>
<summary>Discussion</summary>

This is the key trade-off:
*   **Normalized:** One update, always current, no history
*   **Star Schema:** Many updates needed, BUT often we *want* historical prices preserved

In analytics, keeping the original transaction price is often correct business logic ("What did we actually charge?").

</details>

---

## 7. Your Turn! (Exercises)

### Exercise 1: Monthly Sales Trend Query
**Task:** Write both normalized and star schema queries to get monthly revenue for 2024.

```python
# TODO: Normalized version (join orders, order_items, products)
query_monthly_normalized = """
-- Your query here
"""

# TODO: Star schema version (just fact_sales with year/month columns)
query_monthly_star = """
-- Your query here
"""
```

<details>
<summary>Expected Output</summary>

~~~python
# Normalized
query_monthly_normalized = """
SELECT
    EXTRACT(YEAR FROM o.order_date) AS year,
    EXTRACT(MONTH FROM o.order_date) AS month,
    SUM(oi.quantity * p.unit_price) AS revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
WHERE EXTRACT(YEAR FROM o.order_date) = 2024
GROUP BY 1, 2
ORDER BY 1, 2
"""

# Star Schema
query_monthly_star = """
SELECT
    year,
    month,
    SUM(line_total) AS revenue
FROM fact_sales
WHERE year = 2024
GROUP BY year, month
ORDER BY year, month
"""
~~~

The star schema query is simpler and doesn't require extracting date parts on the fly.

</details>

### Exercise 2: Add a Time Dimension
**Task:** Create a `dim_date` table that the fact table can join to for richer date analysis.

```python
# TODO: Create dim_date with columns: date_key (YYYYMMDD), full_date, year, month,
#       month_name, quarter, day_of_week, is_weekend

# Hint: Generate dates for 2023-2024
```

<details>
<summary>Expected Output</summary>

~~~python
# Step 1: Create the dimension table
conn.execute("""
    CREATE TABLE dim_date AS
    WITH date_series AS (
        SELECT CAST(range AS DATE) AS full_date
        FROM range(DATE '2023-01-01', DATE '2025-01-01', INTERVAL 1 DAY)
    )
    SELECT
        CAST(STRFTIME(full_date, '%Y%m%d') AS INTEGER) AS date_key,
        full_date,
        EXTRACT(YEAR FROM full_date) AS year,
        EXTRACT(MONTH FROM full_date) AS month,
        STRFTIME(full_date, '%B') AS month_name,
        EXTRACT(QUARTER FROM full_date) AS quarter,
        EXTRACT(DAYOFWEEK FROM full_date) AS day_of_week,
        CASE WHEN EXTRACT(DAYOFWEEK FROM full_date) IN (0, 6) THEN TRUE ELSE FALSE END AS is_weekend
    FROM date_series
""")

print(conn.execute("SELECT * FROM dim_date LIMIT 5").df())

# Step 2: Add date_key to fact_sales (in production, you'd design this from the start)
conn.execute("""
    ALTER TABLE fact_sales ADD COLUMN date_key INTEGER;
""")
conn.execute("""
    UPDATE fact_sales
    SET date_key = CAST(STRFTIME(order_date, '%Y%m%d') AS INTEGER);
""")

# Now you can join fact_sales to dim_date for rich date analysis!
print(conn.execute("""
    SELECT dd.month_name, dd.quarter, SUM(fs.line_total) as revenue
    FROM fact_sales fs
    JOIN dim_date dd ON fs.date_key = dd.date_key
    GROUP BY dd.month_name, dd.quarter
    ORDER BY dd.quarter, dd.month_name
    LIMIT 5
""").df())
~~~

</details>

### Exercise 3: When to Normalize vs. Denormalize
**Task:** For each scenario, recommend normalized or denormalized design and explain why.

| Scenario | Your Recommendation | Why? |
| :--- | :--- | :--- |
| Banking transaction system | | |
| Marketing dashboard | | |
| IoT sensor data for real-time monitoring | | |
| ML feature store for model training | | |
| User profile management | | |

<details>
<summary>Expected Answers</summary>

| Scenario | Recommendation | Why |
| :--- | :--- | :--- |
| Banking transaction system | **Normalized** | Data integrity critical, ACID compliance, frequent writes |
| Marketing dashboard | **Denormalized (Star)** | Read-heavy, aggregations, historical snapshots |
| IoT sensor data for real-time monitoring | **Denormalized (Time-series)** | Append-only writes (no updates), time-range queries, often uses specialized time-series DBs (InfluxDB, TimescaleDB) |
| ML feature store for model training | **Denormalized** | Pre-computed features, read-heavy during training |
| User profile management | **Normalized** | Frequent updates, data consistency important |

</details>

---

## 8. Summary
You have successfully:
1.  Built both **normalized** and **star schema** versions of the same data.
2.  Compared **query complexity** and **performance**.
3.  Analyzed **storage** and **update** trade-offs.
4.  Practiced designing **dimension tables** for analytical workloads.

**Key Takeaway:** Neither approach is universally better. Match your schema design to your workload:
*   **OLTP (transactional):** Normalize for integrity
*   **OLAP (analytical):** Denormalize for speed

In Week 4, we'll move to SQL implementation where you'll write `CREATE TABLE` statements to build these schemas in PostgreSQL.
