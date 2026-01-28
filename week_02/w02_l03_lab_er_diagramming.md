---
title: "Lab: ER Diagramming with Mermaid.js"
week: 02
type: lab
tags: [design, mermaid, er diagrams]
difficulty: intermediate
duration: "60 mins"
---

# Lab: ER Diagramming with Mermaid.js

## 1. Prerequisites & Setup
*   **Tool:** We will use **mermaid-py**, a Python package that renders Mermaid diagrams in Jupyter/Colab.
*   **Concept Review:** Ensure you have read `w02_l03_concept_er_modeling.md`.

### Environment Setup
Run this block first to install packages and initialize your environment.
```python
# Setup: Run this cell first (required for Colab)
!pip install -q mermaid-py
```

```python
from mermaid import Mermaid

print("Setup complete! Ready to create ER diagrams.")
```

### How to use mermaid-py
In a code cell, use the `Mermaid()` function with your diagram definition:
```python
Mermaid("""
erDiagram
    ENTITY1 ||--o{ ENTITY2 : label
""")
```

---

## 2. Step 1: Identifying Entities
**Scenario:** We are designing a database for a **University Course Registration System**.

**Requirements:**
1.  The university has **Students**. We need to track their `Student ID`, `Name`, and `Email`.
2.  There are **Courses** offered. Each course has a `Course Code`, `Title`, and `Credits`.
3.  **Professors** teach these courses. We track their `Employee ID` and `Name`.
4.  **Departments** manage courses and professors. A department has a `Name` and `Building Location`.

### The "Naive" Approach (The Problem)
Why not just use Excel? Imagine trying to store this in one sheet:

| Student | Course | Professor | Dept | Dept_Building |
| :--- | :--- | :--- | :--- | :--- |
| Alice | Math 101 | Dr. Smith | Math | East Wing |
| Bob | Math 101 | Dr. Smith | Math | East Wing |
| Alice | Hist 200 | Dr. Jones | History | West Wing |

*   **Issue:** "Math" and "East Wing" are repeated. If Dr. Smith moves to the Physics department, we have to update multiple rows. This is **Redundancy**.

### The "Better" Approach (Entities)
Let's decouple these into distinct Entities.

```python
Mermaid("""
erDiagram
    STUDENT {
        string student_id
        string name
        string email
        date dob
    }
    COURSE {
        string course_code
        string title
        int credits
    }
    PROFESSOR {
        string employee_id
        string name
    }
    DEPARTMENT {
        string name
        string building
    }
""")
```

---

## 3. Step 2: Defining Relationships
Now, let's connect the "Nouns" with "Verbs" based on the rules.

**Rules:**
1.  A **Department** can have many **Professors**, but a **Professor** belongs to only one **Department** (1:N).
2.  A **Professor** can teach many **Courses**, but a **Course** is taught by only one **Professor** (for simplicity) (1:N).
3.  A **Student** can enroll in many **Courses**, and a **Course** can have many **Students** (M:N).

```python
Mermaid("""
erDiagram
    DEPARTMENT ||--|{ PROFESSOR : employs
    PROFESSOR ||--o{ COURSE : teaches
    STUDENT }|--|{ COURSE : enrolls_in
""")
```

### Combining it all
Now we have a high-level view of our system.

---

## 4. Your Turn! (Exercises)
Now it's your turn to refine this model.

### Exercise 1: Attributes & Keys
**Task:** Copy the entities above. Add the correct **PK** (Primary Key) label to the unique identifiers.
**Hint:** in Mermaid, write `type name PK`.

```python
# TODO: Add PKs to Student, Course, Professor, Department
Mermaid("""
erDiagram
    STUDENT {
        string student_id
        string name
        string email
        date dob
    }
""")
```

<details>
<summary>Expected Output</summary>

~~~python
Mermaid("""
erDiagram
    STUDENT {
        string student_id PK
        string name
        string email
        date dob
    }
    COURSE {
        string course_code PK
        string title
        int credits
    }
    PROFESSOR {
        string employee_id PK
        string name
    }
    DEPARTMENT {
        string name PK
        string building
    }
""")
~~~
</details>

### Exercise 2: The "Phone Number" Problem
**Task:** A Student can have *multiple* phone numbers (Mobile, Home, Emergency).
**Question:** How do we model this?
1.  Add `phone1`, `phone2` to the Student entity? (Bad design - what if they have 3?)
2.  Create a new Entity `PHONE_NUMBER`?

**Action:** Create a `PHONE_NUMBER` entity.
*   It should have an `id` and a `number`.
*   Link it to `STUDENT` with the correct cardinality (One Student has Many Phones).

```python
# TODO: Create PHONE_NUMBER entity
# TODO: Link STUDENT ||--o{ PHONE_NUMBER : has
Mermaid("""
erDiagram
    STUDENT {
        string student_id PK
        string name
        string email
        date dob
    }
""")
```

<details>
<summary>Expected Output</summary>

~~~python
Mermaid("""
erDiagram
    STUDENT {
        string student_id PK
        string name
        string email
        date dob
    }
    PHONE_NUMBER {
        int id PK
        string number
        string type
    }
    STUDENT ||--o{ PHONE_NUMBER : has
""")
~~~
</details>

### Exercise 3: The "Waitlist" Constraint
**Task:** We need to track *when* a student enrolled.
**Insight:** An M:N relationship (`enrolls_in`) cannot hold attributes itself in a simple line. We usually describe this attribute on the relationship.
**Action:** In the next lesson, we will turn this relationship into a table. For now, just note that the *relationship itself* needs an attribute: `enrollment_date`.

<details>
<summary>Expected Insight</summary>

The M:N relationship between `STUDENT` and `COURSE` will become a **Junction Table** called `ENROLLMENT` in the next lesson. This table will contain:
- `student_id` (FK)
- `course_code` (FK)
- `enrollment_date` (the relationship attribute)

This pattern is fundamental to relational database design.
</details>

---

## 5. Complete ERD: University Course Registration System

Here is the complete ER Diagram combining all entities and relationships:

```python
Mermaid("""
erDiagram
    DEPARTMENT {
        string dept_id PK
        string name
        string building
    }
    PROFESSOR {
        string employee_id PK
        string name
    }
    COURSE {
        string course_code PK
        string title
        int credits
    }
    STUDENT {
        string student_id PK
        string name
        string email
        date dob
    }
    PHONE_NUMBER {
        int id PK
        string number
        string type
    }

    DEPARTMENT ||--|{ PROFESSOR : employs
    PROFESSOR ||--o{ COURSE : teaches
    STUDENT }|--|{ COURSE : enrolls_in
    STUDENT ||--o{ PHONE_NUMBER : has
""")
```

---

## 6. Summary
You have successfully:
1.  Parsed text requirements into **Entities**.
2.  Defined **Relationships** (1:N, M:N).
3.  Modeled a complex attribute (Multivalued Phone Number) by creating a new Entity.