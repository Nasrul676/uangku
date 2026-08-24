import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:uangkeluar/models/money_location.dart';
import 'package:uangkeluar/providers/transaction_provider.dart';
import 'package:uangkeluar/screens/expense_input_screen.dart';
import 'package:uangkeluar/screens/income_input_screen.dart';
import 'package:uangkeluar/utils/money_location_balance.dart';

MoneyLocation location(int id, String name) => MoneyLocation(
  id: id,
  name: name,
  icon: 'wallet',
  createdAt: '2026-01-01T00:00:00.000',
);

class FakeProvider extends TransactionProvider {
  FakeProvider(this.locations);

  final List<MoneyLocation> locations;

  @override
  List<MoneyLocation> get moneyLocations => locations;

  @override
  List<MoneyLocationSummary> get moneyLocationSummaries => locations
      .map((item) => MoneyLocationSummary(location: item, balance: 0))
      .toList();
}

/// Memastikan baris pemilih lokasi benar-benar sampai ke dua form input, dan
/// pilihannya terbaca kembali di layar. Perjalanan nilainya ke basis data
/// diuji terpisah lewat `money_location_balance_test.dart` dan test migrasi.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('id', null);
  });

  /// Kedua layar input punya animasi yang tidak pernah berhenti (gelembung
  /// chat & kalkulator), jadi `pumpAndSettle` di sini akan menunggu selamanya.
  /// Beberapa frame terhitung sudah cukup untuk membuka sheet dan menutupnya.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> pump(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<TransactionProvider>.value(
        value: FakeProvider([location(1, 'Dompet'), location(2, 'Gopay')]),
        child: MaterialApp(home: screen),
      ),
    );
    await tester.pump();
  }

  group('form pengeluaran', () {
    testWidgets('punya baris "Sumber Uang" dengan placeholder', (tester) async {
      await pump(tester, const ExpenseInputScreen());

      expect(find.text('Sumber Uang'), findsOneWidget);
      expect(find.text('Belum dipilih'), findsWidgets);
    });

    testWidgets('memilih lokasi menampilkan namanya di baris tersebut', (
      tester,
    ) async {
      await pump(tester, const ExpenseInputScreen());

      await tester.tap(find.text('Sumber Uang'));
      await settle(tester);
      expect(find.text('Uang ini dari mana?'), findsOneWidget);

      await tester.tap(find.text('Gopay'));
      await settle(tester);

      expect(find.text('Gopay'), findsOneWidget);
    });
  });

  group('form pemasukan', () {
    testWidgets('punya baris "Masuk ke" dengan placeholder', (tester) async {
      await pump(tester, const IncomeInputScreen());

      expect(find.text('Masuk ke'), findsOneWidget);
      expect(find.text('Belum dipilih'), findsOneWidget);
    });

    testWidgets('memilih lokasi menampilkan namanya di baris tersebut', (
      tester,
    ) async {
      await pump(tester, const IncomeInputScreen());

      await tester.tap(find.text('Belum dipilih'));
      await settle(tester);
      expect(find.text('Uang ini masuk ke mana?'), findsOneWidget);

      await tester.tap(find.text('Dompet'));
      await settle(tester);

      expect(find.text('Dompet'), findsOneWidget);
    });
  });
}
