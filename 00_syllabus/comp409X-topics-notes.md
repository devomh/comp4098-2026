# COMP 409X: Syllabus & Lesson Plan Notes

## Week 8: Performance Lab (Lessons 15 & 16)

### Potential Lesson Outlines

#### Lesson 15: Lab Preparation (The "Data Engineering" Phase)
*Focus: How to move and generate data at scale.*

1.  **Synthetic Data Generation (20 min):**
    *   Introduction to `Faker` vs. Vectorized generation (NumPy/Pandas).
    *   Maintaining Referential Integrity in synthetic datasets (e.g., ensuring `order_id` in a 10M row table matches `user_id` in a 1M row table).
2.  **Ingestion Strategies (40 min):**
    *   **PostgreSQL:** Why standard `INSERT` statements fail at scale. Using `COPY` and `psycopg2` extras (`execute_values`).
    *   **DuckDB:** The power of "Zero-Copy" ingestion. Directly querying Parquet/CSV files without a formal "load" step.
3.  **Lab Activity (20 min):**
    *   Scripting the generation of a 10M row "Retail Transactions" dataset and initiating the load into the Postgres instance.

#### Lesson 16: The Performance Benchmark (The "Architectural" Phase)
*Focus: Why one engine wins and how to prove it.*

1.  **Database Internals & Query Plans (30 min):**
    *   Conceptual `EXPLAIN`: Identifying Sequential Scans vs. Index Scans.
    *   The "Cost" of a join at 10M rows.
    *   Row-store (Postgres) vs. Column-store (DuckDB) execution patterns.
2.  **Benchmark Methodology (20 min):**
    *   Measuring "Wall Clock" time vs. CPU time.
    *   The "Cold Start" vs. "Warm Cache" problem.
3.  **Lab Activity (30 min):**
    *   Executing a "Death Match": Run the same complex analytical query (Join + Group By + Window Function) on both engines.
    *   **Visualization:** Plotting execution time differences using Matplotlib/Seaborn.

### Rationale for the 2-Lesson Structure

1.  **Logistical Lag:** Ingestion of 10M rows can take significant time (15–30 min) depending on the environment. Splitting allows for "soak time" and troubleshooting without cutting into analysis time.
2.  **Skillset Differentiation:** 
    *   **Lesson 15** covers **Data Ingestion** (Engineering/ETL skills).
    *   **Lesson 16** covers **Data Architecture** (Analytics/Optimization skills).
3.  **Buffer for Failure:** Loading large datasets often triggers memory or timeout errors. Having Lesson 15 dedicated to setup ensures students are ready for the benchmark in Lesson 16.

### Implementation Strategy: Google Colab & Persistence

To ensure data generated in **Lesson 15** is available in **Lesson 16** without re-generation:

1.  **DuckDB Storage (Google Drive + Parquet):**
    *   **Persistence:** Mount Google Drive in Colab (`/content/drive/`).
    *   **Format:** Save synthetic data as **Parquet** files. 
    *   **Benefit:** Parquet provides significant compression (e.g., 1GB CSV -> ~150MB Parquet) and DuckDB is optimized for columnar reads directly from Drive.

2.  **PostgreSQL Storage (Cloud Managed):**
    *   **Persistence:** Use a cloud-hosted PostgreSQL instance (e.g., Supabase, Neon, or a department-managed server).
    *   **Benefit:** Data persists independently of the Colab runtime session.

3.  **Lesson 16 "Resume" Workflow:**
    *   The Lesson 16 notebook should start with a "Connection Setup" block that mounts Drive and establishes the DB connection strings, allowing students to start querying in < 2 minutes.
