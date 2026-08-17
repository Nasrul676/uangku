import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uangkeluar/utils/error_message.dart';

void main() {
  test('membuang satu bungkus Exception', () {
    expect(
      friendlyError(Exception('Buku tidak ditemukan')),
      'Buku tidak ditemukan',
    );
  });

  test('membuang bungkus Exception berlapis', () {
    // Ini bentuk yang sebelumnya muncul apa adanya di panel AI.
    final nested = Exception(
      'Gagal memproses pesan: Exception: Gagal menghubungi AI Assistance: '
      "Role 'function' is not supported.",
    );
    expect(
      friendlyError(nested),
      "Gagal menghubungi AI Assistance: Role 'function' is not supported.",
    );
  });

  test('menerjemahkan kegagalan jaringan', () {
    expect(
      friendlyError(const SocketException('failed host lookup')),
      contains('koneksi internet'),
    );
    expect(
      friendlyError(TimeoutException('timeout')),
      contains('terlalu lama'),
    );
  });

  test('pesan biasa dibiarkan apa adanya', () {
    expect(friendlyError('Saldo tidak cukup'), 'Saldo tidak cukup');
  });

  test('exception kosong tidak menghasilkan string kosong', () {
    expect(friendlyError(Exception('')), isNotEmpty);
  });
}
