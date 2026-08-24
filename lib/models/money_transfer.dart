/// Perpindahan uang antar lokasi — misal tarik tunai dari rekening ke dompet.
///
/// Sengaja **bukan** baris di tabel `transactions`: memindahkan uang antar
/// lokasi bukan peristiwa arus kas. Tidak ada uang yang masuk, tidak ada yang
/// keluar — uangnya tidak pernah meninggalkan pengguna. Kalau transfer ditulis
/// sebagai sepasang pemasukan+pengeluaran, total pemasukan dan pengeluaran
/// buku yang sama akan sama-sama menggelembung, dan ikut menyeret budget
/// rencana, alokasi kantong persentase, jatah harian, grafik, serta laporan.
///
/// Tanpa `book_period_id` — lokasi uang lintas periode buku, jadi
/// perpindahannya pun harus begitu.
class MoneyTransfer {
  const MoneyTransfer({
    this.id,
    this.fromLocationId,
    this.toLocationId,
    required this.amount,
    required this.date,
    this.time,
    this.note,
    required this.createdAt,
  });

  final int? id;

  /// Null kalau lokasinya sudah dihapus. Barisnya tetap disimpan supaya saldo
  /// sisi yang masih ada tidak ikut berubah — lihat `deleteMoneyLocation`.
  final int? fromLocationId;
  final int? toLocationId;

  final double amount;
  final String date;
  final String? time;
  final String? note;
  final String createdAt;

  /// Baris yang kedua sisinya sudah hilang tidak lagi memengaruhi saldo siapa
  /// pun, jadi tidak ada gunanya disimpan.
  bool get isOrphan => fromLocationId == null && toLocationId == null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'from_location_id': fromLocationId,
      'to_location_id': toLocationId,
      'amount': amount,
      'date': date,
      'time': time,
      'note': note,
      'created_at': createdAt,
    };
  }

  factory MoneyTransfer.fromMap(Map<String, dynamic> map) {
    return MoneyTransfer(
      id: map['id'] as int?,
      fromLocationId: (map['from_location_id'] as num?)?.toInt(),
      toLocationId: (map['to_location_id'] as num?)?.toInt(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      date: map['date'] as String? ?? '',
      time: map['time'] as String?,
      note: map['note'] as String?,
      createdAt: map['created_at'] as String? ?? '',
    );
  }

  MoneyTransfer copyWith({
    int? id,
    int? fromLocationId,
    int? toLocationId,
    double? amount,
    String? date,
    String? time,
    String? note,
    String? createdAt,
  }) {
    return MoneyTransfer(
      id: id ?? this.id,
      fromLocationId: fromLocationId ?? this.fromLocationId,
      toLocationId: toLocationId ?? this.toLocationId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      time: time ?? this.time,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
