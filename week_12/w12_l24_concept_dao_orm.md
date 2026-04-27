---
title: "Implementation Patterns: DAO, Repository & ORM with SQLAlchemy"
week: 12
type: concept
tags: [dao, repository-pattern, orm, sqlalchemy, design-patterns]
difficulty: intermediate
duration: "40 mins"
---

# Implementation Patterns: DAO, Repository & ORM with SQLAlchemy

## 1. Learning Objectives

By the end of this lesson, you will be able to:
*   Define the DAO (Data Access Object) pattern and explain how it encapsulates data access logic
*   Define the Repository pattern and distinguish it from a DAO
*   Explain what an ORM (Object-Relational Mapping) is and why it exists
*   Map relational concepts (tables, rows, columns, foreign keys) to ORM equivalents (classes, instances, attributes, relationships)
*   Describe SQLAlchemy's two-layer architecture: Core (SQL toolkit) vs. ORM
*   Explain the Session as the unit-of-work manager in SQLAlchemy's ORM
*   Compare raw SQL, SQLAlchemy Core, and SQLAlchemy ORM approaches for the same task

---

## 2. The "Why": From DAL to Design Patterns

In L23 you built a Data Access Layer — a class that centralizes database queries and hides connection details from application code. That DAL used **raw SQL** inside its methods. This works, but it has limitations:

*   **Manual mapping:** You converted rows to dicts by hand (`dict(zip(columns, row))`)
*   **SQL strings everywhere:** Every method contains a SQL string — typos aren't caught until runtime
*   **No object model:** Your application thinks in terms of Python objects (students, courses), but the DAL returns raw dicts
*   **Schema changes ripple:** If a column is renamed, you must find and update every SQL string that references it

Industry has developed patterns to address these problems at different levels of abstraction. All of them are ways to implement a DAL — they differ in how much they abstract away from raw SQL:

| Strategy | Abstraction Level | Best For |
| :--- | :--- | :--- |
| Raw SQL class (L23 DAL) | Lowest | Scripts, learning |
| DAO | Per-table | Straightforward CRUD apps |
| Repository | Per-domain concept | Business logic-heavy apps |
| ORM | Automatic mapping | Productivity-first, web backends |

This lesson covers the last three. The rest of §2–6 dives into each one.

> **Analogy:** Think of ordering food at different types of restaurants:
> *   **Raw SQL** is like going to a food market and cooking yourself — maximum control, maximum effort
> *   **DAO pattern** is like ordering at the counter of a cafeteria — you tell them exactly what you want, they prepare it behind the scenes
> *   **ORM** is like a full-service restaurant — you describe what you'd like, and the kitchen figures out how to prepare it. You never see the raw ingredients

---

## 3. The DAO Pattern

### 3.1 Definition

A **Data Access Object (DAO)** is a class that provides an abstract interface to a specific data source. Each DAO typically maps to one table or collection and exposes CRUD methods.

```mermaid
graph LR
    subgraph "Application"
        APP["Business Logic"]
    end

    subgraph "Data Access Objects"
        SD["StudentDAO"]
        CD["CourseDAO"]
    end

    subgraph "Database"
        ST["students table"]
        CT["courses table"]
    end

    APP --> SD
    APP --> CD
    SD --> ST
    CD --> CT

    style SD fill:#42A5F5,color:white
    style CD fill:#42A5F5,color:white
    style ST fill:#336791,color:white
    style CT fill:#336791,color:white
```

### 3.2 DAO Interface

A DAO typically exposes these standard methods:

| Method | Description | SQL Equivalent |
| :--- | :--- | :--- |
| `find_by_id(id)` | Retrieve one record by primary key | `SELECT ... WHERE id = ?` |
| `find_all()` | Retrieve all records | `SELECT * FROM ...` |
| `find_by(criteria)` | Retrieve records matching criteria | `SELECT ... WHERE ...` |
| `create(entity)` | Insert a new record | `INSERT INTO ...` |
| `update(entity)` | Modify an existing record | `UPDATE ... SET ... WHERE ...` |
| `delete(id)` | Remove a record | `DELETE FROM ... WHERE ...` |

### 3.3 DAO Example (Raw SQL)

This is essentially what you built in L23, but formalized with a consistent interface:

```python
class StudentDAO:
    def __init__(self, engine):
        self.engine = engine

    def find_by_id(self, student_id):
        with self.engine.connect() as conn:
            result = conn.execute(
                text("SELECT * FROM students WHERE student_id = :id"),
                {"id": student_id}
            )
            row = result.fetchone()
            return dict(zip(result.keys(), row)) if row else None

    def find_all(self):
        with self.engine.connect() as conn:
            result = conn.execute(text("SELECT * FROM students ORDER BY name"))
            return [dict(zip(result.keys(), row)) for row in result]

    def create(self, student_data):
        with self.engine.begin() as conn:
            conn.execute(text("""
                INSERT INTO students (name, major, gpa, email)
                VALUES (:name, :major, :gpa, :email)
            """), student_data)

    def delete(self, student_id):
        with self.engine.begin() as conn:
            conn.execute(
                text("DELETE FROM students WHERE student_id = :id"),
                {"id": student_id}
            )
```

**Strengths:** Full SQL control, easy to understand, no new abstractions.
**Weakness:** Manual row-to-dict conversion, SQL strings that can't be checked at import time.

### Key Takeaway
*   A DAO maps one-to-one to a table/collection and provides CRUD methods
*   DAOs hide SQL details from business logic — the application calls `student_dao.find_by_id(3)` instead of writing SQL
*   With raw SQL, the DAO still requires manual result mapping

---

## 4. The Repository Pattern

### 4.1 How It Differs from DAO

The **Repository pattern** operates at a higher level of abstraction than a DAO. While a DAO deals with database operations on a single table, a Repository thinks in terms of **domain objects** and may aggregate data from multiple tables.

| Aspect | DAO | Repository |
| :--- | :--- | :--- |
| **Scope** | One table/collection | One domain concept (may span tables) |
| **Returns** | Dicts or raw data | Domain objects (classes/dataclasses) |
| **Query language** | Exposes CRUD per table | Methods reflect business needs |
| **Example method** | `student_dao.find_by_id(3)` | `student_repo.get_with_enrollments(3)` |

### 4.2 Repository Example

```python
from dataclasses import dataclass

@dataclass
class Student:
    id: int
    name: str
    major: str
    gpa: float
    courses: list  # Aggregated from enrollments + courses tables

class StudentRepository:
    def __init__(self, engine):
        self.engine = engine

    def get_with_enrollments(self, student_id):
        """Return a Student domain object with their enrolled courses."""
        with self.engine.connect() as conn:
            # Fetch student
            row = conn.execute(
                text("SELECT * FROM students WHERE student_id = :id"),
                {"id": student_id}
            ).fetchone()

            if not row:
                return None

            # Fetch enrolled courses
            courses = conn.execute(text("""
                SELECT c.code, c.title, e.grade
                FROM enrollments e JOIN courses c ON e.course_id = c.course_id
                WHERE e.student_id = :id
            """), {"id": student_id}).fetchall()

            return Student(
                id=row[0], name=row[1], major=row[2], gpa=float(row[3]),
                courses=[{"code": c[0], "title": c[1], "grade": c[2]} for c in courses]
            )
```

<details>
<summary>What is <code>@dataclass</code>?</summary>

`@dataclass` is a standard-library decorator (Python 3.7+) that auto-generates boilerplate methods for classes whose primary purpose is holding data. Given the field annotations, it generates:

*   `__init__` — so you can write `Student(id=1, name="Ana", ...)` without coding the constructor
*   `__repr__` — readable string representation for debugging
*   `__eq__` — equality comparison by field values

Without it, the equivalent class would require writing all of that by hand:

```python
class Student:
    def __init__(self, id, name, major, gpa, courses):
        self.id = id
        self.name = name
        ...
```

It's not SQLAlchemy-specific — it's a standard Python feature. It's particularly natural for Repository domain objects because those classes are just structured data containers with no logic. The decorator signals that intent clearly.

</details>

The Repository returns a rich **domain object** — a `Student` with their courses already attached. The application code doesn't need to know that this data comes from two different tables.

### Key Takeaway
*   Repositories aggregate data from multiple tables into domain objects
*   DAOs are database-centric (one per table), Repositories are domain-centric (one per business concept)
*   In practice, many projects use "DAO" and "Repository" interchangeably — the important thing is separating data access from business logic

---

## 5. Object-Relational Mapping (ORM)

### 5.1 The Impedance Mismatch

Relational databases think in **tables, rows, and foreign keys**. Python thinks in **classes, objects, and references**. This fundamental difference is called the **object-relational impedance mismatch**:

| Relational World | Python World |
| :--- | :--- |
| Table | Class |
| Row | Instance (object) |
| Column | Attribute |
| Foreign key | Object reference |
| JOIN | Navigating object relationships |
| SQL query | Method call |

An **ORM (Object-Relational Mapper)** bridges this gap by automatically converting between the two worlds.

### 5.2 How an ORM Works

```mermaid
graph LR
    subgraph "Python"
        CLS["class Student"]
        OBJ["Student(name='Ana',<br/>gpa=3.8)"]
    end

    subgraph "ORM Layer"
        MAP["SQLAlchemy ORM<br/>Mapping Engine"]
    end

    subgraph "Database"
        TBL["students table<br/>| id | name | gpa |"]
    end

    CLS <-->|"class ↔ table"| MAP
    OBJ <-->|"object ↔ row"| MAP
    MAP <-->|"SQL generation"| TBL

    style MAP fill:#42A5F5,color:white
    style TBL fill:#336791,color:white
```

With an ORM:
*   You define a Python class that **maps** to a database table
*   Each instance of the class represents a row
*   The ORM generates SQL behind the scenes — `INSERT`, `SELECT`, `UPDATE`, `DELETE`
*   Relationships (foreign keys) become Python object references

### 5.3 ORM Example Preview

```python
# Define the mapping (ORM model — SQLAlchemy 2.0 style)
class Student(Base):
    __tablename__ = "students"
    student_id: Mapped[int] = mapped_column(primary_key=True)
    name:       Mapped[str] = mapped_column(String(100))
    major:      Mapped[str | None] = mapped_column(String(50))
    gpa:        Mapped[float | None] = mapped_column(Numeric(3, 2))

# Use it — no SQL needed
stmt = select(Student).where(Student.name == "Ana Torres")
student = session.scalars(stmt).first()
print(student.name, student.gpa)   # Accessing row data as object attributes

student.gpa = 3.9                  # Modify in Python
session.commit()                   # ORM generates: UPDATE students SET gpa = 3.9 WHERE ...
```

You'll implement this fully in the L24 lab.

### Key Takeaway
*   ORMs eliminate manual SQL and row-to-object mapping
*   You interact with Python objects; the ORM handles SQL generation
*   Trade-off: less control over exact SQL, potential performance overhead for complex queries

---

## 6. SQLAlchemy Architecture

### 6.1 Two Layers

SQLAlchemy is not just an ORM — it's a comprehensive database toolkit with two distinct layers:

```mermaid
graph TD
    subgraph "SQLAlchemy"
        ORM["ORM Layer<br/>(Classes, Sessions,<br/> Relationships)"]
        CORE["Core Layer<br/>(Engine, Connection,<br/> SQL Expression Language)"]
    end

    subgraph "Database Drivers"
        PG["psycopg2"]
        SL["sqlite3"]
        MY["mysqlclient"]
    end

    ORM --> CORE
    CORE --> PG
    CORE --> SL
    CORE --> MY

    style ORM fill:#FF7043,color:white
    style CORE fill:#42A5F5,color:white
```

| Layer | What It Does | When to Use |
| :--- | :--- | :--- |
| **Core** | Engine creation, connection pooling, raw SQL with `text()`, SQL Expression Language | Data analysis, scripts, when you need exact SQL control |
| **ORM** | Table-to-class mapping, Session (unit of work), relationships, lazy loading | Web applications, CRUD-heavy apps, when productivity matters more than SQL control |

You've been using **Core** since L23 (the `create_engine` + `text()` pattern). The ORM layer adds class mapping on top.

### 6.2 Key ORM Components

| Component | Role |
| :--- | :--- |
| **`DeclarativeBase`** | Base class that all ORM models inherit from; registers the table-class mapping |
| **Model class** | A Python class that maps to a database table (extends `Base`) |
| **`Mapped[T]` + `mapped_column()`** | The 2.0-style column declaration — a typed attribute bound to a database column (type and constraints on the right) |
| **`relationship()`** | Defines how two models are related (1:N, M:N) — enables navigation via attributes |
| **`Session`** | The unit-of-work manager — tracks changes to objects and flushes them to the database |

### 6.3 The Session: Unit of Work

The **Session** is the central concept in SQLAlchemy's ORM. It acts as a staging area between your Python objects and the database:

```mermaid
sequenceDiagram
    participant App as Application
    participant Sess as Session
    participant DB as Database

    App->>Sess: student = Student(name="Ana", gpa=3.8)
    App->>Sess: session.add(student)
    Note over Sess: Tracks the new object<br/>(not yet in DB)
    App->>Sess: session.commit()
    Sess->>DB: INSERT INTO students (name, gpa) VALUES ('Ana', 3.8)
    DB-->>Sess: OK
    Sess-->>App: student.student_id is now set
```

| Session Operation | Effect |
| :--- | :--- |
| `session.add(obj)` | Marks a new object for insertion |
| `session.delete(obj)` | Marks an existing object for deletion |
| Modify `obj.attribute` | Session detects the change automatically |
| `session.commit()` | Flushes all pending changes to the database in a transaction |
| `session.rollback()` | Discards all pending changes |
| `session.close()` | Releases the connection back to the pool |

### Key Takeaway
*   SQLAlchemy has two layers: Core (SQL toolkit + pooling) and ORM (object mapping + sessions)
*   You can use Core without ORM, but not ORM without Core
*   The Session tracks object changes and translates them into SQL on `commit()`

---

## 7. Three Approaches Compared

Here's the same task — "get all Data Science students sorted by GPA" — implemented three ways:

### Raw SQL (psycopg2)
```python
conn = psycopg2.connect(dsn)  # dsn = Data Source Name, e.g. "postgresql://user:pass@host/db"
cur = conn.cursor()
cur.execute("SELECT * FROM students WHERE major = %s ORDER BY gpa DESC", ("Data Science",))
rows = cur.fetchall()
for row in rows:
    print(row[1], row[3])  # Access by index — fragile!
cur.close()
conn.close()
```

### SQLAlchemy Core
```python
engine = create_engine(dsn)  # same DSN string as above
with engine.connect() as conn:
    result = conn.execute(
        text("SELECT * FROM students WHERE major = :m ORDER BY gpa DESC"),
        {"m": "Data Science"}
    )
    for row in result:
        print(row.name, row.gpa)  # Access by column name
```

### SQLAlchemy ORM
```python
with Session(engine) as session:
    stmt = (select(Student)
            .where(Student.major == "Data Science")
            .order_by(Student.gpa.desc()))
    students = session.scalars(stmt).all()
    for s in students:
        print(s.name, s.gpa)  # Access as object attributes
```

### Comparison

| Aspect | Raw SQL | Core | ORM |
| :--- | :--- | :--- | :--- |
| **SQL visibility** | You write all SQL | You write SQL with `text()` | SQL is generated |
| **Result type** | Tuples (by index) | Named tuples (by name) | Python objects |
| **Connection mgmt** | Manual open/close | Context manager | Session manages |
| **Pooling** | Manual | Built-in | Built-in |
| **Type safety** | None | Minimal | Column types defined in model |
| **Best for** | Scripts, max control | Analytics, mixed SQL/Python | CRUD apps, web backends |

---

## 8. Deep Dive: When NOT to Use an ORM (Optional)

<details>
<summary>Click to expand: ORM Trade-offs</summary>

### The N+1 Query Problem

The most notorious ORM performance issue. Consider loading students and their courses:

```python
# ORM with lazy loading (default)
students = session.scalars(select(Student)).all()   # 1 query: SELECT * FROM students
for s in students:
    print(s.enrollments)                             # N queries: 1 per student!
```

This generates N+1 queries (1 for students + 1 per student for enrollments). The fix is **eager loading**:

```python
from sqlalchemy.orm import joinedload
stmt = select(Student).options(joinedload(Student.enrollments))
students = session.scalars(stmt).unique().all()
# 1 query with JOIN — much faster
```

### When ORMs Struggle

| Scenario | Why ORM Isn't Ideal | Better Alternative |
| :--- | :--- | :--- |
| Complex analytical queries (window functions, CTEs) | ORM can't express these naturally | Raw SQL or SQLAlchemy Core |
| Bulk inserts (100K+ rows) | ORM tracks each object individually — slow | `COPY` command or `executemany` |
| Database-specific features (PostgreSQL arrays, JSONB) | ORM abstracts these away | Core with database-specific types |
| Read-heavy analytics | ORM's change tracking adds overhead | `pandas.read_sql()` or DuckDB |

### The Pragmatic Approach

Most production systems use a mix:
*   **ORM** for CRUD operations (create user, update profile, delete record)
*   **Core/Raw SQL** for analytics, reports, and complex queries
*   **pandas** for data analysis and exploration

SQLAlchemy supports this naturally — you can use ORM and Core side by side with the same engine and connection pool.

</details>

---

## 9. FAQ / Industry Reality

### "Should I always use an ORM?"

**Answer:** No. ORMs shine for CRUD-heavy applications (web apps, APIs) where you're creating, reading, updating, and deleting individual records. For analytical workloads (what Data Scientists do most), raw SQL or SQLAlchemy Core is often better. The key insight is knowing both and choosing the right tool for each task. Many production systems use ORM for CRUD and raw SQL for reports — in the same codebase.

### "Is SQLAlchemy the only Python ORM?"

**Answer:** No, but it's the most widely used and flexible. Alternatives include Django's ORM (tightly coupled to the Django web framework), Peewee (simpler, less powerful), and SQLModel (built on SQLAlchemy + Pydantic, popular with FastAPI). SQLAlchemy's two-layer design (Core + ORM) makes it unique — you get an ORM *and* a SQL toolkit in one package.

### "What about MongoDB — does it have an ORM?"

**Answer:** MongoDB uses **ODMs** (Object-Document Mappers) instead of ORMs. The most popular is **MongoEngine**, which maps Python classes to MongoDB collections. The concept is the same — define a class, the ODM handles the database operations — but the underlying storage is documents, not tables. You could also build a DAO pattern on top of `pymongo` (which is essentially what you've been doing in Weeks 9–10).

---

## 10. Summary & Next Steps

**Key takeaways:**

*   The **DAO pattern** provides one class per table with standard CRUD methods — it encapsulates SQL behind a clean interface
*   The **Repository pattern** operates at the domain level, aggregating data from multiple tables into rich objects
*   An **ORM** eliminates manual SQL and row mapping by defining table-to-class mappings — you work with Python objects, the ORM generates SQL
*   **SQLAlchemy** has two layers: Core (engine + SQL toolkit) and ORM (class mapping + sessions)
*   The **Session** is the unit-of-work manager — it tracks object changes and flushes them on `commit()`
*   In practice, use ORM for CRUD and Core/raw SQL for analytics — most production systems combine both

*   **Next:** Go to the Practical Lab [w12_l24_lab_dao_orm_sqlalchemy.md](w12_l24_lab_dao_orm_sqlalchemy.md) to implement ORM models, compare raw SQL vs. ORM side by side, and build a complete DAO using SQLAlchemy.

---

## 11. Further Reading

### Documentation
*   [SQLAlchemy ORM Tutorial (2.0 Style)](https://docs.sqlalchemy.org/en/20/tutorial/) — Official tutorial covering both Core and ORM in SQLAlchemy 2.0
*   [SQLAlchemy ORM Quick Start](https://docs.sqlalchemy.org/en/20/orm/quickstart.html) — Minimal working example of declarative models, sessions, and queries

### Articles & Tutorials
*   [Full Stack Python: Object-Relational Mappers](https://www.fullstackpython.com/object-relational-mappers-orms.html) — Overview of Python ORMs with comparisons and trade-offs
*   [Martin Fowler: Repository Pattern](https://martinfowler.com/eaaCatalog/repository.html) — Original pattern description from *Patterns of Enterprise Application Architecture*
