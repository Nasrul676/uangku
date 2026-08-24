import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uangkeluar/models/financial_plan.dart';
import 'package:uangkeluar/providers/transaction_provider.dart';
import 'package:uangkeluar/screens/expense_input_screen.dart';

/// Menautkan rencana keuangan tidak boleh mengubah dua hal yang sudah benar:
/// nominal yang sudah diketik pengguna, dan tanggal/jam pencatatan.
///
/// Target rencana adalah tenggat di masa depan dengan angka rencana; yang
/// dicatat di form ini adalah uang yang benar-benar keluar hari ini. Dulu
/// keduanya ditimpa diam-diam, sehingga satu ketukan pada baris "Rencana"
/// bisa mengubah pengeluaran Rp 50.000 hari ini jadi Rp 5.000.000 bulan depan.
class FakeProvider extends TransactionProvider {
  FakeProvider(this.plans);

  final List<FinancialPlan> plans;

  @override
  List<FinancialPlan> get financialPlans => plans;

  @override
  List<String> get expenseCategories => const ['Pengeluaran', 'Rumah'];
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id', null);
  });

  final plan = FinancialPlan(
    id: 1,
    bookPeriodId: 1,
    title: 'Renovasi Dapur',
    targetAmount: 5000000,
    targetDate: '2027-12-31',
    category: 'Rumah',
  );

  Future<void> pumpForm(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<TransactionProvider>.value(
        value: FakeProvider([plan]),
        child: const MaterialApp(home: ExpenseInputScreen()),
      ),
    );
    await tester.pump();
  }

  /// Layar ini punya animasi yang tidak pernah berhenti (gelembung chat &
  /// kalkulator), jadi `pumpAndSettle` akan menunggu selamanya.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> linkPlan(WidgetTester tester) async {
    await tester.tap(find.text('Rencana'));
    await settle(tester);
    await tester.tap(find.text('Renovasi Dapur').last);
    await settle(tester);
  }

  Finder amountField() => find.byType(TextFormField).first;

  testWidgets('nominal yang sudah diisi tidak ditimpa nominal rencana', (
    tester,
  ) async {
    await pumpForm(tester);

    await tester.enterText(amountField(), '50000');
    await settle(tester);
    await linkPlan(tester);

    expect(find.text('50.000'), findsOneWidget);
    expect(find.text('5.000.000'), findsNothing);
  });

  testWidgets('nominal yang masih kosong tetap dibantu isi dari rencana', (
    tester,
  ) async {
    await pumpForm(tester);

    await linkPlan(tester);

    expect(find.text('5.000.000'), findsOneWidget);
  });

  testWidgets('nominal berisi spasi saja tetap dianggap kosong', (
    tester,
  ) async {
    await pumpForm(tester);

    await tester.enterText(amountField(), '   ');
    await settle(tester);
    await linkPlan(tester);

    expect(find.text('5.000.000'), findsOneWidget);
  });

  testWidgets('tanggal tetap hari ini, bukan tenggat rencana', (tester) async {
    await pumpForm(tester);

    final today = DateFormat('dd MMM yyyy', 'id').format(DateTime.now());
    expect(find.text(today), findsOneWidget);

    await linkPlan(tester);

    expect(find.text(today), findsOneWidget);
    expect(find.text('31 Des 2027'), findsNothing);
  });

  testWidgets('jam tetap jam sekarang setelah rencana ditautkan', (
    tester,
  ) async {
    await pumpForm(tester);

    final now = TimeOfDay.now();
    final expected =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    await linkPlan(tester);

    expect(find.text(expected), findsOneWidget);
  });

  testWidgets('judul dan kategori tetap terbantu terisi dari rencana', (
    tester,
  ) async {
    await pumpForm(tester);

    await linkPlan(tester);

    expect(find.text('Renovasi Dapur'), findsWidgets);
    expect(find.text('Rumah'), findsWidgets);
  });
}
