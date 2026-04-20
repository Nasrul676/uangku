import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/finance_transaction.dart';

class SyncApiService {
  Future<void> syncTransactionsBatch({
    required String webAppUrl,
    required List<FinanceTransaction> transactions,
    required Map<String, String> keyMapping,
    required String payloadRootKey,
  }) async {
    final payload = {
      payloadRootKey: transactions
          .map((tx) => tx.toJsonByMapping(keyMapping))
          .toList(),
    };

    final response = await http.post(
      Uri.parse(webAppUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200 ||
        response.statusCode == 201 ||
        response.statusCode == 302) {
      return;
    }

    throw Exception('Gagal sync. Status: ${response.statusCode}');
  }
}
