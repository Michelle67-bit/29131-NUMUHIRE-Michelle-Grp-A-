-- ============================================================
-- Phase 2 : Core procedures
-- Project : AUCA Registrar Module (INSY 8311, Assignment 4)
-- R9: no COMMIT / ROLLBACK inside any procedure.
-- ============================================================
SET SERVEROUTPUT ON

-- ===========================================
-- PROCEDURE: pr_log_action
-- Purpose : writes one row into REGISTRAR_LOG
-- Params  : p_action     IN registrar_log.action%TYPE
--           p_student_id IN registrar_log.student_id%TYPE
--           p_course_id  IN registrar_log.course_id%TYPE DEFAULT NULL
--           p_details    IN registrar_log.details%TYPE   DEFAULT NULL
-- Rules   : R8, R9 (logged_by = USER, logged_at = SYSDATE
--           come from the column defaults)
-- Author  : [Your Name] | ID: [Your ID]
-- ===========================================
CREATE OR REPLACE PROCEDURE pr_log_action (
  p_action     IN registrar_log.action%TYPE,
  p_student_id IN registrar_log.student_id%TYPE,
  p_course_id  IN registrar_log.course_id%TYPE DEFAULT NULL,
  p_details    IN registrar_log.details%TYPE   DEFAULT NULL
)
IS
BEGIN
  INSERT INTO registrar_log
         (log_id, action, student_id, course_id, details, logged_by, logged_at)
  VALUES (registrar_log_seq.NEXTVAL, p_action, p_student_id, p_course_id,
          SUBSTR(p_details, 1, 400), USER, SYSDATE);
END pr_log_action;
/

-- ===========================================
-- PROCEDURE: pr_round_score
-- Purpose : rounds a score to the nearest 0.5
-- Params  : p_score IN OUT NUMBER (value in, rounded value out)
-- Rules   : R5
-- Author  : [Your Name] | ID: [Your ID]
-- ===========================================
CREATE OR REPLACE PROCEDURE pr_round_score (
  p_score IN OUT NUMBER
)
IS
BEGIN
  IF p_score IS NOT NULL THEN
    p_score := ROUND(p_score * 2) / 2;
  END IF;
END pr_round_score;
/

-- Short test block: 87.3 must become 87.5
DECLARE
  v_score NUMBER := 87.3;
BEGIN
  DBMS_OUTPUT.PUT_LINE('Before: ' || v_score);
  pr_round_score(v_score);
  DBMS_OUTPUT.PUT_LINE('After : ' || v_score);
END;
/

-- ===========================================
-- PROCEDURE: pr_enroll_student
-- Purpose : enrolls a student if fn_can_enroll says 'OK',
--           otherwise rejects and logs the reason
-- Params  : p_student_id IN  students.student_id%TYPE
--           p_course_id  IN  courses.course_id%TYPE
--           p_message    OUT VARCHAR2
-- Rules   : R1, R2, R3, R4 (via fn_can_enroll), R8, R9
-- Author  : [Your Name] | ID: [Your ID]
-- ===========================================
CREATE OR REPLACE PROCEDURE pr_enroll_student (
  p_student_id IN  students.student_id%TYPE,
  p_course_id  IN  courses.course_id%TYPE,
  p_message    OUT VARCHAR2
)
IS
  v_check VARCHAR2(40);
  v_code  courses.course_code%TYPE;
BEGIN
  v_check := fn_can_enroll(p_student_id, p_course_id);

  IF v_check = 'OK' THEN
    INSERT INTO enrollments
           (enrollment_id, student_id, course_id, enrollment_date, status, grade, score)
    VALUES (enrollment_seq.NEXTVAL, p_student_id, p_course_id, SYSDATE, 'Active', NULL, NULL);

    SELECT course_code INTO v_code FROM courses WHERE course_id = p_course_id;

    pr_log_action('ENROLL', p_student_id, p_course_id,
                  'Enrolled in ' || v_code);
    p_message := 'Enrolled: ' || fn_student_name(p_student_id) || ' in ' || v_code;
  ELSE
    pr_log_action('ENROLL_REJECTED', p_student_id, p_course_id, v_check);
    p_message := 'Rejected: ' || v_check;
  END IF;
END pr_enroll_student;
/

-- ===========================================
-- PROCEDURE: pr_record_score
-- Purpose : validates, rounds and stores a score and its grade
-- Params  : p_enrollment_id IN  enrollments.enrollment_id%TYPE
--           p_score         IN  enrollments.score%TYPE
--           p_message       OUT VARCHAR2
-- Rules   : R5, R6, R8, R9
-- Author  : [Your Name] | ID: [Your ID]
-- ===========================================
CREATE OR REPLACE PROCEDURE pr_record_score (
  p_enrollment_id IN  enrollments.enrollment_id%TYPE,
  p_score         IN  enrollments.score%TYPE,
  p_message       OUT VARCHAR2
)
IS
  v_student_id enrollments.student_id%TYPE;
  v_course_id  enrollments.course_id%TYPE;
  v_old_score  enrollments.score%TYPE;
  v_score      enrollments.score%TYPE := p_score;
  v_grade      enrollments.grade%TYPE;
BEGIN
  -- Look up the context for the log. Aggregates never raise NO_DATA_FOUND,
  -- so "enrollment does not exist" is detected later by SQL%ROWCOUNT.
  SELECT MAX(student_id), MAX(course_id), MAX(score)
  INTO   v_student_id, v_course_id, v_old_score
  FROM   enrollments
  WHERE  enrollment_id = p_enrollment_id;

  -- R5: range check
  IF p_score IS NULL OR p_score < 0 OR p_score > 100 THEN
    pr_log_action('SCORE_REJECTED', v_student_id, v_course_id,
                  'Enrollment ' || p_enrollment_id || ': score ' ||
                  NVL(TO_CHAR(p_score), 'NULL') || ' is outside 0-100');
    p_message := 'Rejected: score must be between 0 and 100';
    RETURN;
  END IF;

  pr_round_score(v_score);
  v_grade := fn_letter_grade(v_score);

  UPDATE enrollments
  SET    score = v_score,
         grade = v_grade
  WHERE  enrollment_id = p_enrollment_id;

  IF SQL%ROWCOUNT = 0 THEN
    pr_log_action('SCORE_REJECTED', NULL, NULL,
                  'Enrollment ' || p_enrollment_id || ' not found');
    p_message := 'Rejected: enrollment not found';
  ELSE
    pr_log_action('SCORE', v_student_id, v_course_id,
                  'Enrollment ' || p_enrollment_id || ': old score ' ||
                  NVL(TO_CHAR(v_old_score), 'none') || ', new score ' || v_score ||
                  ' (' || v_grade || ')');
    p_message := 'Score saved: ' || RTRIM(TO_CHAR(v_score, 'FM990.9'), '.') ||
                 ' (' || v_grade || ')';
  END IF;
END pr_record_score;
/

-- ===========================================
-- PROCEDURE: pr_recalculate_gpa
-- Purpose : recalculates a student's GPA (average / 25, max 4.00)
-- Params  : p_student_id IN  students.student_id%TYPE
--           p_old_gpa    OUT students.gpa%TYPE
--           p_new_gpa    OUT students.gpa%TYPE
-- Rules   : R7, R8, R9
-- Note    : with no graded course both OUT values return the
--           current GPA and nothing is changed or logged.
-- Author  : [Your Name] | ID: [Your ID]
-- ===========================================
CREATE OR REPLACE PROCEDURE pr_recalculate_gpa (
  p_student_id IN  students.student_id%TYPE,
  p_old_gpa    OUT students.gpa%TYPE,
  p_new_gpa    OUT students.gpa%TYPE
)
IS
  v_avg NUMBER;
BEGIN
  SELECT gpa
  INTO   p_old_gpa
  FROM   students
  WHERE  student_id = p_student_id;

  v_avg := fn_student_average(p_student_id);

  IF v_avg IS NULL THEN
    p_new_gpa := p_old_gpa;       -- nothing graded: no change
    RETURN;
  END IF;

  p_new_gpa := LEAST(ROUND(v_avg / 25, 2), 4);

  IF p_old_gpa IS NULL OR p_old_gpa <> p_new_gpa THEN
    UPDATE students
    SET    gpa = p_new_gpa
    WHERE  student_id = p_student_id;

    pr_log_action('GPA_UPDATE', p_student_id, NULL,
                  'GPA changed from ' || NVL(TO_CHAR(p_old_gpa), 'none') ||
                  ' to ' || p_new_gpa);
  END IF;
EXCEPTION
  WHEN NO_DATA_FOUND THEN       -- unknown student: nothing to recalculate
    p_old_gpa := NULL;
    p_new_gpa := NULL;
END pr_recalculate_gpa;
/

SHOW ERRORS
