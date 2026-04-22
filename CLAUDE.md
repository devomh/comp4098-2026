# CLAUDE.md — COMP 4098: Data Management and Architectures for Data Science

**Course:** COMP 4098 · Universidad de Puerto Rico en Humacao · Jan–May 2026
**Professor:** Ollantay Medina
**Status:** Active development — 15 weeks, 30 lessons, 2 lessons/week (80 min each)
**Audience:** Senior Data Science students with strong Python skills.

Authoritative authoring rules live in [_design/lesson-guidelines.md](_design/lesson-guidelines.md). Templates live in [_templates/](_templates/). This file is the quick-reference index.

---

## Repository Layout

```
comp4098-2026-01/
├── 00_syllabus/   # Syllabus (LaTeX source + PDF)
├── _design/       # lesson-guidelines.md — authoritative design reference
├── _templates/    # concept / lab / challenge templates + YAML frontmatter schema
└── week_XX/       # Lesson content (see Progress below)
```

Files are authored in `.md` and converted to `.ipynb` (Google Colab) via `jupytext`. **Never edit `.ipynb` directly.**

---

## File Naming

```
wXX_lYY_<type>_<slug>.md
```
- `wXX` = week (01–15), `lYY` = lesson (01–30), `type` = `concept` | `lab` | `challenge`
- Every lesson number has exactly one `concept` + one `lab` file. Challenges are optional.

**Example:** `w04_l07_concept_ddl_schema.md` + `w04_l07_lab_ddl_implementation.md`

---

## Document Types

### Concept (`*_concept.md`)
YAML frontmatter (`type: concept`). Section order:
1. Learning Objectives
2. The "Why": Industry Context (include non-technical analogy)
3. Core Concepts (use Mermaid for all structural diagrams)
4. Deep Dives (Optional) — in collapsible `<details>` blocks
   - Single: `## Deep Dive: [Topic] (Optional)` with `<details>` directly below
   - Multiple: `## Deep Dives (Optional)` parent, then `### A.`, `### B.` each with own `<details>`
5. FAQ / Industry Reality
6. Summary & Next Steps
7. Further Reading (≥2–3 links; priority: textbook → official docs → articles. *Database Design 2nd Ed.* by Adrienne Watt for Modules 1–2; official MongoDB/Redis/ChromaDB docs for Module 3+)

### Lab (`*_lab.md`)
YAML frontmatter (`type: lab`). Must be self-contained — Colab resets on open, so every lab installs its own packages in a first setup cell:
```python
# Setup: Run this cell first (required for Colab)
!pip install -q <packages>
import ...
```

**Critical jupytext rules:**
- SQL blocks must use the ` ```python ` tag (never ` ```sql `); put `%%sql` magic inside.
- Non-runnable display blocks (e.g., expected output) use **tildes** (`~~~`) not backticks — tilde blocks are not converted to code cells.
- Expected outputs go in `<details><summary>Expected Output</summary>` blocks.
- Exercises are marked with `# TODO`.

### Challenge (`*_challenge.md`)
YAML frontmatter (`type: challenge`). Sections: Scenario → Dataset → Mission (questions with hints) → Submission Criteria. No solution code.

---

## Progress (as of 2026-04-21)

| Module | Week | Lessons | Status |
| :--- | :--- | :--- | :--- |
| 1: Relational Foundations | week_01 | L01 Data Lifecycle, L02 Relational Model | ✅ |
| 1 | week_02 | L03 ER Modeling, L04 Logical Design | ✅ |
| 1 | week_03 | L05 Normalization, L06 Denormalization | ✅ (+ challenge) |
| 1 | week_04 | L07 DDL, L08 DML | ✅ |
| 2: Analytical SQL | week_05 | L09 OLTP vs OLAP, L10 DuckDB | ✅ |
| 2 | week_06 | L11 Complex Joins, L12 Aggregation & Grouping | ✅ |
| 2 | week_07 | L13 Window Functions, L14 CTEs & Advanced Analytics | ✅ |
| 2 | week_08 | L15 Data at Scale, L16 Performance Benchmark | ✅ |
| 3: NoSQL | week_09 | L17 CAP Theorem & Document Model, L18 MongoDB | ✅ |
| 3 | week_10 | L19 MongoDB Essentials, L20 Aggregation Pipeline | ✅ |
| 3 | week_11 | L21 Redis & Key-Value Stores, L22 Data Security & Connectivity | ✅ |
| 4: Data Access Layer | week_12 | L23 DAL Architecture & Connectivity, L24 DAO/ORM with SQLAlchemy | 🟡 Drafted (`.md` only) |
| 5: Modern AI | week_13 | L25 Embeddings & Vector Search, L26 Retrieval for RAG | 🟡 Drafted (`.md` only) |
| 5 | week_14–15 | L27–L30 | ❌ Not started |

**Next up:** Finalize Week 12 & 13 (generate `.ipynb`, review), then Week 14 — L27 + L28.

---

## Stack

PostgreSQL (OLTP, Modules 1–2) · DuckDB (OLAP, Module 2) · MongoDB + Redis (Module 3) · SQLAlchemy / psycopg2 (Module 4) · ChromaDB / LanceDB (Module 5) · Google Colab execution · `jupytext` for `.md` → `.ipynb` · `mermaid-py` for diagrams in notebooks.
