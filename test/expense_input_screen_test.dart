import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uangkeluar/providers/transaction_provider.dart';
import 'package:uangkeluar/screens/expense_input_screen.dart';

/// Menguji tampilan form pengeluaran hasil redesain: nominal sebagai elemen
/// utama, rincian sebagai baris pilihan, jumlah & satuan yang dilipat, serta
/// tanggal dan jam yang harus sudah terisi hari ini / sekarang.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('id', null);
  });

  /// Kolom teks mana saja yang sedang memegang fokus.
  ///
  /// `FocusManager.primaryFocus` tidak bisa dipakai di sini: di lingkungan
  /// test, scope akar selalu memegang fokus utama walau tidak ada satu pun
  /// kolom yang aktif.
  Iterable<EditableText> focusedFields(WidgetTester tester) => tester
      .widgetList<EditableText>(find.byType(EditableText))
      .where((field) => field.focusNode.hasFocus);

  Future<void> pumpForm(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<TransactionProvider>(
        create: (_) => TransactionProvider(),
        child: const MaterialApp(home: ExpenseInputScreen()),
      ),
    );
    await tester.pump();
  }

  /// Membuka form pengeluaran tidak boleh langsung menyita fokus. Papan ketik
  /// yang menyembul sendiri menutupi separuh layar sebelum pengguna sempat
  /// melihat isinya — dan memilih kategori tidak boleh memanggilnya kembali.
  testWidgets('tidak ada kolom yang langsung menyita fokus saat dibuka', (
    tester,
  ) async {
    await pumpForm(tester);

    // `TextFormField` merender `TextField` di dalamnya, jadi memeriksa yang
    // terakhir sudah mencakup keduanya.
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields, isNotEmpty);
    for (final field in fields) {
      expect(field.autofocus, isFalse);
    }
    expect(focusedFields(tester), isEmpty);
  });

  testWidgets('memilih kategori tidak memindahkan fokus ke kolom lain', (
    tester,
  ) async {
    await pumpForm(tester);

    // Pengguna sendiri yang menaruh fokus di nominal, lalu beralih memilih
    // kategori.
    await tester.tap(find.byType(TextFormField).first);
    await tester.pump();
    expect(focusedFields(tester), hasLength(1));

    await tester.tap(find.text('Kategori'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Pilih Kategori'), findsOneWidget);
    expect(focusedFields(tester), isEmpty);
  });

  testWidgets('tanggal default terisi hari ini', (tester) async {
    await pumpForm(tester);

    final today = DateFormat('dd MMM yyyy', 'id').format(DateTime.now());
    expect(find.text(today), findsOneWidget);
    expect(find.text('Tanggal'), findsOneWidget);
  });

  testWidgets('jam default terisi waktu sekarang', (tester) async {
    await pumpForm(tester);

    final now = TimeOfDay.now();
    final expected =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    expect(find.text(expected), findsOneWidget);
    expect(find.text('Jam'), findsOneWidget);
    // Placeholder "opsional" tidak boleh muncul saat jam sudah terisi.
    expect(find.text('Pilih jam (opsional)'), findsNothing);
  });

  testWidgets('nominal tampil sebagai elemen utama dengan prefiks Rp', (
    tester,
  ) async {
    await pumpForm(tester);

    expect(find.text('Rp'), findsOneWidget);
    expect(
      find.text('Ketik angka, atau hitung langsung: 50k+20k'),
      findsOneWidget,
    );
  });

  testWidgets('rincian jadi baris pilihan, bukan field ketikan', (
    tester,
  ) async {
    await pumpForm(tester);

    expect(find.text('RINCIAN'), findsOneWidget);
    expect(find.text('Kategori'), findsOneWidget);
    expect(find.text('Rencana'), findsOneWidget);
    expect(find.text('Kantong'), findsOneWidget);
    expect(find.text('Sumber Uang'), findsOneWidget);

    // Belum dipilih → placeholder redup, bukan teks yang terbaca seperti nilai.
    // Tiga baris: Rencana, Kantong, dan Sumber Uang.
    expect(find.text('Belum dipilih'), findsNWidgets(3));
  });

  testWidgets('jumlah & satuan tersembunyi sampai diminta', (tester) async {
    await pumpForm(tester);

    expect(find.text('Jumlah & satuan'), findsOneWidget);
    expect(find.text('Jumlah'), findsNothing);
    expect(find.text('Satuan'), findsNothing);

    await tester.tap(find.text('Jumlah & satuan'));
    await tester.pump();

    expect(find.text('Jumlah'), findsOneWidget);
    expect(find.text('Satuan'), findsOneWidget);
  });

  testWidgets('label seksi tanpa emoji dan tanpa warna error', (tester) async {
    await pumpForm(tester);

    // Header lama memakai emoji dan label berwarna merah.
    expect(find.text('Detail Pengeluaran'), findsNothing);
    expect(find.text('Kapan?'), findsNothing);
    expect(find.text('KAPAN'), findsOneWidget);
  });
}
