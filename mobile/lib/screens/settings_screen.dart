import 'package:bulker/providers/bulker_state.dart';
import 'package:flutter/material.dart';
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
        _SettingsTile(
          title: 'WhatsApp status',
          value: state.whatsAppReady ? 'Connected' : 'Disconnected',
          icon: Icons.link,
        ),
        _SettingsTile(
          title: 'App version',
          value: state.appVersion,
          icon: Icons.info_outline,
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

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
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
        ],
      ),
    );
  }
}
