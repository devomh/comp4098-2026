---
title: "Lab: Implementing Keys & Integrity"
week: 01
type: lab
tags: [sql, constraints, integrity]
difficulty: introductory
duration: "60 mins"
---

# Lab: Keys & Integrity Constraints

## 1. Prerequisites & Setup
*   **Goal:** Create tables with strict constraints (PK, FK, UNIQUE, CHECK) and test them by trying to insert invalid data.
*   **Tools:** DuckDB (In-memory).

### Environment Setup
```python
# Install DuckDB and JupySQL for SQL magic in Notebooks
!pip install -q duckdb duckdb-engine jupysql pandas mermaid-py
```

```python
import duckdb
%load_ext sql
%config SqlMagic.autopandas = True
%config SqlMagic.autocommit = True
%config SqlMagic.feedback = False
%config SqlMagic.displaycon = False

%sql duckdb:///:memory:
# %sql duckdb:///relational.db
```

---

## 2. Step 1: Defining Primary & Candidate Keys
We will create a `users` table.
*   `user_id`: Primary Key (Surrogate Key)
*   `email`: Candidate Key (Natural Key, must be Unique)
*   `age`: Domain Constraint (Must be positive)

```sql
%%sql
CREATE TABLE users (
    user_id INTEGER PRIMARY KEY,
    username VARCHAR NOT NULL,
    email VARCHAR UNIQUE,
    age INTEGER CHECK (age > 0)
);
```

### Testing Constraints
Now, let's try to break the rules.

**Test 1: Duplicate Primary Key**
```python
try:
    %sql INSERT INTO users VALUES (1, 'Alice', 'alice@test.com', 25);
    %sql INSERT INTO users VALUES (1, 'Bob', 'bob@test.com', 30); # Duplicate ID
except Exception as e:
    %sql ROLLBACK
    print(f"Caught expected error: {e}")
```

**Test 2: Duplicate Candidate Key (Email)**
```python
try:
    %sql INSERT INTO users VALUES (2, 'Bob', 'alice@test.com', 30); # Duplicate Email
except Exception as e:
    %sql ROLLBACK
    print(f"Caught expected error: {e}")
```

**Test 3: Domain Violation (Age)**
```python
try:
    %sql INSERT INTO users VALUES (3, 'Charlie', 'charlie@test.com', -5); # Invalid Age
except Exception as e:
    %sql ROLLBACK
    print(f"Caught expected error: {e}")
```

---

## 3. Step 2: Referential Integrity (Foreign Keys)
Now we create an `orders` table that links to `users`.

```sql
%%sql
CREATE TABLE orders (
    order_id INTEGER PRIMARY KEY,
    user_id INTEGER,
    amount DECIMAL(10, 2),
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);
```

### The "Orphan" Test
Try to create an order for a user that does not exist.

```python
try:
    # User 999 does not exist
    %sql INSERT INTO orders VALUES (101, 999, 50.00);
except Exception as e:
    %sql ROLLBACK
    print(f"Caught expected error: {e}")
```

### The "Valid" Insert
Insert a valid user first, then the order.
```sql
%%sql
INSERT INTO users VALUES (1, 'Alice', 'alice@test.com', 25);
INSERT INTO orders VALUES (101, 1, 50.00); -- Valid, User 1 exists
SELECT * FROM orders;
```

---

## 4. Step 3: Deletion Anomalies
What happens if we delete 'Alice' from the `users` table while she still has orders?

```python
try:
    %sql DELETE FROM users WHERE user_id = 1;
except Exception as e:
    %sql ROLLBACK
    print(f"Caught expected error: {e}")
```
**Observation:** The database **blocks** the deletion to protect the integrity of the `orders` table. You cannot delete a parent that has children (unless you configure `ON DELETE CASCADE`).

---

## 5. Your Turn! (Exercises)

### Exercise 1: Create a Course Catalog
**Task:** Create two tables: `courses` and `enrollments`.
*   `courses`: needs a PK (`course_code`) and a unique title.
*   `enrollments`: needs to link a `student_id` (integer) and `course_code`.
*   **Constraint:** A student cannot enroll in the same course twice. (Hint: Composite Primary Key).

```sql
-- TODO: Write your CREATE TABLE statements here
```

### Exercise 2: Test the Composite Key
**Task:** Insert a student into a course twice and ensure it fails.

```python
# TODO: Write your INSERT tests here
```

### Exercise 3: Identify Keys & Integrity Violations
**Scenario:** The following data was prepared using a spreadsheet and needs to be migrated to a relational database. However, the spreadsheet allowed data entry without any constraints, so there are integrity violations that would prevent this data from being loaded into properly designed tables.

**Task:** Examine the two tables below and identify the problems.

**Table: `departments`**
| dept_id | dept_name     | budget    |
|---------|---------------|-----------|
| 10      | Engineering   | 500000    |
| 20      | Marketing     | 300000    |
| 10      | Sales         | 250000    |
| 30      | HR            | NULL      |

**Table: `employees`**
| emp_id | name    | dept_id | salary |
|--------|---------|---------|--------|
| 1      | Alice   | 10      | 75000  |
| 2      | Bob     | 20      | 65000  |
| 3      | Charlie | 50      | 70000  |
| 4      | Diana   | 10      | 80000  |
| NULL   | Eve     | 30      | 55000  |

**Questions:**
1. What should be the Primary Key for each table?
2. What is the Foreign Key relationship between these tables?
3. List **all** integrity violations you can find in the data above. (Hint: There are at least 3 problems.)

```python
# TODO: Write your answers as comments or markdown below
# 1. Primary Keys:
# 2. Foreign Key:
# 3. Integrity Violations:
```

### Exercise 4: Design a Schema from Requirements
**Task:** A local library needs a database. Here's what they track:

- **Books** have an ISBN (unique 13-digit code), title, and publication year
- **Members** have a member number, name, and join date
- **Loans** track which member borrowed which book and when (a member can borrow the same book multiple times on different dates)

**Sample Data:**

| isbn          | title                    | pub_year |
|---------------|--------------------------|----------|
| 9780134685991 | Effective Java           | 2018     |
| 9780596517748 | JavaScript: The Good Parts | 2008   |
| 9781491950357 | Fluent Python            | 2015     |

| member_no | name         | join_date  |
|-----------|--------------|------------|
| 101       | Alice Wong   | 2023-01-15 |
| 102       | Bob Smith    | 2023-03-22 |

| ?         | ?             | loan_date  |
|-----------|---------------|------------|
| ...       | ...           | 2024-06-01 |
| ...       | ...           | 2024-07-10 |
| ...       | ...           | 2024-09-05 |

*Note: The `loans` table columns are left incomplete—determining which columns link the tables is part of the exercise.*

**Questions:**
1. Identify the Primary Key for each table.
2. Identify the Foreign Keys and which tables they connect.
3. Write the `CREATE TABLE` statements with appropriate constraints.

```sql
-- TODO: Write your CREATE TABLE statements here
-- Table: books

-- Table: members

-- Table: loans
```

### Exercise 5: From ER Diagram to SQL
**Task:** Study the ER diagram below, then write the corresponding `CREATE TABLE` statements.

```python
from mermaid import Mermaid

Mermaid("""
erDiagram
    direction LR
    SUPPLIER {
        int supplier_id PK
        string name
        string country
    }
    PRODUCT {
        int product_id PK
        string name
        decimal price
        int supplier_id FK
        int category_id FK
    }
    CATEGORY {
        int category_id PK
        string name
        string description
    }
    SUPPLIER ||--o{ PRODUCT : supplies
    CATEGORY ||--o{ PRODUCT : contains
""")
```

**Your Task:**
1. Based on the diagram, write the three `CREATE TABLE` statements.
2. Make sure to define the correct data types, PRIMARY KEYs, and FOREIGN KEYs.
3. Add a `CHECK` constraint: `price` must be greater than 0.

```sql
-- TODO: Write your CREATE TABLE statements here
-- Remember: Create parent tables (SUPPLIER, CATEGORY) before child table (PRODUCT)

```

---

## 6. Summary
*   **Primary Keys** ensure rows are unique.
*   **Foreign Keys** ensure relationships are valid.
*   **CHECK constraints** ensure data quality (e.g., Age > 0).
*   The database engine enforces these rules automatically, saving you from writing thousands of lines of validation code in Python.
