---
title: "Lab: Retrieval Quality — Chunking, Tuning, Evaluation"
week: 13
type: lab
tags: [rag, retrieval, chunking, evaluation, chromadb, lab]
difficulty: intermediate
duration: "45 mins"
---

# Lab: Retrieval Quality — Chunking, Tuning, Evaluation

## Prerequisites & What You'll Build

**Before starting:**
*   Complete [w13_l25_lab_vector_search.md](w13_l25_lab_vector_search.md) — this lab **reuses** the `course_concepts` collection at `./chroma_db` that L25 built. The setup cell below can rebuild it from scratch if your Colab session has been reset.
*   Review [w13_l26_concept_retrieval_for_rag.md](w13_l26_concept_retrieval_for_rag.md).

**What you'll accomplish:**

1.  Run a **chunking bake-off** — whole document vs. fixed-size vs. recursive splitter — on the longest concept file in the corpus.
2.  Tune **top-k** and apply a **similarity threshold**; implement a `retrieve(query, k, min_similarity)` wrapper.
3.  Author a 5-pair **gold set** and measure **hit@1 / hit@3 / hit@5**.
4.  Finalize the `retrieve(query)` function as a clean, reusable retrieval contract.

---

## 1. Setup

The setup cell must handle two cases:

*   You are **continuing from L25** in the same Colab session — `./chroma_db` and `./corpus` already exist.
*   You are **starting fresh** (new session, Colab reset) — rebuild from the public course repo.

```python
# Setup: Run this cell first (required for Colab)
!pip install -q chromadb sentence-transformers langchain-text-splitters
```

```python
import os, re, shutil, subprocess
import chromadb
from langchain_text_splitters import RecursiveCharacterTextSplitter

CONCEPT_FILES = [
    "week_01/w01_l01_concept_intro_lifecycle.md",
    "week_01/w01_l02_concept_relational_model.md",
    "week_02/w02_l03_concept_er_modeling.md",
    "week_02/w02_l04_concept_logical_design.md",
    "week_03/w03_l05_concept_normalization.md",
    "week_03/w03_l06_concept_denormalization.md",
    "week_04/w04_l07_concept_ddl_schema.md",
    "week_04/w04_l08_concept_dml_querying.md",
    "week_05/w05_l09_concept_oltp_vs_olap.md",
    "week_05/w05_l10_concept_intro_duckdb.md",
    "week_06/w06_l11_concept_complex_joins.md",
    "week_06/w06_l12_concept_aggregation_grouping.md",
    "week_07/w07_l13_concept_window_functions.md",
    "week_07/w07_l14_concept_ctes_advanced.md",
    "week_08/w08_l15_concept_data_at_scale.md",
    "week_08/w08_l16_concept_query_performance.md",
    "week_09/w09_l17_concept_nosql_document_model.md",
    "week_10/w10_l19_concept_mongodb_essentials.md",
    "week_10/w10_l20_concept_advanced_querying.md",
    "week_11/w11_l21_concept_redis_keyvalue.md",
    "week_11/w11_l22_concept_data_security.md",
]

def strip_frontmatter(text: str) -> str:
    if text.lstrip().startswith("---"):
        parts = text.split("---", 2)
        if len(parts) >= 3:
            return parts[2].lstrip()
    return text

def derive_metadata(filename: str) -> dict:
    m = re.match(r"w(\d+)_l(\d+)_concept_.+\.md$", filename)
    week, lesson = int(m.group(1)), int(m.group(2))
    module = 1 if week <= 4 else (2 if week <= 8 else 3)
    return {"week": week, "lesson": lesson, "module": module, "filename": filename}

def rebuild_from_scratch():
    """Replays L25 §5 — clone repo, copy 21 files, ingest into ./chroma_db."""
    if os.path.exists("/tmp/course_repo"):
        shutil.rmtree("/tmp/course_repo")
    subprocess.run(
        ["git", "clone", "--depth", "1",
         "https://github.com/devomh/comp4098-2026.git", "/tmp/course_repo"],
        check=True,
    )
    if os.path.exists("./corpus"):
        shutil.rmtree("./corpus")
    os.makedirs("./corpus", exist_ok=True)
    for rel in CONCEPT_FILES:
        shutil.copy(f"/tmp/course_repo/{rel}", f"./corpus/{os.path.basename(rel)}")

    if os.path.exists("./chroma_db"):
        shutil.rmtree("./chroma_db")
    c = chromadb.PersistentClient(path="./chroma_db")
    coll = c.get_or_create_collection(name="course_concepts")
    docs, ids, metas = [], [], []
    for fn in sorted(os.listdir("./corpus")):
        if not fn.endswith(".md"):
            continue
        with open(f"./corpus/{fn}") as f:
            docs.append(strip_frontmatter(f.read()))
        ids.append(fn)
        metas.append(derive_metadata(fn))
    coll.add(documents=docs, ids=ids, metadatas=metas)

# Decide which path to take
if not os.path.exists("./chroma_db") or not os.path.exists("./corpus"):
    print("No persisted corpus found — rebuilding from L25 ingestion logic.")
    rebuild_from_scratch()
else:
    print("Persisted corpus found — reusing from L25.")

client = chromadb.PersistentClient(path="./chroma_db")
course_collection = client.get_collection(name="course_concepts")
print(f"course_concepts: {course_collection.count()} documents")
```

<details>
<summary>Expected Output</summary>

~~~text
Persisted corpus found — reusing from L25.
course_concepts: 21 documents
~~~

(Or: `No persisted corpus found — rebuilding from L25 ingestion logic.` followed by a clone, followed by `course_concepts: 21 documents`.)

</details>

---

## 2. Chunking Bake-Off

L25 stored one embedding per entire file. For short concept files that's defensible; for anything longer it's guaranteed to dilute signals. This section demonstrates the difference.

**Bake-off source:** `w09_l17_concept_nosql_document_model.md` — the longest concept file in the corpus (~467 lines) and the one that mixes four sub-topics (CAP theorem, schema-on-read, document model, embed-vs-reference). That mix is what exposes chunker quality.

### 2.1 Read the Bake-Off Document

```python
with open("./corpus/w09_l17_concept_nosql_document_model.md") as f:
    bakeoff_text = strip_frontmatter(f.read())

print(f"Character length: {len(bakeoff_text):,}")
print(f"Line count:       {bakeoff_text.count(chr(10)):,}")
```

<details>
<summary>Expected Output</summary>

~~~text
Character length: ~17,000–19,000
Line count:       ~450–470
~~~

(Exact sizes depend on the repo's current state; the orders of magnitude matter.)

</details>

### 2.2 Produce Three Chunk Versions

```python
# Strategy 1 — whole document (what L25 did)
whole_doc = [bakeoff_text]

# Strategy 2 — fixed 500 chars, no overlap, no structure-aware separators
fixed_splitter = RecursiveCharacterTextSplitter(
    chunk_size=500,
    chunk_overlap=0,
    separators=[""],   # forces character-level cuts
)
fixed_500 = fixed_splitter.split_text(bakeoff_text)

# Strategy 3 — recursive, 200 chars with 50-char overlap (default separators)
recursive_splitter = RecursiveCharacterTextSplitter(
    chunk_size=200,
    chunk_overlap=50,
    # separators=["\n\n", "\n", " ", ""],  # default — tried in order; falls back to next if chunk still too large
)
recursive_200_50 = recursive_splitter.split_text(bakeoff_text)

print(f"whole_doc:        {len(whole_doc)} chunks")
print(f"fixed_500:        {len(fixed_500)} chunks")
print(f"recursive_200_50: {len(recursive_200_50)} chunks")
```

<details>
<summary>Expected Output</summary>

~~~text
whole_doc:        1 chunks
fixed_500:        ~35–45 chunks
recursive_200_50: ~100–140 chunks
~~~

</details>

### 2.3 Ingest Each Strategy Into Its Own Collection

```python
def build_bakeoff_collection(name: str, chunks: list[str]):
    try:
        client.delete_collection(name=name)
    except Exception:
        pass
    coll = client.create_collection(name=name)
    coll.add(
        documents=chunks,
        ids=[f"{name}_{i}" for i in range(len(chunks))],
    )
    return coll

bakeoff_whole     = build_bakeoff_collection("bakeoff_whole", whole_doc)
bakeoff_fixed     = build_bakeoff_collection("bakeoff_fixed", fixed_500)
bakeoff_recursive = build_bakeoff_collection("bakeoff_recursive", recursive_200_50)

for c in [bakeoff_whole, bakeoff_fixed, bakeoff_recursive]:
    print(f"{c.name:22s} → {c.count()} chunks")
```

<details>
<summary>Expected Output</summary>

~~~text
bakeoff_whole          → 1 chunks
bakeoff_fixed          → ~40 chunks
bakeoff_recursive      → ~120 chunks
~~~

</details>

### 2.4 Probe All Three Collections

```python
probes = [
    "What does partition tolerance mean in CAP?",
    "When should I embed a document vs use a reference?",
    "What is schema-on-read?",
]

for query in probes:
    print(f"\n=== Query: {query} ===")
    for coll in [bakeoff_whole, bakeoff_fixed, bakeoff_recursive]:
        res = coll.query(query_texts=[query], n_results=1)
        top_doc = res["documents"][0][0]
        top_dist = res["distances"][0][0]
        preview = top_doc.replace("\n", " ")[:100].strip()
        print(f"  {coll.name:22s} [{top_dist:.3f}]  {preview!r}...")
```

<details>
<summary>Expected Output</summary>

~~~text
=== Query: What does partition tolerance mean in CAP? ===
  bakeoff_whole          [0.80]  '# Module 3: CAP Theorem & the Document Model ...'
  bakeoff_fixed          [0.55]  '...partition tolerance ... network splits ...'
  bakeoff_recursive      [0.40]  'Partition tolerance (P): the system keeps ...'

=== Query: When should I embed a document vs use a reference? ===
  bakeoff_whole          [0.82]  (same first 100 chars of whole doc)
  bakeoff_fixed          [0.62]  (passage that may or may not be the embed/reference one)
  bakeoff_recursive      [0.38]  (a chunk that contains 'embed ... reference ...')

=== Query: What is schema-on-read? ===
  bakeoff_whole          [0.83]  (same whole doc again)
  bakeoff_fixed          [0.60]
  bakeoff_recursive      [0.42]
~~~

(Exact distances will vary. The pattern is the point: `whole` returns the same document at roughly the same distance regardless of query — useless signal. `recursive` returns **different**, **closer** chunks per query.)

</details>

### 2.5 Observation — Fill in the Table

```
| Query                                       | whole | fixed_500 | recursive_200_50 |
|---------------------------------------------|-------|-----------|------------------|
| What does partition tolerance mean in CAP?  |       |           |                  |
| When should I embed vs use a reference?     |       |           |                  |
| What is schema-on-read?                     |       |           |                  |
```

For each cell, record whether the returned chunk actually **contains the answer** (✓) or is noise (✗). Which strategy wins? By how much?

**Takeaways to internalize before moving on:**

*   **`whole` always returns the same chunk** because there is only one. Distance varies with query, but retrieval does not.
*   **`fixed_500` is hit-or-miss** — it's better than `whole`, but it cuts sentences in arbitrary places and a relevant sentence may be split across two chunks.
*   **`recursive_200_50` wins on this corpus** — it respects paragraph and list boundaries, and the overlap means boundary-spanning answers still appear whole in at least one chunk.

---

## 3. Top-k and Threshold Tuning

Now we switch back to the full `course_concepts` collection (all 21 files, one doc per file — same as L25 built).

### 3.1 Vary `n_results`

```python
query = "How do I design a schema with third normal form?"

for k in [1, 3, 5, 10]:
    res = course_collection.query(query_texts=[query], n_results=k)
    print(f"\n--- k = {k} ---")
    for doc_id, dist in zip(res["ids"][0], res["distances"][0]):
        print(f"  [{dist:.3f}]  {doc_id}")
```

<details>
<summary>Expected Output</summary>

~~~text
--- k = 1 ---
  [0.60]  w03_l05_concept_normalization.md

--- k = 3 ---
  [0.60]  w03_l05_concept_normalization.md
  [0.85]  w03_l06_concept_denormalization.md
  [0.95]  w02_l04_concept_logical_design.md

--- k = 5 ---
  [0.60]  w03_l05_concept_normalization.md
  [0.85]  w03_l06_concept_denormalization.md
  [0.95]  w02_l04_concept_logical_design.md
  [1.02]  w04_l07_concept_ddl_schema.md
  [1.05]  w02_l03_concept_er_modeling.md

--- k = 10 ---
  (includes the above plus progressively less relevant files)
~~~

(Exact distances vary by a few hundredths.)

</details>

### 3.2 Observation — The Similarity Cliff

Convert the distances mentally using `similarity = 1 - distance`. You should see a **cliff**: one or two hits at a clearly higher similarity (say, ≥ 0.3), then a drop (often 0.2+) to a plateau of loosely related files. Above the cliff → relevant. Below the cliff → noise. This is why a similarity threshold matters: it lets you cut at the cliff automatically, which is exactly what the `min_similarity` parameter in §3.3 does.

### 3.3 Your Turn — Build the `retrieve` Wrapper

```python
def retrieve(query: str, k: int = 3, min_similarity: float = 0.3) -> list[dict]:
    """Retrieve top-k documents above a similarity threshold.

    Returns a list of dicts with keys: id, document, metadata, similarity.
    Chroma returns cosine distance; convert with: similarity = 1 - distance.
    """
    # TODO: call course_collection.query(query_texts=[query], n_results=k)
    # TODO: zip ids, documents, metadatas, distances from the result
    # TODO: convert distance to similarity
    # TODO: drop entries whose similarity < min_similarity
    # TODO: return the surviving entries as a list of dicts
    pass

# Smoke test
out = retrieve("What is the CAP theorem?", k=3, min_similarity=0.0)
for h in out:
    print(f"[sim={h['similarity']:.3f}]  {h['id']}")
```

<details>
<summary>Solution</summary>

~~~python
def retrieve(query: str, k: int = 3, min_similarity: float = 0.3) -> list[dict]:
    res = course_collection.query(query_texts=[query], n_results=k)
    hits = []
    for doc_id, doc, meta, dist in zip(
        res["ids"][0],
        res["documents"][0],
        res["metadatas"][0],
        res["distances"][0],
    ):
        similarity = 1 - dist
        if similarity >= min_similarity:
            hits.append({
                "id": doc_id,
                "document": doc,
                "metadata": meta,
                "similarity": similarity,
            })
    return hits
~~~

**Verify:**

~~~python
# Expected: CAP-theorem top hit at similarity > 0.3
assert retrieve("What is the CAP theorem?", k=3)[0]["id"] == "w09_l17_concept_nosql_document_model.md"

# A deliberately unrelated query should often return [] at threshold 0.3
off_topic = retrieve("How do I train a sourdough starter?", k=3, min_similarity=0.3)
print(f"Off-topic query returned {len(off_topic)} hits (expect 0 or a weak single hit).")
~~~

</details>

---

## 4. Gold Set and hit@k Measurement

This is the most important cell in the lab. Nothing else matters if you cannot measure retrieval quality.

### 4.1 The Gold Set

Five hand-authored `(question, expected_id)` pairs. The expected id is the concept file a human grader would say *answers the question best*.

```python
GOLD_SET = [
    {
        "question": "What are insert, update, and delete anomalies?",
        "expected_id": "w03_l05_concept_normalization.md",
    },
    {
        "question": "What is the CAP theorem and why can't a distributed system guarantee all three?",
        "expected_id": "w09_l17_concept_nosql_document_model.md",
    },
    {
        "question": "How does column-oriented storage improve analytical query performance?",
        "expected_id": "w05_l09_concept_oltp_vs_olap.md",
    },
    {
        "question": "How do RANK and DENSE_RANK differ?",
        "expected_id": "w07_l13_concept_window_functions.md",
    },
    {
        "question": "What makes parameterized queries safe against SQL injection?",
        "expected_id": "w11_l22_concept_data_security.md",
    },
]
```

### 4.2 Compute hit@1, hit@3, hit@5

```python
def hit_at_k(gold_set: list[dict], collection, k: int) -> float:
    hits = 0
    for item in gold_set:
        res = collection.query(query_texts=[item["question"]], n_results=k)
        if item["expected_id"] in res["ids"][0]:
            hits += 1
    return hits / len(gold_set)

for k in [1, 3, 5]:
    score = hit_at_k(GOLD_SET, course_collection, k)
    print(f"hit@{k} = {score*100:.0f}%  ({int(score*len(GOLD_SET))}/{len(GOLD_SET)})")
```

<details>
<summary>Expected Output</summary>

~~~text
hit@1 = 80%  (4/5)
hit@3 = 100% (5/5)
hit@5 = 100% (5/5)
~~~

(Exact numbers can shift by ±20% on any single gold-set item, depending on the exact embedding-model version. A hit@3 of 100% on a 5-item gold set over a 21-file corpus is reasonable — the corpus is small and the gold set's expected answers are the obvious concept files.)

</details>

### 4.3 Per-Question Diagnostic

```python
for item in GOLD_SET:
    res = course_collection.query(query_texts=[item["question"]], n_results=5)
    ids = res["ids"][0]
    if item["expected_id"] in ids:
        rank = ids.index(item["expected_id"]) + 1
        status = f"hit @ rank {rank}"
    else:
        status = "MISS in top 5"
    print(f"  [{status:15s}]  expected={item['expected_id']}")
    print(f"                    question={item['question']}")
```

### 4.4 Observation

For each hit, look at **which rank** the expected doc landed at. A rank-1 hit means the retriever nailed it. A rank-3 or rank-4 hit means the retriever was *right but indecisive* — often a sign that the query phrasing overlaps with a nearby-topic document (e.g., normalization questions pulling up denormalization). When you see this, you have three tools: rephrase the query, add a metadata filter, or switch to a larger embedding model. In a real deployment with a 500-item gold set, you would see patterns across misses and invest accordingly.

### 4.5 Your Turn — Bake-Off Against the Gold Set

Rerun the gold set against the three bake-off collections from §2. Which chunker wins on hit@3?

```python
# TODO: for each of bakeoff_whole, bakeoff_fixed, bakeoff_recursive, compute hit@3
# over GOLD_SET. Print a small summary table.

# Important framing: the bake-off collections only index ONE of the 21 source
# files (w09_l17_*). Most gold-set questions (normalization, window functions,
# SQL injection, ...) have NO matching document in those collections — they
# will miss no matter how good the chunker is. That's the point: domain
# coverage matters at least as much as chunker quality.
```

<details>
<summary>Solution</summary>

~~~python
for coll in [bakeoff_whole, bakeoff_fixed, bakeoff_recursive]:
    score = hit_at_k(GOLD_SET, coll, k=3)
    print(f"{coll.name:22s}  hit@3 = {score*100:.0f}%")
~~~

Expected: all three score poorly (hit@3 of 0–20%) because four of the five gold-set questions are about topics **not present** in the bake-off corpus at all. The `bakeoff_recursive` run may get credit for the CAP-theorem question. Frame in your notes: **retrieval quality is corpus-bounded, not just chunker-bounded**.

</details>

---

## 5. Finalizing the Retrieval Contract

The `retrieve` function you built in §3 is the retrieval contract. Finalize it here — docstring, signature, and the `course_concepts` collection path — and leave it in a known state.

### 5.1 The Contract

```python
def retrieve(query: str, k: int = 3, min_similarity: float = 0.3) -> list[dict]:
    """Retrieve top-k documents from course_concepts above a similarity threshold.

    Parameters
    ----------
    query : str
        The user's natural-language question.
    k : int
        Maximum number of documents to return (default 3).
    min_similarity : float
        Drop results whose cosine similarity is below this value (default 0.3).

    Returns
    -------
    list[dict]
        Each dict has keys: id, document, metadata, similarity.
        Empty list if no document meets the threshold.
    """
    res = course_collection.query(query_texts=[query], n_results=k)
    hits = []
    for doc_id, doc, meta, dist in zip(
        res["ids"][0],
        res["documents"][0],
        res["metadatas"][0],
        res["distances"][0],
    ):
        similarity = 1 - dist
        if similarity >= min_similarity:
            hits.append({
                "id": doc_id,
                "document": doc,
                "metadata": meta,
                "similarity": similarity,
            })
    return hits

# Sanity check
demo = retrieve("What is the CAP theorem?", k=3)
for h in demo:
    print(f"[sim={h['similarity']:.3f}]  {h['id']}  (mod {h['metadata']['module']})")
```

<details>
<summary>Expected Output</summary>

~~~text
[sim=0.28–0.40]  w09_l17_concept_nosql_document_model.md  (mod 3)
~~~

(If `similarity` is below `min_similarity=0.3`, raise the threshold from 0.3 to 0.2 — the MiniLM model produces modest absolute similarities for abstract questions, and the relative ranking is what matters. Calibrate against your gold set.)

</details>

### 5.2 Extending to Generation

This function, plus the `course_concepts` collection at `./chroma_db`, is the retrieval half of a full RAG pipeline. Adding the generation half looks like this:

```python
def rag_answer(question: str) -> str:
    hits = retrieve(question, k=3, min_similarity=0.3)
    if not hits:
        return "I don't have information to answer that from the course materials."
    context = "\n\n".join(h["document"] for h in hits)
    prompt = f"Context:\n{context}\n\nQuestion: {question}\nAnswer based only on the context above."
    # TODO: call your chosen LLM backend with `prompt`
    ...
```

The LLM backend is your pick — Ollama, Gemini, OpenAI, Claude, or HuggingFace Inference. The `retrieve` function stays the same regardless of which backend you choose.

---

## 6. Summary

In this lab you:

*   Ran a **chunking bake-off** — observed that `RecursiveCharacterTextSplitter(chunk_size=200, chunk_overlap=50)` produces chunks that retrieve specific passages, while whole-document indexing is blind to sub-topics.
*   Tuned **top-k** across k ∈ {1, 3, 5, 10} and observed the **distance cliff** that motivates a similarity threshold.
*   Built a `retrieve(query, k, min_similarity)` wrapper that converts Chroma's cosine distance to similarity and filters below-threshold matches.
*   Authored a 5-pair **gold set** and computed **hit@1 / hit@3 / hit@5** — the evaluation loop the industry skips and later regrets.
*   Finalized the `retrieve` function as a clean retrieval contract — the foundation for any RAG pipeline you choose to build independently.
