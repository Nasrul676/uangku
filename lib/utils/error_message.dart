import 'dart:async';
import 'dart:io';

/// Mengubah exception mentah jadi kalimat yang bisa dibaca pengguna.
///
/// Tujuannya dua: membuang bungkus teknis (`Exception: `, dan bungkus ganda
/// seperti `Exception: Gagal A: Exception: Gagal B`), lalu menerjemahkan
/// kegagalan yang sudah dikenal jadi bahasa yang bisa ditindaklanjuti.
String friendlyError(Object error) {
  if (error is SocketException) {
    return 'Tidak ada koneksi internet. Coba lagi setelah tersambung.';
  }
  if (error is TimeoutException) {
    return 'Server terlalu lama merespons. Coba lagi sebentar lagi.';
  }
  if (error is FormatException) {
    return 'Format data yang diterima tidak sesuai.';
  }

  var message = error.toString();

  // Buang bungkus `Exception: ` berlapis, bukan cuma yang paling luar.
  var previous = '';
  while (previous != message) {
    previous = message;
    message = message.replaceFirst(
      RegExp(r'^(Exception|_Exception|StateError|ArgumentError):\s*'),
      '',
    );
  }

  // Kalau pesannya berbentuk "Gagal A: Gagal B: penyebab asli", ambil
  // bagian paling dalam — itu yang benar-benar menjelaskan masalahnya.
  final segments = message.split(RegExp(r':\s*Exception:\s*'));
  message = segments.last.trim();

  if (message.isEmpty) {
    return 'Terjadi kesalahan yang tidak diketahui.';
  }

  return message;
}
