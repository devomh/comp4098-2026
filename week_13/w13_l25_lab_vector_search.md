---
title: "Lab: Embeddings & Vector Search with ChromaDB"
week: 13
type: lab
tags: [vector-search, embeddings, chromadb, semantic-search, lab]
difficulty: intermediate
duration: "50 mins"
---

# Lab: Embeddings & Vector Search with ChromaDB

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/devomh/comp4098-2026/blob/main/week_13/w13_l25_lab_vector_search.ipynb)

## Prerequisites & What You'll Build

**Before starting:**
*   Review [w13_l25_concept_embeddings_vector_search.md](w13_l25_concept_embeddings_vector_search.md) for the theory behind embeddings, cosine similarity, and vector databases.
*   Comfort with `numpy` arrays and basic Python.

**What you'll accomplish:**

1.  Load a `sentence-transformers` model and embed text by hand.
2.  Compute cosine similarity with `numpy` on three canonical strings.
3.  Switch to ChromaDB — watch the same results appear with 10× less code.
4.  Add **metadata filters** to combine semantic search with structured constraints.
5.  Clone the **course repository**, ingest the 21 concept files from weeks 1–11 into a **persistent** Chroma collection, and verify that the collection survives a fresh client handle.
6.  (Stretch) Swap embedding models and project embeddings to 2D.

The persistent collection you build in §5 (`./chroma_db`, collection name `course_concepts`) **is the input to the L26 lab**. Do not delete it between lessons.

---

## 1. Setup

The setup cell installs Chroma and `sentence-transformers`, loads the embedding model, and prints a sanity check. Run it once, top to bottom.

```python
# Setup: Run this cell first (required for Colab)
!pip install -q chromadb sentence-transformers

import numpy as np
import chromadb
from sentence_transformers import SentenceTransformer

MODEL_NAME = "all-MiniLM-L6-v2"
model = SentenceTransformer(MODEL_NAME)
print(f"Model loaded: {MODEL_NAME}, embedding dim = {model.get_sentence_embedding_dimension()}")
```

<details>
<summary>Expected Output</summary>

~~~text
Model loaded: all-MiniLM-L6-v2, embedding dim = 384
~~~

(The first run downloads ~90 MB of model weights and takes 15–30 seconds. Subsequent runs in the same Colab session are instant.)

</details>

---

## 2. Embeddings Are Just Vectors

Before we touch any database, let's prove the core claim: an embedding model turns text into numeric vectors, and related text produces nearby vectors.

### 2.1 Embed Three Canonical Strings

```python
texts = [
    "I can't log in",
    "authentication error",
    "cheese pizza recipe",
]

vectors = model.encode(texts)
print(f"Shape: {vectors.shape}")
print(f"First 8 dims of vector[0]: {vectors[0][:8]}")
```

<details>
<summary>Expected Output</summary>

~~~text
Shape: (3, 384)
First 8 dims of vector[0]: [ 0.04  -0.03   0.07  -0.02   0.11  -0.05   0.02   0.08 ]
~~~

(The exact floats will vary; the point is: 3 input strings → a (3, 384) array.)

</details>

### 2.2 Cosine Similarity by Hand

```python
def cosine(a, b):
    return float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b)))
```

```python
s_01 = cosine(vectors[0], vectors[1])
s_02 = cosine(vectors[0], vectors[2])
s_12 = cosine(vectors[1], vectors[2])

print(f"cosine(\"I can't log in\",        \"authentication error\") = {s_01:.3f}")
print(f"cosine(\"I can't log in\",        \"cheese pizza recipe\")  = {s_02:.3f}")
print(f"cosine(\"authentication error\",  \"cheese pizza recipe\")  = {s_12:.3f}")
```

<details>
<summary>Expected Output</summary>

~~~text
cosine("I can't log in",        "authentication error") = 0.68
cosine("I can't log in",        "cheese pizza recipe")  = 0.06
cosine("authentication error",  "cheese pizza recipe")  = 0.04
~~~

(Exact values will vary by a few hundredths; the qualitative split — first pair ≫ other two — is stable.)

</details>

### Observation

The first pair — `"I can't log in"` and `"authentication error"` — scores an order of magnitude higher than either paired with `"cheese pizza recipe"`. **No lexical overlap** exists between the first pair: they share no word except `"I"`, which the model largely ignores. Similarity here comes from the model's **training**, not from lookup, pattern matching, or a thesaurus. The model has never seen these exact strings; it has seen enough related text during training to place them near each other in its 384-dimensional space.

### 2.3 Your Turn — Extend the Probe

```python
# TODO: Add 2 more strings of your own choice and compute their cosine
# similarity against "authentication error". Try to produce one "related"
# hit (similarity > 0.4) and one "unrelated" miss (similarity < 0.2).

your_strings = [
    # e.g., "password reset not working",
    # e.g., "banana bread recipe",
]

# TODO: for each string, print its similarity to vectors[1].
```

<details>
<summary>Solution</summary>

~~~python
your_strings = [
    "password reset not working",
    "banana bread recipe",
]
your_vectors = model.encode(your_strings)
for text, vec in zip(your_strings, your_vectors):
    print(f"cosine({text!r:40s} vs 'authentication error') = {cosine(vec, vectors[1]):.3f}")
~~~

Expected: the password string scores well above 0.4, the banana bread string well below 0.2.

</details>

---

## 3. From Manual Similarity to ChromaDB

Hand-computing cosine works for 3 strings. It does not scale to 3,000. Chroma handles embedding, storage, indexing, and nearest-neighbor search for us.

### 3.1 Create an In-Memory Client

```python
client = chromadb.Client()  # in-memory; resets each run

# Throwaway collection for the toy corpus — do NOT reuse this name in §5.
toy_collection = client.get_or_create_collection(name="toy")
print(f"Collection created: {toy_collection.name}")
```

### 3.2 The Toy Corpus

Thirty short customer-support messages covering three topics. The triples let us see clustering later.

```python
TOY_CORPUS = [
    # Billing / authentication (indices 0–9)
    "I can't log in to my account",
    "Authentication error on the login page",
    "My password reset email never arrived",
    "Two-factor authentication is not working",
    "Locked out after too many failed attempts",
    "Cannot access my account on mobile",
    "Forgot my username, how do I recover it?",
    "My session keeps expiring after a few minutes",
    "Single sign-on redirects to a blank page",
    "Login button does nothing when clicked",
    # Shipping / logistics (indices 10–19)
    "Where is my package?",
    "My order has not been delivered yet",
    "The tracking number shows no updates",
    "I received the wrong item in my order",
    "Package arrived damaged in shipping",
    "How do I change my delivery address?",
    "Shipping is taking longer than promised",
    "My order was marked delivered but I did not receive it",
    "Can I expedite shipping on an existing order?",
    "The carrier left my package at the wrong address",
    # Refunds / returns (indices 20–29)
    "How do I return an item for a refund?",
    "Refund has not appeared on my credit card",
    "Item does not match the description on the website",
    "Can I exchange this for a different size?",
    "What is your return policy for electronics?",
    "My refund was smaller than expected",
    "I need to cancel my order before it ships",
    "The product stopped working after one week",
    "Requesting a refund for a duplicate charge",
    "Warranty claim for a defective product",
]

print(f"Toy corpus size: {len(TOY_CORPUS)}")
```

### 3.3 Ingest the Toy Corpus

```python
toy_collection.add(
    documents=TOY_CORPUS,
    ids=[f"toy_{i}" for i in range(len(TOY_CORPUS))],
)
print(f"Collection count: {toy_collection.count()}")
```

<details>
<summary>Expected Output</summary>

~~~text
Collection count: 30
~~~

</details>

Notice what you did **not** write: a call to `model.encode()`, a distance function, or an index-build step. Chroma ran `all-MiniLM-L6-v2` as its default embedding function and built an HNSW index under the hood.

### 3.4 Query the Toy Corpus

```python
results = toy_collection.query(
    query_texts=["I'm locked out"],
    n_results=5,
)

for rank, (doc, dist) in enumerate(zip(results["documents"][0], results["distances"][0]), 1):
    print(f"  {rank}. [{dist:.3f}]  {doc}")
```

<details>
<summary>Expected Output</summary>

~~~text
  1. [0.41]  Locked out after too many failed attempts
  2. [0.48]  I can't log in to my account
  3. [0.52]  Login button does nothing when clicked
  4. [0.55]  Two-factor authentication is not working
  5. [0.58]  Cannot access my account on mobile
~~~

(Distances will vary slightly; **all five top results come from the billing/auth group** (indices 0–9). Remember: Chroma returns *distance*, so smaller is better. Similarity = 1 − distance.)

</details>

Chroma's result matches what §2 predicted with raw `numpy`: the model groups "locked out" near the auth cluster and far from shipping or refunds.

### 3.5 Your Turn — Query the Other Two Topics

```python
# TODO: Run two queries, one for each remaining topic group,
# and confirm the top-3 results come from the expected cluster.

# Query 1 (shipping-flavored): something like "where's my delivery"
# Query 2 (refund-flavored):   something like "I want my money back"

# Print id, distance, and document for the top 3 of each.
```

<details>
<summary>Solution</summary>

~~~python
for q in ["where's my delivery", "I want my money back"]:
    print(f"\nQuery: {q!r}")
    res = toy_collection.query(query_texts=[q], n_results=3)
    for doc_id, doc, dist in zip(res["ids"][0], res["documents"][0], res["distances"][0]):
        print(f"  [{dist:.3f}] {doc_id}  {doc}")
~~~

Top 3 for `"where's my delivery"` should all be in the shipping block (indices 10–19). Top 3 for `"I want my money back"` should all be in the refunds block (indices 20–29).

</details>

---

## 4. Metadata Filtering

Semantic search is useful. Semantic search **plus structured filters** is what makes a vector database beat a hand-rolled `numpy` loop. Let's tag every document with its topic and see what changes.

### 4.1 Rebuild the Collection With Metadata

```python
# Delete the old collection and start fresh
client.delete_collection(name="toy")
toy_collection = client.create_collection(name="toy")

categories = (["billing"] * 10) + (["shipping"] * 10) + (["refunds"] * 10)
metadatas = [{"category": cat} for cat in categories]

toy_collection.add(
    documents=TOY_CORPUS,
    metadatas=metadatas,
    ids=[f"toy_{i}" for i in range(len(TOY_CORPUS))],
)
print(f"Rebuilt with metadata. Count: {toy_collection.count()}")
```

<details>
<summary>Expected Output</summary>

~~~text
Rebuilt with metadata. Count: 30
~~~

</details>

### 4.2 Query Without a Filter

```python
query = "help me with my order"

unfiltered = toy_collection.query(query_texts=[query], n_results=5)
print(f"Query: {query!r} (no filter)")
for doc, meta, dist in zip(unfiltered["documents"][0], unfiltered["metadatas"][0], unfiltered["distances"][0]):
    print(f"  [{dist:.3f}] ({meta['category']:8s})  {doc}")
```

<details>
<summary>Expected Output</summary>

~~~text
Query: 'help me with my order' (no filter)
  [0.58] (shipping)  My order has not been delivered yet
  [0.62] (shipping)  I need to cancel my order before it ships   (← may show 'refunds' on your run)
  [0.65] (refunds)   I need to cancel my order before it ships
  [0.68] (shipping)  Can I expedite shipping on an existing order?
  [0.71] (refunds)   How do I return an item for a refund?
~~~

(Results span **shipping and refunds** because "order" is an ambiguous signal. Exact ordering varies.)

</details>

### 4.3 Same Query, Restricted to Shipping

```python
filtered = toy_collection.query(
    query_texts=[query],
    n_results=5,
    where={"category": "shipping"},
)
print(f"Query: {query!r}  where category = 'shipping'")
for doc, meta, dist in zip(filtered["documents"][0], filtered["metadatas"][0], filtered["distances"][0]):
    print(f"  [{dist:.3f}] ({meta['category']:8s})  {doc}")
```

<details>
<summary>Expected Output</summary>

~~~text
Query: 'help me with my order'  where category = 'shipping'
  [0.58] (shipping)  My order has not been delivered yet
  [0.68] (shipping)  Can I expedite shipping on an existing order?
  [0.69] (shipping)  Where is my package?
  [0.71] (shipping)  Shipping is taking longer than promised
  [0.74] (shipping)  My order has not been delivered yet  (may vary)
~~~

(All 5 results are in the `shipping` category; the semantic ranking within that category is preserved.)

</details>

### Callout — Tie Back to Module 3

This combination — **structured filters + semantic search in one query** — is what a dedicated vector engine offers. It is structurally analogous to MongoDB's `$match` stage after a `$group`, or to a SQL `WHERE` clause on top of a full-text-search ranking. Rolling this yourself on top of `numpy` means pre-filtering the corpus, re-embedding, re-computing cosines, and maintaining two parallel data structures. Chroma folds it into one call.

---

## 5. Persistence & the Course-Concepts Corpus

Everything so far has been in-memory and will vanish when Colab resets. This section clones the **public course repository**, copies the 21 concept files from Module 1–3, and ingests them into a **persistent** Chroma collection. This collection is the input to the L26 lab.

### 5.1 Clone the Course Repo and Prepare `./corpus/`

```python
import os, re, shutil, subprocess

REPO_URL = "https://github.com/devomh/comp4098-2026.git"

# Fresh clone (shallow) into /tmp — avoids polluting the Colab workspace.
if os.path.exists("/tmp/course_repo"):
    shutil.rmtree("/tmp/course_repo")
subprocess.run(
    ["git", "clone", "--depth", "1", REPO_URL, "/tmp/course_repo"],
    check=True,
)

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

if os.path.exists("./corpus"):
    shutil.rmtree("./corpus")
os.makedirs("./corpus", exist_ok=True)

for rel in CONCEPT_FILES:
    src = f"/tmp/course_repo/{rel}"
    dst = f"./corpus/{os.path.basename(rel)}"
    shutil.copy(src, dst)

print(f"Copied {len(os.listdir('./corpus'))} files to ./corpus/")
```

<details>
<summary>Expected Output</summary>

~~~text
Copied 21 files to ./corpus/
~~~

</details>

### 5.2 Strip YAML Frontmatter

Every concept file begins with a YAML block between two `---` lines. That metadata is already captured in filenames; keeping it in the document body only pollutes embeddings. Strip it before ingesting.

```python
def strip_frontmatter(text: str) -> str:
    """Remove a YAML frontmatter block delimited by two '---' lines."""
    if text.lstrip().startswith("---"):
        # Find the closing '---' after the opening one
        parts = text.split("---", 2)
        if len(parts) >= 3:
            return parts[2].lstrip()
    return text

# Sanity check on one file
with open("./corpus/w01_l01_concept_intro_lifecycle.md") as f:
    raw = f.read()
clean = strip_frontmatter(raw)
print(f"Raw first line:   {raw.splitlines()[0]!r}")
print(f"Clean first line: {clean.splitlines()[0]!r}")
```

<details>
<summary>Expected Output</summary>

~~~text
Raw first line:   '---'
Clean first line: '# Module 1: The Data Lifecycle'   (exact first heading varies)
~~~

</details>

### 5.3 Ingest Into a Persistent Chroma Collection

Metadata per document: `week`, `lesson`, `module`, `filename`. The module assignment follows the course structure.

```python
def derive_metadata(filename: str) -> dict:
    """Extract week, lesson, module, filename from e.g. 'w03_l05_concept_normalization.md'."""
    m = re.match(r"w(\d+)_l(\d+)_concept_.+\.md$", filename)
    if not m:
        raise ValueError(f"Unexpected filename: {filename}")
    week = int(m.group(1))
    lesson = int(m.group(2))
    if week <= 4:
        module = 1
    elif week <= 8:
        module = 2
    else:
        module = 3
    return {"week": week, "lesson": lesson, "module": module, "filename": filename}

# Example
print(derive_metadata("w03_l05_concept_normalization.md"))
```

<details>
<summary>Expected Output</summary>

~~~text
{'week': 3, 'lesson': 5, 'module': 1, 'filename': 'w03_l05_concept_normalization.md'}
~~~

</details>

```python
# Remove any stale persistent DB from a previous run of this lab.
if os.path.exists("./chroma_db"):
    shutil.rmtree("./chroma_db")

persistent_client = chromadb.PersistentClient(path="./chroma_db")
collection = persistent_client.get_or_create_collection(name="course_concepts")

docs, ids, metas = [], [], []
for filename in sorted(os.listdir("./corpus")):
    if not filename.endswith(".md"):
        continue
    with open(f"./corpus/{filename}") as f:
        body = strip_frontmatter(f.read())
    docs.append(body)
    ids.append(filename)
    metas.append(derive_metadata(filename))

collection.add(documents=docs, ids=ids, metadatas=metas)
print(f"Collection size: {collection.count()}")
```

<details>
<summary>Expected Output</summary>

~~~text
Collection size: 21
~~~

</details>

### 5.4 Verify Persistence

A persistent client writes to disk. Opening a fresh client against the same path must see the same data.

```python
verify_client = chromadb.PersistentClient(path="./chroma_db")
verify_collection = verify_client.get_collection(name="course_concepts")
print(f"Persistence verified: {verify_collection.count()} documents")
```

<details>
<summary>Expected Output</summary>

~~~text
Persistence verified: 21 documents
~~~

</details>

### 5.5 Query the Course Corpus

Three probing queries that exercise different parts of the corpus. Each should surface the right concept file.

```python
queries = [
    "What is the CAP theorem?",
    "How do window functions work?",
    "How do I prevent SQL injection?",
]

for q in queries:
    print(f"\nQuery: {q}")
    res = collection.query(query_texts=[q], n_results=3)
    for doc_id, meta, dist in zip(res["ids"][0], res["metadatas"][0], res["distances"][0]):
        print(f"  [{dist:.3f}] w{meta['week']:02d} L{meta['lesson']:02d} (mod {meta['module']})  {doc_id}")
```

<details>
<summary>Expected Output</summary>

~~~text
Query: What is the CAP theorem?
  [0.72] w09 L17 (mod 3)  w09_l17_concept_nosql_document_model.md
  [0.98] w08 L15 (mod 2)  w08_l15_concept_data_at_scale.md
  [1.04] w11 L21 (mod 3)  w11_l21_concept_redis_keyvalue.md

Query: How do window functions work?
  [0.65] w07 L13 (mod 2)  w07_l13_concept_window_functions.md
  [1.02] w07 L14 (mod 2)  w07_l14_concept_ctes_advanced.md
  [1.08] w06 L12 (mod 2)  w06_l12_concept_aggregation_grouping.md

Query: How do I prevent SQL injection?
  [0.68] w11 L22 (mod 3)  w11_l22_concept_data_security.md
  [1.10] w04 L08 (mod 1)  w04_l08_concept_dml_querying.md
  [1.15] w04 L07 (mod 1)  w04_l07_concept_ddl_schema.md
~~~

(Exact distances will vary; the **top-1 result** for each query should be the concept file named in bold above.)

</details>

### 5.6 Your Turn — Your Topic

```python
# TODO: Write a query about any topic from weeks 1–11
# (normalization, Redis, DuckDB, ER modeling, aggregation, ...).
# Confirm the top-1 result is the concept file you'd expect.

my_query = "..."

# TODO: collection.query(...) and print id + distance + first 80 chars of the doc
```

<details>
<summary>Solution</summary>

~~~python
my_query = "What is denormalization and when should I use it?"
res = collection.query(query_texts=[my_query], n_results=3)
for doc_id, doc, dist in zip(res["ids"][0], res["documents"][0], res["distances"][0]):
    print(f"[{dist:.3f}] {doc_id}")
    print(f"    {doc[:80].strip()}...")
~~~

Expected top-1: `w03_l06_concept_denormalization.md`.

</details>

---

## 6. Exercises (Optional Stretch)

### Exercise 1: Swap the Embedding Model

**Task:** Load `all-mpnet-base-v2` (768 dimensions, higher quality but ~5× slower). Re-ingest the 21 concept files into a new collection `course_concepts_mpnet`. Run the three queries from §5.5 against both collections and compute the **top-3 overlap** per query.

**Hint:** Use `chromadb.utils.embedding_functions.SentenceTransformerEmbeddingFunction(model_name="all-mpnet-base-v2")` when creating the new collection so Chroma uses the larger model for both ingest and query.

```python
# TODO: Create `course_concepts_mpnet`, ingest the same 21 files with mpnet embeddings,
# run the §5.5 queries against both, print a table of top-3 overlap per query.
```

<details>
<summary>Hints</summary>

~~~python
from chromadb.utils import embedding_functions

mpnet_ef = embedding_functions.SentenceTransformerEmbeddingFunction(
    model_name="all-mpnet-base-v2",
)
# Use embedding_function=mpnet_ef when creating the new collection.
# For each query, take set(top3_minilm) & set(top3_mpnet) to compute overlap.
~~~

You should find high overlap (2–3 shared ids out of 3) for well-posed queries. The models *agree* more often than they *disagree* on this corpus, which is itself an interesting observation.

</details>

### Exercise 2: PCA Visualization

**Task:** Extract all 21 embeddings from the `course_concepts` collection, reduce to 2D with PCA, plot with `matplotlib`, and color points by `module` (1, 2, or 3). Do the modules form visible clusters?

**Hint:** `collection.get(include=["embeddings", "metadatas"])` returns the stored vectors. Use `sklearn.decomposition.PCA(n_components=2)`.

```python
# TODO: retrieve embeddings + metadatas, run PCA to 2D, scatter-plot colored by module.
```

<details>
<summary>Hints</summary>

~~~python
!pip install -q scikit-learn matplotlib
import matplotlib.pyplot as plt
from sklearn.decomposition import PCA

data = collection.get(include=["embeddings", "metadatas"])
X = np.array(data["embeddings"])
modules = np.array([m["module"] for m in data["metadatas"]])

coords = PCA(n_components=2).fit_transform(X)

for mod in [1, 2, 3]:
    mask = modules == mod
    plt.scatter(coords[mask, 0], coords[mask, 1], label=f"Module {mod}")
plt.legend(); plt.title("Course concepts in 2D (PCA)"); plt.show()
~~~

Typical outcome: Module 1 (relational foundations) and Module 2 (analytical SQL) cluster near each other; Module 3 (NoSQL) sits somewhat apart. The split is not perfect — the concepts *do* share vocabulary — but it's visible.

</details>

---

## 7. Handoff to L26

The `./chroma_db` directory and the `course_concepts` collection are the **input to the L26 lab**. Do not delete them. If your Colab session resets between lessons, rerun §5 of this lab to rebuild from scratch — the L26 setup cell also contains a fallback that does this automatically.

### Summary

In this lab you:

*   Loaded the `all-MiniLM-L6-v2` model and embedded text by hand into 384-dimensional vectors.
*   Computed **cosine similarity** with `numpy` and verified that `"I can't log in"` ≈ `"authentication error"` at the embedding level.
*   Switched to **ChromaDB**, ingested a 30-document toy corpus, and ran `collection.query(...)` — same result, far less code.
*   Added **metadata** (`category`) and used `where={"category": "shipping"}` to combine semantic search with structured filtering.
*   Cloned the course repo, ingested the **21 course concept files** from weeks 1–11 into a **persistent** Chroma collection `course_concepts` at `./chroma_db`.
*   Verified persistence by opening a fresh client and ran three probing queries that each surfaced the right concept file.

**Next:** L26 builds on this corpus. You'll chunk documents, tune retrieval, and measure quality with a hand-built gold set.
