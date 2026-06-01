import 'dart:io';

import 'package:bulker/config/constants.dart';
import 'package:bulker/providers/bulker_state.dart';
import 'package:bulker/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class ComposeMessageScreen extends StatefulWidget {
  const ComposeMessageScreen({super.key});

  @override
  State<ComposeMessageScreen> createState() => _ComposeMessageScreenState();
}

class _ComposeMessageScreenState extends State<ComposeMessageScreen> {
  bool _previewEnabled = false;
  bool _syncedInitialText = false;
  final _campaignNameController = TextEditingController();
  final _captionController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_syncedInitialText) return;
    final message = context.read<BulkerState>().message;
    _campaignNameController.text = message.name;
    _captionController.text = message.caption;
    _syncedInitialText = true;
  }

  @override
  void dispose() {
    _campaignNameController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BulkerState>();
    final mediaPath = state.message.mediaPath;
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 22),
      children: [
        Text('Compose Message', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        const Text(
          'Create and bulk-send high-impact media messages.',
          style: TextStyle(fontSize: 12, color: Color(0xFF333842)),
        ),
        const SizedBox(height: 22),
        TextField(
          controller: _campaignNameController,
          onChanged: state.updateCampaignName,
          decoration: InputDecoration(
            labelText: 'Campaign name',
            hintText: 'Easter Sunday Message',
            filled: true,
            fillColor: scheme.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 26),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _showMediaPicker(context),
          child: Container(
            height: 230,
            decoration: BoxDecoration(
              color: mediaPath == null ? scheme.surface : Colors.black,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFB7BCC3),
                style: BorderStyle.solid,
              ),
            ),
            child: mediaPath == null
                ? const _UploadPlaceholder()
                : state.message.mediaType == 'video'
                    ? const Center(
                        child: Icon(Icons.play_circle_fill, color: Colors.white, size: 76),
                      )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(mediaPath), fit: BoxFit.cover),
                  ),
          ),
        ),
        const SizedBox(height: 26),
        const Text(
          'CAPTION',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        const SizedBox(height: 8),
        Container(
          height: 140,
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _captionController,
            maxLines: null,
            maxLength: AppConstants.maxCaptionLength,
            onChanged: state.updateCaption,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Write your message...',
              hintStyle: TextStyle(color: Color(0xFF9AA1AA), fontSize: 13),
              counterStyle: TextStyle(fontSize: 9, color: Color(0xFF69707A)),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _ScheduleTile(
          scheduledFor: state.message.scheduledFor,
          onPick: () => _pickSchedule(context),
          onClear: () => state.updateScheduledFor(null),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 12)],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFC8F9D6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.remove_red_eye_outlined, color: Color(0xFF2F7D32)),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('See Preview', style: TextStyle(fontWeight: FontWeight.w900)),
                    SizedBox(height: 3),
                    Text('Check visual formatting', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              Switch(
                value: _previewEnabled,
                onChanged: state.message.isReady
                    ? (value) {
                        setState(() => _previewEnabled = value);
                        if (value) _showPreview(context);
                      }
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        PrimaryButton(
          label: 'Next: Select Contacts',
          icon: Icons.arrow_forward,
          color: const Color(0xFF05060F),
          onPressed: state.message.isReady ? () => context.go('/contacts') : null,
        ),
      ],
    );
  }

  void _showPreview(BuildContext context) {
    final state = context.read<BulkerState>();
    final mediaPath = state.message.mediaPath;
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'WhatsApp Preview',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              if (mediaPath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: state.message.mediaType == 'video'
                      ? Container(
                          height: 180,
                          color: Colors.black,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.play_circle_fill,
                            color: Colors.white,
                            size: 64,
                          ),
                        )
                      : Image.file(
                          File(mediaPath),
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                ),
              const SizedBox(height: 12),
              Text(
                state.message.caption,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close Preview'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickSchedule(BuildContext context) async {
    final state = context.read<BulkerState>();
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: now,
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 10))),
    );
    if (time == null) return;
    state.updateScheduledFor(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  void _showMediaPicker(BuildContext context) {
    final state = context.read<BulkerState>();
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Upload Image'),
              onTap: () {
                Navigator.pop(context);
                state.pickMedia(ImageSource.gallery, video: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Upload Video'),
              onTap: () {
                Navigator.pop(context);
                state.pickMedia(ImageSource.gallery, video: true);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile({
    required this.scheduledFor,
    required this.onPick,
    required this.onClear,
  });

  final DateTime? scheduledFor;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, color: Color(0xFF2F7D32)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              scheduledFor == null
                  ? 'Send now'
                  : 'Scheduled for $scheduledFor',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          if (scheduledFor != null)
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close),
            ),
          OutlinedButton(
            onPressed: onPick,
            child: const Text('Schedule'),
          ),
        ],
      ),
    );
  }
}

class _UploadPlaceholder extends StatelessWidget {
  const _UploadPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(color: Color(0xFF05060F), shape: BoxShape.circle),
            child: const Icon(Icons.add, color: Colors.white, size: 33),
          ),
          const SizedBox(height: 18),
          const Text(
            'Upload Image or Video',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          ),
          const SizedBox(height: 4),
          const Text(
            'PNG, JPG, MP4 up to 50MB',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
