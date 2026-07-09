import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/banking_models.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class ApiService {
  // Automatically select the correct URL based on the platform
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';
    } else {
      try {
        if (Platform.isAndroid) return 'http://10.0.2.2:8000';
      } catch (e) {
        // Fallback for other platforms
      }
      return 'http://localhost:8000';
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
}
