---
title: "Lab: MongoDB CRUD Operations"
week: 10
type: lab
tags: [mongodb, pymongo, crud, nosql]
difficulty: intermediate
duration: "55 mins"
---

# Lab: MongoDB CRUD Operations

## 1. Prerequisites & Setup

**Before starting this lab, you should:**
*   Review [w10_l19_concept_mongodb_essentials.md](w10_l19_concept_mongodb_essentials.md) for MongoDB architecture and CRUD syntax
*   Be comfortable with Python dictionaries (document model from Week 9)

**What you'll accomplish:**
In this lab, you'll install MongoDB in Colab, connect with pymongo, and perform the full range of CRUD operations against a product catalog collection.

---

### Step 1: Install MongoDB Server

This cell installs MongoDB Community Edition 7.x directly into the Colab runtime.

```python
%%bash
# Install MongoDB 7.x (Community Edition)
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
  gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg

echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | \
  tee /etc/apt/sources.list.d/mongodb-org-7.0.list

apt-get update -qq
apt-get install -y -qq mongodb-org > /dev/null
echo "MongoDB installed: $(mongod --version | head -1)"
```

<details>
<summary>Expected Output</summary>

~~~text
MongoDB installed: db version v7.0.x
~~~

(The exact patch version may differ.)

</details>

### Step 2: Start the MongoDB Server

```python
%%bash
mkdir -p /data/db
mongod --dbpath /data/db --fork --logpath /var/log/mongod.log --bind_ip 127.0.0.1
sleep 2
mongosh --quiet --eval "db.runCommand({ ping: 1 })"
```

<details>
<summary>Expected Output</summary>

~~~text
about to fork child process, waiting until server is ready for connections.
forked process: XXXXX
child process started successfully, parent exiting
{ ok: 1 }
~~~

</details>

### Step 3: Install pymongo and Connect

```python
# Setup: Install pymongo and connect (run Steps 1-2 first)
!pip install -q pymongo

from pymongo import MongoClient, ASCENDING, DESCENDING
import json

def pretty(doc):
    """Pretty-print a document as formatted JSON."""
    print(json.dumps(doc, indent=2, default=str))

# Connect to local MongoDB
client = MongoClient("mongodb://127.0.0.1:27017/")
db = client["store_db"]
products = db["products"]

print(f"Connected to MongoDB {client.server_info()['version']}")
print(f"Database: {db.name}")
```

<details>
<summary>Expected Output</summary>

~~~text
Connected to MongoDB 7.0.x
Database: store_db
~~~

</details>

---

## 2. Create: Inserting Documents

### insert_one — Adding a Single Product

```python
# Insert a single product
result = products.insert_one({
    "name": "Laptop Pro 16",
    "category": "Electronics",
    "price": 1299.99,
    "stock": 45,
    "specs": {"brand": "TechCorp", "ram": "16GB", "storage": "512GB SSD"},
    "tags": ["laptop", "premium", "new"]
})

print(f"Inserted document with _id: {result.inserted_id}")
print(f"Type of _id: {type(result.inserted_id).__name__}")
```

<details>
<summary>Expected Output</summary>

~~~text
Inserted document with _id: 665a1b...  (your ObjectId will differ)
Type of _id: ObjectId
~~~

</details>

Notice that we didn't include `_id` — MongoDB generated an `ObjectId` automatically. The document also contains nested objects (`specs`) and arrays (`tags`), both stored natively.

### insert_many — Bulk Insert

```python
# Insert multiple products at once
more_products = [
    {
        "name": "Wireless Mouse",
        "category": "Electronics",
        "price": 29.99,
        "stock": 200,
        "specs": {"brand": "ClickMax", "connectivity": "Bluetooth"},
        "tags": ["mouse", "wireless", "accessory"]
    },
    {
        "name": "Mechanical Keyboard",
        "category": "Electronics",
        "price": 89.99,
        "stock": 120,
        "specs": {"brand": "KeyForce", "switch_type": "Cherry MX Blue"},
        "tags": ["keyboard", "mechanical", "gaming"]
    },
    {
        "name": "USB-C Hub",
        "category": "Electronics",
        "price": 45.00,
        "stock": 80,
        "specs": {"brand": "PortPlus", "ports": 7},
        "tags": ["hub", "usb-c", "accessory"]
    },
    {
        "name": "Notebook Pack (3)",
        "category": "Office",
        "price": 8.99,
        "stock": 500,
        "specs": {"brand": "WriteWell", "pages": 200},
        "tags": ["notebook", "office", "bundle"]
    },
    {
        "name": "Ergonomic Chair",
        "category": "Furniture",
        "price": 449.99,
        "stock": 25,
        "specs": {"brand": "SitRight", "material": "Mesh", "adjustable": True},
        "tags": ["chair", "ergonomic", "premium"]
    },
    {
        "name": "Standing Desk",
        "category": "Furniture",
        "price": 599.99,
        "stock": 15,
        "specs": {"brand": "UpDesk", "width_cm": 140, "motorized": True},
        "tags": ["desk", "standing", "motorized", "premium"]
    },
    {
        "name": "Desk Lamp",
        "category": "Office",
        "price": 34.99,
        "stock": 150,
        "specs": {"brand": "BrightLine", "lumens": 800},
        "tags": ["lamp", "led", "office"]
    }
]

result = products.insert_many(more_products)
print(f"Inserted {len(result.inserted_ids)} documents")
print(f"Total products in collection: {products.count_documents({})}")
```

<details>
<summary>Expected Output</summary>

~~~text
Inserted 7 documents
Total products in collection: 8
~~~

</details>

---

## 3. Read: Querying Documents

### find_one — Single Document Lookup

```python
# Find a specific product by name
doc = products.find_one({"name": "Laptop Pro 16"})
pretty(doc)
```

<details>
<summary>Expected Output</summary>

~~~json
{
  "_id": "...",
  "name": "Laptop Pro 16",
  "category": "Electronics",
  "price": 1299.99,
  "stock": 45,
  "specs": {
    "brand": "TechCorp",
    "ram": "16GB",
    "storage": "512GB SSD"
  },
  "tags": ["laptop", "premium", "new"]
}
~~~

</details>

### find — Multiple Documents with Filters

```python
# Find all electronics
print("=== Electronics ===")
for doc in products.find({"category": "Electronics"}):
    print(f"  {doc['name']:25s} ${doc['price']:>8.2f}  (stock: {doc['stock']})")

print(f"\nElectronics count: {products.count_documents({'category': 'Electronics'})}")
```

<details>
<summary>Expected Output</summary>

~~~text
=== Electronics ===
  Laptop Pro 16             $ 1299.99  (stock: 45)
  Wireless Mouse            $   29.99  (stock: 200)
  Mechanical Keyboard       $   89.99  (stock: 120)
  USB-C Hub                 $   45.00  (stock: 80)

Electronics count: 4
~~~

</details>

### Comparison Operators

```python
# Products over $100
print("=== Products over $100 ===")
for doc in products.find({"price": {"$gt": 100}}):
    print(f"  {doc['name']:25s} ${doc['price']:.2f}")

# Products between $20 and $100 (inclusive)
print("\n=== Products $20 - $100 ===")
for doc in products.find({"price": {"$gte": 20, "$lte": 100}}):
    print(f"  {doc['name']:25s} ${doc['price']:.2f}")

# Products in specific categories
print("\n=== Furniture or Office ===")
for doc in products.find({"category": {"$in": ["Furniture", "Office"]}}):
    print(f"  {doc['name']:25s} [{doc['category']}]")
```

<details>
<summary>Expected Output</summary>

~~~text
=== Products over $100 ===
  Laptop Pro 16             $1299.99
  Ergonomic Chair           $449.99
  Standing Desk             $599.99

=== Products $20 - $100 ===
  Wireless Mouse            $29.99
  Mechanical Keyboard       $89.99
  USB-C Hub                 $45.00
  Desk Lamp                 $34.99

=== Furniture or Office ===
  Notebook Pack (3)         [Office]
  Ergonomic Chair           [Furniture]
  Standing Desk             [Furniture]
  Desk Lamp                 [Office]
~~~

</details>

### Querying Arrays and Nested Documents

```python
# Find products tagged "premium" (array contains value)
print("=== Premium products ===")
for doc in products.find({"tags": "premium"}):
    print(f"  {doc['name']:25s} tags: {doc['tags']}")

# Find products by nested field (dot notation)
print("\n=== TechCorp products ===")
for doc in products.find({"specs.brand": "TechCorp"}):
    print(f"  {doc['name']}: {doc['specs']}")
```

<details>
<summary>Expected Output</summary>

~~~text
=== Premium products ===
  Laptop Pro 16             tags: ['laptop', 'premium', 'new']
  Ergonomic Chair           tags: ['chair', 'ergonomic', 'premium']
  Standing Desk             tags: ['desk', 'standing', 'motorized', 'premium']

=== TechCorp products ===
  Laptop Pro 16: {'brand': 'TechCorp', 'ram': '16GB', 'storage': '512GB SSD'}
~~~

</details>

---

## 4. Update: Modifying Documents

### $set — Change a Field's Value

```python
# Update the price of Laptop Pro 16 (it's on sale!)
products.update_one(
    {"name": "Laptop Pro 16"},
    {"$set": {"price": 1099.99, "on_sale": True}}
)

# Verify the update
doc = products.find_one({"name": "Laptop Pro 16"})
print(f"Updated price: ${doc['price']}")
print(f"On sale: {doc.get('on_sale')}")
```

<details>
<summary>Expected Output</summary>

~~~text
Updated price: $1099.99
On sale: True
~~~

</details>

Note that `$set` also *created* the `on_sale` field — it didn't exist before. This is schema-on-read in action: fields can be added to individual documents at any time.

### $inc — Increment a Value

```python
# Decrement stock by 1 (someone bought a Laptop Pro 16)
products.update_one(
    {"name": "Laptop Pro 16"},
    {"$inc": {"stock": -1}}
)

doc = products.find_one({"name": "Laptop Pro 16"})
print(f"Laptop Pro 16 stock: {doc['stock']} (was 45)")
```

<details>
<summary>Expected Output</summary>

~~~text
Laptop Pro 16 stock: 44 (was 45)
~~~

</details>

### $push and $pull — Modify Arrays

```python
# Add a tag to Wireless Mouse
products.update_one(
    {"name": "Wireless Mouse"},
    {"$push": {"tags": "sale"}}
)

# Remove "new" tag from Laptop Pro 16
products.update_one(
    {"name": "Laptop Pro 16"},
    {"$pull": {"tags": "new"}}
)

# Verify
mouse = products.find_one({"name": "Wireless Mouse"})
laptop = products.find_one({"name": "Laptop Pro 16"})
print(f"Mouse tags: {mouse['tags']}")
print(f"Laptop tags: {laptop['tags']}")
```

<details>
<summary>Expected Output</summary>

~~~text
Mouse tags: ['mouse', 'wireless', 'accessory', 'sale']
Laptop tags: ['laptop', 'premium']
~~~

</details>

### update_many — Bulk Updates

```python
# Mark all furniture as "low stock" if stock < 30
result = products.update_many(
    {"category": "Furniture", "stock": {"$lt": 30}},
    {"$set": {"low_stock": True}}
)
print(f"Modified {result.modified_count} documents")

# Verify
for doc in products.find({"low_stock": True}):
    print(f"  {doc['name']} - stock: {doc['stock']}")
```

<details>
<summary>Expected Output</summary>

~~~text
Modified 2 documents
  Ergonomic Chair - stock: 25
  Standing Desk - stock: 15
~~~

</details>

---

## 5. Delete: Removing Documents

### delete_one and delete_many

```python
# Delete the notebook pack (discontinued)
result = products.delete_one({"name": "Notebook Pack (3)"})
print(f"Deleted {result.deleted_count} document")
print(f"Total products: {products.count_documents({})}")
```

<details>
<summary>Expected Output</summary>

~~~text
Deleted 1 document
Total products: 7
~~~

</details>

```python
# Delete all products priced under $30
result = products.delete_many({"price": {"$lt": 30}})
print(f"Deleted {result.deleted_count} document(s) under $30")
print(f"Total products: {products.count_documents({})}")

# What's left?
print("\nRemaining products:")
for doc in products.find({}, {"name": 1, "price": 1, "_id": 0}):
    print(f"  {doc['name']:25s} ${doc['price']:.2f}")
```

<details>
<summary>Expected Output</summary>

~~~text
Deleted 1 document(s) under $30
Total products: 6

Remaining products:
  Laptop Pro 16             $1099.99
  Mechanical Keyboard       $89.99
  USB-C Hub                 $45.00
  Ergonomic Chair           $449.99
  Standing Desk             $599.99
  Desk Lamp                 $34.99
~~~

</details>

---

## 6. Projection: Selecting Fields

By default, `find()` returns all fields. Use **projection** to select only the fields you need — similar to choosing columns in a SQL `SELECT`.

```python
# Only return name and price (exclude _id)
print("=== Name and price only ===")
for doc in products.find({}, {"name": 1, "price": 1, "_id": 0}):
    print(f"  {doc['name']:25s} ${doc['price']:.2f}")

# Exclude specs (return everything else)
print("\n=== Without specs ===")
doc = products.find_one({"name": "Laptop Pro 16"}, {"specs": 0})
pretty(doc)
```

<details>
<summary>Expected Output</summary>

~~~text
=== Name and price only ===
  Laptop Pro 16             $1099.99
  Mechanical Keyboard       $89.99
  USB-C Hub                 $45.00
  Ergonomic Chair           $449.99
  Standing Desk             $599.99
  Desk Lamp                 $34.99

=== Without specs ===
{
  "_id": "...",
  "name": "Laptop Pro 16",
  "category": "Electronics",
  "price": 1099.99,
  "stock": 44,
  "tags": ["laptop", "premium"],
  "on_sale": true
}
~~~

</details>

**Projection rules:**
*   `1` = include this field, `0` = exclude this field
*   You cannot mix includes and excludes (except `_id`, which can always be excluded)
*   `{"name": 1, "price": 1, "_id": 0}` — include name and price, exclude `_id`

---

## 7. Sorting and Limiting Results

```python
# Sort by price (ascending)
print("=== Cheapest first ===")
for doc in products.find({}, {"name": 1, "price": 1, "_id": 0}).sort("price", ASCENDING):
    print(f"  {doc['name']:25s} ${doc['price']:.2f}")

# Top 3 most expensive
print("\n=== Top 3 most expensive ===")
cursor = products.find({}, {"name": 1, "price": 1, "_id": 0}).sort("price", DESCENDING).limit(3)
for doc in cursor:
    print(f"  {doc['name']:25s} ${doc['price']:.2f}")
```

<details>
<summary>Expected Output</summary>

~~~text
=== Cheapest first ===
  Desk Lamp                 $34.99
  USB-C Hub                 $45.00
  Mechanical Keyboard       $89.99
  Ergonomic Chair           $449.99
  Standing Desk             $599.99
  Laptop Pro 16             $1099.99

=== Top 3 most expensive ===
  Laptop Pro 16             $1099.99
  Standing Desk             $599.99
  Ergonomic Chair           $449.99
~~~

</details>

Note the **method chaining**: `.find().sort().limit()` — MongoDB cursors support chaining operations, similar to how you chain `.filter()` and `.order_by()` in Django or SQLAlchemy.

---

## 8. Your Turn! (Exercises)

### Reset the Collection

Run this cell to start exercises with a fresh, complete dataset.

```python
# Reset the collection for exercises
products.drop()
products.insert_many([
    {"name": "Laptop Pro 16", "category": "Electronics", "price": 1299.99, "stock": 45,
     "specs": {"brand": "TechCorp", "ram": "16GB", "storage": "512GB SSD"},
     "tags": ["laptop", "premium", "new"]},
    {"name": "Wireless Mouse", "category": "Electronics", "price": 29.99, "stock": 200,
     "specs": {"brand": "ClickMax", "connectivity": "Bluetooth"},
     "tags": ["mouse", "wireless", "accessory"]},
    {"name": "Mechanical Keyboard", "category": "Electronics", "price": 89.99, "stock": 120,
     "specs": {"brand": "KeyForce", "switch_type": "Cherry MX Blue"},
     "tags": ["keyboard", "mechanical", "gaming"]},
    {"name": "USB-C Hub", "category": "Electronics", "price": 45.00, "stock": 80,
     "specs": {"brand": "PortPlus", "ports": 7},
     "tags": ["hub", "usb-c", "accessory"]},
    {"name": "Notebook Pack (3)", "category": "Office", "price": 8.99, "stock": 500,
     "specs": {"brand": "WriteWell", "pages": 200},
     "tags": ["notebook", "office", "bundle"]},
    {"name": "Ergonomic Chair", "category": "Furniture", "price": 449.99, "stock": 25,
     "specs": {"brand": "SitRight", "material": "Mesh", "adjustable": True},
     "tags": ["chair", "ergonomic", "premium"]},
    {"name": "Standing Desk", "category": "Furniture", "price": 599.99, "stock": 15,
     "specs": {"brand": "UpDesk", "width_cm": 140, "motorized": True},
     "tags": ["desk", "standing", "motorized", "premium"]},
    {"name": "Desk Lamp", "category": "Office", "price": 34.99, "stock": 150,
     "specs": {"brand": "BrightLine", "lumens": 800},
     "tags": ["lamp", "led", "office"]}
])
print(f"Collection reset: {products.count_documents({})} products")
```

### Exercise 1: Product Catalog Queries

**Task:** Write queries to answer these questions about the product catalog.

```python
# Q1: How many products cost more than $50?
# TODO: Use count_documents with a $gt filter

# Q2: Find all products that are NOT in the Electronics category
# Hint: Use the $ne operator
# TODO: Print name and category for each

# Q3: Find products tagged "accessory" — print name and price
# TODO: Query the tags array

# Q4: Find the cheapest product (sort ascending by price, limit to 1)
# TODO: Use .sort() and .limit()
```

<details>
<summary>Expected Output</summary>

~~~text
Q1: 4 products cost more than $50

Q2: Non-Electronics:
  Notebook Pack (3)         [Office]
  Ergonomic Chair           [Furniture]
  Standing Desk             [Furniture]
  Desk Lamp                 [Office]

Q3: Accessories:
  Wireless Mouse            $29.99
  USB-C Hub                 $45.00

Q4: Cheapest product:
  Notebook Pack (3) — $8.99
~~~

</details>

### Exercise 2: Inventory Management

**Task:** Use update operators to manage the store's inventory.

```python
# Q1: A customer bought 3 Wireless Mice — decrease stock by 3
# TODO: Use $inc

# Q2: Add the tag "bestseller" to the Wireless Mouse
# TODO: Use $push

# Q3: The Ergonomic Chair now comes in "Black" — add a "color" field to its specs
# Hint: Use $set with dot notation: "specs.color"
# TODO

# Q4: Discontinue all Office products — set {"discontinued": True} on each
# TODO: Use update_many

# Verify all updates
print("=== Verification ===")
mouse = products.find_one({"name": "Wireless Mouse"})
print(f"Wireless Mouse - stock: {mouse['stock']}, tags: {mouse['tags']}")

chair = products.find_one({"name": "Ergonomic Chair"})
print(f"Ergonomic Chair - specs.color: {chair['specs'].get('color')}")

print("Discontinued products:")
for doc in products.find({"discontinued": True}, {"name": 1, "_id": 0}):
    print(f"  {doc['name']}")
```

<details>
<summary>Expected Output</summary>

~~~text
=== Verification ===
Wireless Mouse - stock: 197, tags: ['mouse', 'wireless', 'accessory', 'bestseller']
Ergonomic Chair - specs.color: Black
Discontinued products:
  Notebook Pack (3)
  Desk Lamp
~~~

</details>

### Exercise 3: Custom _id and Student Records

**Task:** Create a new collection called `students` using student IDs as custom `_id` values.

```python
students = db["students"]
students.drop()  # Start fresh

# TODO: Insert 3 students using their student ID as _id
# Each student should have: _id (string), name, major, gpa, courses (array)
# Student 1: _id="S001", name="Ana Torres", major="Data Science", gpa=3.8,
#            courses=["COMP4098", "COMP4050"]
# Student 2: _id="S002", name="Luis Rivera", major="Data Science", gpa=3.5,
#            courses=["COMP4098", "STAT3001"]
# Student 3: _id="S003", name="Maria Santos", major="CS", gpa=3.9,
#            courses=["COMP4098", "COMP4050", "COMP3020"]

# TODO: Find the student with _id "S001" (no ObjectId needed!)

# TODO: Update S001's GPA to 3.9 using $set

# TODO: Count students in the "Data Science" major

# Cleanup
students.drop()
```

<details>
<summary>Expected Output</summary>

~~~text
Inserted 3 students

Student S001:
  Ana Torres — Data Science (GPA: 3.8)

Updated GPA: 3.9

Data Science students: 2
~~~

</details>

### Exercise 4: The Dangerous Update

**Task:** Run the following two updates and observe what happens. Explain the difference.

```python
# Reset a test product
db["test"].drop()
db["test"].insert_one({"_id": "T1", "name": "Widget", "price": 10, "stock": 100, "category": "Test"})

# Update A: Using $set (correct)
db["test"].update_one({"_id": "T1"}, {"$set": {"price": 15}})
doc_a = db["test"].find_one({"_id": "T1"})
print("After $set update:")
pretty(doc_a)

# Reset
db["test"].update_one({"_id": "T1"}, {"$set": {"name": "Widget", "price": 10, "stock": 100, "category": "Test"}})

# Update B: Without operator (DANGER — this replaces the entire document!)
db["test"].replace_one({"_id": "T1"}, {"price": 15})
doc_b = db["test"].find_one({"_id": "T1"})
print("\nAfter replace_one (no operator):")
pretty(doc_b)

# TODO: In a comment, explain:
# 1. What happened to name, stock, and category in Update B?
# 2. Why is $set safer than document replacement?

# Cleanup
db["test"].drop()
```

<details>
<summary>Expected Output</summary>

~~~text
After $set update:
{
  "_id": "T1",
  "name": "Widget",
  "price": 15,
  "stock": 100,
  "category": "Test"
}

After replace_one (no operator):
{
  "_id": "T1",
  "price": 15
}
~~~

Update B replaced the *entire* document with just `{"price": 15}`. The `name`, `stock`, and `category` fields are gone. `$set` only modifies the specified fields and preserves everything else. This is why you should always use `$set` for updates unless you explicitly intend to replace the whole document.

</details>

---

## 9. Cleanup

```python
# Drop the database when done
client.drop_database("store_db")
print("Database 'store_db' dropped")
client.close()
print("Connection closed")
```

---

## Summary

In this lab, you:
*   **Installed** MongoDB Community Edition 7.x in Google Colab and started the `mongod` server
*   **Connected** to MongoDB from Python using `pymongo`
*   **Created** documents with `insert_one` and `insert_many`, observing auto-generated `ObjectId`s
*   **Read** documents using `find_one`, `find` with query filters, comparison operators, and dot notation for nested fields
*   **Updated** documents using `$set`, `$inc`, `$push`, and `$pull` operators
*   **Deleted** documents with `delete_one` and `delete_many`
*   Used **projection** to select specific fields and **sort/limit** to order results

**Next lesson:** You'll go beyond basic CRUD to master advanced querying with logical and array operators, and the powerful **MongoDB Aggregation Pipeline** for analytics.
