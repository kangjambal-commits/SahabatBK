-- SAHABATBK v2.6 - Database hardening untuk counselor_assignments
-- Jalankan sekali di Supabase SQL Editor sebelum memakai Penugasan Siswa ke Konselor.

CREATE OR REPLACE FUNCTION public.validate_counselor_assignment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  student_school uuid;
  counselor_school uuid;
  counselor_role text;
  counselor_active boolean;
BEGIN
  SELECT school_id INTO student_school
  FROM public.students WHERE id = NEW.student_id;

  SELECT school_id, role, is_active
  INTO counselor_school, counselor_role, counselor_active
  FROM public.profiles WHERE id = NEW.counselor_id;

  IF student_school IS NULL OR student_school <> NEW.school_id THEN
    RAISE EXCEPTION 'Siswa tidak berasal dari sekolah yang sama.';
  END IF;

  IF counselor_school IS NULL OR counselor_school <> NEW.school_id THEN
    RAISE EXCEPTION 'Konselor tidak berasal dari sekolah yang sama.';
  END IF;

  IF counselor_role <> 'counselor' THEN
    RAISE EXCEPTION 'Akun tujuan bukan Konselor.';
  END IF;

  IF counselor_active IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'Konselor tujuan sedang nonaktif.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_counselor_assignment
ON public.counselor_assignments;

CREATE TRIGGER trg_validate_counselor_assignment
BEFORE INSERT OR UPDATE OF school_id, student_id, counselor_id
ON public.counselor_assignments
FOR EACH ROW
EXECUTE FUNCTION public.validate_counselor_assignment();
