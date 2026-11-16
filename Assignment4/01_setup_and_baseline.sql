-- ============================================================
-- Phase 0 : Setup and SQL baseline
-- Project : AUCA Registrar Module (INSY 8311, Assignment 4)
-- Run as  : lecturer user, XEPDB1
-- Author  : [Your Name] | ID: [Your ID]
-- ============================================================
SET SERVEROUTPUT ON
SET LINESIZE 200
SET PAGESIZE 100

-- ------------------------------------------------------------
-- 0.1 The log table and its sequence (re-runnable)
-- ------------------------------------------------------------
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE registrar_log PURGE';
EXCEPTION WHEN OTHERS THEN
  IF SQLCODE != -942 THEN RAISE; END IF;
END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP SEQUENCE registrar_log_seq';
EXCEPTION WHEN OTHERS THEN
  IF SQLCODE != -2289 THEN RAISE; END IF;
END;
/

CREATE TABLE registrar_log (
  log_id      NUMBER         CONSTRAINT pk_registrar_log PRIMARY KEY,
  action      VARCHAR2(30)   NOT NULL,
  student_id  NUMBER,
  course_id   NUMBER,
  details     VARCHAR2(400),
  logged_by   VARCHAR2(30)   DEFAULT USER,
  logged_at   DATE           DEFAULT SYSDATE,
  CONSTRAINT ck_registrar_log_action CHECK
    (action IN ('ENROLL','ENROLL_REJECTED','SCORE','SCORE_REJECTED','GPA_UPDATE'))
);

CREATE SEQUENCE registrar_log_seq START WITH 1 INCREMENT BY 1 NOCACHE;

-- ------------------------------------------------------------
-- 0.2 SQL baseline (keep this output to compare with the module)
-- ------------------------------------------------------------

-- Baseline 1: Capacity overview (courses with no enrollments appear)
SELECT c.course_code,
       c.course_name,
       c.max_students,
       COUNT(e.enrollment_id)                                   AS active_enrollments,
       c.max_students - COUNT(e.enrollment_id)                  AS seats_left,
       ROUND(COUNT(e.enrollment_id) / NULLIF(c.max_students, 0) * 100, 1) AS fill_rate_pct
FROM   courses c
       LEFT JOIN enrollments e
              ON e.course_id = c.course_id
             AND e.status    = 'Active'
GROUP  BY c.course_id, c.course_code, c.course_name, c.max_students
ORDER  BY fill_rate_pct DESC NULLS LAST;

-- Baseline 2: GPA check (stored GPA vs. GPA given by rule R7, gap > 0.5)
SELECT s.student_id,
       s.first_name || ' ' || s.last_name           AS student_name,
       s.gpa                                        AS stored_gpa,
       ROUND(LEAST(a.avg_score / 25, 4), 2)         AS r7_gpa
FROM   students s
       JOIN (SELECT student_id, AVG(score) AS avg_score
             FROM   enrollments
             WHERE  score IS NOT NULL
             GROUP  BY student_id) a
         ON a.student_id = s.student_id
WHERE  ABS(s.gpa - ROUND(LEAST(a.avg_score / 25, 4), 2)) > 0.5
ORDER  BY s.student_id;

-- Baseline 3: Waiting for grades (EXISTS, no join)
SELECT s.student_id,
       s.first_name || ' ' || s.last_name AS student_name,
       (SELECT COUNT(*)
        FROM   enrollments e2
        WHERE  e2.student_id = s.student_id
        AND    e2.score IS NULL)            AS ungraded_courses
FROM   students s
WHERE  EXISTS (SELECT 1
               FROM   enrollments e
               WHERE  e.student_id = s.student_id
               AND    e.score IS NULL)
ORDER  BY ungraded_courses DESC, s.student_id;
