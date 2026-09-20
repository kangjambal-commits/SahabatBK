SahabatBK v3.0 RC1 — Release Candidate Audit
==============================================
Basis: v2.9.2 Responsive Sidebar (baseline stabil)

Fokus RC1:
- Tidak menambah modul bisnis baru.
- Mempertahankan Penugasan, Serah Terima, Siswa Binaan, Konseling, Tindak Lanjut, Karier & Studi, dan RLS yang sudah diuji.
- Membersihkan duplikasi statement pada inisialisasi nama pengguna.
- Mencegah submit login ganda saat koneksi lambat/double-click.
- Menambahkan fallback bila login berhasil tetapi inisialisasi data gagal.
- Pesan login juga mencakup kemungkinan akun nonaktif.

Compatibility test matrix sebelum rilis final:
Desktop viewport: 1280x720, 1366x768, 1536x864, 1920x1080.
Mobile viewport: 360x800, 390x844, 414x896.
Browser target: Chrome, Edge, Firefox; Safari diuji sebelum diklaim compatible.

Checklist uji manual wajib:
1. Admin login -> menu Admin -> logout -> Konselor login tanpa reload -> menu Konselor.
2. Konselor -> Data Siswa hanya siswa binaan.
3. Buat Konseling dan Tindak Lanjut untuk siswa binaan.
4. Serah Terima siswa -> konselor lama tidak dapat membuat catatan baru; konselor baru tidak otomatis membaca catatan rahasia lama.
5. Admin tidak dapat membuka isi Konseling/Tindak Lanjut.
6. Penugasan ganda ditolak.
7. Konselor nonaktif tidak muncul sebagai tujuan penugasan/serah terima dan tidak dapat login.
8. Karier & Studi konselor hanya menampilkan siswa binaan.
9. Sidebar tidak tumpang tindih pada viewport target.
10. Uji koneksi lambat/offline: aplikasi harus gagal secara aman dan tidak membuat data ganda.

Catatan:
- Tidak ada SQL baru pada RC1.
- File SQL versi sebelumnya tetap disertakan sebagai dokumentasi migrasi, jangan dijalankan ulang tanpa kebutuhan.
