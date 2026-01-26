---
title: "Lab: Schema Conversion"
week: 02
type: lab
tags: [schema design, logical modeling]
difficulty: intermediate
duration: "60 mins"
---

# Lab: Schema Conversion

## 1. Prerequisites
*   **Context:** This lab builds directly on the ER Diagram from Lesson 3.
*   **Goal:** Convert the "University Course Registration" ERD into a set of Relational Schemas (Logical Table Definitions).

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

### Exercise 2: Multivalued Attributes (Phone Numbers)
**Task:** In Lesson 3, we decided `PhoneNumbers` should be a separate entity.
**Action:** Define the schema for the `student_phones` table.
*   *Hint:* This is a **Weak Entity** scenario. A phone number belongs to a student.

| Column Name | Data Type | Key Type (PK/FK) |
| :--- | :--- | :--- |
| `student_id` | Integer | FK, PK |
| `phone_number` | Varchar | PK |
| `type` | Varchar | (e.g. 'Mobile') |

### Exercise 3: Self-Referencing Relationship (Prerequisites)
**Task:** A Course can have a *Prerequisite* (which is also a Course).
*   Relationship: `Course` (1) --- (N) `Course` (Prereq).
*   *Interpretation:* A Course (e.g., "Advanced SQL") has one Prerequisite ("Intro SQL").

**Action:** How do we model this inside the `courses` table?
*   *Hint:* We need a Foreign Key that points to... the same table.

| Column Name | Data Type | Key Type (PK/FK) |
| :--- | :--- | :--- |
| ... | ... | ... |

---

## 6. Summary
You have now converted a visual diagram into a set of strict table definitions.
*   **Next Week:** We will write the `CREATE TABLE` SQL statements to actually build this in PostgreSQL!