# COMP 4098: Data Management and Architectures for Data Science

**Universidad de Puerto Rico en Humacao**
**Departamento de Matemáticas**
**Enero - Mayo 2026**

---

## Course Description

This course transitions from traditional database systems to modern data engineering and architecture tailored for Data Science. You will move beyond basic storage mechanics to master the architectures that power modern analytics and AI.

The curriculum contrasts **Transactional (OLTP)** systems with **Analytical (OLAP)** engines, bridging the gap between raw data storage and actionable insights. By exploring a **polyglot persistence stack**—including PostgreSQL, DuckDB, MongoDB, and Vector Databases—you'll learn to architect systems that handle structured, semi-structured, and unstructured data (text/embeddings) essential for AI applications like **Retrieval-Augmented Generation (RAG)**.

**Key Shift:** From *"How do I write a query?"* to *"Which database should I use for this problem?"*

---

## Learning Objectives

By the end of this course, you will be able to:

1. **Distinguish and Architect Data Systems:** Design solutions using the appropriate storage engine (Row-oriented vs. Column-oriented) based on workload requirements (OLTP vs. OLAP).

2. **Master Analytical SQL:** Go beyond basic CRUD to perform complex data analysis using Window Functions, CTEs, and aggregations for high-performance reporting.

3. **Manage Diverse Data Shapes:** Effectively model and query data using Relational (PostgreSQL), Document (MongoDB), and Key-Value (Redis) stores.

4. **Engineer Production-Ready Access:** Implement robust Data Access Layers (DAL) using Connection Pooling, DAOs, and ORMs to decouple application logic from database infrastructure.

5. **Build AI-Ready Data Pipelines:** Integrate Vector Databases and Embeddings to support semantic search and build Retrieval-Augmented Generation (RAG) systems for unstructured data.

---

## Course Structure

### Module 1: Relational Foundations & Transactional SQL (4 weeks)
Master the relational model, data integrity, and the language of standard databases. Topics include:
- The Data Lifecycle (Capture, Store, Process, Analyze, Archive)
- Relational Model: Relations, Keys, Referential Integrity
- Entity-Relationship (ER) Modeling
- Normalization (1NF - 3NF) and Data Quality
- Transactional SQL with PostgreSQL (DDL, DML, CRUD)

### Module 2: Analytical SQL & Architecture (4 weeks)
High-performance data analysis, columnar storage, and complex SQL. Topics include:
- OLTP vs. OLAP: Row-oriented vs. Column-oriented storage
- Introduction to DuckDB for in-process analytics
- Advanced SQL: Complex Joins, Aggregations, GROUP BY
- Window Functions (RANK, DENSE_RANK, PARTITION BY)
- Common Table Expressions (CTEs) and advanced analytics
- Performance benchmarking: PostgreSQL vs. DuckDB

### Module 3: NoSQL and Flexible Data Models (3 weeks)
Managing data that doesn't fit neatly into rows and columns. Topics include:
- CAP Theorem and distributed systems
- Document Stores: MongoDB for hierarchical data
- Key-Value Stores: Redis for caching and fast lookups
- Schema-on-Read vs. Schema-on-Write

### Module 4: Data Access & Architecture (1 week)
Bridging the gap between the database and application code. Topics include:
- Data Access Layer (DAL) architecture
- Design Patterns: DAO, Repository, ORM
- Connection Pooling and database independence
- Separation of concerns in production systems

### Module 5: Modern Architectures & AI (3 weeks)
The "AI Stack" - Vector Search and Retrieval-Augmented Generation. Topics include:
- Unstructured data and embeddings
- Vector Databases: ChromaDB/LanceDB
- Semantic search and similarity matching
- RAG (Retrieval-Augmented Generation) architecture
- Final Project: "Chat with Your Data" system

---

## Technologies & Tools

- **Relational Databases:** PostgreSQL
- **Analytical Databases:** DuckDB
- **Document Databases:** MongoDB
- **Key-Value Stores:** Redis
- **Vector Databases:** ChromaDB / LanceDB
- **Programming:** Python (Pandas, SQLAlchemy, ORMs)
- **Environment:** Google Colab (primary), Jupyter Notebooks
- **Version Control:** Git & GitHub

---

## Prerequisites

- Strong Python programming skills
- Basic SQL knowledge (SELECT, WHERE, JOIN)
- Familiarity with Pandas and data manipulation
- Basic understanding of data structures

---

## Getting Started

1. **Review the Syllabus:** Check the [official course guide](00_syllabus/guia-comp4098.pdf) for evaluation criteria, rules, and schedule.

2. **Start with Week 01:** Navigate to [week_01/](week_01/) and follow the README to begin with the Data Lifecycle lesson.

3. **Use Google Colab:** All labs are designed to run in Google Colab - no local installation required. Click the "Open in Colab" badges in each week's README.

4. **Stay Organized:** Each week contains:
   - `README.md` - Week overview and lesson links
   - `w0X_l0Y_concept_*.md` - Conceptual lecture notes
   - `w0X_l0Y_lab_*.md` - Lab instructions
   - `w0X_l0Y_lab_*.ipynb` - Interactive Jupyter notebooks

---

## Repository Structure

```
comp4098-2026-01/
├── README.md                    # This file
├── 00_syllabus/                 # Course syllabus and official documents
├── week_01/                     # Week 1: Foundations of Data Management
│   ├── README.md
│   ├── w01_l01_concept_intro_lifecycle.md
│   ├── w01_l01_lab_colab_setup.md
│   └── w01_l01_lab_colab_setup.ipynb
├── week_02/                     # Week 2: Conceptual & Logical Modeling
├── week_03/                     # Week 3: Normalization & Data Quality
├── ...
├── _templates/                  # Templates for lessons and labs
└── _design/                     # Course design guidelines
```

---

## Course Philosophy

> *"A Chef (Data Scientist) shouldn't just know how to cook (Model data); they need to know how the ingredients arrive, how they are stored to keep them fresh, and how to organize the kitchen for speed (Data Architecture)."*

This course transforms you from a **data consumer** to a **data architect** - someone who can design and build the systems that power modern data science and AI.

---

## License & Usage

This work is licensed under a [Creative Commons Attribution 4.0 International License (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/).

You are free to use, share, and adapt these materials for any purpose, including commercially, as long as you provide appropriate attribution.

**Suggested Citation:**
Medina, O. (2026). *COMP 4098: Data Management and Architectures for Data Science*. Universidad de Puerto Rico en Humacao. https://github.com/devomh/comp4098-2026
