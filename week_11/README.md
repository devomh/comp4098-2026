# Week 11: Redis & Data Security

## Overview

This week completes **Module 3: NoSQL** with two distinct but complementary topics. First, you'll explore Redis — an in-memory key-value store that adds caching and sub-millisecond lookups to your persistence toolkit. Then, you'll confront one of the most persistent threats in data management: SQL injection. You'll learn how attackers exploit unsanitized input and how parameterized queries eliminate the vulnerability entirely.

By the end of this week, you'll have hands-on experience with all four database paradigms (relational, columnar, document, key-value) and understand how to connect to any of them securely.

---

## Lesson 21: Key-Value Stores & Redis

### Learning Objectives

- Define the key-value data model and explain how it differs from document and relational models
- Identify use cases where key-value stores outperform relational and document databases
- Describe Redis's core data structures: Strings, Hashes, Lists, Sets, and Sorted Sets
- Explain caching strategies (Cache-Aside, Write-Through) and when to use each
- Define TTL (Time-To-Live) and explain its role in cache management
- Position Redis within the polyglot persistence stack alongside PostgreSQL, DuckDB, and MongoDB

### Materials

**Concept Notes:**
- [Key-Value Stores & Redis](w11_l21_concept_redis_keyvalue.md)

**Lab Exercise:**
- [Lab: Redis Data Structures & Caching](w11_l21_lab_redis_practice.md)

### Interactive Notebook

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/devomh/comp4098-2026/blob/main/week_11/w11_l21_lab_redis_practice.ipynb)

---

## Lesson 22: Data Security & Secure Connectivity

### Learning Objectives

- Explain SQL injection as an attack vector and why it ranks in the OWASP Top 10
- Describe the **parser / binder separation** that makes parameterized queries safe
- Articulate the "restriction window" — why an attacker's injection must conform to the victim query's column count and types — and reframe SQLi as a grammar problem, not an escape-character problem
- Distinguish the four major SQLi categories: classic, UNION-based, blind, and second-order
- Implement parameterized queries in Python (psycopg2, SQLAlchemy) and identify what they do **not** protect (identifiers, `ORDER BY`)
- Apply **defense in depth**: parameterization, salted + iterated password hashing (bcrypt/argon2), principle of least privilege, credential hygiene with `.env` files and secret managers, query monitoring

### Lesson Flow (lab-first)

This lesson inverts the usual order: **run the lab first**, then read the concept file as a debrief. You will attack a deliberately vulnerable product-search function through five escalating rungs (filter bypass → column discovery → UNION type probing → data exfiltration → stacked destruction), then crack the stolen password hashes, then rebuild everything with parameterized queries. The concept file explains *why* each attack worked and each defense held.

### Materials

**Lab Exercise (start here):**
- [Lab: SQL Injection & Secure Connectivity](w11_l22_lab_sql_injection.md)

**Concept Notes (debrief):**
- [Data Security & Secure Connectivity](w11_l22_concept_data_security.md)

### Interactive Notebook

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/devomh/comp4098-2026/blob/main/week_11/w11_l22_lab_sql_injection.ipynb)

---

## Key Concepts

### Redis Data Structures

| Data Structure | Redis Type | Use Case | Example |
| :--- | :--- | :--- | :--- |
| **String** | `SET` / `GET` | Caching, counters, session tokens | `SET user:1001:session "abc123"` |
| **Hash** | `HSET` / `HGET` | Object storage (user profiles, configs) | `HSET user:1001 name "Alice" age 30` |
| **List** | `LPUSH` / `RPOP` | Queues, activity feeds, recent items | `LPUSH notifications:1001 "New order"` |
| **Set** | `SADD` / `SMEMBERS` | Tags, unique visitors, set operations | `SADD product:42:tags "electronics" "sale"` |
| **Sorted Set** | `ZADD` / `ZRANGE` | Leaderboards, rankings, time-series | `ZADD leaderboard 9500 "player:42"` |

### Caching Strategies

- **Cache-Aside (Lazy Loading)** — Application checks cache first; on miss, queries the database and populates the cache
- **Write-Through** — Application writes to cache and database simultaneously; cache is always current
- **TTL (Time-To-Live)** — Automatic expiration that prevents stale data and manages memory

### SQL Injection — The Attack Ladder

The L22 lab walks through five escalating attacks against a vulnerable product-search function. Each rung teaches a different mechanic:

| Rung | Example Input | What it teaches |
| :--- | :--- | :--- |
| **1. Filter bypass** | `' OR 1=1 --` | Always-true clause dissolves the `WHERE` filter — the canonical SQLi move |
| **2. Column discovery** | `' ORDER BY 3 --` | Probing the query shape through error messages |
| **3. Type probing (UNION)** | `' UNION SELECT NULL, NULL, NULL --` | The "restriction window": UNION must match column count and types |
| **4. Data exfiltration** | `' UNION SELECT 0, username, password_hash FROM users --` | Smuggling another table's rows through the vulnerable query |
| **5. Stacked destruction** | `'; DROP TABLE products; --` | Chained statements (driver-dependent); why least-privilege DB users matter |

**Second-order injection** is demonstrated separately: a malicious username is stored cleanly via a parameterized INSERT, then later fires when a different, non-parameterized query concatenates it back into SQL.

### Defense in Depth

- **Parameterized queries** — the primary defense; parser commits to grammar before data is bound
- **Salted, iterated password hashing** (bcrypt / argon2) — bounds damage when hashes are stolen; the lab cracks plain SHA-256 via dictionary attack to motivate this
- **Principle of least privilege** — a read-only DB user cannot `DROP TABLE` even after a successful injection
- **Credential hygiene** — `.env` files with `.gitignore`, environment variables in deployment, secret managers for production
- **Monitoring and auditing** — detects the raw query that someone adds in a later PR and slips past review

---

## Connection from Previous Weeks

### Week 10 -> Week 11: From MongoDB to Redis and Security
- **Week 10:** Mastered document storage and analytics with MongoDB's CRUD operations and Aggregation Pipeline
- **Week 11:** Redis adds the fourth database paradigm (key-value) for caching and fast lookups; data security addresses how to connect to *all* databases safely
- **Key Connection:** MongoDB completes the document paradigm; Redis adds caching as a complementary layer, not a replacement — polyglot persistence means choosing the right tool for each access pattern

### Week 11 -> Week 12: From NoSQL to the Data Access Layer
- **Week 11:** Completed Module 3 with all four paradigms (relational, columnar, document, key-value) and secure connectivity patterns
- **Week 12 Preview:** Module 4 introduces the Data Access Layer (DAL) — architectural patterns (DAO, Repository, ORM) that organize how application code interacts with databases
- **Key Connection:** The secure connectivity practices from Lesson 22 (parameterized queries, credential management) become foundational patterns in the DAL architecture

---

## Technical Notes

### Redis in Colab
The L21 lab installs Redis Community Edition locally inside the Colab runtime using `apt-get`. This approach:
- Requires no account setup or cloud credentials
- Is completely self-contained (reinstalls fresh each session)
- Uses the same `redis-py` code that works against any Redis instance

### PostgreSQL in Colab
The L22 lab installs PostgreSQL locally inside the Colab runtime to demonstrate SQL injection in a safe, controlled environment. All attacks target this local instance only.

### Datasets
- **L21 Lab:** Explores all five Redis data structures (Strings, Hashes, Lists, Sets, Sorted Sets) and builds a Cache-Aside caching pattern with a simulated database
- **L22 Lab:** Sets up a two-table scenario — a public `products` table (the storefront search) and a private `users` table with SHA-256 password hashes. The attacker reaches `users` through the `products` search, then a dictionary attack cracks the stolen hashes. The lab then rebuilds both with parameterized queries and demonstrates how salted bcrypt would have bounded the damage.

---

## Additional Resources

### Documentation
- [Redis Documentation](https://redis.io/docs/) — Official commands reference and data structure guides
- [redis-py Documentation](https://redis-py.readthedocs.io/en/stable/) — Official Python client library
- [OWASP SQL Injection](https://owasp.org/www-community/attacks/SQL_Injection) — Comprehensive SQL injection reference
- [psycopg2 Documentation: Passing Parameters](https://www.psycopg.org/docs/usage.html#passing-parameters-to-sql-queries) — Parameterized query guide

### Courses
- [Redis University](https://university.redis.io/) — Free official Redis courses
- [OWASP WebGoat](https://owasp.org/www-project-webgoat/) — Interactive security training application

### Articles
- [Redis Data Types Tutorial](https://redis.io/docs/latest/develop/data-types/) — Hands-on guide to each data structure
- [Bobby Tables: A Guide to Preventing SQL Injection](https://bobby-tables.com/) — Language-specific parameterized query examples
