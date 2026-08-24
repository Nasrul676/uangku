import 'package:intl/intl.dart';

/// Nominal ringkas untuk tempat sempit: "Rp 171rb", "Rp 2,4jt".
///
/// Dipakai di kalimat dan kartu kecil di beranda, tempat "Rp 2.400.000" terlalu
/// panjang dan justru memperlambat pembacaan. Angka penuh tetap dipakai di
/// tempat yang memang harus tepat — saldo utama, laporan, dan ekspor.
String compactRupiah(double value, {bool withPrefix = true}) {
  final prefix = withPrefix ? 'Rp ' : '';
  final sign = value < 0 ? '-' : '';
  final abs = value.abs();

  if (abs >= 1000000000) {
    return '$sign$prefix${_trim(abs / 1000000000)}m';
  }
  if (abs >= 1000000) {
    return '$sign$prefix${_trim(abs / 1000000)}jt';
  }
  if (abs >= 1000) {
    return '$sign$prefix${_trim(abs / 1000)}rb';
  }
  return '$sign$prefix${abs.round()}';
}

/// Satu angka di belakang koma, dan koma itu dibuang kalau nol.
///
/// "Rp 2,0jt" terbaca seperti hasil pembulatan yang ceroboh; "Rp 2jt" tidak.
String _trim(double value) {
  final rounded = (value * 10).round() / 10;
  if (rounded == rounded.roundToDouble()) return rounded.round().toString();
  return NumberFormat('0.#', 'id_ID').format(rounded);
}
