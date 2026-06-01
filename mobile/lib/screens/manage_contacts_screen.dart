import 'package:bulker/models/contact.dart';
import 'package:bulker/providers/bulker_state.dart';
import 'package:bulker/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class ManageContactsScreen extends StatelessWidget {
  const ManageContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BulkerState>();
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 30, 20, 18),
            children: [
              Text('Contacts', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              _WhatsAppConnectionCard(connected: state.whatsAppReady),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: 'Import CSV',
                      icon: Icons.file_upload_outlined,
                      filled: true,
                      onTap: state.importCsv,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      label: 'Add Manually',
                      icon: Icons.person_add_alt_1_outlined,
                      onTap: () => _showAddContact(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ActionButton(
                label: 'Import Phone Contacts',
                icon: Icons.contacts_outlined,
                onTap: state.importPhoneContacts,
              ),
              const SizedBox(height: 12),
              _ActionButton(
                label: 'Sync WhatsApp Contacts',
                icon: Icons.chat_outlined,
                onTap: () => state.importWhatsAppContacts(),
              ),
              const SizedBox(height: 12),
              _ActionButton(
                label: 'Clean Duplicates / Invalid Numbers',
                icon: Icons.cleaning_services_outlined,
                onTap: state.cleanupContacts,
              ),
              if (state.contactError != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE8E8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    state.contactError!,
                    style: const TextStyle(
                      color: Color(0xFFB42318),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              TextField(
                onChanged: state.updateContactSearch,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 21),
                  hintText: 'Search 2,400+ contacts...',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF77808A)),
                  filled: true,
                  fillColor: scheme.surface,
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6DF084),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${state.selectedCount} contacts selected',
                      style: const TextStyle(
                        color: Color(0xFF287A35),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: state.selectAll,
                    child: const Text(
                      'Select All',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (state.contacts.isEmpty)
                const _EmptyContacts()
              else if (state.filteredContacts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      'No contacts match your search.',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                )
              else
                ...state.filteredContacts.map(
                  (contact) => _ContactRow(contact: contact),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          child: PrimaryButton(
            label: 'Continue to Send',
            icon: Icons.send_outlined,
            onPressed: state.message.isReady && state.selectedContacts.isNotEmpty
                ? () async {
                    final started = await state.startCampaign();
                    if (!context.mounted) return;
                    if (started) {
                      context.go('/dashboard');
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.read<BulkerState>().lastError ??
                                'Could not start campaign.',
                          ),
                        ),
                      );
                    }
                  }
                : null,
          ),
        ),
      ],
    );
  }

  void _showAddContact(BuildContext context) {
    final name = TextEditingController();
    final phone = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              context.read<BulkerState>().addContact(name.text, phone.text);
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _WhatsAppConnectionCard extends StatelessWidget {
  const _WhatsAppConnectionCard({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE1E4E8)),
      ),
      child: Row(
        children: [
          Icon(
            connected ? Icons.check_circle_outline : Icons.link,
            color: const Color(0xFF2F7D32),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connected ? 'WhatsApp connected' : 'Connect WhatsApp',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  connected
                      ? 'Ready to send to selected contacts.'
                      : 'Link your WhatsApp before sending campaigns.',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF5E6672)),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.go('/'),
            child: Text(connected ? 'Manage' : 'Link'),
          ),
        ],
      ),
    );
  }
}

class _EmptyContacts extends StatelessWidget {
  const _EmptyContacts();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 28),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1E4E8)),
      ),
      child: const Column(
        children: [
          Icon(Icons.group_add_outlined, size: 42, color: Color(0xFF2F7D32)),
          SizedBox(height: 12),
          Text(
            'No contacts yet',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          SizedBox(height: 6),
          Text(
            'Import a CSV or add contacts manually to continue.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          backgroundColor: filled ? const Color(0xFF05060F) : Theme.of(context).colorScheme.surface,
          foregroundColor: filled ? Colors.white : Theme.of(context).colorScheme.onSurface,
          side: const BorderSide(color: Color(0xFF05060F), width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final state = context.read<BulkerState>();
    final initials = contact.name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();
    final colors = [
      const Color(0xFF101331),
      const Color(0xFFD9C48B),
      const Color(0xFF73F095),
      const Color(0xFFE6E8EF),
      const Color(0xFFCFC8F6),
    ];
    final color = colors[contact.name.length % colors.length];

    return Dismissible(
      key: ValueKey(contact.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => state.deleteContact(contact),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: const Color(0xFFFFE5E5),
        child: const Icon(Icons.delete_outline, color: Color(0xFFDA2A2A)),
      ),
      child: Container(
        height: 67,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
        ),
        child: Row(
          children: [
            Checkbox(
              value: contact.selected,
              onChanged: (_) => state.toggleContact(contact),
              activeColor: const Color(0xFF2F7D32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 24,
              backgroundColor: color,
              child: Text(
                initials.isEmpty ? '?' : initials,
                style: TextStyle(
                  color: color.computeLuminance() > .6 ? Colors.black : Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    contact.phone,
                    style: TextStyle(
                      fontSize: 12,
                      color: contact.isValid ? Theme.of(context).colorScheme.onSurface : const Color(0xFFD12C2C),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
