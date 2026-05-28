import 'package:bulker/providers/bulker_state.dart';
import 'package:bulker/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class ConnectWhatsAppScreen extends StatefulWidget {
  const ConnectWhatsAppScreen({super.key});

  @override
  State<ConnectWhatsAppScreen> createState() => _ConnectWhatsAppScreenState();
}

class _ConnectWhatsAppScreenState extends State<ConnectWhatsAppScreen> {
  final _phoneController = TextEditingController();
  _CountryCode _country = _countryCodes.first;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BulkerState>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      children: [
        Text(
          'Link via Phone Number',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Link your WhatsApp account using a pairing code\ninstead of scanning.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, height: 1.35),
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(color: Color(0x12000000), blurRadius: 18, offset: Offset(0, 8)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Phone Number',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Container(
                    width: 82,
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFC8CDD4)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<_CountryCode>(
                        value: _country,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                        items: _countryCodes
                            .map(
                              (country) => DropdownMenuItem(
                                value: country,
                                child: Text(
                                  country.label,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (country) {
                          if (country == null) return;
                          setState(() => _country = country);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: '812 3456 7890',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                ],
              ),
              if (state.pairingCode != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F9ED),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFB9EDC6)),
                  ),
                  child: Text(
                    state.pairingCode!,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: Color(0xFF2F7D32),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              PrimaryButton(
                label: state.isBusy ? 'Generating...' : 'Generate Code',
                onPressed: state.isBusy
                    ? null
                    : () => state.requestPairingCode(_fullPhoneNumber),
              ),
              if (state.whatsAppReady) ...[
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Continue to Compose',
                  icon: Icons.arrow_forward,
                  color: const Color(0xFF05060F),
                  onPressed: () => context.go('/compose'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Step-by-step instructions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 14),
        const _InstructionStep(
          number: 1,
          text: 'Open WhatsApp on your phone.',
        ),
        const _InstructionStep(
          number: 2,
          text: 'Tap Menu or Settings and select Linked Devices.',
        ),
        const _InstructionStep(
          number: 3,
          text: 'Tap on Link a Device, then Link with phone number instead.',
        ),
        const _InstructionStep(
          number: 4,
          text: 'Enter the code shown above on your phone.',
        ),
        const SizedBox(height: 34),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE3E6EA)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                state.whatsAppReady
                    ? const Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Color(0xFF2F7D32),
                      )
                    : const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF2F7D32),
                        ),
                      ),
                const SizedBox(width: 10),
                Text(
                  state.pairingStatus,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        const Center(
          child: Text(
            'ⓘ  Need help connecting?',
            style: TextStyle(
              color: Color(0xFF2F7D32),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        if (state.lastError != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE8E8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              state.lastError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFB42318),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextButton(
          onPressed: state.refreshWhatsAppStatus,
          child: const Text(
            'Refresh connection status',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  String get _fullPhoneNumber {
    var local = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    while (local.startsWith('0')) {
      local = local.substring(1);
    }
    return '${_country.dialCode}$local';
  }
}

class _CountryCode {
  const _CountryCode({
    required this.name,
    required this.dialCode,
    required this.flag,
  });

  final String name;
  final String dialCode;
  final String flag;

  String get label => '$flag +$dialCode';
}

const _countryCodes = [
  _CountryCode(name: 'Nigeria', dialCode: '234', flag: 'NG'),
  _CountryCode(name: 'Ghana', dialCode: '233', flag: 'GH'),
  _CountryCode(name: 'Kenya', dialCode: '254', flag: 'KE'),
  _CountryCode(name: 'South Africa', dialCode: '27', flag: 'ZA'),
  _CountryCode(name: 'United Kingdom', dialCode: '44', flag: 'UK'),
  _CountryCode(name: 'United States', dialCode: '1', flag: 'US'),
  _CountryCode(name: 'India', dialCode: '91', flag: 'IN'),
];

class _InstructionStep extends StatelessWidget {
  const _InstructionStep({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: const Color(0xFF05060F),
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, height: 1.28, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
