import '../models/finance_transaction.dart';
import '../models/money_location.dart';
import '../models/money_transfer.dart';

/// Saldo satu lokasi beserta lokasinya, siap dirender tanpa perhitungan lagi
/// di dalam `build`.
class MoneyLocationSummary {
  const MoneyLocationSummary({required this.location, required this.balance});

  final MoneyLocation location;
  final double balance;

  int? get id => location.id;
  String get name => location.name;
  String get icon => location.icon;
}

/// Arus bersih (pemasukan dikurangi pengeluaran) per lokasi, dalam satu kali
/// sapuan transaksi.
///
/// Sengaja tidak menyaring periode buku: uang di dompet tidak ikut hilang
/// waktu buku ditutup, jadi saldo lokasi dihitung dari seluruh riwayat.
/// Transaksi tanpa lokasi diabaikan di sini — lihat [unassignedNetTotal].
Map<int, double> buildMoneyLocationNetTotals(
  List<FinanceTransaction> transactions, {
  List<MoneyTransfer> transfers = const [],
}) {
  final totals = <int, double>{};
  for (final tx in transactions) {
    final locationId = tx.moneyLocationId;
    if (locationId == null) continue;
    final delta = tx.type == 'INCOME' ? tx.amount : -tx.amount;
    totals[locationId] = (totals[locationId] ?? 0) + delta;
  }

  // Perpindahan cuma menggeser uang antar lokasi: satu sisi berkurang, sisi
  // lain bertambah dengan angka yang sama. Jumlah seluruh lokasi karena itu
  // tidak berubah sedikit pun oleh transfer — sifat itulah yang diuji.
  for (final transfer in transfers) {
    final from = transfer.fromLocationId;
    if (from != null) {
      totals[from] = (totals[from] ?? 0) - transfer.amount;
    }
    final to = transfer.toLocationId;
    if (to != null) {
      totals[to] = (totals[to] ?? 0) + transfer.amount;
    }
  }

  return totals;
}

/// Arus bersih transaksi yang belum ditandai lokasinya.
///
/// Angka ini yang membuat rincian di beranda tetap jujur: tanpa baris ini,
/// daftar lokasi akan terlihat seolah-olah sudah menjelaskan seluruh uang
/// pengguna, padahal transaksi lama semuanya masih kosong lokasinya.
double unassignedNetTotal(List<FinanceTransaction> transactions) {
  var total = 0.0;
  for (final tx in transactions) {
    if (tx.moneyLocationId != null) continue;
    total += tx.type == 'INCOME' ? tx.amount : -tx.amount;
  }
  return total;
}

/// Saldo akhir satu lokasi: saldo awal ditambah arus bersihnya.
double resolveMoneyLocationBalance({
  required MoneyLocation location,
  required Map<int, double> netTotals,
}) {
  final id = location.id;
  return location.initialBalance + (id == null ? 0 : (netTotals[id] ?? 0));
}

/// Ringkasan seluruh lokasi, urut sesuai urutan daftar yang diberikan.
List<MoneyLocationSummary> buildMoneyLocationSummaries({
  required List<MoneyLocation> locations,
  required List<FinanceTransaction> transactions,
  List<MoneyTransfer> transfers = const [],
}) {
  final netTotals = buildMoneyLocationNetTotals(
    transactions,
    transfers: transfers,
  );
  return locations
      .map(
        (location) => MoneyLocationSummary(
          location: location,
          balance: resolveMoneyLocationBalance(
            location: location,
            netTotals: netTotals,
          ),
        ),
      )
      .toList(growable: false);
}
