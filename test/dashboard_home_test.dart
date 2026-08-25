import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:uangkeluar/models/book_period.dart';
import 'package:uangkeluar/theme/app_theme.dart';
import 'package:uangkeluar/models/money_location.dart';
import 'package:uangkeluar/utils/daily_budget.dart';
import 'package:uangkeluar/utils/money_location_balance.dart';
import 'package:uangkeluar/widgets/dashboard/balance_card.dart';
import 'package:uangkeluar/widgets/dashboard/daily_allowance_card.dart';
import 'package:uangkeluar/widgets/dashboard/greeting_header.dart';
import 'package:uangkeluar/widgets/dashboard/pira_mascot.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id', null);
  });

  DailyBudget budget({
    double perDay = 171000,
    double spentToday = 109000,
    int days = 14,
    BudgetHorizon horizon = BudgetHorizon.sampaiTanggal,
  }) {
    return DailyBudget(
      balance: 2400000,
      daysRemaining: days,
      perDay: perDay,
      spentToday: spentToday,
      horizon: horizon,
      until: horizon == BudgetHorizon.sampaiTanggal
          ? DateTime(2026, 8, 31)
          : null,
    );
  }

  Future<void> pumpBalance(
    WidgetTester tester, {
    DailyBudget? withBudget,
    bool hidden = false,
    PiraMood mood = PiraMood.santai,
    List<MoneyLocationSummary> locations = const [],
    double unassignedBalance = 0,
  }) async {
    final theme = ThemeData();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: BalanceCard(
              theme: theme,
              totalIncome: 7500000,
              totalExpense: 5100000,
              netBalance: 2400000,
              isBalanceHidden: hidden,
              onToggleBalanceVisibility: () {},
              onAddIncome: () {},
              onAddExpense: () {},
              mood: mood,
              budget: withBudget,
              locations: locations,
              unassignedBalance: unassignedBalance,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  MoneyLocationSummary summary(int id, String name, double balance) =>
      MoneyLocationSummary(
        location: MoneyLocation(
          id: id,
          name: name,
          icon: 'wallet',
          createdAt: '2026-01-01T00:00:00.000',
        ),
        balance: balance,
      );

  group('rincian lokasi uang', () {
    testWidgets('tidak dirender sama sekali saat belum ada lokasi', (
      tester,
    ) async {
      await pumpBalance(tester);

      expect(find.text('UANGMU ADA DI MANA'), findsNothing);
    });

    testWidgets('menampilkan nama dan saldo tiap lokasi', (tester) async {
      await pumpBalance(
        tester,
        locations: [
          summary(1, 'Dompet', 150000),
          summary(2, 'Rekening / ATM', 2250000),
        ],
      );

      expect(find.text('UANGMU ADA DI MANA'), findsOneWidget);
      expect(find.text('Dompet'), findsOneWidget);
      expect(find.text('Rp 150.000'), findsOneWidget);
      expect(find.text('Rekening / ATM'), findsOneWidget);
      expect(find.text('Rp 2.250.000'), findsOneWidget);
    });

    testWidgets('baris "Belum ditentukan" muncul hanya kalau masih ada sisa', (
      tester,
    ) async {
      await pumpBalance(
        tester,
        locations: [summary(1, 'Dompet', 150000)],
        unassignedBalance: 90000,
      );

      expect(find.text('Belum ditentukan'), findsOneWidget);
      expect(find.text('Rp 90.000'), findsOneWidget);
    });

    testWidgets('baris "Belum ditentukan" disembunyikan saat nol', (
      tester,
    ) async {
      await pumpBalance(tester, locations: [summary(1, 'Dompet', 150000)]);

      expect(find.text('Belum ditentukan'), findsNothing);
    });

    testWidgets('angka lokasi ikut tersembunyi saat saldo disembunyikan', (
      tester,
    ) async {
      await pumpBalance(
        tester,
        hidden: true,
        locations: [summary(1, 'Dompet', 150000)],
      );

      expect(find.text('Dompet'), findsOneWidget);
      expect(find.text('Rp 150.000'), findsNothing);
    });

    testWidgets('rincian lokasi sudah terbuka tanpa perlu diketuk', (
      tester,
    ) async {
      await pumpBalance(tester, locations: [summary(1, 'Dompet', 150000)]);

      expect(find.text('UANGMU ADA DI MANA'), findsOneWidget);
      expect(find.text('Dompet'), findsOneWidget);
    });
  });

  group('kartu saldo tidak luber', () {
    /// Aplikasi membatasi `textScaler` sampai 1,3 di `main.dart`, jadi
    /// kombinasi layar sempit + huruf terbesar adalah keadaan yang benar-benar
    /// bisa dialami pengguna — bukan kasus karangan.
    testWidgets('muat di layar sempit dengan huruf terbesar', (tester) async {
      final theme = ThemeData();

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 320,
                  child: BalanceCard(
                    theme: theme,
                    totalIncome: 128500000,
                    totalExpense: 99000000,
                    netBalance: 128500000,
                    isBalanceHidden: false,
                    onToggleBalanceVisibility: () {},
                    onAddIncome: () {},
                    onAddExpense: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('kontras kartu saldo', () {
    /// Kartu saldo selalu berlatar mint, terang di mode gelap maupun terang.
    /// Teks yang mewarisi warna tema akan jadi putih di mode gelap — 1.35:1
    /// di atas mint, praktis tak terbaca. Warnanya harus ditetapkan sendiri.
    testWidgets('Total Pemasukan memakai tinta gelap, bukan warna tema', (
      tester,
    ) async {
      await pumpBalance(tester);

      final label = tester.widget<Text>(find.text('Total Pemasukan'));
      expect(label.style?.color, AppTheme.borderColor);
    });

    testWidgets('warnanya tetap sama saat tema gelap dipakai', (tester) async {
      final darkTheme = ThemeData.dark();
      await tester.pumpWidget(
        MaterialApp(
          theme: darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: BalanceCard(
                theme: darkTheme,
                totalIncome: 7500000,
                totalExpense: 5100000,
                netBalance: 2400000,
                isBalanceHidden: false,
                onToggleBalanceVisibility: () {},
                onAddIncome: () {},
                onAddExpense: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final label = tester.widget<Text>(find.text('Total Pemasukan'));
      expect(label.style?.color, AppTheme.borderColor);
      expect(label.style?.color, isNot(darkTheme.textTheme.bodySmall?.color));
    });
  });

  group('kartu saldo', () {
    testWidgets('menampilkan satu angka besar, bukan enam', (tester) async {
      await pumpBalance(tester);

      expect(find.text('Rp 2.400.000'), findsOneWidget);
      // "Selisih" nilainya persis sama dengan saldo — barisnya sudah dibuang.
      expect(find.text('Selisih'), findsNothing);
    });

    testWidgets('rincian terbuka sejak beranda dibuka', (tester) async {
      await pumpBalance(tester);

      expect(find.text('Total Pemasukan'), findsOneWidget);
      expect(find.text('Total Pengeluaran'), findsOneWidget);
      expect(find.text('Sembunyikan rincian'), findsOneWidget);
    });

    testWidgets('masih bisa dilipat sendiri kalau mau beranda ringkas', (
      tester,
    ) async {
      await pumpBalance(tester);

      await tester.tap(find.text('Sembunyikan rincian'));
      await tester.pumpAndSettle();

      expect(find.text('Total Pemasukan'), findsNothing);
      expect(find.text('Lihat rincian'), findsOneWidget);
    });

    testWidgets('kalimat penjelas ikut tampil kalau jatahnya bisa dihitung', (
      tester,
    ) async {
      await pumpBalance(tester, withBudget: budget());

      expect(find.textContaining('Cukup sampai 31 Agu'), findsOneWidget);
      expect(find.textContaining('jatah Rp 171rb per hari'), findsOneWidget);
    });

    testWidgets('nada kalimat berbeda saat cuma perkiraan', (tester) async {
      await pumpBalance(
        tester,
        withBudget: budget(horizon: BudgetHorizon.perkiraan),
      );

      // Perkiraan tidak boleh dijual sebagai kepastian.
      expect(find.textContaining('kira-kira'), findsOneWidget);
      expect(find.textContaining('Cukup sampai'), findsNothing);
    });

    testWidgets('menyembunyikan saldo juga menyembunyikan kalimatnya', (
      tester,
    ) async {
      await pumpBalance(tester, withBudget: budget(), hidden: true);

      // Kalimatnya menyebut nominal jatah harian, jadi percuma menutup saldo
      // kalau angkanya tetap bocor lewat sini.
      expect(find.textContaining('Rp 171rb'), findsNothing);
      expect(find.textContaining('Cukup sampai'), findsNothing);
    });

    testWidgets('PiRa duduk di dalam kartu pesan, bukan di sebelah saldo', (
      tester,
    ) async {
      await pumpBalance(tester, withBudget: budget());

      // Bingkai terdekat yang membungkus maskot adalah kartu pesan itu
      // sendiri — kalimatnya harus ada di dalam bingkai yang sama, bukan
      // sekadar bertetangga di kolom kartu saldo.
      final messageCard = find
          .ancestor(
            of: find.byType(PiraMascot),
            matching: find.byType(Container),
          )
          .first;

      expect(
        find.descendant(
          of: messageCard,
          matching: find.textContaining('Cukup sampai 31 Agu'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('kartu pesan tetap ada walau jatahnya belum bisa dihitung', (
      tester,
    ) async {
      // Tanpa budget dulu kartunya hilang sama sekali. Sekarang PiRa tinggal
      // di dalamnya, jadi yang berganti cuma kalimatnya.
      await pumpBalance(tester, mood: PiraMood.hatiHati);

      expect(find.byType(PiraMascot), findsOneWidget);
      expect(
        find.text(greetingForMood(PiraMood.hatiHati)),
        findsOneWidget,
      );
    });

    testWidgets('maskot tidak ikut hilang saat saldo disembunyikan', (
      tester,
    ) async {
      await pumpBalance(tester, withBudget: budget(), hidden: true);

      expect(find.byType(PiraMascot), findsOneWidget);
      expect(find.text(greetingForMood(PiraMood.santai)), findsOneWidget);
    });

    testWidgets('dua tombol aksi utama tersedia', (tester) async {
      var income = 0;
      var expense = 0;
      final theme = ThemeData();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BalanceCard(
              theme: theme,
              totalIncome: 0,
              totalExpense: 0,
              netBalance: 0,
              isBalanceHidden: false,
              onToggleBalanceVisibility: () {},
              onAddIncome: () => income++,
              onAddExpense: () => expense++,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Masuk'));
      await tester.tap(find.text('Keluar'));
      await tester.pump();

      expect(income, 1);
      expect(expense, 1);
    });
  });

  group('kartu jatah harian', () {
    Future<void> pumpAllowance(WidgetTester tester, DailyBudget value) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DailyAllowanceCard(budget: value)),
        ),
      );
      await tester.pump();
    }

    testWidgets('menyebut sisa jatah hari ini', (tester) async {
      await pumpAllowance(tester, budget());

      expect(find.text('Jatah hari ini'), findsOneWidget);
      expect(find.text('Rp 62rb tersisa'), findsOneWidget);
      expect(find.text('Terpakai Rp 109rb'), findsOneWidget);
    });

    testWidgets('lewat batas disebut angkanya, bukan disembunyikan', (
      tester,
    ) async {
      await pumpAllowance(tester, budget(spentToday: 195000));

      expect(find.text('lewat Rp 24rb'), findsOneWidget);
    });

    testWidgets('mode perkiraan tidak berpura-pura punya batas', (
      tester,
    ) async {
      await pumpAllowance(tester, budget(horizon: BudgetHorizon.perkiraan));

      expect(find.text('Rata-rata harianmu'), findsOneWidget);
      expect(find.text('Jatah hari ini'), findsNothing);
    });

    testWidgets('belum belanja hari ini tidak bikin error', (tester) async {
      await pumpAllowance(tester, budget(spentToday: 0));

      expect(find.text('Terpakai Rp 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('sapaan', () {
    test('mengikuti waktu setempat', () {
      expect(greetingFor(DateTime(2026, 8, 17, 7)), 'Selamat pagi');
      expect(greetingFor(DateTime(2026, 8, 17, 13)), 'Selamat siang');
      expect(greetingFor(DateTime(2026, 8, 17, 17)), 'Selamat sore');
      expect(greetingFor(DateTime(2026, 8, 17, 21)), 'Selamat malam');
    });

    testWidgets('menyebut buku yang sedang aktif', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GreetingHeader(
              now: DateTime(2026, 8, 17, 8),
              activeBook: const BookPeriod(
                id: 1,
                label: 'Agustus 2026',
                startDate: '2026-08-01',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Senin, 17 Agustus'), findsOneWidget);
      // Sebelumnya beranda tidak menyebut angkanya milik periode yang mana.
      expect(find.text('Agustus 2026'), findsOneWidget);
      expect(find.text(' · aktif'), findsOneWidget);

      // Sapaannya ada di bar atas layar, yang sudah menyebut nama pengguna.
      // Mengulangnya di sini membuat dua sapaan bertumpuk.
      expect(find.textContaining('Selamat'), findsNothing);
    });

    testWidgets('tanpa buku aktif, chipnya tidak dipaksakan muncul', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GreetingHeader(now: DateTime(2026, 8, 17, 8))),
        ),
      );
      await tester.pump();

      expect(find.text('Senin, 17 Agustus'), findsOneWidget);
      expect(find.textContaining('aktif'), findsNothing);
    });
  });

  group('mode gelap', () {
    testWidgets('garis batang jatah harian ikut tinta tema, bukan hitam mati', (
      tester,
    ) async {
      final dark = ThemeData(brightness: Brightness.dark);

      await tester.pumpWidget(
        MaterialApp(
          theme: dark,
          home: Scaffold(body: DailyAllowanceCard(budget: budget())),
        ),
      );
      await tester.pump();

      // Cari bingkai batang: tinggi 15 dengan border.
      final decorated = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) {
            final decoration = c.decoration;
            return decoration is BoxDecoration && decoration.border != null;
          })
          .map((c) => c.decoration as BoxDecoration)
          .toList();

      expect(decorated, isNotEmpty);
      for (final decoration in decorated) {
        final side = (decoration.border as Border).top;
        // Hitam mati di atas kartu gelap membuat batangnya hilang sama sekali.
        expect(
          side.color,
          isNot(AppTheme.borderColor),
          reason: 'garis hitam mati tak terlihat di mode gelap',
        );
      }
    });
  });

  group('maskot PiRa', () {
    testWidgets('tetap punya label untuk pembaca layar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PiraMascot(mood: PiraMood.lewatBatas)),
        ),
      );
      await tester.pump();

      expect(
        find.bySemanticsLabel('PiRa tetap kalem walau baknya sudah kering'),
        findsOneWidget,
      );
    });

    testWidgets('tiap suasana punya labelnya sendiri', (tester) async {
      const labels = {
        PiraMood.santai: 'PiRa berendam santai, airnya masih penuh',
        PiraMood.hatiHati: 'PiRa mulai waspada, air di baknya menyusut',
        PiraMood.lewatBatas: 'PiRa tetap kalem walau baknya sudah kering',
      };

      for (final entry in labels.entries) {
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: PiraMascot(mood: entry.key))),
        );
        await tester.pump();
        expect(
          find.bySemanticsLabel(entry.value),
          findsOneWidget,
          reason: entry.key.name,
        );
      }
    });

    testWidgets('memuat gambar yang berbeda untuk tiap suasana', (
      tester,
    ) async {
      for (final mood in PiraMood.values) {
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: PiraMascot(mood: mood))),
        );
        // Saat suasananya berganti, `AnimatedSwitcher` sempat menahan gambar
        // lama dan baru sekaligus — tunggu transisinya rampung dulu.
        await tester.pumpAndSettle();

        // `cacheWidth` membungkus penyedia gambarnya dengan `ResizeImage`,
        // jadi nama asetnya ada satu lapis di dalam.
        final image = tester.widget<Image>(find.byType(Image));
        final resized = image.image as ResizeImage;
        expect(
          (resized.imageProvider as AssetImage).assetName,
          assetForMood(mood),
        );
      }
    });

    testWidgets('mencolek PiRa memanggil onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PiraMascot(
              mood: PiraMood.santai,
              onTap: () => taps++,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(PiraMascot));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('tiap suasana punya sapaan sendiri', (tester) async {
      final greetings = PiraMood.values.map(greetingForMood).toSet();

      expect(greetings, hasLength(PiraMood.values.length));
      for (final text in greetings) {
        expect(text.trim(), isNotEmpty);
      }
    });

    /// Sebagian orang benar-benar mual oleh gerakan, dan kedua sistem operasi
    /// menyediakan setelannya. Sapaannya tetap muncul, cuma goyangannya yang
    /// dilewati — interaksinya tidak ikut dimatikan.
    testWidgets('gerakan dilewati saat pengguna mematikan animasi', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: PiraMascot(
                mood: PiraMood.santai,
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(PiraMascot));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });

    /// PiRa hanya bergerak di saat yang berarti. Kalau ada animasi yang
    /// berputar terus, `pumpAndSettle` tidak akan pernah selesai — dan setiap
    /// test yang menyentuh kartu saldo ikut menggantung.
    testWidgets('tidak ada animasi yang berputar tanpa henti', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PiraMascot(mood: PiraMood.santai)),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(PiraMascot), findsOneWidget);
    });

    testWidgets('digambar tanpa melempar exception di ketiga suasana', (
      tester,
    ) async {
      for (final mood in PiraMood.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: PiraMascot(mood: mood)),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: mood.name);
      }
    });
  });
}
