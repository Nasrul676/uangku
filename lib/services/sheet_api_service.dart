import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/expense.dart';

class SheetApiService {
  /// Sends the [expense] data as a JSON POST to the Google Apps Script [url].
  ///
  /// Google Apps Script Web Apps often respond with a 302 redirect on success,
  /// so we treat both 200 and 302 as successful responses.
  static Future<bool> postExpense(String url, Expense expense) async {
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(expense.toJson()),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 302) {
        return true;
      } else {
        throw Exception(
          'Gagal mengirim data. Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
}
