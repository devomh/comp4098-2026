---
title: "Lab: DAO & ORM with SQLAlchemy"
week: 12
type: lab
tags: [dao, orm, sqlalchemy, design-patterns, python]
difficulty: intermediate
duration: "40 mins"
---

# Lab: DAO & ORM with SQLAlchemy

## 1. Prerequisites & Setup

**Before starting this lab, you should:**
*   Review [w12_l24_concept_dao_orm.md](w12_l24_concept_dao_orm.md) for DAO, Repository, and ORM concepts
*   Complete [w12_l23_lab_dal_connectivity.md](w12_l23_lab_dal_connectivity.md) for connection pooling fundamentals

**What you'll accomplish:**
In this lab, you'll define SQLAlchemy ORM models, perform CRUD operations through the ORM, build a DAO class using ORM models, and compare raw SQL vs. ORM approaches side by side.

---

### Step 1: Install PostgreSQL and Start the Server

```python
%%bash
# Install PostgreSQL 15
apt-get update -qq 2>/dev/null
apt-get install -y -qq postgresql postgresql-client > /dev/null
service postgresql start

# Create database and user
sudo -u postgres psql -c "CREATE USER student WITH PASSWORD 'lab_pass';"
sudo -u postgres psql -c "CREATE DATABASE university_db OWNER student;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE university_db TO student;"
echo "PostgreSQL ready"
```

<details>
<summary>Expected Output</summary>

~~~text
PostgreSQL ready
~~~

</details>

### Step 2: Install Python Packages

```python
# Setup: Run this cell first (required for Colab)
!pip install -q sqlalchemy psycopg2-binary pandas

import pandas as pd
import psycopg2
from sqlalchemy import (
    create_engine, text, String, Numeric,
    ForeignKey, select, func
)
from sqlalchemy.orm import (
    DeclarativeBase, Mapped, mapped_column,
    Session, relationship, joinedload
)

pd.set_option('display.max_columns', None)

DB_URL = "postgresql://student:lab_pass@localhost:5432/university_db"
engine = create_engine(DB_URL, pool_size=5, echo=False)

print("Packages imported, engine created")
```

<details>
<summary>Expected Output</summary>

~~~text
Packages imported, engine created
~~~

</details>

---

## 2. Defining ORM Models

### The Base Class

Every ORM model inherits from a declarative base class. In SQLAlchemy 2.0, you create this by subclassing `DeclarativeBase`:

```python
class Base(DeclarativeBase):
    pass

print(f"Base class ready: {Base.__name__}")
```

<details>
<summary>Expected Output</summary>

~~~text
Base class ready: Base
~~~

</details>

### Student Model

```python
class Student(Base):
    __tablename__ = "students"

    student_id: Mapped[int] = mapped_column(primary_key=True)
    name:       Mapped[str] = mapped_column(String(100))
    major:      Mapped[str | None] = mapped_column(String(50))
    gpa:        Mapped[float | None] = mapped_column(Numeric(3, 2))
    email:      Mapped[str | None] = mapped_column(String(100), unique=True)

    # Relationship: a student has many enrollments
    enrollments: Mapped[list["Enrollment"]] = relationship(back_populates="student")

    def __repr__(self):
        return f"Student(id={self.student_id}, name='{self.name}', gpa={self.gpa})"

print("Student model defined")
print(f"  Table: {Student.__tablename__}")
print(f"  Columns: {[c.name for c in Student.__table__.columns]}")
```

<details>
<summary>Expected Output</summary>

~~~text
Student model defined
  Table: students
  Columns: ['student_id', 'name', 'major', 'gpa', 'email']
~~~

</details>

### Course Model

```python
class Course(Base):
    __tablename__ = "courses"

    course_id: Mapped[int] = mapped_column(primary_key=True)
    code:      Mapped[str] = mapped_column(String(10), unique=True)
    title:     Mapped[str] = mapped_column(String(100))
    credits:   Mapped[int | None] = mapped_column()

    # Relationship: a course has many enrollments
    enrollments: Mapped[list["Enrollment"]] = relationship(back_populates="course")

    def __repr__(self):
        return f"Course(id={self.course_id}, code='{self.code}')"

print("Course model defined")
```

### Enrollment Model (Association Table)

```python
class Enrollment(Base):
    __tablename__ = "enrollments"

    enrollment_id: Mapped[int] = mapped_column(primary_key=True)
    student_id:    Mapped[int] = mapped_column(ForeignKey("students.student_id"))
    course_id:     Mapped[int] = mapped_column(ForeignKey("courses.course_id"))
    semester:      Mapped[str | None] = mapped_column(String(20))
    grade:         Mapped[str | None] = mapped_column(String(2))

    # Relationships back to Student and Course
    student: Mapped["Student"] = relationship(back_populates="enrollments")
    course:  Mapped["Course"]  = relationship(back_populates="enrollments")

    def __repr__(self):
        return f"Enrollment(student={self.student_id}, course={self.course_id}, grade='{self.grade}')"

print("Enrollment model defined")
```

### Create Tables from Models

```python
# Drop and recreate all tables defined by our models
Base.metadata.drop_all(engine)
Base.metadata.create_all(engine)
print("Tables created from ORM models:")
for table_name in Base.metadata.tables:
    print(f"  - {table_name}")
```

<details>
<summary>Expected Output</summary>

~~~text
Tables created from ORM models:
  - students
  - courses
  - enrollments
~~~

</details>

---

## 3. CRUD with the ORM

### Create: Inserting Records

```python
with Session(engine) as session:
    # Create student objects
    ana = Student(name="Ana Torres", major="Data Science", gpa=3.8, email="ana.torres@upr.edu")
    luis = Student(name="Luis Rivera", major="Data Science", gpa=3.5, email="luis.rivera@upr.edu")
    maria = Student(name="Maria Santos", major="Computer Science", gpa=3.9, email="maria.santos@upr.edu")
    carlos = Student(name="Carlos Diaz", major="Mathematics", gpa=3.2, email="carlos.diaz@upr.edu")
    sofia = Student(name="Sofia Mendez", major="Data Science", gpa=3.7, email="sofia.mendez@upr.edu")

    # Add to session (staged, not yet in DB)
    session.add_all([ana, luis, maria, carlos, sofia])
    print(f"Before commit — Ana's ID: {ana.student_id}")  # None!

    # Commit — flushes to database
    session.commit()
    print(f"After commit — Ana's ID: {ana.student_id}")   # Auto-assigned!
    count = session.scalar(select(func.count()).select_from(Student))
    print(f"Inserted {count} students")
```

<details>
<summary>Expected Output</summary>

~~~text
Before commit — Ana's ID: None
After commit — Ana's ID: 1
Inserted 5 students
~~~

</details>

Notice that `student_id` was `None` before commit — the ORM doesn't assign IDs until the database generates them via `SERIAL`. After `commit()`, the ORM reads the generated ID back into the object.

### Seed Courses and Enrollments

```python
with Session(engine) as session:
    # Courses
    comp4098 = Course(code="COMP4098", title="Data Management & Architectures", credits=3)
    comp4050 = Course(code="COMP4050", title="Machine Learning", credits=3)
    stat3001 = Course(code="STAT3001", title="Statistical Methods", credits=4)
    comp3020 = Course(code="COMP3020", title="Algorithms", credits=3)
    session.add_all([comp4098, comp4050, stat3001, comp3020])
    session.flush()  # Flush to get course_ids without committing

    # Enrollments (using the IDs assigned by flush)
    enrollments = [
        Enrollment(student_id=1, course_id=comp4098.course_id, semester="2026-01", grade="A"),
        Enrollment(student_id=1, course_id=comp4050.course_id, semester="2026-01", grade="A"),
        Enrollment(student_id=2, course_id=comp4098.course_id, semester="2026-01", grade="B"),
        Enrollment(student_id=2, course_id=stat3001.course_id, semester="2026-01", grade="A"),
        Enrollment(student_id=3, course_id=comp4098.course_id, semester="2026-01", grade="A"),
        Enrollment(student_id=3, course_id=comp4050.course_id, semester="2026-01", grade="A"),
        Enrollment(student_id=3, course_id=comp3020.course_id, semester="2026-01", grade="B"),
        Enrollment(student_id=4, course_id=stat3001.course_id, semester="2026-01", grade="C"),
        Enrollment(student_id=4, course_id=comp3020.course_id, semester="2026-01", grade="B"),
        Enrollment(student_id=5, course_id=comp4098.course_id, semester="2026-01", grade="A"),
        Enrollment(student_id=5, course_id=comp4050.course_id, semester="2026-01", grade="B"),
    ]
    session.add_all(enrollments)
    session.commit()

    n_courses = session.scalar(select(func.count()).select_from(Course))
    n_enrolls = session.scalar(select(func.count()).select_from(Enrollment))
    print(f"Seeded {n_courses} courses")
    print(f"Seeded {n_enrolls} enrollments")
```

<details>
<summary>Expected Output</summary>

~~~text
Seeded 4 courses
Seeded 11 enrollments
~~~

</details>

### Read: Querying with the ORM

```python
with Session(engine) as session:
    # Get all students — select() + scalars() is the 2.0-native form
    print("=== All Students ===")
    students = session.scalars(select(Student).order_by(Student.name)).all()
    for s in students:
        print(f"  {s.name:20s} | {s.major:20s} | GPA: {s.gpa}")

    # Filter: Data Science students with GPA > 3.5
    print("\n=== Data Science, GPA > 3.5 ===")
    stmt = (select(Student)
            .where(Student.major == "Data Science")
            .where(Student.gpa > 3.5)
            .order_by(Student.gpa.desc()))
    ds_students = session.scalars(stmt).all()
    for s in ds_students:
        print(f"  {s.name:20s} GPA: {s.gpa}")

    # Get one student by primary key (session.get is unchanged in 2.0)
    print("\n=== Student #3 ===")
    student = session.get(Student, 3)
    print(f"  {student}")
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

=== Data Science, GPA > 3.5 ===
  Ana Torres           GPA: 3.80
  Sofia Mendez         GPA: 3.70

=== Student #3 ===
  Student(id=3, name='Maria Santos', gpa=3.90)
~~~

</details>

### Navigating Relationships

This is where the ORM truly shines — following foreign keys becomes attribute access:

```python
with Session(engine) as session:
    # Load Ana with her enrollments eagerly (avoids N+1 problem)
    stmt = (select(Student)
            .options(joinedload(Student.enrollments).joinedload(Enrollment.course))
            .where(Student.name == "Ana Torres"))
    ana = session.scalars(stmt).unique().first()

    print(f"Student: {ana.name}")
    print(f"Enrollments:")
    for e in ana.enrollments:
        print(f"  {e.course.code} — {e.course.title} (Grade: {e.grade})")
```

<details>
<summary>Expected Output</summary>

~~~text
Student: Ana Torres
Enrollments:
  COMP4098 — Data Management & Architectures (Grade: A)
  COMP4050 — Machine Learning (Grade: A)
~~~

</details>

Compare this to the raw SQL approach where you'd write a JOIN query, iterate over rows, and manually construct the relationship. With the ORM, `ana.enrollments` navigates the foreign key automatically, and `e.course` follows the second foreign key to get the course details.

### Update: Modifying Records

```python
with Session(engine) as session:
    # Find Carlos and update his GPA
    carlos = session.scalars(
        select(Student).where(Student.name == "Carlos Diaz")
    ).first()
    print(f"Before: {carlos.name} GPA = {carlos.gpa}")

    carlos.gpa = 3.4  # Just modify the attribute!
    session.commit()   # ORM generates: UPDATE students SET gpa = 3.4 WHERE student_id = 4

    print(f"After:  {carlos.name} GPA = {carlos.gpa}")
```

<details>
<summary>Expected Output</summary>

~~~text
Before: Carlos Diaz GPA = 3.20
After:  Carlos Diaz GPA = 3.40
~~~

</details>

No SQL needed — the Session detects that `carlos.gpa` changed and generates the `UPDATE` statement on `commit()`.

### Delete: Removing Records

```python
with Session(engine) as session:
    # Delete Carlos's enrollment in COMP3020
    stmt = (select(Enrollment)
            .join(Course, Enrollment.course_id == Course.course_id)
            .where(Enrollment.student_id == 4, Course.code == "COMP3020"))
    enrollment = session.scalars(stmt).first()

    if enrollment:
        session.delete(enrollment)
        session.commit()
        print(f"Deleted enrollment: {enrollment}")

    remaining = session.scalar(
        select(func.count()).select_from(Enrollment).where(Enrollment.student_id == 4)
    )
    print(f"Carlos's remaining enrollments: {remaining}")
```

<details>
<summary>Expected Output</summary>

~~~text
Deleted enrollment: Enrollment(student=4, course=4, grade='B')
Carlos's remaining enrollments: 1
~~~

</details>

---

## 4. Side-by-Side: Raw SQL vs. SQLAlchemy Core vs. ORM

Let's solve the same analytical question three ways: *"For each course, show the number of enrolled students and the average GPA of those students."*

The three approaches map to the **three levels of abstraction** introduced in the L24 concept: raw driver calls (psycopg2), SQL strings managed by SQLAlchemy Core (`text()` on an `Engine`), and ORM queries built from model classes.

### Approach 1: Raw psycopg2 (Level 0 — the driver itself)

```python
conn = psycopg2.connect(
    host="localhost", port=5432,
    dbname="university_db", user="student", password="lab_pass"
)
cur = conn.cursor()
cur.execute("""
    SELECT c.code, c.title,
           COUNT(e.enrollment_id) AS student_count,
           ROUND(AVG(s.gpa), 2) AS avg_gpa
    FROM courses c
    JOIN enrollments e ON c.course_id = e.course_id
    JOIN students s ON e.student_id = s.student_id
    GROUP BY c.code, c.title
    ORDER BY student_count DESC
""")
rows = cur.fetchall()
cur.close()
conn.close()

print("=== Raw psycopg2 Result ===")
print(f"{'Code':<10} {'Title':<35} {'Students':>8} {'Avg GPA':>8}")
print("-" * 63)
for row in rows:
    code, title, student_count, avg_gpa = row   # positional — fragile!
    print(f"{code:<10} {title:<35} {student_count:>8} {avg_gpa:>8}")
```

<details>
<summary>Expected Output</summary>

~~~text
=== Raw psycopg2 Result ===
Code       Title                               Students  Avg GPA
---------------------------------------------------------------
COMP4098   Data Management & Architectures            4     3.73
COMP4050   Machine Learning                           3     3.80
STAT3001   Statistical Methods                        2     3.35
COMP3020   Algorithms                                 1     3.90
~~~

</details>

Manual connection open/close, tuple-positional access, no pool — this is what every layer above exists to replace.

### Approach 2: SQLAlchemy Core (Level 1 — `text()` on a pooled `Engine`)

```python
with engine.connect() as conn:
    result = conn.execute(text("""
        SELECT c.code, c.title,
               COUNT(e.enrollment_id) AS student_count,
               ROUND(AVG(s.gpa), 2) AS avg_gpa
        FROM courses c
        JOIN enrollments e ON c.course_id = e.course_id
        JOIN students s ON e.student_id = s.student_id
        GROUP BY c.code, c.title
        ORDER BY student_count DESC
    """))

    print("=== SQLAlchemy Core Result ===")
    print(f"{'Code':<10} {'Title':<35} {'Students':>8} {'Avg GPA':>8}")
    print("-" * 63)
    for row in result:
        print(f"{row.code:<10} {row.title:<35} {row.student_count:>8} {row.avg_gpa:>8}")
```

<details>
<summary>Expected Output</summary>

~~~text
=== SQLAlchemy Core Result ===
Code       Title                               Students  Avg GPA
---------------------------------------------------------------
COMP4098   Data Management & Architectures            4     3.73
COMP4050   Machine Learning                           3     3.80
STAT3001   Statistical Methods                        2     3.35
COMP3020   Algorithms                                 1     3.90
~~~

</details>

Same SQL string as Approach 1, but the Engine handles pooling and the context manager handles cleanup. Rows expose column names as attributes instead of tuple indices.

### Approach 3: SQLAlchemy ORM (Level 2 — `select()` built from model classes)

```python
with Session(engine) as session:
    stmt = (select(
                Course.code,
                Course.title,
                func.count(Enrollment.enrollment_id).label("student_count"),
                func.round(func.avg(Student.gpa), 2).label("avg_gpa"),
            )
            .join(Enrollment, Course.course_id == Enrollment.course_id)
            .join(Student, Enrollment.student_id == Student.student_id)
            .group_by(Course.code, Course.title)
            .order_by(func.count(Enrollment.enrollment_id).desc()))
    results = session.execute(stmt).all()

    print("=== SQLAlchemy ORM Result ===")
    print(f"{'Code':<10} {'Title':<35} {'Students':>8} {'Avg GPA':>8}")
    print("-" * 63)
    for row in results:
        print(f"{row.code:<10} {row.title:<35} {row.student_count:>8} {row.avg_gpa:>8}")
```

<details>
<summary>Expected Output</summary>

~~~text
=== SQLAlchemy ORM Result ===
Code       Title                               Students  Avg GPA
---------------------------------------------------------------
COMP4098   Data Management & Architectures            4     3.73
COMP4050   Machine Learning                           3     3.80
STAT3001   Statistical Methods                        2     3.35
COMP3020   Algorithms                                 1     3.90
~~~

</details>

**Observation:** For this analytical query, the raw SQL is arguably the most readable. This illustrates the trade-off: ORMs excel at CRUD and relationship navigation, but complex analytics are often clearer as SQL strings. Production systems commonly mix all three — ORM for CRUD, Core for hand-tuned SQL, and `pandas.read_sql()` for exploration — sharing the same Engine and connection pool.

---

## 5. Building a DAO with ORM Models

Here's a DAO that uses ORM models instead of raw SQL — combining the clean interface of DAOs with the object mapping of the ORM.

```python
class StudentDAO:
    """Data Access Object for Student operations using SQLAlchemy ORM."""

    def __init__(self, engine):
        self.engine = engine

    def find_by_id(self, student_id):
        with Session(self.engine) as session:
            return session.get(Student, student_id)

    def find_all(self):
        with Session(self.engine) as session:
            return session.scalars(
                select(Student).order_by(Student.name)
            ).all()

    def find_by_major(self, major):
        with Session(self.engine) as session:
            stmt = (select(Student)
                    .where(Student.major == major)
                    .order_by(Student.gpa.desc()))
            return session.scalars(stmt).all()

    def create(self, name, major, gpa, email):
        with Session(self.engine) as session:
            student = Student(name=name, major=major, gpa=gpa, email=email)
            session.add(student)
            session.commit()
            session.refresh(student)  # Load the generated ID
            return student

    def update_gpa(self, student_id, new_gpa):
        with Session(self.engine) as session:
            student = session.get(Student, student_id)
            if student:
                student.gpa = new_gpa
                session.commit()
                return True
            return False

    def delete(self, student_id):
        with Session(self.engine) as session:
            student = session.get(Student, student_id)
            if student:
                session.delete(student)
                session.commit()
                return True
            return False

print("StudentDAO defined")
```

### Using the DAO

```python
dao = StudentDAO(engine)

# Find all students
print("=== All Students (via DAO) ===")
for s in dao.find_all():
    print(f"  {s}")

# Find by major
print("\n=== Data Science Students ===")
for s in dao.find_by_major("Data Science"):
    print(f"  {s.name} — GPA: {s.gpa}")

# Create a new student
print("\n=== Create New Student ===")
new_student = dao.create("Pedro Ruiz", "Data Science", 3.6, "pedro.ruiz@upr.edu")
print(f"  Created: {new_student}")

# Update GPA
print("\n=== Update GPA ===")
dao.update_gpa(new_student.student_id, 3.8)
updated = dao.find_by_id(new_student.student_id)
print(f"  Updated: {updated}")

# Delete
print("\n=== Delete Student ===")
dao.delete(new_student.student_id)
print(f"  Total students after delete: {len(dao.find_all())}")
```

<details>
<summary>Expected Output</summary>

~~~text
=== All Students (via DAO) ===
  Student(id=1, name='Ana Torres', gpa=3.80)
  Student(id=4, name='Carlos Diaz', gpa=3.40)
  Student(id=2, name='Luis Rivera', gpa=3.50)
  Student(id=3, name='Maria Santos', gpa=3.90)
  Student(id=5, name='Sofia Mendez', gpa=3.70)

=== Data Science Students ===
  Ana Torres — GPA: 3.80
  Sofia Mendez — GPA: 3.70
  Luis Rivera — GPA: 3.50

=== Create New Student ===
  Created: Student(id=6, name='Pedro Ruiz', gpa=3.60)

=== Update GPA ===
  Updated: Student(id=6, name='Pedro Ruiz', gpa=3.80)

=== Delete Student ===
  Total students after delete: 5
~~~

</details>

---

## 6. ORM Models to DataFrames

For Data Scientists, the ORM integrates smoothly with pandas:

```python
with Session(engine) as session:
    # Query students and convert to DataFrame
    students = session.scalars(select(Student)).all()
    df = pd.DataFrame([
        {"name": s.name, "major": s.major, "gpa": float(s.gpa)}
        for s in students
    ])

    print("=== Students DataFrame ===")
    print(df.to_string(index=False))
    print(f"\nAverage GPA by major:")
    print(df.groupby("major")["gpa"].mean().round(2).to_string())
```

<details>
<summary>Expected Output</summary>

~~~text
=== Students DataFrame ===
          name              major   gpa
    Ana Torres       Data Science  3.80
   Carlos Diaz      Mathematics  3.40
   Luis Rivera       Data Science  3.50
  Maria Santos  Computer Science  3.90
  Sofia Mendez       Data Science  3.70

Average GPA by major:
major
Computer Science    3.90
Data Science        3.67
Mathematics         3.40
~~~

</details>

You can also use `pandas.read_sql()` directly with the engine for read-heavy analytics — bypassing the ORM entirely when you just need a DataFrame:

```python
# Direct SQL → DataFrame (no ORM needed)
df = pd.read_sql("""
    SELECT s.name, c.code, e.grade
    FROM students s
    JOIN enrollments e ON s.student_id = e.student_id
    JOIN courses c ON e.course_id = c.course_id
    ORDER BY s.name, c.code
""", engine)

print("=== Enrollment Report (via pandas.read_sql) ===")
print(df.to_string(index=False))
```

<details>
<summary>Expected Output</summary>

~~~text
=== Enrollment Report (via pandas.read_sql) ===
          name      code grade
    Ana Torres  COMP4050     A
    Ana Torres  COMP4098     A
   Carlos Diaz  STAT3001     C
   Luis Rivera  COMP4098     B
   Luis Rivera  STAT3001     A
  Maria Santos  COMP3020     B
  Maria Santos  COMP4050     A
  Maria Santos  COMP4098     A
  Sofia Mendez  COMP4050     B
  Sofia Mendez  COMP4098     A
~~~

</details>

---

## 7. Your Turn! (Exercises)

### Exercise 1: Course DAO

**Task:** Build a `CourseDAO` class with ORM models, following the same pattern as `StudentDAO`.

```python
# TODO: Implement CourseDAO with these methods:
#
# 1. find_by_id(course_id) — return a Course by primary key
# 2. find_by_code(code) — return a Course by its code (e.g., "COMP4098")
# 3. find_all() — return all courses ordered by code
# 4. create(code, title, credits) — insert a new course and return it
# 5. get_roster(course_code) — return all students enrolled in a course
#    Hint: query Student, join Enrollment, join Course, filter by code
#
# Test your DAO:
# course_dao = CourseDAO(engine)
# print(course_dao.find_all())
# print(course_dao.find_by_code("COMP4098"))
# print(course_dao.get_roster("COMP4098"))
```

<details>
<summary>Expected Output</summary>

~~~text
All courses:
  Course(id=4, code='COMP3020')
  Course(id=2, code='COMP4050')
  Course(id=1, code='COMP4098')
  Course(id=3, code='STAT3001')

COMP4098:
  Course(id=1, code='COMP4098')

COMP4098 roster:
  Ana Torres (Grade: A)
  Luis Rivera (Grade: B)
  Maria Santos (Grade: A)
  Sofia Mendez (Grade: A)
~~~

</details>

### Exercise 2: ORM vs. Raw SQL Comparison

**Task:** Answer the question *"Which students have a GPA above the average?"* using both approaches.

```python
# TODO: Implement this query TWO ways:
#
# Approach 1 — SQLAlchemy Core with engine.connect() and text()
# Hint: Use a subquery: WHERE gpa > (SELECT AVG(gpa) FROM students)
#
# Approach 2 — SQLAlchemy ORM (2.0 style) with select() and session.scalars()
# Hint: build a scalar subquery with func.avg, then use it in .where()
#       avg_sub = select(func.avg(Student.gpa)).scalar_subquery()
#       stmt = select(Student).where(Student.gpa > avg_sub).order_by(Student.name)
#       above_avg = session.scalars(stmt).all()
#
# Print results from both and verify they match.
```

<details>
<summary>Expected Output</summary>

~~~text
Average GPA: 3.56

=== Raw SQL: Above Average ===
  Ana Torres           GPA: 3.80
  Maria Santos         GPA: 3.90
  Sofia Mendez         GPA: 3.70

=== ORM: Above Average ===
  Ana Torres           GPA: 3.80
  Maria Santos         GPA: 3.90
  Sofia Mendez         GPA: 3.70
~~~

</details>

### Exercise 3: Enrollment Service (Repository Pattern)

**Task:** Build an `EnrollmentService` that combines data from multiple tables — a step toward the Repository pattern.

```python
# TODO: Implement EnrollmentService with these methods:
#
# 1. enroll_student(student_id, course_code, semester)
#    - Look up the course by code
#    - Create an Enrollment linking the student and course
#    - Return the created Enrollment
#
# 2. get_transcript(student_id)
#    - Return a list of dicts: {"code": ..., "title": ..., "credits": ..., "grade": ...}
#    - Include all courses the student is enrolled in
#
# 3. get_course_stats()
#    - Return a list of dicts: {"code": ..., "title": ..., "enrolled": ..., "avg_gpa": ...}
#    - "avg_gpa" is the average GPA of enrolled students (not the course grade)
#
# Test:
# svc = EnrollmentService(engine)
# svc.enroll_student(4, "COMP4098", "2026-01")  # Enroll Carlos in COMP4098
# print(svc.get_transcript(4))
# print(svc.get_course_stats())
```

<details>
<summary>Expected Output</summary>

~~~text
Enrolled student 4 in COMP4098

Transcript for student 4 (Carlos Diaz):
  COMP4098 — Data Management & Architectures (3 cr) — Grade: None
  STAT3001 — Statistical Methods (4 cr) — Grade: C

Course stats:
  COMP4098: 5 students, avg GPA 3.66
  COMP4050: 3 students, avg GPA 3.80
  STAT3001: 2 students, avg GPA 3.45
  COMP3020: 1 students, avg GPA 3.90
~~~

(Note: state reflects §3's `UPDATE carlos.gpa = 3.4` and deletion of Carlos's COMP3020 enrollment. Maria remains enrolled in COMP3020 from the original seed, which is why COMP3020 has 1 student, not 0.)

</details>

---

## 8. Summary

In this lab, you:
*   **Defined** SQLAlchemy ORM models (`Student`, `Course`, `Enrollment`) that map Python classes to database tables
*   **Performed** full CRUD operations through the ORM: `session.add()`, `session.query()`, attribute modification + `commit()`, `session.delete()`
*   **Navigated** relationships using `relationship()` — accessing `student.enrollments` and `enrollment.course` without writing JOINs
*   **Compared** raw SQL vs. ORM for the same analytical query and observed the trade-offs
*   **Built** a `StudentDAO` class that combines the DAO pattern with ORM models
*   **Integrated** ORM results with pandas DataFrames for data science workflows
