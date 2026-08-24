import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:uangkeluar/models/money_location.dart';
import 'package:uangkeluar/models/money_transfer.dart';
import 'package:uangkeluar/providers/transaction_provider.dart';
import 'package:uangkeluar/screens/money_location_list_screen.dart';
import 'package:uangkeluar/screens/money_transfer_screen.dart';
import 'package:uangkeluar/utils/money_location_balance.dart';

MoneyLocation location(int id, String name) => MoneyLocation(
  id: id,
  name: name,
  icon: 'wallet',
  createdAt: '2026-01-01T00:00:00.000',
);

MoneyLocationSummary summary(int id, String name, double balance) =>
    MoneyLocationSummary(location: location(id, name), balance: balance);

class RecordedTransfer {
  const RecordedTransfer(this.from, this.to, this.amount, this.note);

  final int from;
  final int to;
  final double amount;
  final String? note;
}

class FakeProvider extends TransactionProvider {
  FakeProvider({
    this.summaries = const [],
    this.transfers = const [],
    this.names = const {},
  });

  final List<MoneyLocationSummary> summaries;
  final List<MoneyTransfer> transfers;
  final Map<int, String> names;

  final List<RecordedTransfer> recorded = [];
  final List<int> deletedTransferIds = [];

  @override
  List<MoneyLocationSummary> get moneyLocationSummaries => summaries;

  @override
  List<MoneyTransfer> get moneyTransfers => transfers;

  @override
  Map<int, String> get moneyLocationNames => names;

  @override
  double get unassignedMoneyBalance => 0;

  @override
  Future<int> addMoneyTransfer({
    required int fromLocationId,
    required int toLocationId,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    recorded.add(
      RecordedTransfer(fromLocationId, toLocationId, amount, note),
    );
    return 1;
  }

  @override
  Future<void> deleteMoneyTransfer(int id) async =>
      deletedTransferIds.add(id);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id', null);
  });

  /// Tombol simpan ada di bawah lipatan pada layar uji 800x600, jadi harus
  /// digulir ke tampak dulu — kalau tidak, ketukannya jatuh di luar viewport.
  Future<void> tapSave(WidgetTester tester) async {
    final button = find.text('Simpan Perpindahan');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> pump(WidgetTester tester, FakeProvider provider, Widget screen) {
    return tester.pumpWidget(
      ChangeNotifierProvider<TransactionProvider>.value(
        value: provider,
        child: MaterialApp(home: screen),
      ),
    );
  }

  group('layar Pindah Uang', () {
    FakeProvider twoLocations() => FakeProvider(
      summaries: [
        summary(1, 'Rekening', 2000000),
        summary(2, 'Dompet', 50000),
      ],
    );

    testWidgets('menampilkan sisi Dari dan Ke dengan placeholder', (
      tester,
    ) async {
      await pump(tester, twoLocations(), const MoneyTransferScreen());
      await tester.pumpAndSettle();

      expect(find.text('Dari'), findsOneWidget);
      expect(find.text('Ke'), findsOneWidget);
      expect(find.text('Pilih lokasi asal'), findsOneWidget);
      expect(find.text('Pilih lokasi tujuan'), findsOneWidget);
    });

    testWidgets('kurang dari dua lokasi memunculkan penjelasan, bukan form', (
      tester,
    ) async {
      await pump(
        tester,
        FakeProvider(summaries: [summary(1, 'Dompet', 0)]),
        const MoneyTransferScreen(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Butuh dua lokasi dulu'), findsOneWidget);
      expect(find.text('Simpan Perpindahan'), findsNothing);
    });

    testWidgets('menolak simpan saat nominal kosong', (tester) async {
      final provider = twoLocations();
      await pump(tester, provider, const MoneyTransferScreen());
      await tester.pumpAndSettle();

      await tapSave(tester);

      expect(find.text('Nominal wajib diisi'), findsOneWidget);
      expect(provider.recorded, isEmpty);
    });

    testWidgets('menolak simpan saat lokasi belum dipilih', (tester) async {
      final provider = twoLocations();
      await pump(tester, provider, const MoneyTransferScreen());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, '500000');
      await tapSave(tester);

      expect(find.text('Pilih lokasi asal dan tujuan dulu'), findsOneWidget);
      expect(provider.recorded, isEmpty);
    });

    testWidgets('menolak asal dan tujuan yang sama', (tester) async {
      final provider = twoLocations();
      await pump(tester, provider, const MoneyTransferScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pilih lokasi asal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rekening').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pilih lokasi tujuan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rekening').last);
      await tester.pumpAndSettle();

      expect(
        find.text('Lokasi asal dan tujuan tidak boleh sama.'),
        findsOneWidget,
      );
      expect(provider.recorded, isEmpty);
    });

    testWidgets('menyimpan perpindahan dengan asal, tujuan, dan nominal benar', (
      tester,
    ) async {
      final provider = twoLocations();
      await pump(tester, provider, const MoneyTransferScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pilih lokasi asal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rekening').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pilih lokasi tujuan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dompet').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, '500000');
      await tapSave(tester);

      expect(provider.recorded, hasLength(1));
      expect(provider.recorded.first.from, 1);
      expect(provider.recorded.first.to, 2);
      expect(provider.recorded.first.amount, 500000);
    });

    testWidgets('nominal melebihi saldo diberi peringatan, bukan diblokir', (
      tester,
    ) async {
      final provider = twoLocations();
      await pump(tester, provider, const MoneyTransferScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pilih lokasi tujuan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rekening').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pilih lokasi asal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dompet').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, '80000');
      await tester.pumpAndSettle();

      expect(find.textContaining('melebihi saldo Dompet'), findsOneWidget);

      await tapSave(tester);

      // Peringatan tidak boleh menghalangi: uang tunai sering sudah berpindah
      // sebelum sempat dicatat.
      expect(provider.recorded, hasLength(1));
      expect(provider.recorded.first.amount, 80000);
    });
  });

  group('jalur masuk', () {
    testWidgets('tombol Pindah Uang ada di layar Lokasi Uang', (tester) async {
      await pump(
        tester,
        FakeProvider(
          summaries: [summary(1, 'ATM', 0), summary(2, 'Dompet', 0)],
        ),
        const MoneyLocationListScreen(),
      );
      await tester.pumpAndSettle();

      // Berlabel, bukan ikon telanjang — di layar sentuh tidak ada kursor
      // untuk memunculkan tooltip.
      expect(find.text('Pindah Uang'), findsOneWidget);
      expect(find.text('Tambah Lokasi'), findsOneWidget);
    });
  });

  group('riwayat perpindahan', () {
    MoneyTransfer transfer({
      int? id = 1,
      int? from = 1,
      int? to = 2,
      double amount = 500000,
      String? note,
    }) => MoneyTransfer(
      id: id,
      fromLocationId: from,
      toLocationId: to,
      amount: amount,
      date: '2026-08-20',
      time: '10:00',
      note: note,
      createdAt: '2026-08-20T10:00:00.000',
    );

    testWidgets('tidak dirender saat belum ada perpindahan', (tester) async {
      await pump(
        tester,
        FakeProvider(summaries: [summary(1, 'Dompet', 0)]),
        const MoneyLocationListScreen(),
      );
      await tester.pumpAndSettle();

      expect(find.text('PERPINDAHAN TERAKHIR'), findsNothing);
    });

    testWidgets('menampilkan arah dan nominal perpindahan', (tester) async {
      await pump(
        tester,
        FakeProvider(
          summaries: [summary(1, 'ATM', 0), summary(2, 'Dompet', 0)],
          transfers: [transfer()],
          names: const {1: 'ATM', 2: 'Dompet'},
        ),
        const MoneyLocationListScreen(),
      );
      await tester.pumpAndSettle();

      expect(find.text('PERPINDAHAN TERAKHIR'), findsOneWidget);
      expect(find.text('ATM → Dompet'), findsOneWidget);
      expect(find.text('Rp 500.000'), findsOneWidget);
    });

    testWidgets('sisi yang lokasinya sudah dihapus tetap terbaca', (
      tester,
    ) async {
      await pump(
        tester,
        FakeProvider(
          summaries: [summary(2, 'Dompet', 0)],
          transfers: [transfer(from: null)],
          names: const {2: 'Dompet'},
        ),
        const MoneyLocationListScreen(),
      );
      await tester.pumpAndSettle();

      expect(find.text('(lokasi dihapus) → Dompet'), findsOneWidget);
    });

    testWidgets('catatan ikut ditampilkan bersama tanggal', (tester) async {
      await pump(
        tester,
        FakeProvider(
          summaries: [summary(1, 'ATM', 0), summary(2, 'Dompet', 0)],
          transfers: [transfer(note: 'Tarik tunai')],
          names: const {1: 'ATM', 2: 'Dompet'},
        ),
        const MoneyLocationListScreen(),
      );
      await tester.pumpAndSettle();

      expect(find.text('20 Agu · Tarik tunai'), findsOneWidget);
    });

    testWidgets('hapus perpindahan minta konfirmasi dan bisa dibatalkan', (
      tester,
    ) async {
      final provider = FakeProvider(
        summaries: [summary(1, 'ATM', 0), summary(2, 'Dompet', 0)],
        transfers: [transfer()],
        names: const {1: 'ATM', 2: 'Dompet'},
      );
      await pump(tester, provider, const MoneyLocationListScreen());
      await tester.pumpAndSettle();

      await tester.drag(find.text('ATM → Dompet'), const Offset(-260, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();

      expect(find.text('Hapus perpindahan ini?'), findsOneWidget);
      expect(find.textContaining('kembali seperti'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Batal'));
      await tester.pumpAndSettle();
      expect(provider.deletedTransferIds, isEmpty);
    });
  });
}
