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

### Materials

**Concept Notes:**
- [Entity-Relationship (ER) Modeling](w02_l03_concept_er_modeling.md)

**Lab Exercise:**
- [ER Diagramming](w02_l03_lab_er_diagramming.md)

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

### Materials

**Concept Notes:**
- [Logical Design: ER to Relational](w02_l04_concept_logical_design.md)

**Lab Exercise:**
- [Schema Conversion](w02_l04_lab_schema_conversion.md)

### Interactive Notebook

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/devomh/comp4098-2026/blob/main/week_02/w02_l04_lab_schema_conversion.ipynb)

Click the badge above to open the lab notebook directly in Google Colab.

---

## Key Concepts
- **ER Modeling:** Entities, Attributes, Relationships
- **Entity Types:** Strong entities vs Weak entities
- **Cardinality:** 1:1, 1:N, M:N relationships
- **Notation Styles:** Chen notation vs Crow's Foot notation
- **Logical Design:** Mapping ER diagrams to relational schemas
- **Foreign Keys:** Implementing 1:N relationships
- **Junction Tables:** Resolving M:N relationships
- **Naming Conventions:** Professional standards for tables and columns
