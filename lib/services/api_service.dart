import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/banking_models.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

class ApiService {
  static String get baseUrl => kIsWeb
      ? 'https://acn-customer-platform-gateway-663qhm0p.uc.gateway.dev'
      : 'https://acn-customer-platform-gateway-663qhm0p.uc.gateway.dev';

  Future<HomeData> getHomeData(String customerId) async {
    final response = await http.get(Uri.parse('$baseUrl/customers/$customerId/home'));
    if (response.statusCode == 200) {
      return HomeData.fromJson(json.decode(response.body));
    } else {
      print('[API] ${response.statusCode} ${response.request?.url} ${response.body}');
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
      print('[API] ${response.statusCode} ${response.request?.url} ${response.body}');
      throw Exception('Failed to load card details');
    }
  }

  /// Advance an application's state machine. See the gateway's
  /// `UpdateApplicationRequest` schema — every field is optional; only the
  /// ones you pass get written. Returns the merged post-write document.
  Future<Map<String, dynamic>> patchApplication(
    String applicationId, {
    String? status,
    String? kycStatus,
    String? creditCheckStatus,
    String? fraudCheckStatus,
    String? docsStatus,
    String? decisionOutcome,
    List<String>? decisionReasons,
    int? currentStep,
    String? detail,
    String? sourceAgent = 'flutter_app',
  }) async {
    final body = <String, dynamic>{
      if (status != null) 'status': status,
      if (kycStatus != null) 'kyc_status': kycStatus,
      if (creditCheckStatus != null) 'credit_check_status': creditCheckStatus,
      if (fraudCheckStatus != null) 'fraud_check_status': fraudCheckStatus,
      if (docsStatus != null) 'docs_status': docsStatus,
      if (decisionOutcome != null) 'decision_outcome': decisionOutcome,
      if (decisionReasons != null) 'decision_reasons': decisionReasons,
      if (currentStep != null) 'current_step': currentStep,
      if (detail != null) 'detail': detail,
      if (sourceAgent != null) 'source_agent': sourceAgent,
    };
    final response = await http.patch(
      Uri.parse('$baseUrl/applications/$applicationId'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(response.body));
    }
    print('[API] ${response.statusCode} ${response.request?.url} ${response.body}');
    throw Exception('patchApplication failed: ${response.statusCode}');
  }

  /// Marks the KYC step as `in_progress` and returns the merged application.
  /// The real document bytes would be uploaded to a separate storage endpoint
  /// (not yet implemented gateway-side); this call is what the timeline
  /// listens on to advance step 2 immediately after the user picks a file.
  Future<Map<String, dynamic>> submitApplicationDocument(
    String applicationId, {
    required String documentType,
  }) async {
    return patchApplication(
      applicationId,
      kycStatus: 'in_progress',
      docsStatus: 'uploaded',
      detail: 'Received $documentType. Verifying now.',
    );
  }

  Future<Map<String, dynamic>> activateCard(String cardId) async {
    final response = await http.post(Uri.parse('$baseUrl/cards/$cardId/activate'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      print('[API] ${response.statusCode} ${response.request?.url} ${response.body}');
      throw Exception('Failed to activate card');
    }
  }

  Future<List<ActivityModel>> getCardActivity(String cardId) async {
    final response = await http.get(Uri.parse('$baseUrl/cards/$cardId/activity'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => ActivityModel.fromJson(item)).toList();
    } else {
      print('[API] ${response.statusCode} ${response.request?.url} ${response.body}');
      return []; // Return empty if failed or not implemented
    }
  }

  Future<List<Map<String, dynamic>>> getNotifications(String customerId) async {
    final response = await http.get(Uri.parse('$baseUrl/customers/$customerId/notifications'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data);
    } else {
      print('[API] ${response.statusCode} ${response.request?.url} ${response.body}');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPayments(String customerId) async {
    final response = await http.get(Uri.parse('$baseUrl/customers/$customerId/payments'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data);
    } else {
      print('[API] ${response.statusCode} ${response.request?.url} ${response.body}');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getStatements(String cardId) async {
    final response = await http.get(Uri.parse('$baseUrl/cards/$cardId/statements'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data);
    } else {
      print('[API] ${response.statusCode} ${response.request?.url} ${response.body}');
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
      print('[API] ${response.statusCode} ${response.request?.url} ${response.body}');
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