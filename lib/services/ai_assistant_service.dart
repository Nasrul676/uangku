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
    
    // Menggunakan prompt bahasa Inggris agar model Llama 3.2 lebih akurat memahaminya
    final prompt = 'You are an expert receipt data extractor. Extract purchased items from this receipt OCR into a JSON array. RULES: 1. Return ONLY a valid JSON array, no other text. 2. Extract ONLY the purchased items (IGNORE store name, address, tax, subtotal, total, cash, change, dates). 3. Format: [{"name":"item name","qty":1.0,"price":10000.0,"category":"category"}]. 4. "name" MUST use the original text from receipt. 5. "price" MUST be the TOTAL price for that row (unit price multiplied by qty). It MUST be a pure number without commas (e.g. 11000, NOT 11,000). 6. "category" MUST be exactly one of: [$categoriesStr] or "Lain-lain". 7. MUST use double quotes (") for all strings. OCR TEXT:\n$ocrText';

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
        
        // Mengekstrak murni bagian JSON array dengan menghitung kurung siku
        // Ini mencegah error jika AI secara tidak sengaja mereturn dua array berurutan: [..] [..]
        String cleanJson = replyText.trim();
        
        final startIndex = cleanJson.indexOf('[');
        
        if (startIndex != -1) {
          int openBrackets = 0;
          int endIndex = -1;
          for (int i = startIndex; i < cleanJson.length; i++) {
            if (cleanJson[i] == '[') openBrackets++;
            if (cleanJson[i] == ']') openBrackets--;
            if (openBrackets == 0) {
              endIndex = i;
              break;
            }
          }
          if (endIndex != -1) {
            cleanJson = cleanJson.substring(startIndex, endIndex + 1);
          } else {
            // Fallback jika kurung siku tidak seimbang, coba cari yang terakhir
            final lastIndex = cleanJson.lastIndexOf(']');
            if (lastIndex > startIndex) {
              cleanJson = cleanJson.substring(startIndex, lastIndex + 1);
            } else {
              throw Exception('AI tidak mengembalikan format list array JSON. Balasan: $replyText');
            }
          }
        } else {
          throw Exception('AI tidak mengembalikan format list array JSON. Balasan: $replyText');
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
          final List<dynamic> jsonList = jsonDecode(cleanJson);
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
