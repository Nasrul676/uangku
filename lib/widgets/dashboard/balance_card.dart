import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../app_card.dart';
import '../../theme/app_theme.dart';
import '../../utils/daily_budget.dart';
import '../../utils/icon_picker_utils.dart';
import '../../utils/money_location_balance.dart';
import 'pira_mascot.dart';

/// Kartu saldo beranda.
///
/// Dulu kartu ini menumpuk enam angka sekaligus, dan salah satunya — "Selisih"
/// — nilainya persis sama dengan saldo di atasnya, karena keduanya
/// `netBalance`. Sekarang tersisa satu angka besar, lalu satu kalimat yang
/// menerjemahkannya jadi keputusan hari ini.
///
/// Rincian pemasukan, pengeluaran, dan sebaran lokasi uang terbuka sejak
/// beranda dibuka. Angka yang harus diketuk dulu praktis tidak pernah dibaca;
/// yang mau beranda ringkas tinggal melipatnya sendiri, dan itu keputusan
/// yang jauh lebih jarang diambil daripada kebutuhan melihat rinciannya.
///
/// PiRa tidak lagi berdiri di samping angka saldo, melainkan duduk di dalam
/// kartu pesan di bawahnya — maskot dan kalimat yang ia sampaikan jadi satu
/// benda, bukan dua elemen yang kebetulan bertetangga.
class BalanceCard extends StatefulWidget {
  const BalanceCard({
    super.key,
    required this.theme,
    required this.totalIncome,
    required this.totalExpense,
    required this.netBalance,
    required this.isBalanceHidden,
    required this.onToggleBalanceVisibility,
    required this.onAddIncome,
    required this.onAddExpense,
    this.mood = PiraMood.santai,
    this.budget,
    this.locations = const [],
    this.unassignedBalance = 0,
    this.onManageLocations,
    this.mascotKey,
    this.onTapMascot,
    this.header,
  });

  final ThemeData theme;
  final double totalIncome;
  final double totalExpense;
  final double netBalance;
  final bool isBalanceHidden;
  final VoidCallback onToggleBalanceVisibility;
  final VoidCallback onAddIncome;
  final VoidCallback onAddExpense;
  final PiraMood mood;

  /// Null kalau angkanya tidak bisa dipercaya — buku sudah lewat, saldo habis,
  /// atau belum ada pengeluaran untuk jadi dasar perkiraan. Perkiraan harinya
  /// diganti sapaan PiRa, bukan diisi tebakan.
  final DailyBudget? budget;

  /// Saldo per tempat penyimpanan uang. Kosong berarti pengguna belum memakai
  /// fiturnya — bagiannya tidak dirender sama sekali, bukan dirender kosong.
  final List<MoneyLocationSummary> locations;

  /// Sisa dari transaksi yang belum ditandai lokasinya.
  ///
  /// Tanpa baris ini daftar di atasnya akan terbaca seolah sudah menjelaskan
  /// seluruh uang pengguna — padahal transaksi lama semuanya masih kosong.
  final double unassignedBalance;

  final VoidCallback? onManageLocations;

  /// Dipakai beranda untuk menyuruh PiRa bereaksi saat transaksi tersimpan.
  final GlobalKey<PiraMascotState>? mascotKey;

  final VoidCallback? onTapMascot;

  /// Baris yang duduk paling atas di dalam kartu, sebelum label "SISA UANGMU".
  ///
  /// Beranda mengisinya dengan tanggal dan chip buku aktif. Keduanya dulu
  /// berdiri sendiri di atas kartu, di atas latar abu — yang memutus bidang
  /// hijau jadi dua potong begitu kartunya dibuat menempel ke tepi layar.
  final Widget? header;

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> {
  /// Terbuka sejak awal. Lihat catatan di dokumentasi kelas: melipat rincian
  /// adalah pilihan sesekali, membacanya adalah kebiasaan harian.
  bool _showDetail = true;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final budget = widget.budget;
    final header = widget.header;

    return AppCard(
      // Menempel ke tepi kiri dan kanan layar, menyambung mulus dengan bar
      // hijau di atasnya. Sudut bawahnya saja yang dibulatkan — sudut atas
      // yang ikut membulat akan memunculkan celah abu di pertemuan keduanya.
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      color: AppTheme.neoMint,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
      // Tanpa bingkai sama sekali. Bingkai satu sisi bukan bingkai seragam,
      // dan Flutter tidak bisa menggambarnya mengikuti sudut membulat — garis
      // lurusnya melewati lengkungan dan terbaca sebagai potongan. Batas
      // kartunya sudah cukup dijelaskan oleh warna dan sudut bawahnya.
      border: const Border(),
      // Bayangan keras bawaan tema bergeser (6,6) — di kartu selebar layar
      // ujungnya terpotong dan menyisakan balok hitam menggantung.
      boxShadow: const [],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null) ...[header, const SizedBox(height: 8)],
          Row(
            children: [
              Expanded(
                child: Text(
                  'SISA UANGMU',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: AppTheme.borderColor.withValues(alpha: 0.72),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Tampilkan atau sembunyikan saldo',
                visualDensity: VisualDensity.compact,
                splashRadius: 18,
                onPressed: widget.onToggleBalanceVisibility,
                icon: Icon(
                  widget.isBalanceHidden ? LucideIcons.eyeOff : LucideIcons.eye,
                  size: 18,
                  color: AppTheme.borderColor,
                ),
              ),
            ],
          ),
          // Sekarang angka saldo memakai seluruh lebar kartu — PiRa sudah
          // pindah ke kartu pesan di bawah. `scaleDown` tetap dipertahankan
          // karena `textScaler` masih bisa sampai 1,3 dan saldo belasan juta
          // tetap bisa melebihi lebar layar sempit.
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: AnimatedVisibilityCurrencyText(
                value: widget.netBalance,
                isHidden: widget.isBalanceHidden,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: AppTheme.borderColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                childBuilder: (style) => AnimatedNetBalanceText(
                  value: widget.netBalance,
                  style: style,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),
          // Kartu pesan selalu ada, karena PiRa tinggal di dalamnya. Saat
          // angkanya tidak bisa dipercaya atau saldo sedang disembunyikan,
          // yang berganti hanya kalimatnya — maskotnya tidak ikut hilang.
          _PiraMessage(
            text: (budget != null && !widget.isBalanceHidden)
                ? describeBudget(budget)
                : greetingForMood(widget.mood),
            mood: widget.mood,
            mascotKey: widget.mascotKey,
            onTapMascot: widget.onTapMascot,
          ),

          const SizedBox(height: 12),
          _DetailToggle(
            expanded: _showDetail,
            onTap: () => setState(() => _showDetail = !_showDetail),
          ),
          // Sengaja AnimatedSize dengan anak bersyarat, bukan AnimatedCrossFade:
          // yang terakhir tetap membangun anak yang tersembunyi, jadi barisnya
          // masih ada di pohon widget walau tak terlihat.
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !_showDetail
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      children: [
                        // Dua angka yang berlawanan arah, jadi dua bidang yang
                        // berdampingan — bukan dua baris bertumpuk yang harus
                        // dibaca berurutan untuk tahu mana yang lebih besar.
                        Row(
                          children: [
                            Expanded(
                              child: _AmountTile(
                                label: 'MASUK',
                                value: widget.totalIncome,
                                valueColor: AppTheme.incomeGreen,
                                isHidden: widget.isBalanceHidden,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _AmountTile(
                                label: 'KELUAR',
                                value: widget.totalExpense,
                                valueColor: AppTheme.expenseRed,
                                isHidden: widget.isBalanceHidden,
                              ),
                            ),
                          ],
                        ),
                        if (widget.locations.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _MoneyLocationBreakdown(
                            locations: widget.locations,
                            unassignedBalance: widget.unassignedBalance,
                            isHidden: widget.isBalanceHidden,
                            onManage: widget.onManageLocations,
                          ),
                        ],
                      ],
                    ),
                  ),
          ),

          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ChunkyActionButton(
                  label: 'Masuk',
                  icon: LucideIcons.arrowDown,
                  background: AppTheme.neoPaper,
                  onTap: widget.onAddIncome,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChunkyActionButton(
                  label: 'Keluar',
                  icon: LucideIcons.arrowUp,
                  background: AppTheme.neoCoral,
                  onTap: widget.onAddExpense,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Kartu pesan di bawah saldo — bagian yang membuat angkanya bisa dipakai,
/// sekarang beserta PiRa yang menyampaikannya.
///
/// Maskot dan kalimat digabung dalam satu bingkai supaya terbaca sebagai
/// "PiRa sedang bilang sesuatu", bukan sebagai stiker yang menempel di sebelah
/// angka. Ketukan hanya aktif pada maskotnya, jadi teksnya tetap bisa
/// diseleksi pembaca layar tanpa memicu sapaan.
class _PiraMessage extends StatelessWidget {
  const _PiraMessage({
    required this.text,
    required this.mood,
    this.mascotKey,
    this.onTapMascot,
  });

  final String text;
  final PiraMood mood;
  final GlobalKey<PiraMascotState>? mascotKey;
  final VoidCallback? onTapMascot;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppTheme.neoPaper.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppTheme.borderColor, width: 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: AppTheme.borderColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          PiraMascot(key: mascotKey, mood: mood, size: 64, onTap: onTapMascot),
        ],
      ),
    );
  }
}

class _DetailToggle extends StatelessWidget {
  const _DetailToggle({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // "Sembunyikan rincian" di `textScaler` 1,3 lebih lebar dari
            // kartunya sendiri di layar 320px. Dikecilkan seperlunya, bukan
            // dipotong — label tombol yang terpenggal berhenti jadi label.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  expanded ? 'Sembunyikan rincian' : 'Lihat rincian',
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.borderColor.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 3),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(
                LucideIcons.chevronDown,
                size: 15,
                color: AppTheme.borderColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tombol aksi utama beranda.
///
/// Tebal, selebar setengah layar, dengan bayangan keras yang mengecil saat
/// ditekan — gerakan "tertekan" yang sama dengan bahasa neo-brutalis di layar
/// lain. Sebelumnya tombol ini kecil dan tenggelam di dasar kartu saldo.
class ChunkyActionButton extends StatefulWidget {
  const ChunkyActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.background,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color background;
  final VoidCallback onTap;

  @override
  State<ChunkyActionButton> createState() => _ChunkyActionButtonState();
}

class _ChunkyActionButtonState extends State<ChunkyActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final offset = _pressed ? 2.0 : 0.0;

    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          setState(() => _pressed = false);
          widget.onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          transform: Matrix4.translationValues(offset, offset, 0),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: widget.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: AppTheme.borderColor,
                offset: Offset(3 - offset, 4 - offset),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 18, color: AppTheme.borderColor),
              const SizedBox(width: 7),
              // Di layar sempit dengan `textScaler` 1,3, label ini melebihi
              // lebar tombolnya. Dikecilkan seperlunya, bukan dipotong —
              // "Kel…" tidak menolong siapa pun.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.borderColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Warna label kecil di atas bidang kertas.
///
/// Kartu saldo selalu berlatar mint dan bidang ini selalu kertas terang, di
/// mode gelap maupun terang. Warna yang diwarisi tema akan jadi putih di mode
/// gelap — praktis tak terbaca di atas keduanya.
final Color _paperLabelInk = AppTheme.borderColor.withValues(alpha: 0.55);

/// Bidang kertas di dalam kartu saldo yang serba mint.
///
/// Dipakai bersama oleh ubin Masuk/Keluar dan kartu "uangmu ada di mana",
/// supaya rinciannya terbaca sebagai satu keluarga bentuk, bukan tiga kotak
/// yang kebetulan bertetangga.
class _PaperPanel extends StatelessWidget {
  const _PaperPanel({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.neoPaper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor, width: 2),
      ),
      child: child,
    );
  }
}

/// Satu ubin angka: label kecil di atas, nominalnya di bawah.
///
/// Nominalnya rata kiri di bawah labelnya, bukan didorong ke kanan. Dua ubin
/// bersebelahan dengan angka yang sama-sama rata kiri bisa dibandingkan
/// sekilas; angka yang dirapatkan ke tepi masing-masing tidak.
class _AmountTile extends StatelessWidget {
  const _AmountTile({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.isHidden,
  });

  final String label;
  final double value;
  final Color valueColor;
  final bool isHidden;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _PaperPanel(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: _paperLabelInk,
            ),
          ),
          const SizedBox(height: 3),
          // Ubinnya cuma selebar setengah kartu. Saldo delapan digit dengan
          // `textScaler` 1,3 melebihi lebar itu — dikecilkan seperlunya, bukan
          // dipotong, karena angka yang terpenggal tidak ada gunanya.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedVisibilityCurrencyText(
              value: value,
              isHidden: isHidden,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: valueColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedNetBalanceText extends StatefulWidget {
  const AnimatedNetBalanceText({
    super.key,
    required this.value,
    required this.style,
  });

  final double value;
  final TextStyle? style;

  @override
  State<AnimatedNetBalanceText> createState() => _AnimatedNetBalanceTextState();
}

class _AnimatedNetBalanceTextState extends State<AnimatedNetBalanceText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant AnimatedNetBalanceText oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasNegative = oldWidget.value < 0;
    final isNegative = widget.value < 0;
    if (wasNegative != isNegative) {
      _syncPulse();
    }
  }

  void _syncPulse() {
    if (widget.value < 0) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
      return;
    }

    if (_pulseController.isAnimating) {
      _pulseController.stop();
    }
    _pulseController.animateTo(
      0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final baseColor =
            widget.style?.color ??
            Theme.of(context).textTheme.titleLarge?.color ??
            const Color(0xFF111111);
        const warningColor = AppTheme.expenseRed;

        final t = widget.value < 0 ? _pulseController.value : 0.0;
        final animatedStyle = widget.style?.copyWith(
          color: Color.lerp(baseColor, warningColor, t),
        );

        return Transform.scale(
          alignment: Alignment.centerLeft,
          scale: 1 + (0.03 * t),
          child: AnimatedCurrencyText(
            value: widget.value,
            style: animatedStyle,
          ),
        );
      },
    );
  }
}

class AnimatedCurrencyText extends StatefulWidget {
  const AnimatedCurrencyText({
    super.key,
    required this.value,
    required this.style,
    this.withSign = false,
  });

  final double value;
  final TextStyle? style;
  final bool withSign;

  @override
  State<AnimatedCurrencyText> createState() => _AnimatedCurrencyTextState();
}

class _AnimatedCurrencyTextState extends State<AnimatedCurrencyText> {
  late double _fromValue;
  late double _toValue;

  @override
  void initState() {
    super.initState();
    _fromValue = widget.value;
    _toValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant AnimatedCurrencyText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) return;
    _fromValue = _toValue;
    _toValue = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _fromValue, end: _toValue),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return Text(
          _formatRupiah(animatedValue, withSign: widget.withSign),
          style: widget.style,
        );
      },
    );
  }

  String _formatRupiah(double value, {bool withSign = false}) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    final formatted = formatter.format(value.abs());

    if (withSign) {
      return '${value >= 0 ? '+' : '-'}$formatted';
    }

    if (value < 0) {
      return '-$formatted';
    }

    return formatted;
  }
}

class AnimatedVisibilityCurrencyText extends StatelessWidget {
  const AnimatedVisibilityCurrencyText({
    super.key,
    required this.value,
    required this.style,
    this.withSign = false,
    this.isHidden = false,
    this.childBuilder,
    this.alignment = Alignment.centerLeft,
  });

  final double value;
  final TextStyle? style;
  final bool withSign;
  final bool isHidden;
  final Widget Function(TextStyle? style)? childBuilder;

  /// Ke mana angkanya merapat kalau ruangnya lebih lebar dari teksnya.
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final visibleChild =
        childBuilder?.call(style) ??
        AnimatedCurrencyText(value: value, style: style, withSign: withSign);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
      // Tata letak bawaan `AnimatedSwitcher` menumpuk anaknya di tengah, dan
      // di dalam `Expanded` yang lebar itu membuat angka saldo terlihat
      // melayang alih-alih sejajar dengan labelnya. Perataannya hanya bisa
      // diubah lewat `layoutBuilder`, bukan lewat parameter.
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: alignment,
        children: <Widget>[...previousChildren, ?currentChild],
      ),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: isHidden
          ? Text(
              'Rp ••••••',
              key: const ValueKey('currency-hidden'),
              style: style,
            )
          : KeyedSubtree(
              key: const ValueKey('currency-visible'),
              child: visibleChild,
            ),
    );
  }
}

/// Rincian "uangnya ada di mana" di dalam panel lipat kartu saldo.
///
/// Angka besar di atas kartu adalah saldo buku yang sedang dipilih, sedangkan
/// saldo lokasi dihitung dari seluruh riwayat — dua cakupan yang berbeda.
/// Karena itu daftar ini diberi judulnya sendiri dan tidak pernah diklaim
/// sebagai rincian dari angka di atasnya.
class _MoneyLocationBreakdown extends StatelessWidget {
  const _MoneyLocationBreakdown({
    required this.locations,
    required this.unassignedBalance,
    required this.isHidden,
    this.onManage,
  });

  final List<MoneyLocationSummary> locations;
  final double unassignedBalance;
  final bool isHidden;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Pemisah lama berupa garis tipis di dalam bidang mint yang sama. Sekarang
    // daftarnya punya bidang kertasnya sendiri — cakupannya memang berbeda
    // dari angka di atasnya, dan bidang terpisah mengatakan itu tanpa kata.
    return _PaperPanel(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'UANGMU ADA DI MANA',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: _paperLabelInk,
                  ),
                ),
              ),
              if (onManage != null)
                InkWell(
                  onTap: onManage,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Text(
                      'Atur',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.borderColor,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (final summary in locations)
            _MoneyLocationRow(
              icon: IconPickerUtils.getLucideIcon(summary.icon),
              label: summary.name,
              value: summary.balance,
              isHidden: isHidden,
            ),
          if (unassignedBalance != 0)
            _MoneyLocationRow(
              icon: LucideIcons.circleHelp,
              label: 'Belum ditentukan',
              value: unassignedBalance,
              isHidden: isHidden,
              // Ikonnya saja yang diberi warna penanda. Labelnya sudah
              // menyebut sendiri apa masalahnya, jadi warnanya menegaskan —
              // bukan satu-satunya cara tahu baris ini perlu dibereskan.
              iconColor: AppTheme.expenseRed,
            ),
        ],
      ),
    );
  }
}

class _MoneyLocationRow extends StatelessWidget {
  const _MoneyLocationRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isHidden,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final double value;
  final bool isHidden;

  /// Null berarti ikut tinta barisnya. Dipakai baris "belum ditentukan"
  /// untuk menandai dirinya sendiri.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppTheme.borderColor.withValues(alpha: 0.9);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor ?? color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedVisibilityCurrencyText(
            value: value,
            isHidden: isHidden,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: value < 0 ? AppTheme.expenseRed : color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
