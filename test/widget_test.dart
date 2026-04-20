import 'package:flutter_test/flutter_test.dart';
import 'package:uangkeluar/main.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const UangKeluarApp());
    await tester.pumpAndSettle();

    // Verify the app title renders
    expect(find.text('UangKeluar'), findsOneWidget);
  });
}
