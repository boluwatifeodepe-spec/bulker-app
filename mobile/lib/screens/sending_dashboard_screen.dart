import 'dart:math' as math;

import 'package:bulker/models/activity_log.dart';
import 'package:bulker/providers/bulker_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SendingDashboardScreen extends StatelessWidget {
  const SendingDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BulkerState>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      children: [
        Text('Sending Campaign', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(
          state.campaignId == null
              ? 'No active campaign'
              : 'Campaign ${state.campaignId}',
          style: const TextStyle(fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
        if (state.lastError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE8E8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              state.lastError!,
              style: const TextStyle(
                color: Color(0xFFB42318),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
        const SizedBox(height: 22),
        Container(
          height: 398,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 18)],
          ),
          child: Stack(
            children: [
              Positioned(
                right: 0,
                top: 0,
                child: Icon(
                  Icons.rocket_launch_outlined,
                  color: const Color(0xFFE8EAEE).withOpacity(.85),
                  size: 112,
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 210,
                      height: 210,
                      child: CustomPaint(
                        painter: _ProgressPainter(progress: state.progress),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${state.percentage}%',
                                style: const TextStyle(
                                  fontSize: 46,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0,
                                ),
                              ),
                              Text(
                                '${state.sent}/${state.total} sent · ${state.failed} failed',
                                style: const TextStyle(
                                  color: Color(0xFF2F7D32),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC8F9D6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        state.campaignComplete
                            ? '●  Campaign complete'
                            : state.campaignId == null
                                ? '●  Waiting for campaign'
                                : '●  Sending in real time...',
                        style: TextStyle(
                          color: const Color(0xFF2F7D32),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 58,
                child: OutlinedButton.icon(
                  onPressed: state.campaignId == null ? null : state.togglePause,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Colors.black, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  icon: Icon(state.isPaused ? Icons.play_arrow : Icons.pause),
                  label: Text(state.isPaused ? 'Resume' : 'Pause'),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: SizedBox(
                height: 58,
                child: OutlinedButton.icon(
                  onPressed: state.campaignId == null ? null : state.cancelCampaign,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE32929),
                    side: const BorderSide(color: Color(0xFFE32929), width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel\nCampaign', textAlign: TextAlign.center),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        Row(
          children: const [
            Text('Activity Log', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
            Spacer(),
            Text(
              'Real-time update',
              style: TextStyle(
                color: Color(0xFF2F7D32),
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...state.activity.map((item) => _ActivityTile(item: item)),
      ],
    );
  }
}

class _ProgressPainter extends CustomPainter {
  _ProgressPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 10;
    const stroke = 10.0;
    final background = Paint()
      ..color = const Color(0xFFE8EAEE)
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final foreground = Paint()
      ..color = const Color(0xFF2F7D32)
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, background);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0, 1).toDouble(),
      false,
      foreground,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item});

  final ActivityLog item;

  @override
  Widget build(BuildContext context) {
    final sent = item.status == 'sent';
    final failed = item.status == 'failed';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: sent
                ? const Color(0xFFE0F4E6)
                : failed
                    ? const Color(0xFFFFE8E8)
                    : const Color(0xFFE7E9ED),
            child: Icon(
              sent
                  ? Icons.check_circle_outline
                  : failed
                      ? Icons.error_outline
                      : Icons.sync,
              color: sent
                  ? const Color(0xFF2F7D32)
                  : failed
                      ? const Color(0xFFB42318)
                      : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sent
                      ? 'Sent to ${item.name}'
                      : failed
                          ? 'Failed for ${item.name}'
                          : 'Waiting for ${item.name}',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                ),
                Text(item.phone, style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
          Text(
            item.timeLabel,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
