---
title: "Lab: MongoDB Aggregation Pipeline"
week: 10
type: lab
tags: [mongodb, aggregation, pipeline, pymongo, analytics]
difficulty: intermediate
duration: "55 mins"
---

# Lab: MongoDB Aggregation Pipeline

## 1. Prerequisites & Setup

**Before starting this lab, you should:**
*   Review [w10_l20_concept_advanced_querying.md](w10_l20_concept_advanced_querying.md) for aggregation pipeline concepts
*   Complete [w10_l19_lab_mongodb_crud.md](w10_l19_lab_mongodb_crud.md) for basic CRUD experience

**What you'll accomplish:**
In this lab, you'll load an e-commerce orders dataset into MongoDB and use the aggregation pipeline to answer analytical questions — computing revenue by city, finding best-selling products, and tracking order trends.

---

### Environment Setup

Since Colab environments are ephemeral, we need to reinstall MongoDB and load our data fresh. Run all three setup cells below.

```python
%%bash
# Install MongoDB 7.x (Community Edition)
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
  gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg
echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | \
  tee /etc/apt/sources.list.d/mongodb-org-7.0.list
apt-get update -qq
apt-get install -y -qq mongodb-org > /dev/null
echo "MongoDB installed: $(mongod --version | head -1)"
```

```python
%%bash
mkdir -p /data/db
mongod --dbpath /data/db --fork --logpath /var/log/mongod.log --bind_ip 127.0.0.1
sleep 2
mongosh --quiet --eval "db.runCommand({ ping: 1 })"
```

```python
# Setup: Install pymongo and connect (run cells above first)
!pip install -q pymongo
```

```python
from pymongo import MongoClient
from datetime import datetime

client = MongoClient("mongodb://127.0.0.1:27017/")
db = client["ecommerce_db"]
orders = db["orders"]

print(f"Connected to MongoDB {client.server_info()['version']}")
```

<details>
<summary>Expected Output</summary>

~~~text
MongoDB installed: db version v7.0.x
...
{ ok: 1 }
Connected to MongoDB 7.0.x
~~~

</details>

---

## 2. Load the Dataset

We'll use an e-commerce orders dataset with embedded customer info and line items — the document model you designed in Week 9.

```python
# Load e-commerce orders
orders.drop()
orders.insert_many([
    {
        "order_id": "ORD-001",
        "customer": {"name": "Ana Torres", "city": "Humacao", "segment": "Premium"},
        "order_date": datetime(2026, 3, 1),
        "status": "delivered",
        "items": [
            {"product": "Laptop Pro 16", "category": "Electronics", "quantity": 1, "price": 1299.99},
            {"product": "Wireless Mouse", "category": "Electronics", "quantity": 1, "price": 29.99}
        ]
    },
    {
        "order_id": "ORD-002",
        "customer": {"name": "Luis Rivera", "city": "San Juan", "segment": "Standard"},
        "order_date": datetime(2026, 3, 5),
        "status": "delivered",
        "items": [
            {"product": "Mechanical Keyboard", "category": "Electronics", "quantity": 1, "price": 89.99},
            {"product": "Desk Lamp", "category": "Office", "quantity": 2, "price": 34.99}
        ]
    },
    {
        "order_id": "ORD-003",
        "customer": {"name": "Maria Santos", "city": "Ponce", "segment": "Premium"},
        "order_date": datetime(2026, 3, 8),
        "status": "delivered",
        "items": [
            {"product": "Ergonomic Chair", "category": "Furniture", "quantity": 1, "price": 449.99},
            {"product": "Standing Desk", "category": "Furniture", "quantity": 1, "price": 599.99}
        ]
    },
    {
        "order_id": "ORD-004",
        "customer": {"name": "Carlos Diaz", "city": "San Juan", "segment": "Standard"},
        "order_date": datetime(2026, 3, 10),
        "status": "shipped",
        "items": [
            {"product": "Laptop Pro 16", "category": "Electronics", "quantity": 1, "price": 1299.99}
        ]
    },
    {
        "order_id": "ORD-005",
        "customer": {"name": "Sofia Ruiz", "city": "Humacao", "segment": "Premium"},
        "order_date": datetime(2026, 3, 12),
        "status": "delivered",
        "items": [
            {"product": "Wireless Mouse", "category": "Electronics", "quantity": 2, "price": 29.99},
            {"product": "USB-C Hub", "category": "Electronics", "quantity": 1, "price": 45.00},
            {"product": "Notebook Pack (3)", "category": "Office", "quantity": 3, "price": 8.99}
        ]
    },
    {
        "order_id": "ORD-006",
        "customer": {"name": "Ana Torres", "city": "Humacao", "segment": "Premium"},
        "order_date": datetime(2026, 3, 15),
        "status": "pending",
        "items": [
            {"product": "Standing Desk", "category": "Furniture", "quantity": 1, "price": 599.99},
            {"product": "Desk Lamp", "category": "Office", "quantity": 1, "price": 34.99}
        ]
    },
    {
        "order_id": "ORD-007",
        "customer": {"name": "Luis Rivera", "city": "San Juan", "segment": "Standard"},
        "order_date": datetime(2026, 3, 18),
        "status": "delivered",
        "items": [
            {"product": "Mechanical Keyboard", "category": "Electronics", "quantity": 2, "price": 89.99}
        ]
    },
    {
        "order_id": "ORD-008",
        "customer": {"name": "Pedro Martinez", "city": "Mayaguez", "segment": "Standard"},
        "order_date": datetime(2026, 3, 20),
        "status": "delivered",
        "items": [
            {"product": "Laptop Pro 16", "category": "Electronics", "quantity": 1, "price": 1299.99},
            {"product": "Ergonomic Chair", "category": "Furniture", "quantity": 1, "price": 449.99},
            {"product": "Desk Lamp", "category": "Office", "quantity": 1, "price": 34.99}
        ]
    },
    {
        "order_id": "ORD-009",
        "customer": {"name": "Maria Santos", "city": "Ponce", "segment": "Premium"},
        "order_date": datetime(2026, 3, 22),
        "status": "shipped",
        "items": [
            {"product": "Wireless Mouse", "category": "Electronics", "quantity": 1, "price": 29.99},
            {"product": "Mechanical Keyboard", "category": "Electronics", "quantity": 1, "price": 89.99}
        ]
    },
    {
        "order_id": "ORD-010",
        "customer": {"name": "Sofia Ruiz", "city": "Humacao", "segment": "Premium"},
        "order_date": datetime(2026, 3, 25),
        "status": "delivered",
        "items": [
            {"product": "Standing Desk", "category": "Furniture", "quantity": 1, "price": 599.99}
        ]
    }
])

print(f"Loaded {orders.count_documents({})} orders")

# Quick overview
for doc in orders.find({}, {"order_id": 1, "customer.name": 1, "status": 1, "_id": 0}):
    print(f"  {doc['order_id']}: {doc['customer']['name']} ({doc['status']})")
```

<details>
<summary>Expected Output</summary>

~~~text
Loaded 10 orders
  ORD-001: Ana Torres (delivered)
  ORD-002: Luis Rivera (delivered)
  ORD-003: Maria Santos (delivered)
  ORD-004: Carlos Diaz (shipped)
  ORD-005: Sofia Ruiz (delivered)
  ORD-006: Ana Torres (pending)
  ORD-007: Luis Rivera (delivered)
  ORD-008: Pedro Martinez (delivered)
  ORD-009: Maria Santos (shipped)
  ORD-010: Sofia Ruiz (delivered)
~~~

</details>

---

## 3. Querying Nested Documents and Arrays

Before building pipelines, let's practice the query operators from the concept lesson.

### Dot Notation for Nested Fields

```python
# Orders from Humacao (nested field: customer.city)
print("=== Orders from Humacao ===")
for doc in orders.find({"customer.city": "Humacao"}, {"order_id": 1, "customer.name": 1, "_id": 0}):
    print(f"  {doc['order_id']}: {doc['customer']['name']}")

# Orders from Premium customers
print("\n=== Premium customers ===")
for doc in orders.find({"customer.segment": "Premium"}, {"order_id": 1, "customer.name": 1, "_id": 0}):
    print(f"  {doc['order_id']}: {doc['customer']['name']}")
```

<details>
<summary>Expected Output</summary>

~~~text
=== Orders from Humacao ===
  ORD-001: Ana Torres
  ORD-005: Sofia Ruiz
  ORD-006: Ana Torres
  ORD-010: Sofia Ruiz

=== Premium customers ===
  ORD-001: Ana Torres
  ORD-003: Maria Santos
  ORD-005: Sofia Ruiz
  ORD-006: Ana Torres
  ORD-009: Maria Santos
  ORD-010: Sofia Ruiz
~~~

</details>

### Array and Logical Queries

```python
# Orders containing a Laptop Pro 16 (query array of sub-documents)
print("=== Orders with Laptop Pro 16 ===")
for doc in orders.find(
    {"items.product": "Laptop Pro 16"},
    {"order_id": 1, "customer.name": 1, "_id": 0}
):
    print(f"  {doc['order_id']}: {doc['customer']['name']}")

# $or: orders from Humacao OR Ponce
print("\n=== Humacao or Ponce ===")
for doc in orders.find(
    {"$or": [{"customer.city": "Humacao"}, {"customer.city": "Ponce"}]},
    {"order_id": 1, "customer.city": 1, "_id": 0}
):
    print(f"  {doc['order_id']}: {doc['customer']['city']}")

# Delivered orders from Premium customers (implicit $and)
print("\n=== Delivered + Premium ===")
count = orders.count_documents({"status": "delivered", "customer.segment": "Premium"})
print(f"  {count} orders match")
```

<details>
<summary>Expected Output</summary>

~~~text
=== Orders with Laptop Pro 16 ===
  ORD-001: Ana Torres
  ORD-004: Carlos Diaz
  ORD-008: Pedro Martinez

=== Humacao or Ponce ===
  ORD-001: Humacao
  ORD-003: Ponce
  ORD-005: Humacao
  ORD-006: Humacao
  ORD-009: Ponce
  ORD-010: Humacao

=== Delivered + Premium ===
  4 orders match
~~~

</details>

### `$elemMatch`: Matching Within Array Elements

When you need multiple conditions to match the *same* array element, use `$elemMatch`. Dot notation checks conditions independently across elements — `$elemMatch` ensures they apply to one element.

```python
# Dot notation: finds orders where ANY item is Electronics AND ANY item has qty > 1
# These conditions can match DIFFERENT items in the array
dot_count = orders.count_documents({
    "items.category": "Electronics",
    "items.quantity": {"$gt": 1}
})

# $elemMatch: finds orders where a SINGLE item is Electronics with qty > 1
elem_count = orders.count_documents({
    "items": {"$elemMatch": {"category": "Electronics", "quantity": {"$gt": 1}}}
})

print("=== $elemMatch vs. dot notation ===")
print(f"  Dot notation (independent conditions): {dot_count} orders")
print(f"  $elemMatch (same element):             {elem_count} orders")
```

<details>
<summary>Expected Output</summary>

~~~text
=== $elemMatch vs. dot notation ===
  Dot notation (independent conditions): 3 orders
  $elemMatch (same element):             2 orders
~~~

Dot notation returns 3 because it matches any order where *any* item is Electronics AND *any* item has qty > 1 — these can be different items. ORD-002 matches because Mechanical Keyboard is Electronics *and* Desk Lamp has qty 2 (different items!). `$elemMatch` returns only 2 — orders where a single Electronics item has quantity > 1 (ORD-005: Wireless Mouse qty 2, ORD-007: Mechanical Keyboard qty 2). ORD-002 is excluded because no single item is both Electronics and qty > 1.

</details>

---

## 4. Aggregation Pipeline: First Steps

### Pipeline 1: Count Orders by Status

The simplest pipeline — equivalent to `SELECT status, COUNT(*) FROM orders GROUP BY status`.

```python
pipeline = [
    {"$group": {
        "_id": "$status",
        "count": {"$sum": 1}
    }},
    {"$sort": {"count": -1}}
]

print("=== Orders by status ===")
for doc in orders.aggregate(pipeline):
    print(f"  {doc['_id']:12s} {doc['count']} orders")
```

<details>
<summary>Expected Output</summary>

~~~text
=== Orders by status ===
  delivered    7 orders
  shipped      2 orders
  pending      1 orders
~~~

</details>

### Pipeline 2: Delivered Orders by City

Adding a `$match` stage — equivalent to `SELECT city, COUNT(*) FROM orders WHERE status = 'delivered' GROUP BY city`.

```python
pipeline = [
    {"$match": {"status": "delivered"}},

    {"$group": {
        "_id": "$customer.city",
        "order_count": {"$sum": 1}
    }},

    {"$sort": {"order_count": -1}},

    {"$project": {
        "city": "$_id",
        "order_count": 1,
        "_id": 0
    }}
]

print("=== Delivered orders by city ===")
for doc in orders.aggregate(pipeline):
    print(f"  {doc['city']:12s} {doc['order_count']} orders")
```

<details>
<summary>Expected Output</summary>

~~~text
=== Delivered orders by city ===
  Humacao      3 orders
  San Juan     2 orders
  Ponce        1 orders
  Mayaguez     1 orders
~~~

</details>

---

## 5. `$unwind`: Analyzing Array Elements

The most powerful pattern in MongoDB analytics: **unwind an array, then group by array element fields.** This lets you aggregate *across* embedded data — for example, finding the most popular products across all orders.

### Pipeline 3: Most Popular Products

```python
pipeline = [
    # Stage 1: Flatten the items array (1 document per item)
    {"$unwind": "$items"},

    # Stage 2: Group by product name
    {"$group": {
        "_id": "$items.product",
        "times_ordered": {"$sum": 1},
        "total_quantity": {"$sum": "$items.quantity"}
    }},

    # Stage 3: Sort by total quantity sold
    {"$sort": {"total_quantity": -1, "times_ordered": -1}}
]

print("=== Product Popularity ===")
print(f"  {'Product':25s} {'Orders':>8s} {'Qty Sold':>10s}")
print(f"  {'-'*25} {'-'*8} {'-'*10}")
for doc in orders.aggregate(pipeline):
    print(f"  {doc['_id']:25s} {doc['times_ordered']:>8d} {doc['total_quantity']:>10d}")
```

<details>
<summary>Expected Output</summary>

~~~text
=== Product Popularity ===
  Product                    Orders   Qty Sold
  ------------------------- -------- ----------
  Wireless Mouse                   3          4
  Mechanical Keyboard              3          4
  Desk Lamp                        3          4
  Laptop Pro 16                    3          3
  Standing Desk                    3          3
  Notebook Pack (3)                1          3
  Ergonomic Chair                  2          2
  USB-C Hub                        1          1
~~~

(Products with equal quantities may appear in different order.)

</details>

### Pipeline 4: Revenue by Product Category

```python
pipeline = [
    {"$unwind": "$items"},

    {"$group": {
        "_id": "$items.category",
        "total_revenue": {
            "$sum": {"$multiply": ["$items.quantity", "$items.price"]}
        },
        "items_sold": {"$sum": "$items.quantity"}
    }},

    {"$sort": {"total_revenue": -1}},

    {"$project": {
        "category": "$_id",
        "total_revenue": {"$round": ["$total_revenue", 2]},
        "items_sold": 1,
        "_id": 0
    }}
]

print("=== Revenue by Category ===")
for doc in orders.aggregate(pipeline):
    print(f"  {doc['category']:15s} ${doc['total_revenue']:>10.2f}  ({doc['items_sold']} items sold)")
```

<details>
<summary>Expected Output</summary>

~~~text
=== Revenue by Category ===
  Electronics     $   4424.89  (12 items sold)
  Furniture       $   2699.95  (5 items sold)
  Office          $    166.93  (7 items sold)
~~~

</details>

Key pattern here: `$unwind` flattened the `items` arrays, then `$group` aggregated across *all* items from *all* orders. Without `$unwind`, we'd be grouping by order, not by product category.

---

## 6. Multi-Stage Pipelines

### Pipeline 5: Top Customers by Spending (Delivered Orders)

This pipeline combines multiple stages to answer: *"Who are the top 3 customers by total spending on delivered orders?"*

We need two `$group` stages: first to compute each order's total, then to sum per customer.

```python
pipeline = [
    # Filter: only delivered orders
    {"$match": {"status": "delivered"}},

    # Flatten items to compute line-item revenue
    {"$unwind": "$items"},

    # Group by (order_id, customer) to get order totals
    {"$group": {
        "_id": {"order_id": "$order_id", "customer_name": "$customer.name"},
        "order_total": {"$sum": {"$multiply": ["$items.quantity", "$items.price"]}}
    }},

    # Group again by customer to sum all their orders
    {"$group": {
        "_id": "$_id.customer_name",
        "total_spent": {"$sum": "$order_total"},
        "order_count": {"$sum": 1}
    }},

    # Sort and limit
    {"$sort": {"total_spent": -1}},
    {"$limit": 3}
]

print("=== Top 3 Customers (Delivered Orders) ===")
for i, doc in enumerate(orders.aggregate(pipeline), 1):
    print(f"  {i}. {doc['_id']:20s} ${doc['total_spent']:>10.2f}  ({doc['order_count']} order(s))")
```

<details>
<summary>Expected Output</summary>

~~~text
=== Top 3 Customers (Delivered Orders) ===
  1. Pedro Martinez       $   1784.97  (1 order(s))
  2. Ana Torres           $   1329.98  (1 order(s))
  3. Maria Santos         $   1049.98  (1 order(s))
~~~

</details>

### Pipeline 6: HAVING Equivalent — Categories with Revenue over $1,000

Use a second `$match` after `$group` to filter aggregated results — just like SQL's `HAVING`.

```python
pipeline = [
    {"$unwind": "$items"},

    {"$group": {
        "_id": "$items.category",
        "total_revenue": {
            "$sum": {"$multiply": ["$items.quantity", "$items.price"]}
        }
    }},

    # This $match acts like SQL HAVING — filters grouped results
    {"$match": {"total_revenue": {"$gt": 1000}}},

    {"$sort": {"total_revenue": -1}},

    {"$project": {
        "category": "$_id",
        "total_revenue": {"$round": ["$total_revenue", 2]},
        "_id": 0
    }}
]

print("=== Categories with revenue > $1,000 ===")
for doc in orders.aggregate(pipeline):
    print(f"  {doc['category']:15s} ${doc['total_revenue']:>10.2f}")
```

<details>
<summary>Expected Output</summary>

~~~text
=== Categories with revenue > $1,000 ===
  Electronics     $   4424.89
  Furniture       $   2699.95
~~~

Office ($166.93) is filtered out by the `$match` after `$group` — this is exactly how SQL's `HAVING` works.

</details>

---

## 7. Your Turn! (Exercises)

### Exercise 1: Customer Segment Analysis

**Task:** Write an aggregation pipeline that computes the number of orders and the average number of items per order for each customer segment ("Premium" vs. "Standard").

**Hint:** Use `$project` with `$size` to compute the number of items per order *before* grouping. Then `$group` by segment with `$avg`.

```python
# TODO: Write your aggregation pipeline
pipeline = [
    # Stage 1: Add a field for item count per order
    # Hint: {"$project": {"customer.segment": 1, "item_count": {"$size": "$items"}}}
    # Stage 2: Group by segment
    # Stage 3: Sort by order count descending
]

# for doc in orders.aggregate(pipeline):
#     print(f"  {doc['_id']:10s}  {doc['order_count']} orders, avg {doc['avg_items_per_order']:.2f} items/order")
```

<details>
<summary>Expected Output</summary>

~~~text
  Premium     6 orders, avg 2.00 items/order
  Standard    4 orders, avg 1.75 items/order
~~~

</details>

### Exercise 2: Monthly Order Trends

**Task:** Group orders by the day of the month and count how many orders were placed each day. Sort by date.

**Hint:** MongoDB has a `$dayOfMonth` expression that extracts the day from a date field. Use it as the `_id` in `$group`:

~~~python
{"$group": {"_id": {"$dayOfMonth": "$order_date"}, "count": {"$sum": 1}}}
~~~

```python
# TODO: Write your aggregation pipeline
pipeline = [
    # TODO
]

print("=== Orders by day of March ===")
# for doc in orders.aggregate(pipeline):
#     print(f"  March {doc['_id']:>2d}: {doc['count']} order(s)")
```

<details>
<summary>Expected Output</summary>

~~~text
=== Orders by day of March ===
  March  1: 1 order(s)
  March  5: 1 order(s)
  March  8: 1 order(s)
  March 10: 1 order(s)
  March 12: 1 order(s)
  March 15: 1 order(s)
  March 18: 1 order(s)
  March 20: 1 order(s)
  March 22: 1 order(s)
  March 25: 1 order(s)
~~~

</details>

### Exercise 3: Product Cross-Selling (Market Basket)

**Task:** Find which products appear together in the same order. This is a simplified version of market basket analysis.

**Approach:**
1. `$unwind` the items array
2. `$group` by `order_id` and collect product names into an array using `$push`
3. Filter for orders with 2+ products (use `$match` with `$size` or `$expr`)
4. Sort by number of products (largest baskets first)

**Hint:** After step 2, your documents look like `{"_id": "ORD-001", "products": ["Laptop Pro 16", "Wireless Mouse"]}`. To filter by array size, use: `{"$match": {"$expr": {"$gte": [{"$size": "$products"}, 2]}}}`.

```python
# TODO: Write your aggregation pipeline
pipeline = [
    # Stage 1: Flatten items
    # Stage 2: Group by order_id, collect product names with $push
    # Stage 3: Filter orders with 2+ products
    # Stage 4: Add product_count field and sort descending
    # Hint: {"$project": {"products": 1, "product_count": {"$size": "$products"}}}
    # Then: {"$sort": {"product_count": -1}}
]

print("=== Multi-product orders ===")
# for doc in orders.aggregate(pipeline):
#     print(f"  {doc['_id']} ({doc['product_count']} products): {doc['products']}")
```

<details>
<summary>Expected Output</summary>

~~~text
=== Multi-product orders ===
  ORD-008 (3 products): ['Laptop Pro 16', 'Ergonomic Chair', 'Desk Lamp']
  ORD-005 (3 products): ['Wireless Mouse', 'USB-C Hub', 'Notebook Pack (3)']
  ORD-001 (2 products): ['Laptop Pro 16', 'Wireless Mouse']
  ORD-002 (2 products): ['Mechanical Keyboard', 'Desk Lamp']
  ORD-003 (2 products): ['Ergonomic Chair', 'Standing Desk']
  ORD-006 (2 products): ['Standing Desk', 'Desk Lamp']
  ORD-009 (2 products): ['Wireless Mouse', 'Mechanical Keyboard']
~~~

(Orders with the same basket size may appear in different order.)

</details>

### Exercise 4: SQL-to-Pipeline Translation

**Task:** Translate this SQL query into a MongoDB aggregation pipeline:

~~~sql
SELECT customer_city,
       COUNT(DISTINCT order_id) AS order_count,
       SUM(item_quantity * item_price) AS total_revenue
FROM orders
JOIN order_items ON orders.order_id = order_items.order_id
WHERE status IN ('delivered', 'shipped')
GROUP BY customer_city
HAVING total_revenue > 500
ORDER BY total_revenue DESC;
~~~

**Hint:** Items are already embedded — no `$lookup` needed. Use `$unwind` to flatten items, then `$group` by city. For `COUNT(DISTINCT order_id)`, use `$addToSet` to collect unique order IDs, then `$size` in a `$project` stage.

```python
# TODO: Translate the SQL query to a MongoDB aggregation pipeline
pipeline = [
    # $match: status in delivered or shipped
    # $unwind: flatten items
    # $group: by customer.city, compute revenue and collect distinct order_ids
    # $project: compute order_count from $size of order_ids set
    # $match: total_revenue > 500 (HAVING)
    # $sort: by total_revenue descending
]

print("=== Revenue by City (Delivered + Shipped) ===")
# for doc in orders.aggregate(pipeline):
#     print(f"  {doc['city']:12s} {doc['order_count']} orders  ${doc['total_revenue']:.2f}")
```

<details>
<summary>Expected Output</summary>

~~~text
=== Revenue by City (Delivered + Shipped) ===
  Humacao      3 orders  $2061.92
  Mayaguez     1 orders  $1784.97
  San Juan     3 orders  $1639.94
  Ponce        2 orders  $1169.96
~~~

</details>

<details>
<summary>Solution Approach</summary>

Pipeline structure:
1. `$match`: `{"status": {"$in": ["delivered", "shipped"]}}`
2. `$unwind`: `"$items"`
3. `$group`: `_id: "$customer.city"`, `$addToSet` for order_ids, `$sum` of `$multiply` for revenue
4. `$project`: compute `order_count` as `{"$size": "$order_ids"}`, rename `_id` to `city`
5. `$match`: `{"total_revenue": {"$gt": 500}}`
6. `$sort`: `{"total_revenue": -1}`

</details>

---

## Summary

In this lab, you:
*   Queried **nested documents** using dot notation (`customer.city`, `items.product`)
*   Used **logical operators** (`$or`) and **array queries** to filter complex documents
*   Built aggregation pipelines with `$match`, `$group`, `$project`, `$sort`, and `$limit`
*   Used **`$unwind`** to flatten arrays and analyze embedded data across orders
*   Applied `$match` after `$group` as a **HAVING** equivalent to filter aggregated results
*   Used **accumulator operators** (`$sum`, `$avg`) for revenue, quantity, and order analysis
*   Translated a **SQL query to an aggregation pipeline**, bridging your relational knowledge