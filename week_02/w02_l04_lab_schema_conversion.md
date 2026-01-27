---
title: "Lab: Schema Conversion"
week: 02
type: lab
tags: [schema design, logical modeling]
difficulty: intermediate
duration: "60 mins"
---

# Lab: Schema Conversion

## 1. Prerequisites & Setup
*   **Context:** This lab builds directly on the ER Diagram from Lesson 3.
*   **Goal:** Convert the "University Course Registration" ERD into a set of Relational Schemas (Logical Table Definitions).
*   **Concept Review:** Ensure you have read `w02_l04_concept_logical_design.md`.

### Environment Setup
Run this block first to set up the visualization tools.
```python
# Setup: Run this cell first (required for Colab)
!pip install -q mermaid-py

from mermaid import Mermaid

print("Setup complete! Ready for schema conversion.")
```

---

## 2. Step 1: Converting Strong Entities
Let's turn our "Nouns" into Tables. We will follow the **Plural Table / Singular Column** convention.

**ER Entity:** `Department`
*   Attributes: Name, Building Location.

**Logical Schema:**
*   Table: `departments`
*   Columns:
    *   `dept_id` (Integer, PK) -> *Added surrogate key for best practice*
    *   `name` (Varchar)
    *   `building` (Varchar)

**ER Entity:** `Course`
*   Attributes: Course Code, Title, Credits.

**Logical Schema:**
*   Table: `courses`
*   Columns:
    *   `course_code` (Char(8), PK) -> *Natural key is okay here*
    *   `title` (Varchar)
    *   `credits` (Integer)

---

## 3. Step 2: Mapping 1:N Relationships
**Relationship:** `Department` (1) --- (N) `Professor`

**Think Before You Peek:**
Where should the link go?
1.  Should `departments` have a list of `professor_ids`?
2.  Should `professors` have a single `dept_id`?

<details>
<summary>Click to reveal the answer</summary>
**Rule:** FK goes to the "Many" side (`Professor`).
</details>

**Logical Schema:**
*   Table: `professors`
*   Columns:
    *   `emp_id` (Integer, PK)
    *   `name` (Varchar)
    *   `dept_id` (Integer, FK references `departments.dept_id`)

---

## 4. Step 3: Mapping M:N Relationships (The Junction Table)
**Relationship:** `Student` (M) --- (N) `Course`

We need a bridge table. Let's call it `enrollments`. This table also captures the `enrollment_date` attribute we discussed in the last lesson.

**Logical Schema:**
*   Table: `enrollments`
*   Columns:
    *   `student_id` (Integer, FK references `students.student_id`)
    *   `course_code` (Char(8), FK references `courses.course_code`)
    *   `enrollment_date` (Date)
    *   **Primary Key:** (`student_id`, `course_code`)

---

## 5. Your Turn! (Exercises)
Define the schemas for the remaining parts of our model. You can write them in markdown tables or simple text blocks.

### Exercise 1: The Student Table
**Task:** Define the schema for the `students` table based on the ERD (ID, Name, Email, DOB).

| Column Name | Data Type | Key Type (PK/FK) |
| :--- | :--- | :--- |
| `student_id` | Integer | PK |
| ... | ... | ... |

<details>
<summary>Expected Output</summary>

| Column Name | Data Type | Key Type (PK/FK) |
| :--- | :--- | :--- |
| `student_id` | Integer | PK |
| `name` | Varchar | |
| `email` | Varchar | |
| `dob` | Date | |

</details>

### Exercise 2: Multivalued Attributes (Phone Numbers)
**Task:** In Lesson 3, we decided `PhoneNumbers` should be a separate entity.
**Action:** Define the schema for the `student_phones` table.
*   *Hint:* This is a **Weak Entity** scenario. A phone number belongs to a student.

| Column Name | Data Type | Key Type (PK/FK) |
| :--- | :--- | :--- |
| `student_id` | Integer | FK, PK |
| `phone_number` | Varchar | PK |
| `type` | Varchar | (e.g. 'Mobile') |

<details>
<summary>Expected Output & Explanation</summary>

The schema above is correct! Key points:

| Column Name | Data Type | Key Type | Notes |
| :--- | :--- | :--- | :--- |
| `student_id` | Integer | FK, PK | References `students.student_id` |
| `phone_number` | Varchar | PK | Part of composite key |
| `type` | Varchar | | 'Mobile', 'Home', 'Emergency' |

**Why Composite PK?** A student can have multiple phone numbers. The combination of (`student_id`, `phone_number`) uniquely identifies each record. This follows the **Weak Entity** pattern: the phone number's identity depends on which student it belongs to.

</details>

### Exercise 3: Self-Referencing Relationship (Prerequisites)
**Task:** A Course can have a *Prerequisite* (which is also a Course).
*   Relationship: `Course` (1) --- (N) `Course` (Prereq).
*   *Interpretation:* A Course (e.g., "Advanced SQL") has one Prerequisite ("Intro SQL").

**Action:** How do we model this inside the `courses` table?
*   *Hint:* We need a Foreign Key that points to... the same table.

| Column Name | Data Type | Key Type (PK/FK) |
| :--- | :--- | :--- |
| ... | ... | ... |

<details>
<summary>Expected Output</summary>

| Column Name | Data Type | Key Type (PK/FK) | Notes |
| :--- | :--- | :--- | :--- |
| `course_code` | Char(8) | PK | |
| `title` | Varchar | | |
| `credits` | Integer | | |
| `prereq_code` | Char(8) | FK | References `courses.course_code`, **NULLABLE** |

**Key Insight:** The `prereq_code` column is a **self-referencing Foreign Key**. It points back to the same table's Primary Key. Courses with no prerequisites have `prereq_code = NULL`.

**Example Data:**
| course_code | title | credits | prereq_code |
| :--- | :--- | :--- | :--- |
| SQL101 | Intro to SQL | 3 | NULL |
| SQL201 | Advanced SQL | 3 | SQL101 |
| DB301 | Database Design | 4 | SQL201 |

</details>

---

## 6. Complete Schema Summary

Here is the complete logical schema for the University Course Registration System:

| Table | Columns | Primary Key | Foreign Keys |
| :--- | :--- | :--- | :--- |
| `departments` | dept_id, name, building | dept_id | - |
| `professors` | emp_id, name, dept_id | emp_id | dept_id → departments |
| `courses` | course_code, title, credits, prereq_code | course_code | prereq_code → courses |
| `students` | student_id, name, email, dob | student_id | - |
| `student_phones` | student_id, phone_number, type | (student_id, phone_number) | student_id → students |
| `enrollments` | student_id, course_code, enrollment_date | (student_id, course_code) | student_id → students, course_code → courses |

### Visual Schema (ERD with Foreign Keys)
```python
Mermaid("""
erDiagram
    departments {
        int dept_id PK
        varchar name
        varchar building
    }
    professors {
        int emp_id PK
        varchar name
        int dept_id FK
    }
    courses {
        char course_code PK
        varchar title
        int credits
        char prereq_code FK
    }
    students {
        int student_id PK
        varchar name
        varchar email
        date dob
    }
    student_phones {
        int student_id PK_FK
        varchar phone_number PK
        varchar type
    }
    enrollments {
        int student_id PK_FK
        char course_code PK_FK
        date enrollment_date
    }

    departments ||--|{ professors : employs
    professors ||--o{ courses : teaches
    courses ||--o| courses : requires
    students ||--o{ student_phones : has
    students ||--o{ enrollments : has
    courses ||--o{ enrollments : has
""")
```

---

## 7. Summary
You have now converted a visual diagram into a set of strict table definitions.
*   **Next Week:** We will write the `CREATE TABLE` SQL statements to build this schema in a database!