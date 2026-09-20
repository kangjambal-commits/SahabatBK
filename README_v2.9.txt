SAHABATBK v2.9 - KONSELING & TINDAK LANJUT SISWA BINAAN

Basis: v2.8.1 stabil.

WAJIB sebelum pengujian:
1. Backup v2.8.1.
2. Jalankan SUPABASE_v2.9_COUNSELING_SECURITY.sql di Supabase SQL Editor.
3. Pastikan Success.
4. Pasang file v2.9 lalu Ctrl+F5 satu kali.

Perlindungan utama:
- Konselor hanya dapat membuat catatan baru untuk siswa binaan aktif.
- Catatan lama tetap milik konselor pembuat setelah serah terima.
- Konselor baru tidak otomatis membaca catatan rahasia konselor lama.
- Admin/Superadmin tidak diberi akses ke isi counseling_sessions/follow_ups.
- Identitas siswa/pemilik pada catatan lama tidak dapat diganti lewat Edit.
- Tindak lanjut hanya dapat dikaitkan ke konseling milik konselor yang sama dan siswa yang sama.
- Tidak ada DELETE untuk catatan rahasia pada kebijakan v2.9.

Uji minimum:
A. Konselor A membuat konseling untuk siswa binaannya -> harus berhasil.
B. Siswa bukan binaan -> tidak boleh tersedia/penyimpanan ditolak.
C. Serah terima siswa A ke Konselor B.
D. Konselor B tidak melihat catatan rahasia lama Konselor A.
E. Konselor A tetap dapat melihat riwayat yang ia buat, tetapi tidak dapat membuat catatan baru untuk siswa yang sudah dialihkan.
F. Admin tetap tidak melihat isi Konseling/Tindak Lanjut.
