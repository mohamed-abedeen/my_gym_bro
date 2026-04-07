import 'dart:convert';
import '../../../core/database/app_database.dart';

/// The type of a DM message.
enum DmMessageType { text, image, schedule }

extension DmMessageTypeX on DmMessageType {
  String get value => name; 
  static DmMessageType fromString(String s) =>
      DmMessageType.values.firstWhere(
        (e) => e.name == s,
        orElse: () => DmMessageType.text,
      );
}

/// Extensions on Drift's generated [DmMessage] class to add DM-specific helpers.
extension DmMessageHelpers on DmMessage {
  DmMessageType get messageType => DmMessageTypeX.fromString(type);

  /// Parse the `body` as a [SharedSchedule] when [type] == 'schedule'.
  SharedSchedule? get sharedSchedule {
    if (messageType != DmMessageType.schedule || body == null) return null;
    try {
      return SharedSchedule.fromJson(
          jsonDecode(body!) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

/// Payload embedded in a schedule-type message body (JSON).
class SharedSchedule {
  final String name;
  final List<SharedScheduleDay> days;

  const SharedSchedule({required this.name, required this.days});

  factory SharedSchedule.fromJson(Map<String, dynamic> json) => SharedSchedule(
        name: json['name'] as String? ?? 'Schedule',
        days: (json['days'] as List<dynamic>? ?? [])
            .map((d) => SharedScheduleDay.fromJson(d as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'days': days.map((d) => d.toJson()).toList(),
      };

  String toJsonString() => jsonEncode(toJson());
}

/// A single day within a shared schedule payload.
class SharedScheduleDay {
  final int dayIndex;
  final String? label;
  final bool isRestDay;

  const SharedScheduleDay({
    required this.dayIndex,
    this.label,
    required this.isRestDay,
  });

  factory SharedScheduleDay.fromJson(Map<String, dynamic> json) =>
      SharedScheduleDay(
        dayIndex: json['dayIndex'] as int? ?? 0,
        label: json['label'] as String?,
        isRestDay: json['isRestDay'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'dayIndex': dayIndex,
        'label': label,
        'isRestDay': isRestDay,
      };
}

/// A DM conversation summary (one row in the inbox list).
class DmConversation {
  final String id;
  final String otherUserId;
  final String otherUserName;
  final String? otherAvatarUrl;
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final int unreadCount;

  const DmConversation({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    this.otherAvatarUrl,
    this.lastMessageText,
    this.lastMessageAt,
    this.unreadCount = 0,
  });
}
