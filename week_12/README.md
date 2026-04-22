# Week 12: The Data Access Layer

## Overview

This week opens **Module 4: Data Access Layer**. After three modules spent learning *storage engines* (relational, columnar, document, key-value), Week 12 zooms in on the **application-side** question those modules deliberately postponed: how should code that *uses* a database be organized?

Lesson 23 establishes the architectural case for a Data Access Layer — separation of concerns, connection pooling, database independence — and you build a minimal DAL with SQLAlchemy Core. Lesson 24 then introduces the implementation patterns that turn a DAL into production code: the **DAO** pattern, the **Repository** pattern, and the **ORM**, all illustrated with SQLAlchemy.

By the end of the week, you'll have refactored the same student/courses/enrollments example across three levels of abstraction — raw SQL, SQLAlchemy Core, and SQLAlchemy ORM — and will be able to articulate the trade-offs of each.

---

## Lesson 23: DAL Architecture & Connectivity

### Learning Objectives

- Explain Separation of Concerns and why application code should not contain raw database logic
- Define the Data Access Layer (DAL) and its role in a software architecture
- Describe Database Independence and why it matters for production systems
- Explain how database drivers (e.g., `psycopg2`, `pymongo`) manage connections
- Describe Connection Pooling and explain why it is critical for performance
- Distinguish between connection-per-request and pooled connection strategies
- Read and construct database connection strings (DSNs) for PostgreSQL

### Materials

**Concept Notes:**
- [The Data Access Layer: Architecture & Connectivity](w12_l23_concept_dal_architecture.md)

**Lab Exercise:**
- [Lab: DAL Architecture & Connection Pooling](w12_l23_lab_dal_connectivity.md)

### Interactive Notebook

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/devomh/comp4098-2026/blob/main/week_12/w12_l23_lab_dal_connectivity.ipynb)

---

## Lesson 24: Implementation Patterns — DAO, Repository & ORM

### Learning Objectives

- Define the DAO (Data Access Object) pattern and explain how it encapsulates data access logic
- Define the Repository pattern and distinguish it from a DAO
- Explain what an ORM (Object-Relational Mapping) is and why it exists
- Map relational concepts (tables, rows, columns, foreign keys) to ORM equivalents (classes, instances, attributes, relationships)
- Describe SQLAlchemy's two-layer architecture: Core (SQL toolkit) vs. ORM
- Explain the Session as the unit-of-work manager in SQLAlchemy's ORM
- Compare raw SQL, SQLAlchemy Core, and SQLAlchemy ORM approaches for the same task

### Materials

**Concept Notes:**
- [Implementation Patterns: DAO, Repository & ORM with SQLAlchemy](w12_l24_concept_dao_orm.md)

**Lab Exercise:**
- [Lab: DAO & ORM with SQLAlchemy](w12_l24_lab_dao_orm_sqlalchemy.md)

### Interactive Notebook

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/devomh/comp4098-2026/blob/main/week_12/w12_l24_lab_dao_orm_sqlalchemy.ipynb)

---

## Key Concepts

### The N-Tier Architecture

```
Presentation  →  Business Logic  →  Data Access Layer  →  Storage
```

Each layer depends only on the one below it. The DAL is the boundary between "what data do I need?" and "how do I get it from the database?" — and it's the only module that should ever see connection strings, SQL, or driver-specific calls.

### Connection Pooling — Why It Matters

| Metric | No Pooling | With Pooling |
| :--- | :--- | :--- |
| Per-query connection setup | ~50–200 ms (prod) | ~0 ms (reused) |
| Concurrent queries vs. PG `max_connections` | Hits the ceiling fast | Bounded by pool size, not PG limit |
| Server memory (per PG connection) | ~5–10 MB | Same, but far fewer connections |
| Connection-leak risk | High (manual `close()`) | Low (pool manages lifecycle) |

Typical pool sizing: **5–20 connections**, roughly **2× database-server CPU cores** for CPU-bound workloads.

### Three Levels of Abstraction

| Level | Approach | Example | Portability |
| :--- | :--- | :--- | :--- |
| **0** | Raw driver calls | `psycopg2.connect(); cur.execute(...)` | Tied to one DB |
| **1** | DAL with raw SQL | `dal.get_student(id)` — SQL hidden inside | SQL is portable; driver is specific |
| **2** | ORM / Query Builder | `session.query(Student).get(id)` | Swap engine URL, keep the code |

L23 lands you at Level 1; L24 takes you to Level 2 with SQLAlchemy ORM.

### DAO vs. Repository

| Pattern | Centered on | Typical method | Returns |
| :--- | :--- | :--- | :--- |
| **DAO** (Data Access Object) | A single table/collection | `student_dao.find_by_id(3)` | Row-shaped object (dict, dataclass, ORM model) |
| **Repository** | A business concept / aggregate | `enrollment_repo.get_transcript(3)` | Rich domain object assembled from multiple tables |

In practice many projects use the terms interchangeably — what matters is that data access lives behind a clean, testable interface.

### SQLAlchemy's Two Layers

- **Core** — SQL expression toolkit. You still think in tables and SQL, but Python-authored (`select(...).where(...)`) and portable across dialects.
- **ORM** — Maps Python classes to tables and manages identity, change tracking, and transactions through a **Session** (unit-of-work).

Both layers share the same `Engine` and connection pool — you can drop from ORM to Core inside the same session when you need precise control.

---

## Connection from Previous Weeks

### Week 11 → Week 12: From Secure Connectivity to Structured Access

- **Week 11:** Closed Module 3 with all four storage paradigms (relational, columnar, document, key-value) and the secure-connectivity practices (parameterized queries, credential hygiene) that apply to all of them
- **Week 12:** The secure-connectivity habits from L22 become architectural defaults — the DAL is now the *only* module that sees credentials, SQL strings, and driver calls
- **Key Connection:** L22's `.env` + parameterized-query patterns reappear as DAL internals. Nothing new to learn security-wise; instead, you learn where that security lives in a well-organized codebase.

### Week 12 → Week 13: From Structured DAL to Unstructured Retrieval

- **Week 12:** Built DAL / DAO / ORM patterns over structured stores where `SELECT ... WHERE` answers the query
- **Week 13 Preview:** Module 5 introduces **vector search** — a paradigm for text where similarity, not equality, is the access pattern. ChromaDB joins the polyglot stack.
- **Key Connection:** The DAL idea survives. A `retrieve(query)` function over ChromaDB is the same architectural move as `student_dao.find_by_id(3)` — hide engine specifics behind a clean function the rest of the app can call.

---

## Technical Notes

### PostgreSQL in Colab

Both labs install PostgreSQL 15 locally inside the Colab runtime via `apt-get` and create a `student` / `lab_pass` user against a `university_db` database. This matches the pattern used in Weeks 4, 8, and 11 and keeps the lab fully self-contained (no cloud accounts, no leaked credentials).

### Why Localhost Timings Understate the Pooling Win

The L23 benchmark measures per-query overhead on `localhost` with no TLS — a best case of roughly **5–20 ms per connection**. In production (remote host, TLS handshake, cloud networking), that overhead is typically **50–200 ms**, so the pooling speedup in real systems is noticeably larger than what the lab shows.

### SQLAlchemy Version

Labs target **SQLAlchemy 2.x** (the current stable line as of early 2026). Expect `Mapped[...]` type annotations, `select(...)` queries, and `session.execute(...)` — *not* the legacy `Query` API.

### Datasets

Both labs use the same three-table student/courses/enrollments schema — 5 students, 4 courses, 11 enrollments — so L24 can refactor the L23 example directly and the diff between "raw SQL DAL" and "ORM DAO" is clean.

---

## Additional Resources

### Documentation

- [SQLAlchemy 2.0 — Unified Tutorial](https://docs.sqlalchemy.org/en/20/tutorial/) — The canonical starting point; covers Core and ORM in one pass
- [SQLAlchemy: Engine Configuration](https://docs.sqlalchemy.org/en/20/core/engines.html) — Connection strings, pool parameters, `QueuePool` vs. `NullPool`
- [psycopg2: Connection Pooling](https://www.psycopg.org/docs/pool.html) — Manual connection pool API for PostgreSQL
- [PgBouncer](https://www.pgbouncer.org/) — Industry-standard external connection pooler; commonly layered below app-level pools

### Articles

- [The Twelve-Factor App: Config](https://12factor.net/config) — The standard argument for keeping credentials out of source code
- [Heroku: Python Concurrency and Database Connections](https://devcenter.heroku.com/articles/python-concurrency-and-database-connections) — Practical guide to pool sizing under real load
- [Martin Fowler: Patterns of Enterprise Application Architecture — DAO, Repository, Unit of Work](https://martinfowler.com/eaaCatalog/) — Original reference for the design patterns used this week
