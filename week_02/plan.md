# Week 2 Lesson Plan: Conceptual & Logical Modeling

## Overview
**Focus:** Transitioning from abstract requirements to concrete database structures.
**Goal:** Students will learn to model real-world systems using ER Diagrams and then translate those diagrams into relational schemas (tables), ready for implementation.

## Proposed Structure

We will adhere to the project's standard structure: 2 Lessons, each split into a **Concept** (Theory) and **Lab** (Practical) document.

### Lesson 3: Entity-Relationship (ER) Modeling

#### 1. `w02_l03_concept_er_modeling.md`
*   **Type:** Concept
*   **Source:** Syllabus Lesson 3
*   **Key Topics:**
    *   Entities (Strong vs. Weak) & Attributes (Composite, Multivalued, Derived).
    *   Relationships & Cardinality (1:1, 1:N, M:N).
    *   Chen Notation vs. Crows Foot Notation (brief mention, focus on conceptual).
*   **Analogy:** Architectural Blueprints (Logical) vs. Construction (Physical).
*   **Visuals:** Mermaid.js ER diagrams demonstrating 1:N and M:N relationships.

#### 2. `w02_l03_lab_er_diagramming.md`
*   **Type:** Lab
*   **Activity:** Design an ER diagram for a "University Course Registration System".
*   **Tools:** Mermaid.js (embedded in Markdown).
*   **Exercises:**
    *   Identify Entities (Student, Course, Professor, Department).
    *   Define Relationships (Student *enrolls in* Course, Professor *teaches* Course).
    *   Handle Cardinality constraints.
*   **Output:** A rendered Mermaid ER Diagram.

---

### Lesson 4: Logical Design (ER to Relational)

#### 3. `w02_l04_concept_logical_design.md`
*   **Type:** Concept
*   **Source:** Syllabus Lesson 4
*   **Key Topics:**
    *   The "Algorithm" for mapping ER to Tables.
    *   Mapping Strong Entities -> Tables.
    *   Mapping 1:N Relationships -> Foreign Keys.
    *   Mapping M:N Relationships -> Junction/Associative Tables.
    *   Handling Multivalued Attributes -> Separate Tables.
*   **Analogy:** Translating a blueprint into a materials list and assembly instructions.
*   **Visuals:** Side-by-side comparison of an ER snippet and its resulting Relational Schema (Table representation).

#### 4. `w02_l04_lab_schema_conversion.md`
*   **Type:** Lab
*   **Activity:** Converting the "University Course Registration" ER diagram (from Lesson 3) into Relational Schemas.
*   **Format:** Defining schemas using Markdown tables (Table Name, Column Name, Type, Key Type).
    *   *Note:* We will not use SQL DDL yet (scheduled for Week 4), but we will define the "Logical Schema".
*   **Exercises:**
    *   Create the `Student`, `Course`, and `Professor` tables.
    *   Create the `Enrollment` junction table (handling the M:N relationship).
    *   Resolve a multi-valued attribute (e.g., Student `PhoneNumbers`).

## Next Steps for Implementation
1.  Generate `w02_l03_concept_er_modeling.md` using `_templates/concept_template.md`.
2.  Generate `w02_l03_lab_er_diagramming.md` using `_templates/lab_template.md`.
3.  Generate `w02_l04_concept_logical_design.md` using `_templates/concept_template.md`.
4.  Generate `w02_l04_lab_schema_conversion.md` using `_templates/lab_template.md`.
