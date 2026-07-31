class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type;
  final String? relatedId;
  final bool read;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.relatedId,
    this.read = false,
  });

  factory NotificationModel.fromMap(String id, Map<String, dynamic> map) => NotificationModel(
        id: id,
        title: map['title'] ?? '',
        body: map['body'] ?? '',
        type: map['type'] ?? '',
        relatedId: map['relatedId'],
        read: map['read'] ?? false,
      );
}
