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
```

```python
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

## 7. Challenge: Library Management System (End-to-End)

**This challenge tests your understanding of the distinction between ER and Relational models.** You will create TWO diagrams following strict conventions.

### The Scenario

You are designing a database for a **City Library System**. Here are the complete requirements:

**Entities & Attributes:**
1. **Members** can borrow books. Track their: membership number, full name, email, and phone number (members can have multiple phone numbers).
2. **Books** in the library catalog. Track: ISBN, title, author name, publication year, and genre.
3. **Physical Copies** of books exist (multiple copies of the same book). Each copy has: a unique barcode, condition (New/Good/Fair/Poor), and shelf location.
4. **Authors** write books. Track: author ID, full name, country of origin, and birth year.
5. **Borrowing Records** track when a member borrows a physical copy. Record: borrow date, due date, and return date (NULL if not yet returned).

**Relationships:**
1. A **Member** can borrow many **Physical Copies** over time, and a **Physical Copy** can be borrowed by many **Members** over time. (M:N - through Borrowing Records)
2. A **Book** can have many **Physical Copies**, but each **Physical Copy** belongs to exactly one **Book**. (1:N)
3. An **Author** can write many **Books**, and a **Book** can have many **Authors** (co-authorship is common). (M:N)
4. A **Book** can have a **Sequel** (which is also a Book). Track this relationship.

**Business Rules:**
- A member cannot borrow the same physical copy twice simultaneously.
- Phone numbers are multivalued (some members have multiple contacts).
- Physical copies are weak entities (they don't exist without a book).
- Books can exist in the catalog even if there are no physical copies yet.

---

### Part A: Create a Pure ER Diagram

**Requirements:**
- Use Mermaid `erDiagram` syntax
- **Entity names**: Singular (e.g., `MEMBER`, `BOOK`)
- **Attributes**: List attribute names only - **NO data types**
- **Primary Keys**: Mark with `PK` annotation
- **Foreign Keys**: **DO NOT include FK columns** in entities
- **Relationships**: Show using relationship lines with proper cardinality
- Focus on **what** data exists, not **how** it's stored

```python
# TODO: Create your pure ER diagram here
Mermaid("""
erDiagram
    MEMBER {
        membership_number PK
        full_name
        email
    }
    %% Add remaining entities and relationships
""")
```

<details>
<summary>Hints for Part A</summary>

**Entity Count:** You should have at least 6-7 entities:
- MEMBER
- BOOK
- PHYSICAL_COPY (weak entity)
- AUTHOR
- BORROWING_RECORD (junction table for Member-Copy M:N)
- BOOK_AUTHORSHIP (junction table for Book-Author M:N)
- MEMBER_PHONE (for multivalued phone numbers)

**Key Relationships:**
- Don't show `book_id` inside `PHYSICAL_COPY` - just show the relationship line
- Don't show FKs in junction tables - just show the relationship lines
- Self-referencing: `BOOK ||--o| BOOK : sequel_of`

</details>

<details>
<summary>Solution for Part A</summary>

~~~python
Mermaid("""
erDiagram
    MEMBER {
        membership_number PK
        full_name
        email
    }
    MEMBER_PHONE {
        membership_number PK
        phone_number PK
        phone_type
    }
    BOOK {
        isbn PK
        title
        publication_year
        genre
    }
    AUTHOR {
        author_id PK
        full_name
        country
        birth_year
    }
    PHYSICAL_COPY {
        book_isbn PK
        barcode PK
        condition
        shelf_location
    }
    BORROWING_RECORD {
        membership_number PK
        barcode PK
        borrow_date PK
        due_date
        return_date
    }
    BOOK_AUTHORSHIP {
        isbn PK
        author_id PK
    }

    MEMBER ||--o{ MEMBER_PHONE : has
    BOOK ||--o{ PHYSICAL_COPY : has_copies
    BOOK ||--o| BOOK : sequel_of
    MEMBER ||--o{ BORROWING_RECORD : borrows
    PHYSICAL_COPY ||--o{ BORROWING_RECORD : borrowed_in
    BOOK ||--o{ BOOK_AUTHORSHIP : written_in
    AUTHOR ||--o{ BOOK_AUTHORSHIP : writes_in
""")
~~~

**Note:** This is a **pure conceptual ER diagram**:
- No data types (just attribute names)
- FKs are implied by relationship lines, not shown as attributes
- Focus is on business concepts and relationships

</details>

---

### Part B: Create a Relational Schema

**Requirements:**
- Use Mermaid `erDiagram` syntax (or a table format)
- **Table names**: Plural, lowercase with underscores (e.g., `members`, `physical_copies`)
- **Columns**: Include **data types** (VARCHAR, INTEGER, DATE, etc.)
- **Primary Keys**: Mark with `PK`
- **Foreign Keys**: **Explicitly include FK columns** with `FK` annotation
- **Relationships**: Show relationship lines AND the FK columns
- Focus on **implementation** details

```python
# TODO: Create your relational schema here
Mermaid("""
erDiagram
    members {
        INTEGER membership_number PK
        VARCHAR full_name
        VARCHAR email
    }
    %% Add remaining tables with data types and FK columns
""")
```

<details>
<summary>Hints for Part B</summary>

**Data Type Suggestions:**
- IDs/Numbers: `INTEGER` or `SERIAL`
- ISBN: `VARCHAR(13)` or `CHAR(13)`
- Barcode: `VARCHAR(20)`
- Names/Text: `VARCHAR(100)` or `VARCHAR(255)`
- Dates: `DATE`
- Enums: `VARCHAR(20)` (for condition, phone_type, genre)

**Foreign Key Placement:**
- `physical_copies` should have `book_isbn FK`
- `borrowing_records` should have `membership_number FK` and `barcode FK`
- `book_authorship` should have `isbn FK` and `author_id FK`
- `member_phones` should have `membership_number FK`
- `books` should have `sequel_isbn FK` (nullable, self-referencing)

</details>

<details>
<summary>Solution for Part B</summary>

~~~python
Mermaid("""
erDiagram
    members {
        INTEGER membership_number PK
        VARCHAR full_name
        VARCHAR email
    }
    member_phones {
        INTEGER membership_number PK_FK
        VARCHAR phone_number PK
        VARCHAR phone_type
    }
    books {
        VARCHAR isbn PK
        VARCHAR title
        INTEGER publication_year
        VARCHAR genre
        VARCHAR sequel_isbn FK
    }
    authors {
        INTEGER author_id PK
        VARCHAR full_name
        VARCHAR country
        INTEGER birth_year
    }
    physical_copies {
        VARCHAR book_isbn PK_FK
        VARCHAR barcode PK
        VARCHAR condition
        VARCHAR shelf_location
    }
    borrowing_records {
        INTEGER membership_number PK_FK
        VARCHAR barcode PK_FK
        DATE borrow_date PK
        DATE due_date
        DATE return_date
    }
    book_authorship {
        VARCHAR isbn PK_FK
        INTEGER author_id PK_FK
    }

    members ||--o{ member_phones : has
    books ||--o{ physical_copies : has_copies
    books ||--o| books : sequel_of
    members ||--o{ borrowing_records : borrows
    physical_copies ||--o{ borrowing_records : borrowed_in
    books ||--o{ book_authorship : written_in
    authors ||--o{ book_authorship : writes_in
""")
~~~

**Key Differences from Part A:**
- Table names are **plural** and **lowercase_with_underscores**
- **Data types** are specified for every column
- **FK columns** are explicitly shown in tables
- Same relationships, but now with implementation details

</details>

---

### Part C: Reflection Questions

Answer these questions to solidify your understanding:

1. **Why don't we show `book_isbn` as an FK column in `PHYSICAL_COPY` in the pure ER diagram (Part A), but we do show it in the relational schema (Part B)?**

<details>
<summary>Answer</summary>

In a **pure ER diagram**, the relationship line (`BOOK ||--o{ PHYSICAL_COPY`) already represents the connection - the FK is *implied* by the 1:N relationship. The ER model is conceptual and focuses on "what is related to what."

In the **relational schema**, we need to specify *how* that relationship is implemented in the database - through an explicit FK column. This is an implementation detail that belongs to the logical/physical layer.

</details>

2. **What is the composite primary key of the `borrowing_records` table, and why does it need three columns?**

<details>
<summary>Answer</summary>

The composite PK is: `(membership_number, barcode, borrow_date)`.

- We need `membership_number` + `barcode` because this junction table links members and copies
- We also need `borrow_date` because the **same member can borrow the same copy multiple times** (at different points in time - after returning it the first time)
- Without `borrow_date`, we couldn't distinguish between the first borrowing and subsequent borrowings of the same copy by the same member

This is a special case where a junction table needs more than just the two FKs as its PK.

</details>

3. **How does the relational model handle the multivalued `phone_numbers` attribute from the ER model?**

<details>
<summary>Answer</summary>

A **multivalued attribute** in the ER model (shown with special notation in Chen diagrams) becomes a **separate table** in the relational model.

The `MEMBER_PHONE` entity/table follows the 1:N pattern:
- One member can have many phone numbers
- The `membership_number` FK links back to the member
- The composite PK `(membership_number, phone_number)` ensures we can't accidentally enter the same phone number twice for the same member

This transformation maintains **First Normal Form (1NF)** - no multi-valued cells.

</details>

---

## 8. Summary
You have now converted a visual diagram into a set of strict table definitions, and practiced the critical distinction between **ER diagrams** (conceptual) and **Relational schemas** (implementation).

**Key Takeaways:**
- ER diagrams focus on **what** data exists (business concepts)
- Relational schemas focus on **how** data is stored (implementation)
- The comparison table in `w02_l03_concept_er_modeling.md` is your reference guide

**Next Week:** We will write the `CREATE TABLE` SQL statements to build this schema in a database!