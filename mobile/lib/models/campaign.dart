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
  });

  final String id;
  final String name;
  final String status;
  final int sent;
  final int failed;
  final int total;
  final DateTime? createdAt;
  final DateTime? scheduledFor;

  factory Campaign.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse('$value');
    }

    return Campaign(
      id: json['id'] as String? ?? json['campaignId'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled Campaign',
      status: json['status'] as String? ?? 'unknown',
      sent: json['sent'] as int? ?? 0,
      failed: json['failed'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
      createdAt: parseDate(json['createdAt']),
      scheduledFor: parseDate(json['scheduledFor']),
    );
  }
}
