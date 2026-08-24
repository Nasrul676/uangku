/// Lokasi penyimpanan uang — tempat nyata uang berada (dompet, rekening,
/// e-wallet, celengan).
///
/// Berbeda dari [Pocket]: kantong adalah *jatah anggaran* untuk satu periode
/// buku dan ikut hilang saat buku ditutup. Lokasi uang adalah *posisi kas*
/// yang lintas periode — uang di dompet tidak berubah cuma karena bukunya
/// ganti. Karena itu lokasi tidak terikat `book_period_id`.
///
/// [initialBalance] menampung uang yang sudah ada sebelum pengguna memakai
/// fitur ini, jadi saldo pertama tidak harus dimulai dari nol.
class MoneyLocation {
  const MoneyLocation({
    this.id,
    required this.name,
    required this.icon,
    this.initialBalance = 0,
    this.sortOrder = 0,
    this.isArchived = 0,
    required this.createdAt,
  });

  final int? id;
  final String name;
  final String icon;
  final double initialBalance;
  final int sortOrder;
  final int isArchived;
  final String createdAt;

  bool get archived => isArchived == 1;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'initial_balance': initialBalance,
      'sort_order': sortOrder,
      'is_archived': isArchived,
      'created_at': createdAt,
    };
  }

  factory MoneyLocation.fromMap(Map<String, dynamic> map) {
    return MoneyLocation(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      icon: map['icon'] as String? ?? 'wallet',
      initialBalance: (map['initial_balance'] as num?)?.toDouble() ?? 0,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      isArchived: (map['is_archived'] as num?)?.toInt() ?? 0,
      createdAt: map['created_at'] as String? ?? '',
    );
  }

  MoneyLocation copyWith({
    int? id,
    String? name,
    String? icon,
    double? initialBalance,
    int? sortOrder,
    int? isArchived,
    String? createdAt,
  }) {
    return MoneyLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      initialBalance: initialBalance ?? this.initialBalance,
      sortOrder: sortOrder ?? this.sortOrder,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
