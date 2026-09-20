-- ============================================================
-- SahabatBK v2.9 - Keamanan Konseling & Tindak Lanjut
-- Jalankan sekali di Supabase SQL Editor sebagai owner proyek.
-- Tidak menghapus data konseling/tindak lanjut lama.
-- Prinsip:
-- 1. Catatan rahasia hanya dapat dibaca pemilik/konselor pembuat.
-- 2. Catatan baru hanya boleh dibuat untuk siswa binaan aktif.
-- 3. Serah terima tidak memindahkan kepemilikan catatan lama.
-- 4. Identitas siswa/pemilik pada catatan lama tidak dapat diganti saat edit.
-- ============================================================

-- ---------- KONSELING: validasi relasi dan kepemilikan ----------
CREATE OR REPLACE FUNCTION public.validate_counseling_session_v29()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student_school uuid;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW.school_id IS DISTINCT FROM OLD.school_id
       OR NEW.student_id IS DISTINCT FROM OLD.student_id
       OR NEW.counselor_id IS DISTINCT FROM OLD.counselor_id THEN
      RAISE EXCEPTION 'Sekolah, siswa, dan pemilik catatan konseling tidak dapat diubah';
    END IF;
    RETURN NEW;
  END IF;

  SELECT school_id INTO v_student_school
  FROM public.students WHERE id = NEW.student_id;

  IF v_student_school IS NULL OR v_student_school <> NEW.school_id THEN
    RAISE EXCEPTION 'Siswa tidak valid atau berasal dari sekolah berbeda';
  END IF;

  IF NEW.counselor_id <> auth.uid() THEN
    RAISE EXCEPTION 'Pemilik catatan konseling harus akun konselor yang sedang login';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.counselor_assignments ca
    WHERE ca.school_id = NEW.school_id
      AND ca.student_id = NEW.student_id
      AND ca.counselor_id = NEW.counselor_id
      AND ca.status = 'active'
  ) THEN
    RAISE EXCEPTION 'Siswa bukan siswa binaan aktif konselor';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_counseling_session_v29 ON public.counseling_sessions;
CREATE TRIGGER trg_validate_counseling_session_v29
BEFORE INSERT OR UPDATE ON public.counseling_sessions
FOR EACH ROW EXECUTE FUNCTION public.validate_counseling_session_v29();

ALTER TABLE public.counseling_sessions ENABLE ROW LEVEL SECURITY;

-- Hapus seluruh policy lama pada tabel rahasia agar tidak ada policy longgar tersisa.
DO $$
DECLARE p record;
BEGIN
  FOR p IN SELECT policyname FROM pg_policies
           WHERE schemaname='public' AND tablename='counseling_sessions'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.counseling_sessions', p.policyname);
  END LOOP;
END $$;

CREATE POLICY counseling_owner_select
ON public.counseling_sessions FOR SELECT TO authenticated
USING (
  public.current_user_role() = 'counselor'
  AND school_id = public.current_school_id()
  AND counselor_id = auth.uid()
);

CREATE POLICY counseling_owner_insert
ON public.counseling_sessions FOR INSERT TO authenticated
WITH CHECK (
  public.current_user_role() = 'counselor'
  AND school_id = public.current_school_id()
  AND counselor_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM public.counselor_assignments ca
    WHERE ca.school_id = counseling_sessions.school_id
      AND ca.student_id = counseling_sessions.student_id
      AND ca.counselor_id = auth.uid()
      AND ca.status = 'active'
  )
);

CREATE POLICY counseling_owner_update
ON public.counseling_sessions FOR UPDATE TO authenticated
USING (
  public.current_user_role() = 'counselor'
  AND school_id = public.current_school_id()
  AND counselor_id = auth.uid()
)
WITH CHECK (
  public.current_user_role() = 'counselor'
  AND school_id = public.current_school_id()
  AND counselor_id = auth.uid()
);

-- Sengaja tidak ada DELETE: riwayat konseling tidak dihapus dari aplikasi.

-- ---------- TINDAK LANJUT: validasi relasi dan kepemilikan ----------
CREATE OR REPLACE FUNCTION public.validate_follow_up_v29()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student_school uuid;
  v_counseling_student uuid;
  v_counseling_owner uuid;
  v_counseling_school uuid;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW.school_id IS DISTINCT FROM OLD.school_id
       OR NEW.student_id IS DISTINCT FROM OLD.student_id
       OR NEW.created_by IS DISTINCT FROM OLD.created_by
       OR NEW.counseling_id IS DISTINCT FROM OLD.counseling_id THEN
      RAISE EXCEPTION 'Siswa, pemilik, sekolah, dan kaitan konseling pada tindak lanjut tidak dapat diubah';
    END IF;
    RETURN NEW;
  END IF;

  SELECT school_id INTO v_student_school
  FROM public.students WHERE id = NEW.student_id;

  IF v_student_school IS NULL OR v_student_school <> NEW.school_id THEN
    RAISE EXCEPTION 'Siswa tidak valid atau berasal dari sekolah berbeda';
  END IF;

  IF NEW.created_by <> auth.uid() THEN
    RAISE EXCEPTION 'Pemilik tindak lanjut harus akun konselor yang sedang login';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.counselor_assignments ca
    WHERE ca.school_id = NEW.school_id
      AND ca.student_id = NEW.student_id
      AND ca.counselor_id = NEW.created_by
      AND ca.status = 'active'
  ) THEN
    RAISE EXCEPTION 'Siswa bukan siswa binaan aktif konselor';
  END IF;

  IF NEW.counseling_id IS NOT NULL THEN
    SELECT student_id, counselor_id, school_id
      INTO v_counseling_student, v_counseling_owner, v_counseling_school
    FROM public.counseling_sessions
    WHERE id = NEW.counseling_id;

    IF v_counseling_student IS NULL
       OR v_counseling_student <> NEW.student_id
       OR v_counseling_owner <> NEW.created_by
       OR v_counseling_school <> NEW.school_id THEN
      RAISE EXCEPTION 'Catatan konseling yang dikaitkan tidak sesuai dengan siswa atau konselor';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_follow_up_v29 ON public.follow_ups;
CREATE TRIGGER trg_validate_follow_up_v29
BEFORE INSERT OR UPDATE ON public.follow_ups
FOR EACH ROW EXECUTE FUNCTION public.validate_follow_up_v29();

ALTER TABLE public.follow_ups ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE p record;
BEGIN
  FOR p IN SELECT policyname FROM pg_policies
           WHERE schemaname='public' AND tablename='follow_ups'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.follow_ups', p.policyname);
  END LOOP;
END $$;

CREATE POLICY followup_owner_select
ON public.follow_ups FOR SELECT TO authenticated
USING (
  public.current_user_role() = 'counselor'
  AND school_id = public.current_school_id()
  AND created_by = auth.uid()
);

CREATE POLICY followup_owner_insert
ON public.follow_ups FOR INSERT TO authenticated
WITH CHECK (
  public.current_user_role() = 'counselor'
  AND school_id = public.current_school_id()
  AND created_by = auth.uid()
  AND EXISTS (
    SELECT 1 FROM public.counselor_assignments ca
    WHERE ca.school_id = follow_ups.school_id
      AND ca.student_id = follow_ups.student_id
      AND ca.counselor_id = auth.uid()
      AND ca.status = 'active'
  )
);

CREATE POLICY followup_owner_update
ON public.follow_ups FOR UPDATE TO authenticated
USING (
  public.current_user_role() = 'counselor'
  AND school_id = public.current_school_id()
  AND created_by = auth.uid()
)
WITH CHECK (
  public.current_user_role() = 'counselor'
  AND school_id = public.current_school_id()
  AND created_by = auth.uid()
);

-- Sengaja tidak ada DELETE.
