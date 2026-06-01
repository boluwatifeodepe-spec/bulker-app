import 'package:bulker/models/campaign.dart';
import 'package:bulker/providers/bulker_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BulkerState>();
    return RefreshIndicator(
      onRefresh: state.loadCampaignHistory,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 30, 20, 22),
        children: [
          Text('Message History', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          const Text('Review previous blasts and retry failed recipients.'),
          const SizedBox(height: 20),
          if (state.isLoadingHistory)
            const Center(child: CircularProgressIndicator())
          else if (state.campaignHistory.isEmpty)
            const _EmptyHistory()
          else
            ...state.campaignHistory.map((campaign) => _CampaignCard(campaign: campaign)),
        ],
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({required this.campaign});

  final Campaign campaign;

  @override
  Widget build(BuildContext context) {
    final state = context.read<BulkerState>();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1E4E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(campaign.name, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(
            '${campaign.status.toUpperCase()} · ${campaign.sent}/${campaign.total} sent · ${campaign.failed} failed · ${campaign.rejected} rejected',
            style: const TextStyle(fontSize: 12),
          ),
          if (campaign.stoppedReason != null) ...[
            const SizedBox(height: 8),
            Text(
              campaign.stoppedReason!,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFB42318),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (campaign.scheduledFor != null) ...[
            const SizedBox(height: 6),
            Text(
              'Scheduled: ${campaign.scheduledFor}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF5F6673)),
            ),
          ],
          if (campaign.failed > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => state.retryFailed(campaign),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry Failed'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showReportLink(context, state, campaign),
                    icon: const Icon(Icons.file_download_outlined),
                    label: const Text('Report CSV'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showReportLink(BuildContext context, BulkerState state, Campaign campaign) {
    final url = state.campaignReportUrl(campaign.id);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Campaign Report'),
        content: SelectableText(url),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Column(
        children: [
          Icon(Icons.history, size: 42, color: Color(0xFF2F7D32)),
          SizedBox(height: 12),
          Text('No campaigns yet', style: TextStyle(fontWeight: FontWeight.w900)),
          SizedBox(height: 6),
          Text('Sent and scheduled campaigns will appear here.'),
        ],
      ),
    );
  }
}
