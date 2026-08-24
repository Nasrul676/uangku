import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uangkeluar/models/money_location.dart';
import 'package:uangkeluar/providers/transaction_provider.dart';
import 'package:uangkeluar/screens/money_location_form_screen.dart';
import 'package:uangkeluar/screens/money_location_list_screen.dart';
import 'package:uangkeluar/utils/money_location_balance.dart';

MoneyLocation location(int id, String name, {double initialBalance = 0}) =>
    MoneyLocation(
      id: id,
      name: name,
      icon: 'wallet',
      initialBalance: initialBalance,
      createdAt: '2026-01-01T00:00:00.000',
    );

/// Provider palsu supaya layar bisa diuji tanpa menyentuh SQLite. Yang dipalsu
/// hanya jendela data yang dibaca layar — perhitungan saldonya sendiri sudah
/// diuji terpisah di `money_location_balance_test.dart`.
class FakeProvider extends TransactionProvider {
  FakeProvider({
    this.summaries = const [],
    this.unassigned = 0,
    this.transactionCount = 0,
  });

  final List<MoneyLocationSummary> summaries;
  final double unassigned;
  final int transactionCount;

  final List<String> addedNames = [];
  final List<double> addedInitialBalances = [];
  final List<int> deletedIds = [];

  @override
  List<MoneyLocationSummary> get moneyLocationSummaries => summaries;

  @override
  double get unassignedMoneyBalance => unassigned;

  @override
  Future<int> countTransactionsInMoneyLocation(int id) async =>
      transactionCount;

  @override
  Future<int> addMoneyLocation({
    required String name,
    required String icon,
    double initialBalance = 0,
  }) async {
    addedNames.add(name);
    addedInitialBalances.add(initialBalance);
    return 1;
  }

  @override
  Future<void> deleteMoneyLocation(int id) async => deletedIds.add(id);
}

void main() {
  Future<void> pumpList(WidgetTester tester, FakeProvider provider) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<TransactionProvider>.value(
        value: provider,
        child: const MaterialApp(home: MoneyLocationListScreen()),
      ),
    );
    await tester.pump();
  }

  Future<void> pumpForm(
    WidgetTester tester,
    FakeProvider provider, {
    MoneyLocation? existing,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<TransactionProvider>.value(
        value: provider,
        child: MaterialApp(home: MoneyLocationFormScreen(location: existing)),
      ),
    );
    await tester.pump();
  }

  group('daftar lokasi', () {
    testWidgets('menampilkan nama dan saldo tiap lokasi', (tester) async {
      await pumpList(
        tester,
        FakeProvider(
          summaries: [
            MoneyLocationSummary(
              location: location(1, 'Dompet'),
              balance: 150000,
            ),
            MoneyLocationSummary(
              location: location(2, 'Rekening / ATM'),
              balance: 2500000,
            ),
          ],
        ),
      );

      expect(find.text('Dompet'), findsOneWidget);
      expect(find.text('Rp 150.000'), findsOneWidget);
      expect(find.text('Rekening / ATM'), findsOneWidget);
      expect(find.text('Rp 2.500.000'), findsOneWidget);
    });

    testWidgets('menjumlahkan seluruh lokasi di kartu total', (tester) async {
      await pumpList(
        tester,
        FakeProvider(
          summaries: [
            MoneyLocationSummary(
              location: location(1, 'Dompet'),
              balance: 150000,
            ),
            MoneyLocationSummary(
              location: location(2, 'ATM'),
              balance: 350000,
            ),
          ],
        ),
      );

      expect(find.text('Rp 500.000'), findsOneWidget);
      expect(find.text('Tersebar di 2 lokasi'), findsOneWidget);
    });

    testWidgets('menampilkan baris "Belum ditentukan" saat masih ada sisanya', (
      tester,
    ) async {
      await pumpList(
        tester,
        FakeProvider(
          summaries: [
            MoneyLocationSummary(location: location(1, 'Dompet'), balance: 0),
          ],
          unassigned: 75000,
        ),
      );

      expect(find.text('Belum ditentukan'), findsOneWidget);
      expect(find.text('Rp 75.000'), findsOneWidget);
    });

    testWidgets('menyembunyikan baris "Belum ditentukan" saat nol', (
      tester,
    ) async {
      await pumpList(
        tester,
        FakeProvider(
          summaries: [
            MoneyLocationSummary(location: location(1, 'Dompet'), balance: 0),
          ],
        ),
      );

      expect(find.text('Belum ditentukan'), findsNothing);
    });

    testWidgets('menampilkan empty state saat belum ada lokasi', (
      tester,
    ) async {
      await pumpList(tester, FakeProvider());

      expect(find.text('Belum ada lokasi uang'), findsOneWidget);
      expect(find.text('Tambah Lokasi'), findsWidgets);
    });

    testWidgets('konfirmasi hapus menyebut jumlah transaksi terdampak', (
      tester,
    ) async {
      final provider = FakeProvider(
        summaries: [
          MoneyLocationSummary(location: location(1, 'Dompet'), balance: 0),
        ],
        transactionCount: 7,
      );
      await pumpList(tester, provider);

      await tester.drag(find.text('Dompet'), const Offset(-260, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();

      expect(find.textContaining('7 transaksi'), findsOneWidget);
      expect(find.text('Hapus Dompet?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Batal'));
      await tester.pumpAndSettle();
      expect(provider.deletedIds, isEmpty);
    });
  });

  group('form lokasi', () {
    testWidgets('menolak nama kosong', (tester) async {
      final provider = FakeProvider();
      await pumpForm(tester, provider);

      await tester.tap(find.text('Simpan Lokasi'));
      await tester.pump();

      expect(find.text('Nama lokasi tidak boleh kosong'), findsOneWidget);
      expect(provider.addedNames, isEmpty);
    });

    testWidgets('menyimpan nama dan saldo awal yang diisi', (tester) async {
      final provider = FakeProvider();
      await pumpForm(tester, provider);

      await tester.enterText(find.byType(TextFormField).first, 'Gopay');
      await tester.enterText(find.byType(TextFormField).last, '200000');
      await tester.tap(find.text('Simpan Lokasi'));
      await tester.pumpAndSettle();

      expect(provider.addedNames, ['Gopay']);
      expect(provider.addedInitialBalances, [200000]);
    });

    testWidgets('judul memakai kata "Tambah" saat membuat baru', (
      tester,
    ) async {
      await pumpForm(tester, FakeProvider());

      expect(find.text('Tambah Lokasi Uang'), findsOneWidget);
    });

    testWidgets('mode ubah memuat nama dan saldo awal yang tersimpan', (
      tester,
    ) async {
      await pumpForm(
        tester,
        FakeProvider(),
        existing: location(1, 'Dompet', initialBalance: 50000),
      );

      expect(find.text('Ubah Lokasi Uang'), findsOneWidget);
      expect(find.text('Dompet'), findsOneWidget);
      expect(find.text('50.000'), findsOneWidget);
    });
  });
}
