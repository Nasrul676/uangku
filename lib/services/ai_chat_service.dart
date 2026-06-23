import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';

typedef FunctionCallHandler = Future<Map<String, dynamic>> Function(String name, Map<String, dynamic> args);

class AiChatService {
  // We use 1.5 flash for better function calling reliability
  static const String _model = 'gemini-flash-lite-latest';

  static final List<Map<String, dynamic>> _tools = [
    {
      'functionDeclarations': [
        {
          'name': 'get_current_balance',
          'description': 'Mendapatkan saldo saat ini beserta total pemasukan dan pengeluaran pada buku aktif.',
        },
        {
          'name': 'get_recent_transactions',
          'description': 'Mendapatkan daftar transaksi terakhir.',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'limit': {
                'type': 'INTEGER',
                'description': 'Jumlah transaksi yang ingin diambil. Default 5.'
              }
            }
          }
        },
        {
          'name': 'add_transaction',
          'description': 'Mencatat transaksi baru (pemasukan atau pengeluaran).',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'title': {'type': 'STRING', 'description': 'Nama transaksi'},
              'amount': {'type': 'NUMBER', 'description': 'Jumlah nominal transaksi'},
              'type': {'type': 'STRING', 'description': 'Jenis: "INCOME" atau "EXPENSE"'},
              'category': {'type': 'STRING', 'description': 'Kategori transaksi'},
              'date': {'type': 'STRING', 'description': 'Tanggal (YYYY-MM-DD). Jika tidak disebutkan gunakan hari ini.'}
            },
            'required': ['title', 'amount', 'type', 'category', 'date']
          }
        },
        {
          'name': 'get_financial_plans',
          'description': 'Mendapatkan daftar rencana keuangan aktif.',
        },
        {
          'name': 'add_financial_plan',
          'description': 'Membuat rencana keuangan baru.',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'title': {'type': 'STRING', 'description': 'Nama rencana'},
              'target_amount': {'type': 'NUMBER', 'description': 'Nominal target'},
              'target_date': {'type': 'STRING', 'description': 'Tanggal target (YYYY-MM-DD).'}
            },
            'required': ['title', 'target_amount', 'target_date']
          }
        },
        {
          'name': 'navigate_to_page',
          'description': 'Mengarahkan pengguna ke halaman/layar tertentu di aplikasi.',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'page_name': {
                'type': 'STRING',
                'description': 'Nama halaman, contoh: "home", "settings", "savings", "shopping_list", "plans", "pockets"'
              }
            },
            'required': ['page_name']
          }
        }
      ]
    }
  ];

  static Future<Map<String, dynamic>> sendMessage({
    required String apiKey,
    required String message,
    required List<ChatMessage> history,
    required String currentContext,
    required List<String> categories,
    required FunctionCallHandler onFunctionCall,
  }) async {
    if (apiKey.isEmpty) {
      throw Exception('API Key Gemini belum diatur. Silakan masukkan API Key di halaman Setelan.');
    }

    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent');
    final categoriesStr = categories.join(', ');

    final systemInstruction = '''
Anda adalah Asisten AI untuk aplikasi keuangan "uangku". Anda ramah, membantu, dan menggunakan bahasa Indonesia santai namun profesional.
Konteks saat ini (layar pengguna): $currentContext
Daftar Kategori: [$categoriesStr]

PENTING:
- Anda memiliki akses ke beberapa fungsi (tools) untuk mengambil data dari database atau melakukan aksi.
- Jika pengguna menanyakan saldo, riwayat transaksi, atau rencana keuangan, GUNAKAN FUNGSI yang tersedia sebelum menjawab.
- Jika pengguna meminta mencatat pengeluaran/pemasukan, gunakan fungsi `add_transaction`.
- Jika pengguna meminta berpindah halaman, gunakan `navigate_to_page`.
- Anda dapat memanggil beberapa fungsi secara berurutan jika diperlukan.
- Jawablah pengguna berdasarkan data riil yang dikembalikan oleh fungsi.
''';

    // Prepare history
    final contents = history.map((msg) {
      return {
        'role': msg.role == 'model' ? 'model' : 'user',
        'parts': [{'text': msg.text}]
      };
    }).toList();

    // Add current user message
    contents.add({
      'role': 'user',
      'parts': [{'text': message}]
    });

    String? finalAction;
    Map<String, dynamic>? finalActionData;

    // Loop for handling function calls (up to 5 iterations to prevent infinite loops)
    for (int i = 0; i < 5; i++) {
      try {
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
          },
          body: jsonEncode({
            'systemInstruction': {
              'parts': [{'text': systemInstruction}]
            },
            'contents': contents,
            'tools': _tools,
            'generationConfig': {
              'temperature': 0.5,
            }
          }),
        );

        if (response.statusCode != 200) {
          final error = jsonDecode(response.body);
          throw Exception('Gagal menghubungi AI Assistance: ${error['error']['message'] ?? response.statusCode}');
        }

        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List?;
        if (candidates == null || candidates.isEmpty) {
          throw Exception('Respons Gemini kosong');
        }

        final content = candidates[0]['content'];
        final parts = content['parts'] as List?;
        if (parts == null || parts.isEmpty) {
          throw Exception('Respons Gemini tidak memiliki teks');
        }

        bool hasFunctionCall = false;
        String? replyText;

        for (final part in parts) {
          if (part.containsKey('functionCall')) {
            hasFunctionCall = true;
            final functionCall = part['functionCall'];
            final String name = functionCall['name'];
            final Map<String, dynamic> args = functionCall['args'] ?? {};

            // Record the action for UI feedback
            finalAction = name;
            finalActionData = args;

            // Add the model's function call to history
            contents.add({
              'role': 'model',
              'parts': [part]
            });

            // Execute the tool
            final result = await onFunctionCall(name, args);

            // Add function response to history
            contents.add({
              'role': 'function',
              'parts': [
                {
                  'functionResponse': {
                    'name': name,
                    'response': {'name': name, 'content': result}
                  }
                }
              ]
            });
          } else if (part.containsKey('text')) {
            replyText = part['text'];
          }
        }

        if (!hasFunctionCall) {
          // If no function was called, we're done
          return {
            'message': replyText ?? '',
            'action': finalAction,
            'action_data': finalActionData,
          };
        }

        // If there was a function call, the loop continues and makes another request with the function response
      } catch (e) {
        throw Exception('Gagal memproses pesan: $e');
      }
    }

    throw Exception('Terlalu banyak pemanggilan fungsi berantai.');
  }
}
