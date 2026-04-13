---
title: "Lab: Redis Data Structures & Caching"
week: 11
type: lab
tags: [redis, key-value, caching, python, data-structures]
difficulty: intermediate
duration: "55 mins"
---

# Lab: Redis Data Structures & Caching

## 1. Prerequisites & Setup

**Before starting this lab, you should:**
*   Review [w11_l21_concept_redis_keyvalue.md](w11_l21_concept_redis_keyvalue.md) for key-value store concepts and Redis data structures
*   Be comfortable with basic Python dictionaries and lists

**What you'll accomplish:**
In this lab, you'll install Redis in Colab, explore all five core data structures (Strings, Hashes, Lists, Sets, Sorted Sets), and build a Cache-Aside pattern that accelerates lookups from a simulated database.

---

### Environment Setup

Since Colab environments are ephemeral, we install Redis fresh each session.

```python
%%bash
# Install Redis server
apt-get update -qq
apt-get install -y -qq redis-server > /dev/null
echo "Redis installed: $(redis-server --version)"
```

```python
%%bash
# Start Redis server in the background
redis-server --daemonize yes --protected-mode no
sleep 1
redis-cli ping
```

```python
# Setup: Install Python client and connect
!pip install -q redis
```

```python
import redis
import time
import json

r = redis.Redis(host='localhost', port=6379, decode_responses=True)
print(f"Connected to Redis: {r.ping()}")
print(f"Server info: Redis {r.info()['redis_version']}")
```

<details>
<summary>Expected Output</summary>

~~~text
Redis installed: Redis server v=7.x.x ...
PONG
Connected to Redis: True
Server info: Redis 7.x.x
~~~

</details>

---

## 2. Strings: The Foundation

Strings are the simplest Redis type — a key maps to a single value.

```python
# Basic SET and GET
r.set("greeting", "Hello, COMP 4098!")
print(r.get("greeting"))

# Numbers are stored as strings but support atomic operations
r.set("page_views", 0)
r.incr("page_views")        # Atomic increment
r.incr("page_views")
r.incrby("page_views", 10)  # Increment by N
print(f"Page views: {r.get('page_views')}")

# SET with TTL (expires in 5 seconds)
r.set("temp_token", "abc123", ex=5)
print(f"Token exists: {r.exists('temp_token')}")
print(f"TTL remaining: {r.ttl('temp_token')} seconds")

time.sleep(6)
print(f"After 6 seconds — Token exists: {r.exists('temp_token')}")
```

<details>
<summary>Expected Output</summary>

~~~text
Hello, COMP 4098!
Page views: 12
Token exists: 1
TTL remaining: 5 seconds
After 6 seconds — Token exists: 0
~~~

</details>

### Practical Use: API Rate Limiter

A common real-world pattern — limit each IP address to 5 API calls per minute.

```python
def check_rate_limit(ip_address, max_requests=5, window_seconds=60):
    """Simple rate limiter using Redis INCR + TTL."""
    key = f"rate:{ip_address}"
    current = r.incr(key)

    if current == 1:
        # First request in this window — set the expiry
        r.expire(key, window_seconds)

    remaining = max(0, max_requests - current)
    allowed = current <= max_requests

    return {"allowed": allowed, "remaining": remaining, "current": current}


# Simulate 7 API calls from the same IP
ip = "192.168.1.42"
r.delete(f"rate:{ip}")  # Clean slate

for i in range(1, 8):
    result = check_rate_limit(ip, max_requests=5, window_seconds=60)
    status = "ALLOWED" if result["allowed"] else "BLOCKED"
    print(f"  Request {i}: {status} (remaining: {result['remaining']})")
```

<details>
<summary>Expected Output</summary>

~~~text
  Request 1: ALLOWED (remaining: 4)
  Request 2: ALLOWED (remaining: 3)
  Request 3: ALLOWED (remaining: 2)
  Request 4: ALLOWED (remaining: 1)
  Request 5: ALLOWED (remaining: 0)
  Request 6: BLOCKED (remaining: 0)
  Request 7: BLOCKED (remaining: 0)
~~~

</details>

---

## 3. Hashes: Mini-Documents

Hashes store field-value pairs under a single key — like a flat JSON object or a single database row.

```python
# Store a user profile as a Hash
r.hset("user:1001", mapping={
    "name": "Ana Torres",
    "email": "ana@upr.edu",
    "major": "Data Science",
    "gpa": "3.8",
    "login_count": "0"
})

# Read individual fields
print(f"Name: {r.hget('user:1001', 'name')}")
print(f"GPA:  {r.hget('user:1001', 'gpa')}")

# Read all fields at once
print(f"\nFull profile: {r.hgetall('user:1001')}")

# Update a single field (no need to rewrite the entire hash)
r.hincrby("user:1001", "login_count", 1)
r.hincrby("user:1001", "login_count", 1)
print(f"\nLogin count: {r.hget('user:1001', 'login_count')}")
```

<details>
<summary>Expected Output</summary>

~~~text
Name: Ana Torres
GPA:  3.8

Full profile: {'name': 'Ana Torres', 'email': 'ana@upr.edu', 'major': 'Data Science', 'gpa': '3.8', 'login_count': '0'}

Login count: 2
~~~

</details>

### Hash vs. JSON String

Why use a Hash instead of `SET user:1001 '{"name":"Ana",...}'`?

```python
# Method 1: JSON string — must read and rewrite the entire value to update one field
r.set("user:json", json.dumps({"name": "Ana", "email": "ana@upr.edu", "gpa": 3.8}))

# To update email, we must: GET → parse → modify → SET
data = json.loads(r.get("user:json"))
data["email"] = "ana.torres@upr.edu"
r.set("user:json", json.dumps(data))
print(f"JSON approach: 3 operations (GET + parse + SET)")

# Method 2: Hash — update a single field directly
r.hset("user:1001", "email", "ana.torres@upr.edu")
print(f"Hash approach: 1 operation (HSET)")

print(f"\nUpdated email: {r.hget('user:1001', 'email')}")
```

<details>
<summary>Expected Output</summary>

~~~text
JSON approach: 3 operations (GET + parse + SET)
Hash approach: 1 operation (HSET)

Updated email: ana.torres@upr.edu
~~~

</details>

---

## 4. Lists: Queues and Stacks

Lists are ordered sequences. Push to either end, pop from either end.

```python
# Build a task queue (FIFO: First In, First Out)
r.delete("queue:tasks")
r.rpush("queue:tasks", "send_email", "resize_image", "generate_report", "update_cache")

print("=== Task Queue ===")
print(f"Queue length: {r.llen('queue:tasks')}")
print(f"All tasks: {r.lrange('queue:tasks', 0, -1)}")

# Process tasks in FIFO order (LPOP = pop from the left/front)
print("\nProcessing tasks:")
while r.llen("queue:tasks") > 0:
    task = r.lpop("queue:tasks")
    print(f"  Processing: {task}")

print(f"\nQueue after processing: {r.lrange('queue:tasks', 0, -1)}")
```

<details>
<summary>Expected Output</summary>

~~~text
=== Task Queue ===
Queue length: 4
All tasks: ['send_email', 'resize_image', 'generate_report', 'update_cache']

Processing tasks:
  Processing: send_email
  Processing: resize_image
  Processing: generate_report
  Processing: update_cache

Queue after processing: []
~~~

</details>

### Recent Activity Feed

A common pattern: keep only the last N items using `LTRIM`.

```python
# Simulate a "recent activity" feed — keep last 5 entries
r.delete("feed:user:1001")

activities = [
    "Logged in",
    "Viewed dashboard",
    "Exported CSV",
    "Updated profile",
    "Ran SQL query",
    "Created report",
    "Shared dashboard",
]

for activity in activities:
    r.lpush("feed:user:1001", f"{activity}")
    r.ltrim("feed:user:1001", 0, 4)  # Keep only the 5 most recent

print("=== Last 5 Activities (most recent first) ===")
for item in r.lrange("feed:user:1001", 0, -1):
    print(f"  {item}")
```

<details>
<summary>Expected Output</summary>

~~~text
=== Last 5 Activities (most recent first) ===
  Shared dashboard
  Created report
  Ran SQL query
  Updated profile
  Exported CSV
~~~

</details>

---

## 5. Sets and Sorted Sets

### Sets: Unique, Unordered Collections

```python
# Tag system — each article has a set of tags
r.delete("tags:article:1", "tags:article:2")

r.sadd("tags:article:1", "python", "redis", "nosql", "caching")
r.sadd("tags:article:2", "python", "mongodb", "nosql", "aggregation")

print(f"Article 1 tags: {r.smembers('tags:article:1')}")
print(f"Article 2 tags: {r.smembers('tags:article:2')}")

# Set operations
print(f"\nShared tags (intersection): {r.sinter('tags:article:1', 'tags:article:2')}")
print(f"All tags (union):           {r.sunion('tags:article:1', 'tags:article:2')}")
print(f"Only in Article 1 (diff):   {r.sdiff('tags:article:1', 'tags:article:2')}")

# Membership check
print(f"\nArticle 1 has 'redis' tag? {r.sismember('tags:article:1', 'redis')}")
print(f"Article 2 has 'redis' tag? {r.sismember('tags:article:2', 'redis')}")
```

<details>
<summary>Expected Output</summary>

~~~text
Article 1 tags: {'python', 'redis', 'nosql', 'caching'}
Article 2 tags: {'python', 'mongodb', 'nosql', 'aggregation'}

Shared tags (intersection): {'python', 'nosql'}
All tags (union):           {'python', 'redis', 'nosql', 'caching', 'mongodb', 'aggregation'}
Only in Article 1 (diff):   {'redis', 'caching'}

Article 1 has 'redis' tag? True
Article 2 has 'redis' tag? False
~~~

(Set members may appear in different order — sets are unordered.)

</details>

### Sorted Sets: Leaderboards

```python
# Student GPA leaderboard
r.delete("leaderboard:gpa")

students = {
    "Ana Torres": 3.8,
    "Luis Rivera": 3.2,
    "Maria Santos": 3.95,
    "Carlos Diaz": 3.5,
    "Sofia Ruiz": 3.7,
}

for name, gpa in students.items():
    r.zadd("leaderboard:gpa", {name: gpa})

# Top students (highest GPA first)
print("=== GPA Leaderboard (Top to Bottom) ===")
rankings = r.zrevrange("leaderboard:gpa", 0, -1, withscores=True)
for rank, (name, gpa) in enumerate(rankings, 1):
    print(f"  {rank}. {name:20s} GPA: {gpa:.2f}")

# Update a score
r.zincrby("leaderboard:gpa", 0.15, "Luis Rivera")
print(f"\nAfter Luis improves: GPA = {r.zscore('leaderboard:gpa', 'Luis Rivera'):.2f}")

# Rank query (0-indexed from the top)
rank = r.zrevrank("leaderboard:gpa", "Ana Torres")
print(f"Ana's rank: #{rank + 1}")
```

<details>
<summary>Expected Output</summary>

~~~text
=== GPA Leaderboard (Top to Bottom) ===
  1. Maria Santos         GPA: 3.95
  2. Ana Torres           GPA: 3.80
  3. Sofia Ruiz           GPA: 3.70
  4. Carlos Diaz          GPA: 3.50
  5. Luis Rivera          GPA: 3.20

After Luis improves: GPA = 3.35
Ana's rank: #2
~~~

</details>

---

## 6. Building a Cache-Aside Pattern

Now let's combine Redis with a simulated database to implement the **Cache-Aside** caching strategy from the concept lesson.

### The "Database" (Simulated)

```python
import random

# Simulated "slow" database — a dictionary with an artificial delay
PRODUCT_DB = {
    "PROD-001": {"name": "Laptop Pro 16", "price": 1299.99, "category": "Electronics"},
    "PROD-002": {"name": "Wireless Mouse", "price": 29.99, "category": "Electronics"},
    "PROD-003": {"name": "Ergonomic Chair", "price": 449.99, "category": "Furniture"},
    "PROD-004": {"name": "Standing Desk", "price": 599.99, "category": "Furniture"},
    "PROD-005": {"name": "Mechanical Keyboard", "price": 89.99, "category": "Electronics"},
}

def query_database(product_id):
    """Simulate a slow database query (5-15 ms)."""
    time.sleep(random.uniform(0.005, 0.015))  # Simulate latency
    return PRODUCT_DB.get(product_id)
```

### Cache-Aside Implementation

```python
CACHE_TTL = 300  # 5 minutes

def get_product(product_id):
    """
    Cache-Aside pattern:
    1. Check Redis cache first
    2. On miss, query the database and store result in cache
    """
    cache_key = f"cache:product:{product_id}"

    # Step 1: Check cache
    cached = r.get(cache_key)
    if cached:
        return json.loads(cached), "HIT"

    # Step 2: Cache miss — query the database
    product = query_database(product_id)
    if product is None:
        return None, "MISS (not found)"

    # Step 3: Store in cache with TTL
    r.set(cache_key, json.dumps(product), ex=CACHE_TTL)
    return product, "MISS (cached)"
```

### Testing the Cache

```python
# Clear any existing cache entries
for key in r.keys("cache:product:*"):
    r.delete(key)

print("=== Cache-Aside Demo ===\n")

# First round: all cache misses (cold cache)
print("Round 1 (cold cache):")
for pid in ["PROD-001", "PROD-003", "PROD-005"]:
    start = time.perf_counter()
    product, status = get_product(pid)
    elapsed = (time.perf_counter() - start) * 1000
    print(f"  {pid}: {product['name']:25s} [{status}] {elapsed:.2f} ms")

print()

# Second round: all cache hits (warm cache)
print("Round 2 (warm cache):")
for pid in ["PROD-001", "PROD-003", "PROD-005"]:
    start = time.perf_counter()
    product, status = get_product(pid)
    elapsed = (time.perf_counter() - start) * 1000
    print(f"  {pid}: {product['name']:25s} [{status}] {elapsed:.2f} ms")

# Show that cache keys exist
print(f"\nCached keys: {r.keys('cache:product:*')}")
print(f"TTL on PROD-001: {r.ttl('cache:product:PROD-001')} seconds")
```

<details>
<summary>Expected Output</summary>

~~~text
=== Cache-Aside Demo ===

Round 1 (cold cache):
  PROD-001: Laptop Pro 16             [MISS (cached)] ~8.50 ms
  PROD-003: Ergonomic Chair           [MISS (cached)] ~11.20 ms
  PROD-005: Mechanical Keyboard       [MISS (cached)] ~7.30 ms

Round 2 (warm cache):
  PROD-001: Laptop Pro 16             [HIT] ~0.30 ms
  PROD-003: Ergonomic Chair           [HIT] ~0.25 ms
  PROD-005: Mechanical Keyboard       [HIT] ~0.28 ms

Cached keys: ['cache:product:PROD-001', 'cache:product:PROD-003', 'cache:product:PROD-005']
TTL on PROD-001: 299 seconds
~~~

(Exact times will vary. Key observation: cache hits are 20–40x faster than misses.)

</details>

### Cache Invalidation

When data changes, we must invalidate (delete) the cached version.

```python
def update_product_price(product_id, new_price):
    """Update the database and invalidate the cache."""
    # Step 1: Update the "database"
    if product_id in PRODUCT_DB:
        PRODUCT_DB[product_id]["price"] = new_price

    # Step 2: Invalidate the cache (force next read to fetch fresh data)
    cache_key = f"cache:product:{product_id}"
    deleted = r.delete(cache_key)
    return deleted == 1  # True if cache entry existed and was removed


# Before update
product, status = get_product("PROD-001")
print(f"Before: {product['name']} @ ${product['price']} [{status}]")

# Update price and invalidate cache
update_product_price("PROD-001", 1199.99)
print("Cache invalidated after price update")

# After update — cache miss, fetches fresh data
product, status = get_product("PROD-001")
print(f"After:  {product['name']} @ ${product['price']} [{status}]")
```

<details>
<summary>Expected Output</summary>

~~~text
Before: Laptop Pro 16 @ $1299.99 [HIT]
Cache invalidated after price update
After:  Laptop Pro 16 @ $1199.99 [MISS (cached)]
~~~

</details>

---

## 7. Your Turn! (Exercises)

### Exercise 1: Session Store

**Task:** Implement a simple session store using Redis Hashes. Create functions:
1. `create_session(user_id)` — generates a session ID (`session:<random>`), stores `user_id`, `created_at`, and `last_active` fields in a Hash. Set a TTL of 30 minutes (1800 seconds). Return the session ID.
2. `get_session(session_id)` — returns the session data or `None` if expired/missing.
3. `refresh_session(session_id)` — updates `last_active` and resets the TTL.

**Hint:** Use `r.hset()` with mapping, `r.expire()` for TTL, and `r.hgetall()` to retrieve.

```python
import uuid
from datetime import datetime

# TODO: Implement create_session, get_session, refresh_session

# Test your implementation:
# sid = create_session("user:1001")
# print(f"Created session: {sid}")
# print(f"Session data: {get_session(sid)}")
# refresh_session(sid)
# print(f"After refresh: {get_session(sid)}")
# print(f"TTL: {r.ttl(sid)} seconds")
```

<details>
<summary>Expected Output</summary>

~~~text
Created session: session:a1b2c3d4...
Session data: {'user_id': 'user:1001', 'created_at': '2026-04-04T10:30:00', 'last_active': '2026-04-04T10:30:00'}
After refresh: {'user_id': 'user:1001', 'created_at': '2026-04-04T10:30:00', 'last_active': '2026-04-04T10:30:05'}
TTL: 1800 seconds
~~~

(Timestamps and session ID will vary.)

</details>

### Exercise 2: Trending Topics with Sorted Sets

**Task:** Build a "trending topics" tracker. Given a list of topic mentions, use a Sorted Set where each topic's score is its mention count. Then:
1. Add all mentions using `ZINCRBY` (increment score by 1 per mention)
2. Display the top 5 trending topics with their counts
3. Show where "redis" ranks in the list

```python
mentions = [
    "python", "sql", "mongodb", "python", "redis",
    "python", "sql", "machine_learning", "redis", "python",
    "mongodb", "sql", "data_science", "python", "redis",
    "machine_learning", "sql", "python", "data_science", "mongodb",
]

# TODO: Process mentions into a sorted set "trending:topics"
# TODO: Display top 5 with scores
# TODO: Show rank of "redis"
```

<details>
<summary>Expected Output</summary>

~~~text
=== Top 5 Trending Topics ===
  1. python              6 mentions
  2. sql                 4 mentions
  3. mongodb             3 mentions
  4. redis               3 mentions
  5. machine_learning    2 mentions

Redis rank: #4 (3 mentions)
~~~

(Topics with the same score may appear in different order.)

</details>

### Exercise 3: Cache Hit Rate

**Task:** Modify the `get_product` function to track cache statistics. Use Redis `INCR` to maintain two counters: `stats:cache:hits` and `stats:cache:misses`. After running 20 random product lookups, compute and display the **hit rate** (hits / total requests * 100).

**Hint:** Increment the appropriate counter inside the `get_product` function based on whether the lookup was a HIT or MISS.

```python
# TODO: Reset counters
# TODO: Modify get_product (or create get_product_with_stats) to track hits/misses
# TODO: Run 20 random lookups and display the hit rate

# product_ids = list(PRODUCT_DB.keys())
# for _ in range(20):
#     pid = random.choice(product_ids)
#     product, status = get_product_with_stats(pid)
#
# hits = int(r.get("stats:cache:hits") or 0)
# misses = int(r.get("stats:cache:misses") or 0)
# total = hits + misses
# print(f"Hits: {hits}, Misses: {misses}, Hit Rate: {hits/total*100:.1f}%")
```

<details>
<summary>Expected Output</summary>

~~~text
=== Cache Statistics (20 lookups) ===
Hits: 15, Misses: 5, Hit Rate: 75.0%
~~~

(Exact numbers will vary. After the cold start, most lookups should be hits since there are only 5 products.)

</details>

---

## 8. Cleanup

```python
r.flushdb()
print(f"Redis database flushed: {r.dbsize()} keys remaining")
```

---

## Summary

In this lab, you:
*   Installed **Redis** in Colab and connected using the `redis-py` client
*   Practiced all five core data structures: **Strings** (counters, TTL), **Hashes** (profiles), **Lists** (queues), **Sets** (tags, intersections), **Sorted Sets** (leaderboards)
*   Built a practical **rate limiter** using atomic `INCR` and `EXPIRE`
*   Implemented the **Cache-Aside** pattern with TTL and cache invalidation
*   Observed the performance difference between cache hits (\~0.3 ms) and database queries (\~8 ms)
