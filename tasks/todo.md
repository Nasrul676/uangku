# TODO: Lokasi Penyimpanan Uang

Rencana lengkap: [tasks/plan.md](plan.md)

## Keputusan yang diambil saat implementasi

- Saldo lokasi dihitung dari **seluruh** periode buku (uang di dompet tidak reset saat tutup buku).
- Baris "Belum ditentukan" juga dihitung lintas buku, supaya bisa dijumlahkan dengan saldo lokasi tanpa mencampur dua cakupan.
- Lokasi bersifat **opsional** di semua form.
- `money_location_id` untuk `recurring_transactions` ikut masuk migrasi v19 (belum dirilis), bukan v20 terpisah.

## Fase 1 — Fondasi Data ✅

- [x] **T1** Tabel `money_locations` + kolom `money_location_id` (`transactions` & `recurring_transactions`), `_dbVersion` 18 → 19, seed "Dompet" & "Rekening / ATM", CRUD di `DatabaseHelper`, model `MoneyLocation`, update `FinanceTransaction` & `RecurringTransaction`
  - Migrasi diekstrak jadi `_applyMigrations` supaya jalurnya bisa diuji
  - 7 test di `test/money_location_migration_test.dart`
- [x] **T2** Provider: `loadMoneyLocations`, CRUD, `getMoneyLocationBalance`, `moneyLocationSummaries`, `unassignedMoneyBalance`, `moneyLocationNames`, helper murni `lib/utils/money_location_balance.dart` + cache
  - 12 test di `test/money_location_balance_test.dart`

- [x] **✅ Checkpoint A** — analyze bersih, seluruh test hijau

## Fase 2 — Alur Pengguna ✅

- [x] **T3** `money_location_list_screen.dart` + `money_location_form_screen.dart`, entri di Setelan, hapus → transaksi jadi tanpa lokasi (konfirmasi menyebut jumlah transaksi terdampak)
  - 10 test di `test/money_location_screens_test.dart`
- [x] **T4** Baris "Sumber Uang" di form pengeluaran, terkirim saat tambah & ubah
- [x] **T5** Picker diangkat ke `lib/widgets/money_location_picker.dart`, dipakai form pemasukan ("Masuk ke") dan pengeluaran
  - 4 test picker + 4 test integrasi form
- [x] **T6** Rincian "UANGMU ADA DI MANA" di `BalanceCard` + baris "Belum ditentukan" + pintasan "Atur"
  - 6 test di `test/dashboard_home_test.dart`

- [x] **✅ Checkpoint B** — alur ujung-ke-ujung jalan, analyze bersih, test hijau

## Fase 3 — Pemolesan & Konsistensi

- [x] **T7** Nama lokasi di baris transaksi (`RecentSection`, `TransactionsCard`) + dukungan lokasi pada transaksi berulang, diteruskan saat transaksi otomatis dibuat
- [x] **T8** Pindah uang antar lokasi — opsi C (tabel `money_transfers` terpisah), lingkup C1
  - [x] **T8a** Tabel `money_transfers` + model + CRUD, delta transfer masuk ke `buildMoneyLocationNetTotals`
    - Aturan hapus lokasi diekstrak jadi `deleteMoneyLocationFrom` supaya bisa diuji di DB in-memory
    - 11 test di `test/money_transfer_test.dart`
  - [x] **T8b** `money_transfer_screen.dart` — dua sisi lokasi + tombol tukar, nominal, tanggal, catatan; melebihi saldo cuma diperingatkan, tidak diblokir; kurang dari dua lokasi memunculkan penjelasan, bukan form buntu
  - [x] **T8c** Bagian "PERPINDAHAN TERAKHIR" di layar Lokasi Uang, hapus lewat swipe + konfirmasi
    - 12 test di `test/money_transfer_screen_test.dart`
  - [x] **✅ Checkpoint D** — analyze bersih, 196 test hijau
- [x] **T9** Kolom "Lokasi" di CSV, AI tool `get_money_locations` + parameter `money_location` di `add_transaction`
  - Backup/restore tidak perlu diubah: `_generateSqlDump` membaca `sqlite_master`, jadi tabel baru ikut terbawa sendirinya; restore versi lama ditangani migrasi v19 (sudah ada test-nya)

- [ ] **✅ Checkpoint C** — seluruh task selesai; tinggal verifikasi manual di perangkat

## Keputusan T8 (sudah diambil)

- [x] Representasi: tabel `money_transfers` terpisah (opsi C), **bukan** sepasang transaksi seperti `transferBetweenBooks` — supaya sembilan tempat perhitungan yang ada tidak perlu disentuh dan tidak ada yang bisa salah diam-diam
- [x] Lingkup: **C1** — riwayat transfer punya tempatnya sendiri di layar Lokasi Uang; transfer tidak diinterleave ke daftar transaksi

## Kenapa transfer dijamin tidak mengotori arus kas

Bukan karena difilter di banyak tempat, tapi karena tipenya berbeda: seluruh
konsumen arus kas (`currentTotalIncome`, `planBudgetBasisForBook`,
`calculatePocketAllocation`, `buildDailyBudget`, `buildCashflowRecap`,
`buildCategoryBreakdown`, grafik, CSV/PDF) menerima `List<FinanceTransaction>`,
sedangkan `MoneyTransfer` bukan `FinanceTransaction`. Kompilernya yang menjaga,
bukan kedisiplinan penulis kode berikutnya.

## Verifikasi manual yang belum dilakukan

- [ ] Jalankan di perangkat dengan DB lama (v18) berisi data nyata — pastikan tidak crash & data utuh
- [ ] Cek tampilan light & dark mode di layar lokasi, picker, dan kartu beranda
- [ ] Cek `textScaler` 1.3 di kartu beranda (rincian lokasi tidak overflow)
- [ ] Restore backup versi lama → app jalan, lokasi bawaan tersedia
- [ ] Tarik tunai ATM → Dompet, lalu cek beranda: saldo dua lokasi benar dan total pengeluaran **tidak** ikut naik
