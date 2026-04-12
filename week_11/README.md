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
- Demonstrate how unsanitized user input can alter SQL query logic
- Implement parameterized queries as the primary defense against SQL injection
- Distinguish between string formatting (vulnerable) and parameterized queries (safe) in Python
- Describe secure credential management using environment variables and `.env` files
- Explain why connection strings should never appear in source code

### Materials

**Concept Notes:**
- [Data Security & Secure Connectivity](w11_l22_concept_data_security.md)

**Lab Exercise:**
- [Lab: SQL Injection & Secure Connectivity](w11_l22_lab_sql_injection.md)

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

### SQL Injection

| Attack Type | Example Input | Effect |
| :--- | :--- | :--- |
| **Tautology** | `' OR '1'='1` | Bypasses authentication by making WHERE always true |
| **Union-based** | `' UNION SELECT * FROM users --` | Extracts data from other tables |
| **Destructive** | `'; DROP TABLE users; --` | Deletes entire tables |

### Defense Strategies

- **Parameterized queries** — The primary defense; separates SQL structure from user data
- **Environment variables / `.env` files** — Keep credentials out of source code
- **Principle of least privilege** — Database users should have only the permissions they need

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
- **L22 Lab:** Sets up a vulnerable user authentication database, demonstrates SQL injection attacks, then fixes vulnerabilities with parameterized queries

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
