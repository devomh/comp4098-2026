# Week 01: Foundations of Data Management

## Overview
This week introduces the fundamentals of data management, focusing on the data lifecycle and the shift from database administration to data architecture. You'll learn why modern Data Scientists need to understand not just how to query data, but how to architect entire data systems.

---

## Lesson 01: Introduction & The Data Lifecycle

### Learning Objectives
By the end of this lesson, you will be able to:
- Map the 5 stages of the **Data Lifecycle** to specific tools in the Data Science stack
- Explain the shift from Database Administration to Data Architecture
- Define **ACID** properties and explain why they matter for data integrity
- Visualize where OLTP (Transactional) and OLAP (Analytical) systems fit in the pipeline

### Materials

**Concept Notes:**
- [Introduction & The Data Lifecycle](w01_l01_concept_intro_lifecycle.md)

**Lab Exercise:**
- [Colab Setup & First Database Connection](w01_l01_lab_colab_setup.md)

### Interactive Notebook

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/devomh/comp4098-2026/blob/main/week_01/w01_l01_lab_colab_setup.ipynb)

Click the badge above to open the lab notebook directly in Google Colab.

---

## Lesson 02: The Relational Model & Keys

### Learning Objectives
By the end of this lesson, you will be able to:
- Define the core components of the Relational Model: Relations, Tuples, and Attributes
- Distinguish between **Superkeys**, **Candidate Keys**, and **Primary Keys**
- Explain **Referential Integrity** and why "Cascading Deletes" can be dangerous
- Identify valid vs. invalid relationships between tables

### Materials

**Concept Notes:**
- [The Relational Model & Keys](w01_l02_concept_relational_model.md)

**Lab Exercise:**
- [Implementing Keys & Integrity Constraints](w01_l02_lab_keys_integrity.md)

### Interactive Notebook

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/devomh/comp4098-2026/blob/main/week_01/w01_l02_lab_keys_integrity.ipynb)

Click the badge above to open the lab notebook directly in Google Colab.

---

## Key Concepts
- **The Data Lifecycle:** Capture → Store → Process → Analyze → Archive
- **ACID Properties:** Atomicity, Consistency, Isolation, Durability
- **OLTP vs OLAP:** Transactional systems vs Analytical systems
- **Data Architecture:** Moving from data consumer to data architect
- **Relational Model:** Relations, Tuples, Attributes, and Domains
- **Keys:** Superkeys, Candidate Keys, Primary Keys, and Foreign Keys
- **Integrity Constraints:** Entity Integrity and Referential Integrity