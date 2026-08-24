import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uangkeluar/models/money_location.dart';
import 'package:uangkeluar/providers/transaction_provider.dart';
import 'package:uangkeluar/utils/money_location_balance.dart';
import 'package:uangkeluar/widgets/money_location_picker.dart';

MoneyLocationSummary summary(int id, String name, double balance) =>
    MoneyLocationSummary(
      location: MoneyLocation(
        id: id,
        name: name,
        icon: 'wallet',
        createdAt: '2026-01-01T00:00:00.000',
      ),
      balance: balance,
    );

class FakeProvider extends TransactionProvider {
  FakeProvider(this.summaries);

  final List<MoneyLocationSummary> summaries;

  @override
  List<MoneyLocationSummary> get moneyLocationSummaries => summaries;
}

void main() {
  /// Membuka picker dari tombol, lalu menyimpan hasilnya supaya bisa diperiksa
  /// — termasuk membedakan "ditutup tanpa memilih" (null) dari "pilih Tanpa
  /// lokasi" (choice dengan locationId null).
  Future<MoneyLocationChoice?> openPicker(
    WidgetTester tester,
    FakeProvider provider, {
    int? selectedId,
  }) async {
    MoneyLocationChoice? result;
    var opened = false;

    await tester.pumpWidget(
      ChangeNotifierProvider<TransactionProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  opened = true;
                  result = await showMoneyLocationPicker(
                    context: context,
                    selectedId: selectedId,
                    title: 'Uang ini dari mana?',
                    noneSubtitle: 'Tidak dicatat asal uangnya',
                  );
                },
                child: const Text('Buka'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
    expect(opened, isTrue);
    return result;
  }

  testWidgets('menampilkan judul, opsi tanpa lokasi, dan daftar lokasi', (
    tester,
  ) async {
    await openPicker(
      tester,
      FakeProvider([
        summary(1, 'Dompet', 150000),
        summary(2, 'Rekening / ATM', 2000000),
      ]),
    );

    expect(find.text('Uang ini dari mana?'), findsOneWidget);
    expect(find.text('Tanpa lokasi'), findsOneWidget);
    expect(find.text('Dompet'), findsOneWidget);
    expect(find.text('Sisa Rp 150.000'), findsOneWidget);
    expect(find.text('Rekening / ATM'), findsOneWidget);
    expect(find.text('Tambah lokasi baru'), findsOneWidget);
  });

  testWidgets('memilih lokasi mengembalikan id-nya', (tester) async {
    MoneyLocationChoice? captured;

    await tester.pumpWidget(
      ChangeNotifierProvider<TransactionProvider>.value(
        value: FakeProvider([summary(7, 'Gopay', 50000)]),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  captured = await showMoneyLocationPicker(
                    context: context,
                    selectedId: null,
                    title: 'Uang ini dari mana?',
                    noneSubtitle: 'Tidak dicatat asal uangnya',
                  );
                },
                child: const Text('Buka'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gopay'));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.locationId, 7);
  });

  testWidgets('memilih "Tanpa lokasi" mengembalikan choice ber-id null', (
    tester,
  ) async {
    MoneyLocationChoice? captured;

    await tester.pumpWidget(
      ChangeNotifierProvider<TransactionProvider>.value(
        value: FakeProvider([summary(7, 'Gopay', 50000)]),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  captured = await showMoneyLocationPicker(
                    context: context,
                    selectedId: 7,
                    title: 'Uang ini dari mana?',
                    noneSubtitle: 'Tidak dicatat asal uangnya',
                  );
                },
                child: const Text('Buka'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tanpa lokasi'));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.locationId, isNull);
  });

  testWidgets('daftar kosong tetap menawarkan cara menambah lokasi', (
    tester,
  ) async {
    await openPicker(tester, FakeProvider(const []));

    expect(find.text('Belum ada lokasi uang.'), findsOneWidget);
    expect(find.text('Tambah lokasi baru'), findsOneWidget);
  });
}
