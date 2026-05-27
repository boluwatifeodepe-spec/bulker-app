class CampaignMessage {
  CampaignMessage({
    this.mediaPath,
    this.mediaType,
    this.caption = '',
    this.name = '',
    this.scheduledFor,
  });

  String? mediaPath;
  String? mediaType;
  String caption;
  String name;
  DateTime? scheduledFor;

  bool get isReady => mediaPath != null && caption.trim().isNotEmpty;
  String get displayName => name.trim().isEmpty ? 'Untitled Campaign' : name.trim();
}
