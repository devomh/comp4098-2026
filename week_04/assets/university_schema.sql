-- ============================================================
-- University Course Registration System — DDL Script
-- ============================================================
-- Usage:
--   psql -d my_database -f university_schema.sql
--   or from a Colab bash cell:
--   !sudo -u postgres psql -d my_database -f /content/university_schema.sql
--
-- This script is idempotent: it drops all tables first (CASCADE)
-- so it can be safely re-run in a fresh Colab session.
-- ============================================================

-- Drop tables in reverse dependency order (children before parents)
DROP TABLE IF EXISTS enrollments CASCADE;
DROP TABLE IF EXISTS student_phones CASCADE;
DROP TABLE IF EXISTS courses CASCADE;
DROP TABLE IF EXISTS students CASCADE;
DROP TABLE IF EXISTS professors CASCADE;
DROP TABLE IF EXISTS departments CASCADE;

-- ============================================================
-- Parent tables (no foreign key dependencies)
-- ============================================================

CREATE TABLE departments (
    dept_id  SERIAL PRIMARY KEY,
    name     VARCHAR(100) NOT NULL UNIQUE,
    building VARCHAR(100) NOT NULL
);

CREATE TABLE students (
    student_id SERIAL PRIMARY KEY,
    name       VARCHAR(100) NOT NULL,
    email      VARCHAR(255) UNIQUE NOT NULL,
    dob        DATE CHECK (dob < CURRENT_DATE AND dob > '1900-01-01')
);

-- ============================================================
-- Tables with foreign keys to parent tables
-- ============================================================

CREATE TABLE professors (
    emp_id  SERIAL PRIMARY KEY,
    name    VARCHAR(100) NOT NULL,
    dept_id INTEGER NOT NULL,
    FOREIGN KEY (dept_id) REFERENCES departments(dept_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

-- Self-referencing: a course may require another course as prerequisite
CREATE TABLE courses (
    course_code CHAR(8) PRIMARY KEY,
    title       VARCHAR(200) NOT NULL,
    credits     INTEGER NOT NULL CHECK (credits > 0 AND credits <= 6),
    prereq_code CHAR(8),
    FOREIGN KEY (prereq_code) REFERENCES courses(course_code)
        ON DELETE SET NULL
);

-- ============================================================
-- Junction / multi-valued attribute tables
-- ============================================================

-- Multi-valued attribute: a student may have multiple phone numbers
CREATE TABLE student_phones (
    student_id   INTEGER NOT NULL,
    phone_number VARCHAR(20) NOT NULL,
    phone_type   VARCHAR(20) DEFAULT 'mobile',
    PRIMARY KEY (student_id, phone_number),
    FOREIGN KEY (student_id) REFERENCES students(student_id)
        ON DELETE CASCADE
);

-- Many-to-many: students ↔ courses
CREATE TABLE enrollments (
    student_id      INTEGER NOT NULL,
    course_code     CHAR(8) NOT NULL,
    enrollment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    grade           CHAR(2) CHECK (grade IN ('A', 'B', 'C', 'D', 'F') OR grade IS NULL),
    PRIMARY KEY (student_id, course_code),
    FOREIGN KEY (student_id) REFERENCES students(student_id)
        ON DELETE CASCADE,
    FOREIGN KEY (course_code) REFERENCES courses(course_code)
        ON DELETE RESTRICT
);
