# Week 02: Data Modeling & Logical Design

## Overview
This week covers the conceptual and logical phases of database design. You'll learn how to capture business requirements as Entity-Relationship (ER) diagrams, then translate those diagrams into relational schemas ready for implementation. This is the bridge between "what the business needs" and "what the database stores."

---

## Lesson 03: Entity-Relationship (ER) Modeling

### Learning Objectives
By the end of this lesson, you will be able to:
- Identify **Entities**, **Attributes**, and **Relationships** in a business requirement
- Distinguish between **Strong** and **Weak** entities
- Define **Cardinality** (1:1, 1:N, M:N) and understand its impact on data integrity
- Explain *why* we model data conceptually before writing code
- **Understand the difference between ER diagrams (conceptual) and Relational schemas (implementation)**

### Materials

**Concept Notes:**
- [Entity-Relationship (ER) Modeling](w02_l03_concept_er_modeling.md)
  - **NEW:** Comprehensive comparison table: ER Model vs Relational Model conventions
  - Covers entity naming, data types, FK handling, and when to use each approach

**Lab Exercise:**
- [ER Diagramming](w02_l03_lab_er_diagramming.md)
  - Hands-on practice with Mermaid.js
  - University Course Registration System example

### Interactive Notebook

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/devomh/comp4098-2026/blob/main/week_02/w02_l03_lab_er_diagramming.ipynb)

Click the badge above to open the lab notebook directly in Google Colab.

---

## Lesson 04: Logical Design (ER to Relational)

### Learning Objectives
By the end of this lesson, you will be able to:
- Apply the "mapping algorithm" to convert ER Diagrams into Relational Schemas (Tables)
- Map **1:N Relationships** using **Foreign Keys**
- Map **M:N Relationships** using **Junction (Associative) Tables**
- Map **Weak Entities** effectively
- Adopt professional **Naming Conventions** for database objects
- **Create both pure ER diagrams and implementation-ready Relational schemas**

### Materials

**Concept Notes:**
- [Logical Design: ER to Relational](w02_l04_concept_logical_design.md)
  - Mapping rules for all relationship types
  - Surrogate vs Natural keys discussion
  - Self-referencing relationships

**Lab Exercise:**
- [Schema Conversion](w02_l04_lab_schema_conversion.md)
  - Converts University system from Lesson 03
  - **NEW:** Comprehensive Library Management System challenge
    - Part A: Create pure ER diagram (no data types, no FK columns)
    - Part B: Create Relational schema (with data types and FK columns)
    - Part C: Reflection questions on the differences
  - Tests understanding of ER vs Relational conventions

### Interactive Notebook

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/devomh/comp4098-2026/blob/main/week_02/w02_l04_lab_schema_conversion.ipynb)

Click the badge above to open the lab notebook directly in Google Colab.

---

## Key Concepts

### Conceptual Modeling
- **ER Modeling:** Entities, Attributes, Relationships
- **Entity Types:** Strong entities vs Weak entities
- **Cardinality:** 1:1, 1:N, M:N relationships
- **Notation Styles:** Chen notation vs Crow's Foot notation

### Logical Design
- **Mapping ER to Relational:** Converting diagrams to table schemas
- **Foreign Keys:** Implementing 1:N relationships (FK goes on "many" side)
- **Junction Tables:** Resolving M:N relationships
- **Weak Entity Mapping:** Composite keys with owner's ID
- **Self-Referencing:** FK pointing to same table (hierarchies, prerequisites)

### Design Conventions
- **ER Model Conventions:**
  - Singular entity names
  - Attribute names only (no data types)
  - Relationships as lines (no FK columns shown)
  - Focus on business concepts

- **Relational Model Conventions:**
  - Plural table names (lowercase_snake_case)
  - Data types required for all columns
  - FK columns explicitly shown
  - Focus on implementation details

### Important Distinctions
- **Hybrid Notation:** Mermaid and many industry tools mix ER and Relational conventions
- **Audience-Driven Design:** Use pure ER for stakeholders, include implementation details for developers
- **Multivalued Attributes:** Become separate tables in relational model
- **Composite Attributes:** Become multiple columns in relational model
