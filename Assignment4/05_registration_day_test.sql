-- ============================================================
-- Phase 4 : Registration Day integration test
-- Project : AUCA Registrar Module (INSY 8311, Assignment 4)
-- One transaction, ends with ROLLBACK -> can be re-run any time.
-- Author  : [Your Name] | ID: [Your ID]
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200

DECLARE
  v_start    DATE := SYSDATE;
  v_msg      VARCHAR2(200);
  v_enr_id   enrollments.enrollment_id%TYPE;
  v_old      students.gpa%TYPE;
  v_new      students.gpa%TYPE;
  v_n        NUMBER;
  v_test     NUMBER := 0;

  PROCEDURE show (p_label VARCHAR2, p_text VARCHAR2) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE(RPAD(p_label, 5) || ' ' || p_text);
  END show;
BEGIN
  DBMS_OUTPUT.PUT_LINE('=== STEP 1: Test conditions ===');
  UPDATE students SET status = 'Suspended' WHERE student_id = 1049;
  UPDATE courses  SET max_students = 3     WHERE course_id  = 115;
  DBMS_OUTPUT.PUT_LINE('Student 1049 -> Suspended, course 115 -> max_students 3');

  DBMS_OUTPUT.PUT_LINE('=== STEP 2: Enrollment requests ===');
  FOR r IN (SELECT 1010 AS sid, 103 AS cid FROM dual UNION ALL
            SELECT 1001, 101 FROM dual UNION ALL
            SELECT 1016, 110 FROM dual UNION ALL
            SELECT 1049, 104 FROM dual UNION ALL
            SELECT 1020, 115 FROM dual UNION ALL
            SELECT 9999, 101 FROM dual UNION ALL
            SELECT 1030, 999 FROM dual)
  LOOP
    v_test := v_test + 1;
    pr_enroll_student(r.sid, r.cid, v_msg);
    show('T' || v_test, 'Enroll ' || r.sid || ' in ' || r.cid || ' -> ' || v_msg);
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('=== STEP 3: Scores ===');
  -- find the new enrollment of student 1010 in course 103 with SQL
  SELECT MAX(enrollment_id)
  INTO   v_enr_id
  FROM   enrollments
  WHERE  student_id = 1010 AND course_id = 103;

  pr_record_score(v_enr_id, 87.3, v_msg);
  show('T8',  'Score 87.3 for 1010 in 103 (enrollment ' || v_enr_id || ') -> ' || v_msg);
  pr_record_score(3, 91.2, v_msg);
  show('T9',  'Score 91.2 for enrollment 3    -> ' || v_msg);
  pr_record_score(5, 105, v_msg);
  show('T10', 'Score 105 for enrollment 5     -> ' || v_msg);
  pr_record_score(9999, 80, v_msg);
  show('T11', 'Score 80 for enrollment 9999   -> ' || v_msg);

  DBMS_OUTPUT.PUT_LINE('=== STEP 4: GPA ===');
  pr_recalculate_gpa(1001, v_old, v_new);
  show('T12', 'GPA of 1001: ' || TO_CHAR(v_old, 'FM0.00') || ' -> ' || TO_CHAR(v_new, 'FM0.00'));
  pr_recalculate_gpa(1010, v_old, v_new);
  show('T13', 'GPA of 1010: ' || TO_CHAR(v_old, 'FM0.00') || ' -> ' || TO_CHAR(v_new, 'FM0.00'));

  DBMS_OUTPUT.PUT_LINE('=== STEP 5: Report ===');
  pr_course_report('Computer Science');

  DBMS_OUTPUT.PUT_LINE('=== STEP 6: Verification (log rows of this run) ===');
  FOR r IN (SELECT action, COUNT(*) AS n
            FROM   registrar_log
            WHERE  logged_at >= v_start
            AND    logged_by = USER
            GROUP  BY action
            ORDER  BY action)
  LOOP
    show('T14', RPAD(r.action, 16) || r.n);
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('--- Objects status ---');
  FOR r IN (SELECT object_name, object_type, status
            FROM   user_objects
            WHERE  object_type IN ('FUNCTION', 'PROCEDURE')
            AND   (object_name LIKE 'FN\_%' ESCAPE '\' OR object_name LIKE 'PR\_%' ESCAPE '\')
            ORDER  BY object_type, object_name)
  LOOP
    DBMS_OUTPUT.PUT_LINE(RPAD(r.object_type, 10) || RPAD(r.object_name, 28) || r.status);
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('=== STEP 7: Clean up ===');
  ROLLBACK;

  SELECT COUNT(*) INTO v_n FROM enrollments;
  show('T15', 'Enrollments after ROLLBACK: ' || v_n || ' (expected 75)');
  SELECT COUNT(*) INTO v_n FROM registrar_log WHERE logged_at >= v_start;
  show('T15', 'Log rows from this run after ROLLBACK: ' || v_n || ' (expected 0)');
END;
/

-- Same two checks as plain SQL
SELECT COUNT(*) AS enrollments_after_rollback FROM enrollments;
SELECT COUNT(*) AS log_rows_after_rollback    FROM registrar_log;
