# CLAUDE.md — Panduan Proyek uangku

> File ini adalah panduan untuk Claude AI dan agen lainnya saat bekerja di proyek ini.
> Baca seluruh dokumen sebelum membuat perubahan apa pun.

---

## 📱 Gambaran Proyek

**uangku** (package name: `uangkeluar`) adalah aplikasi keuangan personal berbasis **Flutter** yang memungkinkan pengguna mencatat pemasukan & pengeluaran, mengelola kantong (pocket), menetapkan tujuan tabungan, memindai struk belanja via OCR, dan mendapatkan bantuan dari AI assistant.

- **Platform target:** Android, iOS, Web (Flutter multi-platform)
- **Bahasa:** Dart / Flutter
- **Database lokal:** SQLite via `sqflite` (versi DB saat ini: `_dbVersion = 18`)
- **State management:** `provider` (`ChangeNotifier`)
- **Font utama:** `PlusJakartaSans` (family lokal), `DMSerifDisplay`
- **Versi SDK Dart:** `^3.11.5`

---

## 🗂️ Struktur Direktori

```
lib/
├── main.dart                  # Entry point, setup provider & routing awal
├── models/                    # Data model (plain Dart class + fromMap/toMap)
├── providers/                 # State management (ChangeNotifier)
├── screens/                   # Halaman UI utama
├── services/                  # Business logic, DB, API, notifikasi
├── theme/                     # ThemeData (light & dark mode)
├── utils/                     # Helper/utility functions
└── widgets/                   # Reusable widget components
```

### Models utama (`lib/models/`)
| File | Deskripsi |
|------|-----------|
| `finance_transaction.dart` | Transaksi keuangan (pemasukan/pengeluaran) |
| `pocket.dart` | Kantong/dompet virtual |
| `saving_goal.dart` | Target tabungan |
| `saving_history.dart` | Riwayat setoran tabungan |
| `saving_expense.dart` | Pengeluaran dari tabungan |
| `recurring_transaction.dart` | Transaksi berulang/terjadwal |
| `book_period.dart` | Periode buku keuangan |
| `financial_plan.dart` | Rencana keuangan |
| `shopping_item.dart` | Item daftar belanja |
| `chat_session.dart` | Sesi chat AI |
| `chat_message.dart` | Pesan dalam sesi chat AI |
| `parsed_receipt_item.dart` | Item hasil parsing struk OCR |
| `app_notification.dart` | Notifikasi dalam aplikasi |

### Services utama (`lib/services/`)
| File | Deskripsi |
|------|-----------|
| `database_helper.dart` | **Singleton** SQLite helper — semua CRUD database |
| `ai_assistant_service.dart` | Parsing struk via OCR (Gemini API / Cloudflare fallback) |
| `ai_chat_service.dart` | Layanan chat AI interaktif |
| `auth_service.dart` | Autentikasi pengguna (PIN/biometrik) |
| `app_settings_service.dart` | Pengaturan aplikasi (SharedPreferences) |
| `backup_service.dart` | Export/import backup database |
| `auto_backup_service.dart` | Auto backup terjadwal |
| `notification_service.dart` | Notifikasi lokal (flutter_local_notifications) |
| `background_notification_service.dart` | Notifikasi latar belakang harian |
| `home_balance_widget_service.dart` | Widget layar rumah (home_widget) |

### Providers (`lib/providers/`)
| File | Deskripsi |
|------|-----------|
| `transaction_provider.dart` | **Provider utama** — transaksi, pocket, saving goals, book period |
| `shopping_provider.dart` | State daftar belanja |
| `theme_provider.dart` | State tema (light/dark/system) |
| `expense_provider.dart` | State form input pengeluaran |

---

## 🏗️ Arsitektur & Konvensi

### State Management
- Gunakan `Provider` + `ChangeNotifier`. **Jangan** menggunakan Bloc, Riverpod, atau GetX kecuali ada diskusi eksplisit.
- `TransactionProvider` adalah provider utama yang diinisialisasi di `main.dart` dengan `..init()`.
- `ShoppingProvider` merupakan `ChangeNotifierProxyProvider` yang bergantung pada `TransactionProvider`.

### Database (SQLite)
- Semua operasi database melalui `DatabaseHelper.instance` (singleton).
- Saat menambah tabel/kolom baru, **wajib** menambahkan migration di blok `onUpgrade` dan **increment** `_dbVersion`.
- Konstanta nama tabel didefinisikan sebagai `static const` di `DatabaseHelper`.
- **Tabel yang ada:** `transactions`, `book_periods`, `financial_plans`, `shopping_items`, `pockets`, `notifications`, `saving_goals`, `saving_histories`, `saving_expenses`, `recurring_transactions`, `chat_sessions`, `chat_messages`.

### Navigasi
- Gunakan `Navigator.push` / `Navigator.pushAndRemoveUntil` dengan `MaterialPageRoute`.
- Tidak menggunakan named routes atau router package.

### Tema
- Dukung **light mode** dan **dark mode** — selalu gunakan `Theme.of(context)` untuk warna, bukan hardcode.
- Jangan gunakan `Colors.blue`, `Colors.red` langsung; gunakan `colorScheme.primary`, `colorScheme.error`, dll.
- Font default aplikasi: `PlusJakartaSans`. Pastikan setiap `TextStyle` tidak mengoverride family ke font lain tanpa alasan.

### Internasionalisasi
- Semua teks UI **berbahasa Indonesia**.
- Format tanggal menggunakan `intl` dengan locale `id`.
- Format mata uang dalam **Rupiah (IDR)** — gunakan `intl` dengan format `NumberFormat.currency(locale: 'id_ID', symbol: 'Rp')`.

### AI & API
- Gemini API digunakan untuk parsing struk (`AiAssistantService`) dan chat interaktif (`AiChatService`).
- **API key** disimpan secara aman via `flutter_secure_storage` dan dapat dikonfigurasi dari halaman Setelan.
- Jangan hardcode API key di kode sumber.
- Ada fallback ke Cloudflare endpoint untuk `parseReceiptTextOld` (fungsi lama, hanya sebagai cadangan).

---

## 📦 Dependencies Penting

| Package | Kegunaan |
|---------|---------|
| `provider` | State management |
| `sqflite` | Local SQLite database |
| `sqflite_common_ffi_web` | SQLite untuk platform Web |
| `shared_preferences` | Key-value storage ringan |
| `flutter_secure_storage` | Penyimpanan aman (API key, PIN) |
| `google_fonts` | Font dari Google (cadangan) |
| `fl_chart` | Grafik keuangan |
| `lottie` | Animasi Lottie |
| `confetti` | Efek confetti (pencapaian) |
| `flutter_local_notifications` | Notifikasi lokal |
| `home_widget` | Widget layar rumah Android/iOS |
| `file_picker` | Pilih file untuk backup/restore |
| `share_plus` | Bagikan file/laporan |
| `pdf` | Export laporan ke PDF |
| `google_mlkit_text_recognition` | OCR teks dari struk |
| `image_picker` & `image_cropper` | Ambil & crop foto struk |
| `math_expressions` | Evaluasi ekspresi matematika (kalkulator) |
| `flutter_slidable` | Swipe actions pada list item |
| `lucide_icons_flutter` | Icon set Lucide |
| `archive` | Kompresi file backup |

---

## 🛠️ Perintah Umum

```bash
# Jalankan aplikasi
flutter run

# Jalankan di Chrome (Web)
flutter run -d chrome

# Build APK
flutter build apk --release

# Update dependencies
flutter pub get

# Analisis kode
flutter analyze

# Generate launcher icons
flutter pub run flutter_launcher_icons
```

---

## ✅ Checklist Sebelum Membuat Perubahan

- [ ] Apakah perubahan melibatkan skema database? → Tambah migration + increment `_dbVersion`
- [ ] Apakah menambah widget baru? → Periksa apakah sudah ada widget serupa di `lib/widgets/`
- [ ] Apakah menyentuh state? → Pastikan `notifyListeners()` dipanggil di provider
- [ ] Apakah ada teks UI baru? → Tulis dalam Bahasa Indonesia
- [ ] Apakah menggunakan warna/font? → Gunakan theme token, bukan hardcode
- [ ] Apakah ada akses API key? → Gunakan `flutter_secure_storage`, bukan plaintext

---

## 🤖 Skills yang Tersedia (Claude Agent)

Skills berikut tersedia dan dapat diaktifkan dengan slash command di chat:

| Slash Command | Kegunaan |
|---------------|---------|
| `/agent-skills:frontend-ui-engineering` | Bantu desain & implementasi UI Flutter yang premium |
| `/agent-skills:build` | Bantu proses build, CI/CD, dan konfigurasi proyek |
| `/artifact-design` | Bantu desain artifact dan struktur data |
| `/agent-skills:api-and-interface-design` | Bantu desain API dan interface antar layer |
| `/agent-skills:debugging-and-error-recovery` | Bantu debug error dan recovery dari crash |
| `/caveman:caveman-help` | Bantuan umum dari skill Caveman |
| `/caveman:cavecrew` | Mode multi-agent untuk task kompleks |
| `/ponytail:ponytail-help` | Bantuan skill Ponytail |
| `/btw` | Catatan/informasi tambahan untuk agent |

> **Tips:** Gunakan `/agent-skills:debugging-and-error-recovery` saat menghadapi error runtime
> atau database migration yang gagal. Gunakan `/agent-skills:frontend-ui-engineering`
> saat mendesain screen baru agar konsisten dengan design system uangku.

---

## ⚠️ Hal yang Perlu Diperhatikan

1. **Database migration:** Setiap perubahan skema HARUS melalui `onUpgrade`. Jangan drop & recreate tabel karena akan menghapus data pengguna.
2. **Web support:** Beberapa fitur (notifikasi latar belakang, home widget, kamera OCR) tidak tersedia di Web — selalu cek `kIsWeb` sebelum memanggil API platform-specific.
3. **Text scaling:** Aplikasi membatasi `textScaler` antara `0.9` dan `1.3` di `main.dart` untuk mencegah overflow.
4. **Auth flow:** Layar awal ditentukan oleh `_bootstrapInitialHome()` — selalu melalui `OnboardingScreen` jika belum login, atau langsung ke `DashboardScreen` jika ada widget launch URI.
5. **Backup/Restore:** Fitur backup menggunakan format `.zip` berisi file `.db` — pastikan `closeDatabase()` dipanggil sebelum operasi file pada database.
6. **AI Prompt:** Prompt untuk parsing struk ditulis dalam Bahasa Inggris agar lebih akurat dengan model Gemini/Llama. Jangan ubah ke Bahasa Indonesia tanpa pengujian.
