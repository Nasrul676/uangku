import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';

/// Jarak gulir saat saldo mulai naik ke header, dan saat pergantiannya
/// selesai.
///
/// Titik mulainya sengaja bukan nol: gulir sepele beberapa piksel — yang
/// terjadi tiap kali jari menyentuh layar — tidak boleh langsung menukar
/// sapaan dengan angka.
const double _revealStart = 28;
const double _revealEnd = 108;

/// Bar hijau di puncak beranda.
///
/// Warnanya sama persis dengan kartu saldo di bawahnya dan menempel ke tepi
/// layar, jadi keduanya terbaca sebagai satu bidang hijau yang utuh, bukan
/// sebagai bar dan kartu yang kebetulan sewarna.
///
/// Isinya berganti mengikuti gulir: saat kartu saldo masih terlihat, bar ini
/// menyapa; begitu angka besarnya tergulung ke atas, saldo naik menggantikan
/// sapaan supaya angkanya tidak pernah benar-benar hilang dari layar.
class DashboardHeaderBar extends StatelessWidget {
  const DashboardHeaderBar({
    super.key,
    required this.greeting,
    required this.netBalance,
    required this.isBalanceHidden,
    required this.scrollController,
    required this.actions,
  });

  final String greeting;
  final double netBalance;
  final bool isBalanceHidden;

  /// Controller milik daftar beranda. Boleh belum punya klien — saat tab lain
  /// sedang terbuka, tidak ada daftar yang terpasang padanya.
  final ScrollController scrollController;

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scrollController,
      builder: (context, _) {
        final progress = _progress();

        return Container(
          width: double.infinity,
          color: AppTheme.neoMint,
          child: SafeArea(
            bottom: false,
            // Hijaunya tetap menembus sampai tepi fisik layar; yang dijaga
            // hanya isinya supaya tidak tertutup poni atau bilah status.
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Expanded(child: _buildTitle(context, progress)),
                  const SizedBox(width: 8),
                  ...actions,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 0 saat beranda di puncak, 1 saat saldo sudah sepenuhnya naik ke bar.
  double _progress() {
    // `offset` melempar kalau controller-nya dipakai lebih dari satu daftar
    // sekaligus — yang memang terjadi sesaat waktu tab berganti dengan
    // animasi, karena daftar lama belum dilepas saat yang baru dipasang.
    if (!scrollController.hasClients ||
        scrollController.positions.length != 1) {
      return 0;
    }

    final travelled = scrollController.offset - _revealStart;
    return (travelled / (_revealEnd - _revealStart)).clamp(0.0, 1.0);
  }

  Widget _buildTitle(BuildContext context, double progress) {
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      // Bar ini selalu mint, terang di mode gelap maupun terang. Teks yang
      // mewarisi warna tema jadi putih di mode gelap — 1.35:1 di atas mint.
      color: AppTheme.borderColor,
    );

    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        _CrossfadeLayer(
          opacity: 1 - progress,
          dy: -14 * progress,
          child: Text(
            greeting,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: baseStyle,
          ),
        ),
        _CrossfadeLayer(
          opacity: progress,
          dy: 18 * (1 - progress),
          child: Semantics(
            label: 'Sisa uangmu ${_semanticBalance()}',
            excludeSemantics: true,
            child: Text(
              _balanceText(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: baseStyle?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _balanceText() =>
      isBalanceHidden ? 'Rp ••••••' : _formatRupiah(netBalance);

  String _semanticBalance() =>
      isBalanceHidden ? 'disembunyikan' : _formatRupiah(netBalance);

  String _formatRupiah(double value) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final formatted = formatter.format(value.abs());
    return value < 0 ? '-$formatted' : formatted;
  }
}

/// Satu lapis silih-ganti di bar header.
///
/// Lapis yang sudah pudar juga dicabut dari pohon semantik — kalau tidak,
/// pembaca layar membacakan sapaan dan saldo berbarengan sepanjang waktu,
/// padahal mata hanya melihat salah satunya.
class _CrossfadeLayer extends StatelessWidget {
  const _CrossfadeLayer({
    required this.opacity,
    required this.dy,
    required this.child,
  });

  final double opacity;
  final double dy;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final visible = opacity > 0.5;

    return ExcludeSemantics(
      excluding: !visible,
      child: IgnorePointer(
        ignoring: !visible,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, dy), child: child),
        ),
      ),
    );
  }
}

/// Bidang hijau yang mengisi celah saat daftar ditarik melewati puncaknya.
///
/// `BouncingScrollPhysics` membiarkan isi digeser ke bawah melampaui puncak.
/// Celah yang terbuka di situ memperlihatkan latar scaffold — krem di mode
/// terang, hitam pekat di mode gelap — dan hijau beranda terlihat terpotong
/// jadi dua potong oleh pita gelap.
///
/// Tingginya persis sebesar tarikannya, jadi bidang ini tidak pernah terlihat
/// saat daftarnya diam maupun saat digulung ke bawah. Dipasang di belakang
/// daftar, bukan di depannya.
class HeaderOverscrollFill extends StatelessWidget {
  const HeaderOverscrollFill({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scrollController,
      builder: (context, _) => SizedBox(
        width: double.infinity,
        height: _overscroll(),
        child: const ColoredBox(color: AppTheme.neoMint),
      ),
    );
  }

  double _overscroll() {
    // `offset` melempar kalau controller-nya dipakai lebih dari satu daftar
    // sekaligus — yang memang terjadi sesaat waktu tab berganti dengan animasi.
    if (!scrollController.hasClients ||
        scrollController.positions.length != 1) {
      return 0;
    }

    final offset = scrollController.offset;
    return offset < 0 ? -offset : 0;
  }
}
