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

### B. Practical Document (`*_lab.md`)
*   **Goal:** Build muscle memory, demonstrate syntax, and solve concrete problems.
*   **Tone:** Instructional, imperative, and streamlined.
*   **Key Elements:**
    *   **Prerequisites:** Explicit list of required libraries or previous labs.
    *   **Setup Block:** Standardized import/connection code block at the top.
    *   **Iterative Code:** Start simple, then refactor. Show "Bad vs. Good" patterns (e.g., looping vs. vectorization).
    *   **"Your Turn":** Small, unguided exercises sprinkled throughout (marked as `# TODO`).
    *   **Output:** Expected output samples (tables, JSON) so students can verify correctness without running the code immediately.

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
*   **Language Tag:** Always specify language (e.g., ```` ```sql ````, ```` ```python ````).
*   **Runnable:** All code in Practical docs must be copy-paste runnable in the target environment (Colab/Local).

## 4. Directory Structure Proposal
A hierarchical structure that groups related materials by week, keeping assets local to the lesson.

```text
comp4098_material/
├── week_01/
│   ├── assets/
│   │   └── data_lifecycle_diagram.png
│   ├── data/
│   │   └── raw_logs.csv
│   ├── w01_l01_concept_foundations.md
│   └── w01_l02_lab_intro_pandas.md
├── week_02/
│   ├── ...
└── _templates/
    ├── concept_template.md
    └── lab_template.md
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
- [ ] Do the learning objectives in Concept match the tasks in Lab?
- [ ] Are all external datasets accessible (or included in `data/`)?
- [ ] Is the terminology consistent between Concept and Lab?
- [ ] Does the "Bad" example clearly explain *why* it is bad?
