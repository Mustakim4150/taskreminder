/// Supported input/output languages for a task's description.
enum TaskLanguage { english, hindi }

/// Core Task entity shared by local DB, notification scheduler and API sync.
class TaskModel {
  final String id; // uuid, generated client-side so it works offline
  final String description; // raw text, may be Hindi or English
  final TaskLanguage language;
  final DateTime scheduledAt; // exact date + time of the task
  final bool nightBeforeReminderSent;
  final bool dayOfReminderSent;
  final bool isCancelled;
  final DateTime createdAt;

  const TaskModel({
    required this.id,
    required this.description,
    required this.language,
    required this.scheduledAt,
    this.nightBeforeReminderSent = false,
    this.dayOfReminderSent = false,
    this.isCancelled = false,
    required this.createdAt,
  });

  /// 10:00 PM the day before [scheduledAt]. If the task itself is created
  /// less than 24h out, the caller is responsible for skipping this trigger.
  DateTime get nightBeforeTriggerAt {
    final dayBefore = scheduledAt.subtract(const Duration(days: 1));
    return DateTime(dayBefore.year, dayBefore.month, dayBefore.day, 22, 0, 0);
  }

  /// Stable, collision-resistant int IDs for the OS notification/alarm APIs,
  /// which require 32-bit integer IDs rather than the string uuid.
  int get nightBeforeNotificationId => _hashToInt('$id-night');
  int get dayOfNotificationId => _hashToInt('$id-day');

  static int _hashToInt(String input) {
    // Simple, deterministic 31-bit hash (avoids negative IDs).
    var hash = 0;
    for (final unit in input.codeUnits) {
      hash = (hash * 31 + unit) & 0x7FFFFFFF;
    }
    return hash;
  }

  TaskModel copyWith({
    String? description,
    TaskLanguage? language,
    DateTime? scheduledAt,
    bool? nightBeforeReminderSent,
    bool? dayOfReminderSent,
    bool? isCancelled,
  }) {
    return TaskModel(
      id: id,
      description: description ?? this.description,
      language: language ?? this.language,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      nightBeforeReminderSent:
          nightBeforeReminderSent ?? this.nightBeforeReminderSent,
      dayOfReminderSent: dayOfReminderSent ?? this.dayOfReminderSent,
      isCancelled: isCancelled ?? this.isCancelled,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'description': description,
        'language': language.name,
        'scheduledAt': scheduledAt.toIso8601String(),
        'nightBeforeReminderSent': nightBeforeReminderSent ? 1 : 0,
        'dayOfReminderSent': dayOfReminderSent ? 1 : 0,
        'isCancelled': isCancelled ? 1 : 0,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TaskModel.fromMap(Map<String, dynamic> map) => TaskModel(
        id: map['id'] as String,
        description: map['description'] as String,
        language: (map['language'] as String) == 'hindi'
            ? TaskLanguage.hindi
            : TaskLanguage.english,
        scheduledAt: DateTime.parse(map['scheduledAt'] as String),
        nightBeforeReminderSent: (map['nightBeforeReminderSent'] as int) == 1,
        dayOfReminderSent: (map['dayOfReminderSent'] as int) == 1,
        isCancelled: (map['isCancelled'] as int) == 1,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'language': language.name,
        'scheduledAt': scheduledAt.toIso8601String(),
        'isCancelled': isCancelled,
      };

  factory TaskModel.fromJson(Map<String, dynamic> json) => TaskModel(
        id: json['id'] as String,
        description: json['description'] as String,
        language: (json['language'] as String) == 'hindi'
            ? TaskLanguage.hindi
            : TaskLanguage.english,
        scheduledAt: DateTime.parse(json['scheduledAt'] as String),
        isCancelled: json['isCancelled'] as bool? ?? false,
        createdAt: DateTime.now(),
      );
}
