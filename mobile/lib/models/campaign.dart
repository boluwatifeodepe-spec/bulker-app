class Campaign {
  const Campaign({
    required this.id,
    required this.name,
    required this.status,
    required this.sent,
    required this.failed,
    required this.total,
    this.createdAt,
    this.scheduledFor,
    this.rejected = 0,
    this.stoppedReason,
  });

  final String id;
  final String name;
  final String status;
  final int sent;
  final int failed;
  final int total;
  final int rejected;
  final String? stoppedReason;
  final DateTime? createdAt;
  final DateTime? scheduledFor;

  factory Campaign.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse('$value');
    }

    int rejectedCount(dynamic value) {
      if (value is List) return value.length;
      if (value is int) return value;
      return 0;
    }

    return Campaign(
      id: json['id'] as String? ?? json['campaignId'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled Campaign',
      status: json['status'] as String? ?? 'unknown',
      sent: json['sent'] as int? ?? 0,
      failed: json['failed'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
      rejected: rejectedCount(json['rejected']),
      stoppedReason: json['stoppedReason'] as String?,
      createdAt: parseDate(json['createdAt']),
      scheduledFor: parseDate(json['scheduledFor']),
    );
  }
}
