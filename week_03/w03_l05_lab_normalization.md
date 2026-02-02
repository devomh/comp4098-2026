---
title: "Lab: Normalizing a Messy Dataset"
week: 03
type: lab
tags: [normalization, data integrity, sql]
difficulty: intermediate
duration: "60 mins"
---

# Lab: Normalizing a Messy Dataset

## 1. Prerequisites & Setup
*   **Context:** This lab applies the normalization theory from Lesson 5.
*   **Goal:** Take a denormalized "flat" table and progressively normalize it to 3NF.
*   **Concept Review:** Ensure you have read `w03_l05_concept_normalization.md`.

### Environment Setup
Run this block first to set up the environment and load our messy data.
```python
# Setup: Run this cell first (required for Colab)
# NOTE: Run cells in order. If you need to restart, re-run this cell first.
!pip install -q pandas mermaid-py

import pandas as pd
from mermaid import Mermaid

pd.set_option('display.max_columns', None)
print("Setup complete! Ready for normalization exercises.")
```

---

## 2. The Scenario: A Messy Orders Table
You've inherited a database from a small e-commerce company. They've been storing everything in one big "flat" table. Your job: normalize it.

### The Raw Data
```python
# Create our messy "orders" table
messy_data = {
    'order_id': [1001, 1001, 1002, 1002, 1002, 1003],
    'order_date': ['2024-01-15', '2024-01-15', '2024-01-16', '2024-01-16', '2024-01-16', '2024-01-17'],
    'customer_id': [501, 501, 502, 502, 502, 501],
    'customer_name': ['Alice Smith', 'Alice Smith', 'Bob Jones', 'Bob Jones', 'Bob Jones', 'Alice Smith'],
    'customer_email': ['alice@email.com', 'alice@email.com', 'bob@email.com', 'bob@email.com', 'bob@email.com', 'alice@email.com'],
    'customer_city': ['New York', 'New York', 'Los Angeles', 'Los Angeles', 'Los Angeles', 'New York'],
    'product_id': ['P001', 'P002', 'P001', 'P003', 'P004', 'P002'],
    'product_name': ['Widget A', 'Widget B', 'Widget A', 'Gadget X', 'Gadget Y', 'Widget B'],
    'product_category': ['Widgets', 'Widgets', 'Widgets', 'Gadgets', 'Gadgets', 'Widgets'],
    'unit_price': [10.00, 15.00, 10.00, 25.00, 30.00, 15.00],
    'quantity': [2, 1, 3, 1, 2, 4],
}

df_messy = pd.DataFrame(messy_data)
df_messy
```

<details>
<summary>Expected Output</summary>

~~~text
   order_id  order_date  customer_id customer_name   customer_email  customer_city product_id product_name product_category  unit_price  quantity
0      1001  2024-01-15          501   Alice Smith  alice@email.com       New York       P001     Widget A          Widgets       10.00         2
1      1001  2024-01-15          501   Alice Smith  alice@email.com       New York       P002     Widget B          Widgets       15.00         1
2      1002  2024-01-16          502     Bob Jones    bob@email.com    Los Angeles       P001     Widget A          Widgets       10.00         3
3      1002  2024-01-16          502     Bob Jones    bob@email.com    Los Angeles       P003     Gadget X          Gadgets       25.00         1
4      1002  2024-01-16          502     Bob Jones    bob@email.com    Los Angeles       P004     Gadget Y          Gadgets       30.00         2
5      1003  2024-01-17          501   Alice Smith  alice@email.com       New York       P002     Widget B          Widgets       15.00         4
~~~

</details>

---

## 3. Step 1: Identify the Problems

Before normalizing, let's identify the anomalies.

### Discussion Questions
Look at the data and answer:

1.  **Update Anomaly:** If Alice changes her email, how many rows need updating?
2.  **Delete Anomaly:** If we delete order 1002, what customer information do we lose?
3.  **Insert Anomaly:** Can we add a new product "Gadget Z" without an order?

```python
# Count how many times each customer appears
print("Customer repetition (update anomaly risk):")
print(df_messy.groupby('customer_id')['customer_name'].count())
```

<details>
<summary>Expected Output</summary>

~~~text
Customer repetition (update anomaly risk):
customer_id
501    3
502    3
Name: customer_name, dtype: int64
~~~

Alice's data is repeated 3 times, Bob's data is repeated 3 times. Any update to their info requires changing multiple rows!

</details>

---

## 4. Step 2: Check 1NF (Atomicity)

### Is our table in 1NF?

**1NF Checklist:**
- [x] All columns have atomic values (no lists or arrays)
- [x] No repeating groups (no `product1`, `product2`, `product3` columns)
- [x] Rows are distinguishable (though PK isn't clean)

**Verdict:** This table IS in 1NF. Each cell contains a single value.

> **What would a 1NF violation look like?** Imagine if we had stored products as a comma-separated list: `products: "P001,P002"`. That would violate 1NF because the cell isn't atomic. Our table avoids this by having separate rows per product.

*But wait — what's the Primary Key?*

```python
# Can order_id be the PK?
print("Is order_id unique?")
print(df_messy['order_id'].is_unique)

# What about (order_id, product_id)?
print("\nIs (order_id, product_id) unique?")
print(df_messy.groupby(['order_id', 'product_id']).size().max() == 1)
```

<details>
<summary>Expected Output</summary>

~~~text
Is order_id unique?
False

Is (order_id, product_id) unique?
True
~~~

The Primary Key must be the **composite key**: `(order_id, product_id)`.

</details>

---

## 5. Step 3: Apply 2NF (Remove Partial Dependencies)

### Identify Partial Dependencies
With PK = `(order_id, product_id)`, let's check each attribute. Remember: a **partial dependency** means an attribute depends on only *part* of a composite key.

| Attribute | Depends On | Dependency Type |
| :--- | :--- | :--- |
| `order_date` | `order_id` only | **Partial** ❌ (2NF violation) |
| `customer_id` | `order_id` only | **Partial** ❌ (2NF violation) |
| `product_name` | `product_id` only | **Partial** ❌ (2NF violation) |
| `product_category` | `product_id` only | **Partial** ❌ (2NF violation) |
| `unit_price` | `product_id` only | **Partial** ❌ (2NF violation) |
| `quantity` | `(order_id, product_id)` | **Full** ✓ |

> **What about `customer_name`, `customer_email`, `customer_city`?** These depend on `customer_id`, which itself depends on `order_id`. This is actually a **transitive dependency** (A → B → C), which we'll formally address when checking 3NF. For now, we'll extract them along with the customer_id they depend on.

### Solution: Decompose into Three Tables

```python
# Table 1: orders (facts about the ORDER itself)
df_orders = df_messy[['order_id', 'order_date', 'customer_id']].drop_duplicates()
print("ORDERS table:")
print(df_orders)
print()

# Table 2: products (facts about the PRODUCT itself)
df_products = df_messy[['product_id', 'product_name', 'product_category', 'unit_price']].drop_duplicates()
print("PRODUCTS table:")
print(df_products)
print()

# Table 3: order_items (the relationship with quantity)
df_order_items = df_messy[['order_id', 'product_id', 'quantity']]
print("ORDER_ITEMS table:")
print(df_order_items)
```

<details>
<summary>Expected Output</summary>

~~~text
ORDERS table:
   order_id  order_date  customer_id
0      1001  2024-01-15          501
2      1002  2024-01-16          502
5      1003  2024-01-17          501

PRODUCTS table:
  product_id product_name product_category  unit_price
0       P001     Widget A          Widgets       10.00
1       P002     Widget B          Widgets       15.00
3       P003     Gadget X          Gadgets       25.00
4       P004     Gadget Y          Gadgets       30.00

ORDER_ITEMS table:
   order_id product_id  quantity
0      1001       P001         2
1      1001       P002         1
2      1002       P001         3
3      1002       P003         1
4      1002       P004         2
5      1003       P002         4
~~~

</details>

### But wait — where are the customers?
In the original table, `customer_name`, `customer_email`, and `customer_city` all depend on `customer_id` — not on `order_id` directly. This is a **transitive dependency**:

```
order_id → customer_id → customer_name, customer_email, customer_city
```

While technically a 3NF issue, it's practical to extract these now. The customer attributes form their own logical entity:

```python
# Extract customer data
df_customers = df_messy[['customer_id', 'customer_name', 'customer_email', 'customer_city']].drop_duplicates()
print("CUSTOMERS table:")
print(df_customers)
```

<details>
<summary>Expected Output</summary>

~~~text
CUSTOMERS table:
   customer_id customer_name   customer_email customer_city
0          501   Alice Smith  alice@email.com      New York
2          502     Bob Jones    bob@email.com   Los Angeles
~~~

Now each customer is stored exactly once.

</details>

---

## 6. Step 4: Apply 3NF (Remove Transitive Dependencies)

We already extracted the customer attributes (a transitive dependency) in the previous step. Now let's verify all our tables are in 3NF.

### Check the Orders Table
Our current `orders` table:

| order_id (PK) | order_date | customer_id |
| :--- | :--- | :--- |

**Dependencies:**
*   `order_id → order_date` ✓ (Direct)
*   `order_id → customer_id` ✓ (Direct)

No transitive dependencies. **Orders is in 3NF!** ✓

### Check the Products Table
Our current `products` table:

| product_id (PK) | product_name | product_category | unit_price |
| :--- | :--- | :--- | :--- |

**Dependencies:**
*   `product_id → product_name` ✓
*   `product_id → product_category` ✓
*   `product_id → unit_price` ✓

No transitive dependencies. **Products is in 3NF!** ✓

### Check the Customers Table
Our current `customers` table:

| customer_id (PK) | customer_name | customer_email | customer_city |
| :--- | :--- | :--- | :--- |

**Dependencies:**
*   `customer_id → customer_name` ✓
*   `customer_id → customer_email` ✓
*   `customer_id → customer_city` ✓

No transitive dependencies. **Customers is in 3NF!** ✓

---

## 7. Your Turn! (Exercises)

### Exercise 1: Verify the Decomposition
**Task:** Prove that we can reconstruct the original data by joining our normalized tables.

```python
# TODO: Join df_orders, df_order_items, df_products, and df_customers
# to recreate the original messy table

# Hint: Start with order_items, then join orders, then products, then customers
reconstructed = (
    df_order_items
    # .merge(df_orders, on='order_id')
    # .merge(df_products, on='product_id')
    # .merge(df_customers, on='customer_id')
)

# Uncomment and complete the joins above
```

<details>
<summary>Expected Output</summary>

~~~python
reconstructed = (
    df_order_items
    .merge(df_orders, on='order_id')
    .merge(df_products, on='product_id')
    .merge(df_customers, on='customer_id')
)
print(reconstructed)
~~~

~~~text
   order_id product_id  quantity  order_date  customer_id product_name product_category  unit_price customer_name   customer_email customer_city
0      1001       P001         2  2024-01-15          501     Widget A          Widgets       10.00   Alice Smith  alice@email.com      New York
1      1001       P002         1  2024-01-15          501     Widget B          Widgets       15.00   Alice Smith  alice@email.com      New York
2      1002       P001         3  2024-01-16          502     Widget A          Widgets       10.00     Bob Jones    bob@email.com   Los Angeles
3      1002       P003         1  2024-01-16          502     Gadget X          Gadgets       25.00     Bob Jones    bob@email.com   Los Angeles
4      1002       P004         2  2024-01-16          502     Gadget Y          Gadgets       30.00     Bob Jones    bob@email.com   Los Angeles
5      1003       P002         4  2024-01-17          501     Widget B          Widgets       15.00   Alice Smith  alice@email.com      New York
~~~

All original data is preserved through joins.

</details>

### Exercise 2: Find a Transitive Dependency
**Task:** Consider this hypothetical `products` table with an additional column:

| product_id | product_name | category_id | category_name |
| :--- | :--- | :--- | :--- |
| P001 | Widget A | C01 | Widgets |
| P002 | Widget B | C01 | Widgets |
| P003 | Gadget X | C02 | Gadgets |

**Questions:**
1.  Is this in 2NF? (The PK is `product_id` — single column)
2.  Is this in 3NF? What's the transitive dependency?
3.  How would you decompose it?

```python
# TODO: Create the decomposed tables as DataFrames
# df_products_fixed = ...
# df_categories = ...
```

<details>
<summary>Expected Output</summary>

**Answers:**
1.  Yes, it's in 2NF (single-column PK means no partial dependencies possible).
2.  No, it's NOT in 3NF. Transitive dependency: `product_id → category_id → category_name`
3.  Decompose:

~~~python
df_products_fixed = pd.DataFrame({
    'product_id': ['P001', 'P002', 'P003'],
    'product_name': ['Widget A', 'Widget B', 'Gadget X'],
    'category_id': ['C01', 'C01', 'C02']
})

df_categories = pd.DataFrame({
    'category_id': ['C01', 'C02'],
    'category_name': ['Widgets', 'Gadgets']
})
~~~

</details>

### Exercise 3: Anomaly Verification
**Task:** Prove that our normalized design eliminates the anomalies we identified earlier.

1.  **Update:** If Alice changes her email, how many rows need updating now?
2.  **Delete:** If we delete order 1002, do we lose Bob's info?
3.  **Insert:** Can we add product "Gadget Z" without an order?

```python
# TODO: Answer each question with code that demonstrates the answer
# For example, for Update:
# print(f"Rows to update for Alice's email: {len(df_customers[df_customers['customer_id'] == 501])}")
```

<details>
<summary>Expected Output</summary>

~~~text
1. Update: Only 1 row in the customers table needs updating.
2. Delete: Bob's info stays in the customers table even if order 1002 is deleted.
3. Insert: Yes! We can add to df_products without touching orders.
~~~

All three anomalies are eliminated.

</details>

---

## 8. Final Schema Diagram

Here's our normalized schema:

```python
Mermaid("""
erDiagram
    customers {
        int customer_id PK
        varchar customer_name
        varchar customer_email
        varchar customer_city
    }
    orders {
        int order_id PK
        date order_date
        int customer_id FK
    }
    products {
        varchar product_id PK
        varchar product_name
        varchar product_category
        decimal unit_price
    }
    order_items {
        int order_id PK_FK
        varchar product_id PK_FK
        int quantity
    }

    customers ||--o{ orders : places
    orders ||--|{ order_items : contains
    products ||--o{ order_items : appears_in
""")
```

---

## 9. Summary
You have successfully:
1.  Identified **anomalies** in a denormalized table.
2.  Applied **1NF** (verified atomicity).
3.  Applied **2NF** (removed partial dependencies from composite key).
4.  Applied **3NF** (verified no transitive dependencies).
5.  Decomposed one messy table into four normalized tables.

**Key Insight:** Normalization trades **storage efficiency** and **data integrity** for **query complexity** (more joins). In the next lesson, we'll explore when it makes sense to intentionally denormalize.
