import 'package:intl/intl.dart';

/// Label waktu untuk daftar transaksi.
///
/// Untuk hari ini dan kemarin, waktu relatif jauh lebih cepat dicerna daripada
/// "17/08/2026 12:30". Lewat dari itu tanggal biasa justru lebih berguna —
/// "23 hari lalu" memaksa orang berhitung sendiri.
///
/// [date] adalah teks 'yyyy-MM-dd' seperti yang tersimpan di basis data, dan
/// [time] teks 'HH:mm' yang boleh kosong.
String relativeTimeLabel(String date, String? time, DateTime now) {
  final parsed = DateTime.tryParse(date);
  if (parsed == null) return date;

  final day = DateTime(parsed.year, parsed.month, parsed.day);
  final today = DateTime(now.year, now.month, now.day);
  final dayDiff = today.difference(day).inDays;

  // Transaksi bertanggal besok bisa muncul dari pencatatan terjadwal. Tidak
  // masuk akal menyebutnya "-1 hari lalu".
  if (dayDiff < 0) {
    return DateFormat('d MMM yyyy', 'id').format(day);
  }

  if (dayDiff == 0) {
    final at = _combine(day, time);
    if (at == null) return 'hari ini';

    final minutes = now.difference(at).inMinutes;
    // Jam yang tercatat bisa lebih maju dari sekarang kalau pengguna mengisi
    // jam secara manual. Diperlakukan sebagai baru saja, bukan angka minus.
    if (minutes < 1) return 'baru saja';
    if (minutes < 60) return '$minutes menit lalu';
    return '${minutes ~/ 60} jam lalu';
  }

  if (dayDiff == 1) {
    final at = _combine(day, time);
    return at == null ? 'kemarin' : 'kemarin, ${_clock(at)}';
  }

  if (dayDiff < 7) return '$dayDiff hari lalu';

  return DateFormat('d MMM yyyy', 'id').format(day);
}

DateTime? _combine(DateTime day, String? time) {
  final raw = time?.trim();
  if (raw == null || raw.isEmpty) return null;

  final parts = raw.split(':');
  if (parts.length < 2) return null;

  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

  return DateTime(day.year, day.month, day.day, hour, minute);
}

String _clock(DateTime at) {
  final hour = at.hour.toString().padLeft(2, '0');
  final minute = at.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
