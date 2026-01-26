---
title: "Logical Design: ER to Relational"
week: 02
type: concept
tags: [schema design, normalization, sql prep]
difficulty: intermediate
duration: "45 mins"
---

# Module 1: Logical Design (ER to Relational)

## 1. Learning Objectives
By the end of this lesson, you will be able to:
*   Apply the "mapping algorithm" to convert ER Diagrams into Relational Schemas (Tables).
*   Map **1:N Relationships** using **Foreign Keys**.
*   Map **M:N Relationships** using **Junction (Associative) Tables**.
*   Map **Weak Entities** effectively.
*   Adopt professional **Naming Conventions** for database objects.

---

## 2. The "Why": Industry Context
*How do we turn the drawing into a database?*

An ER Diagram is conceptual. PostgreSQL (or any relational DB) doesn't know what a "relationship line" is. It only knows **Tables**, **Columns**, and **Keys**. Logical Design is the translation layer. If this step is done poorly, you end up with circular dependencies, slow joins, or data anomalies.

> **Analogy:** ER Diagram = **Blueprint**. Logical Schema = **Assembly Instructions** (List of parts and how they bolt together).

---

## 3. Best Practice: Naming Conventions
Before we map, let's agree on how to name things.

| Concept | Convention | Example |
| :--- | :--- | :--- |
| **Table** | **Plural**, lowercase, snake_case | `students`, `order_items` |
| **Column** | Singular, lowercase, snake_case | `first_name`, `created_at` |
| **Primary Key** | `table_singular` + `_id` | `student_id` |
| **Foreign Key** | `target_table_singular` + `_id` | `dept_id` |

*Why?* Consistency makes writing SQL queries much easier later.

---

## 4. Core Concept A: Mapping Entities & 1:N Relationships
### The Rule
1.  **Strong Entity** -> Becomes a **Table**. Attributes become Columns.
2.  **1:N Relationship** -> The Primary Key (PK) of the "One" side becomes a **Foreign Key (FK)** in the "Many" side table.

### Visual Example
**ER Model:** `Department (1) ---- (N) Professor`

**Relational Schema:**

| Table | Columns |
| :--- | :--- |
| **Department** | `dept_id` (PK), `name`, `building` |
| **Professor** | `emp_id` (PK), `name`, `dept_id` (FK) |

*Note:* The `dept_id` moved into the `Professor` table because a Professor "belongs to" a Department. If we put `emp_id` in Department, a Department could only have one Professor!

### Key Takeaway
*   **"Foreign Keys go to the Many side."** Memorize this.

---

## 5. Core Concept B: Mapping M:N Relationships
### The Problem
Relational databases **cannot** store a list of IDs in a single cell (violates 1NF - Atomicity). You cannot have a column `course_ids` in the `Student` table containing `[101, 102, 103]`.

### The Solution: The Junction Table
We create a **new table** to represent the relationship. This table contains the PKs from *both* original entities.

**ER Model:** `Student (M) ---- (N) Course`

**Relational Schema:**

| Table | Columns |
| :--- | :--- |
| **Student** | `student_id` (PK), `name` |
| **Course** | `course_code` (PK), `title` |
| **Enrollment** | `student_id` (FK, PK), `course_code` (FK, PK), `enrollment_date` |

*   The `Enrollment` table is the bridge.
*   The Primary Key of `Enrollment` is usually a **Composite Key** (`student_id` + `course_code`).

---

## 6. Core Concept C: Mapping Weak Entities
A **Weak Entity** (like `Room` inside `Hotel`) cannot exist without its owner.

### The Rule
1.  Create a table for the Weak Entity.
2.  Include the Owner's Primary Key as a Foreign Key.
3.  The Weak Entity's Primary Key is often a **Composite Key**: `(owner_id, weak_entity_id)`.

**Example:**
*   Table `rooms`: `hotel_id` (FK, PK), `room_number` (PK), `type`.
*   Note: You need *both* `hotel_id` and `room_number` to uniquely identify a specific room in the database.

---

## 7. FAQ / Industry Reality

### "Can't I just use an Array column in Postgres?"
**Answer:** Postgres *does* support Array types. For simple lists (like tags), this is fine. But for relationships where you need to *join* or *query* the related data efficiently (e.g., "Find all students in Math 101"), standard Junction Tables are significantly faster and enforce integrity constraints that arrays cannot easily do.

---

## 8. Summary & Next Steps
*   **Strong Entity** = New Table.
*   **1:N** = FK in the Child ("Many") table.
*   **M:N** = New "Junction" Table with two FKs.
*   **Weak Entity** = Composite PK including the Owner's ID.
*   **Next:** Go to the Practical Lab `w02_l04_lab_schema_conversion.md` to write these schemas out.