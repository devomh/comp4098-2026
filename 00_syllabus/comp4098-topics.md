# COMP 4098: Data Management and Architectures for Data Science
**Detailed Syllabus & Lesson Plan**

**Course Description**
This course transitions from traditional database systems to modern data engineering and architecture tailored for Data Science. Students will move beyond basic storage mechanics to master the architectures that power modern analytics and AI. The curriculum contrasts Transactional (OLTP) systems with Analytical (OLAP) engines, bridging the gap between raw data storage and actionable insights. By exploring a polyglot persistence stack—including PostgreSQL, DuckDB, MongoDB, and Vector Databases—students will learn to architect systems that handle structured, semi-structured, and unstructured data (text/embeddings) essential for AI applications like Retrieval-Augmented Generation (RAG).

**Course Goals**
By the end of this course, students will be able to:
1.  **Distinguish and Architect Data Systems:** Design solutions using the appropriate storage engine (Row-oriented vs. Column-oriented) based on workload requirements (OLTP vs. OLAP).
2.  **Master Analytical SQL:** Go beyond basic CRUD to perform complex data analysis using Window Functions, CTEs, and aggregations for high-performance reporting.
3.  **Manage Diverse Data Shapes:** Effectively model and query data using Relational (PostgreSQL), Document (MongoDB), and Key-Value (Redis) stores.
4.  **Engineer Production-Ready Access:** Implement robust Data Access Layers (DAL) using Connection Pooling, DAOs, and ORMs to decouple application logic from database infrastructure.
5.  **Build AI-Ready Data Pipelines:** Integrate Vector Databases and Embeddings to support semantic search and build Retrieval-Augmented Generation (RAG) systems for unstructured data.

**Course Structure:** 15 Weeks
**Frequency:** 2 Lessons per week (80 minutes each)
**Target Audience:** Senior Data Science Students (Strong Python skills, basic SQL knowledge)

---

## Module 1: Relational Foundations & Transactional SQL
*Focus: Mastering the relational model, data integrity, and the language of standard databases.*

### Week 1: Foundations of Data Management
*   **Lesson 1: Introduction & The Data Lifecycle**
    *   **Topics:** Course overview & tools setup (Google Colab). The Data Lifecycle: Capture, Store, Process, Analyze, Archive.
    *   **Activity:** Discussion on why we need ACID compliance in the lifecycle.
*   **Lesson 2: The Relational Model**
    *   **Topics:** Relations, Tuples, Attributes, Domains. Keys: Superkeys, Candidate Keys, Primary Keys, Foreign Keys. Referential Integrity.
    *   **Activity:** Paper-based exercise: Identify keys and integrity violations in a sample dataset.

### Week 2: Conceptual & Logical Modeling
*   **Lesson 3: Entity-Relationship (ER) Modeling**
    *   **Topics:** Entities, Attributes (Composite, Multivalued, Derived), Relationships, Cardinality (1:1, 1:N, M:N). Strong vs. Weak entities.
    *   **Activity:** Design an ER diagram for a system (e.g., "University Course Registration").
*   **Lesson 4: Logical Design (ER to Relational)**
    *   **Topics:** Mapping Strong/Weak entities to tables. Mapping 1:N and M:N relationships. Handling Multi-valued attributes. Normalization context.
    *   **Activity:** Convert the Week 2 ER diagram into a set of Relational Schemas (Tables).

### Week 3: Normalization & Data Quality
*   **Lesson 5: Normalization Theory (1NF - 3NF)**
    *   **Topics:** Data Integrity. Update/Delete/Insert Anomalies. Functional Dependencies. 1NF (Atomicity), 2NF (Partial Dependencies), 3NF (Transitive Dependencies).
    *   **Activity:** Normalizing a "messy" dataset to 3NF.
*   **Lesson 6: Practical Design & Denormalization**
    *   **Topics:** When to stop normalizing. Write Performance vs. Read Performance.
    *   **Activity:** Discussion: Trade-offs of normalization in Data Science workflows.

### Week 4: Transactional SQL (PostgreSQL)
*   **Lesson 7: DDL & Schema Implementation**
    *   **Topics:** PostgreSQL architecture. Data Types. `CREATE`, `ALTER`, `DROP` Tables. Constraints (`NOT NULL`, `UNIQUE`, `CHECK`).
    *   **Lab (Colab):** Implement the schema in PostgreSQL using SQL Magic.
*   **Lesson 8: DML & Basic Querying**
    *   **Topics:** `INSERT`, `UPDATE`, `DELETE`. Basic `SELECT` with `WHERE`, `ORDER BY`.
    *   **Lab (Colab):** Populate tables and run basic CRUD operations.

---

## Module 2: Analytical SQL & Architecture
*Focus: High-performance data analysis, Columnar storage, and complex SQL.*

### Week 5: Analytical Architectures
*   **Lesson 9: OLTP vs. OLAP**
    *   **Topics:** Row-Oriented vs. Column-Oriented storage. Compression and Vectorization in column stores.
    *   **Activity:** Comparison of storage layouts.
*   **Lesson 10: Introduction to DuckDB**
    *   **Topics:** In-process OLAP. Reading data from CSV/Parquet. Comparison with Postgres.
    *   **Lab (Colab):** Querying local files using DuckDB.

### Week 6: Advanced SQL Techniques I
*   **Lesson 11: Complex Joins**
    *   **Topics:** `INNER`, `LEFT`, `RIGHT`, `FULL OUTER` joins. Complex join logic.
    *   **Lab (Colab):** Solving multi-table analytical questions.
*   **Lesson 12: Aggregation & Grouping**
    *   **Topics:** `GROUP BY`, `HAVING`. Aggregations (`COUNT`, `SUM`, `AVG`).
    *   **Lab (Colab):** Generating summary reports.

### Week 7: Advanced SQL Techniques II
*   **Lesson 13: Analytical Functions (Window Functions)**
    *   **Topics:** `OVER`, `PARTITION BY`, `ORDER BY`. Ranking: `RANK`, `DENSE_RANK`, `ROW_NUMBER`.
    *   **Lab (Colab):** Solving "Top N" and ranking problems.
*   **Lesson 14: CTEs & Advanced Analytics**
    *   **Topics:** Common Table Expressions (CTEs). Offset functions: `LEAD`, `LAG`.
    *   **Lab (Colab):** Year-Over-Year growth and moving averages.

### Week 8: Performance Lab
*   **Lesson 15: Lab Preparation**
    *   **Topics:** Data generation strategies. Loading large datasets (10M+ rows).
    *   **Lab (Colab):** Preparing the dataset for the benchmark.
*   **Lesson 16: The Performance Benchmark**
    *   **Topics:** Analyzing query plans (conceptual). Execution time measurement.
    *   **Lab (Colab):** Experiment: Load 10M rows into Postgres and DuckDB. Compare execution times for analytical queries.

---

## Module 3: NoSQL and Flexible Data Models
*Focus: Managing data that doesn't fit neatly into rows and columns.*

### Week 9: Distributed Concepts & Documents
*   **Lesson 17: The CAP Theorem**
    *   **Topics:** Consistency, Availability, Partition Tolerance. Schema-on-Read vs. Schema-on-Write.
    *   **Activity:** Discussion on distributed system trade-offs.
*   **Lesson 18: Document Stores (MongoDB)**
    *   **Topics:** Modeling hierarchical data in JSON. Querying nested documents.
    *   **Activity:** Modeling complex objects in JSON vs. Tables.

### Week 10: MongoDB in Practice
*   **Lesson 19: MongoDB Essentials**
    *   **Topics:** MongoDB Atlas setup. Basic CRUD (`find`, `insert`).
    *   **Lab (Colab):** Connecting to Atlas and performing basic operations.
*   **Lesson 20: Advanced Document Querying**
    *   **Topics:** Querying arrays and nested structures.
    *   **Lab (Colab):** Analyzing a hierarchical dataset (e.g., product logs).

### Week 11: Key-Value Stores
*   **Lesson 21: Redis Concepts**
    *   **Topics:** Key-Value stores. Caching strategies. Fast lookups.
    *   **Activity:** Designing a caching layer.
*   **Lesson 22: Redis Implementation**
    *   **Topics:** Redis data structures.
    *   **Lab (Colab):** Implementing a simple cache or lookup system.

---

## Module 4: Data Access & Architecture
*Focus: Bridging the gap between the database and the application code.*

### Week 12: The Data Access Layer (DAL)
*   **Lesson 23: Architecture & Connectivity**
    *   **Topics:** Separation of Concerns. The Data Access Layer (DAL) - "Persistence Layer". **Database Independence**. Connection Management: Connection strings, drivers (ODBC/JDBC concepts). **Connection Pooling**.
    *   **Activity:** Discussion: Why separation of concerns matters for maintainability.
*   **Lesson 24: Implementation Patterns**
    *   **Topics:** **DAO** (Data Access Object) Pattern. **Repository Pattern**. **ORM** (Object-Relational Mapping).
    *   **Demo (Python):** A script comparing "Raw SQL" vs. "ORM/DAO" approaches.

---

## Module 5: Modern Architectures & AI
*Focus: The "AI Stack" - Vector Search and RAG.*

### Week 13: Unstructured Data & Vector Databases
*   **Lesson 25: Unstructured Data & Embeddings**
    *   **Topics:** Handling text and binary data. What are embeddings? (High-dimensional vectors).
    *   **Activity:** Visualizing vector similarity.
*   **Lesson 26: Vector Similarity Search**
    *   **Topics:** Cosine Similarity, Euclidean Distance. Vector Stores: **ChromaDB** or **LanceDB**.
    *   **Lab (Colab):** Generating embeddings and performing similarity search.

### Week 14: RAG Architecture
*   **Lesson 27: RAG Concepts**
    *   **Topics:** Retrieval-Augmented Generation (RAG). Connecting a Vector DB to an LLM.
    *   **Activity:** Architecture breakdown of a RAG system.
*   **Lesson 28: Building a RAG System**
    *   **Topics:** Indexing, Retrieval, Generation.
    *   **Lab (Colab):** *Final Project Part 1:* Building the "Chat with your Data" backend (Ingestion & Retrieval).

### Week 15: Final Project Integration
*   **Lesson 29: RAG Integration & Tuning**
    *   **Topics:** Connecting the retrieval layer to the LLM. Tuning results.
    *   **Lab (Colab):** *Final Project Part 2:* Completing the "Chat with your Data" system.
*   **Lesson 30: Final Project Showcase**
    *   **Activity:** Presentation of Final Projects.