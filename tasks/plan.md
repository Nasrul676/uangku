# Implementation Plan: Lokasi Penyimpanan Uang (Money Location)

> **Status:** Seluruh task (1–9) sudah diimplementasikan — analyze bersih, **196 test hijau**.
> Task 8 dikerjakan dengan opsi C (tabel `money_transfers` terpisah), lingkup C1.
> Sisa pekerjaan: verifikasi manual di perangkat, daftarnya di [tasks/todo.md](todo.md).

## Overview

Menambahkan entitas **Lokasi Uang** — tempat fisik/virtual uang disimpan (Dompet, ATM/Bank, E-wallet, Celengan). Setiap transaksi pemasukan & pengeluaran bisa ditandai berasal dari / masuk ke lokasi mana. Saldo per lokasi ditampilkan sebagai rincian di kartu "SISA UANGMU" di beranda, dan lokasi bisa dikelola (tambah/ubah/hapus) dari layar sendiri.

## Konteks Kode Saat Ini (hasil pembacaan)

| Hal | Temuan |
|---|---|
| DB version | `_dbVersion = 18` di [database_helper.dart:23](lib/services/database_helper.dart#L23) → migrasi baru jadi **19** |
| Tabel `transactions` | [database_helper.dart:337](lib/services/database_helper.dart#L337) — sudah punya `pocket_id`, belum punya kolom lokasi |
| Model transaksi | [finance_transaction.dart](lib/models/finance_transaction.dart) — `toMap`/`fromMap`/`copyWith`/`toJsonByMapping` semua perlu field baru |
| Provider | [transaction_provider.dart](lib/providers/transaction_provider.dart) — `addTransaction` (L1040), `addTransactionForShopping` (L1102), `updateTransaction` (L1157), pola cache `_pocketRealizations` (L1598) bisa ditiru |
| Pola picker | `_openPocketPicker` di [expense_input_screen.dart:339](lib/screens/expense_input_screen.dart#L339) — bottom sheet + `_PickerTile`, **tiru pola ini** |
| Kartu beranda | [balance_card.dart](lib/widgets/dashboard/balance_card.dart) — sudah punya mekanisme `_showDetail` (lipat/buka rincian), tempat alami untuk breakdown lokasi |
| Pocket CRUD | [database_helper.dart:754-781](lib/services/database_helper.dart#L754) — pola CRUD yang ditiru |
| Call site pembuat transaksi | `receipt_result_screen.dart:92`, `receipt_review_screen.dart:230`, `input_screen.dart:84`, `shopping_provider.dart:104`, `income_input_screen.dart:170,182`, `expense_input_screen.dart:707,721` |

## Architecture Decisions

1. **Entitas baru, bukan perluasan `Pocket`.** `Pocket` adalah *alokasi anggaran per periode buku* (punya `allocation_type`/`allocation_value`, terikat `book_period_id`). Lokasi uang adalah *posisi kas nyata* yang lintas periode buku. Menggabungkan keduanya akan merusak semantik `calculatePocketAllocation()`. → tabel baru `money_locations`.

2. **Lokasi bersifat global (tidak terikat `book_period_id`).** Uang di dompet tidak hilang saat buku ditutup. Konsekuensi: saldo lokasi dihitung dari **seluruh** transaksi, bukan hanya buku aktif.

3. **Saldo lokasi = `initial_balance` + Σ INCOME − Σ EXPENSE** untuk transaksi dengan `money_location_id` tersebut. `initial_balance` dipakai untuk saldo awal saat pengguna mulai memakai fitur (mis. "di dompet sekarang sudah ada Rp 200.000").

4. **Nullable & opsional.** `money_location_id` boleh `NULL`. Transaksi lama tetap valid dan masuk bucket "Belum ditentukan". Tidak ada migrasi data paksa, tidak ada field wajib baru di form.

5. **Angka besar di kartu beranda tidak berubah.** `netBalance` tetap saldo periode buku terpilih. Breakdown lokasi ditampilkan sebagai daftar terpisah di dalam panel rincian kartu, dengan total lokasi sendiri + baris "Belum ditentukan" bila ada selisih. Menyamakan paksa dua angka yang dihitung dari cakupan berbeda akan menghasilkan angka yang bohong.

6. **Seed default saat migrasi**: "Dompet" (`wallet`) dan "Rekening / ATM" (`credit-card`), keduanya `initial_balance = 0`. Supaya picker tidak kosong saat pertama dibuka.

7. **Ikon** memakai `IconPickerUtils` yang sudah ada ([icon_picker_utils.dart](lib/utils/icon_picker_utils.dart)), sama seperti pocket.

## Dependency Graph

```
T1 Skema DB + model (money_locations, transactions.money_location_id)
 │
 ├── T2 Provider: state, CRUD, perhitungan saldo  ── (unit test murni)
 │     │
 │     ├── T3 Layar kelola Lokasi Uang (list + form)
 │     │
 │     ├── T4 Picker lokasi di input pengeluaran
 │     ├── T5 Picker lokasi di input pemasukan
 │     │
 │     └── T6 Breakdown saldo lokasi di BalanceCard beranda
 │            │
 │            └── T7 Tampilkan lokasi di daftar/riwayat transaksi
 │                   │
 │                   └── T8 Pindah uang antar lokasi (opsional)
 │
 └── T9 Konsistensi backup/export/AI tools
```

## Task List

### Fase 1: Fondasi Data

#### Task 1: Skema `money_locations` + kolom `money_location_id`

**Description:** Buat model `MoneyLocation`, tabel `money_locations`, tambah kolom `money_location_id` di `transactions`, migrasi ke `_dbVersion = 19`, dan CRUD di `DatabaseHelper`.

**Detail teknis:**
```sql
CREATE TABLE money_locations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  icon TEXT NOT NULL,
  initial_balance REAL NOT NULL DEFAULT 0,
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_archived INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
);
ALTER TABLE transactions ADD COLUMN money_location_id INTEGER;
CREATE INDEX idx_transactions_money_location_id ON transactions(money_location_id);
```

**Acceptance criteria:**
- [ ] `lib/models/money_location.dart` berisi `MoneyLocation` dengan `toMap`/`fromMap`/`copyWith`, mengikuti gaya [pocket.dart](lib/models/pocket.dart)
- [ ] `_createSchema` (install baru) dan blok `if (oldVersion < 19)` (upgrade) menghasilkan skema identik; kolom ditambah dengan pengecekan `PRAGMA table_info` seperti pola `oldVersion < 17`
- [ ] Migrasi menyisipkan 2 baris default ("Dompet", "Rekening / ATM") hanya bila tabel masih kosong
- [ ] `FinanceTransaction` punya `moneyLocationId`; `toMap`, `fromMap`, `copyWith`, dan `toJsonByMapping` semuanya diperbarui
- [ ] `DatabaseHelper` punya `getAllMoneyLocations`, `insertMoneyLocation`, `updateMoneyLocation`, `deleteMoneyLocation` (delete juga `UPDATE transactions SET money_location_id = NULL` untuk id tsb)
- [ ] Tidak ada `DROP TABLE` pada tabel berisi data pengguna

**Verification:**
- [ ] `flutter analyze` bersih
- [ ] `flutter test test/database_book_deletion_test.dart` tetap lulus
- [ ] Test baru `test/money_location_migration_test.dart`: buka DB v18 palsu → upgrade → tabel ada, transaksi lama utuh, `money_location_id` bernilai NULL
- [ ] Manual: jalankan di device yang sudah ada datanya, pastikan tidak crash & data lama masih tampil

**Dependencies:** None · **Scope:** M (3 file)

---

#### Task 2: State & perhitungan saldo di `TransactionProvider`

**Description:** Muat daftar lokasi ke provider, sediakan CRUD, dan hitung saldo per lokasi. Perhitungannya dipisah ke helper murni supaya bisa diuji tanpa DB.

**Detail teknis:** buat `lib/utils/money_location_balance.dart` berisi fungsi murni:
```dart
Map<int, double> buildMoneyLocationTotals(List<FinanceTransaction> txs);
double unassignedTotal(List<FinanceTransaction> txs);
```
Provider membungkusnya dengan cache yang di-invalidate di tempat yang sama dengan `_pocketRealizationCache` ([transaction_provider.dart:1592](lib/providers/transaction_provider.dart#L1592)).

**Acceptance criteria:**
- [ ] `provider.moneyLocations` (non-arsip, urut `sort_order`), `addMoneyLocation`, `updateMoneyLocation`, `deleteMoneyLocation` — semua memanggil `notifyListeners()`
- [ ] `getMoneyLocationBalance(int id)` = `initial_balance` + Σ INCOME − Σ EXPENSE dari **seluruh** transaksi
- [ ] `unassignedMoneyBalance` mengembalikan total transaksi tanpa lokasi (buku terpilih saja — angkanya dipakai untuk baris "Belum ditentukan" di beranda)
- [ ] Cache saldo lokasi di-invalidate setiap `loadTransactions()` selesai
- [ ] `loadMoneyLocations()` dipanggil dari `init()` bersama `loadPockets()` ([L222](lib/providers/transaction_provider.dart#L222))

**Verification:**
- [ ] Test baru `test/money_location_balance_test.dart`: saldo awal saja; income saja; income−expense; transaksi tanpa lokasi tidak bocor ke lokasi mana pun; lokasi tanpa transaksi = saldo awal
- [ ] `flutter analyze` bersih, `flutter test` hijau

**Dependencies:** Task 1 · **Scope:** M (3 file)

---

### ✅ Checkpoint A — Fondasi
- [ ] `flutter analyze` bersih & `flutter test` seluruhnya hijau
- [ ] App jalan di device dengan DB lama, tanpa crash & tanpa data hilang
- [ ] **Review manusia sebelum lanjut ke UI**

---

### Fase 2: Alur Pengguna (irisan vertikal)

#### Task 3: Layar kelola Lokasi Uang

**Description:** Layar daftar lokasi + form tambah/ubah, dijangkau dari Setelan dan dari picker ("+ Tambah lokasi"). Tiru struktur [pocket_list_screen.dart](lib/screens/pocket_list_screen.dart) dan [pocket_form_screen.dart](lib/screens/pocket_form_screen.dart).

**Acceptance criteria:**
- [ ] `money_location_list_screen.dart`: daftar lokasi + saldo terkini per lokasi, empty state berbahasa Indonesia, swipe/slidable untuk ubah & hapus
- [ ] `money_location_form_screen.dart`: nama (wajib), ikon (`IconPickerUtils`), saldo awal (`RupiahInputFormatter`) — dipakai untuk tambah maupun ubah
- [ ] Hapus lokasi memunculkan konfirmasi yang menyebut jumlah transaksi terdampak, lalu transaksi jadi "Belum ditentukan" (bukan ikut terhapus)
- [ ] Semua warna dari `Theme.of(context)`, teks Bahasa Indonesia, format Rupiah `id_ID`
- [ ] Entri menu baru di [settings_screen.dart](lib/screens/settings_screen.dart)

**Verification:**
- [ ] Widget test `test/money_location_screens_test.dart`: form menolak nama kosong; submit memanggil provider dengan nilai benar; daftar merender saldo
- [ ] Manual: tambah "Gopay" → muncul di daftar → ubah nama → hapus, transaksi lama tetap ada
- [ ] Cek tampilan di light **dan** dark mode

**Dependencies:** Task 2 · **Scope:** M (4 file)

---

#### Task 4: Pilih lokasi saat input **pengeluaran**

**Description:** Tambah baris picker "Sumber Uang" di [expense_input_screen.dart](lib/screens/expense_input_screen.dart), persis mengikuti pola `_openPocketPicker` yang sudah ada di sana.

**Acceptance criteria:**
- [ ] Baris picker baru dengan label "Sumber Uang", nilai default "Belum dipilih"
- [ ] Bottom sheet menampilkan seluruh lokasi + saldo terkini, plus opsi "Tanpa lokasi" dan pintasan "+ Tambah lokasi" ke Task 3
- [ ] `moneyLocationId` ikut terkirim di `addTransaction` (L721) **dan** `updateTransaction` (L707)
- [ ] Mode edit memuat ulang lokasi transaksi yang tersimpan
- [ ] Bila lokasi terpilih sudah dihapus, seleksi direset ke null tanpa crash (tiru guard di L788-790)

**Verification:**
- [ ] Test `test/expense_input_screen_test.dart` diperluas: pilih lokasi → simpan → provider menerima `moneyLocationId` yang benar
- [ ] Manual: input pengeluaran Rp 50.000 dari "Dompet" → saldo Dompet turun Rp 50.000

**Dependencies:** Task 2 (Task 3 untuk pintasan tambah) · **Scope:** S (2 file)

---

#### Task 5: Pilih lokasi saat input **pemasukan**

**Description:** Hal yang sama untuk [income_input_screen.dart](lib/screens/income_input_screen.dart) — layar ini saat ini belum punya picker apa pun, jadi widget picker dari Task 4 sebaiknya diangkat ke `lib/widgets/money_location_picker.dart` dan dipakai berdua.

**Acceptance criteria:**
- [ ] Widget picker bersama `lib/widgets/money_location_picker.dart` dipakai oleh layar pengeluaran & pemasukan (label "Masuk ke" untuk pemasukan)
- [ ] `moneyLocationId` terkirim di `addTransaction` (L182) dan `updateTransaction` (L170)
- [ ] Task 4 direfaktor memakai widget bersama ini — tidak ada duplikasi bottom sheet

**Verification:**
- [ ] Test `test/money_location_picker_test.dart`: sheet merender daftar, memilih item mengembalikan id, "Tanpa lokasi" mengembalikan null
- [ ] Manual: pemasukan Rp 1.000.000 ke "Rekening / ATM" → saldo ATM naik

**Dependencies:** Task 4 · **Scope:** M (3 file)

---

#### Task 6: Rincian saldo per lokasi di kartu beranda

**Description:** Di dalam panel rincian [balance_card.dart](lib/widgets/dashboard/balance_card.dart) (yang sudah dilipat via `_showDetail`), tambahkan daftar "Uangmu ada di mana" berisi nama + ikon + saldo tiap lokasi, plus baris "Belum ditentukan" bila nilainya ≠ 0.

**Acceptance criteria:**
- [ ] `BalanceCard` menerima parameter baru `List<MoneyLocationSummary> locations` (murni data, widget tetap tanpa akses provider)
- [ ] [dashboard_screen.dart:1571](lib/screens/dashboard_screen.dart#L1571) menyusun summary dari provider dan meneruskannya
- [ ] Daftar ikut tersembunyi saat `isBalanceHidden == true`
- [ ] Tanpa lokasi sama sekali → bagian ini tidak dirender (tidak ada blok kosong)
- [ ] Saldo negatif tampil dengan warna `colorScheme.error`
- [ ] Angka besar `netBalance` **tidak** berubah perilakunya

**Verification:**
- [ ] Test `test/dashboard_home_test.dart` diperluas: kartu merender nama & saldo lokasi; tersembunyi saat saldo disembunyikan; tidak dirender saat daftar kosong
- [ ] Manual: cek beranda di light & dark mode, dan pada `textScaler` 1.3 (tidak overflow)

**Dependencies:** Task 2 · **Scope:** S (2 file)

---

### ✅ Checkpoint B — Alur inti
- [ ] Alur ujung-ke-ujung jalan: buat lokasi → input pemasukan ke lokasi → input pengeluaran dari lokasi → saldo di beranda benar
- [ ] `flutter test` hijau, `flutter analyze` bersih
- [ ] **Review manusia sebelum lanjut ke pemolesan**

---

### Fase 3: Pemolesan & Konsistensi

#### Task 7: Tampilkan lokasi di riwayat transaksi

**Description:** Tunjukkan lokasi di daftar transaksi terbaru dan detail transaksi, supaya asal uang terlihat tanpa membuka form. Termasuk dukungan lokasi untuk transaksi berulang.

**Acceptance criteria:**
- [ ] Item transaksi di [recent_section.dart](lib/widgets/dashboard/recent_section.dart) & [transactions_card.dart](lib/widgets/dashboard/transactions_card.dart) menampilkan nama lokasi (ikon kecil / teks sekunder), disembunyikan bila null
- [ ] `RecurringTransaction` + layarnya mendukung `money_location_id` (migrasi kolom masuk ke Task 1 bila sekalian, atau migrasi terpisah v20)
- [ ] `_processRecurringTransactions` ([L~570](lib/providers/transaction_provider.dart#L570)) meneruskan `moneyLocationId`

**Verification:**
- [ ] Widget test daftar transaksi menampilkan/menyembunyikan label lokasi dengan benar
- [ ] Manual: transaksi berulang yang jatuh tempo terbuat dengan lokasi yang benar

**Dependencies:** Task 5, Task 6 · **Scope:** M (4-5 file)

---

### Task 8: Pindah Uang Antar Lokasi — analisis desain *(selesai: opsi C, lingkup C1)*

**Masalah nyata:** tarik tunai Rp 1.000.000 dari ATM ke dompet. Uangnya tidak
ke mana-mana — masih milik pengguna, cuma pindah tempat. Tanpa fitur ini
pengguna terpaksa mencatatnya sebagai pengeluaran dari ATM, yang membuat
"Total Pengeluaran" naik Rp 1 juta palsu.

#### Tiga cara merepresentasikannya

**A. Sepasang transaksi EXPENSE + INCOME berkategori "Transfer"**
(mengikuti `transferBetweenBooks` yang sudah ada di
[transaction_provider.dart:1555](lib/providers/transaction_provider.dart#L1555))

Pola ini benar untuk **antar buku** — tiap buku memang buku besar terpisah,
jadi uang betul-betul keluar dari yang satu dan masuk ke yang lain. Untuk
**antar lokasi** kedua sisinya ada di buku yang sama, jadi satu transfer
menaikkan `totalIncome` **dan** `totalExpense` di buku yang sama sekaligus.
Netto memang tetap, tapi sembilan tempat lain jadi salah:

| Tempat | Akibat kalau transfer jadi transaksi biasa |
|---|---|
| [`currentTotalIncome` / `currentTotalExpense`](lib/providers/transaction_provider.dart#L189) | Dua-duanya naik sebesar transfer |
| [`planBudgetBasisForBook`](lib/providers/transaction_provider.dart#L120) | Budget rencana ikut naik — uang yang tidak pernah masuk |
| [`calculatePocketAllocation`](lib/providers/transaction_provider.dart#L1786) | Kantong PERCENTAGE mengalokasikan dari pemasukan palsu |
| Rasio celengan (`moodForRatio`) | Wajah celengan berubah tanpa sebab |
| [`buildDailyBudget`](lib/utils/daily_budget.dart#L121) | Jatah harian ikut bergeser |
| [`buildCashflowRecap`](lib/utils/cashflow_recap.dart#L90) | Laporan menggelembung di dua sisi |
| [`graph_card.dart`](lib/widgets/dashboard/graph_card.dart) | Grafik memunculkan lonjakan hantu |
| `buildCategoryBreakdown` | Kategori "Transfer" ikut jadi pengeluaran terbesar |
| CSV & PDF | Total di laporan ikut salah |

Bisa ditambal dengan filter di sembilan tempat itu — tapi setiap tempat yang
terlewat akan salah diam-diam, selamanya, dan tempat baru yang ditulis nanti
harus ingat menambahkan filter yang sama.

**B. Tipe baru `type = 'TRANSFER'` di tabel `transactions`**

Lebih buruk dari A. Sebagian besar kode di proyek ini menulis pengecekannya
sebagai terner `tx.type == 'INCOME' ? ... : ...` — lihat
[money_location_balance.dart:30](lib/utils/money_location_balance.dart#L30),
[cashflow_export.dart:82](lib/utils/cashflow_export.dart#L82), dan baris
nominal di `TransactionTile`. Artinya "apa pun yang bukan INCOME" otomatis
diperlakukan sebagai pengeluaran. Baris `TRANSFER` akan terhitung sebagai
pengeluaran **secara diam-diam di semua tempat itu** — gagal secara default,
bukan gagal dengan berisik.

**C. Tabel sendiri `money_transfers`, tidak menyentuh `transactions`** ← **DISETUJUI**

Transfer antar lokasi bukan peristiwa arus kas: tidak ada uang yang masuk,
tidak ada yang keluar. Tabel `transactions` adalah buku besar arus kas, jadi
transfer memang bukan tempatnya.

Konsekuensinya: **tidak ada satu pun dari sembilan tempat di atas yang perlu
diubah**, dan tidak ada yang bisa salah diam-diam — karena baris transfer tidak
pernah sampai ke sana. Yang perlu tahu soal transfer cuma satu: perhitungan
saldo lokasi.

```
saldo lokasi = saldo awal
             + Σ(pemasukan) − Σ(pengeluaran)     ← sudah ada
             + Σ(transfer masuk) − Σ(transfer keluar)   ← tambahan
```

Risiko terkurung di dalam fitur baru. Ini alasan utama memilih C.

#### Harga yang dibayar oleh opsi C

Transfer tidak akan muncul di daftar "Transaksi Terbaru", padahal pengguna
sering ingin melihat "tarik tunai 500rb" di riwayatnya. Ini tradeoff yang
nyata, bukan detail teknis — dan menentukan besar pekerjaan:

- **C1 (disarankan untuk mulai):** riwayat transfer punya tempatnya sendiri di
  layar Lokasi Uang. Sederhana, jujur, dan cukup untuk menjawab "kok saldo
  dompetku naik?"
- **C2 (menyusul kalau terasa kurang):** transfer ikut ditampilkan di daftar
  transaksi sebagai baris bergaya berbeda (ikon panah dua arah, nominal netral
  tanpa +/−), digabung saat merender saja — totalnya tetap tidak tersentuh.

**Diputuskan: C1.** C2 baru dibuat kalau setelah dipakai memang terasa hilang,
bukan diantisipasi dari sekarang.

#### Skema yang diusulkan

```sql
CREATE TABLE money_transfers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  from_location_id INTEGER,       -- nullable: lihat aturan hapus
  to_location_id INTEGER,         -- nullable: lihat aturan hapus
  amount REAL NOT NULL,
  date TEXT NOT NULL,
  time TEXT,
  note TEXT,
  created_at TEXT NOT NULL
);
CREATE INDEX idx_money_transfers_from ON money_transfers(from_location_id);
CREATE INDEX idx_money_transfers_to ON money_transfers(to_location_id);
```

Sengaja **tanpa `book_period_id`** — lokasi lintas periode buku, jadi
transfernya pun harus lintas periode. Menambahkan kolom itu hanya akan
mengundang pertanyaan "transfer ini masuk buku mana" yang tidak ada jawabannya.

**Aturan saat lokasi dihapus** (penting, mudah salah): jangan hapus baris
transfernya. Kalau transfer ATM → Dompet ikut terhapus saat ATM dihapus, saldo
**Dompet** ikut berkurang — padahal Dompet betul-betul menerima uang itu.
Yang benar: sisi yang dihapus di-`NULL`-kan, barisnya tetap tinggal, dan
barisnya baru dibuang kalau **kedua** sisinya sudah null.

---

#### Task 8a: Skema `money_transfers` + perhitungan saldo

**Description:** Tabel transfer, model, CRUD, dan memasukkan delta transfer ke
perhitungan saldo lokasi. Migrasi v19 belum dirilis, jadi tabelnya menumpang di
blok yang sama — belum perlu v20.

**Acceptance criteria:**
- [ ] `lib/models/money_transfer.dart` dengan `toMap`/`fromMap`/`copyWith`
- [ ] Tabel dibuat identik di `_createSchema` dan di blok `oldVersion < 19`
- [ ] `DatabaseHelper`: `getAllMoneyTransfers`, `insertMoneyTransfer`, `deleteMoneyTransfer`
- [ ] `deleteMoneyLocation` mengubah `from_location_id`/`to_location_id` yang cocok jadi NULL, lalu menghapus baris yang kedua sisinya null — dalam satu transaksi DB
- [ ] `buildMoneyLocationNetTotals` menerima daftar transfer dan menjumlahkan deltanya
- [ ] Provider: `loadMoneyTransfers`, `addMoneyTransfer`, `deleteMoneyTransfer`, cache ikut di-invalidate

**Verification:**
- [ ] Test murni: transfer Rp 100.000 → saldo asal −100.000, tujuan +100.000, total kedua lokasi tetap
- [ ] Test: `currentTotalIncome`, `currentTotalExpense`, dan `currentNetBalance` **tidak berubah** sama sekali setelah transfer
- [ ] Test: hapus lokasi asal → saldo lokasi tujuan tidak berubah
- [ ] Test: hapus kedua lokasi → baris transfernya hilang
- [ ] Test migrasi: tabel ada setelah upgrade dari v18

**Dependencies:** Task 2 · **Scope:** M (4-5 file)

---

#### Task 8b: Layar Pindah Uang

**Description:** Form pindah uang yang dijangkau dari layar Lokasi Uang.
Memakai ulang `showMoneyLocationPicker` yang sudah ada untuk sisi asal & tujuan.

**Acceptance criteria:**
- [ ] Pilih asal, tujuan, nominal (`RupiahInputFormatter`), tanggal, catatan opsional
- [ ] Validasi: asal ≠ tujuan, nominal > 0, kedua lokasi wajib dipilih
- [ ] Saldo asal ditampilkan saat dipilih; nominal melebihi saldo hanya diberi peringatan, **tidak diblokir** (uang tunai memang bisa lebih dulu ada di tangan sebelum tercatat)
- [ ] Teks Bahasa Indonesia, warna dari `Theme.of(context)`, jalan di light & dark mode

**Verification:**
- [ ] Widget test: tombol simpan menolak asal == tujuan dan nominal kosong
- [ ] Widget test: submit memanggil provider dengan asal, tujuan, dan nominal yang benar
- [ ] Manual: tarik tunai ATM → Dompet, cek saldo kedua lokasi di beranda

**Dependencies:** Task 8a · **Scope:** S (2 file)

---

#### Task 8c: Riwayat transfer di layar Lokasi Uang

**Description:** Daftar transfer terakhir beserta cara menghapusnya, supaya
transfer yang salah ketik bisa dibatalkan dan pengguna bisa menjawab sendiri
"kok saldo dompetku naik?".

**Acceptance criteria:**
- [ ] Bagian "Perpindahan Terakhir" di bawah daftar lokasi: "ATM → Dompet · Rp 500.000 · 23 Agu"
- [ ] Tidak dirender sama sekali kalau belum pernah ada transfer
- [ ] Hapus transfer mengembalikan saldo kedua lokasi seperti semula
- [ ] Transfer dengan sisi yang lokasinya sudah dihapus tetap terbaca (mis. "(lokasi dihapus) → Dompet")

**Verification:**
- [ ] Widget test: daftar merender arah dan nominal; kosong saat belum ada transfer
- [ ] Test: hapus transfer → saldo kedua lokasi kembali ke nilai sebelumnya

**Dependencies:** Task 8b · **Scope:** S (2 file)

---

### ✅ Checkpoint D — Pindah uang
- [ ] `flutter analyze` bersih, `flutter test` hijau
- [ ] Transfer terbukti **tidak** menyentuh total pemasukan/pengeluaran, grafik, jatah harian, budget rencana, maupun alokasi kantong
- [ ] Alur nyata jalan: tarik tunai ATM → Dompet, saldo dua lokasi benar di beranda

---

#### Task 9: Konsistensi backup, ekspor, dan AI

**Description:** Pastikan kolom & tabel baru ikut terbawa di backup/restore, muncul di CSV/PDF, dan bisa diakses AI.

**Acceptance criteria:**
- [x] Backup/restore ([backup_service.dart](lib/services/backup_service.dart)) membawa `money_locations` dan `money_location_id` — **tanpa perubahan kode**: `_generateSqlDump` menyusun daftar tabel dari `sqlite_master`, dan restore mengganti berkas `.db` yang lalu di-upgrade migrasi v19 (sudah dicakup test migrasi)
- [ ] CSV/PDF ([cashflow_export.dart](lib/utils/cashflow_export.dart)) punya kolom "Lokasi"
- [ ] AI tool `add_transaction` menerima `money_location` opsional (cocokkan nama, abaikan bila tidak ketemu), dan tool baru `get_money_locations` mengembalikan saldo per lokasi ([transaction_provider.dart:469](lib/providers/transaction_provider.dart#L469))

**Verification:**
- [ ] `test/cashflow_export_test.dart` diperluas untuk kolom baru
- [ ] Manual: restore backup versi lama → app jalan, lokasi default tersedia
- [ ] Manual: tanya AI "uangku ada di mana saja?" → jawabannya cocok dengan beranda

**Dependencies:** Task 6 · **Scope:** M (4 file)

---

### ✅ Checkpoint C — Selesai
- [ ] Semua acceptance criteria terpenuhi
- [ ] `flutter analyze` bersih, `flutter test` hijau
- [ ] Diuji di light & dark mode
- [ ] Restore backup lama terbukti aman
- [ ] Siap review

## Risks and Mitigations

| Risiko | Dampak | Mitigasi |
|---|---|---|
| Migrasi DB merusak data pengguna | **Tinggi** | Hanya `ALTER TABLE ADD COLUMN` + `CREATE TABLE IF NOT EXISTS`, tanpa drop. Uji upgrade dari salinan DB v18 nyata sebelum rilis |
| Saldo lokasi ≠ `netBalance` membingungkan pengguna | Sedang | Baris eksplisit "Belum ditentukan" + label yang jujur ("Uangmu ada di mana"), bukan memaksa dua angka jadi sama |
| Bingung "Kantong" vs "Lokasi Uang" | Sedang | Bedakan bahasa di UI: Kantong = *jatah/anggaran*, Lokasi = *tempat uang disimpan*. Beri kalimat penjelas satu baris di layar Lokasi |
| Transaksi lama semua tanpa lokasi → rincian terlihat kosong | Rendah | Baris "Belum ditentukan" menampung sisanya, jadi angkanya tetap utuh sejak hari pertama |
| Menghitung saldo lokasi di setiap `build` | Rendah | Cache di provider dengan invalidasi, meniru `_pocketRealizationCache` |
| Konflik dengan pekerjaan yang belum di-commit di branch ini | Sedang | 16 file sudah termodifikasi & 9 file baru belum di-commit. Commit atau stash dulu sebelum Task 1 |

## Open Questions

1. ~~**Apakah saldo lokasi dihitung dari seluruh periode buku, atau hanya buku terpilih?**~~ → Diputuskan: **seluruh periode**. Baris "Belum ditentukan" ikut dihitung lintas buku supaya sejajar cakupannya.
2. **Task 8 (pindah uang antar lokasi) masuk lingkup sekarang?** Tidak diminta eksplisit, tapi tanpanya alur "tarik tunai dari ATM" tidak bisa dicatat dengan benar. Rekomendasi: kerjakan.
3. ~~**Lokasi wajib diisi atau opsional?**~~ → Diputuskan: **opsional** di semua form.
4. **Perlu isyarat rekonsiliasi** ("uang di dompet sebenarnya tinggal berapa?" → penyesuaian saldo)? Diusulkan ditunda ke iterasi berikutnya.
