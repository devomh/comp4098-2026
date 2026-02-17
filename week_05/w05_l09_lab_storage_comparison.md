---
title: "Lab: Comparing Storage Layouts"
week: 05
type: lab
tags: [oltp, olap, row-store, column-store, performance, python]
difficulty: intermediate
duration: "60 mins"
---

# Lab: Comparing Storage Layouts

## Prerequisites & Setup

**Before starting this lab, you should:**
- Review [w05_l09_concept_oltp_vs_olap.md](w05_l09_concept_oltp_vs_olap.md) for OLTP vs. OLAP concepts
- Understand row-oriented vs. column-oriented storage
- Be familiar with Python dictionaries and lists

**What you'll build:**
In this lab, you'll simulate row-oriented and column-oriented storage in Python to understand *why* columnar storage is faster for analytical queries. You'll measure the performance difference and explore compression techniques hands-on.

**Goal:** Build intuition for how storage layout affects query performance, setting the stage for DuckDB in Lesson 10.

---

## Environment Setup

Run this setup block first to install required packages.

```python
# Setup: Run this cell first (required for Colab)
!pip install -q pandas mermaid-py

import pandas as pd
import time
import random
import sys
from mermaid import Mermaid

# Display settings
pd.set_option('display.max_columns', None)
```

---

## The Scenario: Student Records at Scale

Imagine a university with **100,000 students**. We'll generate synthetic data and compare how row-store and column-store layouts perform for different types of queries.

---

## Step 1: Generate Synthetic Data

First, let's create a realistic dataset.

```python
import random
import string

random.seed(42)  # Reproducible results

NUM_STUDENTS = 100_000

# Generate data columns
student_ids = list(range(1, NUM_STUDENTS + 1))
names = [f"Student_{i}" for i in range(1, NUM_STUDENTS + 1)]
departments = [random.choice(['CS', 'Math', 'Physics', 'English', 'Biology', 'Chemistry']) for _ in range(NUM_STUDENTS)]
gpas = [round(random.uniform(0.0, 4.0), 2) for _ in range(NUM_STUDENTS)]
credits = [random.randint(30, 150) for _ in range(NUM_STUDENTS)]
emails = [f"student{i}@university.edu" for i in range(1, NUM_STUDENTS + 1)]
years = [random.choice([2020, 2021, 2022, 2023, 2024, 2025]) for _ in range(NUM_STUDENTS)]

print(f"Generated {NUM_STUDENTS:,} student records")
print(f"Columns: student_id, name, department, gpa, credits, email, year")
```

<details>
<summary>Expected Output</summary>

```text
Generated 100,000 student records
Columns: student_id, name, department, gpa, credits, email, year
```

</details>

---

## Step 2: Simulate Row-Oriented Storage

In a row store, each "row" is a tuple/dictionary containing all columns for one record.

```python
# ROW STORE: List of dictionaries (each dict = one row)
row_store = []
for i in range(NUM_STUDENTS):
    row_store.append({
        'student_id': student_ids[i],
        'name': names[i],
        'department': departments[i],
        'gpa': gpas[i],
        'credits': credits[i],
        'email': emails[i],
        'year': years[i],
    })

# Inspect first 3 rows
for row in row_store[:3]:
    print(row)
```

<details>
<summary>Expected Output</summary>

```text
{'student_id': 1, 'name': 'Student_1', 'department': 'Biology', 'gpa': 2.5, 'credits': 109, 'email': 'student1@university.edu', 'year': 2021}
{'student_id': 2, 'name': 'Student_2', 'department': 'Math', 'gpa': 0.89, 'credits': 83, 'email': 'student2@university.edu', 'year': 2023}
{'student_id': 3, 'name': 'Student_3', 'department': 'CS', 'gpa': 1.08, 'credits': 80, 'email': 'student3@university.edu', 'year': 2020}
```

(Values may differ due to random generation, but structure is the same)

</details>

---

## Step 3: Simulate Column-Oriented Storage

In a column store, each "column" is a separate list containing all values for that attribute.

```python
# COLUMN STORE: Dictionary of lists (each key = one column)
col_store = {
    'student_id': student_ids,
    'name': names,
    'department': departments,
    'gpa': gpas,
    'credits': credits,
    'email': emails,
    'year': years,
}

# Inspect first 3 values of each column
for col_name, values in col_store.items():
    print(f"{col_name:>12}: {values[:3]}")
```

<details>
<summary>Expected Output</summary>

```text
  student_id: [1, 2, 3]
        name: ['Student_1', 'Student_2', 'Student_3']
  department: ['Biology', 'Math', 'CS']
         gpa: [2.5, 0.89, 1.08]
     credits: [109, 83, 80]
       email: ['student1@university.edu', 'student2@university.edu', 'student3@university.edu']
        year: [2021, 2023, 2020]
```

</details>

---

## Step 4: Benchmark Analytical Queries

### Query 1: Average GPA (Full Column Scan)

This is a classic OLAP query — it needs only **one column** out of seven.

```python
# --- ROW STORE: Must iterate through all rows, accessing the 'gpa' field ---
start = time.perf_counter()
total_gpa = 0
count = 0
for row in row_store:
    total_gpa += row['gpa']  # Must access each row dict to get 'gpa'
    count += 1
avg_gpa_row = total_gpa / count
row_time = time.perf_counter() - start

# --- COLUMN STORE: Directly access the 'gpa' column ---
start = time.perf_counter()
avg_gpa_col = sum(col_store['gpa']) / len(col_store['gpa'])
col_time = time.perf_counter() - start

print(f"Average GPA (Row Store):    {avg_gpa_row:.4f}  |  Time: {row_time*1000:.2f} ms")
print(f"Average GPA (Column Store): {avg_gpa_col:.4f}  |  Time: {col_time*1000:.2f} ms")
print(f"Column store speedup: {row_time/col_time:.1f}×")
```

<details>
<summary>Expected Output</summary>

```text
Average GPA (Row Store):    2.0023  |  Time: 15.23 ms
Average GPA (Column Store): 2.0023  |  Time: 2.41 ms
Column store speedup: 6.3×
```

(Times will vary, but column store should be notably faster)

</details>

**Why is column store faster?**
- Row store: Each iteration accesses a Python dictionary (hash lookup for 'gpa' key), touching all 7 fields in memory
- Column store: Direct list traversal of contiguous float values — no dictionary overhead, better cache locality

### Query 2: Count Students by Department (GROUP BY)

```python
# --- ROW STORE ---
start = time.perf_counter()
dept_counts_row = {}
for row in row_store:
    dept = row['department']
    dept_counts_row[dept] = dept_counts_row.get(dept, 0) + 1
row_time = time.perf_counter() - start

# --- COLUMN STORE ---
start = time.perf_counter()
dept_counts_col = {}
for dept in col_store['department']:
    dept_counts_col[dept] = dept_counts_col.get(dept, 0) + 1
col_time = time.perf_counter() - start

print("Department Counts:")
for dept in sorted(dept_counts_col):
    print(f"  {dept}: {dept_counts_col[dept]:,}")
print(f"\nRow Store:    {row_time*1000:.2f} ms")
print(f"Column Store: {col_time*1000:.2f} ms")
print(f"Speedup: {row_time/col_time:.1f}×")
```

<details>
<summary>Expected Output</summary>

```text
Department Counts:
  Biology: 16,745
  CS: 16,583
  Chemistry: 16,668
  English: 16,575
  Math: 16,778
  Physics: 16,651

Row Store:    14.52 ms
Column Store: 7.89 ms
Speedup: 1.8×
```

(Counts will vary slightly due to random generation)

</details>

### Query 3: Point Lookup (OLTP Pattern)

Now let's test an **OLTP-style query** — finding a single student by ID.

```python
target_id = 50_000

# --- ROW STORE (linear scan for fairness) ---
start = time.perf_counter()
result_row = None
for row in row_store:
    if row['student_id'] == target_id:
        result_row = row
        break
row_time = time.perf_counter() - start

# --- COLUMN STORE ---
start = time.perf_counter()
idx = col_store['student_id'].index(target_id)
result_col = {col: values[idx] for col, values in col_store.items()}
col_time = time.perf_counter() - start

print(f"Found student {target_id}:")
print(f"  Name: {result_row['name']}, Dept: {result_row['department']}, GPA: {result_row['gpa']}")
print(f"\nRow Store:    {row_time*1000:.2f} ms")
print(f"Column Store: {col_time*1000:.2f} ms")
print(f"Row store advantage: {col_time/row_time:.1f}×")
```

<details>
<summary>Expected Output</summary>

```text
Found student 50000:
  Name: Student_50000, Dept: CS, GPA: 3.21

Row Store:    2.15 ms
Column Store: 3.87 ms
Row store advantage: 1.8×
```

(The row store wins for point lookups because once it finds the row, all columns are right there)

</details>

**Key Insight:** Row stores win for **point lookups** (OLTP). Column stores win for **full scans and aggregations** (OLAP). Neither is universally better — it depends on the workload.

---

## Step 5: Visualize I/O Differences

Let's calculate how much data each storage layout reads for different query types.

```python
# Approximate sizes per value (bytes)
size_per_value = {
    'student_id': 4,   # integer
    'name': 20,        # avg string
    'department': 8,   # short string
    'gpa': 8,          # float
    'credits': 4,      # integer
    'email': 30,       # string
    'year': 4,         # integer
}

total_row_size = sum(size_per_value.values())  # bytes per row
total_rows = NUM_STUDENTS

# Query: SELECT AVG(gpa) FROM students
row_store_io = total_rows * total_row_size  # Must read every column of every row
col_store_io = total_rows * size_per_value['gpa']  # Only read the gpa column

print("Query: SELECT AVG(gpa) FROM students")
print(f"  Row Store I/O:    {row_store_io / 1_000_000:.1f} MB (reads ALL columns)")
print(f"  Column Store I/O: {col_store_io / 1_000_000:.1f} MB (reads only 'gpa')")
print(f"  I/O reduction:    {row_store_io / col_store_io:.0f}×")

print()

# Query: SELECT AVG(gpa), AVG(credits) FROM students (2 columns)
col_store_io_2 = total_rows * (size_per_value['gpa'] + size_per_value['credits'])
print("Query: SELECT AVG(gpa), AVG(credits) FROM students")
print(f"  Row Store I/O:    {row_store_io / 1_000_000:.1f} MB (reads ALL columns)")
print(f"  Column Store I/O: {col_store_io_2 / 1_000_000:.1f} MB (reads 2 columns)")
print(f"  I/O reduction:    {row_store_io / col_store_io_2:.0f}×")
```

<details>
<summary>Expected Output</summary>

```text
Query: SELECT AVG(gpa) FROM students
  Row Store I/O:    7.8 MB (reads ALL columns)
  Column Store I/O: 0.8 MB (reads only 'gpa')
  I/O reduction:    10×

Query: SELECT AVG(gpa), AVG(credits) FROM students
  Row Store I/O:    7.8 MB (reads ALL columns)
  Column Store I/O: 1.2 MB (reads 2 columns)
  I/O reduction:    7×
```

</details>

### Summarize Results

```python
# Summary table
summary = pd.DataFrame({
    'Query Type': [
        'AVG(gpa) — Full scan, 1 column',
        'COUNT BY department — GROUP BY',
        'Find student by ID — Point lookup'
    ],
    'Row Store': [
        f"Reads all {len(size_per_value)} columns",
        f"Reads all {len(size_per_value)} columns",
        "Finds row, all columns ready"
    ],
    'Column Store': [
        "Reads only gpa column",
        "Reads only department column",
        "Must reconstruct row from columns"
    ],
    'Winner': ['Column Store', 'Column Store', 'Row Store']
})

print(summary.to_string(index=False))
```

---

## Step 6: Compression Simulation

Let's see how much space compression saves in a column store.

### Dictionary Encoding

```python
dept_column = col_store['department']

# Calculate original size
original_size = sum(len(d) for d in dept_column)

# Build dictionary
unique_depts = list(set(dept_column))
dept_dict = {dept: i for i, dept in enumerate(unique_depts)}

# Encode
encoded_column = [dept_dict[d] for d in dept_column]

# Calculate compressed size
dict_size = sum(len(d) for d in unique_depts) + len(unique_depts) * 4
encoded_size = len(encoded_column) * 1  # 1 byte per code
compressed_size = dict_size + encoded_size

print("Dictionary Encoding — Department Column")
print(f"  Distinct values: {len(unique_depts)}")
print(f"  Dictionary: {dept_dict}")
print(f"  Original size:    {original_size:>10,} bytes ({original_size/1024:.1f} KB)")
print(f"  Compressed size:  {compressed_size:>10,} bytes ({compressed_size/1024:.1f} KB)")
print(f"  Compression ratio: {original_size/compressed_size:.1f}×")
```

<details>
<summary>Expected Output</summary>

```text
Dictionary Encoding — Department Column
  Distinct values: 6
  Dictionary: {'Biology': 0, 'Math': 1, 'Physics': 2, 'English': 3, 'CS': 4, 'Chemistry': 5}
  Original size:      648,123 bytes (633.0 KB)
  Compressed size:    100,069 bytes (97.7 KB)
  Compression ratio: 6.5×
```

</details>

### Run-Length Encoding

```python
# Sort department column first (RLE works best on sorted data)
sorted_depts = sorted(dept_column)

# RLE encode
rle_encoded = []
current_val = sorted_depts[0]
current_count = 1

for dept in sorted_depts[1:]:
    if dept == current_val:
        current_count += 1
    else:
        rle_encoded.append((current_val, current_count))
        current_val = dept
        current_count = 1
rle_encoded.append((current_val, current_count))  # Don't forget the last run

# Calculate sizes
original_size = sum(len(d) for d in sorted_depts)
rle_size = sum(len(val) + 4 for val, count in rle_encoded)  # string + 4-byte count

print("Run-Length Encoding — Sorted Department Column")
print(f"  Original entries: {len(sorted_depts):,}")
print(f"  RLE entries:      {len(rle_encoded)}")
print(f"  RLE data: {rle_encoded}")
print(f"  Original size: {original_size:>10,} bytes")
print(f"  RLE size:      {rle_size:>10,} bytes")
print(f"  Compression ratio: {original_size/rle_size:.0f}×")
```

<details>
<summary>Expected Output</summary>

```text
Run-Length Encoding — Sorted Department Column
  Original entries: 100,000
  RLE entries:      6
  RLE data: [('Biology', 16745), ('CS', 16583), ('Chemistry', 16668), ('English', 16575), ('Math', 16778), ('Physics', 16651)]
  Original size:    648,123 bytes
  RLE size:             63 bytes
  Compression ratio: 10291×
```

(RLE achieves extreme compression on sorted columns with few distinct values)

</details>

**Key Insight:** RLE achieves extreme compression on sorted, low-cardinality columns. This is why OLAP databases often **sort data by frequently-queried columns** to maximize compression.

---

## Your Turn! (Exercises)

### Exercise 1: Benchmark a Filter + Aggregate Query

**Task:** Benchmark the query: "What is the average GPA of Computer Science students?"
- Implement for both row store and column store
- Report the times and speedup

```python
# TODO: Implement filter + aggregate for both storage layouts
# Row store: iterate rows, check department == 'CS', accumulate gpa
# Column store: zip department and gpa columns, filter, compute average
```

<details>
<summary>Expected Output</summary>

```text
Average GPA of CS students (Row Store):    2.01  |  Time: 14.5 ms
Average GPA of CS students (Column Store): 2.01  |  Time: 5.2 ms
Speedup: 2.8×
```

</details>

### Exercise 2: Measure Memory Usage

**Task:** Compare the memory usage of row store vs. column store using `sys.getsizeof()`.

```python
# TODO: Use sys.getsizeof() to measure memory of both stores
# Note: sys.getsizeof() only measures the top-level object
# For nested structures, you'll need to sum up children
# Hint: For row store, sum sizes of all dicts. For column store, sum sizes of all lists.
```

<details>
<summary>Expected Output</summary>

```text
Row Store Memory:    ~38.4 MB
Column Store Memory: ~5.2 MB
Memory reduction: ~7.4×
```

(Approximate — Python object overhead varies)

</details>

### Exercise 3: Bit Packing Simulation

**Task:** Implement bit packing for the `credits` column (values range 30-150). Calculate how many bits are needed and the compression ratio vs. standard 32-bit integers.

```python
import math

# TODO: Calculate minimum bits needed for the range 30-150
# Hint: bits_needed = math.ceil(math.log2(max_val - min_val + 1))
# Compare: standard_size = NUM_STUDENTS * 32 bits
#          packed_size = NUM_STUDENTS * bits_needed
```

<details>
<summary>Expected Output</summary>

```text
Credits range: 30-150 (121 distinct values)
Bits needed: 7 (can represent 0-127)
Standard size: 3,200,000 bits (400.0 KB)
Packed size:     700,000 bits  (87.5 KB)
Compression ratio: 4.6×
```

</details>

### Exercise 4: Wide Table Penalty

**Task:** Create a "wide" row store with 50 columns but run a query that only needs 1 column. Compare the performance against the column store. This demonstrates why column stores become increasingly advantageous as tables get wider.

```python
# TODO: Add 43 more "dummy" columns to make it 50 columns total
# Then benchmark AVG(gpa) on both stores
# Hint: wide_row_store = [{**row, 'col_8': 0, 'col_9': 0, ...} for row in row_store]
```

<details>
<summary>Expected Output</summary>

```text
Wide table (50 columns), Query: AVG(gpa)
  Row Store:    ~25 ms  (must touch all 50 columns per row)
  Column Store: ~2.5 ms (still reads only gpa column)
  Speedup: ~10×
```

</details>

---

## Summary

In this lab, you have successfully:

1. Simulated row-oriented and column-oriented storage in Python
2. Benchmarked analytical queries (aggregations, GROUP BY) — column store wins
3. Benchmarked point lookups — row store wins
4. Calculated I/O differences between storage layouts
5. Implemented Dictionary Encoding and Run-Length Encoding compression
6. Demonstrated why the right storage layout depends on the workload

**Key Takeaways:**

- **Column stores excel at analytics** — reading only needed columns, achieving high compression
- **Row stores excel at transactions** — fast single-row access, efficient writes
- **Compression amplifies the column store advantage** — less data to read means faster queries
- **Neither is universally better** — match your storage engine to your workload

**What's Next:**

In [Lesson 10](w05_l10_concept_intro_duckdb.md), you'll move from simulation to reality — using **DuckDB**, a production-grade columnar OLAP engine, to query CSV and Parquet files with SQL.
