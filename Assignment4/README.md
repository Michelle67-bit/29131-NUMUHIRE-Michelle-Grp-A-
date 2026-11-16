# ADVENTIST UNIVERSITY OF CENTRAL AFRICA (AUCA)

## Assignment 4 — AUCA Registrar Module

**Course:** INSY 8311 — Database Development with PL/SQL
**Student Name:** NUMUHIRE MICHELLE
**Student ID:** 29131
**Git Branch:** `29131_numuhire_michelle_assignment4`

## Introduction

For this assignment, I worked on developing an AUCA Registrar Module using PL/SQL. The system helps manage student registration, courses, scores, grades and GPAs. I used functions and procedures to make these tasks easier and follow the given assignment rules.

## Assignment Objectives

The main things I worked on were:

- Creating an audit log to keep records of activities.
- Checking course capacity and student information.
- Calculating grades and student averages.
- Checking if students qualify for course registration.
- Managing scores and GPA updates.
- Handling errors and generating reports.
- Testing the system to make sure everything works properly.

## Project Files

I divided my work into five SQL files inside the `Assignment4` folder:

- **`01_setup_and_baseline.sql`** – Creates the audit log and runs the first queries.
- **`02_functions.sql`** – Contains five functions for checking student details, grades, averages and available seats.
- **`03_procedures.sql`** – Contains procedures for registration, score recording, activity logging and GPA updates.
- **`04_batch_and_reports.sql`** – Handles GPA recalculation and course reports.
- **`05_registration_day_test.sql`** – Contains 15 test cases for checking the system.

## Technologies Used

I used the following tools:

- Oracle Database (XEPDB1)
- PL/SQL
- Oracle SQL Developer
- Git and GitHub

## How to Run the Assignment

To run my work:

- Open Oracle SQL Developer.
- Connect to the `XEPDB1` database.
- Make sure Auto-Commit is OFF.
- Open the SQL files one by one, starting with `01_setup_and_baseline.sql`.
- Execute each file using F5.
- Check the results to see if everything runs correctly.

**Note:** The `STUDENTS`, `COURSES` and `ENROLLMENTS` tables, together with the `ENROLLMENT_SEQ` sequence, must already exist.

## Design Decisions

- I used `VARCHAR2` in `fn_can_enroll` because it allows the function to return messages explaining why a student cannot register.
- I left transaction control to the testing script instead of putting `COMMIT` and `ROLLBACK` inside my procedures.
- I used GPA procedures to update student GPAs according to the assignment requirements.

## Challenges and Solutions

I faced a few challenges while working on the assignment:

- **Audit logging:** I used a table and sequence to keep records of registrar activities.
- **Student eligibility:** I created `fn_can_enroll` to check the registration rules.
- **Score rounding:** I used the `ROUND` function to round scores to the nearest 0.5.
- **Error handling:** I used exception handling to deal with errors.
- **GPA updates:** I used procedures to recalculate student GPAs.

## What I Learned

I learned how to create functions and procedures, use different parameters, work with cursors and handle errors. I also got more practice with sequences, audit logs and transaction control.

This assignment helped me understand PL/SQL better and become more comfortable writing and testing database code.

## Conclusion

Overall, this assignment gave me a better understanding of how PL/SQL can be used to manage a registration system. I learned through practising, testing my code and correcting mistakes. It was a good opportunity to improve my database skills and gain more confidence in using Oracle Database.

---

