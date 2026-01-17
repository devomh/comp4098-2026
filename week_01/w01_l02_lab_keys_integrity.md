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
import duckdb
%load_ext sql
%config SqlMagic.autopandas = True
%config SqlMagic.feedback = False
%config SqlMagic.displaycon = False
%sql duckdb:///:memory:
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
    print(f"Caught expected error: {e}")
```

**Test 2: Duplicate Candidate Key (Email)**
```python
try:
    %sql INSERT INTO users VALUES (2, 'Bob', 'alice@test.com', 30); # Duplicate Email
except Exception as e:
    print(f"Caught expected error: {e}")
```

**Test 3: Domain Violation (Age)**
```python
try:
    %sql INSERT INTO users VALUES (3, 'Charlie', 'charlie@test.com', -5); # Invalid Age
except Exception as e:
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

---

## 6. Summary
*   **Primary Keys** ensure rows are unique.
*   **Foreign Keys** ensure relationships are valid.
*   **CHECK constraints** ensure data quality (e.g., Age > 0).
*   The database engine enforces these rules automatically, saving you from writing thousands of lines of validation code in Python.
