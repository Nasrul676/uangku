import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uangkeluar/providers/transaction_provider.dart';
import 'package:uangkeluar/services/app_settings_service.dart';
import 'package:uangkeluar/widgets/ai_chat_bubble.dart';
import 'package:uangkeluar/widgets/calculator_bubble.dart';

/// Provider palsu yang cuma menjawab dua getter yang dipakai pintasan, supaya
/// tesnya tidak perlu menyentuh database sama sekali.
class _FakeProvider extends TransactionProvider {
  _FakeProvider({this.calculator = true, this.ai = true});

  final bool calculator;
  final bool ai;

  @override
  bool get showCalculatorShortcut => calculator;

  @override
  bool get showAiAssistantShortcut => ai;
}

void main() {
  Future<void> pumpBubbles(WidgetTester tester, _FakeProvider provider) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<TransactionProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: const [
                SizedBox.expand(),
                CalculatorBubble(),
                AiChatBubble(currentContext: 'Test Screen'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('setelan pintasan melayang', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('keduanya menyala secara bawaan', () async {
      final settings = AppSettingsService();

      // Pengguna lama sudah terbiasa dengan kedua tombol ini. Memperbarui
      // aplikasi tidak boleh diam-diam menghilangkannya.
      expect(await settings.getShowCalculatorShortcut(), isTrue);
      expect(await settings.getShowAiAssistantShortcut(), isTrue);
    });

    test('pilihan mati ikut tersimpan', () async {
      final settings = AppSettingsService();

      await settings.saveShowCalculatorShortcut(false);
      await settings.saveShowAiAssistantShortcut(false);

      expect(await settings.getShowCalculatorShortcut(), isFalse);
      expect(await settings.getShowAiAssistantShortcut(), isFalse);
    });

    test('masing-masing pintasan berdiri sendiri', () async {
      final settings = AppSettingsService();

      await settings.saveShowCalculatorShortcut(false);

      // Mematikan kalkulator tidak boleh ikut mematikan asisten AI.
      expect(await settings.getShowAiAssistantShortcut(), isTrue);
    });

    test('provider menyimpan lalu menyiarkan perubahannya', () async {
      final provider = TransactionProvider(
        settingsService: AppSettingsService(),
      );
      var notified = 0;
      provider.addListener(() => notified++);

      await provider.setShowCalculatorShortcut(false);

      expect(provider.showCalculatorShortcut, isFalse);
      expect(notified, 1);
      expect(await AppSettingsService().getShowCalculatorShortcut(), isFalse);
    });

    test('menyetel ke nilai yang sama tidak memicu rebuild sia-sia', () async {
      final provider = TransactionProvider(
        settingsService: AppSettingsService(),
      );
      var notified = 0;
      provider.addListener(() => notified++);

      await provider.setShowAiAssistantShortcut(true);

      expect(notified, 0);
    });
  });

  group('pintasan melayang mengikuti setelannya', () {
    testWidgets('keduanya tampil saat setelannya menyala', (tester) async {
      await pumpBubbles(tester, _FakeProvider());

      expect(find.byIcon(Icons.calculate_rounded), findsOneWidget);
      expect(find.byType(LottieBuilder), findsOneWidget);
    });

    testWidgets('kalkulator hilang saat dimatikan', (tester) async {
      await pumpBubbles(tester, _FakeProvider(calculator: false));

      expect(find.byIcon(Icons.calculate_rounded), findsNothing);
      // Yang satunya tidak boleh ikut terbawa.
      expect(find.byType(LottieBuilder), findsOneWidget);
    });

    testWidgets('asisten AI hilang saat dimatikan', (tester) async {
      await pumpBubbles(tester, _FakeProvider(ai: false));

      expect(find.byType(LottieBuilder), findsNothing);
      expect(find.byIcon(Icons.calculate_rounded), findsOneWidget);
    });

    testWidgets('layar jadi bersih saat keduanya dimatikan', (tester) async {
      await pumpBubbles(tester, _FakeProvider(calculator: false, ai: false));

      expect(find.byIcon(Icons.calculate_rounded), findsNothing);
      expect(find.byType(LottieBuilder), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
