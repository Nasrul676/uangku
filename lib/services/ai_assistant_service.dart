import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/parsed_receipt_item.dart';

class AiAssistantService {
  static const String _baseUrl = 'https://cds-apparently-directions-festivals.trycloudflare.com/api/chat';

  /// Kata kunci yang menandakan baris bukan merupakan item belanjaan.
  /// Baris yang mengandung salah satu keyword ini akan dibuang sebelum dikirim ke AI.
  static const List<String> _noiseKeywords = [
    // --- Informasi toko & alamat ---
    'JL.', 'JL ', 'JALAN', 'ALAMAT', 'KEC.', 'KEL.', 'KAB.', 'KOTA',
    'PROVINSI', 'RT/', 'RW/', 'BLOK',

    // --- Identitas toko ---
    'NPWP', 'NO.NPWP', 'NIB', 'IZIN', 'CABANG', 'KASIR', 'STRUK',
    'OUTLET', 'MEMBER', 'PELANGGAN',

    // --- Kontak ---
    'TELP', 'TELEPON', 'FAX', 'HP ', 'PHONE', 'WA ', 'EMAIL',

    // --- Pembayaran & ringkasan ---
    'TUNAI', 'CASH', 'DEBIT', 'KREDIT', 'CREDIT', 'QRIS', 'E-WALLET',
    'GOPAY', 'OVO', 'DANA', 'SHOPEEPAY', 'LINKAJA',
    'TOTAL', 'SUBTOTAL', 'SUB TOTAL', 'GRAND TOTAL',
    'KEMBALI', 'KEMBALIAN', 'CHANGE',
    'PPN', 'PAJAK', 'TAX', 'DPP', 'DISC', 'DISKON', 'DISCOUNT',
    'PEMBULATAN', 'ROUNDING',

    // --- Ucapan & footer ---
    'TERIMA KASIH', 'TERIMAKASIH', 'THANK', 'SELAMAT BELANJA',
    'SIMPAN STRUK', 'BARANG YANG SUDAH', 'HARGA SUDAH',

    // --- Tanggal & waktu (pola umum) ---
    'TANGGAL', 'TGL', 'WAKTU', 'JAM',

    // --- Separator / dekorasi ---
    '====', '----', '****', '....',
  ];

  /// Membersihkan teks OCR dari baris-baris yang bukan item belanjaan.
  /// Menghapus baris kosong, baris yang hanya berisi angka/tanggal,
  /// dan baris yang mengandung keyword noise.
  static String _cleanOcrText(String rawText) {
    final lines = rawText.split('\n');
    final cleaned = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();

      // Abaikan baris kosong
      if (trimmed.isEmpty) continue;

      // Abaikan baris yang terlalu pendek (biasanya noise/separator)
      if (trimmed.length < 3) continue;

      // Abaikan baris yang hanya berisi angka, tanda baca, atau spasi
      // (misal: nomor struk, tanggal, separator)
      if (RegExp(r'^[\d\s\-\/\.\:\,\=\*]+$').hasMatch(trimmed)) continue;

      // Abaikan baris yang cocok dengan keyword noise
      final upper = trimmed.toUpperCase();
      final isNoise = _noiseKeywords.any((keyword) => upper.contains(keyword));
      if (isNoise) continue;

      cleaned.add(trimmed);
    }

    return cleaned.join('\n');
  }

  /// Menerima teks hasil OCR dan daftar kategori yang tersedia, 
  /// lalu mengirimkannya ke AI untuk diekstrak menjadi list [ParsedReceiptItem].
  static Future<List<ParsedReceiptItem>> parseReceiptText({
    required String ocrText,
    required List<String> categories,
  }) async {
    final categoriesStr = categories.join(', ');

    // Bersihkan teks OCR dari noise sebelum dikirim ke AI
    final cleanedOcrText = _cleanOcrText(ocrText);
    
    // Menggunakan prompt bahasa Inggris yang sangat spesifik dan terstruktur agar model Llama 3.2 / Qwen
    // lebih akurat membaca qty, unit, dan total price dari format struk Indonesia.
    final prompt = '''You are an expert receipt data extractor. Extract purchased items from this Indonesian receipt OCR into a JSON array. 
RULES: 
1. Return ONLY a valid JSON array, no other text or markdown formatting. 
2. Extract ONLY the purchased items (IGNORE store name, address, tax/PPN, subtotal, total, cash, change, dates, promo). 
3. Format: [{"name":"item name","qty":1.0,"unit":"pcs","price":10000.0,"category":"category"}]. 
4. "name": MUST use the original item text. 
5. "qty": Look carefully for quantities. Sometimes they appear as "2 x 50.000" (qty is 2) or "3 PCS". If not explicitly stated, assume qty is 1.0. MUST be a number.
6. "unit": Extract the unit of measurement if present (e.g. "pcs", "kg", "liter", "porsi", "pack", "box", "buah", "lusin", "rim", "roll", "bungkus", "botol", "kantong", "batang", "biji", "dus", "karton", "lembar", "ons", "pon", "kwintal", "ton". "galon", "meter", "roll"). If not found, default to "pcs". MUST be a string.
7. "price": This MUST be the FINAL TOTAL PRICE for that row (qty * unit price), NOT the unit price. IMPORTANT: Indonesian receipts use '.' for thousands (e.g. 15.000). You MUST remove all dots and commas, and output a pure number (e.g. 15000.0).
8. "category" MUST be EXACTLY one of: [$categoriesStr] or "Lain-lain" if unsure. 
9. Keep it strictly JSON.
OCR TEXT:
$cleanedOcrText''';

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
              unit: item['unit']?.toString() ?? 'pcs',
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
