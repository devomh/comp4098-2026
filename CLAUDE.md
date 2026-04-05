# CLAUDE.md — COMP 4098: Data Management and Architectures for Data Science

**Course:** COMP 4098 · Universidad de Puerto Rico en Humacao · Jan–May 2026
**Professor:** Ollantay Medina
**Status:** Active development — 15 weeks, 30 lessons, 2 lessons/week (80 min each)

---

## Repository Overview

This repo holds all course materials as version-controlled Markdown artifacts. Files are authored in `.md` and converted to `.ipynb` (Google Colab) via `jupytext`. The target audience is senior Data Science students with strong Python skills.

```
comp4098-2026-01/
├── 00_syllabus/        # Syllabus (LaTeX source + PDF)
├── _design/            # lesson-guidelines.md — authoritative design reference
├── _templates/         # concept_template.md, lab_template.md, challenge_template.md
├── week_01/ … week_05/ # Completed lesson content (see Progress below)
├── _assignments/       # Assignment files
└── _system/            # System/tooling files
```

---

## File Naming Convention

```
wXX_lYY_<type>_<slug>.md
```
- `wXX` = week number (01–15)
- `lYY` = lesson number (01–30)
- `type` = `concept` | `lab` | `challenge`
- Each lesson has exactly one `concept` + one `lab` file with the same `lYY`

**Example:** `w04_l07_concept_ddl_schema.md` + `w04_l07_lab_ddl_implementation.md`

---

## Document Types & Critical Rules

### Concept Files (`*_concept.md`)
YAML frontmatter required (`type: concept`). Sections in order:
1. Learning Objectives
2. The "Why": Industry Context (include non-technical analogy)
3. Core Concepts (use Mermaid for all structural diagrams)
4. Deep Dives (Optional) — **must use collapsible `<details>` blocks**
5. FAQ / Industry Reality
6. Summary & Next Steps
7. Further Reading (≥2–3 links: textbook → official docs → articles)

**Deep Dive structure rules:**
- Single deep dive → `## Deep Dive: [Topic] (Optional)` with `<details>` directly below
- Multiple → `## Deep Dives (Optional)` parent, then `### A.`, `### B.` sub-headings each with own `<details>`

### Lab Files (`*_lab.md`)
YAML frontmatter required (`type: lab`). Must be self-contained (Colab is ephemeral).

**Critical jupytext rules:**
- SQL blocks must use ` ```python ` tag (never ` ```sql `); use `%%sql` magic inside
- Non-runnable display blocks (e.g., expected output inside `<details>`) use **tildes** (`~~~`) not backticks — jupytext will not convert tilde blocks to code cells
- Expected outputs go in collapsible `<details><summary>Expected Output</summary>` blocks

**Required setup cell (first code cell):**
```python
# Setup: Run this cell first (required for Colab)
!pip install -q <packages>
import ...
```

### Challenge Files (`*_challenge.md`)
YAML frontmatter required (`type: challenge`). Sections: Scenario → Dataset → Mission (questions with hints) → Submission Criteria. No solution code.

---

## Module & Lesson Map

| Module | Weeks | Lessons | Topics |
| :--- | :--- | :--- | :--- |
| 1: Relational Foundations | 1–4 | 1–8 | Data lifecycle, ER modeling, Normalization, PostgreSQL DDL/DML |
| 2: Analytical SQL | 5–8 | 9–16 | OLTP vs OLAP, DuckDB, Joins, Aggregations, Window Functions, CTEs, Benchmarks |
| 3: NoSQL | 9–11 | 17–22 | CAP theorem, MongoDB, Redis |
| 4: Data Access Layer | 12 | 23–24 | DAL, DAO, Repository, ORM, Connection Pooling |
| 5: Modern AI | 13–15 | 25–30 | Embeddings, Vector DBs (ChromaDB/LanceDB), RAG |

---

## Progress (as of 2026-04-04)

| Week | Lessons | Status |
| :--- | :--- | :--- |
| week_01 | L01 (Data Lifecycle), L02 (Relational Model) | ✅ Complete |
| week_02 | L03 (ER Modeling), L04 (Logical Design) | ✅ Complete |
| week_03 | L05 (Normalization), L06 (Denormalization) | ✅ Complete (includes challenge) |
| week_04 | L07 (DDL), L08 (DML) | ✅ Complete |
| week_05 | L09 (OLTP vs OLAP), L10 (DuckDB) | 🟡 In progress |
| week_06 | L11 (Complex Joins), L12 (Aggregation & Grouping) | ✅ Complete |
| week_07 | L13 (Window Functions), L14 (CTEs & Advanced Analytics) | ✅ Complete |
| week_08 | L15 (Data at Scale), L16 (Performance Benchmark) | ✅ Complete |
| week_09 | L17 (CAP Theorem & Document Model), L18 (Document Stores / MongoDB) | ✅ Complete |
| week_10 | L19 (MongoDB Essentials), L20 (Aggregation Pipeline) | ✅ Complete |
| week_11 | L21 (Redis & Key-Value Stores), L22 (Data Security & Connectivity) | ✅ Complete |
| week_12+ | L23–L30 | ❌ Not started |

**Next up:** Week 12 — L23 (DAL Architecture & Connectivity) + L24 (DAO/ORM with SQLAlchemy) · Module 4

---

## Technologies Used

| Tool | Role |
| :--- | :--- |
| PostgreSQL | OLTP, row-oriented, Module 1 & 2 |
| DuckDB | OLAP, in-process columnar, Module 2 |
| MongoDB | Document store, Module 3 |
| Redis | Key-value / caching, Module 3 |
| ChromaDB / LanceDB | Vector databases, Module 5 |
| Python / SQLAlchemy / psycopg2 | Application layer |
| Google Colab | Primary execution environment |
| `mermaid-py` | Mermaid diagrams in Colab notebooks |
| `jupytext` | Converts `*_lab.md` → `.ipynb` |

---

## Key Design Decisions (from `_design/lesson-guidelines.md`)

1. **Markdown-first:** Author in `.md`, distribute as `.ipynb`. Never edit `.ipynb` directly.
2. **SQL tag in labs = `python`:** Jupytext maps code blocks to cells; using `sql` tag breaks conversion.
3. **Tildes for non-runnable blocks:** `~~~python` in lab files stays as markdown (no cell created).
4. **Mermaid for all diagrams:** Prefer Mermaid over binary images. Binary assets go in `assets/`.
5. **Self-contained labs:** Every lab installs its own packages (Colab resets on open).
6. **Paired files:** Every lesson number must have both a `concept` and a `lab` file.
7. **Further reading priority:** Textbook (*Database Design 2nd Ed.* by Adrienne Watt) → Official docs → Articles.
8. **Module 3+ reading:** Textbook does not cover NoSQL+; use official MongoDB/Redis/ChromaDB docs instead.

---

## YAML Frontmatter Schema

```yaml
---
title: "Descriptive Title"
week: 04           # integer
type: concept      # concept | lab | challenge
tags: [sql, postgres, ddl]
difficulty: intermediate   # introductory | intermediate | advanced
duration: "45 mins"
---
```

---

## Design Checklist (quick reference)

**Concept:** objectives match lab tasks · terminology consistent · ≥2 Further Reading links · deep dives in `<details>`

**Lab:** setup cell present · expected outputs in `<details>` · SQL uses `python` tag · non-runnable blocks use tildes · exercises have `# TODO`

**General:** file names follow convention · datasets accessible or in `data/`
