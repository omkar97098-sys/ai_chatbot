import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl = 'http://127.0.0.1:8000';

  static Future<Map<String, dynamic>> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name.trim(),
          'email': email.trim(),
          'password': password,
        }),
      );

      final data = _decodeResponse(response);
      return {'statusCode': response.statusCode, ...data};
    } catch (e) {
      return {
        'success': false,
        'message': 'Could not connect to backend.',
        'error': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
        }),
      );

      final data = _decodeResponse(response);

      if (response.statusCode == 200 && data['success'] == true) {
        final user = data['user'];
        final token = data['access_token'];

        if (user is Map && token is String && token.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', token);
          await prefs.setInt('user_id', user['id'] as int);
          await prefs.setString('user_name', user['name'].toString());
          await prefs.setString('user_email', user['email'].toString());
        }
      }

      return {'statusCode': response.statusCode, ...data};
    } catch (e) {
      return {
        'success': false,
        'message': 'Could not connect to backend.',
        'error': e.toString(),
      };
    }
  }

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'success': false, 'message': 'Invalid server response.'};
    } catch (_) {
      return {
        'success': false,
        'message': 'Invalid server response.',
      };
    }
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_name');
  }

  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_email');
  }

  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id');
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
  }
}
