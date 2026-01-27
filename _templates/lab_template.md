---
title: "Lab Title (e.g., Intro to DuckDB)"
week: 00
type: lab
tags: [tag1, tag2]
difficulty: introductory
duration: "60 mins"
---

# Lab: [Lesson Title]

## 1. Prerequisites & Setup
*   **Required Libraries:** `pandas`, `duckdb`, `sqlalchemy`
*   **Data:** Ensure `data/dataset.csv` is present.

### Environment Setup
Run this block first to install packages and initialize your environment.
```python
# Setup: Run this cell first (required for Colab)
!pip install -q pandas duckdb sqlalchemy mermaid-py

import pandas as pd
import duckdb
# from mermaid import Mermaid  # Uncomment if using Mermaid diagrams

# Display settings
pd.set_option('display.max_columns', None)
```

---

## 2. Step 1: [Task Name]
*Brief explanation of what we are doing.*

### The "Naive" Approach
*Show the simple/inefficient way first (if applicable).*
```python
# Code snippet
```

### The "Better" Approach
*Show the optimized or idiomatic way.*
```python
# Optimized code
```

<details>
<summary>Expected Output</summary>

```text
(Show what the result should look like)
```
</details>

---

## 3. Step 2: [Task Name]
Explain the next logical step.

```python
# Code snippet
```

---

## 4. Your Turn! (Exercises)
Now it's your turn to apply what you've learned.

### Exercise 1
**Task:** [Describe task]
**Hint:** Use the `GROUP BY` clause.

```python
# TODO: Write your code here
```

<details>
<summary>Expected Output</summary>

```text
(Expected result for Exercise 1)
```
</details>

### Exercise 2
**Task:** [Describe task]

```python
# TODO: Write your code here
```

<details>
<summary>Expected Output</summary>

```text
(Expected result for Exercise 2)
```
</details>

---

## 5. Summary
Briefly summarize the commands or patterns mastered in this lab.
