class Expense {
  final String tanggal;
  final String kategori;
  final double nominal;
  final int qty;
  final String keterangan;

  Expense({
    required this.tanggal,
    required this.kategori,
    required this.nominal,
    required this.qty,
    required this.keterangan,
  });

  /// Returns a JSON map with keys matching the Google Sheet column headers exactly.
  Map<String, dynamic> toJson() {
    return {
      'Tanggal': tanggal,
      'Kategori': kategori,
      'Nominal': nominal,
      'Qty': qty,
      'Keterangan': keterangan,
    };
  }
}
