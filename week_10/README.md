# Week 10: MongoDB in Practice

## Overview

This week is the **hands-on MongoDB week**. In Week 9, you built document modeling intuition — CAP theorem, schema-on-read, embed vs. reference decisions. Now you connect to a real MongoDB instance, perform CRUD operations with `pymongo`, and use the Aggregation Pipeline for analytics.

By the end of this week, you'll be able to go from a document model design to a working MongoDB application with analytical capabilities.

---

## Lesson 19: MongoDB Essentials — CRUD Operations

### Learning Objectives

- Describe MongoDB's architecture: `mongod` server, databases, collections, and the `pymongo` driver
- Connect to a MongoDB instance from Python using `pymongo`
- Perform Create, Read, Update, and Delete operations with `pymongo`
- Use query filters with comparison operators (`$gt`, `$lt`, `$in`, `$ne`)
- Use update operators (`$set`, `$inc`, `$push`, `$pull`) to modify documents safely
- Explain the role of `_id` and `ObjectId` in document identity

### Materials

**Concept Notes:**
- [MongoDB Essentials: From Documents to Operations](w10_l19_concept_mongodb_essentials.md)

**Lab Exercise:**
- [Lab: MongoDB CRUD Operations](w10_l19_lab_mongodb_crud.md)

### Interactive Notebook

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/devomh/comp4098-2026/blob/main/week_10/w10_l19_lab_mongodb_crud.ipynb)

---

## Lesson 20: Advanced Document Querying & the Aggregation Pipeline

### Learning Objectives

- Combine query filters using logical operators (`$and`, `$or`)
- Query arrays using `$elemMatch`, `$all`, and `$size`
- Explain the Aggregation Pipeline as a sequence of data transformation stages
- Use core pipeline stages: `$match`, `$group`, `$project`, `$unwind`, `$sort`, `$limit`
- Map MongoDB aggregation concepts to SQL equivalents (`WHERE`, `GROUP BY`, `HAVING`)
- Use accumulator operators (`$sum`, `$avg`, `$min`, `$max`) within `$group`

### Materials

**Concept Notes:**
- [Advanced Document Querying & the Aggregation Pipeline](w10_l20_concept_advanced_querying.md)

**Lab Exercise:**
- [Lab: MongoDB Aggregation Pipeline](w10_l20_lab_aggregation_pipeline.md)

### Interactive Notebook

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/devomh/comp4098-2026/blob/main/week_10/w10_l20_lab_aggregation_pipeline.ipynb)

---

## Key Concepts

### MongoDB CRUD Operations

| Operation | pymongo Method | SQL Equivalent |
| :--- | :--- | :--- |
| **Create** | `insert_one()`, `insert_many()` | `INSERT INTO` |
| **Read** | `find_one()`, `find()` | `SELECT ... WHERE` |
| **Update** | `update_one()`, `update_many()` | `UPDATE ... SET` |
| **Delete** | `delete_one()`, `delete_many()` | `DELETE FROM ... WHERE` |

### Update Operators
- `$set` — Set field value (safe default for updates)
- `$inc` — Increment/decrement numeric fields
- `$push` / `$pull` — Add/remove array elements
- `$unset` — Remove a field entirely

### Aggregation Pipeline Stages

| Stage | Purpose | SQL Equivalent |
| :--- | :--- | :--- |
| `$match` | Filter documents | `WHERE` |
| `$group` | Group and aggregate | `GROUP BY` + `SUM/AVG/COUNT` |
| `$project` | Reshape output | `SELECT` |
| `$unwind` | Flatten arrays | `UNNEST` / `LATERAL JOIN` |
| `$sort` | Order results | `ORDER BY` |
| `$limit` | Cap result count | `LIMIT` |

### The `$unwind` + `$group` Pattern
The most powerful aggregation pattern: flatten embedded arrays with `$unwind`, then `$group` by array element fields. This is how you analyze data *across* embedded documents (e.g., "most popular product across all orders").

---

## Connection from Previous Weeks

### Week 09 -> Week 10: From Modeling to MongoDB CRUD
- **Week 09:** Built document modeling intuition — CAP classification, embed vs. reference, cardinality patterns using Python dicts
- **Week 10:** Those document models become real MongoDB collections with `pymongo` CRUD and aggregation pipelines
- **Key Connection:** The embed/reference decisions from Week 09 directly shape how you query and aggregate in Week 10

### Week 10 -> Week 11: From MongoDB to Redis and Security
- **Week 10:** Mastered document storage and analytics with MongoDB
- **Week 11 Preview:** Explore Redis (key-value stores) for caching and fast lookups, then learn about SQL injection and secure database connectivity
- **Key Connection:** MongoDB joins the polyglot persistence toolkit alongside PostgreSQL and DuckDB; Redis adds caching as the fourth paradigm

---

## Technical Notes

### MongoDB in Colab
Both labs install MongoDB Community Edition 7.x locally inside the Colab runtime. This approach:
- Requires no account setup or cloud credentials
- Is completely self-contained (each lab reinstalls from scratch)
- Uses the same `pymongo` code that works against MongoDB Atlas

### Dataset
- **L19 Lab:** Product catalog (8 products across Electronics, Office, Furniture) with nested specs and tags arrays
- **L20 Lab:** E-commerce orders (10 orders with embedded customer info and line items) designed for aggregation pipeline exercises

---

## Additional Resources

### Documentation
- [pymongo Documentation: Tutorial](https://pymongo.readthedocs.io/en/stable/tutorial.html) — Official Python driver guide
- [MongoDB Manual: CRUD Operations](https://www.mongodb.com/docs/manual/crud/) — Complete CRUD reference
- [MongoDB Manual: Aggregation Pipeline](https://www.mongodb.com/docs/manual/core/aggregation-pipeline/) — Pipeline stages and operators

### Courses
- [MongoDB University: M001 — MongoDB Basics](https://university.mongodb.com/) — Free fundamentals course
- [MongoDB University: M121 — Aggregation Framework](https://university.mongodb.com/) — Free aggregation deep-dive

### Articles
- [Practical MongoDB Aggregations (free e-book)](https://www.practical-mongodb-aggregations.com/) — Real-world pipeline examples
