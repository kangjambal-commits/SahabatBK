SAHABATBK v3.0 RC2 - COMPATIBILITY HARDENING

Basis: v3.0 RC1.
Tidak ada perubahan database dan tidak ada SQL baru.

PENGUATAN RC2
1. Fallback 100vh + 100dvh untuk kompatibilitas tinggi viewport browser.
2. Focus-visible untuk navigasi keyboard.
3. Perlindungan teks panjang agar tidak merusak layout.
4. Dukungan prefers-reduced-motion.
5. Seluruh fitur keamanan/role/penugasan/konseling dari RC1 dipertahankan.

MATRIX UJI VIEWPORT
Desktop/laptop:
- 1280 x 720
- 1366 x 768
- 1536 x 864
- 1920 x 1080
Mobile:
- 360 x 800
- 390 x 844
- 414 x 896

ALUR UJI WAJIB
A. Admin login -> Dashboard -> Data Siswa -> Pengaturan -> logout.
B. Konselor login tanpa reload -> sidebar/badge harus berubah -> Data Siswa hanya siswa binaan.
C. Buka Konseling, Tindak Lanjut, Karier & Studi.
D. Logout -> Admin login tanpa reload -> seluruh menu Admin kembali.
E. Pada layar pendek, menu sidebar tetap dapat diakses dan Keluar tidak menimpa menu.

CATATAN COMPATIBILITY
Label final "Compatible With" hanya ditetapkan setelah pengujian browser/perangkat nyata.
Target browser: Chrome, Edge, Firefox, Safari versi modern.
