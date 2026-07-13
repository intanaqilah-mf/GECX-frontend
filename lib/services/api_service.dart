import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/banking_models.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

class ApiService {
  // Automatically select the correct URL based on the platform
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';
    } else {
      // Use the common Android emulator loopback if not on web
      // In a real app, this would be a production URL.
      return 'http://10.0.2.2:8000';
    }
  }

  Future<HomeData> getHomeData(String customerId) async {
    final response = await http.get(Uri.parse('$baseUrl/customers/$customerId/home'));
    if (response.statusCode == 200) {
      return HomeData.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load home data');
    }
  }

  Future<CardModel> getCardDetails(String cardId) async {
    final response = await http.get(Uri.parse('$baseUrl/cards/$cardId'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true && data['card'] != null) {
        return CardModel.fromJson(data['card']);
      }
      throw Exception(data['message'] ?? 'Card not found');
    } else {
      throw Exception('Failed to load card details');
    }
  }

  Future<Map<String, dynamic>> activateCard(String cardId) async {
    final response = await http.post(Uri.parse('$baseUrl/cards/$cardId/activate'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to activate card');
    }
  }

  Future<List<ActivityModel>> getCardActivity(String cardId) async {
    final response = await http.get(Uri.parse('$baseUrl/cards/$cardId/activity'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => ActivityModel.fromJson(item)).toList();
    } else {
      return []; // Return empty if failed or not implemented
    }
  }

  Future<List<Map<String, dynamic>>> getNotifications(String customerId) async {
    final response = await http.get(Uri.parse('$baseUrl/customers/$customerId/notifications'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data);
    } else {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPayments(String customerId) async {
    final response = await http.get(Uri.parse('$baseUrl/customers/$customerId/payments'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data);
    } else {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getStatements(String cardId) async {
    final response = await http.get(Uri.parse('$baseUrl/cards/$cardId/statements'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data);
    } else {
      return [];
    }
  }

  Future<void> registerDevice(String customerId, String fcmToken) async {
    final deviceId = await _getOrCreateDeviceId();
    final response = await http.post(
      Uri.parse('$baseUrl/customers/$customerId/devices'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'device_id': deviceId,
        'fcm_token': fcmToken,
        'platform': _platform,
        'app_version': '1.0.0',
        'os_version': 'unknown',
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('registerDevice failed: ${response.statusCode}');
    }
  }

  static Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('acn_device_id');
    if (id == null) {
      id = _generateUuid();
      await prefs.setString('acn_device_id', id);
    }
    return id;
  }

  static String _generateUuid() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10xx
    String hex(List<int> b) =>
        b.map((n) => n.toRadixString(16).padLeft(2, '0')).join();
    return '${hex(bytes.sublist(0, 4))}-'
        '${hex(bytes.sublist(4, 6))}-'
        '${hex(bytes.sublist(6, 8))}-'
        '${hex(bytes.sublist(8, 10))}-'
        '${hex(bytes.sublist(10, 16))}';
  }

  static String get _platform {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'unknown';
    }
  }
}
