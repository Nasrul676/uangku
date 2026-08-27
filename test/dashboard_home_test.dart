import 'dart:math' as math;

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
import 'package:uangkeluar/widgets/dashboard/dashboard_buttons.dart';
import 'package:uangkeluar/widgets/entrance_animation.dart';
import 'package:uangkeluar/widgets/dashboard/dashboard_header_bar.dart';
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
    Widget? header,
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
              header: header,
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
    /// Kartu saldo selalu berlatar mint dan ubin rinciannya selalu kertas
    /// terang, di mode gelap maupun terang. Teks yang mewarisi warna tema akan
    /// jadi putih di atas keduanya — praktis tak terbaca.
    testWidgets('label rincian memakai tinta gelap, bukan warna tema', (
      tester,
    ) async {
      await pumpBalance(tester);

      final label = tester.widget<Text>(find.text('MASUK'));
      expect(label.style?.color, AppTheme.borderColor.withValues(alpha: 0.55));
    });

    testWidgets('nominalnya dibedakan hijau dan merah', (tester) async {
      await pumpBalance(tester);

      // Arah uangnya tidak hanya dibedakan posisi ubin: warnanya ikut
      // menyebut, dan labelnya menyebut lagi dengan kata.
      final income = tester.widget<Text>(find.text('Rp 7.500.000'));
      final expense = tester.widget<Text>(find.text('Rp 5.100.000'));
      expect(income.style?.color, AppTheme.incomeGreen);
      expect(expense.style?.color, AppTheme.expenseRed);
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

      final label = tester.widget<Text>(find.text('MASUK'));
      expect(label.style?.color, AppTheme.borderColor.withValues(alpha: 0.55));
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

      expect(find.text('MASUK'), findsOneWidget);
      expect(find.text('KELUAR'), findsOneWidget);
      expect(find.text('Sembunyikan rincian'), findsOneWidget);
    });

    testWidgets('masih bisa dilipat sendiri kalau mau beranda ringkas', (
      tester,
    ) async {
      await pumpBalance(tester);

      await tester.tap(find.text('Sembunyikan rincian'));
      // Bukan `pumpAndSettle`: gerakan menganggur PiRa berputar terus, jadi
      // pohonnya tidak pernah benar-benar diam. Yang ditunggu cuma lipatannya.
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('MASUK'), findsNothing);
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

    testWidgets('PiRa duduk di ujung kanan, kalimatnya di kiri', (
      tester,
    ) async {
      await pumpBalance(tester, withBudget: budget());

      final mascot = tester.getCenter(find.byType(PiraMascot));
      final message = tester.getCenter(
        find.textContaining('Cukup sampai 31 Agu'),
      );

      // Kalimatnya jadi rata dengan teks lain di kartu; maskot di kiri dulu
      // mendorongnya masuk sendirian dan memutus garis bacanya.
      expect(mascot.dx, greaterThan(message.dx));
    });

    testWidgets('kartu pesan tetap ada walau jatahnya belum bisa dihitung', (
      tester,
    ) async {
      // Tanpa budget dulu kartunya hilang sama sekali. Sekarang PiRa tinggal
      // di dalamnya, jadi yang berganti cuma kalimatnya.
      await pumpBalance(tester, mood: PiraMood.hatiHati);

      expect(find.byType(PiraMascot), findsOneWidget);
      expect(find.text(greetingForMood(PiraMood.hatiHati)), findsOneWidget);
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

  group('tata letak rincian', () {
    testWidgets('Masuk dan Keluar berdampingan, bukan bertumpuk', (
      tester,
    ) async {
      await pumpBalance(tester);

      final masuk = tester.getCenter(find.text('MASUK'));
      final keluar = tester.getCenter(find.text('KELUAR'));

      expect(masuk.dy, keluar.dy);
      expect(masuk.dx, lessThan(keluar.dx));
    });

    testWidgets('daftar lokasi turun ke bidangnya sendiri di bawah', (
      tester,
    ) async {
      await pumpBalance(tester, locations: [summary(1, 'Dompet', 150000)]);

      final masuk = tester.getCenter(find.text('MASUK'));
      final lokasi = tester.getCenter(find.text('UANGMU ADA DI MANA'));

      expect(lokasi.dy, greaterThan(masuk.dy));
    });

    testWidgets('rincian lengkap muat di layar sempit dengan huruf terbesar', (
      tester,
    ) async {
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
                    netBalance: 29500000,
                    isBalanceHidden: false,
                    onToggleBalanceVisibility: () {},
                    onAddIncome: () {},
                    onAddExpense: () {},
                    locations: [
                      summary(1, 'Rekening Bersama Keluarga', 2250000),
                    ],
                    unassignedBalance: 78921,
                    onManageLocations: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Dua ubin berdampingan masing-masing cuma selebar setengah kartu —
      // keadaan paling sempit yang benar-benar bisa dialami pengguna.
      expect(tester.takeException(), isNull);
    });
  });

  group('kartu saldo menempel ke tepi layar', () {
    testWidgets('lebarnya persis selebar layar', (tester) async {
      await pumpBalance(tester);

      // Kartu ini menyambung dengan bar hijau di atasnya. Sisa margin
      // sedikit pun memunculkan pita abu di kiri-kanan yang memutus hijaunya.
      expect(
        tester.getSize(find.byType(BalanceCard)).width,
        tester.getSize(find.byType(Scaffold)).width,
      );
    });

    testWidgets('slot header dirender di dalam kartu', (tester) async {
      await pumpBalance(tester, header: const Text('tanggal dan buku aktif'));

      expect(
        find.descendant(
          of: find.byType(BalanceCard),
          matching: find.text('tanggal dan buku aktif'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tanpa slot header, tidak ada ruang kosong dipaksakan', (
      tester,
    ) async {
      await pumpBalance(tester);

      expect(find.byType(BalanceCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('baris tanggal di atas mint', () {
    testWidgets('memakai tinta gelap, bukan warna tema', (tester) async {
      final darkTheme = ThemeData.dark();

      await tester.pumpWidget(
        MaterialApp(
          theme: darkTheme,
          home: Scaffold(
            body: GreetingHeader(
              now: DateTime(2026, 8, 17, 8),
              activeBook: const BookPeriod(
                id: 1,
                label: 'Agustus 2026',
                startDate: '2026-08-01',
              ),
              inkColor: AppTheme.borderColor,
            ),
          ),
        ),
      );
      await tester.pump();

      // Mint selalu terang. Tinta tema mode gelap di atasnya praktis hilang.
      final date = tester.widget<Text>(find.text('Senin, 17 Agustus'));
      expect(date.style?.color, isNot(darkTheme.hintColor));

      final label = tester.widget<Text>(find.text('Agustus 2026'));
      expect(label.style?.color, AppTheme.borderColor);
    });

    testWidgets('tanpa inkColor tetap ikut tema seperti sebelumnya', (
      tester,
    ) async {
      final darkTheme = ThemeData.dark();

      await tester.pumpWidget(
        MaterialApp(
          theme: darkTheme,
          home: Scaffold(body: GreetingHeader(now: DateTime(2026, 8, 17, 8))),
        ),
      );
      await tester.pump();

      final date = tester.widget<Text>(find.text('Senin, 17 Agustus'));
      expect(date.style?.color, darkTheme.hintColor);
    });
  });

  group('bar header beranda', () {
    const greeting = 'Selamat pagi, Nasrul';

    Future<ScrollController> pumpHeader(
      WidgetTester tester, {
      bool hidden = false,
    }) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final theme = ThemeData();

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Column(
              children: [
                DashboardHeaderBar(
                  greeting: greeting,
                  netBalance: 2400000,
                  isBalanceHidden: hidden,
                  scrollController: controller,
                  actions: const [],
                ),
                Expanded(
                  child: ListView(
                    controller: controller,
                    children: const [SizedBox(height: 2000)],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      return controller;
    }

    /// Lapis silih-ganti terdekat yang membungkus sepotong teks.
    double opacityOf(WidgetTester tester, Finder text) {
      return tester
          .widget<Opacity>(
            find.ancestor(of: text, matching: find.byType(Opacity)).first,
          )
          .opacity;
    }

    testWidgets('di puncak beranda yang tampil sapaannya', (tester) async {
      await pumpHeader(tester);

      expect(opacityOf(tester, find.text(greeting)), 1.0);
      expect(opacityOf(tester, find.text('Rp 2.400.000')), 0.0);
    });

    testWidgets('gulir sepele belum menukar apa pun', (tester) async {
      final controller = await pumpHeader(tester);

      // Jari yang menyentuh layar selalu menggeser beberapa piksel. Kalau
      // ambangnya nol, sapaannya berkedip tiap kali layar disentuh.
      controller.jumpTo(20);
      await tester.pump();

      expect(opacityOf(tester, find.text(greeting)), 1.0);
    });

    testWidgets('saldo naik menggantikan sapaan setelah digulir', (
      tester,
    ) async {
      final controller = await pumpHeader(tester);

      controller.jumpTo(400);
      await tester.pump();

      expect(opacityOf(tester, find.text(greeting)), 0.0);
      expect(opacityOf(tester, find.text('Rp 2.400.000')), 1.0);
    });

    testWidgets('pergantiannya bertahap, bukan meloncat', (tester) async {
      final controller = await pumpHeader(tester);

      controller.jumpTo(68);
      await tester.pump();

      final greetingOpacity = opacityOf(tester, find.text(greeting));
      expect(greetingOpacity, greaterThan(0.0));
      expect(greetingOpacity, lessThan(1.0));
    });

    testWidgets('saldo yang disembunyikan tidak bocor lewat header', (
      tester,
    ) async {
      final controller = await pumpHeader(tester, hidden: true);

      controller.jumpTo(400);
      await tester.pump();

      expect(find.text('Rp 2.400.000'), findsNothing);
      expect(find.text('Rp ••••••'), findsOneWidget);
    });

    testWidgets('tab lain tidak membuat header meledak', (tester) async {
      // Controller-nya menganggur saat tab lain terbuka — tidak ada daftar
      // yang terpasang padanya, dan `offset` melempar kalau dipaksa dibaca.
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardHeaderBar(
              greeting: greeting,
              netBalance: 0,
              isBalanceHidden: false,
              scrollController: controller,
              actions: const [],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(opacityOf(tester, find.text(greeting)), 1.0);
    });
  });

  group('sambungan bidang hijau', () {
    testWidgets('animasi masuk melepaskan bungkusnya setelah selesai', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EntranceAnimation(
              type: EntranceType.flipX,
              duration: Duration(milliseconds: 400),
              child: Text('isi'),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // `Transform` yang tertinggal — walau matriksnya sudah identitas —
      // memaksa lapisan komposit tersendiri, dan tepi lapisan itu jadi garis
      // rambut yang terlihat seperti bingkai di sambungan dua bidang sewarna.
      expect(
        find.descendant(
          of: find.byType(EntranceAnimation),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
      expect(find.text('isi'), findsOneWidget);
    });

    testWidgets('kartu saldo tidak menggambar bingkai apa pun', (tester) async {
      await pumpBalance(tester);

      // Bingkai satu sisi bukan bingkai seragam, dan Flutter menggambarnya
      // sebagai garis lurus yang melewati sudut membulat.
      final card = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(BalanceCard),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = card.decoration as BoxDecoration;
      expect(decoration.border, const Border());
    });

    testWidgets('ikon header bisa berdiri tanpa latar sendiri', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                CircleIconButton(
                  tooltip: 'Tanpa latar',
                  filled: false,
                  icon: Icons.shopping_cart_outlined,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      // Latar putih di atas bar mint memotong hijaunya, padahal ikonnya
      // sendiri sudah cukup terbaca.
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(CircleIconButton),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(container.decoration, isNull);
    });

    testWidgets('di luar bar hijau latarnya tetap dipakai', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                CircleIconButton(
                  tooltip: 'Dengan latar',
                  icon: Icons.shopping_cart_outlined,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(CircleIconButton),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(container.decoration, isNotNull);
    });
  });

  group('hijau tidak terpotong saat ditarik', () {
    testWidgets('diam di puncak berarti tidak ada bidang tambahan', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: HeaderOverscrollFill(scrollController: controller),
                ),
                ListView(
                  controller: controller,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  children: const [SizedBox(height: 2000)],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.getSize(find.byType(HeaderOverscrollFill)).height, 0);
    });

    testWidgets('celah tarikan diisi hijau, bukan latar scaffold', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: HeaderOverscrollFill(scrollController: controller),
                ),
                ListView(
                  controller: controller,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  children: const [SizedBox(height: 2000)],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      // Tarikan ditahan, bukan dilepas: yang diperiksa keadaan saat jarinya
      // masih menempel — persis keadaan di tangkapan layar.
      final gesture = await tester.startGesture(const Offset(400, 300));
      await gesture.moveBy(const Offset(0, 200));
      await tester.pump();

      final height = tester.getSize(find.byType(HeaderOverscrollFill)).height;
      expect(height, greaterThan(0));
      // Tingginya persis sebesar tarikannya — kalau kurang, pita gelapnya
      // cuma menyempit, tidak hilang.
      expect(height, closeTo(-controller.offset, 0.5));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('digulung ke bawah tidak menyisakan bidang menggantung', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: HeaderOverscrollFill(scrollController: controller),
                ),
                ListView(
                  controller: controller,
                  children: const [SizedBox(height: 2000)],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      controller.jumpTo(500);
      await tester.pump();

      // Kalau bidang ini ikut terlihat saat digulung, hijaunya akan bocor ke
      // sela-sela kartu di bawah kartu saldo.
      expect(tester.getSize(find.byType(HeaderOverscrollFill)).height, 0);
    });

    testWidgets('hijaunya tetap terbaca oleh tinta gelap', (tester) async {
      // Hijaunya ditua-kan supaya bidang selebar layar tidak menyilaukan.
      // Yang tidak boleh ikut turun adalah keterbacaan teks di atasnya.
      double channel(double c) {
        return c <= 0.04045
            ? c / 12.92
            : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
      }

      double luminance(Color color) {
        return 0.2126 * channel(color.r) +
            0.7152 * channel(color.g) +
            0.0722 * channel(color.b);
      }

      final green = luminance(AppTheme.neoMint);
      final ink = luminance(AppTheme.borderColor);
      final ratio = (green + 0.05) / (ink + 0.05);

      // Ambang WCAG AA untuk teks biasa 4,5:1; AAA 7:1.
      expect(ratio, greaterThan(7.0));
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
          MaterialApp(
            home: Scaffold(body: PiraMascot(mood: entry.key)),
          ),
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
          MaterialApp(
            home: Scaffold(body: PiraMascot(mood: mood)),
          ),
        );
        // Saat suasananya berganti, `AnimatedSwitcher` sempat menahan gambar
        // lama dan baru sekaligus — tunggu transisinya rampung dulu. Durasinya
        // disebut sendiri karena `pumpAndSettle` akan menggantung di gerakan
        // menganggur PiRa yang memang berputar terus.
        await tester.pump(const Duration(milliseconds: 600));

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
            body: PiraMascot(mood: PiraMood.santai, onTap: () => taps++),
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
              body: PiraMascot(mood: PiraMood.santai, onTap: () => taps++),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(PiraMascot));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });

    testWidgets('hanyut sendiri tanpa perlu disentuh', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PiraMascot(mood: PiraMood.santai)),
        ),
      );
      await tester.pump();

      final start = tester.getCenter(find.byType(Image));
      await tester.pump(const Duration(seconds: 2));
      final later = tester.getCenter(find.byType(Image));

      expect(later, isNot(start));
    });

    testWidgets('hanyut ke dua sumbu, bukan naik-turun saja', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PiraMascot(mood: PiraMood.santai)),
        ),
      );
      await tester.pump();

      final start = tester.getCenter(find.byType(Image));
      var movedHorizontally = false;
      var movedVertically = false;

      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 750));
        final now = tester.getCenter(find.byType(Image));
        if ((now.dx - start.dx).abs() > 0.5) movedHorizontally = true;
        if ((now.dy - start.dy).abs() > 0.5) movedVertically = true;
      }

      expect(movedHorizontally, isTrue);
      expect(movedVertically, isTrue);
    });

    testWidgets('tiap suasana punya gerakannya sendiri', (tester) async {
      final drifts = PiraMood.values.map(driftForMood).toList();

      // Kalau ketiganya sama, "gerakannya ikut kondisi" cuma jadi klaim.
      final amplitudes = drifts.map((d) => d.amplitudeY).toSet();
      final speeds = drifts.map((d) => d.cyclesY).toSet();
      expect(amplitudes, hasLength(PiraMood.values.length));
      expect(speeds, hasLength(PiraMood.values.length));
    });

    testWidgets('putarannya bilangan bulat supaya tidak tersentak', (
      tester,
    ) async {
      // Satu periode harus berisi putaran utuh. Pecahan membuat PiRa
      // meloncat balik ke titik awal tiap kali pengulangannya mulai lagi.
      for (final mood in PiraMood.values) {
        final drift = driftForMood(mood);
        expect(drift.cyclesX, greaterThan(0), reason: mood.name);
        expect(drift.cyclesY, greaterThan(0), reason: mood.name);
        expect(drift.cyclesTilt, greaterThan(0), reason: mood.name);
      }
    });

    testWidgets('berhenti total saat pengguna mematikan animasi', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(body: PiraMascot(mood: PiraMood.santai)),
          ),
        ),
      );
      await tester.pump();

      final start = tester.getCenter(find.byType(Image));
      await tester.pump(const Duration(seconds: 3));

      // Bukan sekadar beramplitudo nol — controller-nya benar-benar berhenti,
      // jadi beranda tidak menggambar ulang tiap frame sepanjang waktu.
      expect(tester.getCenter(find.byType(Image)), start);
      expect(tester.hasRunningAnimations, isFalse);
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
