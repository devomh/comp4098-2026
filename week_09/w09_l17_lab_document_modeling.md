---
title: "Lab: Document Modeling — From Tables to Documents"
week: 09
type: lab
tags: [document-model, json, mongodb, nosql, modeling]
difficulty: intermediate
duration: "40 mins"
---

# Lab: Document Modeling — From Tables to Documents

## Prerequisites & Setup

**Before starting this lab, you should:**
*   Review [w09_l17_concept_nosql_document_model.md](w09_l17_concept_nosql_document_model.md) for CAP theorem and document model concepts
*   Understand relational modeling (tables, foreign keys, JOINs)
*   Be comfortable with Python dictionaries and lists

**What you'll accomplish:**
In this lab, you'll classify distributed systems using the CAP theorem, convert a relational schema into document models, and practice the embed-vs-reference decision for different cardinality patterns.

**Goal:** Build the modeling intuition you'll need before writing actual MongoDB queries in the next lesson.

---

### Environment Setup

No external packages needed — this lab uses pure Python and the `json` module.

```python
# Setup: Run this cell first (required for Colab)
import json

def pretty(doc):
    """Pretty-print a Python dict as formatted JSON."""
    print(json.dumps(doc, indent=2, default=str))

print("Setup complete! Ready for document modeling exercises.")
```

<details>
<summary>Expected Output</summary>

~~~text
Setup complete! Ready for document modeling exercises.
~~~

</details>

---

## Step 1: CAP Classification Activity

In the concept lesson, you learned that distributed systems must choose between consistency and availability when a network partition occurs. Let's apply that understanding to real-world systems.

### System Behaviors During a Network Partition

| # | System | Behavior During Partition |
| :--- | :--- | :--- |
| 1 | **PostgreSQL** (streaming replication) | Primary rejects writes if it can't reach replicas. Reads may block. Guarantees no stale data. |
| 2 | **Apache Cassandra** | All nodes continue accepting reads and writes. Different nodes may temporarily return different values. |
| 3 | **MongoDB** (replica set, default) | Writes only go to the primary. If the primary is unreachable, a new election occurs; during election, writes are unavailable. |
| 4 | **Amazon DynamoDB** (default) | Always responds to reads, but the value returned may not reflect the most recent write. |
| 5 | **Redis Sentinel** | Promotes a replica to primary if the current primary is unreachable. During failover, some acknowledged writes may be lost. |

**Task:** Classify each system as **CP** or **AP** based on the behavior described above. Write a one-sentence justification for each.

```python
# Classify each system as "CP" or "AP"
# Write a brief justification based on the behavior described above

cap_classifications = {
    "PostgreSQL":  {"classification": "TODO", "reason": "TODO"},  # TODO
    "Cassandra":   {"classification": "TODO", "reason": "TODO"},  # TODO
    "MongoDB":     {"classification": "TODO", "reason": "TODO"},  # TODO
    "DynamoDB":    {"classification": "TODO", "reason": "TODO"},  # TODO
    "Redis":       {"classification": "TODO", "reason": "TODO"},  # TODO
}

for system, info in cap_classifications.items():
    print(f"{system}: {info['classification']} — {info['reason']}")
```

<details>
<summary>Expected Output</summary>

~~~text
PostgreSQL: CP — Sacrifices availability (rejects writes) to maintain consistency across replicas.
Cassandra: AP — Sacrifices consistency (stale reads possible) to maintain availability on all nodes.
MongoDB: CP — Sacrifices availability (no writes during election) to maintain consistency via single primary.
DynamoDB: AP — Sacrifices consistency (eventually consistent reads) to always return a response.
Redis: CP — Sacrifices availability during failover; prioritizes consistency after new primary is promoted.
~~~

</details>

---

## Step 2: The Relational Starting Point

Here's an e-commerce schema — four related tables that you're familiar with from the relational world. We'll use this data throughout the lab.

```python
# Relational data — simulating SQL tables as lists of dicts

customers = [
    {"customer_id": "C001", "name": "Ana Torres", "email": "ana@example.com", "city": "Humacao"},
    {"customer_id": "C002", "name": "Luis Rivera", "email": "luis@example.com", "city": "San Juan"},
]

orders = [
    {"order_id": "O1001", "customer_id": "C001", "order_date": "2026-03-15", "status": "shipped"},
    {"order_id": "O1002", "customer_id": "C001", "order_date": "2026-03-20", "status": "pending"},
    {"order_id": "O1003", "customer_id": "C002", "order_date": "2026-03-18", "status": "delivered"},
]

order_items = [
    {"item_id": "I01", "order_id": "O1001", "product_name": "Laptop",    "quantity": 1, "unit_price": 999.99},
    {"item_id": "I02", "order_id": "O1001", "product_name": "Mouse",     "quantity": 2, "unit_price": 25.00},
    {"item_id": "I03", "order_id": "O1002", "product_name": "Keyboard",  "quantity": 1, "unit_price": 75.00},
    {"item_id": "I04", "order_id": "O1003", "product_name": "Monitor",   "quantity": 1, "unit_price": 450.00},
    {"item_id": "I05", "order_id": "O1003", "product_name": "HDMI Cable","quantity": 3, "unit_price": 12.99},
]

print(f"Customers: {len(customers)}")
print(f"Orders: {len(orders)}")
print(f"Order items: {len(order_items)}")
```

<details>
<summary>Expected Output</summary>

~~~text
Customers: 2
Orders: 3
Order items: 5
~~~

</details>

**The relational schema:**

| Table | Columns |
| :--- | :--- |
| `customers` | `customer_id (PK)`, `name`, `email`, `city` |
| `orders` | `order_id (PK)`, `customer_id (FK → customers)`, `order_date`, `status` |
| `order_items` | `item_id (PK)`, `order_id (FK → orders)`, `product_name`, `quantity`, `unit_price` |

---

## Step 3: The JOIN Problem

Let's retrieve order `O1001` with all its items and customer info. In the relational model, this requires joining three tables:

```python
# Simulating a 3-table JOIN in Python
# SQL equivalent:
#   SELECT c.name, o.order_id, o.order_date, o.status,
#          oi.product_name, oi.quantity, oi.unit_price
#   FROM customers c
#   JOIN orders o ON c.customer_id = o.customer_id
#   JOIN order_items oi ON o.order_id = oi.order_id
#   WHERE o.order_id = 'O1001';

target_order = "O1001"

# Step 1: Find the order
order = [o for o in orders if o["order_id"] == target_order][0]

# Step 2: Find the customer (JOIN #1)
customer = [c for c in customers if c["customer_id"] == order["customer_id"]][0]

# Step 3: Find the items (JOIN #2)
items = [i for i in order_items if i["order_id"] == target_order]

# Step 4: Assemble the result
print(f"Customer: {customer['name']} ({customer['email']})")
print(f"Order: {order['order_id']} ({order['order_date']}) — {order['status']}")
print(f"Items:")
for item in items:
    print(f"  {item['product_name']} x{item['quantity']} @ ${item['unit_price']}")
total = sum(i["quantity"] * i["unit_price"] for i in items)
print(f"Total: ${total:.2f}")
```

<details>
<summary>Expected Output</summary>

~~~text
Customer: Ana Torres (ana@example.com)
Order: O1001 (2026-03-15) — shipped
Items:
  Laptop x1 @ $999.99
  Mouse x2 @ $25.0
Total: $1049.99
~~~

</details>

Now the **document model** equivalent — the same data stored as a single embedded document:

```python
# The same data as ONE document — no joins needed
order_document = {
    "_id": "O1001",
    "customer": {
        "customer_id": "C001",
        "name": "Ana Torres",
        "email": "ana@example.com"
    },
    "order_date": "2026-03-15",
    "status": "shipped",
    "items": [
        {"product": "Laptop",  "quantity": 1, "unit_price": 999.99},
        {"product": "Mouse",   "quantity": 2, "unit_price": 25.00}
    ]
}

# One "read" — no joins
pretty(order_document)
total = sum(i["quantity"] * i["unit_price"] for i in order_document["items"])
print(f"\nTotal: ${total:.2f}")
```

<details>
<summary>Expected Output</summary>

~~~json
{
  "_id": "O1001",
  "customer": {
    "customer_id": "C001",
    "name": "Ana Torres",
    "email": "ana@example.com"
  },
  "order_date": "2026-03-15",
  "status": "shipped",
  "items": [
    {
      "product": "Laptop",
      "quantity": 1,
      "unit_price": 999.99
    },
    {
      "product": "Mouse",
      "quantity": 2,
      "unit_price": 25.0
    }
  ]
}

Total: $1049.99
~~~

</details>

In SQL, this required 3 tables and 2 JOINs. In the document model, it's a single read. This is the fundamental advantage of embedding: **data that is accessed together is stored together.**

---

## Step 4: Modeling Cardinalities as Documents

Let's practice each cardinality pattern from the concept lesson.

### One-to-One: Student with Address

A student has exactly one address. Always embed.

```python
student_doc = {
    "_id": "S001",
    "name": "Ana Torres",
    "email": "ana@upr.edu",
    "address": {
        "street": "123 Marina St",
        "city": "Humacao",
        "state": "PR",
        "zip": "00791"
    }
}
pretty(student_doc)
```

<details>
<summary>Expected Output</summary>

~~~json
{
  "_id": "S001",
  "name": "Ana Torres",
  "email": "ana@upr.edu",
  "address": {
    "street": "123 Marina St",
    "city": "Humacao",
    "state": "PR",
    "zip": "00791"
  }
}
~~~

</details>

### One-to-Many (bounded): Student with Phone Numbers

A student has 1-3 phone numbers. The array is small and bounded — embed.

```python
student_phones = {
    "_id": "S001",
    "name": "Ana Torres",
    "phone_numbers": [
        {"type": "mobile", "number": "787-555-0001"},
        {"type": "home",   "number": "787-555-0002"}
    ]
}
pretty(student_phones)
```

<details>
<summary>Expected Output</summary>

~~~json
{
  "_id": "S001",
  "name": "Ana Torres",
  "phone_numbers": [
    {
      "type": "mobile",
      "number": "787-555-0001"
    },
    {
      "type": "home",
      "number": "787-555-0002"
    }
  ]
}
~~~

</details>

### One-to-Many (unbounded): Host with Log Entries

A web server generates thousands of log entries per day. Embedding would exceed MongoDB's 16 MB document limit. Use references.

```python
# Host document — small and stable
host_doc = {
    "_id": "host-123",
    "hostname": "web-server-1",
    "ip": "10.0.1.50",
    "os": "Ubuntu 22.04"
}

# Log entries — separate collection, each references the host
log_entries = [
    {"_id": "log-001", "host_id": "host-123",
     "timestamp": "2026-03-15T10:00:00Z", "level": "INFO",
     "message": "Server started"},
    {"_id": "log-002", "host_id": "host-123",
     "timestamp": "2026-03-15T10:00:01Z", "level": "WARN",
     "message": "High memory usage (92%)"},
]

print("Host document:")
pretty(host_doc)
print(f"\nLog entries (showing 2 of potentially millions):")
for entry in log_entries:
    pretty(entry)
```

<details>
<summary>Expected Output</summary>

~~~text
Host document:
{
  "_id": "host-123",
  "hostname": "web-server-1",
  "ip": "10.0.1.50",
  "os": "Ubuntu 22.04"
}

Log entries (showing 2 of potentially millions):
{
  "_id": "log-001",
  "host_id": "host-123",
  "timestamp": "2026-03-15T10:00:00Z",
  "level": "INFO",
  "message": "Server started"
}
{
  "_id": "log-002",
  "host_id": "host-123",
  "timestamp": "2026-03-15T10:00:01Z",
  "level": "WARN",
  "message": "High memory usage (92%)"
}
~~~

</details>

---

## Your Turn! (Exercises)

### Exercise 1: Convert the Full Order Dataset

**Task:** Convert ALL three orders (`O1001`, `O1002`, `O1003`) from the relational data in Step 2 into embedded documents. Each order document should contain the customer info and all line items. Store them in a Python list called `order_documents`.

**Hint:** Look at the `order_document` example in Step 3 for the target structure.

```python
# TODO: Create a list of 3 order documents, each with embedded customer and items
order_documents = [
    # TODO: Order O1001 (Ana Torres, 2 items: Laptop + Mouse)
    # TODO: Order O1002 (Ana Torres, 1 item: Keyboard)
    # TODO: Order O1003 (Luis Rivera, 2 items: Monitor + HDMI Cable)
]

# Verify your documents
for doc in order_documents:
    item_count = len(doc.get("items", []))
    total = sum(i["quantity"] * i["unit_price"] for i in doc["items"])
    print(f"Order {doc['_id']}: {doc['customer']['name']} — {item_count} items — ${total:.2f}")
```

<details>
<summary>Expected Output</summary>

~~~text
Order O1001: Ana Torres — 2 items — $1049.99
Order O1002: Ana Torres — 1 items — $75.00
Order O1003: Luis Rivera — 2 items — $488.97
~~~

</details>

### Exercise 2: Identify the Duplication Problem

**Task:** Look at the order documents you just created. Ana Torres appears in both `O1001` and `O1002`.

1.  What happens if Ana changes her email address? How many documents need updating?
2.  Create an alternative design using **references** — orders store only a `customer_id`, and customer data lives in a separate collection.

```python
# TODO: Answer the questions in comments
# Q1: If Ana changes her email, how many documents need updating?
# Answer: TODO

# Q2: Create referenced versions

# Customer documents (separate collection)
customer_documents = [
    # TODO: customer doc for Ana
    # TODO: customer doc for Luis
]

# Order documents with customer references (not embedded)
order_docs_referenced = [
    # TODO: Order O1001 with customer_id reference instead of embedded customer
    # TODO: Order O1002
    # TODO: Order O1003
]

# Display one example
print("Customer document:")
pretty(customer_documents[0])
print("\nOrder document (referenced):")
pretty(order_docs_referenced[0])
```

<details>
<summary>Expected Output</summary>

~~~text
Customer document:
{
  "_id": "C001",
  "name": "Ana Torres",
  "email": "ana@example.com",
  "city": "Humacao"
}

Order document (referenced):
{
  "_id": "O1001",
  "customer_id": "C001",
  "order_date": "2026-03-15",
  "status": "shipped",
  "items": [
    {
      "product": "Laptop",
      "quantity": 1,
      "unit_price": 999.99
    },
    {
      "product": "Mouse",
      "quantity": 2,
      "unit_price": 25.0
    }
  ]
}
~~~

Note: With embedding, changing Ana's email requires updating 2 documents. With references, it requires updating only 1 customer document. However, fetching an order now requires 2 reads instead of 1.

</details>

### Exercise 3: Model a Blog Platform

**Task:** Design a document model for a blog platform with these requirements:
*   A blog has **authors** and **posts**
*   Each post has one author, a title, body, tags (array), and a published date
*   Each post can have many **comments**; each comment has an author name, text, and timestamp
*   A typical blog has 50–200 posts, each post has 0–50 comments

**Decide:** Should comments be embedded or referenced? Justify your choice in a comment.

```python
# TODO: Create a sample blog post document
# Consider: Should comments be embedded or referenced?
# Justify your decision in a comment.

# Decision: TODO (embed / reference)
# Reason: TODO

blog_post = {
    # TODO: Design your document structure
    # Include: _id, author info, title, body, tags, published_date, and comments
}

pretty(blog_post)
print(f"\nTags: {len(blog_post.get('tags', []))}")
print(f"Comments: {len(blog_post.get('comments', []))}")
```

<details>
<summary>Expected Output</summary>

~~~text
{
  "_id": "post-001",
  "author": {
    "name": "Ana Torres",
    "email": "ana@example.com"
  },
  "title": "Getting Started with Document Databases",
  "body": "In this post, we explore the document model...",
  "tags": ["mongodb", "nosql", "tutorial"],
  "published_date": "2026-03-15",
  "comments": [
    {
      "author": "Luis Rivera",
      "text": "Great introduction! Very clear examples.",
      "timestamp": "2026-03-15T14:30:00Z"
    },
    {
      "author": "Maria Santos",
      "text": "How does this compare to PostgreSQL JSONB?",
      "timestamp": "2026-03-16T09:15:00Z"
    }
  ]
}

Tags: 3
Comments: 2
~~~

Decision: Embed comments. With 0-50 comments per post (bounded), embedding keeps each post self-contained for reading. Comments are always displayed with their post and are not shared across posts.

</details>

### Exercise 4: The Anti-Pattern Detector

**Task:** Each of the following document designs has a modeling problem. Identify the issue and suggest a fix.

```python
# --- Design A ---
# E-commerce platform where power users place 10,000+ orders
design_a = {
    "_id": "user-1",
    "name": "Power Shopper",
    "email": "shopper@example.com",
    "orders": [
        # ... imagine 10,000+ order objects embedded here,
        # each with its own items array
    ]
}

# --- Design B ---
# Product review that embeds the entire product catalog entry
design_b = {
    "_id": "review-1",
    "rating": 5,
    "text": "Great product!",
    "reviewer": "Ana Torres",
    "product": {
        "product_id": "P001",
        "name": "Laptop Pro 16",
        "description": "A very long description with full specs...",
        "specs": {"cpu": "M2 Pro", "ram": "16GB", "storage": "512GB SSD"},
        "images": ["img1.jpg", "img2.jpg", "img3.jpg"],
        "price": 999.99,
        "category": "Electronics",
        "manufacturer": {"name": "TechCorp", "country": "US", "support_url": "..."}
    }
}

# TODO: For each design, identify the problem and suggest a fix

# Design A:
#   Problem: TODO
#   Fix: TODO

# Design B:
#   Problem: TODO
#   Fix: TODO

print("Design A — Document size for 10,000 orders:")
avg_order_bytes = 200  # rough estimate per embedded order
print(f"  Estimated: {avg_order_bytes * 10_000 / 1_000_000:.1f} MB")
print(f"  MongoDB limit: 16 MB")
print(f"  Exceeds limit: {avg_order_bytes * 10_000 > 16_000_000}")

print("\nDesign B — Data shared across reviews:")
print(f"  If 500 users review this product, the full product object")
print(f"  is duplicated {500} times. If the price changes, all 500")
print(f"  review documents need updating.")
```

<details>
<summary>Expected Output</summary>

~~~text
Design A — Document size for 10,000 orders:
  Estimated: 2.0 MB
  MongoDB limit: 16 MB
  Exceeds limit: False

Design B — Data shared across reviews:
  If 500 users review this product, the full product object
  is duplicated 500 times. If the price changes, all 500
  review documents need updating.
~~~

**Design A — Unbounded array:**
Even though 10,000 orders at 200 bytes each fits under 16 MB, real orders have items arrays, addresses, and metadata. At 2-5 KB per order, 10K orders = 20-50 MB, exceeding the limit. More importantly, every read of the user document loads *all* orders into memory.

**Fix:** Store orders in a separate collection with a `user_id` reference field. Query orders by `user_id` when needed.

**Design B — Excessive embedding of shared data:**
The full product object is duplicated in every review. If the product has 500 reviews, the product data is stored 500 times. Updating the product name or price requires updating all 500 review documents.

**Fix:** Store only a `product_id` reference, plus a small snapshot of the fields needed for display (e.g., `product_name` and `price` at time of review). The full product lives in a `products` collection.

</details>

---

## Summary

In this lab, you:
*   Classified real distributed systems as **CP** or **AP** using the CAP theorem
*   Experienced the **JOIN cost** of relational data and saw how **embedding** eliminates it
*   Modeled **one-to-one**, **one-to-few**, and **one-to-millions** relationships as documents
*   Practiced the **embed vs. reference** decision — the core modeling skill for document databases
*   Identified common **anti-patterns** (unbounded arrays, excessive embedding)

**Next lesson:** You'll install MongoDB in Colab, connect with `pymongo`, and run real CRUD operations against document collections.
