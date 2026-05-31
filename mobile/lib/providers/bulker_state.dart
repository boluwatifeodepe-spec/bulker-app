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
import 'package:flutter_contacts/flutter_contacts.dart' as phone_contacts;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final Map<String, dynamic> safety = {};

  String? pairingCode;
  String pairingStatus = 'STATUS: WAITING FOR INPUT...';
  String? lastError;
  String? contactError;
  String appVersion = '1.0.5';
  String profileName = 'Bulker User';
  String profilePhone = '';
  String? profilePhotoPath;
  String? campaignId;
  int sent = 0;
  int failed = 0;
  int total = 0;
  bool isPaused = false;
  bool isBusy = false;
  bool whatsAppReady = false;
  bool campaignComplete = false;
  bool hasCompletedLogin = false;
  bool isAppReady = false;
  String contactSearchQuery = '';
  bool isAuthenticated = false;
  bool isLoadingHistory = false;
  int duplicatesRemoved = 0;
  int invalidContactsRemoved = 0;

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
    final prefs = await SharedPreferences.getInstance();
    hasCompletedLogin = prefs.getBool('hasCompletedLogin') ?? false;
    notifyListeners();
    _socket.connect(
      onProgress: _handleProgress,
      onComplete: handleCampaignComplete,
      onPairingStatus: _handlePairingStatus,
    );
    try {
      final user = await _firebase.signInAnonymously();
      isAuthenticated = user != null;
    } catch (_) {
      // The app remains usable in local/demo mode until Firebase is configured.
    }
    await refreshWhatsAppStatus();
    await refreshSettings();
    await loadCampaignHistory();
    isAppReady = true;
    notifyListeners();
  }

  Future<void> completeLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasCompletedLogin', true);
    hasCompletedLogin = true;
    isAuthenticated = true;
    notifyListeners();
  }

  Future<String?> signInWithEmail({
    required String email,
    required String password,
    required bool createAccount,
  }) async {
    final cleanEmail = email.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(cleanEmail)) {
      return 'Enter a valid email address.';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }

    try {
      final user = createAccount
          ? await _firebase.createAccountWithEmail(
              email: cleanEmail,
              password: password,
            )
          : await _firebase.signInWithEmail(
              email: cleanEmail,
              password: password,
            );
      isAuthenticated = user != null || !_firebase.isAvailable;
      await completeLogin();
      return null;
    } catch (error) {
      final text = error.toString();
      if (text.contains('user-not-found') || text.contains('wrong-password')) {
        return 'Email or password is not correct.';
      }
      if (text.contains('email-already-in-use')) {
        return 'This email already has an account. Sign in instead.';
      }
      if (text.contains('weak-password')) {
        return 'Password is too weak. Use at least 6 characters.';
      }
      return text.replaceFirst('Exception: ', '');
    }
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasCompletedLogin', false);
    hasCompletedLogin = false;
    notifyListeners();
  }

  Future<void> refreshWhatsAppStatus() async {
    try {
      final status = await _api.getWhatsAppStatus();
      whatsAppReady = status['ready'] == true;
      pairingStatus = whatsAppReady
          ? 'STATUS: WHATSAPP CONNECTED'
          : 'STATUS: WHATSAPP NOT LINKED';
      if (whatsAppReady && contacts.isEmpty) {
        await importWhatsAppContacts(showErrors: false);
      }
    } catch (error) {
      whatsAppReady = false;
      pairingStatus = 'STATUS: BACKEND NOT CONNECTED';
    }
    notifyListeners();
  }

  Future<void> requestPairingCode(String phoneNumber) async {
    final normalized = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^[1-9]\d{8,14}$').hasMatch(normalized)) {
      pairingCode = null;
      pairingStatus = 'STATUS: CHECK PHONE NUMBER';
      lastError = 'Select your country code and enter a valid phone number.';
      notifyListeners();
      return;
    }
    isBusy = true;
    lastError = null;
    pairingStatus = 'STATUS: REQUESTING PAIRING CODE...';
    notifyListeners();
    try {
      pairingCode = await _api.requestPairingCode(normalized);
      pairingStatus = 'STATUS: WAITING FOR LINK...';
    } catch (error) {
      pairingCode = null;
      pairingStatus = 'STATUS: PAIRING FAILED';
      lastError = error.toString().replaceFirst('Exception: ', '');
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
    contactError = null;
    notifyListeners();
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
    cleanupContacts(showResult: false);
    for (final contact in contacts) {
      try {
        _firebase.upsertContact(contact).catchError((_) {});
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> importPhoneContacts() async {
    contactError = null;
    notifyListeners();
    try {
      final allowed = await phone_contacts.FlutterContacts.requestPermission();
      if (!allowed) {
        contactError = 'Contacts permission is required before Bulker can import phone contacts.';
        notifyListeners();
        return;
      }
      var imported = 0;
      final existing = contacts.map((contact) => contact.normalizedPhone).toSet();
      final phoneContacts = await phone_contacts.FlutterContacts.getContacts(
        withProperties: true,
      );
      for (final item in phoneContacts) {
        for (final number in item.phones) {
          final digits = number.number.replaceAll(RegExp(r'\D'), '');
          if (digits.length < 9 || existing.contains(digits)) continue;
          contacts.add(
            Contact(
              name: item.displayName.trim().isEmpty ? 'Phone Contact' : item.displayName,
              phone: digits,
            ),
          );
          existing.add(digits);
          imported++;
        }
      }
      if (imported == 0) {
        contactError = 'No new phone contacts found.';
      } else {
        cleanupContacts(showResult: false);
        contactError = 'Imported $imported phone contacts.';
      }
    } catch (error) {
      contactError = 'Could not open phone contacts. Allow Contacts permission and try again.';
    }
    notifyListeners();
  }

  Future<void> importWhatsAppContacts({bool showErrors = true}) async {
    contactError = null;
    notifyListeners();
    try {
      final imported = await _api.fetchWhatsAppContacts();
      final existing = contacts.map((contact) => contact.normalizedPhone).toSet();
      var added = 0;
      for (final contact in imported) {
        if (!contact.isValid || existing.contains(contact.normalizedPhone)) continue;
        contacts.add(contact);
        existing.add(contact.normalizedPhone);
        added++;
      }
      if (added == 0 && showErrors) {
        contactError = whatsAppReady
            ? 'No new WhatsApp contacts found.'
            : 'Link WhatsApp first, then sync WhatsApp contacts.';
      } else if (showErrors) {
        contactError = 'Imported $added WhatsApp contacts.';
      }
      cleanupContacts(showResult: false);
    } catch (error) {
      if (showErrors) {
        contactError = 'Could not load WhatsApp contacts. Link WhatsApp and try again.';
      }
    }
    notifyListeners();
  }

  void addContact(String name, String phone) {
    final contact = Contact(name: name, phone: phone);
    if (!contact.isValid) {
      contactError = 'Enter phone number with country code and no leading zero.';
      notifyListeners();
      return;
    }
    if (contacts.any((item) => item.normalizedPhone == contact.normalizedPhone)) {
      contactError = 'This phone number is already in your contacts.';
      notifyListeners();
      return;
    }
    contacts.add(contact);
    try {
      _firebase.upsertContact(contact).catchError((_) {});
    } catch (_) {}
    notifyListeners();
  }

  void cleanupContacts({bool showResult = true}) {
    final seen = <String>{};
    var duplicates = 0;
    var invalid = 0;
    contacts.removeWhere((contact) {
      if (!contact.isValid) {
        invalid++;
        return true;
      }
      final phone = contact.normalizedPhone;
      if (seen.contains(phone)) {
        duplicates++;
        return true;
      }
      seen.add(phone);
      return false;
    });
    duplicatesRemoved = duplicates;
    invalidContactsRemoved = invalid;
    if (showResult) {
      contactError = duplicates == 0 && invalid == 0
          ? 'Contacts are clean. No duplicate or invalid numbers found.'
          : 'Cleaned contacts: removed $duplicates duplicate and $invalid invalid number(s).';
    }
    notifyListeners();
  }

  Future<void> pickProfilePhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 82);
    if (picked == null) return;
    profilePhotoPath = picked.path;
    notifyListeners();
  }

  void updateProfile({required String name, required String phone}) {
    profileName = name.trim().isEmpty ? 'Bulker User' : name.trim();
    profilePhone = phone.trim();
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
        mediaPath: message.mediaPath,
        mediaType: message.mediaType,
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
      campaignHistory.clear();
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

  String campaignReportUrl(String campaignId) {
    return _api.campaignReportUrl(campaignId).toString();
  }

  Future<void> refreshSettings() async {
    try {
      final settings = await _api.fetchSettings();
      appVersion = settings['version'] as String? ?? appVersion;
      safety
        ..clear()
        ..addAll(Map<String, dynamic>.from(settings['safety'] as Map? ?? {}));
      final accounts = settings['accounts'] as List<dynamic>? ?? [];
      whatsappAccounts
        ..clear()
        ..addAll(accounts.map((item) => Map<String, dynamic>.from(item as Map)));
    } catch (error) {
      whatsappAccounts.clear();
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
    if (whatsAppReady && contacts.isEmpty) {
      importWhatsAppContacts(showErrors: false);
    }
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
