---
title: "Lab: Implementing Schemas in PostgreSQL"
week: 04
type: lab
tags: [postgresql, ddl, sql-magic, schema, implementation]
difficulty: intermediate
duration: "60 mins"
---

# Lab: Implementing Schemas in PostgreSQL

## Prerequisites & Setup

**Before starting this lab, you should:**
- Review [w04_l07_concept_ddl_schema.md](w04_l07_concept_ddl_schema.md) for DDL concepts
- Understand normalization principles from Week 03
- Be familiar with the ER modeling from Week 02

**What you'll build:**
In this lab, you'll implement the **University Course Registration System** that you designed conceptually in Week 02. You'll create all tables with proper constraints, test constraint enforcement, and verify the schema integrity.

**Goal:** Transform a normalized design into a production-ready PostgreSQL database.

---

## Environment Setup

Run this setup block first to install required packages and configure SQL Magic.

```python
# Install required packages
!pip install -q psycopg2-binary ipython-sql sqlalchemy pandas mermaid-py

# Import libraries
import pandas as pd
from mermaid import Mermaid
import warnings
warnings.filterwarnings('ignore')

# Load SQL magic
%load_ext sql

# Configure SQL Magic
%config SqlMagic.autocommit = False  # Require explicit COMMIT for safety
%config SqlMagic.feedback = True     # Show row counts
%config SqlMagic.displaycon = False  # Hide connection string in output
```

### Database Connection Options

You need a PostgreSQL database to complete this lab. Choose one of the following options:

**Option 1: Supabase (Recommended for Students)**
- Free tier: 500MB database, unlimited API calls
- Sign up at: https://supabase.com
- Create a new project
- Go to Settings → Database → Connection String
- Copy the URI connection string

```python
# Replace with your Supabase credentials
%sql postgresql://postgres:[YOUR-PASSWORD]@db.[YOUR-PROJECT].supabase.co:5432/postgres
```

**Option 2: ElephantSQL (Alternative)**
- Free tier: 20MB database
- Sign up at: https://www.elephantsql.com
- Create a new instance
- Copy the URL

```python
# Replace with your ElephantSQL URL
%sql postgresql://user:pass@host/database
```

**Option 3: Local PostgreSQL (Advanced)**
- If you have PostgreSQL installed locally:

```python
%sql postgresql://postgres:password@localhost:5432/comp4098
```

**Test Your Connection:**

```python
%%sql
SELECT version();
```

<details>
<summary>Expected Output</summary>

You should see the PostgreSQL version information:

~~~
PostgreSQL 15.x on x86_64-pc-linux-gnu, compiled by gcc...
~~~

</details>

---

## The Scenario: University Course Registration System

You're building a database for a university's course registration system. The system needs to track:

- **Departments:** Academic departments (Computer Science, Mathematics, etc.)
- **Professors:** Faculty members employed by departments
- **Courses:** Classes offered with credit hours and prerequisites
- **Students:** Enrolled students with contact information
- **Enrollments:** Which students are taking which courses

This schema was **normalized to 3NF in Week 03** to eliminate data anomalies. Now you'll implement it with proper constraints.

---

## Step 1: Create Parent Tables (No Dependencies)

Let's start by creating tables that **don't depend on other tables** - our "root" entities.

### Drop Existing Tables (For Reruns)

Always clean up first so you can re-run this lab multiple times.

```python
%%sql
-- Drop tables in reverse dependency order
DROP TABLE IF EXISTS enrollments CASCADE;
DROP TABLE IF EXISTS student_phones CASCADE;
DROP TABLE IF EXISTS courses CASCADE;
DROP TABLE IF EXISTS students CASCADE;
DROP TABLE IF EXISTS professors CASCADE;
DROP TABLE IF EXISTS departments CASCADE;
```

### Create Departments Table

```python
%%sql
CREATE TABLE departments (
    dept_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    building VARCHAR(100) NOT NULL
);

-- Verify the structure
SELECT column_name, data_type, character_maximum_length, is_nullable
FROM information_schema.columns
WHERE table_name = 'departments'
ORDER BY ordinal_position;
```

<details>
<summary>Expected Output</summary>

| column_name | data_type | character_maximum_length | is_nullable |
|-------------|-----------|--------------------------|-------------|
| dept_id | integer | NULL | NO |
| name | character varying | 100 | NO |
| building | character varying | 100 | NO |

</details>

**Key Points:**
- `SERIAL` creates an auto-incrementing integer (1, 2, 3, ...)
- `PRIMARY KEY` enforces uniqueness and creates an index
- `UNIQUE` on name prevents duplicate department names
- `NOT NULL` ensures required fields are always provided

### Create Students Table

```python
%%sql
CREATE TABLE students (
    student_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    dob DATE CHECK (dob < CURRENT_DATE AND dob > '1900-01-01')
);

-- Verify constraints
SELECT constraint_name, constraint_type
FROM information_schema.table_constraints
WHERE table_name = 'students';
```

<details>
<summary>Expected Output</summary>

| constraint_name | constraint_type |
|-----------------|-----------------|
| students_pkey | PRIMARY KEY |
| students_email_key | UNIQUE |
| students_dob_check | CHECK |

</details>

**Key Points:**
- `CHECK (dob < CURRENT_DATE)` prevents future birthdates
- `CHECK (dob > '1900-01-01')` prevents unrealistic old dates
- Email must be unique (no two students can share an email)

---

## Step 2: Create Tables with Foreign Keys

Now we'll create tables that **reference** the parent tables we just created.

### Create Professors Table

Professors belong to departments, so we need a foreign key.

```python
%%sql
CREATE TABLE professors (
    emp_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    dept_id INTEGER NOT NULL,
    FOREIGN KEY (dept_id) REFERENCES departments(dept_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

-- Verify the foreign key
SELECT
    tc.constraint_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_name = 'professors';
```

<details>
<summary>Expected Output</summary>

| constraint_name | column_name | foreign_table_name | foreign_column_name |
|-----------------|-------------|---------------------|---------------------|
| professors_dept_id_fkey | dept_id | departments | dept_id |

</details>

**Key Points:**
- `ON DELETE RESTRICT` prevents deleting a department that has professors
- `ON UPDATE CASCADE` automatically updates dept_id in professors if it changes in departments

---

## Step 3: Self-Referencing Foreign Keys

Some tables reference **themselves**. Courses can have prerequisites, which are also courses.

### Create Courses Table

```python
%%sql
CREATE TABLE courses (
    course_code CHAR(8) PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    credits INTEGER NOT NULL CHECK (credits > 0 AND credits <= 6),
    prereq_code CHAR(8),
    FOREIGN KEY (prereq_code) REFERENCES courses(course_code)
        ON DELETE SET NULL
);

-- Verify the structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'courses'
ORDER BY ordinal_position;
```

<details>
<summary>Expected Output</summary>

| column_name | data_type | is_nullable |
|-------------|-----------|-------------|
| course_code | character | NO |
| title | character varying | NO |
| credits | integer | NO |
| prereq_code | character | YES |

</details>

**Key Points:**
- `CHAR(8)` is fixed-length (e.g., "COMP1101" is always 8 characters)
- `prereq_code` can be NULL (not all courses have prerequisites)
- `ON DELETE SET NULL` means if a course is deleted, dependent courses just lose their prerequisite link (don't cascade delete)

**Why CHAR vs VARCHAR?**
- Course codes are **fixed format** (e.g., COMP1101, MATH2201)
- CHAR is slightly more efficient for fixed-length strings
- VARCHAR would work too, but CHAR documents the fixed-length expectation

---

## Step 4: Composite Primary Keys and Junction Tables

### Multi-valued Attributes: Student Phones

Students can have multiple phone numbers (mobile, home, emergency). This is a **multi-valued attribute** from ER modeling, implemented as a separate table.

```python
%%sql
CREATE TABLE student_phones (
    student_id INTEGER NOT NULL,
    phone_number VARCHAR(20) NOT NULL,
    phone_type VARCHAR(20) DEFAULT 'mobile',
    PRIMARY KEY (student_id, phone_number),
    FOREIGN KEY (student_id) REFERENCES students(student_id)
        ON DELETE CASCADE
);

-- Verify the composite primary key
SELECT constraint_name, constraint_type
FROM information_schema.table_constraints
WHERE table_name = 'student_phones' AND constraint_type = 'PRIMARY KEY';
```

<details>
<summary>Expected Output</summary>

| constraint_name | constraint_type |
|-----------------|-----------------|
| student_phones_pkey | PRIMARY KEY |

</details>

**Key Points:**
- **Composite Primary Key:** `(student_id, phone_number)` together must be unique
- A student can have multiple phone numbers
- A phone number can't be duplicated for the same student
- `ON DELETE CASCADE` means deleting a student deletes all their phone numbers

### Many-to-Many Relationship: Enrollments

Students and courses have a **many-to-many** relationship (one student takes many courses, one course has many students). We need a **junction table**.

```python
%%sql
CREATE TABLE enrollments (
    student_id INTEGER NOT NULL,
    course_code CHAR(8) NOT NULL,
    enrollment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    grade CHAR(2) CHECK (grade IN ('A', 'B', 'C', 'D', 'F') OR grade IS NULL),
    PRIMARY KEY (student_id, course_code),
    FOREIGN KEY (student_id) REFERENCES students(student_id)
        ON DELETE CASCADE,
    FOREIGN KEY (course_code) REFERENCES courses(course_code)
        ON DELETE RESTRICT
);

-- Verify both foreign keys
SELECT
    tc.constraint_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_name = 'enrollments';
```

<details>
<summary>Expected Output</summary>

| constraint_name | column_name | foreign_table_name |
|-----------------|-------------|---------------------|
| enrollments_student_id_fkey | student_id | students |
| enrollments_course_code_fkey | course_code | courses |

</details>

**Key Points:**
- **Composite PK:** A student can only enroll in a course once
- `DEFAULT CURRENT_DATE` automatically timestamps enrollment
- `CHECK (grade IN ...)` only allows valid letter grades
- `ON DELETE CASCADE` for student: If student is deleted, remove their enrollments
- `ON DELETE RESTRICT` for course: Can't delete a course if students are enrolled

---

## Step 5: Test Constraint Enforcement

Now let's **test** that our constraints actually work by trying to insert invalid data.

### Test 1: NOT NULL Violation

```python
%%sql
-- This should fail because email is NOT NULL
INSERT INTO students (name, email, dob)
VALUES ('John Doe', NULL, '2000-01-01');
```

You should see an error like:
```
null value in column "email" violates not-null constraint
```

### Test 2: UNIQUE Violation

```python
%%sql
-- Insert a valid student first
INSERT INTO students (name, email, dob)
VALUES ('Alice Smith', 'alice@university.edu', '2000-05-15');

-- This should fail because email must be unique
INSERT INTO students (name, email, dob)
VALUES ('Bob Jones', 'alice@university.edu', '1999-08-22');
```

You should see an error like:
```
duplicate key value violates unique constraint "students_email_key"
```

**Fix it:** Roll back and insert with a unique email

```python
%%sql
ROLLBACK;  -- Undo the failed transaction

-- Now insert both students correctly
INSERT INTO students (name, email, dob) VALUES
    ('Alice Smith', 'alice@university.edu', '2000-05-15'),
    ('Bob Jones', 'bob@university.edu', '1999-08-22');
```

### Test 3: CHECK Constraint Violation

```python
%%sql
-- This should fail: credits must be between 1 and 6
INSERT INTO courses (course_code, title, credits, prereq_code)
VALUES ('COMP9999', 'Invalid Course', 10, NULL);
```

You should see an error like:
```
new row violates check constraint "courses_credits_check"
```

### Test 4: Foreign Key Violation

```python
%%sql
-- This should fail: dept_id 999 doesn't exist
INSERT INTO professors (name, dept_id)
VALUES ('Dr. Smith', 999);
```

You should see an error like:
```
insert or update on table "professors" violates foreign key constraint
```

**Fix it:** Insert department first, then professor

```python
%%sql
-- Insert department first
INSERT INTO departments (name, building)
VALUES ('Computer Science', 'Tech Building');

-- Now insert professor
INSERT INTO professors (name, dept_id)
VALUES ('Dr. Alice Cooper', 1);  -- dept_id 1 was auto-generated

SELECT * FROM professors;
```

<details>
<summary>Expected Output</summary>

| emp_id | name | dept_id |
|--------|------|---------|
| 1 | Dr. Alice Cooper | 1 |

</details>

---

## Your Turn! (Exercises)

### Exercise 1: Add a New Table

**Task:** Create a `textbooks` table with the following requirements:
- ISBN (13 characters, PRIMARY KEY)
- Title (up to 200 characters, required)
- Author (up to 150 characters, required)
- Course code (foreign key to courses, allow multiple textbooks per course)
- ON DELETE CASCADE (if course is deleted, remove its textbooks)

```python
%%sql
-- TODO: Write your CREATE TABLE statement here
```

<details>
<summary>Hint</summary>

Structure:
- `isbn CHAR(13) PRIMARY KEY`
- `title VARCHAR(200) NOT NULL`
- `author VARCHAR(150) NOT NULL`
- `course_code CHAR(8) NOT NULL`
- `FOREIGN KEY (course_code) REFERENCES courses(course_code) ON DELETE CASCADE`

</details>

<details>
<summary>Solution</summary>

~~~python
%%sql
CREATE TABLE textbooks (
    isbn CHAR(13) PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    author VARCHAR(150) NOT NULL,
    course_code CHAR(8) NOT NULL,
    FOREIGN KEY (course_code) REFERENCES courses(course_code)
        ON DELETE CASCADE
);
~~~

</details>

### Exercise 2: Modify Existing Schema with ALTER

**Task:** Add a `salary` column to the `professors` table with the following constraints:
- Data type: NUMERIC(10, 2)
- NOT NULL
- CHECK: salary must be greater than 30000

```python
%%sql
-- TODO: Write your ALTER TABLE statement here
```

<details>
<summary>Hint</summary>

Use `ALTER TABLE professors ADD COLUMN ...` with constraints.
Since the column is NOT NULL and the table might have existing rows, you may need to provide a DEFAULT value or ensure the table is empty.

</details>

<details>
<summary>Solution</summary>

~~~python
%%sql
-- Option 1: Add with default value (if professors table has data)
ALTER TABLE professors
ADD COLUMN salary NUMERIC(10, 2) NOT NULL DEFAULT 50000
CHECK (salary > 30000);

-- Option 2: Add without default (only if table is empty)
ALTER TABLE professors
ADD COLUMN salary NUMERIC(10, 2) NOT NULL CHECK (salary > 30000);
~~~

</details>

### Exercise 3: Document the Schema

**Task:** Write a query to list all tables, their columns, data types, and constraints in your database.

```python
%%sql
-- TODO: Query information_schema to document your schema
-- Hint: Use information_schema.columns and information_schema.table_constraints
```

<details>
<summary>Solution</summary>

~~~python
%%sql
-- List all tables and columns
SELECT
    table_name,
    column_name,
    data_type,
    character_maximum_length,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
ORDER BY table_name, ordinal_position;
~~~

~~~python
%%sql
-- List all constraints
SELECT
    tc.table_name,
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name
FROM information_schema.table_constraints AS tc
LEFT JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_schema = 'public'
ORDER BY tc.table_name, tc.constraint_type;
~~~

</details>

### Exercise 4: Practice ALTER Statements

**Task:** Perform the following schema modifications:
1. Add a `section` column to enrollments (VARCHAR(10))
2. Add a UNIQUE constraint on (course_code, section) to ensure no duplicate sections per course
3. Drop the section column

```python
%%sql
-- TODO: Step 1 - Add section column
```

```python
%%sql
-- TODO: Step 2 - Add unique constraint
```

```python
%%sql
-- TODO: Step 3 - Drop section column
```

<details>
<summary>Solution</summary>

~~~python
%%sql
-- Step 1: Add section column
ALTER TABLE enrollments ADD COLUMN section VARCHAR(10);

-- Step 2: Add unique constraint
-- Note: This creates a composite UNIQUE constraint
ALTER TABLE enrollments
ADD CONSTRAINT unique_course_section UNIQUE (course_code, section);

-- Step 3: Drop section column
ALTER TABLE enrollments DROP COLUMN section;
~~~

</details>

---

## Final Schema Visualization

Here's the complete schema you've implemented:

```python
Mermaid("""
erDiagram
    departments {
        serial dept_id PK
        varchar name UK
        varchar building
    }
    professors {
        serial emp_id PK
        varchar name
        integer dept_id FK
    }
    courses {
        char course_code PK
        varchar title
        integer credits
        char prereq_code FK
    }
    students {
        serial student_id PK
        varchar name
        varchar email UK
        date dob
    }
    student_phones {
        integer student_id PK_FK
        varchar phone_number PK
        varchar phone_type
    }
    enrollments {
        integer student_id PK_FK
        char course_code PK_FK
        date enrollment_date
        char grade
    }

    departments ||--|{ professors : employs
    courses ||--o| courses : requires
    students ||--o{ student_phones : has
    students ||--o{ enrollments : enrolls
    courses ||--o{ enrollments : offered_in
""")
```

**Legend:**
- **PK:** Primary Key
- **FK:** Foreign Key
- **UK:** Unique Key
- **||--|{:** One-to-many relationship
- **||--o{:** One-to-zero-or-many relationship
- **||--o|:** One-to-zero-or-one relationship (self-referencing)

---

## Summary

Congratulations! In this lab, you have successfully:

1. ✅ Connected to a PostgreSQL database from Google Colab
2. ✅ Implemented a complete normalized schema with DDL statements
3. ✅ Created tables in the correct dependency order (parents before children)
4. ✅ Applied all constraint types:
   - NOT NULL (required fields)
   - UNIQUE (candidate keys)
   - CHECK (domain constraints)
   - PRIMARY KEY (unique identifiers)
   - FOREIGN KEY (referential integrity)
5. ✅ Tested constraint enforcement by attempting invalid insertions
6. ✅ Used ALTER statements to modify schemas
7. ✅ Queried information_schema to document your database

**Key Takeaways:**

- **Constraints enforce business rules** - The database prevents bad data automatically
- **Foreign keys enforce referential integrity** - You can't orphan records
- **Schema design requires planning** - Create parent tables before child tables
- **ALTER TABLE is powerful but dangerous** - Always back up before schema changes
- **Documentation is critical** - Use information_schema to understand existing databases

**Next Steps:**

In [Lesson 8: DML & Basic Querying](w04_l08_concept_dml_querying.md), you'll learn how to populate this schema with data using INSERT, UPDATE, DELETE, and SELECT statements.

---

## Troubleshooting

### Connection Issues

**Problem:** Can't connect to PostgreSQL
- **Solution:** Double-check your connection string format
- **Solution:** Verify your password doesn't contain special characters (or URL-encode them)
- **Solution:** Check if your IP is whitelisted (Supabase requires this in free tier)

### Constraint Violations

**Problem:** "violates foreign key constraint"
- **Solution:** Insert parent records before child records
- **Solution:** Verify the referenced value actually exists

**Problem:** "violates check constraint"
- **Solution:** Check your values match the constraint logic
- **Solution:** Query information_schema to see exact constraint definition

### ALTER TABLE Failures

**Problem:** Can't add NOT NULL column to existing table
- **Solution:** Add with DEFAULT value, or update existing NULLs first

**Problem:** Can't drop column that's referenced by foreign key
- **Solution:** Use `DROP COLUMN ... CASCADE` (but be careful!)
