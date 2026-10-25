# GERAKSI — Next.js + Supabase

Prototype fungsional aplikasi mahasiswa berdasarkan mockup: Login/Register, Dashboard, Rencana Perjalanan, Verifikasi, Riwayat, Reward, Dampak, Profil, dan Panel Admin.

## Mulai

1. Instal Node.js 20.9+ dan buat project Supabase.
2. Buka **Supabase → SQL Editor**, jalankan seluruh isi `supabase/schema.sql`.
3. Salin `.env.example` menjadi `.env.local`, isi URL dan **anon/publishable key** dari Supabase Project Settings → API. **Jangan pakai service_role key** di frontend.
4. Pada **Authentication → URL Configuration**, isi Site URL `http://localhost:3000` dan tambahkan Redirect URL `http://localhost:3000/auth/callback` (tambahkan URL deployment ketika live).
5. Jalankan:

```bash
npm install
npm run dev
```

6. Buka `http://localhost:3000`, daftar akun dan login. Jika konfirmasi email aktif, konfirmasi dari inbox dahulu.
7. Untuk membuat admin, daftar akun khusus admin lalu jalankan query promosi admin pada akhir `supabase/schema.sql` dengan alamat email akun tersebut.

## Alur uji coba

Login → Rute → pilih moda dan jarak → Simpan → Riwayat → Verifikasi → unggah bukti → Admin setujui → Green Points bertambah → Reward → tukar poin → Dampak.

## Catatan penting

- UI dibuat mengikuti struktur, warna, navigasi, dan layar utama mockup; bukan pixel-perfect dari aset gambar.
- Pilihan rute, waktu, biaya, dan faktor emisi adalah **simulasi**. Belum ada API peta, operator, tiket, atau perhitungan karbon terverifikasi.
- Persetujuan admin merupakan verifikasi manual; unggah QR **bukan** validasi QR otomatis.
- Reward adalah penukaran poin yang tersimpan di database, belum voucher valid dari merchant. `redemptions.status=pending` sampai mitra memenuhi pesanan.
- RLS aktif. Bukti disimpan dalam private Supabase Storage. Admin bisa membuka signed URL bukti selama 60 detik.
- Hanya perjalanan dengan baseline emisi lebih tinggi dari emisi aktual yang memperoleh 10 poin setelah disetujui. Tidak ada poin untuk perjalanan sepeda motor dalam model contoh.
- Untuk produksi perlu proteksi spam, antifraud, audit log, privasi lokasi, metode baseline lebih kuat, faktor emisi tervalidasi, dan integrasi operator.

## Deploy ke Vercel

Push folder ke GitHub, import repository ke Vercel, atur kedua env vars yang sama, tambahkan domain Vercel pada Supabase Authentication URL Configuration, lalu deploy.
