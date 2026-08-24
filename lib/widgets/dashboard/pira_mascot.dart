import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Suasana hati PiRa, si kapibara penunggu bak mandi.
enum PiraMood { santai, hatiHati, lewatBatas }

/// Menerjemahkan rasio pengeluaran terhadap pemasukan jadi suasana hati.
///
/// Rasio yang sama sudah dihitung `BookRecap.spentRatio` di
/// `cashflow_recap.dart`. Wajahnya adalah data, bukan hiasan — itu yang
/// membuat gaya lucu di beranda tetap membawa informasi.
///
/// Rasio null (belum ada pemasukan sama sekali) dianggap santai: belum ada
/// yang bisa dinilai, dan menampilkan wajah cemas ke pengguna baru yang
/// belum mencatat apa pun jelas keliru.
PiraMood moodForRatio(double? spentRatio) {
  if (spentRatio == null) return PiraMood.santai;
  if (spentRatio > 1.0) return PiraMood.lewatBatas;
  if (spentRatio >= 0.7) return PiraMood.hatiHati;
  return PiraMood.santai;
}

String assetForMood(PiraMood mood) {
  switch (mood) {
    case PiraMood.santai:
      return 'assets/maskot-pira/santai-scene.png';
    case PiraMood.hatiHati:
      return 'assets/maskot-pira/hati-hati-scene.png';
    case PiraMood.lewatBatas:
      return 'assets/maskot-pira/lewat-batas-scene.png';
  }
}

String labelForMood(PiraMood mood) {
  switch (mood) {
    case PiraMood.santai:
      return 'PiRa berendam santai, airnya masih penuh';
    case PiraMood.hatiHati:
      return 'PiRa mulai waspada, air di baknya menyusut';
    case PiraMood.lewatBatas:
      return 'PiRa tetap kalem walau baknya sudah kering';
  }
}

/// Kalimat yang muncul kalau PiRa dicolek.
String greetingForMood(PiraMood mood) {
  switch (mood) {
    case PiraMood.santai:
      return 'Airnya masih hangat. Santai dulu~';
    case PiraMood.hatiHati:
      return 'Airnya mulai surut, pelan-pelan ya.';
    case PiraMood.lewatBatas:
      return 'Baknya kering, tapi masih bisa diisi lagi kok.';
  }
}

/// PiRa — kapibara yang berendam di bak, wajah dan tinggi airnya mengikuti
/// keadaan uangmu.
///
/// Kapibara dipilih bukan cuma karena lucu: ia tidak pernah panik. Maskot yang
/// tetap tenang waktu saldonya menipis berkata "masih bisa dibenahi", bukan
/// "kamu gagal" — dan pengguna yang merasa dihakimi berhenti mencatat.
class PiraMascot extends StatefulWidget {
  const PiraMascot({
    super.key,
    required this.mood,
    this.size = 58,
    this.onTap,
  });

  final PiraMood mood;
  final double size;

  /// Dipanggil setelah PiRa dicolek, sesudah animasinya jalan.
  final VoidCallback? onTap;

  @override
  State<PiraMascot> createState() => PiraMascotState();
}

class PiraMascotState extends State<PiraMascot>
    with SingleTickerProviderStateMixin {
  /// Reaksi sekali jalan — dipakai saat dicolek maupun saat transaksi
  /// tersimpan.
  ///
  /// Sengaja tidak ada animasi napas yang berputar terus. Di ukuran 54 piksel
  /// amplitudonya cuma sepersekian piksel — tak terlihat, tapi tetap membakar
  /// baterai selama beranda terbuka, dan membuat setiap test yang menyentuh
  /// kartu saldo tidak pernah bisa `pumpAndSettle`. PiRa bergerak hanya di
  /// saat yang berarti: dicolek, transaksi tersimpan, dan suasana berubah.
  late final AnimationController _react;

  @override
  void initState() {
    super.initState();
    _react = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
  }

  @override
  void dispose() {
    _react.dispose();
    super.dispose();
  }

  /// Membuat PiRa bereaksi sekali. Bisa dipanggil dari luar lewat
  /// [GlobalKey] saat transaksi berhasil disimpan.
  ///
  /// Sebagian orang benar-benar mual oleh gerakan, dan kedua sistem operasi
  /// menyediakan setelannya — kalau menyala, sapaannya tetap muncul, cuma
  /// goyangannya yang dilewati.
  void react() {
    if (!mounted || MediaQuery.disableAnimationsOf(context)) return;
    _react.forward(from: 0);
  }

  void _handleTap() {
    react();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: labelForMood(widget.mood),
      button: widget.onTap != null,
      image: true,
      child: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.square(
          dimension: widget.size,
          child: AnimatedBuilder(
            animation: _react,
            builder: (context, child) {
              // Satu lompatan yang mereda, bukan pantulan berulang — di
              // beranda yang tenang, gerakan berlebih terasa berisik.
              final t = _react.value;
              final decay = t == 0 ? 0.0 : math.sin(t * math.pi) * (1 - t);

              return Transform.translate(
                offset: Offset(0, -decay * widget.size * 0.16),
                child: Transform.rotate(
                  angle: decay * 0.10,
                  child: Transform.scale(
                    scale: 1 + decay * 0.06,
                    child: child,
                  ),
                ),
              );
            },
            child: _MoodImage(mood: widget.mood, size: widget.size),
          ),
        ),
      ),
    );
  }
}

/// Gambar yang berganti halus saat suasananya berubah.
///
/// Pergantiannya sengaja diberi transisi: begitu belanja melewati ambang,
/// pengguna melihat PiRa *berubah* — bukan tiba-tiba sudah jadi gambar lain
/// tanpa ada yang menandai kapan itu terjadi.
class _MoodImage extends StatelessWidget {
  const _MoodImage({required this.mood, required this.size});

  final PiraMood mood;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Berkasnya 512px sedangkan tampilnya sebesar kuku jari. Tanpa batas ini
    // Flutter menyimpan bitmap penuh di memori untuk setiap suasana.
    final cacheSize =
        (size * MediaQuery.devicePixelRatioOf(context)).round().clamp(64, 512);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.82, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: Image.asset(
        assetForMood(mood),
        key: ValueKey(mood),
        width: size,
        height: size,
        cacheWidth: cacheSize,
        cacheHeight: cacheSize,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
