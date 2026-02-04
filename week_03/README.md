# Week 03: Normalization & Data Quality

## Overview
This week formalizes the intuitions from ER modeling with **Normalization Theory**. You'll learn to identify design flaws (anomalies) in existing tables and systematically fix them using the 1NF → 2NF → 3NF progression. Then, you'll explore when it makes sense to intentionally **denormalize** for analytical workloads, bridging the gap between transactional (OLTP) and analytical (OLAP) database design.

---

## Lesson 05: Normalization Theory (1NF - 3NF)

### Learning Objectives
By the end of this lesson, you will be able to:
- Identify **Update**, **Delete**, and **Insert Anomalies** in poorly designed tables
- Define **Functional Dependencies** and use them to analyze table structure
- Apply the rules for **1NF**, **2NF**, and **3NF** to decompose tables
- Explain *why* normalization matters for data integrity and maintenance

### Materials

**Concept Notes:**
- [Normalization Theory (1NF - 3NF)](w03_l05_concept_normalization.md)

**Lab Exercise:**
- [Normalizing a Messy Dataset](w03_l05_lab_normalization.md)

### Interactive Notebook

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/devomh/comp4098-2026/blob/main/week_03/w03_l05_lab_normalization.ipynb)

Click the badge above to open the lab notebook directly in Google Colab.

### Challenge Exercise

**Ready for a bigger challenge?** Apply your normalization skills to a realistic retail dataset that mimics real-world CSV exports from legacy ERP systems.

**Materials:**
- [Retail Normalization Challenge](w03_l05_challenge_retail_normalization.md)

### Challenge Notebook

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/devomh/comp4098-2026/blob/main/week_03/w03_l05_challenge_retail_normalization.ipynb)

**What's included in the challenge:**
- 🏪 **15-row retail dataset** with order, customer, product, and shipping data (15 columns)
- 📊 **Part A:** Identify and demonstrate all three types of anomalies with code
- 🔍 **Part B:** Complete functional dependency analysis with classification
- 🛠️ **Part C:** Normalize to 3NF (decompose into 4-5 tables) and verify lossless reconstruction
- 💭 **Part D:** Reflection questions on trade-offs, query complexity, and real-world application
- ✅ **Full solutions** with explanations and schema diagrams

**Why take this challenge?**
- Apply normalization to a dataset that looks like real business data exports
- Practice the complete workflow: analyze → normalize → verify → reflect
- Build a portfolio piece demonstrating your database design skills
- Bridge the gap between theory and data science practice

**Estimated time:** 90 minutes

This challenge is an excellent way to solidify your normalization skills before moving to Week 4's SQL implementation!

---

## Lesson 06: Practical Design & Denormalization

### Learning Objectives
By the end of this lesson, you will be able to:
- Explain when to **stop normalizing** and why
- Contrast **Write Performance** (favors normalization) vs. **Read Performance** (may favor denormalization)
- Identify scenarios where **controlled denormalization** is the correct choice
- Apply trade-off analysis to Data Science workflow decisions

### Materials

**Concept Notes:**
- [Practical Design & Denormalization](w03_l06_concept_denormalization.md)

**Lab Exercise:**
- [Trade-offs and Star Schema Design](w03_l06_lab_denormalization.md)

### Interactive Notebook

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/devomh/comp4098-2026/blob/main/week_03/w03_l06_lab_denormalization.ipynb)

Click the badge above to open the lab notebook directly in Google Colab.

---

## Key Concepts
- **Data Anomalies:** Update, Delete, and Insert anomalies
- **Functional Dependencies:** Determinants and dependent attributes
- **Normal Forms:** 1NF (Atomicity), 2NF (No Partial Dependencies), 3NF (No Transitive Dependencies)
- **Denormalization:** Controlled redundancy for read performance
- **OLTP vs. OLAP:** Workload-driven design decisions
- **Star Schema:** Fact tables and dimension tables for analytics
- **Materialized Views:** Database-managed denormalized tables
