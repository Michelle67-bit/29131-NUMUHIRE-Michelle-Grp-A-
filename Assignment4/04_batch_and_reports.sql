-- ============================================================
-- Phase 3 : Batch processing and reports with cursors
-- Project : AUCA Registrar Module (INSY 8311, Assignment 4)
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200

-- ===========================================
-- PROCEDURE: pr_recalculate_all_gpas
-- Purpose : recalculates the GPA of every Active student who has
--           at least p_min_graded graded courses
-- Params  : p_min_graded IN  NUMBER DEFAULT 1
--           p_changed    OUT NUMBER  (GPAs that changed)
--           p_unchanged  OUT NUMBER  (GPAs that stayed the same)
-- Rules   : R7, R8, R9 (through pr_recalculate_gpa)
-- Note    : students below the threshold are skipped and not counted
-- Author  : [Your Name] | ID: [Your ID]
-- ===========================================
CREATE OR REPLACE PROCEDURE pr_recalculate_all_gpas (
  p_min_graded IN  NUMBER DEFAULT 1,
  p_changed    OUT NUMBER,
  p_unchanged  OUT NUMBER
)
IS
  v_old students.gpa%TYPE;
  v_new students.gpa%TYPE;
BEGIN
  p_changed   := 0;
  p_unchanged := 0;

  FOR r IN (SELECT s.student_id,
                   (SELECT COUNT(e.score)
                    FROM   enrollments e
                    WHERE  e.student_id = s.student_id) AS graded_count
            FROM   students s
            WHERE  s.status = 'Active'
            ORDER  BY s.student_id)
  LOOP
    IF r.graded_count >= p_min_graded THEN
      pr_recalculate_gpa(r.student_id, v_old, v_new);

      IF v_old = v_new OR (v_old IS NULL AND v_new IS NULL) THEN
        p_unchanged := p_unchanged + 1;
      ELSE
        p_changed := p_changed + 1;
      END IF;
    END IF;
  END LOOP;
END pr_recalculate_all_gpas;
/

-- ===========================================
-- PROCEDURE: pr_course_report
-- Purpose : prints, per course, instructor, seats left, graded count,
--           average score and A-F distribution, then a total line
-- Params  : p_department IN VARCHAR2 DEFAULT NULL
--           (NULL = all departments)
-- Rules   : R3 (seats via fn_seats_left), R6 (grades)
-- Author  : [Your Name] | ID: [Your ID]
-- ===========================================
CREATE OR REPLACE PROCEDURE pr_course_report (
  p_department IN VARCHAR2 DEFAULT NULL
)
IS
  -- Outer cursor: courses of the department (explicit)
  CURSOR c_courses IS
    SELECT c.course_id,
           c.course_code,
           c.course_name,
           i.first_name || ' ' || i.last_name AS instructor
    FROM   courses c
           JOIN departments d ON d.department_id = c.department_id
           LEFT JOIN employees i ON i.employee_id = c.instructor_id
    WHERE  p_department IS NULL
       OR  d.department_name = p_department
    ORDER  BY c.course_code;

  -- Inner cursor with a parameter: enrollments of one course
  CURSOR c_enr (p_course_id courses.course_id%TYPE) IS
    SELECT e.score, e.grade
    FROM   enrollments e
    WHERE  e.course_id = p_course_id
    AND    e.status    = 'Active';

  v_course   c_courses%ROWTYPE;

  -- per course
  v_graded   NUMBER;
  v_sum      NUMBER;
  v_a NUMBER; v_b NUMBER; v_c NUMBER; v_d NUMBER; v_f NUMBER;

  -- department totals
  t_courses  NUMBER := 0;
  t_enrolled NUMBER := 0;
  t_graded   NUMBER := 0;
  t_sum      NUMBER := 0;
BEGIN
  DBMS_OUTPUT.PUT_LINE('=== COURSE REPORT: ' || NVL(p_department, 'All departments') || ' ===');

  OPEN c_courses;
  LOOP
    FETCH c_courses INTO v_course;
    EXIT WHEN c_courses%NOTFOUND;

    v_graded := 0; v_sum := 0;
    v_a := 0; v_b := 0; v_c := 0; v_d := 0; v_f := 0;

    FOR v_enr IN c_enr(v_course.course_id) LOOP
      t_enrolled := t_enrolled + 1;
      IF v_enr.score IS NOT NULL THEN
        v_graded := v_graded + 1;
        v_sum    := v_sum + v_enr.score;
        CASE fn_letter_grade(v_enr.score)
          WHEN 'A' THEN v_a := v_a + 1;
          WHEN 'B' THEN v_b := v_b + 1;
          WHEN 'C' THEN v_c := v_c + 1;
          WHEN 'D' THEN v_d := v_d + 1;
          ELSE          v_f := v_f + 1;
        END CASE;
      END IF;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(v_course.course_code || ' - ' || v_course.course_name);
    DBMS_OUTPUT.PUT_LINE('   Instructor : ' || NVL(v_course.instructor, 'not assigned'));
    DBMS_OUTPUT.PUT_LINE('   Seats left : ' || fn_seats_left(v_course.course_id));
    DBMS_OUTPUT.PUT_LINE('   Graded     : ' || v_graded ||
                         '   Average: ' ||
                         CASE WHEN v_graded = 0 THEN 'n/a'
                              ELSE TO_CHAR(ROUND(v_sum / v_graded, 2), 'FM990.00') END);
    DBMS_OUTPUT.PUT_LINE('   Grades     : A=' || v_a || ' B=' || v_b || ' C=' || v_c ||
                         ' D=' || v_d || ' F=' || v_f);

    t_courses := t_courses + 1;
    t_graded  := t_graded + v_graded;
    t_sum     := t_sum + v_sum;
  END LOOP;
  CLOSE c_courses;

  DBMS_OUTPUT.PUT_LINE('--- TOTAL ' || NVL(p_department, 'All departments') ||
                       ': ' || t_courses || ' courses, ' || t_enrolled ||
                       ' active enrollments, ' || t_graded || ' graded, average ' ||
                       CASE WHEN t_graded = 0 THEN 'n/a'
                            ELSE TO_CHAR(ROUND(t_sum / t_graded, 2), 'FM990.00') END ||
                       ' ---');
END pr_course_report;
/

SHOW ERRORS

-- ------------------------------------------------------------
-- Demonstration (everything is rolled back at the end so that
-- script 05 starts from the same data)
-- ------------------------------------------------------------
DECLARE
  v_changed   NUMBER;
  v_unchanged NUMBER;
BEGIN
  -- 1. default parameter (p_min_graded = 1)
  pr_recalculate_all_gpas(p_changed => v_changed, p_unchanged => v_unchanged);
  DBMS_OUTPUT.PUT_LINE('Default (min 1 graded) : changed=' || v_changed ||
                       ', unchanged=' || v_unchanged);

  ROLLBACK;   -- the caller decides (R9): undo so the next call sees the same data

  -- 2. named notation, p_min_graded => 3
  pr_recalculate_all_gpas(p_min_graded => 3, p_changed => v_changed, p_unchanged => v_unchanged);
  DBMS_OUTPUT.PUT_LINE('Named (min 3 graded)   : changed=' || v_changed ||
                       ', unchanged=' || v_unchanged);
  ROLLBACK;
END;
/

BEGIN
  pr_course_report('Computer Science');          -- positional
  pr_course_report(p_department => 'English');   -- named
  pr_course_report;                              -- no argument = all departments
END;
/

ROLLBACK;
