-- ============================================================
-- SahabatBK v2.8.1 - Karier & Studi: integritas relasi + RLS
-- Jalankan sekali di Supabase SQL Editor sebagai owner proyek.
-- Tidak menghapus data career_plans yang sudah ada.
-- ============================================================

-- 1) Validasi relasi: siswa harus berasal dari sekolah yang sama.
--    Jika talent_result_id diisi, hasil asesmen harus milik siswa yang sama.
CREATE OR REPLACE FUNCTION public.validate_career_plan_relation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student_school uuid;
  v_result_student uuid;
  v_result_school uuid;
BEGIN
  SELECT school_id INTO v_student_school
  FROM public.students
  WHERE id = NEW.student_id;

  IF v_student_school IS NULL OR v_student_school <> NEW.school_id THEN
    RAISE EXCEPTION 'Siswa tidak valid atau berasal dari sekolah yang berbeda';
  END IF;

  IF NEW.talent_result_id IS NOT NULL THEN
    SELECT student_id, school_id
      INTO v_result_student, v_result_school
    FROM public.assessment_results
    WHERE id = NEW.talent_result_id;

    IF v_result_student IS NULL
       OR v_result_student <> NEW.student_id
       OR v_result_school <> NEW.school_id THEN
      RAISE EXCEPTION 'Hasil pemetaan tidak sesuai dengan siswa yang dipilih';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_career_plan_relation ON public.career_plans;
CREATE TRIGGER trg_validate_career_plan_relation
BEFORE INSERT OR UPDATE OF school_id, student_id, talent_result_id
ON public.career_plans
FOR EACH ROW
EXECUTE FUNCTION public.validate_career_plan_relation();

-- 2) Pastikan RLS aktif.
ALTER TABLE public.career_plans ENABLE ROW LEVEL SECURITY;

-- 3) Bersihkan policy career_plans lama agar tidak ada policy longgar yang
--    tetap memberi konselor akses ke seluruh siswa satu sekolah.
DO $$
DECLARE p record;
BEGIN
  FOR p IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname='public' AND tablename='career_plans'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.career_plans', p.policyname);
  END LOOP;
END $$;

-- Admin sekolah: data Karier & Studi seluruh sekolah.
CREATE POLICY career_admin_select
ON public.career_plans FOR SELECT TO authenticated
USING (
  school_id = public.current_school_id()
  AND public.current_user_role() IN ('school_admin','superadmin')
);

CREATE POLICY career_admin_insert
ON public.career_plans FOR INSERT TO authenticated
WITH CHECK (
  school_id = public.current_school_id()
  AND public.current_user_role() IN ('school_admin','superadmin')
  AND created_by = auth.uid()
);

CREATE POLICY career_admin_update
ON public.career_plans FOR UPDATE TO authenticated
USING (
  school_id = public.current_school_id()
  AND public.current_user_role() IN ('school_admin','superadmin')
)
WITH CHECK (
  school_id = public.current_school_id()
  AND public.current_user_role() IN ('school_admin','superadmin')
);

CREATE POLICY career_admin_delete
ON public.career_plans FOR DELETE TO authenticated
USING (
  school_id = public.current_school_id()
  AND public.current_user_role() IN ('school_admin','superadmin')
);

-- Konselor: hanya siswa yang sedang ditugaskan aktif kepadanya.
CREATE POLICY career_counselor_select
ON public.career_plans FOR SELECT TO authenticated
USING (
  school_id = public.current_school_id()
  AND public.current_user_role() = 'counselor'
  AND EXISTS (
    SELECT 1 FROM public.counselor_assignments ca
    WHERE ca.school_id = career_plans.school_id
      AND ca.student_id = career_plans.student_id
      AND ca.counselor_id = auth.uid()
      AND ca.status = 'active'
  )
);

CREATE POLICY career_counselor_insert
ON public.career_plans FOR INSERT TO authenticated
WITH CHECK (
  school_id = public.current_school_id()
  AND public.current_user_role() = 'counselor'
  AND created_by = auth.uid()
  AND EXISTS (
    SELECT 1 FROM public.counselor_assignments ca
    WHERE ca.school_id = career_plans.school_id
      AND ca.student_id = career_plans.student_id
      AND ca.counselor_id = auth.uid()
      AND ca.status = 'active'
  )
);

CREATE POLICY career_counselor_update
ON public.career_plans FOR UPDATE TO authenticated
USING (
  school_id = public.current_school_id()
  AND public.current_user_role() = 'counselor'
  AND EXISTS (
    SELECT 1 FROM public.counselor_assignments ca
    WHERE ca.school_id = career_plans.school_id
      AND ca.student_id = career_plans.student_id
      AND ca.counselor_id = auth.uid()
      AND ca.status = 'active'
  )
)
WITH CHECK (
  school_id = public.current_school_id()
  AND public.current_user_role() = 'counselor'
  AND EXISTS (
    SELECT 1 FROM public.counselor_assignments ca
    WHERE ca.school_id = career_plans.school_id
      AND ca.student_id = career_plans.student_id
      AND ca.counselor_id = auth.uid()
      AND ca.status = 'active'
  )
);

-- Konselor sengaja tidak diberi DELETE.
-- Riwayat rencana tidak hilang hanya karena siswa berpindah konselor.
