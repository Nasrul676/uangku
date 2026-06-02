import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/parsed_receipt_item.dart';

class ReceiptParser {
  /// Parses recognized text from a receipt and extracts product items.
  ///
  /// Uses a token-based approach:
  /// 1. Split each line into tokens by whitespace.
  /// 2. Identify trailing pure-numeric tokens (digits, dots, commas only).
  /// 3. The rightmost numeric token is the total price.
  /// 4. If 3 trailing numbers: validate qty × unitPrice ≈ totalPrice.
  /// 5. If 2 trailing numbers: treat small integer as quantity.
  /// 6. Everything before the numeric zone is the item name.
  /// 7. Filter out non-item lines (totals, addresses, promos, etc.).
  static List<ParsedReceiptItem> parse(RecognizedText recognizedText) {
    final items = <ParsedReceiptItem>[];

    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        final text = line.text.trim();
        if (text.isEmpty) continue;
        if (_isNonItemLine(text)) continue;

        // Split into whitespace-separated tokens
        final tokens = text.split(RegExp(r'\s+'));
        if (tokens.isEmpty) continue;

        // Find trailing pure-numeric tokens (right-to-left)
        int trailingNumStart = tokens.length;
        for (int i = tokens.length - 1; i >= 0; i--) {
          if (_isNumericToken(tokens[i])) {
            trailingNumStart = i;
          } else {
            break;
          }
        }

        final numericCount = tokens.length - trailingNumStart;
        if (numericCount < 1) continue;

        // Name = everything before the trailing numbers
        final nameTokens = tokens.sublist(0, trailingNumStart);
        if (nameTokens.isEmpty) continue;

        String itemName = nameTokens.join(' ').trim();
        itemName = itemName.replaceAll(RegExp(r'^[^a-zA-Z0-9]+'), '').trim();
        itemName = itemName.replaceAll(RegExp(r'[^a-zA-Z0-9)]+$'), '').trim();

        if (itemName.isEmpty) continue;
        if (!RegExp(r'[a-zA-Z]').hasMatch(itemName)) continue;
        if (_excludePattern.hasMatch(itemName)) continue;

        // Parse trailing numeric tokens
        final numericTokens = tokens.sublist(trailingNumStart);

        double totalPrice = 0;
        double quantity = 1.0;

        if (numericTokens.length == 1) {
          totalPrice = _parseIndonesianNumber(numericTokens[0]);
        } else if (numericTokens.length == 2) {
          final val1 = _parseIndonesianNumber(numericTokens[0]);
          final val2 = _parseIndonesianNumber(numericTokens[1]);

          // If val1 is small integer-like, treat as quantity
          if (val1 > 0 && val1 < 100 && val1 == val1.roundToDouble() && val2 > val1) {
            quantity = val1;
            totalPrice = val2;
          } else {
            totalPrice = val2;
          }
        } else if (numericTokens.length >= 3) {
          final qtyVal = _parseIndonesianNumber(numericTokens[numericTokens.length - 3]);
          final unitVal = _parseIndonesianNumber(numericTokens[numericTokens.length - 2]);
          totalPrice = _parseIndonesianNumber(numericTokens[numericTokens.length - 1]);

          if (qtyVal > 0 && qtyVal < 1000 && unitVal > 0 && totalPrice > 0) {
            final expectedTotal = qtyVal * unitVal;
            final tolerance = totalPrice * 0.05 + 1;
            if ((expectedTotal - totalPrice).abs() <= tolerance) {
              quantity = qtyVal;
            }
          }
        }

        if (totalPrice <= 0) continue;

        items.add(ParsedReceiptItem(
          name: itemName,
          price: totalPrice,
          quantity: quantity,
        ));
      }
    }

    return items;
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  /// A token is "numeric" if it contains ONLY digits, dots, and commas.
  /// Tokens like "300ML", "1KG", "1L" are NOT numeric.
  static bool _isNumericToken(String token) {
    return RegExp(r'^[\d\.,]+$').hasMatch(token);
  }

  /// Parse a number string in Indonesian format.
  ///
  /// Indonesian receipts use dots as thousands separators and commas as
  /// decimal separators: 15.000 = 15000, 12.500,00 = 12500.00.
  static double _parseIndonesianNumber(String raw) {
    String s = raw.trim();
    if (s.isEmpty) return 0;

    bool isNegative = s.startsWith('-');
    if (isNegative) s = s.substring(1);

    bool hasDot = s.contains('.');
    bool hasComma = s.contains(',');

    if (hasDot && hasComma) {
      int lastDot = s.lastIndexOf('.');
      int lastComma = s.lastIndexOf(',');
      if (lastComma > lastDot) {
        // 12.500,00 → 12500.00
        s = s.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // 12,500.00 → 12500.00
        s = s.replaceAll(',', '');
      }
    } else if (hasDot) {
      final parts = s.split('.');
      if (parts.length == 2 && parts[1].length == 3) {
        // 5.000 → 5000 (thousands separator)
        s = s.replaceAll('.', '');
      } else if (parts.length > 2) {
        // 1.500.000 → 1500000
        s = s.replaceAll('.', '');
      }
      // else keep as decimal (e.g. 4.5)
    } else if (hasComma) {
      final parts = s.split(',');
      if (parts.length == 2 && parts[1].length == 3) {
        // 11,000 → 11000 (thousands separator)
        s = s.replaceAll(',', '');
      } else if (parts.length > 2) {
        s = s.replaceAll(',', '');
      } else {
        // 0,5 or 1,25 → decimal
        s = s.replaceAll(',', '.');
      }
    }

    final val = double.tryParse(s) ?? 0;
    return isNegative ? -val : val;
  }

  /// Words/phrases that indicate a line is NOT a product item.
  static final _excludePattern = RegExp(
    r'(^total|^sub\s*total|^grand\s*total|tunai|kembali|^ppn|^dpp|^tax|'
    r'^cash|^change|^diskon|^discount|^harga jual|^member|^layanan|^sms|'
    r'^telp|^kontak|^belanja lebih|^gratis|^terima kasih|^struk ini|'
    r'^simpan struk|@|\.co\.|\.com|\.id$|^jl\.?\s|^jalan\s)',
    caseSensitive: false,
  );

  /// Checks if a line is clearly not a product (address, date, phone, etc.).
  static bool _isNonItemLine(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return true;
    // Pure numbers / phone numbers
    if (RegExp(r'^[\d\s\-\.\/\(\)\+]+$').hasMatch(trimmed)) return true;
    // Date/code line
    if (RegExp(r'^\d{1,2}[\.\-/]\d{1,2}[\.\-/]\d{2,4}').hasMatch(trimmed)) return true;
    // No digits at all (store name, promo text)
    if (!RegExp(r'\d').hasMatch(trimmed)) return true;
    // Matches exclude patterns
    if (_excludePattern.hasMatch(trimmed)) return true;
    // Lines with = (summary: DPP= PPN=)
    if (trimmed.contains('=')) return true;
    return false;
  }
}
