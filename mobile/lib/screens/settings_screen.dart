import 'dart:io';

import 'package:bulker/providers/bulker_state.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BulkerState>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 22),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 20),
        _ProfileCard(state: state),
        const SizedBox(height: 16),
        _SettingsTile(
          title: 'WhatsApp status',
          value: state.whatsAppReady ? 'Connected' : 'Disconnected',
          icon: Icons.link,
          onTap: () => context.go('/'),
        ),
        _SettingsTile(
          title: 'App version',
          value: state.appVersion,
          icon: Icons.info_outline,
        ),
        _ThemeTile(state: state),
        _SettingsTile(
          title: 'Sent today',
          value: '${state.safety['sentToday'] ?? 0}/${state.safety['dailyLimit'] ?? 150}',
          icon: Icons.speed_outlined,
        ),
        _SettingsTile(
          title: 'Send delay',
          value:
              '${((state.safety['minDelayMs'] ?? 30000) / 1000).round()}-${((state.safety['maxDelayMs'] ?? 90000) / 1000).round()}s',
          icon: Icons.timer_outlined,
        ),
        const SizedBox(height: 18),
        const Text('WhatsApp Accounts', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        if (state.whatsappAccounts.isEmpty)
          const Text('No WhatsApp account data loaded yet.')
        else
          ...state.whatsappAccounts.map(
            (account) => _SettingsTile(
              title: account['name'] as String? ?? 'WhatsApp Account',
              value: account['status'] as String? ?? 'unknown',
              icon: Icons.account_circle_outlined,
            ),
          ),
        const SizedBox(height: 22),
        OutlinedButton.icon(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.link),
          label: Text(state.whatsAppReady ? 'Manage WhatsApp Link' : 'Connect WhatsApp'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: state.refreshSettings,
          icon: const Icon(Icons.sync),
          label: const Text('Refresh Settings'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: state.disconnectWhatsApp,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFE32929),
            side: const BorderSide(color: Color(0xFFE32929)),
          ),
          icon: const Icon(Icons.link_off),
          label: const Text('Disconnect WhatsApp'),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.state});

  final BulkerState state;

  @override
  Widget build(BuildContext context) {
    final photoPath = state.profilePhotoPath;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE1E4E8)),
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(36),
            onTap: state.pickProfilePhoto,
            child: CircleAvatar(
              radius: 34,
              backgroundColor: const Color(0xFF173041),
              backgroundImage: photoPath == null ? null : FileImage(File(photoPath)),
              child: photoPath == null
                  ? const Icon(Icons.person, color: Colors.white, size: 34)
                  : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.profileName,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  state.profilePhone.isEmpty ? 'Tap edit to add phone' : state.profilePhone,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF5E6672)),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showProfileEditor(context, state),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
    );
  }

  void _showProfileEditor(BuildContext context, BulkerState state) {
    final name = TextEditingController(text: state.profileName);
    final phone = TextEditingController(text: state.profilePhone);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              onPressed: state.pickProfilePhoto,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Upload Profile Photo'),
            ),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              state.updateProfile(name: name.text, phone: phone.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.state});

  final BulkerState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1E4E8)),
      ),
      child: Row(
        children: [
          Icon(
            state.isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            color: const Color(0xFF2F7D32),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Dark mode', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
          Switch(
            value: state.isDarkMode,
            activeColor: const Color(0xFF2F7D32),
            onChanged: state.setDarkMode,
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    required this.value,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE1E4E8)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF2F7D32)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
            Text(value, style: const TextStyle(fontSize: 12)),
            if (onTap != null) const SizedBox(width: 8),
            if (onTap != null) const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}
