# Lesson Design Guidelines & Workflow

## 1. Core Philosophy
The course materials are treated as **software artifacts**. They must be modular, version-controllable, and convertible. We separate the *theory* (Conceptual) from the *application* (Practical) to allow students to focus on one mode of learning at a time while maintaining tight integration between the two.

## 2. Document Types

### A. Conceptual Document (`*_concept.md`)
*   **Goal:** Build mental models, explain architectural decisions, and provide deep context.
*   **Tone:** Explanatory, visual, and academic but accessible.
*   **Key Elements:**
    *   **Learning Objectives:** Clear bullet points at the top.
    *   **Analogies:** Use non-technical analogies for abstract concepts (e.g., "Vector Store as a Library Index").
    *   **Visuals:** Heavy use of **Mermaid.js** for architecture, ER diagrams, and flowcharts.
    *   **"Why this matters":** Every major section should explain the industry relevance.
    *   **FAQ / Industry Reality:** Address common "Student vs. Professional" misconceptions (e.g., "Pandas vs. SQL").
    *   **Links:** Direct references to the corresponding Practical document (e.g., "See this implemented in Lab 1.2").
    *   **Further Reading:** Curated links to external resources for self-study (see Depth Considerations below).

#### Depth Considerations
Concept files should balance in-class coverage with opportunities for deeper self-study. Content is categorized as:

| Content Type | Purpose | Format |
| :--- | :--- | :--- |
| **Core Content** | Must be understood in class. Covers the "what" and "why." | Regular sections |
| **Deep Dive** | Extended explanations, mathematical foundations, or edge cases for advanced topics. Optional reading. | Collapsible `<details>` block with clear "Deep Dive" label |
| **Further Reading** | External resources for self-study after class. | Dedicated section at end of document |

**When to include a Deep Dive:**
*   Topics with mathematical or theoretical foundations (e.g., normalization proofs, set theory, B-tree complexity)
*   Edge cases and exceptions that are important but not essential for basic understanding
*   Historical context or alternative approaches

**Further Reading sources (in order of preference):**
1.  **Textbook:** *Database Design - 2nd Edition* by Adrienne Watt (suggested course textbook)
2.  **Official Documentation:** PostgreSQL docs, Python docs, library references
3.  **Quality Articles:** Well-written blog posts, tutorials, or conference talks

*Note:* Always provide at least 2-3 Further Reading links per concept file.

**Module-Specific Reading:**
The course textbook covers Modules 1-2 (Relational Foundations, Analytical SQL). For later modules, prioritize official documentation and quality articles:

| Module | Primary Reading Sources |
| :--- | :--- |
| Module 1-2 (Relational, SQL) | Textbook + PostgreSQL/DuckDB docs |
| Module 3 (NoSQL) | MongoDB University, Redis docs |
| Module 4 (Data Access) | SQLAlchemy docs, ORM tutorials |
| Module 5 (Vector DBs, RAG) | ChromaDB/LanceDB docs, LangChain tutorials |

### B. Practical Document (`*_lab.md`)
*   **Goal:** Build muscle memory, demonstrate syntax, and solve concrete problems.
*   **Tone:** Instructional, imperative, and streamlined.
*   **Execution Environment:** Labs are written in Markdown and converted to **Google Colab notebooks** via `jupytext`. Since Colab environments are ephemeral, each lab must be self-contained.
*   **Key Elements:**
    *   **Prerequisites:** Explicit list of required libraries or previous labs.
    *   **Setup Block:** A dedicated **first code cell** that:
        1.  Installs required packages (`!pip install -q ...`)
        2.  Imports libraries
        3.  Establishes database connections (if applicable)

        *Note:* For Mermaid diagrams in labs, use the `mermaid-py` package.
    *   **Iterative Code:** Start simple, then refactor. Show "Bad vs. Good" patterns (e.g., looping vs. vectorization).
    *   **"Your Turn":** Small, unguided exercises sprinkled throughout (marked as `# TODO`).
    *   **Output:** Expected output samples (tables, JSON) in **collapsible `<details>` blocks**, so students can verify correctness without spoilers.

#### Setup Block Template
```python
# Setup: Run this cell first
!pip install -q sqlalchemy psycopg2-binary pandas mermaid-py

import pandas as pd
from sqlalchemy import create_engine
from mermaid import Mermaid

# Database connection (adjust for your environment)
DB_URL = "postgresql://user:pass@host:5432/dbname"
engine = create_engine(DB_URL)
%load_ext sql
%sql engine
```

#### Expected Output Template
```html
<details>
<summary>Expected Output</summary>

| id | name  |
|----|-------|
| 1  | Alice |
| 2  | Bob   |

</details>
```

## 3. Standardized Components

### Frontmatter (YAML)
All markdown files must start with YAML frontmatter to facilitate future automation (e.g., generating a website or converting to notebooks).

```yaml
---
title: "Relational Modeling & Normalization"
week: 03
type: concept  # or 'lab'
tags: [sql, postgres, normalization]
difficulty: intermediate
duration: "45 mins"
---
```

### Visuals & Diagrams
*   **Mermaid:** Preferred for all structural diagrams (ERDs, Flowcharts, Sequence diagrams). This ensures diagrams are editable text.
*   **Assets:** Binary images (screenshots, complex schemas) go into a local `assets/` folder.

### Code Blocks
*   **Language Tag:** Always specify language.
*   **Runnable:** All code in Practical docs must be copy-paste runnable in the target environment (Colab/Local).
*   **SQL in Labs vs. Concepts:**
    | Document Type | SQL Language Tag | Reason |
    | :--- | :--- | :--- |
    | `*_concept.md` | ` ```sql ` | Read-only, illustrative snippets |
    | `*_lab.md` | ` ```python ` | Uses IPython SQL magic (`%sql`, `%%sql`); `sql` tag confuses jupytext conversion |

    *Example (Lab file):*
    ```python
    %%sql
    SELECT * FROM students WHERE enrolled = TRUE;
    ```

*   **Non-Runnable Code Blocks (Labs):** For code blocks in lab files that should **not** be converted to code cells by jupytext (e.g., expected output in `<details>` blocks, illustrative snippets), use **tildes** instead of backticks:

    ~~~python
    # This will NOT become a code cell
    print("Expected output")
    ~~~

    Jupytext does not convert tilde-fenced blocks, making them safe for display-only code.

## 4. Directory Structure Proposal
A hierarchical structure that groups related materials by week, keeping assets local to the lesson.

**Naming Convention:** `wXX_lYY_type_name.md`
*   `wXX` = Week number (e.g., `w01`, `w02`)
*   `lYY` = Lesson number (e.g., `l01`, `l02`)
*   `type` = Document type (`concept`, `lab`, `challenge`)
*   Each lesson has **both** a concept and lab file with the **same lesson number**.

```text
comp4098_material/
├── week_01/
│   ├── assets/
│   │   └── data_lifecycle_diagram.png
│   ├── data/
│   │   └── sample_data.csv
│   ├── w01_l01_concept_foundations.md
│   ├── w01_l01_lab_data_lifecycle.md
│   ├── w01_l02_concept_relational_model.md
│   └── w01_l02_lab_keys_integrity.md
├── week_02/
│   ├── w02_l03_concept_er_modeling.md
│   ├── w02_l03_lab_er_diagramming.md
│   ├── w02_l04_concept_logical_design.md
│   └── w02_l04_lab_schema_conversion.md
└── _templates/
    ├── concept_template.md
    ├── lab_template.md
    └── challenge_template.md
```

## 5. Workflow & Automation Ideas

### "Markdown-First" Approach
We write in Markdown, but we design for the Notebook experience.

1.  **Drafting:** Write content in `.md` files using a standard IDE (VS Code).
2.  **Linting:** Use a linter to ensure broken links are caught and frontmatter is valid.
3.  **Conversion (Future-proofing):**
    *   Use tools like `jupytext` or custom scripts to convert `*_lab.md` files into `.ipynb` files for distribution.
    *   *Rule:* Code blocks in `*_lab.md` become code cells; text becomes markdown cells.
    *   *Rule:* Code blocks in `*_concept.md` generally remain markdown (read-only) unless they are illustrative snippets.

### The "Challenge" Extension
Consider adding a third document type: **The Challenge (`*_challenge.md`)**.
*   Contains a problem statement and a dataset.
*   No solution code, only hints.
*   Serves as homework or in-class group work.

## 6. Design Checklist
Before finalizing a week's content:

**Concept Files:**
- [ ] Do the learning objectives match the tasks in the corresponding Lab?
- [ ] Is the terminology consistent between Concept and Lab?
- [ ] Does the Concept file have a Further Reading section with 2-3 links?
- [ ] Are Deep Dive sections (if any) in collapsible `<details>` blocks?

**Lab Files:**
- [ ] Does the Lab file have a Setup Block with package installation?
- [ ] Are expected outputs in collapsible `<details>` blocks?
- [ ] Are SQL blocks using `python` tag (not `sql`) for jupytext compatibility?
- [ ] Does the "Bad" example clearly explain *why* it is bad?

**General:**
- [ ] Are all external datasets accessible (or included in `data/`)?
- [ ] Do file names follow the `wXX_lYY_type_name.md` convention?

**Challenge Files (if applicable):**
- [ ] Is the scenario realistic and industry-relevant?
- [ ] Are hints provided without giving away the solution?
- [ ] Are submission criteria clearly defined?
