---
title: "MongoDB Essentials: From Documents to Operations"
week: 10
type: concept
tags: [mongodb, pymongo, crud, nosql, document-database]
difficulty: intermediate
duration: "40 mins"
---

# MongoDB Essentials: From Documents to Operations

## 1. Learning Objectives

By the end of this lesson, you will be able to:
*   Describe MongoDB's architecture: the `mongod` server, databases, collections, and client drivers
*   Connect to a MongoDB instance from Python using `pymongo`
*   Perform all four CRUD operations: Create (`insert_one`, `insert_many`), Read (`find`, `find_one`), Update (`update_one`, `update_many`), and Delete (`delete_one`, `delete_many`)
*   Construct query filters using comparison operators (`$gt`, `$lt`, `$in`, `$ne`)
*   Use update operators (`$set`, `$inc`, `$push`, `$pull`) to modify documents without replacing them
*   Use projection to select specific fields and `.sort()`/`.limit()` to order and cap results
*   Explain the role of `_id` and `ObjectId` in document identity

---

## 2. The "Why": From Modeling to Practice

Last week you built document modeling intuition — classifying distributed systems with the CAP theorem, converting relational schemas into embedded documents, and deciding when to embed vs. reference (see [L17 Concept](../week_09/w09_l17_concept_nosql_document_model.md) and [L17 Lab](../week_09/w09_l17_lab_document_modeling.md) for review). You designed documents on paper (as Python dicts). This week, those documents become real.

> **Analogy:** Last week was like drawing architectural blueprints for a house. This week, you pick up the tools and build it. The blueprints (document models) guide the construction (CRUD operations), but you also need to learn how the tools work — how to connect to MongoDB, how to insert and query documents, and how the database assigns identities to your data.

MongoDB is the most widely used document database in the industry. Understanding its CRUD operations is the foundation for everything that follows: advanced querying, aggregation pipelines, and eventually integrating MongoDB into data science workflows.

---

## 3. MongoDB Architecture

### 3.1 The Big Picture

MongoDB uses a client-server architecture. The **server** (`mongod`) stores data and processes queries. **Clients** connect via network drivers and send commands.

```mermaid
graph LR
    subgraph "Client Layer"
        APP["Python Application"]
        PYMONGO["pymongo Driver"]
    end

    subgraph "Server Layer"
        MONGOD["mongod Server"]
        DB1["Database: store_db"]
        C1["Collection: products"]
        C2["Collection: orders"]
    end

    APP --> PYMONGO
    PYMONGO -->|"TCP/IP<br/>mongodb://localhost:27017"| MONGOD
    MONGOD --> DB1
    DB1 --> C1
    DB1 --> C2

    style MONGOD fill:#4DB33D,color:white
    style PYMONGO fill:#306998,color:white
```

### 3.2 Key Components

| Component | Role | Relational Equivalent |
| :--- | :--- | :--- |
| **`mongod`** | The database server process — stores data, handles queries | `postgres` server process |
| **Database** | A namespace that holds collections | A PostgreSQL database |
| **Collection** | A group of documents (no enforced schema by default) | A table |
| **Document** | A JSON/BSON object — the unit of data | A row |
| **`pymongo`** | The official Python driver for MongoDB | `psycopg2` for PostgreSQL |
| **`mongosh`** | Interactive MongoDB shell (JavaScript-based) | `psql` for PostgreSQL |

### 3.3 Connection Methods

MongoDB supports two deployment models:

| Method | Description | When to Use |
| :--- | :--- | :--- |
| **Local** (`mongod` on your machine) | Install MongoDB Community Edition and run locally | Development, learning, Colab labs |
| **MongoDB Atlas** (cloud) | Fully managed cloud database (free tier available) | Production, team collaboration, persistent data |

In this course, we run MongoDB **locally inside Google Colab** — this keeps everything self-contained and free, with no account setup required. The `pymongo` code you write works identically against a local or Atlas instance; only the connection string changes.

### 3.4 Production Reality: Replica Sets

A single `mongod` is fine for development, but **no production system runs a lone server**. MongoDB's standard deployment unit is the **replica set** — a group of `mongod` processes that maintain the same data:

```mermaid
graph LR
    CLIENT["pymongo Driver"] -->|reads & writes| P["Primary"]
    P -->|replication| S1["Secondary 1"]
    P -->|replication| S2["Secondary 2"]

    style P fill:#4DB33D,color:white
    style S1 fill:#888,color:white
    style S2 fill:#888,color:white
```

| Role | Responsibility |
| :--- | :--- |
| **Primary** | Receives all writes; the only node that accepts `insert`, `update`, `delete` |
| **Secondaries** | Replicate data from the primary asynchronously; can serve read queries if configured |
| **Automatic failover** | If the primary goes down, secondaries hold an election and promote a new primary — typically within 10 seconds |

**Why this matters for your CRUD code:** it doesn't change. The `pymongo` driver is replica-set-aware — it discovers all members from the connection string and automatically redirects writes to the current primary. The only visible difference is the connection string, which lists multiple hosts:

```python
# Single server (our labs)
client = MongoClient("mongodb://localhost:27017/")

# Replica set (production)
client = MongoClient("mongodb://host1:27017,host2:27017,host3:27017/?replicaSet=myRS")
```

> **For this course** we use a single local `mongod`. Everything you learn — CRUD operations, aggregation, indexing — applies unchanged to replica sets and sharded clusters.

### Key Takeaway
*   MongoDB follows a familiar client-server model — `pymongo` talks to `mongod` just like `psycopg2` talks to `postgres`
*   Databases contain collections, collections contain documents — no schema enforcement by default
*   The same Python code works against local and cloud MongoDB — only the connection string differs

---

## 4. CRUD Operations

CRUD stands for **C**reate, **R**ead, **U**pdate, **D**elete — the four fundamental operations for any database. In MongoDB, each operation works with JSON documents rather than SQL statements.

### 4.1 Create: Inserting Documents

| Method | Description | Returns |
| :--- | :--- | :--- |
| `insert_one(doc)` | Insert a single document | `InsertOneResult` (contains the `_id`) |
| `insert_many([doc1, doc2, ...])` | Insert multiple documents in one call | `InsertManyResult` (contains all `_id`s) |

```python
# Insert one document
result = collection.insert_one({
    "name": "Laptop Pro",
    "category": "Electronics",
    "price": 999.99
})
print(result.inserted_id)  # ObjectId('...')

# Insert many documents
result = collection.insert_many([
    {"name": "Mouse", "category": "Electronics", "price": 25.00},
    {"name": "Notebook", "category": "Office", "price": 4.99}
])
print(result.inserted_ids)  # [ObjectId('...'), ObjectId('...')]
```

**Key behavior:** If you don't include an `_id` field, MongoDB automatically generates a unique `ObjectId` for each document. You *can* supply your own `_id` (any type), but it must be unique within the collection.

### 4.2 Read: Querying Documents

| Method | Description | Returns |
| :--- | :--- | :--- |
| `find_one(filter)` | Return the first matching document | A single document (dict) or `None` |
| `find(filter)` | Return all matching documents | A `Cursor` (lazy iterator) |
| `count_documents(filter)` | Count matching documents | An integer |

**Query filters** use a dictionary syntax that maps to comparison operators:

| MongoDB Filter | SQL Equivalent | Example |
| :--- | :--- | :--- |
| `{"price": 25.00}` | `WHERE price = 25.00` | Exact match |
| `{"price": {"$gt": 50}}` | `WHERE price > 50` | Greater than |
| `{"price": {"$gte": 50}}` | `WHERE price >= 50` | Greater than or equal |
| `{"price": {"$lt": 100}}` | `WHERE price < 100` | Less than |
| `{"price": {"$lte": 100}}` | `WHERE price <= 100` | Less than or equal |
| `{"category": {"$in": ["Electronics", "Office"]}}` | `WHERE category IN (...)` | Match any in list |
| `{"price": {"$ne": 0}}` | `WHERE price != 0` | Not equal |

**Logical operators** combine conditions — `$and`, `$or`, and `$not`:

| MongoDB Filter | SQL Equivalent |
| :--- | :--- |
| `{"$and": [{"price": {"$gt": 10}}, {"price": {"$lt": 100}}]}` | `WHERE price > 10 AND price < 100` |
| `{"$or": [{"category": "Electronics"}, {"price": {"$lt": 5}}]}` | `WHERE category = 'Electronics' OR price < 5` |
| `{"price": {"$not": {"$gt": 100}}}` | `WHERE NOT (price > 100)` |

> **Tip:** Multiple keys in one dictionary act as an implicit AND: `{"price": {"$gt": 10}, "category": "Electronics"}`. Use explicit `$and` only when you need two conditions on the **same field**.

```python
# Find one document
doc = collection.find_one({"name": "Laptop Pro"})

# Find all electronics
for doc in collection.find({"category": "Electronics"}):
    print(doc["name"], doc["price"])

# Find products over $50
expensive = collection.find({"price": {"$gt": 50}})
```

### 4.3 Update: Modifying Documents

MongoDB updates use **update operators** that modify specific fields without replacing the entire document:

| Operator | Action | Example |
| :--- | :--- | :--- |
| `$set` | Set a field's value (create if doesn't exist) | `{"$set": {"price": 899.99}}` |
| `$inc` | Increment a numeric field | `{"$inc": {"stock": -1}}` |
| `$push` | Append to an array | `{"$push": {"tags": "sale"}}` |
| `$pull` | Remove from an array | `{"$pull": {"tags": "discontinued"}}` |
| `$unset` | Remove a field entirely | `{"$unset": {"temp_flag": ""}}` |

| Method | Description |
| :--- | :--- |
| `update_one(filter, update)` | Update the first matching document |
| `update_many(filter, update)` | Update all matching documents |

```python
# Set a new price (update one document)
collection.update_one(
    {"name": "Laptop Pro"},       # filter: which document
    {"$set": {"price": 899.99}}   # update: what to change
)

# Decrement stock for all electronics
collection.update_many(
    {"category": "Electronics"},
    {"$inc": {"stock": -1}}
)
```

**Important:** The update document must use an operator like `$set`. In `pymongo`, calling `update_one` without a `$` operator raises a `ValueError`. If you intend to replace an entire document, use `replace_one()` instead — but this is rarely what you want, since it deletes every field not in the replacement. Always default to `$set`.

### 4.4 Delete: Removing Documents

| Method | Description |
| :--- | :--- |
| `delete_one(filter)` | Delete the first matching document |
| `delete_many(filter)` | Delete all matching documents |
| `drop()` | Delete the entire collection |

```python
# Delete one document
collection.delete_one({"name": "Notebook"})

# Delete all products with price = 0
result = collection.delete_many({"price": 0})
print(f"Deleted {result.deleted_count} documents")

# Drop the entire collection
collection.drop()
```

### 4.5 CRUD Summary: MongoDB vs. SQL

| Operation | SQL | MongoDB (`pymongo`) |
| :--- | :--- | :--- |
| **Create** | `INSERT INTO products (name, price) VALUES ('Laptop', 999)` | `db.products.insert_one({"name": "Laptop", "price": 999})` |
| **Read** | `SELECT * FROM products WHERE price > 50` | `db.products.find({"price": {"$gt": 50}})` |
| **Update** | `UPDATE products SET price = 899 WHERE name = 'Laptop'` | `db.products.update_one({"name": "Laptop"}, {"$set": {"price": 899}})` |
| **Delete** | `DELETE FROM products WHERE price = 0` | `db.products.delete_many({"price": 0})` |

### 4.6 Projection, Sorting, and Limiting

Just like SQL's `SELECT col1, col2` and `ORDER BY ... LIMIT`, MongoDB lets you control *which fields* are returned and *how results are ordered*.

**Projection** — pass a second argument to `find()`:

```python
# Include only name and price, exclude _id
collection.find({}, {"name": 1, "price": 1, "_id": 0})

# Exclude a specific field (return everything else)
collection.find({}, {"specs": 0})
```

Rules — you must pick **one mode** per projection:
*   **Include mode** (`1`): you list the fields you want — everything else is excluded automatically
*   **Exclude mode** (`0`): you list the fields you don't want — everything else is included automatically

You cannot mix includes and excludes in the same projection (except `_id`, which can always be excluded).

**Sorting and limiting** — chain `.sort()` and `.limit()` on the cursor:

```python
from pymongo import ASCENDING, DESCENDING

# Cheapest first
collection.find().sort("price", ASCENDING)

# Top 3 most expensive
collection.find().sort("price", DESCENDING).limit(3)
```

| pymongo | SQL Equivalent |
| :--- | :--- |
| `.find({}, {"name": 1, "_id": 0})` | `SELECT name FROM ...` |
| `.sort("price", ASCENDING)` | `ORDER BY price ASC` |
| `.limit(3)` | `LIMIT 3` |

---

## 5. The `_id` Field and ObjectId

Every MongoDB document must have a unique `_id` field — it serves the same role as a primary key in a relational table.

### Auto-generated ObjectId

If you don't provide `_id`, MongoDB generates a 12-byte `ObjectId`:

```
|  4 bytes  |  5 bytes   | 3 bytes  |
| timestamp | random     | counter  |
| (seconds) | (per-proc) | (increm) |
```

**Key properties:**
*   **Roughly time-ordered** — documents inserted later get higher ObjectIds, which means default sort order approximates insertion order
*   **Globally unique** — the random + counter components prevent collisions across servers
*   **Extractable timestamp** — `ObjectId.generation_time` returns when the document was created

### Custom `_id`

You can supply your own `_id` of any BSON type — strings, integers, or even nested objects:

```python
collection.insert_one({"_id": "SKU-001", "name": "Laptop Pro", "price": 999.99})
```

This is useful when your data has a natural unique identifier (SKU, email, order number).

### Key Takeaway
*   Every document gets an `_id` — auto-generated or user-supplied
*   `ObjectId` is time-sortable and globally unique without coordination between servers
*   Use custom `_id` when your data has natural unique identifiers

---

## 6. Deep Dive: MongoDB Atlas (Optional)

<details>
<summary>Click to expand: MongoDB Atlas — Cloud Setup</summary>

While this course uses a local MongoDB instance in Colab, production systems typically use **MongoDB Atlas** — MongoDB's fully managed cloud database service.

### What Atlas Provides
*   **Free tier (M0):** 512 MB storage, shared cluster — sufficient for learning and small projects
*   **Automatic backups, monitoring, and scaling**
*   **Global clusters** across AWS, GCP, or Azure regions
*   **Built-in security:** Network access lists, authentication, encryption at rest

### Connecting to Atlas from pymongo

The only change in your code is the connection string:

```python
# Local connection (what we use in Colab)
client = MongoClient("mongodb://127.0.0.1:27017/")

# Atlas connection (production)
client = MongoClient(
    "mongodb+srv://username:password@cluster0.xxxxx.mongodb.net/"
    "?retryWrites=true&w=majority"
)
```

Everything else — `insert_one`, `find`, `update_one` — works identically. This is the power of the driver abstraction: your application code doesn't care whether the database is local or in the cloud.

### Setting Up Atlas (Quick Steps)
1.  Create a free account at [mongodb.com/cloud/atlas](https://www.mongodb.com/cloud/atlas)
2.  Create a free M0 cluster
3.  Add your IP address to the network access list (or allow all IPs for Colab: `0.0.0.0/0`)
4.  Create a database user with read/write permissions
5.  Click "Connect" > "Connect your application" > copy the connection string
6.  Replace `<password>` in the connection string with your database user's password

</details>

---

## 7. FAQ / Industry Reality

### "Why not just use PostgreSQL's JSONB support instead of MongoDB?"

**Answer:** PostgreSQL's `JSONB` type gives you document-style storage within a relational database — and for many use cases, that's sufficient. But MongoDB is purpose-built for the document model: its query language, indexing, aggregation pipeline, and horizontal scaling are all optimized for nested document structures. If your *entire* data model is document-oriented and you need features like sharding or change streams, MongoDB is the better fit. If you need documents *alongside* relational data, PostgreSQL's JSONB is a pragmatic choice.

### "Is `find()` loading all documents into memory at once?"

**Answer:** No. `find()` returns a **cursor** — a lazy iterator that fetches documents in batches from the server (default batch size is 101 documents for the first batch, then 16 MB batches). You can iterate through millions of documents without loading them all into memory. However, converting a cursor to a list (`list(cursor)`) *does* load everything — avoid this on large collections.

### "Should I always use `$set` for updates?"

**Answer:** Yes, for field-level changes. In `pymongo`, `update_one` *requires* a `$` operator and will reject a plain document. However, `replace_one(filter, new_doc)` performs a **full document replacement** — it deletes every field not in `new_doc`. This is a common source of data loss when confused with `update_one`. Always use `$set` (or `$inc`, `$push`, etc.) to modify specific fields while preserving the rest of the document.

---

## 8. Summary & Next Steps

**Key takeaways:**

*   MongoDB uses a client-server architecture: `pymongo` connects to `mongod` via a connection string
*   **CRUD operations** map directly to `pymongo` methods: `insert_one`/`insert_many`, `find`/`find_one`, `update_one`/`update_many`, `delete_one`/`delete_many`
*   **Query filters** use dictionary syntax with operators like `$gt`, `$lt`, `$in` — the MongoDB equivalent of SQL's `WHERE` clause
*   **Update operators** (`$set`, `$inc`, `$push`) modify specific fields without replacing the entire document
*   Every document has a unique `_id` — auto-generated as an `ObjectId` or user-supplied

*   **Next:** Go to the Practical Lab [w10_l19_lab_mongodb_crud.md](w10_l19_lab_mongodb_crud.md) to install MongoDB in Colab, connect with pymongo, and run real CRUD operations.

---

## 9. Further Reading

### Documentation
*   [pymongo Documentation: Tutorial](https://pymongo.readthedocs.io/en/stable/tutorial.html) — Official getting-started guide for the Python MongoDB driver
*   [MongoDB Manual: CRUD Operations](https://www.mongodb.com/docs/manual/crud/) — Comprehensive reference for all insert, query, update, and delete operations

### Articles & Tutorials
*   [MongoDB University: M001 — MongoDB Basics](https://university.mongodb.com/) — Free, self-paced course covering MongoDB fundamentals (video + exercises)
*   [Real Python: Introduction to MongoDB and Python](https://realpython.com/introduction-to-mongodb-and-python/) — Hands-on tutorial covering pymongo basics with practical examples
