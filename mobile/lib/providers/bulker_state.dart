import 'dart:async';
import 'dart:io';

import 'package:bulker/models/activity_log.dart';
import 'package:bulker/models/campaign.dart';
import 'package:bulker/models/campaign_message.dart';
import 'package:bulker/models/contact.dart';
import 'package:bulker/services/api_service.dart';
import 'package:bulker/services/firebase_service.dart';
import 'package:bulker/services/socket_service.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class BulkerState extends ChangeNotifier {
  BulkerState({
    ApiService? apiService,
    FirebaseService? firebaseService,
    SocketService? socketService,
  })  : _api = apiService ?? ApiService(),
        _firebase = firebaseService ?? FirebaseService(),
        _socket = socketService ?? SocketService();

  final ApiService _api;
  final FirebaseService _firebase;
  final SocketService _socket;
  final ImagePicker _picker = ImagePicker();

  final CampaignMessage message = CampaignMessage();
  final List<Contact> contacts = [];
  final List<ActivityLog> activity = [];
  final List<Campaign> campaignHistory = [];
  final List<Map<String, dynamic>> whatsappAccounts = [];

  String? pairingCode;
  String pairingStatus = 'STATUS: WAITING FOR INPUT...';
  String? lastError;
  String appVersion = '1.0.0';
  String? campaignId;
  int sent = 0;
  int failed = 0;
  int total = 0;
  bool isPaused = false;
  bool isBusy = false;
  bool whatsAppReady = false;
  bool campaignComplete = false;
  String contactSearchQuery = '';
  bool isAuthenticated = false;
  bool isLoadingHistory = false;

  int get selectedCount => contacts.where((contact) => contact.selected).length;
  double get progress => total == 0 ? 0 : sent / total;
  int get percentage => (progress * 100).round();
  List<Contact> get selectedContacts =>
      contacts.where((contact) => contact.selected && contact.isValid).toList();
  List<Contact> get filteredContacts {
    final query = contactSearchQuery.trim().toLowerCase();
    if (query.isEmpty) return contacts;
    return contacts.where((contact) {
      return contact.name.toLowerCase().contains(query) ||
          contact.phone.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> initialize() async {
    _socket.connect(
      onProgress: _handleProgress,
      onComplete: handleCampaignComplete,
      onPairingStatus: _handlePairingStatus,
    );
    try {
      await _firebase.signInAnonymously();
      isAuthenticated = true;
    } catch (_) {
      // The app remains usable in local/demo mode until Firebase is configured.
    }
    await refreshWhatsAppStatus();
    await refreshSettings();
    await loadCampaignHistory();
  }

  Future<void> refreshWhatsAppStatus() async {
    try {
      final status = await _api.getWhatsAppStatus();
      whatsAppReady = status['ready'] == true;
      pairingStatus = whatsAppReady
          ? 'STATUS: WHATSAPP CONNECTED'
          : 'STATUS: WHATSAPP NOT LINKED';
      lastError = status['error'] as String?;
    } catch (error) {
      lastError = '$error';
    }
    notifyListeners();
  }

  Future<void> requestPairingCode(String phoneNumber) async {
    isBusy = true;
    lastError = null;
    pairingStatus = 'STATUS: REQUESTING PAIRING CODE...';
    notifyListeners();
    try {
      pairingCode = await _api.requestPairingCode(phoneNumber);
      pairingStatus = 'STATUS: WAITING FOR LINK...';
    } catch (error) {
      pairingCode = null;
      pairingStatus = 'STATUS: PAIRING FAILED';
      lastError = '$error';
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> pickMedia(ImageSource source, {required bool video}) async {
    final XFile? picked = video
        ? await _picker.pickVideo(source: source)
        : await _picker.pickImage(source: source, imageQuality: 88);
    if (picked == null) return;
    message.mediaPath = picked.path;
    message.mediaType = video ? 'video' : 'image';
    notifyListeners();
  }

  void updateCaption(String value) {
    message.caption = value;
    notifyListeners();
  }

  void updateCampaignName(String value) {
    message.name = value;
    notifyListeners();
  }

  void updateScheduledFor(DateTime? value) {
    message.scheduledFor = value;
    notifyListeners();
  }

  void updateContactSearch(String value) {
    contactSearchQuery = value;
    notifyListeners();
  }

  Future<void> importCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    final path = result?.files.single.path;
    if (path == null) return;

    try {
      final imported = await _api.uploadContacts(File(path));
      contacts.addAll(imported);
    } catch (_) {
      final rows = const CsvToListConverter(eol: '\n')
          .convert(await File(path).readAsString())
          .skip(1);
      for (final row in rows) {
        if (row.length < 2) continue;
        contacts.add(Contact(name: '${row[0]}', phone: '${row[1]}'));
      }
    }
    for (final contact in contacts) {
      try {
        _firebase.upsertContact(contact).catchError((_) {});
      } catch (_) {}
    }
    notifyListeners();
  }

  void addContact(String name, String phone) {
    final contact = Contact(name: name, phone: phone);
    contacts.add(contact);
    try {
      _firebase.upsertContact(contact).catchError((_) {});
    } catch (_) {}
    notifyListeners();
  }

  void toggleContact(Contact contact) {
    contact.selected = !contact.selected;
    notifyListeners();
  }

  void selectAll() {
    final shouldSelect = selectedCount != contacts.length;
    for (final contact in contacts) {
      contact.selected = shouldSelect;
    }
    notifyListeners();
  }

  void deleteContact(Contact contact) {
    contacts.removeWhere((item) => item.id == contact.id);
    try {
      _firebase.deleteContact(contact.id).catchError((_) {});
    } catch (_) {}
    notifyListeners();
  }

  Future<bool> startCampaign() async {
    if (!message.isReady) {
      lastError = 'Add media and caption before sending.';
      notifyListeners();
      return false;
    }
    if (selectedContacts.isEmpty) {
      lastError = 'Select at least one valid contact.';
      notifyListeners();
      return false;
    }
    total = selectedContacts.length;
    sent = 0;
    failed = 0;
    isPaused = false;
    campaignComplete = false;
    activity.clear();
    lastError = null;
    notifyListeners();
    try {
      campaignId = await _api.startCampaign(
        mediaPath: message.mediaPath!,
        mediaType: message.mediaType!,
        caption: message.caption,
        name: message.displayName,
        scheduledFor: message.scheduledFor,
        contacts: selectedContacts,
      );
      await loadCampaignHistory();
      return true;
    } catch (error) {
      lastError = '$error';
      return false;
    } finally {
      notifyListeners();
    }
  }

  Future<void> togglePause() async {
    isPaused = !isPaused;
    final id = campaignId;
    if (id != null) {
      if (isPaused) {
        await _api.pauseCampaign(id);
      } else {
        await _api.resumeCampaign(id);
      }
    }
    notifyListeners();
  }

  Future<void> cancelCampaign() async {
    final id = campaignId;
    if (id != null) {
      await _api.cancelCampaign(id);
    }
    campaignId = null;
    notifyListeners();
  }

  Future<void> loadCampaignHistory() async {
    isLoadingHistory = true;
    notifyListeners();
    try {
      final campaigns = await _api.fetchCampaignHistory();
      campaignHistory
        ..clear()
        ..addAll(campaigns);
    } catch (error) {
      lastError = '$error';
    } finally {
      isLoadingHistory = false;
      notifyListeners();
    }
  }

  Future<void> retryFailed(Campaign campaign) async {
    try {
      campaignId = await _api.retryFailed(campaign.id);
      await loadCampaignHistory();
    } catch (error) {
      lastError = '$error';
    }
    notifyListeners();
  }

  Future<void> refreshSettings() async {
    try {
      final settings = await _api.fetchSettings();
      appVersion = settings['version'] as String? ?? appVersion;
      final accounts = settings['accounts'] as List<dynamic>? ?? [];
      whatsappAccounts
        ..clear()
        ..addAll(accounts.map((item) => Map<String, dynamic>.from(item as Map)));
    } catch (error) {
      lastError = '$error';
    }
    notifyListeners();
  }

  Future<void> disconnectWhatsApp() async {
    await _api.disconnectWhatsApp();
    whatsAppReady = false;
    pairingCode = null;
    pairingStatus = 'STATUS: WHATSAPP DISCONNECTED';
    await refreshSettings();
    notifyListeners();
  }

  void _handleProgress(Map<String, dynamic> data) {
    sent = data['sent'] as int? ?? sent;
    failed = data['failed'] as int? ?? failed;
    total = data['total'] as int? ?? total;
    final contact = data['contact'] as Map<String, dynamic>?;
    if (contact != null) {
      activity.insert(
        0,
        ActivityLog(
          name: contact['name'] as String? ?? 'Contact',
          phone: contact['phone'] as String? ?? '',
          status: data['status'] as String? ?? 'sent',
          timeLabel: 'Now',
        ),
      );
    }
    notifyListeners();
  }

  void _handlePairingStatus(Map<String, dynamic> data) {
    pairingStatus = data['message'] as String? ?? pairingStatus;
    whatsAppReady = data['connected'] as bool? ?? whatsAppReady;
    if (data['error'] != null) {
      lastError = '${data['error']}';
    }
    notifyListeners();
  }

  void handleCampaignComplete(Map<String, dynamic> data) {
    sent = data['sent'] as int? ?? sent;
    failed = data['failed'] as int? ?? failed;
    total = data['total'] as int? ?? total;
    campaignComplete = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _socket.dispose();
    super.dispose();
  }
}
