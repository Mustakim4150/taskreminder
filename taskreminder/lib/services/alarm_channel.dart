import 'dart:io';
import 'package:flutter/services.dart';

/// Bridges to native platform code so that spoken reminders can bypass
/// silent/vibrate mode. See android/.../ReminderTtsService.kt for the
/// Android implementation (AudioAttributes.USAGE_ALARM + STREAM_ALARM).
///
/// On Android, scheduling here uses AlarmManager.setExactAndAllowWhileIdle
/// so the reminder fires even if the app is killed and the device is dozing.
/// On iOS, true silent-switch bypass while the app is fully backgrounded is
/// only possible with Apple's Critical Alerts entitlement (see README). This
/// channel exposes the same API on iOS for forward-compatibility, but the
/// iOS side currently schedules a local notification only; speaking happens
/// via TtsService when the app is foregrounded/opened from that notification.
class AlarmChannel {
  static const MethodChannel _channel =
      MethodChannel('com.example.taskreminder/alarm');

  /// Schedules a native exact alarm that will speak [text] at [triggerAt].
  /// [alarmId] must be a stable 32-bit int (see TaskModel.*NotificationId).
  static Future<void> scheduleSpokenAlarm({
    required int alarmId,
    required DateTime triggerAt,
    required String text,
    required String languageCode, // 'en-US' or 'hi-IN'
  }) async {
    if (!Platform.isAndroid) return; // iOS handled by NotificationService
    await _channel.invokeMethod('scheduleSpokenAlarm', {
      'alarmId': alarmId,
      'triggerAtMillis': triggerAt.millisecondsSinceEpoch,
      'text': text,
      'languageCode': languageCode,
    });
  }

  static Future<void> cancelSpokenAlarm(int alarmId) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod('cancelSpokenAlarm', {'alarmId': alarmId});
  }

  /// Requests the user allow "exact alarms" (Android 12+) and disable
  /// battery optimisation for this app, both required for reliable firing.
  static Future<void> requestReliabilityPermissions() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod('requestReliabilityPermissions');
  }
}
