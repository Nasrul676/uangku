import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:uangkeluar/models/book_period.dart';
import 'package:uangkeluar/models/financial_plan.dart';
import 'package:uangkeluar/providers/transaction_provider.dart';
import 'package:uangkeluar/utils/rupiah_input_formatter.dart';
import 'package:uangkeluar/widgets/dashboard/financial_plan_dialog.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id', null);
  });

  final books = [
    const BookPeriod(id: 1, label: 'Agustus 2026', startDate: '2026-08-01'),
    const BookPeriod(id: 2, label: 'September 2026', startDate: '2026-09-01'),
  ];

  Future<void> pumpForm(
    WidgetTester tester, {
    List<BookPeriod>? targetBooks,
    FinancialPlan? initialPlan,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<TransactionProvider>(
        create: (_) => TransactionProvider(),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FinancialPlanForm(
                targetBooks: targetBooks ?? books,
                defaultBookId: 1,
                parsePlanAmount: (input) {
                  final amount = RupiahInputFormatter.parse(input);
                  return amount <= 0 ? null : amount;
                },
                initialPlan: initialPlan,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('target nominal jadi elemen utama dengan prefiks Rp', (
    tester,
  ) async {
    await pumpForm(tester);
    expect(find.text('Rp'), findsOneWidget);
  });

  testWidgets('rincian jadi baris pilihan dengan jarak waktu', (tester) async {
    await pumpForm(tester);

    expect(find.text('RINCIAN'), findsOneWidget);
    expect(find.text('Target'), findsOneWidget);
    expect(find.text('Buku'), findsOneWidget);
    expect(find.text('Kategori'), findsOneWidget);

    // Kategori belum dipilih → placeholder netral, bukan "Tanpa Kategori".
    expect(find.text('Belum dipilih'), findsOneWidget);
    // Tanggal target default hari ini.
    expect(find.text('Hari ini'), findsOneWidget);
  });

  testWidgets('baris buku disembunyikan kalau hanya ada satu buku', (
    tester,
  ) async {
    await pumpForm(tester, targetBooks: [books.first]);

    expect(find.text('Buku'), findsNothing);
    expect(find.text('Target'), findsOneWidget);
  });

  testWidgets('angka per bulan muncul setelah nominal diisi', (tester) async {
    await pumpForm(tester);

    // Sebelum diisi: petunjuk kalkulator, bukan hitungan.
    expect(find.textContaining('hitung langsung'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, '6000000');
    await tester.pump();

    expect(find.textContaining('per bulan selama'), findsOneWidget);
  });

  testWidgets('semua error validasi muncul sekaligus di field masing-masing', (
    tester,
  ) async {
    await pumpForm(tester);

    await tester.tap(find.text('Simpan rencana'));
    await tester.pump();

    // Dulu hanya satu pesan tampil di dasar dialog; sekarang keduanya.
    expect(find.text('Target nominal tidak valid'), findsOneWidget);
    expect(find.text('Judul rencana wajib diisi'), findsOneWidget);
  });

  testWidgets('form valid mengembalikan draft', (tester) async {
    FinancialPlanDraft? captured;

    await tester.pumpWidget(
      ChangeNotifierProvider<TransactionProvider>(
        create: (_) => TransactionProvider(),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  captured = await showFinancialPlanSheet(
                    context: context,
                    title: 'Rencana baru',
                    targetBooks: books,
                    defaultBookId: 1,
                    parsePlanAmount: (input) {
                      final amount = RupiahInputFormatter.parse(input);
                      return amount <= 0 ? null : amount;
                    },
                  );
                },
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '6000000');
    await tester.enterText(find.byType(TextFormField).last, 'Dana darurat');
    await tester.pump();

    await tester.tap(find.text('Simpan rencana'));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.title, 'Dana darurat');
    expect(captured!.targetAmount, 6000000);
    expect(captured!.targetBookId, 1);
    expect(captured!.category, isNull);
  });

  testWidgets('blok dampak budget disembunyikan kalau budget belum diketahui', (
    tester,
  ) async {
    await pumpForm(tester);

    await tester.enterText(find.byType(TextFormField).first, '6000000');
    await tester.pump();

    // Tanpa pemasukan maupun plan_budget, tidak ada yang bisa dibandingkan —
    // lebih baik tidak menampilkan apa pun daripada angka menyesatkan.
    expect(find.text('Budget buku'), findsNothing);
    expect(find.text('Sisa'), findsNothing);
    expect(find.text('Kelebihan'), findsNothing);
  });

  group('perhitungan dampak budget', () {
    late TransactionProvider provider;

    setUp(() => provider = TransactionProvider());

    test('buku tanpa data menghasilkan nol, bukan exception', () {
      expect(provider.planBudgetBasisForBook(1), 0);
      expect(provider.totalPlannedForBook(1), 0);
      expect(provider.plannedCountForBook(1), 0);
    });

    test('buku yang tidak dikenal tidak melempar', () {
      expect(provider.planBudgetBasisForBook(99999), 0);
      expect(provider.totalPlannedForBook(99999, excludingPlanId: 5), 0);
    });
  });
}
