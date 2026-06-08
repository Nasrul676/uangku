import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/parsed_receipt_item.dart';

class AiAssistantService {
  static const String _baseUrl = 'https://figures-prefer-subsequent-gardens.trycloudflare.com/api/chat';

  /// Menerima teks hasil OCR dan daftar kategori yang tersedia, 
  /// lalu mengirimkannya ke AI untuk diekstrak menjadi list [ParsedReceiptItem].
  static Future<List<ParsedReceiptItem>> parseReceiptText({
    required String ocrText,
    required List<String> categories,
  }) async {
    final categoriesStr = categories.join(', ');
    
    final prompt = '''You are a receipt item extractor. Your only job is to output a JSON object.

[CRITICAL OUTPUT RULE]
Output ONLY the raw JSON object. No explanation, no preamble, no "Here is...", 
no markdown fences (no ```json). Your entire response must start with { and end with }.

[TASK]
Extract purchased items from the Indonesian receipt OCR text below.

[IGNORE THESE — DO NOT include in output]
- Store name, address, phone number
- Transaction ID / receipt code lines (e.g. "31.05.26-09:11/FEN5-35330/...")
- Cashier name, date, time
- SUBTOTAL, TOTAL BELANJA, TUNAI, KEMBALI (change)
- PPN, DPP, HARGA JUAL, tax lines
- Discount lines (DISC, DISKON, POTONGAN)
- Footer/promotional text

[JSON SCHEMA — follow exactly]
{"items": [{"name": "...", "qty": 1.0, "price": 10000.0, "category": "..."}]}

[FIELD RULES]
- "name"   : Copy the item name exactly as it appears in the OCR text.

- "qty"    : The quantity as a number. Default to 1.0 if not explicitly shown.

- "price"  : The final line-total price as a plain integer (no separators).
              Indonesian receipts use either dot OR comma as thousand separators.
              Convert both: 11.000 → 11000, and 11,000 → 11000.
              Line format is typically: NAME | QTY | UNIT_PRICE | LINE_TOTAL
              Always take the LAST number on the item row as the price.
              Never multiply or recalculate — just clean and copy the last number.

- "category": Choose EXACTLY one from: [$categoriesStr]
              If none fits, use "Lain-lain".

[EXAMPLE — based on real Indomaret receipt]
Input OCR:
MY BB SOAP SWT.FL075   2   5500   11,000
TOTAL BELANJA :        11,000

Output:
{"items": [{"name": "MY BB SOAP SWT.FL075", "qty": 2.0, "price": 11000.0, "category": "Lain-lain"}]}

[OCR TEXT TO PROCESS]
$ocrText''';

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'message': prompt,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String replyText = data['reply'] ?? '';
        
        // Mengekstrak murni bagian JSON object dengan menghitung kurung kurawal
        // Ini mencegah error jika AI secara tidak sengaja menambahkan teks pembuka
        String cleanJson = replyText.trim();
        final startIndex = cleanJson.indexOf('{');
        
        if (startIndex != -1) {
          int openBrackets = 0;
          int endIndex = -1;
          for (int i = startIndex; i < cleanJson.length; i++) {
            if (cleanJson[i] == '{') openBrackets++;
            if (cleanJson[i] == '}') openBrackets--;
            if (openBrackets == 0) {
              endIndex = i;
              break;
            }
          }
          if (endIndex != -1) {
            cleanJson = cleanJson.substring(startIndex, endIndex + 1);
          } else {
            // Fallback jika kurung kurawal tidak seimbang, coba cari yang terakhir
            final lastIndex = cleanJson.lastIndexOf('}');
            if (lastIndex > startIndex) {
              cleanJson = cleanJson.substring(startIndex, lastIndex + 1);
            } else {
              throw Exception('AI tidak mengembalikan format JSON object. Balasan: $replyText');
            }
          }
        } else {
          throw Exception('AI tidak mengembalikan format JSON object. Balasan: $replyText');
        }

        // Hapus komentar inline (// ...) jika AI masih bandel menambahkannya (LAKUKAN SEBELUM newline diganti)
        cleanJson = cleanJson.replaceAll(RegExp(r'//.*'), '');
        // Hapus block komentar (/* ... */)
        cleanJson = cleanJson.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');

        // Perbaiki kutip tunggal di akhir value jika AI salah ketik
        cleanJson = cleanJson.replaceAll("',", '",');
        cleanJson = cleanJson.replaceAll("'\n", '"\n');

        // Perbaiki koma pada angka (pemisah ribuan) misal 18,000 -> 18000
        cleanJson = cleanJson.replaceAllMapped(RegExp(r'(\d+),(\d{3})'), (match) {
          return '${match.group(1)}${match.group(2)}';
        });

        // Sanitasi: ganti newline dengan spasi agar tidak ada "Control character in string" error
        cleanJson = cleanJson.replaceAll('\n', ' ');
        cleanJson = cleanJson.replaceAll('\r', ' ');

        try {
          final Map<String, dynamic> jsonMap = jsonDecode(cleanJson);
          final List<dynamic> jsonList = jsonMap['items'] ?? [];
          
          return jsonList.map((item) {
            return ParsedReceiptItem(
              name: item['name']?.toString() ?? 'Barang',
              price: (item['price'] is num) ? (item['price'] as num).toDouble() : double.tryParse(item['price']?.toString() ?? '0') ?? 0,
              quantity: (item['qty'] is num) ? (item['qty'] as num).toDouble() : double.tryParse(item['qty']?.toString() ?? '1') ?? 1.0,
              category: item['category']?.toString() ?? 'Lain-lain',
            );
          }).toList();
        } catch (e) {
          print("=== GAGAL DECODE JSON ===");
          print(cleanJson);
          print("=========================");
          throw Exception('Format JSON dari AI tidak valid. Error: $e\n\nTeks JSON (setelah dibersihkan):\n$cleanJson');
        }
      } else {
        throw Exception('Gagal menghubungi AI Assistance: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Gagal mengekstrak data struk: $e');
    }
  }
}
