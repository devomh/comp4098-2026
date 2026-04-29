# Week 13: Embeddings, Vector Search & Retrieval for RAG

## Overview

This week opens **Module 5: Modern Architectures & AI**. After mastering relational (Module 1), columnar (Module 2), document, and key-value stores (Module 3), and the data-access-layer patterns that organize application code on top of them (Module 4), Module 5 turns to **unstructured data** — text that doesn't fit neatly into schemas.

You'll learn **semantic search** via embeddings and vector databases (L25), then build the **retrieval half** of a Retrieval-Augmented Generation (RAG) system (L26). The labs stop at retrieval deliberately: generation is covered conceptually in L26 and executed hands-on in the W15 final project, where you choose your own LLM backend and wrap the `retrieve(query)` function you finalize this week.

By the end of Week 13, you'll have ingested the course's own 21 concept files from weeks 1–11 into a persistent ChromaDB collection and measured retrieval quality with a hand-built gold set.

---

## Lesson 25: Embeddings & Vector Search

### Learning Objectives

- Explain what an embedding is and why high-dimensional vectors capture semantic similarity
- Compare cosine similarity, dot product, and Euclidean distance; pick the right metric for normalized embeddings
- Distinguish lexical search (`LIKE`, BM25) from semantic search
- Describe what a vector database adds over `numpy` brute-force similarity (indexing, persistence, metadata filtering)
- Position ChromaDB in the polyglot stack alongside PostgreSQL, DuckDB, MongoDB, and Redis

### Materials

**Concept Notes:**
- [Embeddings & Vector Search](w13_l25_concept_embeddings_vector_search.md)

**Lab Exercise:**
- [Lab: Embeddings & Vector Search with ChromaDB](w13_l25_lab_vector_search.md)

### Interactive Notebook

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/devomh/comp4098-2026/blob/main/week_13/w13_l25_lab_vector_search.ipynb)

---

## Lesson 26: Retrieval for RAG

### Learning Objectives

- Draw the full RAG architecture and identify which stages this course covers in lab vs. which are the final-project integration task
- Explain *why* RAG exists: knowledge cutoffs, hallucination, private data, context-window limits
- Compare chunking strategies (fixed-size, sentence, recursive, semantic) and their trade-offs
- Define top-k, similarity threshold, and MMR as retrieval tuning knobs
- Evaluate retrieval quality independently of generation using hit@k over a hand-authored gold set

### Materials

**Concept Notes:**
- [Retrieval for RAG](w13_l26_concept_retrieval_for_rag.md)

**Lab Exercise:**
- [Lab: Retrieval Quality — Chunking, Tuning, Evaluation](w13_l26_lab_retrieval_quality.md)

### Interactive Notebook

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/devomh/comp4098-2026/blob/main/week_13/w13_l26_lab_retrieval_quality.ipynb)

---

## Key Concepts

### Embeddings & Distance Metrics

| Metric | Formula | Typical use |
| :--- | :--- | :--- |
| **Cosine similarity** | `(a·b) / (‖a‖‖b‖)` | Default for text embeddings |
| **Dot product** | `a·b` | Equivalent to cosine when vectors are unit-normalized |
| **Euclidean (L2)** | `‖a − b‖` | Rare for text; common for images |

Chroma returns **cosine distance**, not similarity: `similarity = 1 − distance`.

### ChromaDB Essentials

| Concept | What it is |
| :--- | :--- |
| **Client** | `chromadb.Client()` (in-memory) or `chromadb.PersistentClient(path=...)` (on-disk) |
| **Collection** | Logical table of documents + embeddings + metadata |
| **Document** | A text string to retrieve later |
| **Embedding** | The vector; Chroma generates it by default using `all-MiniLM-L6-v2` (384 dims) |
| **Metadata** | Filterable dict of scalars attached to each document |
| **Id** | Your unique identifier per document |

### Chunking Strategies

| Strategy | Pros | Cons | When to use |
| :--- | :--- | :--- | :--- |
| **Fixed-size** (chars / tokens) | Simple, predictable | Breaks sentences mid-word | Quick prototypes |
| **Sentence / paragraph** | Respects boundaries | Variable size, depends on punctuation | Well-structured prose |
| **Recursive character** | Hierarchical separators, size-bounded | More moving parts | Production default |
| **Semantic** | Best topical coherence | Expensive (embedding at chunk-time) | High-value corpora |

Overlap of 50–100 characters reduces boundary loss.

### Retrieval Tuning Knobs

- **Top-k** — too small: missing context; too large: dilution and lost-in-the-middle
- **Similarity threshold** — reject low-confidence matches; prevents the LLM from inventing answers from irrelevant chunks
- **MMR (Maximal Marginal Relevance)** — trade relevance for diversity when top-k returns near-duplicates

### Evaluating Retrieval Without an LLM

Build a small **gold set** of `(question, expected_doc_id)` pairs. Measure:

- **hit@1** — fraction of questions where the expected doc is the first result
- **hit@3** / **hit@5** — fraction where it's among the top 3 / top 5

This is the evaluation the industry skips and later regrets. The L26 lab makes it concrete with 5 pairs over the 21-file course corpus.

---

## Connection from Previous Weeks

### Week 12 → Week 13: From DAL Patterns to Unstructured Data

- **Week 12:** Built the Data Access Layer — DAO, Repository, ORM — patterns that organize how application code talks to structured stores
- **Week 13:** Shifts to unstructured text. Embeddings + ChromaDB introduce a fifth engine to the polyglot stack and a paradigm that `SELECT ... WHERE` cannot express
- **Key Connection:** The same mental model — engine per workload — extends from OLTP / OLAP / document / key-value to vector search. ChromaDB isn't a replacement; it's an addition for the text-similarity use case.

---

## Technical Notes

### ChromaDB in Colab

- **In-memory** client (`chromadb.Client()`) is used for the L25 toy-corpus demos and the L26 chunking bake-off — resets each session, zero setup
- **Persistent** client (`chromadb.PersistentClient(path="./chroma_db")`) is used for the course-concepts corpus that bridges L25 and L26

### Corpus Source

The persistent corpus is 21 concept files from weeks 1–11, cloned from the public course repo at `https://github.com/devomh/comp4098-2026`. Ingestion happens in L25 §5 (one document per file, YAML frontmatter stripped, metadata extracted from filenames) and is reused verbatim by L26.

### No LLM in These Labs

Module 5 labs deliberately stop at retrieval. Generation is:

- **Covered conceptually** in L26 §3 (the RAG pipeline diagram shows boxes 6–7 as out of scope for the labs)

### Datasets

- **L25 toy corpus:** 30 short customer-support strings in three topic groups (billing/auth, shipping, refunds) — used to demonstrate clustering, metadata filtering, and semantic-vs-lexical contrast
- **L25 §5 / L26 corpus:** 21 concept files from weeks 1–11, stored one-per-document in the `course_concepts` collection
- **L26 bake-off source:** `w09_l17_concept_nosql_document_model.md` — the longest concept file, chosen because it covers four distinct sub-topics and thus exposes chunker-quality differences

---

## Additional Resources

### Documentation

- [ChromaDB Documentation](https://docs.trychroma.com/) — Official quickstart, `where` filters, `n_results`, persistence
- [Sentence Transformers documentation](https://www.sbert.net/) — The library behind `all-MiniLM-L6-v2`; "Pretrained Models" is the key reference when choosing a different model
- [LangChain — Text Splitters](https://python.langchain.com/docs/concepts/text_splitters/) — Reference for `RecursiveCharacterTextSplitter` and related splitters

### Articles & Research

- [Pinecone: What are Vector Embeddings?](https://www.pinecone.io/learn/vector-embeddings/) — Accessible primer with 2D intuition
- [Anthropic — Contextual Retrieval](https://www.anthropic.com/news/contextual-retrieval) — State-of-the-art technique for chunk-retrieval improvements (2024)
- [Lost in the Middle (Liu et al., 2023)](https://arxiv.org/abs/2307.03172) — Empirical demonstration that LLMs underuse the middle of long contexts
- [Pinecone — RAG evaluation guide](https://www.pinecone.io/learn/series/vector-databases-in-production-for-busy-engineers/rag-evaluation/) — hit@k, MRR, NDCG, RAGAs-style evaluation

---

## Questions or Issues?

- **If Chroma persistence is missing after a Colab reset:** rerun L25 §5 in full, or let the L26 setup cell rebuild from scratch (it auto-detects the absence of `./chroma_db` / `./corpus` and replays the L25 ingestion)
- **If `sentence-transformers` fails to download the model:** check network; the first load pulls ~90 MB. Subsequent loads in the same session are cached.
- **If the embedding step seems slow:** `all-MiniLM-L6-v2` is CPU-friendly but not instant on cold start. Expect ~15–30 seconds for the first `SentenceTransformer(...)` call and near-instant ingestion of the 21-file corpus after that.
- **If hit@k numbers look off:** the gold-set expected ids are tied to filenames in the 2026 course repo; if you renamed or reorganized files locally, regenerate the gold set or skip the affected items.
