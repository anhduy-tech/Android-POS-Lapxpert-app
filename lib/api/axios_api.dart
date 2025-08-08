import 'package:http/http.dart' as http;
import 'dart:convert';

class Api {
  static const String baseUrl = 'http://192.168.1.67:8080/api/v2';
  static const int defaultTimeout = 10000;

  static Future<Map<String, dynamic>> get(String endpoint, {Map<String, dynamic>? queryParameters}) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: queryParameters);
      final response = await http.get(uri, headers: {'Content-Type': 'application/json'}).timeout(const Duration(milliseconds: defaultTimeout));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load data: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('API Error: $e');
    }
  }

  static Future<Map<String, dynamic>> post(String endpoint, {dynamic data}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      ).timeout(const Duration(milliseconds: defaultTimeout));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to post data: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('API Error: $e');
    }
  }
}