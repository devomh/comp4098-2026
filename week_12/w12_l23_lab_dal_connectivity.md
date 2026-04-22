---
title: "Lab: DAL Architecture & Connection Pooling"
week: 12
type: lab
tags: [dal, connection-pooling, sqlalchemy, psycopg2, architecture]
difficulty: intermediate
duration: "55 mins"
---

# Lab: DAL Architecture & Connection Pooling

## 1. Prerequisites & Setup

**Before starting this lab, you should:**
*   Review [w12_l23_concept_dal_architecture.md](w12_l23_concept_dal_architecture.md) for DAL concepts, connection pooling, and credential management
*   Be comfortable with PostgreSQL from Weeks 4 and 8

**What you'll accomplish:**
In this lab, you'll build a connection pool with SQLAlchemy, compare pooled vs. unpooled performance, implement secure credential management, and structure a minimal Data Access Layer.

---

### Step 1: Install PostgreSQL and Required Packages

```python
%%bash
# Install PostgreSQL 15
apt-get update -qq 2>/dev/null
apt-get install -y -qq postgresql postgresql-client > /dev/null
service postgresql start

# Create a database and user for our lab
sudo -u postgres psql -c "CREATE USER student WITH PASSWORD 'lab_pass';"
sudo -u postgres psql -c "CREATE DATABASE university_db OWNER student;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE university_db TO student;"
echo "PostgreSQL ready: $(psql --version | head -1)"
```

<details>
<summary>Expected Output</summary>

~~~text
PostgreSQL ready: psql (PostgreSQL) 15.x (Ubuntu ...)
~~~

</details>

### Step 2: Install Python Packages

```python
# Setup: Run this cell first (required for Colab)
!pip install -q sqlalchemy psycopg2-binary python-dotenv pandas
```

```python
import time
import os
import pandas as pd
from sqlalchemy import create_engine, text, pool as sa_pool
import psycopg2
from psycopg2 import pool as pg_pool

pd.set_option('display.max_columns', None)
print("Packages installed and imported")
```

<details>
<summary>Expected Output</summary>

~~~text
Packages installed and imported
~~~

</details>

### Step 3: Create a Test Schema and Seed Data

```python
# Connect directly to create schema and seed data
DB_URL = "postgresql://student:lab_pass@localhost:5432/university_db"
engine = create_engine(DB_URL)

with engine.begin() as conn:
    conn.execute(text("""
        DROP TABLE IF EXISTS enrollments, courses, students CASCADE;

        CREATE TABLE students (
            student_id SERIAL PRIMARY KEY,
            name VARCHAR(100) NOT NULL,
            major VARCHAR(50),
            gpa NUMERIC(3,2) CHECK (gpa >= 0 AND gpa <= 4.0),
            email VARCHAR(100) UNIQUE
        );

        CREATE TABLE courses (
            course_id SERIAL PRIMARY KEY,
            code VARCHAR(10) UNIQUE NOT NULL,
            title VARCHAR(100) NOT NULL,
            credits INTEGER CHECK (credits > 0)
        );

        CREATE TABLE enrollments (
            enrollment_id SERIAL PRIMARY KEY,
            student_id INTEGER REFERENCES students(student_id),
            course_id INTEGER REFERENCES courses(course_id),
            semester VARCHAR(20),
            grade VARCHAR(2)
        );
    """))

    # Seed students
    conn.execute(text("""
        INSERT INTO students (name, major, gpa, email) VALUES
        ('Ana Torres', 'Data Science', 3.8, 'ana.torres@upr.edu'),
        ('Luis Rivera', 'Data Science', 3.5, 'luis.rivera@upr.edu'),
        ('Maria Santos', 'Computer Science', 3.9, 'maria.santos@upr.edu'),
        ('Carlos Diaz', 'Mathematics', 3.2, 'carlos.diaz@upr.edu'),
        ('Sofia Mendez', 'Data Science', 3.7, 'sofia.mendez@upr.edu');
    """))

    # Seed courses
    conn.execute(text("""
        INSERT INTO courses (code, title, credits) VALUES
        ('COMP4098', 'Data Management & Architectures', 3),
        ('COMP4050', 'Machine Learning', 3),
        ('STAT3001', 'Statistical Methods', 4),
        ('COMP3020', 'Algorithms', 3);
    """))

    # Seed enrollments
    conn.execute(text("""
        INSERT INTO enrollments (student_id, course_id, semester, grade) VALUES
        (1, 1, '2026-01', 'A'), (1, 2, '2026-01', 'A'),
        (2, 1, '2026-01', 'B'), (2, 3, '2026-01', 'A'),
        (3, 1, '2026-01', 'A'), (3, 2, '2026-01', 'A'), (3, 4, '2026-01', 'B'),
        (4, 3, '2026-01', 'C'), (4, 4, '2026-01', 'B'),
        (5, 1, '2026-01', 'A'), (5, 2, '2026-01', 'B');
    """))

print("Schema created and seeded:")
print(pd.read_sql("SELECT * FROM students", engine))
```

<details>
<summary>Expected Output</summary>

~~~text
Schema created and seeded:
   student_id           name           major   gpa                   email
0           1     Ana Torres    Data Science  3.80    ana.torres@upr.edu
1           2    Luis Rivera    Data Science  3.50   luis.rivera@upr.edu
2           3  Maria Santos  Computer Science  3.90  maria.santos@upr.edu
3           4   Carlos Diaz     Mathematics  3.20   carlos.diaz@upr.edu
4           5  Sofia Mendez    Data Science  3.70  sofia.mendez@upr.edu
~~~

</details>

---

## 2. Connection Lifecycle: The Naive Approach

### Opening and Closing Connections Manually

Every time you call `psycopg2.connect()`, you pay the full cost of TCP setup, authentication, and server process creation.

> **Note:** This lab runs on `localhost` with no TLS, so connection setup is a best case (~5–20 ms). In production — remote host, TLS handshake, cloud networking — per-connection overhead is typically **50–200 ms**, and the pooling speedup is correspondingly larger.

```python
def query_without_pool(n_queries):
    """Run n_queries, each opening and closing a fresh connection."""
    results = []
    for _ in range(n_queries):
        conn = psycopg2.connect(
            host="localhost", port=5432,
            dbname="university_db", user="student", password="lab_pass"
        )
        cur = conn.cursor()
        cur.execute("SELECT * FROM students WHERE gpa > %s", (3.5,))
        results.append(cur.fetchall())
        cur.close()
        conn.close()
    return results

# Time it
start = time.time()
query_without_pool(100)
no_pool_time = time.time() - start
print(f"100 queries WITHOUT pooling: {no_pool_time:.3f}s")
print(f"Average per query: {no_pool_time/100*1000:.1f}ms")
```

<details>
<summary>Expected Output</summary>

~~~text
100 queries WITHOUT pooling: ~0.5-2.0s (varies by machine)
Average per query: ~5-20ms
~~~

</details>

---

## 3. Connection Pooling with psycopg2

### Using `SimpleConnectionPool`

```python
# Create a pool of 1-10 connections
connection_pool = pg_pool.SimpleConnectionPool(
    minconn=1,
    maxconn=10,
    host="localhost", port=5432,
    dbname="university_db", user="student", password="lab_pass"
)

def query_with_psycopg2_pool(n_queries):
    """Run n_queries, borrowing and returning connections from the pool."""
    results = []
    for _ in range(n_queries):
        conn = connection_pool.getconn()   # Borrow from pool
        cur = conn.cursor()
        cur.execute("SELECT * FROM students WHERE gpa > %s", (3.5,))
        results.append(cur.fetchall())
        cur.close()
        connection_pool.putconn(conn)      # Return to pool (NOT close!)
    return results

# Time it
start = time.time()
query_with_psycopg2_pool(100)
pool_time = time.time() - start
print(f"100 queries WITH psycopg2 pool: {pool_time:.3f}s")
print(f"Average per query: {pool_time/100*1000:.1f}ms")
print(f"\nSpeedup: {no_pool_time/pool_time:.1f}x faster with pooling")

# Clean up
connection_pool.closeall()
```

<details>
<summary>Expected Output</summary>

~~~text
100 queries WITH psycopg2 pool: ~0.05-0.2s (varies by machine)
Average per query: ~0.5-2ms

Speedup: ~5-10x faster with pooling
~~~

</details>

Notice: `putconn()` returns the connection to the pool — it does **not** close it. The connection stays open and ready for the next request.

---

## 4. Connection Pooling with SQLAlchemy

SQLAlchemy provides built-in connection pooling through its `Engine` object. This is the approach you'll use going forward.

### Creating a Pooled Engine

```python
# SQLAlchemy engine with explicit pool configuration
engine_pooled = create_engine(
    "postgresql://student:lab_pass@localhost:5432/university_db",
    pool_size=5,          # Maintain 5 connections
    max_overflow=10,      # Allow up to 15 total under load
    pool_timeout=30,      # Wait 30s for an available connection
    pool_recycle=1800,    # Replace connections every 30 minutes
    echo_pool=False       # Set True to log pool activity when debugging; verbose otherwise
)

print(f"Pool class: {engine_pooled.pool.__class__.__name__}")
print(f"Pool size: {engine_pooled.pool.size()}")
```

<details>
<summary>Expected Output</summary>

~~~text
Pool class: QueuePool
Pool size: 5
~~~

</details>

### Querying with the Pooled Engine

```python
def query_with_sqlalchemy_pool(n_queries):
    """Run n_queries using SQLAlchemy's built-in pool."""
    results = []
    for _ in range(n_queries):
        with engine_pooled.connect() as conn:
            result = conn.execute(text("SELECT * FROM students WHERE gpa > :min_gpa"),
                                  {"min_gpa": 3.5})
            results.append(result.fetchall())
    return results

start = time.time()
query_with_sqlalchemy_pool(100)
sa_pool_time = time.time() - start
print(f"100 queries with SQLAlchemy pool: {sa_pool_time:.3f}s")
print(f"Average per query: {sa_pool_time/100*1000:.1f}ms")
```

<details>
<summary>Expected Output</summary>

~~~text
100 queries with SQLAlchemy pool: ~0.05-0.3s (varies by machine)
Average per query: ~0.5-3ms
~~~

</details>

### Comparing No Pool vs. SQLAlchemy Pool

```python
# Disable pooling for comparison (NullPool creates a fresh connection every time)
engine_no_pool = create_engine(
    "postgresql://student:lab_pass@localhost:5432/university_db",
    poolclass=sa_pool.NullPool   # No pooling — new connection per request
)

def query_with_no_pool_sa(n_queries):
    results = []
    for _ in range(n_queries):
        with engine_no_pool.connect() as conn:
            result = conn.execute(text("SELECT * FROM students WHERE gpa > :min_gpa"),
                                  {"min_gpa": 3.5})
            results.append(result.fetchall())
    return results

# Run the benchmark
n = 200
print(f"Benchmark: {n} identical queries\n")

start = time.time()
query_with_no_pool_sa(n)
t_no_pool = time.time() - start

start = time.time()
query_with_sqlalchemy_pool(n)
t_pooled = time.time() - start

print(f"{'Strategy':<25} {'Total (s)':>10} {'Per Query (ms)':>15}")
print("-" * 52)
print(f"{'NullPool (no pooling)':<25} {t_no_pool:>10.3f} {t_no_pool/n*1000:>15.1f}")
print(f"{'QueuePool (pooled)':<25} {t_pooled:>10.3f} {t_pooled/n*1000:>15.1f}")
print(f"\nPooling speedup: {t_no_pool/t_pooled:.1f}x")
```

<details>
<summary>Expected Output</summary>

~~~text
Benchmark: 200 identical queries

Strategy                    Total (s)  Per Query (ms)
----------------------------------------------------
NullPool (no pooling)         ~1.500           ~7.5
QueuePool (pooled)            ~0.150           ~0.8

Pooling speedup: ~5-10x
~~~

(Exact numbers depend on the Colab runtime. The speedup ratio is the important observation.)

</details>

---

## 5. Secure Credential Management

### Using Environment Variables

```python
# Simulate setting environment variables (in production, these come from the deployment platform)
os.environ["DATABASE_URL"] = "postgresql://student:lab_pass@localhost:5432/university_db"

# Read the connection string from the environment — NOT hardcoded
db_url = os.environ["DATABASE_URL"]
engine_secure = create_engine(db_url, pool_size=5)

# Verify it works
with engine_secure.connect() as conn:
    result = conn.execute(text("SELECT COUNT(*) FROM students"))
    count = result.scalar()
print(f"Connected securely — {count} students found")
```

<details>
<summary>Expected Output</summary>

~~~text
Connected securely — 5 students found
~~~

</details>

### Using `.env` Files with `python-dotenv`

```python
# Create a .env file (in production, this file exists but is NOT committed to git)
with open(".env", "w") as f:
    f.write("DATABASE_URL=postgresql://student:lab_pass@localhost:5432/university_db\n")
    f.write("APP_ENV=development\n")

print("Created .env file")
!cat .env
```

```python
from dotenv import load_dotenv

# Clear the env var we set manually above
if "DATABASE_URL" in os.environ:
    del os.environ["DATABASE_URL"]

# Load from .env file
load_dotenv()

db_url = os.environ["DATABASE_URL"]
app_env = os.environ.get("APP_ENV", "production")
print(f"Environment: {app_env}")
print(f"DB URL loaded: {db_url[:20]}...{db_url[-15:]}")

# Connect using the loaded URL
engine_env = create_engine(db_url, pool_size=5)
with engine_env.connect() as conn:
    result = conn.execute(text("SELECT name FROM students LIMIT 1"))
    print(f"Connection works: {result.scalar()}")
```

<details>
<summary>Expected Output</summary>

~~~text
Environment: development
DB URL loaded: postgresql://stude...university_db
Connection works: Ana Torres
~~~

</details>

```python
# Clean up — in a real project, .env is in .gitignore
os.remove(".env")
```

---

## 6. Building a Minimal DAL

Now let's put it all together: a simple Data Access Layer that centralizes connection management and query execution.

### The DAL Module

```python
class UniversityDAL:
    """
    Data Access Layer for the university database.
    Centralizes connection management and provides clean query methods.
    """
    def __init__(self, db_url, pool_size=5):
        self.engine = create_engine(db_url, pool_size=pool_size)

    def get_all_students(self):
        """Return all students as a list of dicts."""
        with self.engine.connect() as conn:
            result = conn.execute(text("SELECT * FROM students ORDER BY name"))
            columns = result.keys()
            return [dict(zip(columns, row)) for row in result]

    def get_student_by_id(self, student_id):
        """Return a single student by ID, or None if not found."""
        with self.engine.connect() as conn:
            result = conn.execute(
                text("SELECT * FROM students WHERE student_id = :id"),
                {"id": student_id}
            )
            row = result.fetchone()
            if row is None:
                return None
            return dict(zip(result.keys(), row))

    def get_students_by_major(self, major):
        """Return all students in a given major."""
        with self.engine.connect() as conn:
            result = conn.execute(
                text("SELECT * FROM students WHERE major = :major ORDER BY gpa DESC"),
                {"major": major}
            )
            columns = result.keys()
            return [dict(zip(columns, row)) for row in result]

    def get_student_courses(self, student_id):
        """Return all courses a student is enrolled in."""
        with self.engine.connect() as conn:
            result = conn.execute(text("""
                SELECT c.code, c.title, e.semester, e.grade
                FROM enrollments e
                JOIN courses c ON e.course_id = c.course_id
                WHERE e.student_id = :id
                ORDER BY c.code
            """), {"id": student_id})
            columns = result.keys()
            return [dict(zip(columns, row)) for row in result]

    def get_course_roster(self, course_code):
        """Return all students enrolled in a course."""
        with self.engine.connect() as conn:
            result = conn.execute(text("""
                SELECT s.name, s.major, e.grade
                FROM enrollments e
                JOIN students s ON e.student_id = s.student_id
                JOIN courses c ON e.course_id = c.course_id
                WHERE c.code = :code
                ORDER BY s.name
            """), {"code": course_code})
            columns = result.keys()
            return [dict(zip(columns, row)) for row in result]

    def close(self):
        """Dispose the engine and close all pooled connections."""
        self.engine.dispose()

print("UniversityDAL class defined")
```

### Using the DAL

Notice how the application code below has **zero SQL and zero connection logic** — it only calls clean DAL methods.

```python
# Initialize the DAL (one-time setup) — credentials loaded from the environment,
# never hardcoded. This is the pattern established earlier in this lab and in L22.
dal = UniversityDAL(os.environ["DATABASE_URL"])

# --- Application code: no SQL, no connections, no drivers ---

# Get all students
print("=== All Students ===")
for s in dal.get_all_students():
    print(f"  {s['name']:20s} | {s['major']:20s} | GPA: {s['gpa']}")

# Get one student
print("\n=== Student #3 ===")
student = dal.get_student_by_id(3)
print(f"  {student['name']} — {student['major']} (GPA: {student['gpa']})")

# Get Data Science students
print("\n=== Data Science Students (by GPA) ===")
for s in dal.get_students_by_major("Data Science"):
    print(f"  {s['name']:20s} GPA: {s['gpa']}")

# Get courses for a student
print("\n=== Ana Torres's Courses ===")
for c in dal.get_student_courses(1):
    print(f"  {c['code']} — {c['title']} (Grade: {c['grade']})")

# Get course roster
print("\n=== COMP4098 Roster ===")
for s in dal.get_course_roster("COMP4098"):
    print(f"  {s['name']:20s} | {s['major']:20s} | Grade: {s['grade']}")
```

<details>
<summary>Expected Output</summary>

~~~text
=== All Students ===
  Ana Torres           | Data Science         | GPA: 3.80
  Carlos Diaz          | Mathematics          | GPA: 3.20
  Luis Rivera          | Data Science         | GPA: 3.50
  Maria Santos         | Computer Science     | GPA: 3.90
  Sofia Mendez         | Data Science         | GPA: 3.70

=== Student #3 ===
  Maria Santos — Computer Science (GPA: 3.90)

=== Data Science Students (by GPA) ===
  Ana Torres           GPA: 3.80
  Sofia Mendez         GPA: 3.70
  Luis Rivera          GPA: 3.50

=== Ana Torres's Courses ===
  COMP4050 — Machine Learning (Grade: A)
  COMP4098 — Data Management & Architectures (Grade: A)

=== COMP4098 Roster ===
  Ana Torres           | Data Science         | Grade: A
  Luis Rivera          | Data Science         | Grade: B
  Maria Santos         | Computer Science     | Grade: A
  Sofia Mendez         | Data Science         | Grade: A
~~~

</details>

---

## 7. The DAL Advantage: Swapping the "Backend"

The DAL makes it trivial to add new data sources. Here's how you'd add a pandas-based "export" without changing any SQL:

```python
# The DAL methods return plain dicts — easy to convert to DataFrames
students_df = pd.DataFrame(dal.get_all_students())
courses_df = pd.DataFrame(dal.get_student_courses(1))

print("Students DataFrame:")
print(students_df[['name', 'major', 'gpa']].to_string(index=False))
print(f"\nAna Torres's courses:")
print(courses_df.to_string(index=False))
```

<details>
<summary>Expected Output</summary>

~~~text
Students DataFrame:
          name              major   gpa
    Ana Torres       Data Science  3.80
   Carlos Diaz      Mathematics  3.20
   Luis Rivera       Data Science  3.50
  Maria Santos  Computer Science  3.90
  Sofia Mendez       Data Science  3.70

Ana Torres's courses:
     code                              title semester grade
 COMP4050                   Machine Learning  2026-01     A
 COMP4098  Data Management & Architectures  2026-01     A
~~~

</details>

```python
# Clean up
dal.close()
```

---

## 8. Your Turn! (Exercises)

### Exercise 1: Pool Size Experiment

**Task:** Experiment with different pool sizes and observe the effect on performance.

```python
# TODO: Create three engines with different pool configurations:
# 1. pool_size=1, max_overflow=0 (only 1 connection ever)
# 2. pool_size=5, max_overflow=5
# 3. pool_size=10, max_overflow=10
#
# For each, run 200 queries and time the results.
# Print a comparison table.
#
# Hint: Use create_engine() with different pool_size values
#       Use the query_with_sqlalchemy_pool pattern from section 4
```

<details>
<summary>Expected Output</summary>

~~~text
Pool Size Experiment (200 queries each):

Pool Size    Max Overflow    Total (s)    Per Query (ms)
-------------------------------------------------------
1            0               ~0.15        ~0.7
5            5               ~0.12        ~0.6
10           10              ~0.12        ~0.6

Note: With sequential queries, a single connection is nearly as fast
as multiple connections. The benefit of larger pools becomes apparent
with CONCURRENT requests (e.g., a web server with multiple threads).
~~~

</details>

### Exercise 2: Extend the DAL

**Task:** Add two new methods to the `UniversityDAL` class.

```python
# TODO: Add these methods to UniversityDAL:
#
# 1. get_honor_roll(min_gpa=3.5)
#    Returns students with GPA >= min_gpa, sorted by GPA descending
#
# 2. get_enrollment_summary()
#    Returns a list of dicts with: course_code, course_title, student_count
#    Hint: Use GROUP BY with COUNT and JOIN
#
# Test your methods:
# dal = UniversityDAL("postgresql://student:lab_pass@localhost:5432/university_db")
# print("Honor Roll:", dal.get_honor_roll())
# print("Enrollment Summary:", dal.get_enrollment_summary())
# dal.close()
```

<details>
<summary>Expected Output</summary>

~~~text
Honor Roll:
  Maria Santos         GPA: 3.90
  Ana Torres           GPA: 3.80
  Sofia Mendez         GPA: 3.70
  Luis Rivera          GPA: 3.50

Enrollment Summary:
  COMP4098 — Data Management & Architectures: 4 students
  COMP4050 — Machine Learning: 3 students
  STAT3001 — Statistical Methods: 2 students
  COMP3020 — Algorithms: 2 students
~~~

</details>

### Exercise 3: Credential Security Audit

**Task:** Identify the security issues in the following code and fix them.

```python
# TODO: This code has THREE security problems. Find and fix all three.
# Write the corrected version below.

import psycopg2

DB_HOST = "prod-db.company.com"
DB_PASSWORD = "P@ssw0rd123!"

conn = psycopg2.connect(
    host=DB_HOST,
    dbname="production_db",
    user="admin",
    password=DB_PASSWORD
)

user_input = input("Enter student name: ")
cur = conn.cursor()
cur.execute(f"SELECT * FROM students WHERE name = '{user_input}'")
results = cur.fetchall()
print(results)
conn.close()

# TODO: Write the corrected version using:
# 1. Environment variables for credentials
# 2. Parameterized queries
# 3. Connection pooling (or context manager)
```

<details>
<summary>Expected Output (Reference Solution)</summary>

**Security issues found:**
1. Hardcoded production credentials (`DB_PASSWORD` in source code)
2. SQL injection vulnerability (f-string interpolates `user_input` into the query)
3. Manual connection management — no pooling, and `conn.close()` is skipped if an exception is raised

**Corrected version:**

~~~python
import os
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

# 1. Credentials from environment (DATABASE_URL injected by deployment or .env)
load_dotenv()
engine = create_engine(
    os.environ["DATABASE_URL"],
    pool_size=5,
    max_overflow=10,
)

# 3. Pooled connection via context manager — auto-returned even on exception
user_input = input("Enter student name: ")
with engine.connect() as conn:
    # 2. Parameterized query — driver escapes the value; injection is impossible
    result = conn.execute(
        text("SELECT * FROM students WHERE name = :name"),
        {"name": user_input},
    )
    print(result.fetchall())
~~~

</details>

---

## 9. Summary

In this lab, you:
*   **Compared** unpooled vs. pooled connection strategies and measured the performance difference
*   **Created** connection pools with both `psycopg2.pool` and SQLAlchemy's built-in `QueuePool`
*   **Implemented** secure credential management using environment variables and `.env` files
*   **Built** a minimal `UniversityDAL` class that centralizes all database access behind clean methods
*   **Observed** how the DAL decouples application code from SQL and driver details
