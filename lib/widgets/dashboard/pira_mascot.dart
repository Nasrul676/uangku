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

/// Satu periode penuh gerakan menganggur PiRa.
///
/// Sengaja panjang: yang dicari kesan mengapung, bukan bergetar. Semua
/// suasana memakai periode yang sama dan hanya berbeda jumlah putarannya, jadi
/// suasana bisa berganti di tengah jalan tanpa perlu menyetel ulang controller
/// — yang akan membuat PiRa meloncat balik ke titik awal.
const Duration piraDriftPeriod = Duration(seconds: 18);

/// Bagaimana PiRa hanyut saat tidak disentuh.
///
/// Sumbu X dan Y punya jumlah putaran yang berbeda, jadi lintasannya berupa
/// angka delapan — hanyut ke segala arah, bukan naik-turun di satu garis.
class PiraDrift {
  const PiraDrift({
    required this.amplitudeX,
    required this.amplitudeY,
    required this.tilt,
    required this.cyclesX,
    required this.cyclesY,
    required this.cyclesTilt,
  });

  /// Simpangan dalam piksel, diukur pada PiRa berukuran 64. Ukuran lain
  /// menskalakannya, supaya maskot kecil tidak bergoyang sejauh yang besar.
  final double amplitudeX;
  final double amplitudeY;

  /// Kemiringan maksimum dalam radian.
  final double tilt;

  /// Jumlah putaran penuh dalam satu [piraDriftPeriod]. Wajib bilangan bulat:
  /// pecahan membuat gerakannya tersentak saat pengulangan kembali ke awal.
  final int cyclesX;
  final int cyclesY;
  final int cyclesTilt;
}

/// Gerakannya ikut suasana, sama seperti wajahnya.
///
/// Yang santai mengapung lebar dan lambat; yang mulai waspada bergerak lebih
/// kecil tapi lebih sering, seperti tidak bisa diam; yang baknya kering nyaris
/// tidak bergerak — tetap tenang, cuma kehabisan tenaga.
PiraDrift driftForMood(PiraMood mood) {
  switch (mood) {
    case PiraMood.santai:
      return const PiraDrift(
        amplitudeX: 4.0,
        amplitudeY: 5.0,
        tilt: 0.032,
        cyclesX: 2,
        cyclesY: 3,
        cyclesTilt: 2,
      );
    case PiraMood.hatiHati:
      return const PiraDrift(
        amplitudeX: 2.4,
        amplitudeY: 2.8,
        tilt: 0.05,
        cyclesX: 5,
        cyclesY: 7,
        cyclesTilt: 5,
      );
    case PiraMood.lewatBatas:
      return const PiraDrift(
        amplitudeX: 2.0,
        amplitudeY: 3.0,
        tilt: 0.018,
        cyclesX: 1,
        cyclesY: 2,
        cyclesTilt: 1,
      );
  }
}

/// PiRa — kapibara yang berendam di bak, wajah dan tinggi airnya mengikuti
/// keadaan uangmu.
///
/// Kapibara dipilih bukan cuma karena lucu: ia tidak pernah panik. Maskot yang
/// tetap tenang waktu saldonya menipis berkata "masih bisa dibenahi", bukan
/// "kamu gagal" — dan pengguna yang merasa dihakimi berhenti mencatat.
class PiraMascot extends StatefulWidget {
  const PiraMascot({super.key, required this.mood, this.size = 58, this.onTap});

  final PiraMood mood;
  final double size;

  /// Dipanggil setelah PiRa dicolek, sesudah animasinya jalan.
  final VoidCallback? onTap;

  @override
  State<PiraMascot> createState() => PiraMascotState();
}

class PiraMascotState extends State<PiraMascot>
    with TickerProviderStateMixin {
  /// Reaksi sekali jalan — dipakai saat dicolek maupun saat transaksi
  /// tersimpan. Berlapis di atas gerakan menganggur, bukan menggantikannya.
  late final AnimationController _react;

  /// Gerakan menganggur yang berputar terus selama PiRa terlihat.
  ///
  /// Hanya menggerakkan `Transform` di atas satu gambar yang sudah di-cache —
  /// tidak ada tata letak yang dihitung ulang tiap frame. Tetap saja ini
  /// berarti beranda menggambar terus-menerus, jadi ia benar-benar berhenti
  /// (bukan sekadar beramplitudo nol) saat pengguna mematikan animasi.
  late final AnimationController _drift;

  @override
  void initState() {
    super.initState();
    _react = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _drift = AnimationController(vsync: this, duration: piraDriftPeriod);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncDrift();
  }

  void _syncDrift() {
    if (MediaQuery.disableAnimationsOf(context)) {
      if (_drift.isAnimating) _drift.stop();
      _drift.value = 0;
      return;
    }
    if (!_drift.isAnimating) _drift.repeat();
  }

  @override
  void dispose() {
    _react.dispose();
    _drift.dispose();
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
            animation: Listenable.merge([_react, _drift]),
            builder: (context, child) {
              final drift = driftForMood(widget.mood);
              // Simpangannya ditakar pada PiRa berukuran 64 — yang seukuran
              // kuku jari tidak boleh berayun sejauh yang seukuran kartu.
              final span = widget.size / 64;
              final phase = _drift.value * 2 * math.pi;

              // Keduanya sinus, jadi pada nilai controller 0 posisinya persis
              // di titik asal. Itu yang membuat "animasi dimatikan" benar-
              // benar berarti diam, bukan diam di tempat yang meleset.
              final driftX =
                  math.sin(phase * drift.cyclesX) * drift.amplitudeX * span;
              final driftY =
                  math.sin(phase * drift.cyclesY) * drift.amplitudeY * span;
              final driftTilt = math.sin(phase * drift.cyclesTilt) * drift.tilt;

              // Satu lompatan yang mereda, bukan pantulan berulang — di
              // beranda yang tenang, gerakan berlebih terasa berisik.
              final t = _react.value;
              final decay = t == 0 ? 0.0 : math.sin(t * math.pi) * (1 - t);

              return Transform.translate(
                offset: Offset(driftX, driftY - decay * widget.size * 0.16),
                child: Transform.rotate(
                  angle: driftTilt + decay * 0.10,
                  child: Transform.scale(scale: 1 + decay * 0.06, child: child),
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
    final cacheSize = (size * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(64, 512);

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
