import 'dart:convert';
import 'dart:io';

import 'package:bulker/config/constants.dart';
import 'package:bulker/models/campaign.dart';
import 'package:bulker/models/contact.dart';
import 'package:http/http.dart' as http;

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path) => Uri.parse('${AppConstants.backendUrl}$path');

  String _messageFromResponse(http.Response response, String fallback) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] != null) {
        return decoded['error'].toString();
      }
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } catch (_) {}
    if (response.statusCode == 404) {
      return 'Backend route not found. Check that the Railway backend is deployed and connected.';
    }
    if (response.body.trim().isNotEmpty && response.body.length < 120) {
      return response.body.trim();
    }
    return fallback;
  }

  Future<String> requestPairingCode(String phoneNumber) async {
    final response = await _client.post(
      _uri('/api/whatsapp/pairing-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phoneNumber': phoneNumber}),
    );
    if (response.statusCode >= 400) {
      throw Exception(_messageFromResponse(response, 'Pairing failed'));
    }
    return jsonDecode(response.body)['code'] as String;
  }

  Future<Map<String, dynamic>> getWhatsAppStatus() async {
    final response = await _client.get(_uri('/api/whatsapp/status'));
    if (response.statusCode >= 400) {
      throw Exception('Could not read WhatsApp status');
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<List<Contact>> uploadContacts(File file) async {
    final request = http.MultipartRequest('POST', _uri('/api/contacts/import'));
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode >= 400) {
      throw Exception('Contact import failed');
    }
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final contacts = decoded['contacts'] as List<dynamic>? ?? [];
    return contacts
        .map((item) => Contact.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<String> startCampaign({
    required String mediaPath,
    required String mediaType,
    required String caption,
    required String name,
    DateTime? scheduledFor,
    required List<Contact> contacts,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/api/send'));
    request.fields['mediaType'] = mediaType;
    request.fields['caption'] = caption;
    request.fields['name'] = name;
    if (scheduledFor != null) {
      request.fields['scheduledFor'] = scheduledFor.toIso8601String();
    }
    request.fields['contacts'] = jsonEncode(
      contacts.map((contact) => contact.toJson()).toList(),
    );
    request.files.add(await http.MultipartFile.fromPath('media', mediaPath));
    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode >= 400) {
      throw Exception(body);
    }
    return jsonDecode(body)['campaignId'] as String;
  }

  Future<List<Campaign>> fetchCampaignHistory() async {
    final response = await _client.get(_uri('/api/send/history'));
    if (response.statusCode >= 400) {
      throw Exception('Could not load campaign history');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final campaigns = decoded['campaigns'] as List<dynamic>? ?? [];
    return campaigns
        .map((item) => Campaign.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<String> retryFailed(String campaignId) async {
    final response = await _client.post(_uri('/api/send/$campaignId/retry-failed'));
    if (response.statusCode >= 400) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Retry failed');
    }
    return jsonDecode(response.body)['campaignId'] as String;
  }

  Future<Map<String, dynamic>> fetchSettings() async {
    final response = await _client.get(_uri('/api/settings'));
    if (response.statusCode >= 400) {
      throw Exception('Could not load settings');
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<void> disconnectWhatsApp() async {
    await _client.post(_uri('/api/settings/disconnect-whatsapp'));
  }

  Future<void> pauseCampaign(String campaignId) async {
    await _client.post(_uri('/api/send/$campaignId/pause'));
  }

  Future<void> resumeCampaign(String campaignId) async {
    await _client.post(_uri('/api/send/$campaignId/resume'));
  }

  Future<void> cancelCampaign(String campaignId) async {
    await _client.post(_uri('/api/send/$campaignId/cancel'));
  }
}
