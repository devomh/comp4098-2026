# Week 09: NoSQL — Distributed Trade-offs & the Document Model

## Overview

This week begins **Module 3: NoSQL**. You've spent Weeks 1–8 mastering the relational world — ER modeling, normalization, SQL, joins, window functions, CTEs, and performance benchmarking across PostgreSQL and DuckDB. Now you'll step beyond tables and rows into a fundamentally different paradigm.

The central question: **What happens when your data doesn't fit neatly into predefined table schemas, or your system must survive network failures across distributed nodes?** You'll learn the CAP theorem — the impossibility result that shapes every distributed database — and then explore the document model, where data is stored as flexible JSON documents instead of rigid rows.

---

## Lesson 17: Why NoSQL? Distributed Trade-offs & the Document Model

### Learning Objectives

- Define Consistency, Availability, and Partition Tolerance and explain the CAP impossibility result
- Classify real-world database systems as CP or AP and explain the trade-off each makes
- Distinguish Schema-on-Write (relational) from Schema-on-Read (document/NoSQL)
- Explain the MongoDB data model: documents, collections, and databases
- Compare embedded documents vs. references and identify when each is appropriate
- Model one-to-one, one-to-many, and many-to-many relationships as JSON documents

### Materials

**Concept Notes:**
- [Why NoSQL? Distributed Trade-offs & the Document Model](w09_l17_concept_nosql_document_model.md)

**Lab Exercise:**
- [Document Modeling — From Tables to Documents](w09_l17_lab_document_modeling.md)

### Interactive Notebook

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/devomh/comp4098-2026/blob/main/week_09/w09_l17_lab_document_modeling.ipynb)

---

## Key Concepts

### CAP Theorem
- **Consistency (C)** — Every read receives the most recent write or an error
- **Availability (A)** — Every request gets a non-error response, even if it's stale
- **Partition Tolerance (P)** — The system continues operating despite network splits
- **The impossibility result** — A distributed system cannot guarantee all three simultaneously; since partitions are inevitable, the real choice is between C and A

### CP vs. AP Systems
- **CP systems** (PostgreSQL, MongoDB) — Prioritize correctness; reject requests rather than return stale data during a partition
- **AP systems** (Cassandra, DynamoDB) — Prioritize uptime; continue responding even if different nodes return different values

### Schema-on-Write vs. Schema-on-Read
- **Schema-on-Write** — Define schema before inserting data; the database rejects invalid data (PostgreSQL, MySQL)
- **Schema-on-Read** — Insert any JSON structure; the application interprets structure at query time (MongoDB, Elasticsearch)

### The Document Model
- **Documents** — JSON/BSON objects stored in **collections** (analogous to rows in tables)
- **Embedded documents** — Nest related data inside the parent document; fast reads, no joins needed
- **References** — Link documents by ID across collections; avoids duplication, supports shared and unbounded data
- **16 MB limit** — MongoDB's maximum document size; unbounded arrays must use references

### Embed vs. Reference Decision
- **Embed** when data is accessed together and bounded (one-to-one, one-to-few)
- **Reference** when data is shared across entities, grows without bound, or is updated independently

---

## Connection from Previous Weeks

### Week 08 → Week 09: From SQL to NoSQL
- **Week 08:** Concluded Module 2 with a performance benchmark comparing PostgreSQL (row-oriented) and DuckDB (column-oriented) on 5M rows
- **Week 09:** Module 3 introduces data that doesn't fit tables — documents, key-value pairs, and the distributed trade-offs that drive NoSQL adoption
- **Key Connection:** Understanding storage architecture trade-offs (Week 08) prepares you to evaluate the CAP theorem and document model trade-offs

### Week 09 → Week 10: From Modeling to MongoDB CRUD
- **Week 09:** Built document modeling intuition — CAP classification, embed vs. reference, cardinality patterns
- **Week 10 Preview:** Install MongoDB in Colab, connect with `pymongo`, and run real CRUD operations against document collections
- **Key Connection:** The document structures you designed this week become the collections you'll query next week

---

## Practical Applications for Data Scientists

### Why the Document Model Matters
1. **JSON API ingestion** — Most web APIs return JSON; document databases store it natively without flattening into tables
2. **Semi-structured data** — Product catalogs, user profiles, and IoT sensor readings have varying attributes that don't fit rigid schemas
3. **Rapid prototyping** — Schema-on-read lets you ingest first and structure later — "store now, explore later"

### When to Choose What
```
Structured data + strict integrity → PostgreSQL (relational)
Analytical queries at scale        → DuckDB (columnar)
Hierarchical / semi-structured     → MongoDB (document)
Caching / sessions / real-time     → Redis (key-value)   [Week 11]
Similarity search / embeddings     → ChromaDB (vector)    [Week 13+]
```

---

## Additional Resources

### Documentation
- [MongoDB Manual: Data Modeling Introduction](https://www.mongodb.com/docs/manual/core/data-modeling-introduction/) — Official guide to embedding vs. referencing
- [MongoDB Manual: Schema Validation](https://www.mongodb.com/docs/manual/core/schema-validation/) — Optional schema enforcement for document collections

### Articles
- [Visual Guide to NoSQL Systems — Nathan Hurst](http://blog.nahurst.com/visual-guide-to-nosql-systems) — The widely-referenced CAP triangle visualization
- [Martin Kleppmann: "Please stop calling databases CP or AP"](https://martin.kleppmann.com/2015/05/11/please-stop-calling-databases-cp-or-ap.html) — Nuanced critique of oversimplified CAP classifications

---

## Questions or Issues?

If you encounter problems with:
- **Concept material** — Review the CAP theorem section carefully; the key insight is that partition tolerance is not optional
- **Modeling exercises** — Start by asking "Is this data bounded or unbounded?" to decide embed vs. reference
- **JSON formatting** — Use the `pretty()` helper function provided in the lab setup cell
- **Relational comparisons** — Review your Week 04 (DDL/DML) notes to contrast relational and document approaches
