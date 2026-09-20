
/* SAHABATBK - DATA INTEGRITY & VALIDATION v1
   NIS = identitas internal utama; NISN opsional. */
function normalisasiNIS(v){ return String(v ?? "").trim(); }
function normalisasiNISN(v){ const s=String(v ?? "").trim(); return s || null; }
function pesanErrorData(err){
  const msg=String(err?.message || err || "");
  const low=msg.toLowerCase();
  if(low.includes("students_school_nis_unique") || (low.includes("duplicate key") && low.includes("nis")))
    return "NIS sudah digunakan oleh siswa lain di sekolah ini.";
  if(low.includes("classes_school_name_year_unique") || (low.includes("duplicate key") && low.includes("class")))
    return "Nama kelas tersebut sudah digunakan pada tahun ajaran yang sama.";
  if(low.includes("students_nis_not_blank")) return "NIS wajib diisi.";
  if(low.includes("students_full_name_not_blank")) return "Nama siswa wajib diisi.";
  if(low.includes("classes_name_not_blank")) return "Nama kelas wajib diisi.";
  if(low.includes("classes_academic_year_not_blank")) return "Tahun ajaran wajib diisi.";
  if(low.includes("classes_grade_level_valid")) return "Tingkat kelas hanya boleh 10, 11, atau 12.";
  return msg || "Terjadi kesalahan saat menyimpan data.";
}
function validasiSiswaInternal(data){
  const nama=formatNama(data?.full_name || "");
  const nis=normalisasiNIS(data?.nis);
  if(!nama) return {ok:false,pesan:"Nama siswa wajib diisi."};
  if(!nis) return {ok:false,pesan:"NIS wajib diisi."};
  return {ok:true,nama,nis,nisn:normalisasiNISN(data?.nisn)};
}

/* =========================================================
   SAHABATBK v1.0
   APP.JS
========================================================= */


/* =========================================================
   1. KONEKSI SUPABASE
========================================================= */

const SUPABASE_URL =
  "https://ofhssxcjdfdbuvyvulhk.supabase.co";

const SUPABASE_KEY =
  "sb_publishable_ck4DfAbICEnevkTPPdgkXg_KO8ay6kM";

const client = window.supabase.createClient(
  SUPABASE_URL,
  SUPABASE_KEY
);


/* =========================================================
   2. ELEMEN UTAMA
========================================================= */

const loginPage =
  document.querySelector(".login-page");

const dashboard =
  document.getElementById("dashboard");

const loginForm =
  document.getElementById("loginForm");

const message =
  document.getElementById("message");

const logoutBtn =
  document.getElementById("logoutBtn");


/* =========================================================
   3. LOGIN
========================================================= */

loginForm.addEventListener("submit", async (event) => {

  event.preventDefault();

  const submitBtn = loginForm.querySelector('button[type="submit"]');
  if (submitBtn?.disabled) return;
  if (submitBtn) submitBtn.disabled = true;

  const email =
    document.getElementById("email")
      .value
      .trim();

  const password =
    document.getElementById("password")
      .value;

  message.textContent =
    "Memeriksa akun...";


  const { data, error } =
    await client.auth.signInWithPassword({

      email,
      password

    });


  if (error) {

    console.error(error);

    message.textContent =
      "Login gagal. Periksa email, password, atau status akun.";

    if (submitBtn) submitBtn.disabled = false;
    return;
  }

  try {
    await tampilkanDashboard(data.user);

    // Sesi baru harus langsung merender UI sesuai role akun yang baru login.
    await terapkanRoleUI();
    await muatDashboardRole();
    rapikanDashboardV21();
  } catch (err) {
    console.error("Inisialisasi setelah login gagal:", err);
    message.textContent = "Login berhasil, tetapi aplikasi gagal memuat data. Periksa koneksi lalu coba lagi.";
    await client.auth.signOut();
    dashboard.style.display = "none";
    loginPage.style.display = "flex";
  } finally {
    if (submitBtn) submitBtn.disabled = false;
  }

});


/* =========================================================
   4. TAMPILKAN DASHBOARD
========================================================= */

async function tampilkanDashboard(user) {

  const { data: profile, error } =
    await client
      .from("profiles")
      .select(`
        full_name,
        role,
        school_id,
        schools (
          name,
          subscription_plan
        )
      `)
      .eq("id", user.id)
      .single();


  if (error || !profile) {

    console.error(error);

    message.textContent =
      "Profil pengguna tidak ditemukan.";

    return;
  }


  loginPage.style.display = "none";
  dashboard.style.display = "block";


  document.getElementById("userName")
    .textContent =
    profile.full_name;


  document.getElementById("userRole")
    .textContent =
    ubahRole(profile.role);


  document.getElementById("schoolName")
    .textContent =
    profile.schools?.name || "Sekolah";


  document.getElementById("welcomeText")
    .textContent =
    "Selamat datang, " + profile.full_name;


  await muatStatistik();

}


/* =========================================================
   5. STATISTIK DASHBOARD
========================================================= */

async function muatStatistik() {

  const [
    siswa,
    asesmen,
    konseling,
    tindakLanjut
  ] = await Promise.all([

    client
      .from("students")
      .select("*", {
        count: "exact",
        head: true
      }),

    client
      .from("assessments")
      .select("*", {
        count: "exact",
        head: true
      }),

    client
      .from("counseling_sessions")
      .select("*", {
        count: "exact",
        head: true
      }),

    client
      .from("follow_ups")
      .select("*", {
        count: "exact",
        head: true
      })
      .neq("status", "completed")

  ]);


  document.getElementById("totalStudents")
    .textContent =
    siswa.count ?? 0;


  document.getElementById("totalAssessments")
    .textContent =
    asesmen.count ?? 0;


  document.getElementById("totalCounseling")
    .textContent =
    konseling.count ?? 0;


  document.getElementById("totalFollowups")
    .textContent =
    tindakLanjut.count ?? 0;

}


/* =========================================================
   6. NAMA ROLE
========================================================= */

function ubahRole(role) {

  const roles = {

    superadmin:
      "Super Admin",

    school_admin:
      "Admin Sekolah",

    counselor:
      "Guru BK",

    student:
      "Siswa"

  };

  return roles[role] || role;

}


/* =========================================================
   7. LOGOUT
========================================================= */

logoutBtn.addEventListener(
  "click",
  async () => {

    await client.auth.signOut();

    // v2.6.3: bersihkan state role lama sebelum akun lain login.
    roleAktifUI = null;
    setRoleBadge(null);
    setMenuVisibleByText("Konseling", true);
    setMenuVisibleByText("Tindak Lanjut", true);
    setMenuVisibleByText("Pengaturan", true);

    dashboard.style.display = "none";
    loginPage.style.display = "flex";

    loginForm.reset();

    message.textContent = "";

  }
);


/* =========================================================
   8. CEK SESI LOGIN
========================================================= */

async function cekSesi() {

  const { data } =
    await client.auth.getSession();


  if (data.session) {

    await tampilkanDashboard(
      data.session.user
    );

  }

}


/* =========================================================
   9. DATA SISWA - ELEMEN
========================================================= */

const studentPage =
  document.getElementById("studentPage");

const studentProfilePage =
  document.getElementById(
    "studentProfilePage"
  );

const studentModal =
  document.getElementById("studentModal");

const addStudentBtn =
  document.getElementById("addStudentBtn");

const closeStudentModal =
  document.getElementById(
    "closeStudentModal"
  );

const studentForm =
  document.getElementById("studentForm");

const studentTableBody =
  document.getElementById(
    "studentTableBody"
  );

const studentClass =
  document.getElementById("studentClass");

const classFilter =
  document.getElementById("classFilter");

const searchStudent =
  document.getElementById(
    "searchStudent"
  );

const studentMessage =
  document.getElementById(
    "studentMessage"
  );

const editStudentBtn =
  document.getElementById(
    "editStudentBtn"
  );


let daftarSiswa = [];
let daftarKelas = [];
let siswaSedangDiedit = null;


/* =========================================================
   10. MENU
========================================================= */

const menuButtons = document.querySelectorAll(".menu");
const dashboardHome = document.getElementById("dashboardHome");
const assessmentPage = document.getElementById("assessmentPage");
const topbarTitle = document.getElementById("topbarTitle");

function sembunyikanSemuaHalaman() {
  if (dashboardHome) dashboardHome.style.display = "none";
  studentPage.style.display = "none";
  studentProfilePage.style.display = "none";
  if (assessmentPage) assessmentPage.style.display = "none";
  const talentPage = document.getElementById("talentPage");
  if (talentPage) talentPage.style.display = "none";
  const counselingPage = document.getElementById("counselingPage");
  if (counselingPage) counselingPage.style.display = "none";
  const followupPage = document.getElementById("followupPage");
  if (followupPage) followupPage.style.display = "none";
  const careerPage = document.getElementById("careerPage");
  if (careerPage) careerPage.style.display = "none";
  const reportPage = document.getElementById("reportPage");
  if (reportPage) reportPage.style.display = "none";
  const settingsPage = document.getElementById("settingsPage");
  if (settingsPage) settingsPage.style.display = "none";
}

// v2.6.2: navigasi sidebar terpusat.
// Tidak menempelkan listener ke tiap tombol agar render modul lain tidak dapat
// membuat navigasi sidebar kehilangan respons.
let navigasiToken = 0;

async function navigasiKeMenu(button) {
  if (!button) return;
  const token = ++navigasiToken;
  const namaMenu = (button.textContent || "").trim();

  menuButtons.forEach(btn => btn.classList.remove("active"));
  button.classList.add("active");
  sembunyikanSemuaHalaman();
  if (topbarTitle) topbarTitle.textContent = namaMenu;

  // Tampilkan halaman tujuan lebih dulu. Pemuatan data berjalan setelahnya,
  // sehingga klik sidebar berikutnya tidak bergantung pada request sebelumnya.
  try {
    if (namaMenu === "Dashboard") {
      if (dashboardHome) dashboardHome.style.display = "block";
      await muatStatistik();
    } else if (namaMenu === "Data Siswa") {
      studentPage.style.display = "block";
      await muatKelas();
      if (token === navigasiToken) await muatSiswa();
    } else if (namaMenu === "Asesmen") {
      if (assessmentPage) assessmentPage.style.display = "block";
      await muatAsesmen();
    } else if (namaMenu === "Bakat & Minat") {
      const page = document.getElementById("talentPage");
      if (page) page.style.display = "block";
      await muatPemetaanBakatMinat();
    } else if (namaMenu === "Konseling") {
      const page = document.getElementById("counselingPage");
      if (page) page.style.display = "block";
      await muatKonseling();
    } else if (namaMenu === "Tindak Lanjut") {
      const page = document.getElementById("followupPage");
      if (page) page.style.display = "block";
      await muatTindakLanjut();
    } else if (namaMenu === "Karier & Studi") {
      const page = document.getElementById("careerPage");
      if (page) page.style.display = "block";
      await muatKarierStudi();
    } else if (namaMenu === "Laporan") {
      const page = document.getElementById("reportPage");
      if (page) page.style.display = "block";
      await muatLaporan();
    } else if (namaMenu === "Pengaturan") {
      const page = document.getElementById("settingsPage");
      if (page) page.style.display = "block";
      await muatPengaturan();
    } else {
      if (dashboardHome) dashboardHome.style.display = "block";
    }
  } catch (err) {
    console.error("Gagal memuat menu " + namaMenu, err);
  } finally {
    if (token === navigasiToken) {
      window.scrollTo({ top: 0, behavior: "auto" });
    }
  }
}

const sidebarNav = document.querySelector(".sidebar nav");
if (sidebarNav) {
  sidebarNav.addEventListener("click", (event) => {
    const button = event.target.closest("button.menu");
    if (!button || !sidebarNav.contains(button)) return;
    event.preventDefault();
    // Jangan await di event handler: sidebar tetap menerima klik baru walaupun
    // request Supabase dari menu sebelumnya masih berjalan.
    void navigasiKeMenu(button);
  });
}



/* =========================================================
   11. AMBIL DATA KELAS
========================================================= */

async function muatKelas() {

  const { data, error } =
    await client
      .from("classes")
      .select(`
        id,
        name,
        grade_level
      `)
      .order("grade_level")
      .order("name");


  if (error) {

    console.error(
      "Gagal mengambil kelas:",
      error
    );

    return;
  }


  daftarKelas = data || [];


  studentClass.innerHTML =
    '<option value="">Pilih kelas</option>';


  classFilter.innerHTML =
    '<option value="">Semua Kelas</option>';


  daftarKelas.forEach(kelas => {

    const optionForm =
      document.createElement("option");

    optionForm.value =
      kelas.id;

    optionForm.textContent =
      kelas.name;

    studentClass.appendChild(
      optionForm
    );


    const optionFilter =
      document.createElement("option");

    optionFilter.value =
      kelas.id;

    optionFilter.textContent =
      kelas.name;

    classFilter.appendChild(
      optionFilter
    );

  });

}


/* =========================================================
   12. AMBIL DATA SISWA
========================================================= */

async function muatSiswa() {

  const role = roleAktifUI || await ambilRoleAktif();
  let idsBinaan = null;

  // v2.8: Konselor hanya bekerja dengan siswa yang sedang ditugaskan kepadanya.
  if (role === "counselor") {
    const { data: { user } } = await client.auth.getUser();
    if (!user) { daftarSiswa = []; tampilkanSiswa(); return; }
    const { data: tugas, error: tugasError } = await client
      .from("counselor_assignments")
      .select("student_id")
      .eq("counselor_id", user.id)
      .eq("status", "active");
    if (tugasError) {
      console.error("Gagal mengambil siswa binaan:", tugasError);
      daftarSiswa = []; tampilkanSiswa(); return;
    }
    idsBinaan = [...new Set((tugas || []).map(x => x.student_id).filter(Boolean))];
    if (!idsBinaan.length) { daftarSiswa = []; tampilkanSiswa(); return; }
  }

  let query = client
    .from("students")
    .select(`
      id, nis, nisn, full_name, gender, status, class_id,
      classes ( name )
    `)
    .order("full_name");

  if (idsBinaan) query = query.in("id", idsBinaan);
  const { data, error } = await query;

  if (error) {
    console.error("Gagal mengambil siswa:", error);
    return;
  }

  daftarSiswa = data || [];
  tampilkanSiswa();
}


/* =========================================================
   13. TAMPILKAN DAFTAR SISWA
========================================================= */

function tampilkanSiswa() {

  const kataKunci =
    searchStudent
      .value
      .toLowerCase()
      .trim();


  const kelasDipilih =
    classFilter.value;


  const hasil =
    daftarSiswa.filter(siswa => {

      const cocokPencarian =

        siswa.full_name
          .toLowerCase()
          .includes(kataKunci)

        ||

        (siswa.nis || "")
          .toLowerCase()
          .includes(kataKunci)

        ||

        (siswa.nisn || "")
          .toLowerCase()
          .includes(kataKunci);


      const cocokKelas =

        !kelasDipilih

        ||

        siswa.class_id ===
          kelasDipilih;


      return (
        cocokPencarian &&
        cocokKelas
      );

    });


  if (hasil.length === 0) {

    studentTableBody.innerHTML = `
      <tr>
        <td
          colspan="6"
          class="empty-data"
        >
          Belum ada data siswa.
        </td>
      </tr>
    `;

    return;
  }


  studentTableBody.innerHTML =
    hasil.map(siswa => `

      <tr>

        <td>
          ${aman(siswa.nis || "-")}
        </td>

        <td>
          <strong>
            ${aman(siswa.full_name)}
          </strong>
        </td>

        <td>
          ${aman(
            siswa.classes?.name || "-"
          )}
        </td>

        <td>
          ${aman(
            siswa.gender || "-"
          )}
        </td>

        <td>
          ${namaStatus(
            siswa.status
          )}
        </td>

        <td>

          <button
            type="button"
            class="table-action"
            onclick="lihatSiswa(
              '${siswa.id}'
            )"
          >
            Lihat
          </button>

        </td>

      </tr>

    `).join("");

}


/* =========================================================
   14. NAMA STATUS SISWA
========================================================= */

function namaStatus(status) {

  const statusNama = {

    active:
      "Aktif",

    graduated:
      "Lulus",

    moved:
      "Pindah",

    inactive:
      "Tidak Aktif"

  };

  return statusNama[status] ||
    status ||
    "-";

}


/* =========================================================
   15. BUKA FORM TAMBAH SISWA
========================================================= */

addStudentBtn.addEventListener(
  "click",
  async () => {

    siswaSedangDiedit = null;


    document.querySelector(
      "#studentModal .modal-header h3"
    ).textContent =
      "Tambah Siswa";


    await muatKelas();


    studentForm.reset();

    studentMessage.textContent = "";

    studentModal.style.display =
      "flex";

  }
);


/* =========================================================
   16. TUTUP FORM SISWA
========================================================= */

closeStudentModal.addEventListener(
  "click",
  () => {

    studentModal.style.display =
      "none";

  }
);


studentModal.addEventListener(
  "click",
  (event) => {

    if (
      event.target === studentModal
    ) {

      studentModal.style.display =
        "none";

    }

  }
);


/* =========================================================
   17. SIMPAN / EDIT SISWA
========================================================= */

studentForm.addEventListener(
  "submit",
  async (event) => {

    event.preventDefault();


    const {
      data: { user }
    } =
      await client.auth.getUser();


    if (!user) {

      studentMessage.textContent =
        "Sesi login telah berakhir.";

      return;
    }


    const {
      data: profile,
      error: profileError
    } =
      await client
        .from("profiles")
        .select("school_id")
        .eq("id", user.id)
        .single();


    if (
      profileError ||
      !profile
    ) {

      console.error(profileError);

      studentMessage.textContent =
        "Data sekolah pengguna tidak ditemukan.";

      return;
    }


    const nama =
      document.getElementById(
        "studentName"
      ).value.trim();


    const kelas =
      document.getElementById(
        "studentClass"
      ).value;


    const gender =
      document.getElementById(
        "studentGender"
      ).value;


    if (
      !nama ||
      !kelas ||
      !gender
    ) {

      studentMessage.textContent =
        "Lengkapi data wajib siswa.";

      return;
    }


    studentMessage.textContent =
      siswaSedangDiedit
        ? "Memperbarui data..."
        : "Menyimpan data...";


    const dataSiswa = {

      school_id:
        profile.school_id,

      class_id:
        kelas,

      full_name:
        formatNama(nama),

      nis:
        document.getElementById(
          "studentNis"
        ).value.trim() || null,

      nisn:
        document.getElementById(
          "studentNisn"
        ).value.trim() || null,

      gender:
        gender

    };


    let hasilSimpan;


    /* EDIT */

    if (siswaSedangDiedit) {

      hasilSimpan =
        await client
          .from("students")
          .update(dataSiswa)
          .eq(
            "id",
            siswaSedangDiedit.id
          );

    }


    /* TAMBAH BARU */

    else {

      dataSiswa.status =
        "active";


      hasilSimpan =
        await client
          .from("students")
          .insert(dataSiswa);

    }


    const error =
      hasilSimpan.error;


    if (error) {

      console.error(error);

      studentMessage.textContent =
        siswaSedangDiedit
          ? "Data siswa gagal diperbarui."
          : "Data siswa gagal disimpan.";

      return;
    }


    studentMessage.textContent =
      siswaSedangDiedit
        ? "Data siswa berhasil diperbarui."
        : "Data siswa berhasil disimpan.";


    const idSiswaDiedit =
      siswaSedangDiedit?.id;


    await muatSiswa();

    await muatStatistik();


    /* Jika sedang edit,
       perbarui juga halaman profil */

    if (idSiswaDiedit) {

      const siswaBaru =
        daftarSiswa.find(
          item =>
            item.id ===
            idSiswaDiedit
        );


      if (siswaBaru) {

        siswaSedangDiedit =
          siswaBaru;

        isiProfilSiswa(
          siswaBaru
        );

      }

    }


    setTimeout(() => {

      studentModal.style.display =
        "none";

      studentMessage.textContent =
        "";

    }, 700);

  }
);


/* =========================================================
   18. PENCARIAN DAN FILTER
========================================================= */

searchStudent.addEventListener(
  "input",
  tampilkanSiswa
);


classFilter.addEventListener(
  "change",
  tampilkanSiswa
);


/* =========================================================
   19. PROFIL SISWA
========================================================= */

async function lihatSiswa(id) {

  const siswa =
    daftarSiswa.find(
      item =>
        item.id === id
    );


  if (!siswa) {

    alert(
      "Data siswa tidak ditemukan."
    );

    return;
  }


  siswaSedangDiedit =
    siswa;


  studentPage.style.display =
    "none";


  studentProfilePage.style.display =
    "block";


  isiProfilSiswa(siswa);


  await muatRiwayatSiswa(id);


  studentProfilePage.scrollIntoView({
    behavior: "smooth"
  });

}


/* =========================================================
   20. ISI IDENTITAS PROFIL SISWA
========================================================= */

function isiProfilSiswa(siswa) {

  aturAksiCepatProfilSiswa();

  document.getElementById(
    "profileName"
  ).textContent =
    siswa.full_name;


  document.getElementById(
    "profileInitial"
  ).textContent =
    siswa.full_name
      .charAt(0)
      .toUpperCase();


  document.getElementById(
    "profileNis"
  ).textContent =
    siswa.nis || "-";


  document.getElementById(
    "profileNisn"
  ).textContent =
    siswa.nisn || "-";


  document.getElementById(
    "profileClass"
  ).textContent =
    siswa.classes?.name || "-";


  document.getElementById(
    "profileGender"
  ).textContent =

    siswa.gender === "L"
      ? "Laki-laki"

      : siswa.gender === "P"
      ? "Perempuan"

      : "-";


  document.getElementById(
    "profileStatus"
  ).textContent =
    namaStatus(
      siswa.status
    );

}


/* =========================================================
   21. RIWAYAT BK SISWA
========================================================= */

async function muatRiwayatSiswa(id) {

  const [
    asesmen,
    konseling,
    tindakLanjut
  ] = await Promise.all([

    client
      .from("assessment_results")
      .select("*", {
        count: "exact",
        head: true
      })
      .eq(
        "student_id",
        id
      ),

    client
      .from("counseling_sessions")
      .select("*", {
        count: "exact",
        head: true
      })
      .eq(
        "student_id",
        id
      ),

    client
      .from("follow_ups")
      .select("*", {
        count: "exact",
        head: true
      })
      .eq(
        "student_id",
        id
      )

  ]);


  document.getElementById(
    "profileAssessmentCount"
  ).textContent =
    asesmen.count ?? 0;


  document.getElementById(
    "profileCounselingCount"
  ).textContent =
    konseling.count ?? 0;


  document.getElementById(
    "profileFollowupCount"
  ).textContent =
    tindakLanjut.count ?? 0;


  document.getElementById(
    "profileTalentStatus"
  ).textContent =

    (asesmen.count ?? 0) > 0
      ? "Sudah Dipetakan"
      : "Belum Dipetakan";

}


/* =========================================================
   22. TOMBOL KEMBALI
========================================================= */

document
  .getElementById(
    "backToStudents"
  )
  .addEventListener(
    "click",
    () => {

      studentProfilePage.style.display =
        "none";

      studentPage.style.display =
        "block";

      studentPage.scrollIntoView({
        behavior: "smooth"
      });

    }
  );


/* =========================================================
   23. EDIT DATA SISWA
========================================================= */

editStudentBtn.addEventListener(
  "click",
  async () => {

    if (!siswaSedangDiedit) {

      alert(
        "Data siswa tidak ditemukan."
      );

      return;
    }


    await muatKelas();


    const siswa =
      siswaSedangDiedit;


    document.getElementById(
      "studentName"
    ).value =
      siswa.full_name || "";


    document.getElementById(
      "studentNis"
    ).value =
      siswa.nis || "";


    document.getElementById(
      "studentNisn"
    ).value =
      siswa.nisn || "";


    document.getElementById(
      "studentClass"
    ).value =
      siswa.class_id || "";


    document.getElementById(
      "studentGender"
    ).value =
      siswa.gender || "";


    document.querySelector(
      "#studentModal .modal-header h3"
    ).textContent =
      "Edit Data Siswa";


    studentMessage.textContent =
      "";


    studentModal.style.display =
      "flex";

  }
);


/* =========================================================
   SAHABATBK v2.8 - AKSI CEPAT PROFIL SISWA BINAAN
========================================================= */
function aturAksiCepatProfilSiswa(){
  const box=document.getElementById("counselorStudentQuickActions");
  if(!box)return;
  box.style.display=roleAktifUI==="counselor"?"flex":"none";
}

async function bukaKonselingDariProfil(){
  if(roleAktifUI!=="counselor" || !siswaSedangDiedit)return;
  konselingSedangDiedit=null; counselingForm.reset();
  await muatPilihanSiswaKonseling();
  const pilih=document.getElementById("counselingStudent");
  if(![...pilih.options].some(o=>o.value===siswaSedangDiedit.id)){
    alert("Siswa ini bukan siswa binaan aktif Anda."); return;
  }
  pilih.value=siswaSedangDiedit.id;
  document.getElementById("counselingDate").value=new Date().toISOString().slice(0,10);
  document.getElementById("counselingConfidentiality").value="private";
  document.getElementById("counselingStatus").value="open";
  document.getElementById("counselingModalTitle").textContent="Catat Konseling";
  counselingMessage.textContent=""; counselingModal.style.display="flex";
}

async function bukaTindakLanjutDariProfil(){
  if(roleAktifUI!=="counselor" || !siswaSedangDiedit)return;
  tindakLanjutSedangDiedit=null; followupForm.reset();
  await muatPilihanTindakLanjut();
  const pilih=document.getElementById("followupStudent");
  if(![...pilih.options].some(o=>o.value===siswaSedangDiedit.id)){
    alert("Siswa ini bukan siswa binaan aktif Anda."); return;
  }
  pilih.value=siswaSedangDiedit.id;
  document.getElementById("followupDate").value=new Date().toISOString().slice(0,10);
  document.getElementById("followupStatus").value="planned";
  document.getElementById("followupModalTitle").textContent="Tambah Tindak Lanjut";
  await muatKonselingUntukSiswa(siswaSedangDiedit.id);
  followupMessage.textContent=""; followupModal.style.display="flex";
}

document.getElementById("profileQuickCounseling")?.addEventListener("click",bukaKonselingDariProfil);
document.getElementById("profileQuickFollowup")?.addEventListener("click",bukaTindakLanjutDariProfil);

/* =========================================================
   24. FORMAT NAMA ORANG
   - SahabatBK: nama orang selalu HURUF KAPITAL
   - Merapikan spasi ganda
========================================================= */

function formatNama(nama) {
  return String(nama || "")
    .trim()
    .replace(/\s+/g, " ")
    .toLocaleUpperCase("id-ID");
}


/* =========================================================
   25. KEAMANAN TAMPILAN TEKS
========================================================= */

function aman(teks) {

  return String(teks)

    .replaceAll(
      "&",
      "&amp;"
    )

    .replaceAll(
      "<",
      "&lt;"
    )

    .replaceAll(
      ">",
      "&gt;"
    )

    .replaceAll(
      '"',
      "&quot;"
    )

    .replaceAll(
      "'",
      "&#039;"
    );

}


/* =========================================================
   26. MULAI APLIKASI
========================================================= */


/* =========================================================
   MODUL ASESMEN
========================================================= */
const addAssessmentBtn = document.getElementById("addAssessmentBtn");
const assessmentModal = document.getElementById("assessmentModal");
const closeAssessmentModal = document.getElementById("closeAssessmentModal");
const assessmentForm = document.getElementById("assessmentForm");
const assessmentTableBody = document.getElementById("assessmentTableBody");
const searchAssessment = document.getElementById("searchAssessment");
const assessmentStatusFilter = document.getElementById("assessmentStatusFilter");
const assessmentMessage = document.getElementById("assessmentMessage");

let daftarAsesmen = [];
let asesmenSedangDiedit = null;

async function muatAsesmen() {
  const { data, error } = await client.from("assessments")
    .select("id,title,assessment_type,description,is_active,created_at,created_by")
    .order("created_at", { ascending: false });
  if (error) {
    console.error(error);
    assessmentTableBody.innerHTML = '<tr><td colspan="5" class="empty-data">Data asesmen gagal dimuat.</td></tr>';
    return;
  }
  daftarAsesmen = data || [];
  tampilkanAsesmen();
}

function labelJenisAsesmen(jenis) {
  return ({kebutuhan:"Kebutuhan Siswa",minat:"Minat",bakat_minat:"Bakat & Minat",karier:"Karier & Studi",lainnya:"Lainnya"})[jenis] || jenis || "-";
}

function tampilkanAsesmen() {
  const kata = (searchAssessment?.value || "").toLowerCase().trim();
  const filter = assessmentStatusFilter?.value || "";
  const hasil = daftarAsesmen.filter(item => {
    const cocok = String(item.title || "").toLowerCase().includes(kata) ||
      labelJenisAsesmen(item.assessment_type).toLowerCase().includes(kata);
    const status = item.is_active ? "active" : "inactive";
    return cocok && (!filter || filter === status);
  });
  if (!hasil.length) {
    assessmentTableBody.innerHTML = '<tr><td colspan="5" class="empty-data">Belum ada asesmen.</td></tr>';
    return;
  }
  assessmentTableBody.innerHTML = hasil.map(item => {
    const tanggal = item.created_at ? new Date(item.created_at).toLocaleDateString("id-ID") : "-";
    return `<tr><td><strong>${aman(item.title)}</strong></td><td>${aman(labelJenisAsesmen(item.assessment_type))}</td><td>${item.is_active ? "Aktif" : "Nonaktif"}</td><td>${aman(tanggal)}</td><td><button type="button" class="table-action" onclick="editAsesmen('${item.id}')">Edit</button></td></tr>`;
  }).join("");
}

if (addAssessmentBtn) addAssessmentBtn.addEventListener("click", () => {
  asesmenSedangDiedit = null;
  assessmentForm.reset();
  document.getElementById("assessmentActive").value = "true";
  document.getElementById("assessmentModalTitle").textContent = "Tambah Asesmen";
  assessmentMessage.textContent = "";
  assessmentModal.style.display = "flex";
});

function tutupModalAsesmen() {
  assessmentModal.style.display = "none";
  assessmentMessage.textContent = "";
}
if (closeAssessmentModal) closeAssessmentModal.addEventListener("click", tutupModalAsesmen);
if (assessmentModal) assessmentModal.addEventListener("click", e => { if (e.target === assessmentModal) tutupModalAsesmen(); });

if (assessmentForm) assessmentForm.addEventListener("submit", async event => {
  event.preventDefault();
  const { data: { user } } = await client.auth.getUser();
  if (!user) { assessmentMessage.textContent = "Sesi login telah berakhir."; return; }

  const { data: profile, error: profileError } = await client.from("profiles").select("school_id").eq("id", user.id).single();
  if (profileError || !profile) { assessmentMessage.textContent = "Data sekolah pengguna tidak ditemukan."; return; }

  const payload = {
    school_id: profile.school_id,
    title: document.getElementById("assessmentTitle").value.trim(),
    assessment_type: document.getElementById("assessmentType").value,
    description: document.getElementById("assessmentDescription").value.trim() || null,
    is_active: document.getElementById("assessmentActive").value === "true",
    created_by: user.id
  };

  assessmentMessage.textContent = "Menyimpan asesmen...";
  const hasil = asesmenSedangDiedit
    ? await client.from("assessments").update(payload).eq("id", asesmenSedangDiedit.id)
    : await client.from("assessments").insert(payload);

  if (hasil.error) { console.error(hasil.error); assessmentMessage.textContent = "Asesmen gagal disimpan: " + hasil.error.message; return; }
  assessmentMessage.textContent = "Asesmen berhasil disimpan.";
  await muatAsesmen();
  await muatStatistik();
  setTimeout(tutupModalAsesmen, 600);
});

window.editAsesmen = function(id) {
  const item = daftarAsesmen.find(a => a.id === id);
  if (!item) return;
  asesmenSedangDiedit = item;
  document.getElementById("assessmentModalTitle").textContent = "Edit Asesmen";
  document.getElementById("assessmentTitle").value = item.title || "";
  document.getElementById("assessmentType").value = item.assessment_type || "";
  document.getElementById("assessmentDescription").value = item.description || "";
  document.getElementById("assessmentActive").value = item.is_active ? "true" : "false";
  assessmentMessage.textContent = "";
  assessmentModal.style.display = "flex";
};
if (searchAssessment) searchAssessment.addEventListener("input", tampilkanAsesmen);
if (assessmentStatusFilter) assessmentStatusFilter.addEventListener("change", tampilkanAsesmen);



/* =========================================================
   MODUL BAKAT & MINAT
========================================================= */
const addTalentBtn = document.getElementById("addTalentBtn");
const talentModal = document.getElementById("talentModal");
const closeTalentModal = document.getElementById("closeTalentModal");
const talentForm = document.getElementById("talentForm");
const talentStudent = document.getElementById("talentStudent");
const talentAssessment = document.getElementById("talentAssessment");
const talentSummary = document.getElementById("talentSummary");
const talentRecommendation = document.getElementById("talentRecommendation");
const talentMessage = document.getElementById("talentMessage");
const talentTableBody = document.getElementById("talentTableBody");
const searchTalent = document.getElementById("searchTalent");
const talentClassFilter = document.getElementById("talentClassFilter");

let daftarPemetaan = [];
let pemetaanSedangDiedit = null;

async function muatPilihanBakatMinat() {
  await muatKelas();
  await muatSiswa();

  talentStudent.innerHTML = '<option value="">Pilih siswa</option>' +
    daftarSiswa.filter(s => s.status === "active").map(s =>
      `<option value="${s.id}">${aman(s.full_name)} — ${aman(s.classes?.name || "-")}</option>`).join("");

  const { data: instrumen, error } = await client.from("assessments")
    .select("id,title,assessment_type,is_active")
    .eq("is_active", true)
    .in("assessment_type", ["minat","bakat_minat"])
    .order("title");

  if (error) console.error(error);
  talentAssessment.innerHTML = '<option value="">Pilih instrumen</option>' +
    (instrumen || []).map(a => `<option value="${a.id}">${aman(a.title)}</option>`).join("");

  talentClassFilter.innerHTML = '<option value="">Semua Kelas</option>' +
    daftarKelas.map(k => `<option value="${k.id}">${aman(k.name)}</option>`).join("");
}

async function muatPemetaanBakatMinat() {
  await muatPilihanBakatMinat();

  const { data, error } = await client.from("assessment_results")
    .select("id,assessment_id,student_id,result_summary,recommendation,completed_at,assessments(title,assessment_type),students(full_name,class_id,classes(name))")
    .order("completed_at", { ascending:false });

  if (error) {
    console.error(error);
    talentTableBody.innerHTML = '<tr><td colspan="5" class="empty-data">Data pemetaan gagal dimuat.</td></tr>';
    return;
  }
  daftarPemetaan = (data || []).filter(r => ["minat","bakat_minat"].includes(r.assessments?.assessment_type));
  tampilkanPemetaanBakatMinat();
}

function tampilkanPemetaanBakatMinat() {
  const kata = (searchTalent?.value || "").toLowerCase().trim();
  const kelas = talentClassFilter?.value || "";
  const hasil = daftarPemetaan.filter(r => {
    const cocokNama = String(r.students?.full_name || "").toLowerCase().includes(kata);
    const cocokKelas = !kelas || r.students?.class_id === kelas;
    return cocokNama && cocokKelas;
  });

  if (!hasil.length) {
    talentTableBody.innerHTML = '<tr><td colspan="5" class="empty-data">Belum ada hasil pemetaan.</td></tr>';
    return;
  }

  talentTableBody.innerHTML = hasil.map(r => `<tr>
    <td><strong>${aman(r.students?.full_name || "-")}</strong></td>
    <td>${aman(r.students?.classes?.name || "-")}</td>
    <td>${aman(r.assessments?.title || "-")}</td>
    <td>${aman(r.result_summary || "-")}</td>
    <td><button type="button" class="table-action" onclick="editPemetaan('${r.id}')">Edit</button></td>
  </tr>`).join("");
}

if (addTalentBtn) addTalentBtn.addEventListener("click", async () => {
  pemetaanSedangDiedit = null;
  talentForm.reset();
  talentMessage.textContent = "";
  await muatPilihanBakatMinat();
  talentModal.style.display = "flex";
});

function tutupTalentModal() {
  talentModal.style.display = "none";
  talentMessage.textContent = "";
}
if (closeTalentModal) closeTalentModal.addEventListener("click", tutupTalentModal);
if (talentModal) talentModal.addEventListener("click", e => {
  if (e.target === talentModal) tutupTalentModal();
});

if (talentForm) talentForm.addEventListener("submit", async e => {
  e.preventDefault();

  const { data:{user} } = await client.auth.getUser();
  if (!user) { talentMessage.textContent = "Sesi login telah berakhir."; return; }

  const { data:profile, error:profileError } = await client.from("profiles")
    .select("school_id").eq("id",user.id).single();
  if (profileError || !profile) {
    talentMessage.textContent = "Data sekolah pengguna tidak ditemukan.";
    return;
  }

  const payload = {
    school_id: profile.school_id,
    assessment_id: talentAssessment.value,
    student_id: talentStudent.value,
    result_summary: talentSummary.value.trim(),
    recommendation: talentRecommendation.value.trim() || null,
    completed_at: new Date().toISOString()
  };

  talentMessage.textContent = "Menyimpan pemetaan...";
  const hasil = pemetaanSedangDiedit
    ? await client.from("assessment_results").update(payload).eq("id",pemetaanSedangDiedit.id)
    : await client.from("assessment_results").insert(payload);

  if (hasil.error) {
    console.error(hasil.error);
    talentMessage.textContent = hasil.error.code === "23505"
      ? "Siswa sudah memiliki hasil untuk instrumen ini. Gunakan Edit."
      : "Pemetaan gagal disimpan: " + hasil.error.message;
    return;
  }

  talentMessage.textContent = "Pemetaan berhasil disimpan.";
  await muatPemetaanBakatMinat();
  setTimeout(tutupTalentModal,600);
});

window.editPemetaan = async function(id) {
  const r = daftarPemetaan.find(x => x.id === id);
  if (!r) return;
  pemetaanSedangDiedit = r;
  await muatPilihanBakatMinat();
  talentStudent.value = r.student_id;
  talentAssessment.value = r.assessment_id;
  talentSummary.value = r.result_summary || "";
  talentRecommendation.value = r.recommendation || "";
  talentMessage.textContent = "";
  talentModal.style.display = "flex";
};

if (searchTalent) searchTalent.addEventListener("input", tampilkanPemetaanBakatMinat);
if (talentClassFilter) talentClassFilter.addEventListener("change", tampilkanPemetaanBakatMinat);



/* =========================================================
   MODUL KONSELING
========================================================= */
const addCounselingBtn = document.getElementById("addCounselingBtn");
const counselingModal = document.getElementById("counselingModal");
const closeCounselingModal = document.getElementById("closeCounselingModal");
const counselingForm = document.getElementById("counselingForm");
const counselingTableBody = document.getElementById("counselingTableBody");
const searchCounseling = document.getElementById("searchCounseling");
const counselingStatusFilter = document.getElementById("counselingStatusFilter");
const counselingMessage = document.getElementById("counselingMessage");
let daftarKonseling = [];
let konselingSedangDiedit = null;

function labelStatusKonseling(v){return ({open:"Terbuka",monitoring:"Pemantauan",completed:"Selesai",referred:"Dirujuk"})[v]||v||"-";}
function labelJenisLayanan(v){return ({individual:"Konseling Individual",group:"Konseling Kelompok",consultation:"Konsultasi",referral:"Rujukan",other:"Lainnya"})[v]||v||"-";}

async function muatPilihanSiswaKonseling(){
  await muatSiswa();
  const el=document.getElementById("counselingStudent");
  el.innerHTML='<option value="">Pilih siswa</option>'+daftarSiswa.filter(s=>s.status==="active").map(s=>`<option value="${s.id}">${aman(s.full_name)} — ${aman(s.classes?.name||"-")}</option>`).join("");
}

async function muatKonseling(){
  /* muatKonseling_PRIVACY_V2 */
  const roleAktif=await ambilRoleAktif();
  if(!roleBolehBukaRahasia(roleAktif)){
    const body=document.getElementById("counselingTableBody");
    if(body)body.innerHTML='<tr><td colspan="8" class="empty-data">Data ini bersifat rahasia dan hanya dapat dibuka oleh akun Konselor.</td></tr>';
    return;
  }
  await muatPilihanSiswaKonseling();
  const {data,error}=await client.from("counseling_sessions")
    .select("id,student_id,counselor_id,session_date,service_type,topic,problem_summary,counseling_notes,confidentiality,status,created_at,students(full_name,classes(name))")
    .eq("counselor_id", (await client.auth.getUser()).data.user?.id || "00000000-0000-0000-0000-000000000000")
    .order("session_date",{ascending:false});
  if(error){console.error(error);counselingTableBody.innerHTML='<tr><td colspan="6" class="empty-data">Data konseling gagal dimuat.</td></tr>';return;}
  daftarKonseling=data||[]; tampilkanKonseling();
}

function tampilkanKonseling(){
  const q=(searchCounseling?.value||"").toLowerCase().trim(), f=counselingStatusFilter?.value||"";
  const rows=daftarKonseling.filter(x=>(String(x.students?.full_name||"").toLowerCase().includes(q)||String(x.topic||"").toLowerCase().includes(q))&&(!f||x.status===f));
  if(!rows.length){counselingTableBody.innerHTML='<tr><td colspan="6" class="empty-data">Belum ada catatan konseling.</td></tr>';return;}
  counselingTableBody.innerHTML=rows.map(x=>`<tr><td>${aman(x.session_date?new Date(x.session_date+"T00:00:00").toLocaleDateString("id-ID"):"-")}</td><td><strong>${aman(x.students?.full_name||"-")}</strong><br><small>${aman(x.students?.classes?.name||"-")}</small></td><td>${aman(labelJenisLayanan(x.service_type))}</td><td>${aman(x.topic||"-")}</td><td>${aman(labelStatusKonseling(x.status))}</td><td><button type="button" class="table-action" onclick="editKonseling('${x.id}')">Edit</button></td></tr>`).join("");
}

if(addCounselingBtn)addCounselingBtn.addEventListener("click",async()=>{
  konselingSedangDiedit=null;counselingForm.reset();await muatPilihanSiswaKonseling();
  document.getElementById("counselingStudent").disabled=false;
  document.getElementById("counselingDate").value=new Date().toISOString().slice(0,10);
  document.getElementById("counselingConfidentiality").value="private";
  document.getElementById("counselingStatus").value="open";
  document.getElementById("counselingModalTitle").textContent="Catat Konseling";
  counselingMessage.textContent="";counselingModal.style.display="flex";
});
function tutupKonseling(){counselingModal.style.display="none";counselingMessage.textContent="";const e=document.getElementById("counselingStudent");if(e)e.disabled=false;}
if(closeCounselingModal)closeCounselingModal.addEventListener("click",tutupKonseling);
if(counselingModal)counselingModal.addEventListener("click",e=>{if(e.target===counselingModal)tutupKonseling();});

async function siswaMasihBinaanAktif(studentId, counselorId){
  if(!studentId || !counselorId) return false;
  const {data,error}=await client.from("counselor_assignments")
    .select("id").eq("student_id",studentId).eq("counselor_id",counselorId).eq("status","active").limit(1);
  if(error){ console.error("Validasi siswa binaan gagal:",error); return false; }
  return Array.isArray(data) && data.length>0;
}

if(counselingForm)counselingForm.addEventListener("submit",async e=>{
  e.preventDefault();
  const {data:{user}}=await client.auth.getUser();
  if(!user){counselingMessage.textContent="Sesi login telah berakhir.";return;}
  const {data:profile,error:pe}=await client.from("profiles").select("school_id").eq("id",user.id).single();
  if(pe||!profile){counselingMessage.textContent="Data sekolah pengguna tidak ditemukan.";return;}
  const studentIdKonseling=document.getElementById("counselingStudent").value;
  if(!konselingSedangDiedit && !(await siswaMasihBinaanAktif(studentIdKonseling,user.id))){
    counselingMessage.textContent="Siswa bukan siswa binaan aktif Anda atau penugasannya sudah berubah. Muat ulang data siswa.";return;
  }
  const payload={
    school_id:profile.school_id,student_id:studentIdKonseling,
    counselor_id:user.id,session_date:document.getElementById("counselingDate").value,
    service_type:document.getElementById("counselingType").value,topic:document.getElementById("counselingTopic").value.trim(),
    problem_summary:document.getElementById("problemSummary").value.trim()||null,
    counseling_notes:document.getElementById("counselingNotes").value.trim()||null,
    confidentiality:document.getElementById("counselingConfidentiality").value,status:document.getElementById("counselingStatus").value
  };
  counselingMessage.textContent="Menyimpan konseling...";
  const hasil=konselingSedangDiedit?await client.from("counseling_sessions").update(payload).eq("id",konselingSedangDiedit.id):await client.from("counseling_sessions").insert(payload);
  if(hasil.error){console.error(hasil.error);counselingMessage.textContent="Konseling gagal disimpan: "+hasil.error.message;return;}
  counselingMessage.textContent="Konseling berhasil disimpan.";await muatKonseling();await muatStatistik();setTimeout(tutupKonseling,600);
});

window.editKonseling=async function(id){
  const x=daftarKonseling.find(v=>v.id===id);if(!x)return;konselingSedangDiedit=x;await muatPilihanSiswaKonseling();
  document.getElementById("counselingModalTitle").textContent="Edit Konseling";
  document.getElementById("counselingStudent").value=x.student_id||"";
  document.getElementById("counselingStudent").disabled=true;
  document.getElementById("counselingDate").value=x.session_date||"";
  document.getElementById("counselingType").value=x.service_type||"";
  document.getElementById("counselingTopic").value=x.topic||"";
  document.getElementById("problemSummary").value=x.problem_summary||"";
  document.getElementById("counselingNotes").value=x.counseling_notes||"";
  document.getElementById("counselingConfidentiality").value=x.confidentiality||"private";
  document.getElementById("counselingStatus").value=x.status||"open";
  counselingMessage.textContent="";counselingModal.style.display="flex";
};
if(searchCounseling)searchCounseling.addEventListener("input",tampilkanKonseling);
if(counselingStatusFilter)counselingStatusFilter.addEventListener("change",tampilkanKonseling);



/* =========================================================
   MODUL TINDAK LANJUT
========================================================= */
const addFollowupBtn=document.getElementById("addFollowupBtn");
const followupModal=document.getElementById("followupModal");
const closeFollowupModal=document.getElementById("closeFollowupModal");
const followupForm=document.getElementById("followupForm");
const followupTableBody=document.getElementById("followupTableBody");
const searchFollowup=document.getElementById("searchFollowup");
const followupStatusFilter=document.getElementById("followupStatusFilter");
const followupMessage=document.getElementById("followupMessage");
let daftarTindakLanjut=[], tindakLanjutSedangDiedit=null;

function labelStatusTindakLanjut(v){return ({planned:"Direncanakan",in_progress:"Proses",completed:"Selesai",cancelled:"Dibatalkan"})[v]||v||"-";}

async function muatPilihanTindakLanjut(){
  await muatSiswa();
  const s=document.getElementById("followupStudent");
  s.innerHTML='<option value="">Pilih siswa</option>'+daftarSiswa.filter(x=>x.status==="active").map(x=>`<option value="${x.id}">${aman(x.full_name)} — ${aman(x.classes?.name||"-")}</option>`).join("");
}
async function muatKonselingUntukSiswa(studentId,selected=""){
  const c=document.getElementById("followupCounseling");
  c.innerHTML='<option value="">Tanpa kaitan langsung</option>';
  if(!studentId)return;
  const {data,error}=await client.from("counseling_sessions").select("id,session_date,topic").eq("student_id",studentId).eq("counselor_id", (await client.auth.getUser()).data.user?.id || "00000000-0000-0000-0000-000000000000").order("session_date",{ascending:false});
  if(error){console.error(error);return;}
  c.innerHTML+=(data||[]).map(x=>`<option value="${x.id}">${aman(x.session_date||"-")} — ${aman(x.topic||"Tanpa topik")}</option>`).join("");
  c.value=selected||"";
}
async function muatTindakLanjut(){
  /* muatTindakLanjut_PRIVACY_V2 */
  const roleAktif=await ambilRoleAktif();
  if(!roleBolehBukaRahasia(roleAktif)){
    const body=document.getElementById("followupTableBody");
    if(body)body.innerHTML='<tr><td colspan="8" class="empty-data">Data ini bersifat rahasia dan hanya dapat dibuka oleh akun Konselor.</td></tr>';
    return;
  }
  await muatPilihanTindakLanjut();
  const {data,error}=await client.from("follow_ups").select("id,counseling_id,student_id,follow_up_date,action_plan,result_notes,status,created_by,created_at,students(full_name,classes(name))").eq("created_by", (await client.auth.getUser()).data.user?.id || "00000000-0000-0000-0000-000000000000").order("follow_up_date",{ascending:false});
  if(error){console.error(error);followupTableBody.innerHTML='<tr><td colspan="5" class="empty-data">Data tindak lanjut gagal dimuat.</td></tr>';return;}
  daftarTindakLanjut=data||[];tampilkanTindakLanjut();
}
function tampilkanTindakLanjut(){
  const q=(searchFollowup?.value||"").toLowerCase().trim(),f=followupStatusFilter?.value||"";
  const rows=daftarTindakLanjut.filter(x=>(String(x.students?.full_name||"").toLowerCase().includes(q)||String(x.action_plan||"").toLowerCase().includes(q))&&(!f||x.status===f));
  if(!rows.length){followupTableBody.innerHTML='<tr><td colspan="5" class="empty-data">Belum ada tindak lanjut.</td></tr>';return;}
  followupTableBody.innerHTML=rows.map(x=>`<tr><td>${aman(x.follow_up_date?new Date(x.follow_up_date+"T00:00:00").toLocaleDateString("id-ID"):"-")}</td><td><strong>${aman(x.students?.full_name||"-")}</strong><br><small>${aman(x.students?.classes?.name||"-")}</small></td><td>${aman(x.action_plan||"-")}</td><td>${aman(labelStatusTindakLanjut(x.status))}</td><td><button type="button" class="table-action" onclick="editTindakLanjut('${x.id}')">Edit</button></td></tr>`).join("");
}
if(addFollowupBtn)addFollowupBtn.addEventListener("click",async()=>{
  tindakLanjutSedangDiedit=null;followupForm.reset();await muatPilihanTindakLanjut();
  document.getElementById("followupStudent").disabled=false;
  document.getElementById("followupDate").value=new Date().toISOString().slice(0,10);
  document.getElementById("followupStatus").value="planned";document.getElementById("followupModalTitle").textContent="Tambah Tindak Lanjut";
  await muatKonselingUntukSiswa("");followupMessage.textContent="";followupModal.style.display="flex";
});
document.getElementById("followupStudent")?.addEventListener("change",e=>muatKonselingUntukSiswa(e.target.value));
function tutupFollowup(){followupModal.style.display="none";followupMessage.textContent="";const e=document.getElementById("followupStudent");if(e)e.disabled=false;}
if(closeFollowupModal)closeFollowupModal.addEventListener("click",tutupFollowup);
if(followupModal)followupModal.addEventListener("click",e=>{if(e.target===followupModal)tutupFollowup();});

if(followupForm)followupForm.addEventListener("submit",async e=>{
  e.preventDefault();
  const {data:{user}}=await client.auth.getUser();if(!user){followupMessage.textContent="Sesi login telah berakhir.";return;}
  const {data:profile,error:pe}=await client.from("profiles").select("school_id").eq("id",user.id).single();
  if(pe||!profile){followupMessage.textContent="Data sekolah pengguna tidak ditemukan.";return;}
  const studentIdFollowup=document.getElementById("followupStudent").value;
  if(!tindakLanjutSedangDiedit && !(await siswaMasihBinaanAktif(studentIdFollowup,user.id))){
    followupMessage.textContent="Siswa bukan siswa binaan aktif Anda atau penugasannya sudah berubah. Muat ulang data siswa.";return;
  }
  const payload={school_id:profile.school_id,counseling_id:document.getElementById("followupCounseling").value||null,student_id:studentIdFollowup,follow_up_date:document.getElementById("followupDate").value,action_plan:document.getElementById("followupPlan").value.trim(),result_notes:document.getElementById("followupResult").value.trim()||null,status:document.getElementById("followupStatus").value,created_by:user.id};
  followupMessage.textContent="Menyimpan tindak lanjut...";
  const hasil=tindakLanjutSedangDiedit?await client.from("follow_ups").update(payload).eq("id",tindakLanjutSedangDiedit.id):await client.from("follow_ups").insert(payload);
  if(hasil.error){console.error(hasil.error);followupMessage.textContent="Tindak lanjut gagal disimpan: "+hasil.error.message;return;}
  followupMessage.textContent="Tindak lanjut berhasil disimpan.";await muatTindakLanjut();await muatStatistik();setTimeout(tutupFollowup,600);
});
window.editTindakLanjut=async function(id){
  const x=daftarTindakLanjut.find(v=>v.id===id);if(!x)return;tindakLanjutSedangDiedit=x;await muatPilihanTindakLanjut();
  document.getElementById("followupModalTitle").textContent="Edit Tindak Lanjut";document.getElementById("followupStudent").value=x.student_id||"";
  document.getElementById("followupStudent").disabled=true;
  await muatKonselingUntukSiswa(x.student_id,x.counseling_id);
  document.getElementById("followupDate").value=x.follow_up_date||"";document.getElementById("followupPlan").value=x.action_plan||"";
  document.getElementById("followupResult").value=x.result_notes||"";document.getElementById("followupStatus").value=x.status||"planned";
  followupMessage.textContent="";followupModal.style.display="flex";
};
if(searchFollowup)searchFollowup.addEventListener("input",tampilkanTindakLanjut);
if(followupStatusFilter)followupStatusFilter.addEventListener("change",tampilkanTindakLanjut);



/* =========================================================
   MODUL KARIER & STUDI — SUPABASE
========================================================= */
const addCareerBtn=document.getElementById("addCareerBtn");
const careerModal=document.getElementById("careerModal");
const closeCareerModal=document.getElementById("closeCareerModal");
const careerForm=document.getElementById("careerForm");
const careerTableBody=document.getElementById("careerTableBody");
const searchCareer=document.getElementById("searchCareer");
const careerClassFilter=document.getElementById("careerClassFilter");
const careerPathFilter=document.getElementById("careerPathFilter");
const careerMessage=document.getElementById("careerMessage");
let daftarKarier=[], karierSedangDiedit=null, careerSchoolId="", careerUserId="";

function labelJalurKarier(v){
  return ({kuliah:"Kuliah",kerja:"Kerja",wirausaha:"Wirausaha",kedinasan:"Kedinasan",lainnya:"Lainnya"})[v]||v||"-";
}

async function muatPilihanKarier(){
  await muatKelas();
  await muatSiswa();
  const {data:{user}}=await client.auth.getUser();
  careerUserId=user?.id||"";
  if(user){
    const {data:p}=await client.from("profiles").select("school_id").eq("id",user.id).single();
    careerSchoolId=p?.school_id||"";
  }
  const siswa=document.getElementById("careerStudent");
  siswa.innerHTML='<option value="">Pilih siswa</option>'+daftarSiswa.filter(s=>s.status==="active").map(s=>`<option value="${s.id}">${aman(s.full_name)} — ${aman(s.classes?.name||"-")}</option>`).join("");
  careerClassFilter.innerHTML='<option value="">Semua Kelas</option>'+daftarKelas.map(k=>`<option value="${k.id}">${aman(k.name)}</option>`).join("");
}

async function muatReferensiBakatMinat(studentId, selected=""){
  const el=document.getElementById("careerTalentResult");
  el.innerHTML='<option value="">Tidak dikaitkan</option>';
  if(!studentId)return;
  const {data,error}=await client.from("assessment_results")
    .select("id,result_summary,assessments(title,assessment_type)")
    .eq("student_id",studentId)
    .order("completed_at",{ascending:false});
  if(error){console.error(error);return;}
  const hasil=(data||[]).filter(r=>["minat","bakat_minat"].includes(r.assessments?.assessment_type));
  el.innerHTML+=hasil.map(r=>`<option value="${r.id}">${aman(r.assessments?.title||"Pemetaan")} — ${aman((r.result_summary||"").slice(0,60))}</option>`).join("");
  el.value=selected||"";
}

async function muatKarierStudi(){
  await muatPilihanKarier();
  const role = roleAktifUI || await ambilRoleAktif();

  // v2.8.1: Konselor hanya memuat rencana milik siswa binaan aktif.
  // Ini mencegah baris anonim (- / -) ketika sebuah rencana milik siswa
  // yang tidak berada dalam daftar binaan konselor yang sedang login.
  const idsSiswaTerlihat = daftarSiswa.map(s => s.id).filter(Boolean);
  if (role === "counselor" && !idsSiswaTerlihat.length) {
    daftarKarier = [];
    tampilkanKarierStudi();
    return;
  }

  let query = client.from("career_plans")
    .select("id,school_id,student_id,plan_type,field,destination,notes,talent_result_id,created_by,created_at,updated_at")
    .eq("school_id",careerSchoolId);

  if (role === "counselor") query = query.in("student_id", idsSiswaTerlihat);

  const {data,error}=await query.order("updated_at",{ascending:false});
  if(error){
    console.error(error);
    daftarKarier=[];
    careerTableBody.innerHTML=`<tr><td colspan="6" class="empty-data">Data Karier & Studi gagal dimuat: ${aman(error.message)}</td></tr>`;
    return;
  }

  // Pertahanan UI tambahan: jangan pernah render record tanpa siswa yang dapat diakses.
  const siswaIds = new Set(idsSiswaTerlihat);
  daftarKarier=(data||[]).filter(x => role !== "counselor" || siswaIds.has(x.student_id));
  tampilkanKarierStudi();
}

function tampilkanKarierStudi(){
  const q=(searchCareer?.value||"").toLowerCase().trim();
  const kelas=careerClassFilter?.value||"";
  const jalur=careerPathFilter?.value||"";
  const rows=daftarKarier.filter(x=>{
    const s=daftarSiswa.find(v=>v.id===x.student_id);
    const teks=[s?.full_name,x.field,x.destination,x.notes].join(" ").toLowerCase();
    return teks.includes(q)&&(!kelas||s?.class_id===kelas)&&(!jalur||x.plan_type===jalur);
  });
  if(!rows.length){
    careerTableBody.innerHTML='<tr><td colspan="6" class="empty-data">Belum ada data rencana karier dan studi.</td></tr>';return;
  }
  careerTableBody.innerHTML=rows.map(x=>{
    const s=daftarSiswa.find(v=>v.id===x.student_id);
    return `<tr><td><strong>${aman(s?.full_name||"-")}</strong></td><td>${aman(s?.classes?.name||"-")}</td><td>${aman(labelJalurKarier(x.plan_type))}</td><td>${aman(x.field||"-")}</td><td>${aman(x.destination||"-")}</td><td><button type="button" class="table-action" onclick="editKarier('${x.id}')">Edit</button></td></tr>`;
  }).join("");
}

if(addCareerBtn)addCareerBtn.addEventListener("click",async()=>{
  karierSedangDiedit=null;careerForm.reset();await muatPilihanKarier();await muatReferensiBakatMinat("");
  document.getElementById("careerModalTitle").textContent="Tambah Rencana Karier & Studi";
  careerMessage.textContent="";careerModal.style.display="flex";
});
document.getElementById("careerStudent")?.addEventListener("change",e=>muatReferensiBakatMinat(e.target.value));
function tutupCareer(){careerModal.style.display="none";careerMessage.textContent="";}
if(closeCareerModal)closeCareerModal.addEventListener("click",tutupCareer);
if(careerModal)careerModal.addEventListener("click",e=>{if(e.target===careerModal)tutupCareer();});

if(careerForm)careerForm.addEventListener("submit",async e=>{
  e.preventDefault();
  careerMessage.textContent="Menyimpan...";
  const selectedStudentId=document.getElementById("careerStudent").value;
  if(!selectedStudentId){careerMessage.textContent="Pilih siswa terlebih dahulu.";return;}
  const role = roleAktifUI || await ambilRoleAktif();
  if(role === "counselor" && !daftarSiswa.some(s=>s.id===selectedStudentId)){
    careerMessage.textContent="Siswa bukan binaan aktif Anda. Muat ulang halaman lalu pilih siswa binaan.";
    return;
  }
  const payload={
    school_id:careerSchoolId,
    student_id:selectedStudentId,
    plan_type:document.getElementById("careerPath").value,
    field:document.getElementById("careerField").value.trim()||null,
    destination:document.getElementById("careerDestination").value.trim()||null,
    notes:document.getElementById("careerNotes").value.trim()||null,
    talent_result_id:document.getElementById("careerTalentResult").value||null,
    updated_at:new Date().toISOString()
  };
  let error;
  if(karierSedangDiedit){
    ({error}=await client.from("career_plans").update(payload).eq("id",karierSedangDiedit.id));
  }else{
    payload.created_by=careerUserId;
    ({error}=await client.from("career_plans").insert(payload));
  }
  if(error){careerMessage.textContent="Gagal menyimpan: "+error.message;return;}
  careerMessage.textContent="Rencana berhasil disimpan ke Supabase.";
  await muatKarierStudi();
  setTimeout(tutupCareer,600);
});

window.editKarier=async function(id){
  const x=daftarKarier.find(v=>v.id===id);if(!x)return;
  await muatPilihanKarier();
  const role = roleAktifUI || await ambilRoleAktif();
  if (role === "counselor" && !daftarSiswa.some(s => s.id === x.student_id)) {
    alert("Rencana ini tidak dapat dibuka karena siswa bukan lagi binaan aktif Anda.");
    await muatKarierStudi();
    return;
  }
  karierSedangDiedit=x;
  document.getElementById("careerModalTitle").textContent="Edit Rencana Karier & Studi";
  document.getElementById("careerStudent").value=x.student_id||"";
  document.getElementById("careerPath").value=x.plan_type||"";
  document.getElementById("careerField").value=x.field||"";
  document.getElementById("careerDestination").value=x.destination||"";
  document.getElementById("careerNotes").value=x.notes||"";
  await muatReferensiBakatMinat(x.student_id,x.talent_result_id);
  careerMessage.textContent="";careerModal.style.display="flex";
};
if(searchCareer)searchCareer.addEventListener("input",tampilkanKarierStudi);
if(careerClassFilter)careerClassFilter.addEventListener("change",tampilkanKarierStudi);
if(careerPathFilter)careerPathFilter.addEventListener("change",tampilkanKarierStudi);

/* =========================================================
   MODUL LAPORAN
   Tidak menampilkan isi catatan konseling rahasia.
========================================================= */
const reportClassFilter=document.getElementById("reportClassFilter");
const reportPeriodFilter=document.getElementById("reportPeriodFilter");
const reportStudentBody=document.getElementById("reportStudentBody");
const reportAssessmentBody=document.getElementById("reportAssessmentBody");
const printReportBtn=document.getElementById("printReportBtn");
const exportReportBtn=document.getElementById("exportReportBtn");
let laporanAsesmen=[];

function tanggalMasukPeriode(tanggal,periode){
  if(!tanggal||periode==="all")return true;
  const d=new Date(tanggal),n=new Date();
  if(periode==="month")return d.getFullYear()===n.getFullYear()&&d.getMonth()===n.getMonth();
  if(periode==="year")return d.getFullYear()===n.getFullYear();
  return true;
}
async function muatLaporan(){
  await muatKelas(); await muatSiswa();
  reportClassFilter.innerHTML='<option value="">Semua Kelas</option>'+daftarKelas.map(k=>`<option value="${k.id}">${aman(k.name)}</option>`).join("");

  const {data:{user}}=await client.auth.getUser();
  if(user){
    const {data:p}=await client.from("profiles").select("school_id,schools(name)").eq("id",user.id).single();
    document.getElementById("reportSchoolName").textContent=p?.schools?.name||document.getElementById("schoolName").textContent||"SahabatBK";
  }

  const {data:a,error:ae}=await client.from("assessments").select("id,title,assessment_type,is_active,created_at").order("created_at",{ascending:false});
  if(ae)console.error(ae); laporanAsesmen=a||[];
  await renderLaporan();
}
async function renderLaporan(){
  const kelas=reportClassFilter?.value||"",periode=reportPeriodFilter?.value||"all";
  const siswa=daftarSiswa.filter(s=>(!kelas||s.class_id===kelas)&&s.status==="active");
  document.getElementById("reportStudents").textContent=siswa.length;
  const kelasList=kelas?daftarKelas.filter(k=>k.id===kelas):daftarKelas;
  reportStudentBody.innerHTML=kelasList.map(k=>{
    const x=siswa.filter(s=>s.class_id===k.id);
    return `<tr><td>${aman(k.name)}</td><td>${x.length}</td><td>${x.filter(s=>s.gender==="L").length}</td><td>${x.filter(s=>s.gender==="P").length}</td></tr>`;
  }).join("")||'<tr><td colspan="4" class="empty-data">Tidak ada data.</td></tr>';

  const asesmen=laporanAsesmen.filter(a=>tanggalMasukPeriode(a.created_at,periode));
  document.getElementById("reportAssessments").textContent=asesmen.length;
  reportAssessmentBody.innerHTML=asesmen.map(a=>`<tr><td>${aman(a.title)}</td><td>${aman(labelJenisAsesmen(a.assessment_type))}</td><td>${a.is_active?"Aktif":"Nonaktif"}</td></tr>`).join("")||'<tr><td colspan="3" class="empty-data">Tidak ada data.</td></tr>';

  // PRIVACY V2: browser admin tidak meminta baris konseling/tindak lanjut rahasia.
  const roleAktif=await ambilRoleAktif();
  if(roleBolehBukaRahasia(roleAktif)){
    const [cr,fr]=await Promise.all([
      client.from("counseling_sessions").select("id,student_id,session_date"),
      client.from("follow_ups").select("id,student_id,follow_up_date,status")
    ]);
    let cdata=cr.data||[], fdata=fr.data||[];
    if(kelas){const ids=new Set(siswa.map(s=>s.id));cdata=cdata.filter(x=>ids.has(x.student_id));fdata=fdata.filter(x=>ids.has(x.student_id));}
    cdata=cdata.filter(x=>tanggalMasukPeriode(x.session_date,periode));
    fdata=fdata.filter(x=>tanggalMasukPeriode(x.follow_up_date,periode)&&["planned","in_progress"].includes(x.status));
    document.getElementById("reportCounseling").textContent=cdata.length;
    document.getElementById("reportFollowups").textContent=fdata.length;
  }else{
    document.getElementById("reportCounseling").textContent="Privat";
    document.getElementById("reportFollowups").textContent="Privat";
  }
}
if(reportClassFilter)reportClassFilter.addEventListener("change",renderLaporan);
if(reportPeriodFilter)reportPeriodFilter.addEventListener("change",renderLaporan);
if(printReportBtn)printReportBtn.addEventListener("click",()=>window.print());
if(exportReportBtn)exportReportBtn.addEventListener("click",()=>{
  const kelas=reportClassFilter?.value||"";
  const siswa=daftarSiswa.filter(s=>(!kelas||s.class_id===kelas)&&s.status==="active");
  const rows=siswa.map(s=>({NAMA:s.full_name||"",NIS:s.nis||"",NISN:s.nisn||"",KELAS:s.classes?.name||"",JK:s.gender||"",STATUS:s.status||""}));
  const wb=XLSX.utils.book_new(),ws=XLSX.utils.json_to_sheet(rows);
  XLSX.utils.book_append_sheet(wb,ws,"Rekap Siswa");
  XLSX.writeFile(wb,"Laporan_SahabatBK.xlsx");
});



/* =========================================================
   MODUL PENGATURAN
========================================================= */
const schoolSettingsForm=document.getElementById("schoolSettingsForm");
const settingsClassBody=document.getElementById("settingsClassBody");
const settingsUserBody=document.getElementById("settingsUserBody");
const addClassBtn=document.getElementById("addClassBtn");
const classModal=document.getElementById("classModal");
const closeClassModal=document.getElementById("closeClassModal");
const classForm=document.getElementById("classForm");
let settingsSchoolId="";


async function ambilRoleAktif(){
  const {data:{user}}=await client.auth.getUser();
  if(!user)return null;
  const {data,error}=await client.from("profiles").select("role").eq("id",user.id).single();
  if(error){console.error(error);return null;}
  return data?.role||null;
}
function roleBolehBukaRahasia(role){return role==="counselor";}

function labelRole(r){return ({school_admin:"Admin Sekolah",counselor:"Konselor",superadmin:"Superadmin",student:"Siswa"})[r]||r||"-";}

async function muatPengaturan(){
  const {data:{user}}=await client.auth.getUser(); if(!user)return;
  const {data:p,error}=await client.from("profiles").select("id,school_id,full_name,role,phone,schools(id,name,npsn,address,phone,email)").eq("id",user.id).single();
  if(error){console.error(error);return;}
  settingsSchoolId=p.school_id||"";
  const s=p.schools||{};
  document.getElementById("settingsSchoolName").value=s.name||"";
  document.getElementById("settingsNpsn").value=s.npsn||"";
  document.getElementById("settingsAddress").value=s.address||"";
  document.getElementById("settingsPhone").value=s.phone||"";
  document.getElementById("settingsEmail").value=s.email||"";
  document.getElementById("myAccountInfo").innerHTML=`<strong>${aman(p.full_name||user.email)}</strong><br>Role: ${aman(labelRole(p.role))}<br>Email: ${aman(user.email||"-")}`;
  if(addCounselorBtn)addCounselorBtn.style.display=p.role==="school_admin"?"inline-flex":"none";
  await muatKelas();
  settingsClassBody.innerHTML=daftarKelas.map(k=>`<tr><td>${aman(k.name)}</td><td>${aman(k.academic_year||"-")}</td><td>${aman(String(k.grade_level||"-"))}</td></tr>`).join("")||'<tr><td colspan="3" class="empty-data">Belum ada kelas.</td></tr>';
  const {data:users,error:ue}=await client.from("profiles").select("id,full_name,role,phone").eq("school_id",settingsSchoolId).order("full_name");
  if(ue)console.error(ue);
  settingsUserBody.innerHTML=(users||[]).map(u=>`<tr><td>${aman(formatNama(u.full_name))}</td><td>${aman(labelRole(u.role))}</td><td>${aman(u.phone||"-")}</td></tr>`).join("")||'<tr><td colspan="3" class="empty-data">Belum ada pengguna.</td></tr>';
  setTimeout(()=>{ if(typeof pasangAksiManajemenPengguna==="function")pasangAksiManajemenPengguna(); },80);
  setTimeout(()=>{ if(typeof muatPenugasanKonselor==="function")muatPenugasanKonselor(); },120);
}
if(schoolSettingsForm)schoolSettingsForm.addEventListener("submit",async e=>{
  e.preventDefault(); const msg=document.getElementById("schoolSettingsMessage"); msg.textContent="Menyimpan...";
  const payload={name:document.getElementById("settingsSchoolName").value.trim(),npsn:document.getElementById("settingsNpsn").value.trim()||null,address:document.getElementById("settingsAddress").value.trim()||null,phone:document.getElementById("settingsPhone").value.trim()||null,email:document.getElementById("settingsEmail").value.trim()||null};
  const {error}=await client.from("schools").update(payload).eq("id",settingsSchoolId);
  if(error){msg.textContent="Gagal: "+error.message;return;}
  msg.textContent="Profil sekolah berhasil disimpan.";
  const sn=document.getElementById("schoolName"); if(sn)sn.textContent=payload.name;
});
if(addClassBtn)addClassBtn.addEventListener("click",()=>{classForm.reset();document.getElementById("classMessage").textContent="";classModal.style.display="flex";});
if(closeClassModal)closeClassModal.addEventListener("click",()=>classModal.style.display="none");
if(classModal)classModal.addEventListener("click",e=>{if(e.target===classModal)classModal.style.display="none";});
if(classForm)classForm.addEventListener("submit",async e=>{
  e.preventDefault(); const msg=document.getElementById("classMessage"); msg.textContent="Menyimpan...";
  const payload={school_id:settingsSchoolId,name:document.getElementById("newClassName").value.trim().toUpperCase(),academic_year:document.getElementById("newAcademicYear").value.trim(),grade_level:Number(document.getElementById("newGradeLevel").value)};
  const {error}=await client.from("classes").insert(payload);
  if(error){msg.textContent="Gagal: "+error.message;return;}
  msg.textContent="Kelas berhasil ditambahkan."; await muatPengaturan(); setTimeout(()=>classModal.style.display="none",500);
});



/* =========================================================
   MANAJEMEN AKUN KONSELOR
========================================================= */
const addCounselorBtn=document.getElementById("addCounselorBtn");
const counselorModal=document.getElementById("counselorModal");
const closeCounselorModal=document.getElementById("closeCounselorModal");
const counselorForm=document.getElementById("counselorForm");

if(addCounselorBtn)addCounselorBtn.addEventListener("click",()=>{
  counselorForm.reset();
  document.getElementById("counselorMessage").textContent="";
  counselorModal.style.display="flex";
});
if(closeCounselorModal)closeCounselorModal.addEventListener("click",()=>counselorModal.style.display="none");
if(counselorModal)counselorModal.addEventListener("click",e=>{if(e.target===counselorModal)counselorModal.style.display="none";});

if(counselorForm)counselorForm.addEventListener("submit",async e=>{
  e.preventDefault();
  const msg=document.getElementById("counselorMessage");
  const btn=counselorForm.querySelector('button[type="submit"]');
  const payload={
    full_name:document.getElementById("counselorName").value.trim(),
    email:document.getElementById("counselorEmail").value.trim(),
    phone:document.getElementById("counselorPhone").value.trim(),
    password:document.getElementById("counselorPassword").value
  };
  if(payload.password.length<8){msg.textContent="Password minimal 8 karakter.";return;}
  msg.textContent="Membuat akun...";
  btn.disabled=true;
  try{
    const {data:{session}}=await client.auth.getSession();
    if(!session)throw new Error("Sesi login tidak ditemukan.");
    const {data,error}=await client.functions.invoke("create-counselor",{
      body:payload,
      headers:{Authorization:`Bearer ${session.access_token}`}
    });
    if(error){
      let detail=error.message;
      try{
        if(error.context){
          const body=await error.context.json();
          detail=body?.message||detail;
        }
      }catch(_){}
      throw new Error(detail);
    }
    if(!data?.success)throw new Error(data?.message||"Akun Konselor gagal dibuat.");
    msg.textContent="Akun Konselor berhasil dibuat.";
    counselorForm.reset();
    await muatPengaturan();
    setTimeout(()=>{counselorModal.style.display="none";},900);
  }catch(err){
    msg.textContent="Gagal: "+(err?.message||"Terjadi kesalahan.");
  }finally{
    btn.disabled=false;
  }
});



async function perjelasInstrumenBakatMinat(){
  const select=document.getElementById("talentAssessment")||
               document.getElementById("talentInstrument")||
               document.getElementById("assessmentTalent")||
               document.querySelector('#talentModal select[id*="ssessment"], #talentModal select[id*="nstrument"]');
  if(!select)return;
  const opsiAktif=[...select.options].filter(o=>o.value);
  if(!opsiAktif.length){
    select.innerHTML='<option value="">Belum ada instrumen Bakat & Minat aktif</option>';
    select.disabled=true;
    select.title="Buat instrumen Bakat & Minat aktif terlebih dahulu melalui menu Asesmen.";
  }else{
    select.disabled=false;
    select.title="";
  }
}


/* =========================================================
   ROLE & UI v1
   Admin Sekolah: administrasi sistem, tanpa isi rahasia BK.
   Konselor: layanan BK, tanpa fungsi administrasi sekolah.
========================================================= */
let roleAktifUI=null;

function setMenuVisibleByText(label, visible){
  document.querySelectorAll(".menu-item, .nav-item, [data-menu], aside button, aside a").forEach(el=>{
    const teks=(el.textContent||"").trim().toLowerCase();
    if(teks===label.toLowerCase() || teks.includes(label.toLowerCase())){
      el.style.display=visible?"":"none";
    }
  });
}
function setRoleBadge(role){
  const el=document.getElementById("activeRoleBadge");
  if(!el)return;
  el.textContent=labelRole(role);
  el.dataset.role=role||"";
}
async function terapkanRoleUI(){
  roleAktifUI=await ambilRoleAktif();
  setRoleBadge(roleAktifUI);

  if(roleAktifUI==="school_admin"){
    // Admin tidak membuka modul rahasia.
    setMenuVisibleByText("Konseling",false);
    setMenuVisibleByText("Tindak Lanjut",false);
    setMenuVisibleByText("Pengaturan",true);
  }else if(roleAktifUI==="counselor"){
    // Konselor bekerja pada layanan BK, tetapi tidak mengelola administrasi sistem.
    setMenuVisibleByText("Konseling",true);
    setMenuVisibleByText("Tindak Lanjut",true);
    setMenuVisibleByText("Pengaturan",false);
  }

  // v2.8: Data Siswa untuk konselor bersifat operasional, bukan administrasi.
  const bolehKelolaSiswa = roleAktifUI === "school_admin" || roleAktifUI === "superadmin";
  if (addStudentBtn) addStudentBtn.style.display = bolehKelolaSiswa ? "" : "none";
  const importBtn = document.getElementById("importStudentBtn");
  if (importBtn) importBtn.style.display = bolehKelolaSiswa ? "" : "none";
  const importHelp = document.querySelector(".import-help");
  if (importHelp) importHelp.style.display = bolehKelolaSiswa ? "" : "none";
  if (editStudentBtn) editStudentBtn.style.display = bolehKelolaSiswa ? "" : "none";
  const subtitle = document.querySelector("#studentPage .page-header p");
  if (subtitle) subtitle.textContent = roleAktifUI === "counselor"
    ? "Siswa binaan yang aktif ditugaskan kepada Anda."
    : "Kelola data peserta didik.";
}



/* =========================================================
   DASHBOARD v2 — BERDASARKAN ROLE
========================================================= */
function cariMenuDanKlik(label){
  const items=[...document.querySelectorAll(".menu-item, .nav-item, [data-menu], aside button, aside a")];
  const el=items.find(x=>(x.textContent||"").trim().toLowerCase().includes(label.toLowerCase()));
  if(el)el.click();
}
function dashboardCard(label,value,target){
  const key=String(label||"").toLowerCase();
  let tone="blue", icon="users";
  if(key.includes("kelas")){tone="green";icon="school";}
  else if(key.includes("asesmen")){tone="orange";icon="chart";}
  else if(key.includes("pemetaan")){tone="purple";icon="pin";}
  else if(key.includes("karier")){tone="rose";icon="cap";}
  else if(key.includes("pengguna")){tone="cyan";icon="user";}
  else if(key.includes("konseling")){tone="indigo";icon="chat";}
  else if(key.includes("tindak lanjut")){tone="teal";icon="check";}
  else if(key.includes("binaan")||key.includes("siswa")){tone="blue";icon="users";}
  const icons={
    users:'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8ZM22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/></svg>',
    school:'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 21h18M5 21V8l7-4 7 4v13M9 21v-5h6v5M8 11h.01M12 11h.01M16 11h.01"/></svg>',
    chart:'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 20V10M10 20V4M16 20v-7M22 20H2"/></svg>',
    pin:'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M20 10c0 5-8 11-8 11S4 15 4 10a8 8 0 1 1 16 0Z"/><circle cx="12" cy="10" r="2.5"/></svg>',
    cap:'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m2 10 10-5 10 5-10 5L2 10Z M6 12.5V17c3 2.5 9 2.5 12 0v-4.5M22 10v6"/></svg>',
    user:'<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/></svg>',
    chat:'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M21 15a4 4 0 0 1-4 4H8l-5 3v-7a4 4 0 0 1-1-2.7V7a4 4 0 0 1 4-4h11a4 4 0 0 1 4 4v8Z"/><path d="M7 9h10M7 13h6"/></svg>',
    check:'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M9 11l3 3L22 4M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/></svg>'
  };
  return `<button type="button" class="role-stat-card dashboard-v22-card tone-${tone}" ${target?`onclick="cariMenuDanKlik('${target}')"`:""}>
    <span class="dashboard-card-icon">${icons[icon]}</span>
    <span class="dashboard-card-copy"><span class="dashboard-v22-label">${aman(label)}</span><strong class="dashboard-v22-value">${aman(String(value))}</strong>${target?'<small class="dashboard-v22-link">Buka modul →</small>':""}</span>
  </button>`;
}
function quickAction(label,target){
  const key=String(label||"").toLowerCase();
  let tone="blue", icon="users";
  if(key.includes("asesmen")){tone="orange";icon="chart";}
  else if(key.includes("bakat")||key.includes("minat")){tone="green";icon="target";}
  else if(key.includes("karier")){tone="rose";icon="cap";}
  else if(key.includes("laporan")){tone="purple";icon="file";}
  else if(key.includes("pengaturan")){tone="cyan";icon="gear";}
  else if(key.includes("konseling")){tone="indigo";icon="chat";}
  else if(key.includes("tindak lanjut")){tone="teal";icon="check";}
  const icons={
    users:'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8ZM22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/></svg>',
    chart:'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 20V11M12 20V5M19 20v-8"/></svg>',
    target:'<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="3"/><path d="M12 4V1M20 12h3"/></svg>',
    cap:'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m2 10 10-5 10 5-10 5L2 10Z M6 12.5V17c3 2.5 9 2.5 12 0v-4.5M22 10v6"/></svg>',
    file:'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 2h8l4 4v16H6zM14 2v5h5M9 12h6M9 16h6"/></svg>',
    gear:'<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .34 1.88l.06.06-2.83 2.83-.06-.06A1.7 1.7 0 0 0 15 19.4a1.7 1.7 0 0 0-1 .6 1.7 1.7 0 0 0-.4 1.1V21H9.6v-.1A1.7 1.7 0 0 0 8.5 19.4a1.7 1.7 0 0 0-1.88.34l-.06.06-2.83-2.83.06-.06A1.7 1.7 0 0 0 4.1 15a1.7 1.7 0 0 0-.6-1 1.7 1.7 0 0 0-1.1-.4H2v-4h.4A1.7 1.7 0 0 0 4.1 8.5a1.7 1.7 0 0 0-.34-1.88l-.06-.06 2.83-2.83.06.06A1.7 1.7 0 0 0 8.5 4.1a1.7 1.7 0 0 0 1-.6 1.7 1.7 0 0 0 .4-1.1V2h4v.4A1.7 1.7 0 0 0 15 4.1a1.7 1.7 0 0 0 1.88-.34l.06-.06 2.83 2.83-.06.06A1.7 1.7 0 0 0 19.4 8.5a1.7 1.7 0 0 0 .6 1 1.7 1.7 0 0 0 1.1.4h.9v4h-.9A1.7 1.7 0 0 0 19.4 15Z"/></svg>',
    chat:'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M21 15a4 4 0 0 1-4 4H8l-5 3v-7a4 4 0 0 1-1-2.7V7a4 4 0 0 1 4-4h11a4 4 0 0 1 4 4v8Z"/></svg>',
    check:'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M9 11l3 3L22 4M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/></svg>'
  };
  return `<button type="button" class="quick-action quick-tone-${tone}" onclick="cariMenuDanKlik('${target}')"><span class="quick-action-icon">${icons[icon]}</span><span class="quick-action-label">${aman(label)}</span><span class="quick-action-arrow" aria-hidden="true">→</span></button>`;
}
async function muatDashboardRole(){
  const {data:{user}}=await client.auth.getUser(); if(!user)return;
  const {data:p,error}=await client.from("profiles").select("full_name,role,school_id").eq("id",user.id).single();
  if(error||!p)return;
  const stats=document.getElementById("roleStats"),qa=document.getElementById("dashboardQuickActions");

  const [{count:siswaCount},{count:asesmenCount},{count:kelasCount},{count:karierCount},{count:userCount},{count:talentCount}] = await Promise.all([
    client.from("students").select("id",{count:"exact",head:true}).eq("school_id",p.school_id).eq("status","active"),
    client.from("assessments").select("id",{count:"exact",head:true}).eq("school_id",p.school_id),
    client.from("classes").select("id",{count:"exact",head:true}).eq("school_id",p.school_id),
    client.from("career_plans").select("id",{count:"exact",head:true}).eq("school_id",p.school_id),
    client.from("profiles").select("id",{count:"exact",head:true}).eq("school_id",p.school_id),
    client.from("assessment_results").select("id",{count:"exact",head:true}).eq("school_id",p.school_id)
  ]);

  if(p.role==="school_admin"){
    document.getElementById("roleDashboardTitle").textContent="Dashboard Admin Sekolah";
    document.getElementById("roleDashboardSubtitle").textContent="Ringkasan administrasi SahabatBK tanpa membuka catatan konseling rahasia.";
    stats.innerHTML=[
      dashboardCard("Siswa Aktif",siswaCount||0,"Data Siswa"),
      dashboardCard("Kelas",kelasCount||0,"Pengaturan"),
      dashboardCard("Asesmen",asesmenCount||0,"Asesmen"),
      dashboardCard("Hasil Pemetaan",talentCount||0,"Bakat & Minat"),
      dashboardCard("Karier & Studi",karierCount||0,"Karier & Studi"),
      dashboardCard("Pengguna",userCount||0,"Pengaturan")
    ].join("");
    qa.innerHTML=[
      quickAction("Data Siswa","Data Siswa"),quickAction("Asesmen","Asesmen"),
      quickAction("Bakat & Minat","Bakat & Minat"),quickAction("Karier & Studi","Karier & Studi"),
      quickAction("Laporan","Laporan"),quickAction("Pengaturan","Pengaturan")
    ].join("");
  }else if(p.role==="counselor"){
    document.getElementById("roleDashboardTitle").textContent="Dashboard Konselor";
    document.getElementById("roleDashboardSubtitle").textContent="Ringkasan siswa binaan dan pekerjaan layanan BK Anda.";
    const [{count:konselingCount},{count:followupCount},{data:assignmentRows,error:assignmentErr}]=await Promise.all([
      client.from("counseling_sessions").select("id",{count:"exact",head:true}).eq("counselor_id",user.id),
      client.from("follow_ups").select("id",{count:"exact",head:true}).eq("created_by",user.id).in("status",["planned","in_progress"]),
      client.from("counselor_assignments").select("id,student_id,assigned_at,students(id,full_name,nis,status,classes(name))").eq("school_id",p.school_id).eq("counselor_id",user.id).eq("status","active").order("assigned_at",{ascending:false})
    ]);
    const binaan=assignmentErr?[]:(assignmentRows||[]).filter(a=>a.students && a.students.status==="active");
    stats.innerHTML=[
      dashboardCard("Siswa Binaan",binaan.length,"Data Siswa"),
      dashboardCard("Konseling Saya",konselingCount||0,"Konseling"),
      dashboardCard("Tindak Lanjut Aktif",followupCount||0,"Tindak Lanjut"),
      dashboardCard("Hasil Pemetaan",talentCount||0,"Bakat & Minat"),
      dashboardCard("Asesmen",asesmenCount||0,"Asesmen"),
      dashboardCard("Karier & Studi",karierCount||0,"Karier & Studi")
    ].join("");
    qa.innerHTML=[
      quickAction("Catat Konseling","Konseling"),quickAction("Tindak Lanjut","Tindak Lanjut"),
      quickAction("Bakat & Minat","Bakat & Minat"),quickAction("Karier & Studi","Karier & Studi"),
      quickAction("Data Siswa","Data Siswa")
    ].join("");
    let panel=document.getElementById("counselorStudentPanel");
    if(!panel){
      panel=document.createElement("div"); panel.id="counselorStudentPanel"; panel.className="dashboard-panel counselor-student-panel";
      qa.closest(".dashboard-panel")?.insertAdjacentElement("afterend",panel);
    }
    panel.style.display="block";
    panel.innerHTML=`<div class="counselor-panel-head"><div><h3>Siswa Binaan Saya</h3><p>${binaan.length} siswa aktif ditugaskan kepada Anda.</p></div></div>
      <div class="table-container"><table class="student-table"><thead><tr><th>NIS</th><th>Nama Siswa</th><th>Kelas</th><th>Penugasan</th></tr></thead><tbody>${binaan.length?binaan.slice(0,10).map(a=>`<tr><td>${aman(a.students.nis||"-")}</td><td><strong>${aman(formatNama(a.students.full_name))}</strong></td><td>${aman(a.students.classes?.name||"-")}</td><td>${a.assigned_at?new Date(a.assigned_at).toLocaleDateString("id-ID"):"-"}</td></tr>`).join(""):`<tr><td colspan="4" class="empty-data">Belum ada siswa yang ditugaskan kepada Anda.</td></tr>`}</tbody></table></div>
      ${binaan.length>10?`<p class="dashboard-panel-note">Menampilkan 10 dari ${binaan.length} siswa binaan.</p>`:""}`;
  }else{
    const panel=document.getElementById("counselorStudentPanel"); if(panel)panel.style.display="none";
  }
}



function rapikanDashboardV21(){
  const home=document.getElementById("dashboardHome");
  const baru=document.getElementById("roleDashboard");
  if(!home||!baru)return;
  let node=baru.nextElementSibling;
  while(node){
    node.style.display="none";
    node=node.nextElementSibling;
  }
}


/* UI CLEANUP v1 */
function rapikanHeaderModul(){
  const title=document.getElementById("topbarTitle");
  if(!title)return;
  document.querySelectorAll(".content-page").forEach(page=>{
    if(page.style.display!=="none"){
      const h=page.querySelector(".page-header h2,.page-header h1");
      if(h && h.textContent.trim()) title.textContent=h.textContent.trim();
    }
  });
}
document.addEventListener("click",e=>{
  if(e.target.closest(".menu-item,.nav-item,[data-menu],aside button,aside a")){
    setTimeout(rapikanHeaderModul,80);
  }
});


cekSesi().then(async()=>{await terapkanRoleUI();await muatDashboardRole();rapikanDashboardV21();}).catch(console.error);

document.addEventListener("click",e=>{
  const t=e.target;
  if(t && (t.id==="addTalentBtn" || (t.textContent||"").includes("Tambah Pemetaan"))){
    setTimeout(()=>perjelasInstrumenBakatMinat(),300);
  }
});


/* =========================================================
   SAHABATBK - MANAJEMEN AKUN v2
   Reset password Konselor melalui Edge Function.
========================================================= */
function bukaResetPasswordKonselor(counselorId, counselorName){
  const modal=document.getElementById("resetCounselorPasswordModal");
  if(!modal)return;
  document.getElementById("resetCounselorId").value=String(counselorId||"");
  document.getElementById("resetCounselorName").textContent=String(counselorName||"Konselor").toLocaleUpperCase("id-ID");
  document.getElementById("resetCounselorNewPassword").value="";
  document.getElementById("resetCounselorConfirmPassword").value="";
  modal.style.display="flex";
  setTimeout(()=>document.getElementById("resetCounselorNewPassword")?.focus(),50);
}
function tutupResetPasswordKonselor(){
  const modal=document.getElementById("resetCounselorPasswordModal");
  if(modal)modal.style.display="none";
}
async function resetPasswordKonselorSubmit(ev){
  ev.preventDefault();
  const counselor_id=document.getElementById("resetCounselorId")?.value?.trim();
  const p1=document.getElementById("resetCounselorNewPassword")?.value||"";
  const p2=document.getElementById("resetCounselorConfirmPassword")?.value||"";
  if(!counselor_id){ alert("Akun Konselor tidak ditemukan."); return; }
  if(p1.length<8){ alert("Password baru minimal 8 karakter."); return; }
  if(p1!==p2){ alert("Konfirmasi password tidak sama."); return; }

  const btn=document.getElementById("submitResetCounselorPassword");
  const old=btn?.textContent;
  if(btn){ btn.disabled=true; btn.textContent="Menyimpan..."; }
  try{
    const {data,error}=await client.functions.invoke("reset-counselor-password",{
      body:{counselor_id,new_password:p1}
    });
    if(error) throw error;
    if(!data?.success) throw new Error(data?.message||"Reset password gagal.");
    alert(data.message||"Password Konselor berhasil diperbarui.");
    tutupResetPasswordKonselor();
  }catch(err){
    let pesan=err?.message||"Reset password gagal.";
    try{
      if(err?.context){
        const body=await err.context.json();
        if(body?.message)pesan=body.message;
      }
    }catch(_){}
    alert(pesan);
  }finally{
    if(btn){ btn.disabled=false; btn.textContent=old||"Simpan Password Baru"; }
  }
}
function pasangResetPasswordPadaDaftarKonselor(){
  const tables=[...document.querySelectorAll("table")];
  tables.forEach(table=>{
    const rows=[...table.querySelectorAll("tbody tr")];
    rows.forEach(row=>{
      if(row.querySelector(".reset-counselor-btn"))return;
      const text=row.textContent||"";
      if(!/konselor|guru bk/i.test(text))return;
      const candidates=[...row.querySelectorAll("[data-user-id],[data-id],button")];
      let id=row.dataset.userId||row.dataset.id||"";
      if(!id){
        for(const el of candidates){
          const v=el.dataset?.userId||el.dataset?.id||"";
          if(/^[0-9a-f]{8}-[0-9a-f-]{27,}$/i.test(v)){id=v;break;}
        }
      }
      if(!id)return;
      const name=(row.querySelector("td")?.textContent||"Konselor").trim();
      const cell=row.lastElementChild;
      if(!cell)return;
      const b=document.createElement("button");
      b.type="button";
      b.className="secondary-btn reset-counselor-btn";
      b.textContent="Reset Password";
      b.addEventListener("click",()=>bukaResetPasswordKonselor(id,name));
      cell.appendChild(b);
    });
  });
}
document.addEventListener("DOMContentLoaded",()=>{
  document.getElementById("resetCounselorPasswordForm")?.addEventListener("submit",resetPasswordKonselorSubmit);
  document.getElementById("closeResetCounselorPassword")?.addEventListener("click",tutupResetPasswordKonselor);
  document.getElementById("cancelResetCounselorPassword")?.addEventListener("click",tutupResetPasswordKonselor);
  document.getElementById("toggleResetPassword")?.addEventListener("click",e=>{
    const inp=document.getElementById("resetCounselorNewPassword");
    if(!inp)return;
    inp.type=inp.type==="password"?"text":"password";
    e.currentTarget.textContent=inp.type==="password"?"Lihat":"Sembunyikan";
  });
  document.getElementById("resetCounselorPasswordModal")?.addEventListener("click",e=>{
    if(e.target?.id==="resetCounselorPasswordModal")tutupResetPasswordKonselor();
  });
  // v2.6.1: jangan mengamati seluruh DOM. Observer global sebelumnya dapat
  // memicu render berulang saat halaman Pengaturan berubah dan membuat sidebar macet.
  setTimeout(pasangResetPasswordPadaDaftarKonselor,500);
});


/* =========================================================
   SAHABATBK - MANAJEMEN AKUN v2.1
========================================================= */
function bukaKelolaKonselor(id,nama,action){
  const modal=document.getElementById("manageCounselorModal");
  if(!modal)return;
  document.getElementById("manageCounselorId").value=id||"";
  document.getElementById("manageCounselorAction").value=action;
  document.getElementById("manageCounselorName").textContent=String(nama||"Konselor").toLocaleUpperCase("id-ID");
  const nonaktif=action==="deactivate";
  document.getElementById("manageCounselorTitle").textContent=nonaktif?"Nonaktifkan Konselor":"Aktifkan Kembali Konselor";
  document.getElementById("deactivationReasonWrap").style.display=nonaktif?"block":"none";
  document.getElementById("deactivationReason").value="";
  document.getElementById("deactivationReasonOther").value="";
  document.getElementById("submitManageCounselor").textContent=nonaktif?"Nonaktifkan":"Aktifkan Kembali";
  document.getElementById("manageCounselorInfo").textContent=nonaktif
    ?"Akun tidak dihapus dan Konselor tidak dapat login setelah dinonaktifkan. Riwayat konseling tetap tersimpan."
    :"Akun akan dapat digunakan untuk login kembali. Riwayat lama tetap tersimpan.";
  modal.style.display="flex";
}
function tutupKelolaKonselor(){
  const m=document.getElementById("manageCounselorModal"); if(m)m.style.display="none";
}
async function submitKelolaKonselor(ev){
  ev.preventDefault();
  const counselor_id=document.getElementById("manageCounselorId").value;
  const action=document.getElementById("manageCounselorAction").value;
  let reason="";
  if(action==="deactivate"){
    reason=document.getElementById("deactivationReason").value.trim();
    const other=document.getElementById("deactivationReasonOther").value.trim();
    if(!reason){alert("Alasan penonaktifan wajib dipilih.");return;}
    if(reason==="Lainnya" && other)reason=other;
    else if(other)reason += " - "+other;
  }
  const btn=document.getElementById("submitManageCounselor"), old=btn.textContent;
  btn.disabled=true; btn.textContent="Memproses...";
  try{
    const {data,error}=await client.functions.invoke("manage-counselor",{body:{counselor_id,action,reason}});
    if(error)throw error;
    if(!data?.success)throw new Error(data?.message||"Pengelolaan akun gagal.");
    alert(data.message);
    tutupKelolaKonselor();
    if(typeof muatPengaturan==="function") await muatPengaturan();
    setTimeout(pasangAksiManajemenPengguna,250);
  }catch(err){
    let pesan=err?.message||"Pengelolaan akun gagal.";
    try{if(err?.context){const b=await err.context.json();if(b?.message)pesan=b.message;}}catch(_){}
    alert(pesan);
  }finally{btn.disabled=false;btn.textContent=old;}
}

/* Render tabel Manajemen Pengguna dari data profiles agar ID/status tersedia. */
async function pasangAksiManajemenPengguna(){
  const headings=[...document.querySelectorAll("h1,h2,h3,h4")];
  const heading=headings.find(h=>/manajemen pengguna/i.test(h.textContent||""));
  if(!heading)return;
  let box=heading.parentElement;
  while(box && !box.querySelector("table"))box=box.parentElement;
  const table=box?.querySelector("table");
  if(!table)return;
  const bodyNow=table.querySelector("tbody");
  const expected=Number(table.dataset.accountV21Rows||"-1");
  const currentRows=bodyNow ? bodyNow.querySelectorAll("tr").length : -1;
  const hasActionButtons=!!bodyNow?.querySelector(".btn-reset-account,.btn-toggle-account");
  if(table.dataset.accountV21==="1" && currentRows===expected && hasActionButtons)return;

  try{
    const {data:{user}}=await client.auth.getUser(); if(!user)return;
    const {data:me}=await client.from("profiles").select("school_id,role").eq("id",user.id).single();
    if(!me || me.role!=="school_admin")return;
    const {data:users,error}=await client.from("profiles")
      .select("id,full_name,role,phone,is_active,deactivation_reason")
      .eq("school_id",me.school_id);
    if(error)throw error;

    // v3.0 RC6: Admin Sekolah selalu di atas, lalu Konselor A-Z.
    // Role lain (jika kelak ada) mengikuti setelahnya dan tetap alfabetis.
    const roleOrder={school_admin:0,counselor:1};
    (users||[]).sort((a,b)=>{
      const ra=roleOrder[a.role] ?? 99;
      const rb=roleOrder[b.role] ?? 99;
      if(ra!==rb)return ra-rb;
      return String(a.full_name||"").localeCompare(String(b.full_name||""),"id",{sensitivity:"base"});
    });

    const thead=table.querySelector("thead tr");
    if(thead)thead.innerHTML="<th>Nama</th><th>Role</th><th>Telepon</th><th>Status</th><th>Aksi</th>";
    const tbody=table.querySelector("tbody"); if(!tbody)return;
    tbody.innerHTML="";
    (users||[]).forEach(u=>{
      const tr=document.createElement("tr");
      const roleLabel=u.role==="school_admin"?"Admin Sekolah":u.role==="counselor"?"Konselor":u.role;
      const status=u.is_active===false?"Nonaktif":"Aktif";
      const aksi=u.role==="counselor"
        ? `<div class="account-actions">
             <button type="button" class="secondary-btn btn-reset-account">Reset Password</button>
             <button type="button" class="secondary-btn btn-handover-account" ${u.is_active===false?"disabled":""}>Serah Terima</button>
             <button type="button" class="${u.is_active===false?"primary-btn":"secondary-btn"} btn-toggle-account">${u.is_active===false?"Aktifkan":"Nonaktifkan"}</button>
           </div>` : "—";
      tr.innerHTML=`<td><strong>${String(u.full_name||"-").toLocaleUpperCase("id-ID")}</strong></td>
                    <td>${roleLabel}</td><td>${u.phone||"-"}</td>
                    <td><span class="account-status ${u.is_active===false?"inactive":"active"}">${status}</span></td>
                    <td>${aksi}</td>`;
      tr.querySelector(".btn-reset-account")?.addEventListener("click",()=>bukaResetPasswordKonselor(u.id,u.full_name));
      tr.querySelector(".btn-handover-account")?.addEventListener("click",()=>bukaSerahTerimaKonselor(u.id,u.full_name));
      tr.querySelector(".btn-toggle-account")?.addEventListener("click",()=>bukaKelolaKonselor(u.id,u.full_name,u.is_active===false?"activate":"deactivate"));
      tbody.appendChild(tr);
    });
    table.dataset.accountV21="1";
    table.dataset.accountV21Rows=String((users||[]).length);
  }catch(err){console.error("Manajemen Akun v2.1:",err);}
}

document.addEventListener("DOMContentLoaded",()=>{
  document.getElementById("manageCounselorForm")?.addEventListener("submit",submitKelolaKonselor);
  document.getElementById("closeManageCounselor")?.addEventListener("click",tutupKelolaKonselor);
  document.getElementById("cancelManageCounselor")?.addEventListener("click",tutupKelolaKonselor);
  document.getElementById("manageCounselorModal")?.addEventListener("click",e=>{if(e.target?.id==="manageCounselorModal")tutupKelolaKonselor();});
  // v2.6: hindari observer DOM global. Renderer dipanggil eksplisit saat Pengaturan dimuat/diubah.
  setTimeout(pasangAksiManajemenPengguna,600);
});


/* v2.6.2: renderer Manajemen Pengguna dipanggil hanya dari muatPengaturan(). */

/* =========================================================
   SAHABATBK v2.4 - Password visibility
========================================================= */
document.addEventListener("DOMContentLoaded",()=>{
  const btn=document.getElementById("toggleLoginPassword");
  const inp=document.getElementById("password");
  if(btn && inp){
    btn.addEventListener("click",()=>{
      const terlihat=inp.type==="text";
      inp.type=terlihat?"password":"text";
      btn.setAttribute("title", terlihat ? "Lihat password" : "Sembunyikan password");
      btn.setAttribute("aria-label",terlihat?"Lihat password":"Sembunyikan password");
      inp.focus();
      try{inp.setSelectionRange(inp.value.length,inp.value.length)}catch(_){}
    });
  }
});


/* =========================================================
   SAHABATBK - SERAH TERIMA KONSELOR v1
   Memindahkan penugasan aktif siswa tanpa mengubah histori
   counseling_sessions milik konselor sebelumnya.
========================================================= */
let handoverAssignments=[];

async function bukaSerahTerimaKonselor(counselorId,counselorName){
  const modal=document.getElementById("handoverCounselorModal");
  if(!modal)return;
  document.getElementById("handoverFromId").value=counselorId||"";
  document.getElementById("handoverFromName").textContent=String(counselorName||"Konselor").toLocaleUpperCase("id-ID");
  document.getElementById("handoverNote").value="";
  document.getElementById("handoverMessage").textContent="Memuat penugasan siswa...";
  document.getElementById("handoverStudentList").innerHTML="";
  modal.style.display="flex";
  try{
    const {data:{user}}=await client.auth.getUser();
    if(!user)throw new Error("Sesi login tidak ditemukan.");
    const {data:me,error:meErr}=await client.from("profiles").select("school_id,role").eq("id",user.id).single();
    if(meErr)throw meErr;
    if(me?.role!=="school_admin")throw new Error("Hanya Admin Sekolah yang dapat melakukan serah terima.");

    const [{data:counselors,error:cErr},{data:assignments,error:aErr}]=await Promise.all([
      client.from("profiles").select("id,full_name,is_active").eq("school_id",me.school_id).eq("role","counselor").eq("is_active",true).neq("id",counselorId).order("full_name"),
      client.from("counselor_assignments").select("id,student_id,students(id,full_name,nis,classes(name))").eq("school_id",me.school_id).eq("counselor_id",counselorId).eq("status","active").order("assigned_at")
    ]);
    if(cErr)throw cErr; if(aErr)throw aErr;
    const target=document.getElementById("handoverToId");
    target.innerHTML='<option value="">Pilih konselor pengganti</option>'+((counselors||[]).map(c=>`<option value="${aman(c.id)}">${aman(formatNama(c.full_name))}</option>`).join(""));
    handoverAssignments=assignments||[];
    const list=document.getElementById("handoverStudentList");
    if(!handoverAssignments.length){
      list.innerHTML='<div class="handover-empty">Belum ada siswa dengan penugasan aktif pada konselor ini.</div>';
      document.getElementById("handoverMessage").textContent="Tidak ada penugasan aktif yang dapat diserahterimakan.";
      return;
    }
    list.innerHTML=handoverAssignments.map(a=>{
      const st=a.students||{}; const kelas=st.classes?.name||"-";
      return `<label class="handover-student-item"><input type="checkbox" class="handover-student-check" value="${aman(a.id)}" checked><span><strong>${aman(formatNama(st.full_name||"-"))}</strong><small>NIS ${aman(st.nis||"-")} · ${aman(kelas)}</small></span></label>`;
    }).join("");
    document.getElementById("handoverMessage").textContent=`${handoverAssignments.length} siswa memiliki penugasan aktif.`;
  }catch(err){
    console.error(err);
    document.getElementById("handoverMessage").textContent="Gagal memuat: "+(err?.message||"Terjadi kesalahan.");
  }
}
function tutupSerahTerimaKonselor(){
  const m=document.getElementById("handoverCounselorModal"); if(m)m.style.display="none";
  handoverAssignments=[];
}
async function submitSerahTerimaKonselor(ev){
  ev.preventDefault();
  const fromId=document.getElementById("handoverFromId").value;
  const toId=document.getElementById("handoverToId").value;
  const note=document.getElementById("handoverNote").value.trim();
  const selected=[...document.querySelectorAll(".handover-student-check:checked")].map(x=>x.value);
  if(!toId){alert("Pilih Konselor pengganti.");return;}
  if(!selected.length){alert("Pilih minimal satu siswa yang akan diserahterimakan.");return;}
  if(!note){alert("Alasan/catatan serah terima wajib diisi.");return;}
  if(!confirm(`Serahterimakan ${selected.length} siswa kepada Konselor pengganti? Riwayat konseling lama tidak akan diubah.`))return;

  const btn=document.getElementById("submitHandoverCounselor"), old=btn.textContent;
  btn.disabled=true; btn.textContent="Memproses...";
  const msg=document.getElementById("handoverMessage");
  try{
    const {data:{user}}=await client.auth.getUser(); if(!user)throw new Error("Sesi login tidak ditemukan.");
    const {data:me,error:meErr}=await client.from("profiles").select("school_id,role").eq("id",user.id).single();
    if(meErr)throw meErr; if(me?.role!=="school_admin")throw new Error("Akses ditolak.");
    let berhasil=0;
    for(const assignmentId of selected){
      const oldAssignment=handoverAssignments.find(a=>a.id===assignmentId);
      if(!oldAssignment)continue;
      const endedAt=new Date().toISOString();
      const {error:endErr}=await client.from("counselor_assignments").update({status:"ended",ended_at:endedAt,handover_note:note}).eq("id",assignmentId).eq("status","active");
      if(endErr)throw endErr;
      const {error:insertErr}=await client.from("counselor_assignments").insert({school_id:me.school_id,student_id:oldAssignment.student_id,counselor_id:toId,assigned_by:user.id,handover_from:fromId,handover_note:note,status:"active"});
      if(insertErr){
        await client.from("counselor_assignments").update({status:"active",ended_at:null,handover_note:null}).eq("id",assignmentId);
        throw insertErr;
      }
      berhasil++;
    }
    msg.textContent=`Serah terima berhasil untuk ${berhasil} siswa.`;
    alert(`Serah terima berhasil untuk ${berhasil} siswa. Riwayat konseling lama tetap tersimpan pada Konselor sebelumnya.`);
    tutupSerahTerimaKonselor();
    if(typeof muatPengaturan==="function")await muatPengaturan();
    setTimeout(pasangAksiManajemenPengguna,200);
  }catch(err){
    console.error(err); msg.textContent="Gagal: "+(err?.message||"Serah terima gagal.");
  }finally{btn.disabled=false;btn.textContent=old||"Proses Serah Terima";}
}

document.addEventListener("DOMContentLoaded",()=>{
  document.getElementById("handoverCounselorForm")?.addEventListener("submit",submitSerahTerimaKonselor);
  document.getElementById("closeHandoverCounselor")?.addEventListener("click",tutupSerahTerimaKonselor);
  document.getElementById("cancelHandoverCounselor")?.addEventListener("click",tutupSerahTerimaKonselor);
  document.getElementById("handoverCounselorModal")?.addEventListener("click",e=>{if(e.target?.id==="handoverCounselorModal")tutupSerahTerimaKonselor();});
  document.getElementById("handoverSelectAll")?.addEventListener("change",e=>document.querySelectorAll(".handover-student-check").forEach(x=>x.checked=e.target.checked));
});

/* =========================================================
   SAHABATBK v2.6 - PENUGASAN SISWA KE KONSELOR
   Admin hanya menetapkan siswa yang belum memiliki konselor aktif.
   Perpindahan siswa yang sudah ditugaskan wajib melalui Serah Terima.
========================================================= */
let assignmentStudents=[];
let assignmentCounselors=[];
let assignmentActiveMap=new Map();

function updateAssignmentSelectedCount(){
  const checks=[...document.querySelectorAll('.assignment-student-check:checked')];
  const label=document.getElementById('assignmentSelectedCount');
  const btn=document.getElementById('assignStudentsBtn');
  if(label)label.textContent=`${checks.length} siswa dipilih`;
  if(btn)btn.disabled=!document.getElementById('assignmentCounselorFilter')?.value || checks.length===0;
  const all=[...document.querySelectorAll('.assignment-student-check:not(:disabled)')];
  const selectAll=document.getElementById('assignmentSelectAll');
  if(selectAll){
    selectAll.checked=all.length>0 && all.every(x=>x.checked);
    selectAll.indeterminate=checks.length>0 && checks.length<all.length;
  }
}

function renderAssignmentStudents(){
  const body=document.getElementById('assignmentStudentBody'); if(!body)return;
  const classId=document.getElementById('assignmentClassFilter')?.value||'';
  const q=(document.getElementById('assignmentSearch')?.value||'').trim().toLocaleUpperCase('id-ID');
  const counselorNames=new Map(assignmentCounselors.map(c=>[c.id,formatNama(c.full_name||'-')]));
  const rows=assignmentStudents.filter(s=>{
    if(classId && s.class_id!==classId)return false;
    if(q && !`${s.full_name||''} ${s.nis||''}`.toLocaleUpperCase('id-ID').includes(q))return false;
    return true;
  });
  if(!rows.length){body.innerHTML='<tr><td colspan="6" class="empty-data">Tidak ada siswa sesuai filter.</td></tr>';updateAssignmentSelectedCount();return;}
  body.innerHTML=rows.map(s=>{
    const a=assignmentActiveMap.get(s.id);
    const assigned=!!a;
    const konselor=assigned?(counselorNames.get(a.counselor_id)||'Konselor aktif'):'—';
    const kelas=s.classes?.name||'-';
    return `<tr class="${assigned?'assignment-row-assigned':''}">
      <td><input type="checkbox" class="assignment-student-check" value="${aman(s.id)}" ${assigned?'disabled':''}></td>
      <td><strong>${aman(formatNama(s.full_name||'-'))}</strong></td>
      <td>${aman(s.nis||'-')}</td><td>${aman(kelas)}</td><td>${aman(konselor)}</td>
      <td><span class="assignment-status ${assigned?'assigned':'unassigned'}">${assigned?'Sudah ditugaskan':'Belum ditugaskan'}</span></td></tr>`;
  }).join('');
  body.querySelectorAll('.assignment-student-check').forEach(x=>x.addEventListener('change',updateAssignmentSelectedCount));
  updateAssignmentSelectedCount();
}

async function muatPenugasanKonselor(){
  const card=document.getElementById('counselorAssignmentCard'); if(!card)return;
  const msg=document.getElementById('assignmentMessage');
  try{
    if(msg)msg.textContent='Memuat data...';
    const {data:{user}}=await client.auth.getUser(); if(!user)throw new Error('Sesi login tidak ditemukan.');
    const {data:me,error:meErr}=await client.from('profiles').select('school_id,role').eq('id',user.id).single();
    if(meErr)throw meErr;
    if(me?.role!=='school_admin'){card.style.display='none';return;}
    card.style.display='block';
    const [cRes,sRes,aRes,kRes]=await Promise.all([
      client.from('profiles').select('id,full_name,is_active').eq('school_id',me.school_id).eq('role','counselor').eq('is_active',true).order('full_name'),
      client.from('students').select('id,full_name,nis,class_id,status,classes(name)').eq('school_id',me.school_id).eq('status','active').order('full_name'),
      client.from('counselor_assignments').select('id,student_id,counselor_id,assigned_at').eq('school_id',me.school_id).eq('status','active'),
      client.from('classes').select('id,name,academic_year').eq('school_id',me.school_id).order('grade_level').order('name')
    ]);
    if(cRes.error)throw cRes.error;if(sRes.error)throw sRes.error;if(aRes.error)throw aRes.error;if(kRes.error)throw kRes.error;
    assignmentCounselors=cRes.data||[]; assignmentStudents=sRes.data||[];
    assignmentActiveMap=new Map((aRes.data||[]).map(a=>[a.student_id,a]));
    const counselorSel=document.getElementById('assignmentCounselorFilter');
    const prevC=counselorSel?.value||'';
    if(counselorSel){counselorSel.innerHTML='<option value="">Pilih konselor tujuan</option>'+assignmentCounselors.map(c=>`<option value="${aman(c.id)}">${aman(formatNama(c.full_name))}</option>`).join(''); if(assignmentCounselors.some(c=>c.id===prevC))counselorSel.value=prevC;}
    const classSel=document.getElementById('assignmentClassFilter');
    const prevK=classSel?.value||'';
    if(classSel){classSel.innerHTML='<option value="">Semua kelas</option>'+(kRes.data||[]).map(k=>`<option value="${aman(k.id)}">${aman(k.name)} · ${aman(k.academic_year||'-')}</option>`).join(''); if((kRes.data||[]).some(k=>k.id===prevK))classSel.value=prevK;}
    const assigned=assignmentActiveMap.size, total=assignmentStudents.length;
    const summary=document.getElementById('assignmentSummary');
    if(summary)summary.textContent=`${total} siswa aktif · ${assigned} sudah memiliki konselor · ${Math.max(total-assigned,0)} belum ditugaskan · ${assignmentCounselors.length} konselor aktif`;
    renderAssignmentStudents();
    if(msg)msg.textContent=assignmentCounselors.length?'':'Belum ada Konselor aktif. Tambahkan atau aktifkan akun Konselor terlebih dahulu.';
  }catch(err){console.error('Penugasan Konselor:',err);if(msg)msg.textContent='Gagal memuat penugasan: '+(err?.message||'Terjadi kesalahan.');}
}

async function tetapkanSiswaKeKonselor(){
  const counselorId=document.getElementById('assignmentCounselorFilter')?.value||'';
  const studentIds=[...document.querySelectorAll('.assignment-student-check:checked')].map(x=>x.value);
  if(!counselorId){alert('Pilih Konselor tujuan.');return;}
  if(!studentIds.length){alert('Pilih minimal satu siswa yang belum memiliki Konselor.');return;}
  const counselor=assignmentCounselors.find(c=>c.id===counselorId);
  if(!counselor){alert('Konselor tujuan tidak valid atau sudah tidak aktif. Muat ulang data.');return;}
  if(!confirm(`Tetapkan ${studentIds.length} siswa kepada ${formatNama(counselor.full_name)}?`))return;
  const btn=document.getElementById('assignStudentsBtn'), old=btn?.textContent||'Tetapkan Konselor';
  const msg=document.getElementById('assignmentMessage');
  if(btn){btn.disabled=true;btn.textContent='Memproses...';}
  try{
    const {data:{user}}=await client.auth.getUser();if(!user)throw new Error('Sesi login tidak ditemukan.');
    const {data:me,error:meErr}=await client.from('profiles').select('school_id,role').eq('id',user.id).single();
    if(meErr)throw meErr;if(me?.role!=='school_admin')throw new Error('Hanya Admin Sekolah yang dapat membuat penugasan.');
    // Re-check tepat sebelum INSERT untuk mencegah penugasan ganda akibat data yang berubah di tab/perangkat lain.
    const {data:existing,error:checkErr}=await client.from('counselor_assignments').select('student_id').eq('school_id',me.school_id).eq('status','active').in('student_id',studentIds);
    if(checkErr)throw checkErr;
    if((existing||[]).length){
      const conflict=new Set((existing||[]).map(x=>x.student_id));
      const names=assignmentStudents.filter(s=>conflict.has(s.id)).map(s=>formatNama(s.full_name)).join(', ');
      throw new Error(`Penugasan dibatalkan. Siswa berikut sudah memiliki Konselor aktif: ${names}. Gunakan Serah Terima untuk memindahkannya.`);
    }
    const rows=studentIds.map(student_id=>({school_id:me.school_id,student_id,counselor_id:counselorId,assigned_by:user.id,status:'active'}));
    const {error:insertErr}=await client.from('counselor_assignments').insert(rows);
    if(insertErr)throw insertErr;
    if(msg)msg.textContent=`Berhasil menetapkan ${studentIds.length} siswa kepada ${formatNama(counselor.full_name)}.`;
    alert(`Berhasil menetapkan ${studentIds.length} siswa kepada ${formatNama(counselor.full_name)}.`);
    await muatPenugasanKonselor();
  }catch(err){console.error(err);if(msg)msg.textContent='Gagal: '+(err?.message||'Penugasan gagal.');alert('Penugasan gagal. '+(err?.message||''));}
  finally{if(btn){btn.textContent=old;updateAssignmentSelectedCount();}}
}

document.addEventListener('DOMContentLoaded',()=>{
  document.getElementById('assignmentClassFilter')?.addEventListener('change',renderAssignmentStudents);
  document.getElementById('assignmentSearch')?.addEventListener('input',renderAssignmentStudents);
  document.getElementById('assignmentCounselorFilter')?.addEventListener('change',updateAssignmentSelectedCount);
  document.getElementById('assignmentSelectAll')?.addEventListener('change',e=>{document.querySelectorAll('.assignment-student-check:not(:disabled)').forEach(x=>x.checked=e.target.checked);updateAssignmentSelectedCount();});
  document.getElementById('refreshAssignmentsBtn')?.addEventListener('click',muatPenugasanKonselor);
  document.getElementById('assignStudentsBtn')?.addEventListener('click',tetapkanSiswaKeKonselor);
});

/* SahabatBK v2.8 - Siswa Binaan Konselor */
