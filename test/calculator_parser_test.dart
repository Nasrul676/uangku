import 'package:flutter_test/flutter_test.dart';
import 'package:uangkeluar/utils/calculator_parser.dart';

void main() {
  test('angka biasa dengan pemisah ribuan gaya Indonesia', () {
    expect(CalculatorParser.evaluate('50.000'), 50000);
    expect(CalculatorParser.evaluate('1.250.000'), 1250000);
  });

  test('operasi aritmetika', () {
    expect(CalculatorParser.evaluate('50.000+25.000'), 75000);
    expect(CalculatorParser.evaluate('100.000-40.000'), 60000);
    expect(CalculatorParser.evaluate('3*15.000'), 45000);
  });

  test('singkatan k dan m', () {
    expect(CalculatorParser.evaluate('50k'), 50000);
    expect(CalculatorParser.evaluate('2m'), 2000000);
    expect(CalculatorParser.evaluate('50k+2m'), 2050000);
  });

  test('awalan rp dan spasi diabaikan', () {
    expect(CalculatorParser.evaluate('Rp 50.000'), 50000);
  });

  test('operator menggantung dipulihkan, bukan dilempar', () {
    expect(CalculatorParser.evaluate('50.000+'), 50000);
    expect(CalculatorParser.evaluate('50.000*'), 50000);
  });

  test('input kosong atau sampah menghasilkan nol', () {
    expect(CalculatorParser.evaluate(''), 0);
    expect(CalculatorParser.evaluate('   '), 0);
    expect(CalculatorParser.evaluate('abc'), 0);
  });

  test('formatAndCalculate membuang .0 yang tidak perlu', () {
    expect(CalculatorParser.formatAndCalculate('50k+50k'), '100000');
  });
}
