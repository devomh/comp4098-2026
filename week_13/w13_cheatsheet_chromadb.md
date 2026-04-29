---
title: "ChromaDB Quick Reference"
week: 13
type: reference
tags: [chromadb, vector-search, embeddings, cheatsheet]
difficulty: intermediate
---

# ChromaDB Quick Reference

---

## Clients

```python
import chromadb

# In-memory — resets when the process ends
client = chromadb.EphemeralClient()

# Persistent — reads/writes to disk
client = chromadb.PersistentClient(path="./chroma_db")

# Remote server
client = chromadb.HttpClient(host="localhost", port=8000)
```

---

## Collections

```python
# Create (errors if name already exists)
col = client.create_collection(name="my_collection")

# Open existing (errors if name does not exist)
col = client.get_collection(name="my_collection")

# Open or create
col = client.get_or_create_collection(name="my_collection")

# List all collection names
client.list_collections()          # returns list of Collection objects

# Delete
client.delete_collection(name="my_collection")

# Document count
col.count()
```

### Custom embedding function

```python
from chromadb.utils import embedding_functions

ef = embedding_functions.SentenceTransformerEmbeddingFunction(
    model_name="all-MiniLM-L6-v2"  # or "all-mpnet-base-v2", etc.
)

col = client.get_or_create_collection(
    name="my_collection",
    embedding_function=ef,
)
```

If `embedding_function` is omitted, Chroma uses its built-in `DefaultEmbeddingFunction`
(`all-MiniLM-L6-v2` via ONNX). Pass the **same** function at ingest time and query time.

---

## Adding Documents

```python
col.add(
    documents=["text one", "text two"],   # raw text — Chroma embeds automatically
    ids=["id_0", "id_1"],                 # required, must be unique strings
    metadatas=[{"source": "a"}, {"source": "b"}],  # optional
)
```

To supply your own vectors instead of letting Chroma embed:

```python
col.add(
    embeddings=[[0.1, 0.2, ...], [0.4, 0.5, ...]],
    ids=["id_0", "id_1"],
    metadatas=[...],   # optional
)
```

Both `documents` and `embeddings` can be provided together; Chroma stores both.

---

## Querying

```python
results = col.query(
    query_texts=["my query"],   # Chroma embeds the query
    n_results=5,
    where={"category": "shipping"},   # optional metadata filter
    include=["documents", "metadatas", "distances"],  # default
)
```

Result structure (each value is a list-of-lists — one inner list per query):

```python
results["ids"]        # [["id_3", "id_1", ...]]
results["documents"]  # [["text ...", "text ...", ...]]
results["metadatas"]  # [[{"category": "shipping"}, ...]]
results["distances"]  # [[0.41, 0.55, ...]]   lower = more similar
```

To query with a pre-computed vector:

```python
results = col.query(
    query_embeddings=[[0.1, 0.2, ...]],
    n_results=5,
)
```

### `include` options

| Value | Description |
| :--- | :--- |
| `"documents"` | Raw text (default) |
| `"metadatas"` | Metadata dicts (default) |
| `"distances"` | L2 / cosine distance (default) |
| `"embeddings"` | Stored vectors (not returned by default) |

---

## Getting Documents (no similarity ranking)

```python
# All documents
col.get()

# By IDs
col.get(ids=["id_0", "id_1"])

# By metadata filter
col.get(where={"module": 2})

# Limit results
col.get(limit=10, offset=0)

# Quick peek at the first N documents
col.peek(limit=5)
```

`get()` also accepts `include=` with the same options as `query()`.

---

## Updating & Deleting

```python
# Update existing documents (errors on unknown IDs)
col.update(
    ids=["id_0"],
    documents=["updated text"],
    metadatas=[{"category": "billing"}],
)

# Upsert — insert if new, update if exists
col.upsert(
    documents=["text"],
    ids=["id_0"],
    metadatas=[{"category": "billing"}],
)

# Delete by IDs
col.delete(ids=["id_0", "id_1"])

# Delete by filter
col.delete(where={"category": "billing"})
```

---

## Metadata Filters (`where=`)

### Simple equality

```python
where={"category": "shipping"}                  # shorthand
where={"category": {"$eq": "shipping"}}         # explicit
```

### Comparison operators

| Operator | Meaning | Example |
| :--- | :--- | :--- |
| `$eq` | equals | `{"week": {"$eq": 3}}` |
| `$ne` | not equals | `{"week": {"$ne": 3}}` |
| `$gt` | greater than | `{"week": {"$gt": 5}}` |
| `$gte` | greater than or equal | `{"week": {"$gte": 5}}` |
| `$lt` | less than | `{"week": {"$lt": 9}}` |
| `$lte` | less than or equal | `{"week": {"$lte": 9}}` |
| `$in` | value in list | `{"module": {"$in": [1, 2]}}` |
| `$nin` | value not in list | `{"module": {"$nin": [3]}}` |

### Logical operators

```python
# AND — both conditions must match
where={"$and": [{"module": {"$eq": 2}}, {"week": {"$gt": 5}}]}

# OR — either condition must match
where={"$or": [{"category": "shipping"}, {"category": "refunds"}]}
```

---

## Distance & Similarity

Chroma returns **distance** (lower = more similar). The default metric is
**L2** (squared Euclidean). To use cosine distance, set it at collection creation:

```python
col = client.get_or_create_collection(
    name="my_collection",
    metadata={"hnsw:space": "cosine"},
)
```

| `hnsw:space` value | Metric |
| :--- | :--- |
| `"l2"` (default) | Squared Euclidean |
| `"cosine"` | Cosine distance (= 1 − cosine similarity) |
| `"ip"` | Inner product |

---

## Common Patterns

### Ingest a list of texts with metadata

```python
col.add(
    documents=texts,
    ids=[f"doc_{i}" for i in range(len(texts))],
    metadatas=[{"source": src} for src in sources],
)
```

### Retrieve top-k with a filter, then inspect

```python
res = col.query(query_texts=["my question"], n_results=3,
                where={"module": 2})
for doc_id, doc, dist in zip(res["ids"][0], res["documents"][0], res["distances"][0]):
    print(f"[{dist:.3f}] {doc_id}  {doc[:80]}")
```

### Extract stored embeddings for downstream use (e.g., PCA)

```python
data = col.get(include=["embeddings", "metadatas"])
import numpy as np
X = np.array(data["embeddings"])   # shape: (n_docs, embedding_dim)
```
