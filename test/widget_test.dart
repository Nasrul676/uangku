import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uangkeluar/main.dart';

void main() {
  testWidgets('aplikasi mulai tanpa exception dan menampilkan layar awal', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const UangKeluarApp());

    // Sengaja `pump`, bukan `pumpAndSettle`: layar awal menampilkan indikator
    // loading yang beranimasi terus, jadi `pumpAndSettle` tidak akan pernah
    // selesai dan tesnya timeout.
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
