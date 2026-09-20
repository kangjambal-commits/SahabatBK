SahabatBK v3.0 RC7 — Mobile Navigation

Basis: v3.0 RC6.
Perubahan hanya pada navigasi mobile/responsif.

Perubahan:
- Pada layar <= 768 px, sidebar menjadi drawer dari kiri.
- Dashboard langsung terlihat saat halaman dibuka di HP.
- Tombol hamburger tetap terlihat di kiri atas.
- Menu tertutup otomatis setelah modul dipilih.
- Menu dapat ditutup dengan menyentuh area gelap atau tombol Escape.
- Navigasi desktop tetap menggunakan sidebar permanen.
- Menu drawer dapat discroll pada layar pendek dan tombol Keluar tetap berada di bagian bawah.
- Tidak ada perubahan database, RLS, Edge Function, maupun SQL.

Uji HP:
1. Buka SahabatBK dan login Admin.
2. Pastikan Dashboard langsung terlihat; sidebar tidak memenuhi layar.
3. Tekan tombol hamburger dan coba semua menu.
4. Pastikan drawer menutup setelah menu dipilih.
5. Uji portrait dan landscape.
6. Logout lalu login Konselor tanpa reload; cek menu sesuai role.
