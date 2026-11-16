-- ============================================================
-- Phase 1 : Helper functions
-- Project : AUCA Registrar Module (INSY 8311, Assignment 4)
-- None of these functions changes data (callable from SQL).
-- ============================================================
SET SERVEROUTPUT ON

-- ===========================================
-- FUNCTION: fn_letter_grade
-- Purpose : converts a score to a letter grade
-- Params  : p_score IN NUMBER
-- Returns : VARCHAR2 (A-F), or NULL when p_score is NULL
-- Rules   : R6
-- Author  : [Your Name] | ID: [Your ID]
-- ===========================================
CREATE OR REPLACE FUNCTION fn_letter_grade (
  p_score IN NUMBER
) RETURN VARCHAR2
IS
BEGIN
  IF p_score IS NULL THEN
    RETURN NULL;
  END IF;
  RETURN CASE
           WHEN p_score >= 90 THEN 'A'
           WHEN p_score >= 80 THEN 'B'
           WHEN p_score >= 70 THEN 'C'
           WHEN p_score >= 60 THEN 'D'
           ELSE 'F'
         END;
END fn_letter_grade;
/

-- ===========================================
-- FUNCTION: fn_student_name
-- Purpose : returns the first and last name of a student
-- Params  : p_student_id IN students.student_id%TYPE
-- Returns : VARCHAR2 'First Last', or 'Unknown student'
--           when the ID does not exist
-- Rules   : (none)
-- Author  : [Your Name] | ID: [Your ID]
-- ===========================================
CREATE OR REPLACE FUNCTION fn_student_name (
  p_student_id IN students.student_id%TYPE
) RETURN VARCHAR2
IS
  v_first students.first_name%TYPE;
  v_last  students.last_name%TYPE;
BEGIN
  SELECT first_name, last_name
  INTO   v_first, v_last
  FROM   students
  WHERE  student_id = p_student_id;

  RETURN v_first || ' ' || v_last;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN 'Unknown student';
END fn_student_name;
/

-- ===========================================
-- FUNCTION: fn_seats_left
-- Purpose : seats still free in a course
-- Params  : p_course_id IN courses.course_id%TYPE
-- Returns : NUMBER = max_students - Active enrollments,
--           NULL if the course does not exist
-- Rules   : R3
-- Author  : [Your Name] | ID: [Your ID]
-- ===========================================
CREATE OR REPLACE FUNCTION fn_seats_left (
  p_course_id IN courses.course_id%TYPE
) RETURN NUMBER
IS
  v_max    courses.max_students%TYPE;
  v_active NUMBER;
BEGIN
  SELECT max_students
  INTO   v_max
  FROM   courses
  WHERE  course_id = p_course_id;

  SELECT COUNT(*)
  INTO   v_active
  FROM   enrollments
  WHERE  course_id = p_course_id
  AND    status    = 'Active';

  RETURN v_max - v_active;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN NULL;
END fn_seats_left;
/

-- ===========================================
-- FUNCTION: fn_student_average
-- Purpose : average of a student's graded scores
-- Params  : p_student_id IN students.student_id%TYPE
-- Returns : NUMBER rounded to 2 decimals,
--           NULL if the student has no graded course
-- Rules   : R7 (input of the GPA formula)
-- Author  : [Your Name] | ID: [Your ID]
-- ===========================================
CREATE OR REPLACE FUNCTION fn_student_average (
  p_student_id IN students.student_id%TYPE
) RETURN NUMBER
IS
  v_avg NUMBER;
BEGIN
  -- AVG ignores NULL scores and returns NULL when no row qualifies
  SELECT ROUND(AVG(score), 2)
  INTO   v_avg
  FROM   enrollments
  WHERE  student_id = p_student_id
  AND    score IS NOT NULL;

  RETURN v_avg;
END fn_student_average;
/

-- ===========================================
-- FUNCTION: fn_can_enroll
-- Purpose : checks whether a student may enroll in a course
-- Params  : p_student_id IN students.student_id%TYPE
--           p_course_id  IN courses.course_id%TYPE
-- Returns : VARCHAR2: 'OK' or the first failing rule, in order:
--           'STUDENT NOT FOUND', 'STUDENT NOT ACTIVE',
--           'COURSE NOT FOUND', 'ALREADY ENROLLED',
--           'COURSE FULL', 'GPA TOO LOW'
-- Rules   : R1, R2, R3, R4
-- Author  : [Your Name] | ID: [Your ID]
-- ===========================================
CREATE OR REPLACE FUNCTION fn_can_enroll (
  p_student_id IN students.student_id%TYPE,
  p_course_id  IN courses.course_id%TYPE
) RETURN VARCHAR2
IS
  v_status  students.status%TYPE;
  v_gpa     students.gpa%TYPE;
  v_code    courses.course_code%TYPE;
  v_already NUMBER;
  v_seats   NUMBER;
BEGIN
  -- Student exists?
  BEGIN
    SELECT status, gpa
    INTO   v_status, v_gpa
    FROM   students
    WHERE  student_id = p_student_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN 'STUDENT NOT FOUND';
  END;

  -- R1
  IF v_status <> 'Active' THEN
    RETURN 'STUDENT NOT ACTIVE';
  END IF;

  -- Course exists?
  BEGIN
    SELECT course_code
    INTO   v_code
    FROM   courses
    WHERE  course_id = p_course_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN 'COURSE NOT FOUND';
  END;

  -- R2
  SELECT COUNT(*)
  INTO   v_already
  FROM   enrollments
  WHERE  student_id = p_student_id
  AND    course_id  = p_course_id;

  IF v_already > 0 THEN
    RETURN 'ALREADY ENROLLED';
  END IF;

  -- R3 (reuse fn_seats_left)
  v_seats := fn_seats_left(p_course_id);
  IF v_seats <= 0 THEN
    RETURN 'COURSE FULL';
  END IF;

  -- R4: first digit of the number in the code is 5 -> GPA >= 3.0
  IF SUBSTR(REGEXP_SUBSTR(v_code, '[0-9]+'), 1, 1) = '5'
     AND NVL(v_gpa, 0) < 3.0 THEN
    RETURN 'GPA TOO LOW';
  END IF;

  RETURN 'OK';
END fn_can_enroll;
/

-- ------------------------------------------------------------
-- Proof that every function works inside one SQL statement
-- ------------------------------------------------------------
SELECT e.enrollment_id,
       fn_student_name(e.student_id)              AS student_name,
       e.score,
       fn_letter_grade(e.score)                   AS letter,
       fn_student_average(e.student_id)           AS student_avg,
       fn_seats_left(e.course_id)                 AS seats_left,
       fn_can_enroll(e.student_id, e.course_id)   AS can_enroll
FROM   enrollments e
ORDER  BY e.enrollment_id
FETCH FIRST 15 ROWS ONLY;

-- Edge cases
SELECT fn_letter_grade(NULL)      AS grade_of_null,
       fn_student_name(9999)      AS unknown_student,
       fn_seats_left(999)         AS seats_unknown_course,
       fn_student_average(9999)   AS avg_unknown_student,
       fn_can_enroll(9999, 101)   AS can_enroll_unknown
FROM   dual;
