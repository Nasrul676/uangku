import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/book_period.dart';
import '../models/finance_transaction.dart';
import '../theme/app_theme.dart';
import '../utils/rupiah_compact.dart';
import '../utils/transaction_calendar.dart';
import 'app_card.dart';
import 'custom_bottom_sheet.dart';
import 'dashboard/dashboard_buttons.dart';
import 'dashboard/transactions_card.dart';

final _fullAmount = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

/// Kalender transaksi satu bulan.
///
/// Menjawab pertanyaan yang tidak dijawab panel mana pun: *kapan*. Pola uang
/// hampir selalu punya bentuk mingguan — belanja ramai di akhir pekan, uang
/// masuk menumpuk di tanggal gajian. Bentuk itu cuma terlihat kalau harinya
/// disusun sebagai kalender, bukan sebagai daftar.
///
/// Nominal di dalam sel ditulis ringkas ("125rb"), karena "Rp 125.000" tidak
/// muat di kotak selebar sepertujuh layar. Angka penuhnya muncul di baris
/// bawah begitu tanggalnya diketuk.
class TransactionCalendarPanel extends StatefulWidget {
  const TransactionCalendarPanel({
    super.key,
    required this.book,
    required this.transactions,
    required this.today,
    this.moneyLocationNames = const {},
  });

  final BookPeriod book;

  /// Sudah disaring ke buku yang bersangkutan oleh pemanggil.
  final List<FinanceTransaction> transactions;

  /// Disuntikkan supaya bisa diuji tanpa menunggu jam dinding berubah.
  final DateTime today;

  /// Nama lokasi per id, diteruskan ke baris transaksi di lembar rincian.
  final Map<int, String> moneyLocationNames;

  @override
  State<TransactionCalendarPanel> createState() =>
      _TransactionCalendarPanelState();
}

class _TransactionCalendarPanelState extends State<TransactionCalendarPanel> {
  CalendarRange? _range;
  late DateTime _month;
  int? _selectedDay;
  CalendarMode _mode = CalendarMode.pengeluaran;

  @override
  void initState() {
    super.initState();
    _resetToLatestMonth();
  }

  @override
  void didUpdateWidget(covariant TransactionCalendarPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.book.id != widget.book.id) _resetToLatestMonth();
  }

  void _resetToLatestMonth() {
    final range = calendarRangeFor(widget.book, today: widget.today);
    _range = range;
    // Bulan terakhir, bukan bulan pertama: yang dicari orang saat membuka
    // laporan hampir selalu catatan terbarunya.
    _month =
        range?.lastMonth ?? DateTime(widget.today.year, widget.today.month);
    _selectedDay = null;
  }

  void _stepMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _selectedDay = null;
    });
  }

  /// Membuka daftar transaksi satu tanggal.
  ///
  /// Lembar bawah, bukan layar baru: pengguna sedang membaca pola sebulan, dan
  /// menariknya keluar ke halaman lain memutus alur itu untuk pertanyaan yang
  /// jawabannya cuma beberapa baris.
  Future<void> _openDaySheet(DateTime date) async {
    final items = transactionsOnDate(date, widget.transactions, mode: _mode);
    if (items.isEmpty) return;

    await showCustomBottomSheet<void>(
      context: context,
      title: DateFormat('EEEE, d MMMM yyyy', 'id').format(date),
      child: _DaySheetBody(
        items: items,
        mode: _mode,
        moneyLocationNames: widget.moneyLocationNames,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final range = _range;

    // Tanggal mulai buku tidak terbaca. Tidak ada kisi yang bisa digambar dari
    // itu, dan kalender kosong tanpa penjelasan lebih membingungkan daripada
    // tidak ada kalender sama sekali.
    if (range == null) return const SizedBox.shrink();

    final month = buildCalendarMonth(
      month: _month,
      transactions: widget.transactions,
    );

    return AppCard(
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MonthBar(
            month: _month,
            canGoBack: range.hasMonthBefore(_month),
            canGoForward: range.hasMonthAfter(_month),
            onBack: () => _stepMonth(-1),
            onForward: () => _stepMonth(1),
          ),
          const SizedBox(height: 10),
          _ModeFilter(
            mode: _mode,
            // Pilihan tanggal ikut dilepas: satu tanggal bisa ramai belanja
            // tapi kosong pemasukan, dan rincian yang tertinggal dari filter
            // sebelumnya akan menyebut angka yang tidak ada di kisinya lagi.
            onChanged: (mode) => setState(() {
              _mode = mode;
              _selectedDay = null;
            }),
          ),
          const SizedBox(height: 12),
          const _WeekdayStrip(),
          const SizedBox(height: 4),
          _MonthGrid(
            month: month,
            mode: _mode,
            range: range,
            today: widget.today,
            selectedDay: _selectedDay,
            onSelect: (day) =>
                setState(() => _selectedDay = _selectedDay == day ? null : day),
          ),
          const SizedBox(height: 10),
          Divider(
            height: 1,
            thickness: 1,
            color: theme.dividerColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 10),
          _Footnote(
            month: month,
            mode: _mode,
            selectedDay: _selectedDay,
            onClearSelection: () => setState(() => _selectedDay = null),
            onOpenDay: _openDaySheet,
          ),
        ],
      ),
    );
  }
}

/// Nama, warna, dan kata bantu untuk tiap mode — supaya ketiganya tidak
/// tersebar sebagai `switch` yang diulang di lima tempat.
class _ModeStyle {
  const _ModeStyle({
    required this.label,
    required this.tint,
    required this.chip,
    required this.ink,
    required this.emptyText,
    required this.totalPrefix,
    required this.peakPrefix,
  });

  final String label;

  /// Warna isian sel.
  final Color tint;

  /// Warna latar tombol filter saat terpilih.
  final Color chip;

  /// Warna tulisan tombol filter saat terpilih.
  final Color ink;

  final String emptyText;
  final String totalPrefix;
  final String peakPrefix;
}

_ModeStyle _styleFor(CalendarMode mode) {
  switch (mode) {
    case CalendarMode.pengeluaran:
      return const _ModeStyle(
        label: 'Pengeluaran',
        tint: AppTheme.expenseRed,
        chip: AppTheme.expenseLight,
        ink: AppTheme.expenseRed,
        emptyText: 'Belum ada pengeluaran tercatat di bulan ini.',
        totalPrefix: 'Total keluar bulan ini',
        peakPrefix: 'Paling boros',
      );
    case CalendarMode.pemasukan:
      return const _ModeStyle(
        label: 'Pemasukan',
        tint: AppTheme.incomeGreen,
        chip: AppTheme.incomeLight,
        ink: AppTheme.incomeGreen,
        emptyText: 'Belum ada pemasukan tercatat di bulan ini.',
        totalPrefix: 'Total masuk bulan ini',
        peakPrefix: 'Paling besar',
      );
    case CalendarMode.net:
      return const _ModeStyle(
        label: 'Net',
        // Di mode net warnanya ditentukan tanda angkanya per hari, bukan oleh
        // modenya. Nilai ini cuma jadi cadangan yang praktis tak terpakai.
        tint: AppTheme.incomeGreen,
        chip: AppTheme.neoBlue,
        ink: AppTheme.borderColor,
        emptyText: 'Belum ada catatan di bulan ini.',
        totalPrefix: 'Selisih bulan ini',
        peakPrefix: 'Selisih terbesar',
      );
  }
}

/// Warna isian satu sel — di mode net ditentukan tanda angkanya.
Color _tintFor(CalendarMode mode, double value) {
  if (mode != CalendarMode.net) return _styleFor(mode).tint;
  if (value > 0) return AppTheme.incomeGreen;
  if (value < 0) return AppTheme.expenseRed;
  return Colors.transparent;
}

/// Nominal ringkas untuk di dalam sel.
///
/// Mode net memberi tanda `+` pada yang positif. Tanpa itu "125rb" di kolom
/// net tidak bisa dibedakan dari "-125rb" selain lewat warna — dan warna saja
/// tidak cukup untuk menyampaikan arti.
String _cellText(CalendarMode mode, double value) {
  final text = compactRupiah(value, withPrefix: false);
  if (mode == CalendarMode.net && value > 0) return '+$text';
  return text;
}

class _ModeFilter extends StatelessWidget {
  const _ModeFilter({required this.mode, required this.onChanged});

  final CalendarMode mode;
  final ValueChanged<CalendarMode> onChanged;

  @override
  Widget build(BuildContext context) {
    // `Wrap`, bukan `Row`: di layar 320px dengan huruf terbesar ketiga label
    // ini melebihi lebar kartunya. Turun ke baris kedua jauh lebih baik
    // daripada dikecilkan sampai tak terbaca atau digulung ke samping sampai
    // salah satunya tersembunyi.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in CalendarMode.values)
          Semantics(
            button: true,
            selected: option == mode,
            child: FilterButton(
              label: _styleFor(option).label,
              selected: option == mode,
              selectedColor: _styleFor(option).chip,
              textColor: _styleFor(option).ink,
              onTap: () => onChanged(option),
            ),
          ),
      ],
    );
  }
}

/// Judul panel sekaligus penggeser bulan.
class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.month,
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
  });

  final DateTime month;
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'KALENDER TRANSAKSI',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.hintColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                DateFormat('MMMM yyyy', 'id').format(month),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        // Tombolnya dimatikan, bukan disembunyikan: kontrol yang muncul dan
        // hilang membuat tata letaknya bergeser tiap ganti bulan.
        IconButton(
          tooltip: 'Bulan sebelumnya',
          visualDensity: VisualDensity.compact,
          onPressed: canGoBack ? onBack : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        IconButton(
          tooltip: 'Bulan berikutnya',
          visualDensity: VisualDensity.compact,
          onPressed: canGoForward ? onForward : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _WeekdayStrip extends StatelessWidget {
  const _WeekdayStrip();

  /// Pekan dimulai Senin, sesuai kalender yang dipakai sehari-hari di sini.
  static const labels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ExcludeSemantics(
      // Tiap sel sudah menyebut nama harinya sendiri untuk pembaca layar.
      // Membacakan baris ini lebih dulu cuma menambah tujuh kata tanpa arti.
      child: Row(
        children: [
          for (final label in labels)
            Expanded(
              child: Center(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.hintColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.mode,
    required this.range,
    required this.today,
    required this.selectedDay,
    required this.onSelect,
  });

  final CalendarMonth month;
  final CalendarMode mode;
  final CalendarRange range;
  final DateTime today;
  final int? selectedDay;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final leading = month.leadingWeekday - 1;
    final total = leading + month.dayCount;
    final weeks = (total / 7).ceil();

    return Column(
      children: [
        for (var week = 0; week < weeks; week++)
          // Bukan `stretch`: kisinya berada di dalam daftar yang tingginya
          // tak terbatas, dan meregangkan sel ke tinggi induknya di situ
          // berarti meminta tinggi tak hingga.
          Row(
            children: [
              for (var column = 0; column < 7; column++)
                Expanded(child: _cellAt(week * 7 + column - leading)),
            ],
          ),
      ],
    );
  }

  Widget _cellAt(int day) {
    if (day < 1 || day > month.dayCount) {
      // Tinggi yang sama persis dengan sel berisi, margin ikut dihitung —
      // kalau meleset, pekan pertama dan terakhir jadi lebih pendek.
      return const SizedBox(height: _DayCell.height + _DayCell.margin * 2);
    }

    final date = DateTime(month.month.year, month.month.month, day);
    final entry = month.dayAt(day);

    return _DayCell(
      date: date,
      mode: mode,
      entry: entry != null && entry.hasDataFor(mode) ? entry : null,
      intensity: month.intensityAt(day, mode),
      isWithinBook: range.contains(date),
      isToday: _isSameDay(date, today),
      isSelected: selectedDay == day,
      onTap: () => onSelect(day),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.mode,
    required this.entry,
    required this.intensity,
    required this.isWithinBook,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  static const double height = 46;
  static const double margin = 1.5;

  final DateTime date;
  final CalendarMode mode;

  /// Null kalau tanggal ini tidak punya catatan pada mode yang sedang aktif.
  final CalendarDay? entry;

  final double intensity;
  final bool isWithinBook;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink =
        theme.textTheme.bodyMedium?.color ?? theme.colorScheme.onSurface;
    final value = entry?.amountFor(mode) ?? 0;

    // Warna tembus pandang, bukan warna padat: satu resep ini terbaca benar di
    // atas kartu terang maupun gelap, dan tintanya tetap tinta tema.
    final fill = intensity <= 0
        ? Colors.transparent
        : _tintFor(mode, value).withValues(alpha: 0.10 + 0.34 * intensity);

    final border = isSelected
        ? Border.all(color: ink, width: 2)
        : isToday
        ? Border.all(color: theme.colorScheme.primary, width: 1.5)
        : null;

    return Semantics(
      button: true,
      selected: isSelected,
      label: _semanticLabel(),
      excludeSemantics: true,
      child: InkWell(
        onTap: isWithinBook ? onTap : null,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: height,
          margin: const EdgeInsets.all(margin),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(9),
            border: border,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${date.day}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: isToday || isSelected
                      ? FontWeight.w800
                      : FontWeight.w500,
                  // Di luar rentang buku tanggalnya tetap ditulis supaya
                  // bentuk bulannya utuh, cuma diredupkan agar jelas bukan
                  // bagian dari periode ini.
                  color: isWithinBook ? ink : ink.withValues(alpha: 0.32),
                ),
              ),
              if (entry != null) ...[
                const SizedBox(height: 1),
                // Sel ini selebar sepertujuh layar. Nominal ringkas pun bisa
                // melebihinya di huruf terbesar, jadi dikecilkan seperlunya.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _cellText(mode, value),
                    maxLines: 1,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _semanticLabel() {
    final dateText = DateFormat('EEEE, d MMMM', 'id').format(date);
    if (!isWithinBook) return '$dateText, di luar periode buku';

    final data = entry;
    final style = _styleFor(mode);
    if (data == null) {
      return '$dateText, tidak ada ${style.label.toLowerCase()}';
    }

    return '$dateText, ${style.label.toLowerCase()} '
        '${_fullAmount.format(data.amountFor(mode))}, '
        '${data.countFor(mode)} transaksi';
  }
}

/// Baris di bawah kisi: rangkuman bulan, atau rincian tanggal yang diketuk.
///
/// Angkanya ditulis penuh di sini. Sel kalender memang harus ringkas, tapi
/// begitu satu tanggal dipilih pengguna berhak melihat nominal yang tepat —
/// "125rb" tidak cukup untuk mencocokkan dengan catatan.
class _Footnote extends StatelessWidget {
  const _Footnote({
    required this.month,
    required this.mode,
    required this.selectedDay,
    required this.onClearSelection,
    required this.onOpenDay,
  });

  final CalendarMonth month;
  final CalendarMode mode;
  final int? selectedDay;
  final VoidCallback onClearSelection;
  final ValueChanged<DateTime> onOpenDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = _styleFor(mode);
    final day = selectedDay;

    if (day != null) {
      final raw = month.dayAt(day);
      final entry = (raw != null && raw.hasDataFor(mode)) ? raw : null;
      final date = DateTime(month.month.year, month.month.month, day);
      final dateText = DateFormat('EEEE, d MMMM', 'id').format(date);

      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry == null
                      ? 'Tidak ada ${style.label.toLowerCase()} tercatat.'
                      : '${entry.countFor(mode)} transaksi · '
                            '${_fullAmount.format(entry.amountFor(mode))}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: entry == null ? theme.hintColor : null,
                    fontWeight: entry == null
                        ? FontWeight.w400
                        : FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (entry != null)
            TextButton(
              onPressed: () => onOpenDay(date),
              child: Text('Lihat ${entry.countFor(mode)} transaksi'),
            ),
          // Ikon, bukan tombol teks kedua: menutup pilihan adalah aksi
          // sekunder, dan dua tombol teks bersebelahan membuat keduanya
          // terlihat sama penting.
          IconButton(
            tooltip: 'Tutup pilihan tanggal',
            visualDensity: VisualDensity.compact,
            onPressed: onClearSelection,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      );
    }

    if (month.isEmptyFor(mode)) {
      return Text(
        style.emptyText,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
      );
    }

    final busiest = month.busiestDayFor(mode)!;
    final busiestDate = DateTime(
      month.month.year,
      month.month.month,
      busiest.day,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${style.totalPrefix} ${_fullAmount.format(month.totalFor(mode))}',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${style.peakPrefix} '
          '${DateFormat('d MMMM', 'id').format(busiestDate)} — '
          '${_fullAmount.format(busiest.amountFor(mode))}. '
          'Ketuk tanggal untuk rinciannya.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
      ],
    );
  }
}

/// Isi lembar rincian satu tanggal.
///
/// Tingginya dibatasi separuh layar lalu digulung: satu tanggal bisa berisi
/// dua transaksi, bisa juga dua puluh, dan lembar yang tingginya ikut isi akan
/// menutupi seluruh layar di kasus kedua.
class _DaySheetBody extends StatelessWidget {
  const _DaySheetBody({
    required this.items,
    required this.mode,
    required this.moneyLocationNames,
  });

  final List<FinanceTransaction> items;
  final CalendarMode mode;
  final Map<int, String> moneyLocationNames;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    var total = 0.0;
    for (final tx in items) {
      total += tx.type == 'INCOME' ? tx.amount : -tx.amount;
    }
    // Di mode pengeluaran totalnya ditulis sebagai angka positif — daftarnya
    // sudah jelas berisi uang keluar, dan tanda minus di situ cuma jadi
    // tanda baca yang mengganggu.
    final shown = mode == CalendarMode.net ? total : total.abs();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Total ${_fullAmount.format(shown)}',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: shown < 0
                ? AppTheme.expenseRed
                : (mode == CalendarMode.pengeluaran
                      ? AppTheme.expenseRed
                      : AppTheme.incomeGreen),
          ),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.5,
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) => TransactionTile(
              item: items[index],
              theme: theme,
              moneyLocationName:
                  moneyLocationNames[items[index].moneyLocationId],
            ),
          ),
        ),
      ],
    );
  }
}
