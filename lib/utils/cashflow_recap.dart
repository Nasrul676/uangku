import '../models/book_period.dart';
import '../models/finance_transaction.dart';

/// Rekap satu buku beserta turunannya.
class BookRecap {
  const BookRecap({
    required this.book,
    required this.totalIncome,
    required this.totalExpense,
    required this.transactionCount,
    this.expenseDeltaRatio,
  });

  final BookPeriod book;
  final double totalIncome;
  final double totalExpense;
  final int transactionCount;

  /// Perubahan pengeluaran terhadap buku sebelumnya, sebagai rasio.
  /// `0.12` berarti naik 12%, `-0.24` berarti turun 24%.
  ///
  /// Null kalau tidak ada buku sebelumnya, atau buku sebelumnya nol
  /// pengeluaran (persentase perubahan dari nol tidak bermakna).
  final double? expenseDeltaRatio;

  double get net => totalIncome - totalExpense;

  /// Porsi pemasukan yang terpakai. Lebih dari 1 berarti belanja melebihi
  /// pemasukan periode itu. Null kalau belum ada pemasukan sama sekali —
  /// membaginya dengan nol tidak menghasilkan apa pun yang berguna.
  double? get spentRatio {
    if (totalIncome <= 0) return null;
    return totalExpense / totalIncome;
  }

  bool get isOverspending {
    final ratio = spentRatio;
    return ratio != null && ratio > 1;
  }
}

/// Ringkasan seluruh buku — isi blok teratas tab Laporan.
class CashflowRecap {
  const CashflowRecap({
    required this.books,
    required this.totalIncome,
    required this.totalExpense,
  });

  final List<BookRecap> books;
  final double totalIncome;
  final double totalExpense;

  double get net => totalIncome - totalExpense;
  bool get isEmpty => books.isEmpty;

  /// Nilai bersih terbesar (absolut) di antara semua buku — dipakai untuk
  /// menskalakan tinggi batang pada deret periode.
  double get maxAbsoluteNet {
    var max = 0.0;
    for (final recap in books) {
      final value = recap.net.abs();
      if (value > max) max = value;
    }
    return max;
  }
}

/// Menyusun rekap untuk seluruh buku.
///
/// [books] diharapkan sudah terurut dari yang terbaru ke terlama, sesuai
/// keluaran `getAllBookPeriods()`. Delta dihitung terhadap elemen berikutnya
/// dalam urutan itu, yaitu periode yang lebih lama.
CashflowRecap buildCashflowRecap(
  List<BookPeriod> books,
  List<FinanceTransaction> transactions,
) {
  final incomeByBook = <int, double>{};
  final expenseByBook = <int, double>{};
  final countByBook = <int, int>{};

  var grandIncome = 0.0;
  var grandExpense = 0.0;

  for (final tx in transactions) {
    final bookId = tx.bookPeriodId;
    if (bookId == null) continue;

    countByBook[bookId] = (countByBook[bookId] ?? 0) + 1;
    if (tx.type == 'INCOME') {
      incomeByBook[bookId] = (incomeByBook[bookId] ?? 0) + tx.amount;
      grandIncome += tx.amount;
    } else if (tx.type == 'EXPENSE') {
      expenseByBook[bookId] = (expenseByBook[bookId] ?? 0) + tx.amount;
      grandExpense += tx.amount;
    }
  }

  final recaps = <BookRecap>[];
  for (var i = 0; i < books.length; i++) {
    final book = books[i];
    final id = book.id;
    final expense = id == null ? 0.0 : (expenseByBook[id] ?? 0);

    // Buku berikutnya dalam daftar adalah periode yang lebih lama.
    double? delta;
    if (i + 1 < books.length) {
      final previousId = books[i + 1].id;
      final previousExpense = previousId == null
          ? 0.0
          : (expenseByBook[previousId] ?? 0);
      if (previousExpense > 0) {
        delta = (expense - previousExpense) / previousExpense;
      }
    }

    recaps.add(
      BookRecap(
        book: book,
        totalIncome: id == null ? 0 : (incomeByBook[id] ?? 0),
        totalExpense: expense,
        transactionCount: id == null ? 0 : (countByBook[id] ?? 0),
        expenseDeltaRatio: delta,
      ),
    );
  }

  return CashflowRecap(
    books: recaps,
    totalIncome: grandIncome,
    totalExpense: grandExpense,
  );
}

/// Satu baris pada rincian pengeluaran per kategori.
class CategorySlice {
  const CategorySlice({
    required this.label,
    required this.amount,
    required this.share,
    this.collapsedCount = 0,
  });

  final String label;
  final double amount;

  /// Porsi terhadap total pengeluaran, 0..1.
  final double share;

  /// Berapa kategori yang dilipat ke dalam baris ini. Nol untuk kategori biasa.
  final int collapsedCount;

  bool get isOther => collapsedCount > 0;
}

/// Memecah pengeluaran per kategori, terurut dari yang terbesar.
///
/// Kategori di luar [topN] teratas digabung jadi satu baris "Lainnya" yang
/// menyebutkan berapa kategori yang dilipat — tanpa itu, barisnya
/// menyembunyikan jumlah yang tidak diketahui pembaca.
List<CategorySlice> buildCategoryBreakdown(
  List<FinanceTransaction> transactions, {
  int topN = 5,
}) {
  final byCategory = <String, double>{};
  var total = 0.0;

  for (final tx in transactions) {
    if (tx.type != 'EXPENSE') continue;
    byCategory[tx.category] = (byCategory[tx.category] ?? 0) + tx.amount;
    total += tx.amount;
  }

  if (total <= 0) return const [];

  final sorted = byCategory.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final slices = <CategorySlice>[];
  for (final entry in sorted.take(topN)) {
    slices.add(
      CategorySlice(
        label: entry.key,
        amount: entry.value,
        share: entry.value / total,
      ),
    );
  }

  final rest = sorted.skip(topN).toList();
  if (rest.isNotEmpty) {
    final restTotal = rest.fold<double>(0, (sum, e) => sum + e.value);
    slices.add(
      CategorySlice(
        label: 'Lainnya',
        amount: restTotal,
        share: restTotal / total,
        collapsedCount: rest.length,
      ),
    );
  }

  return slices;
}
