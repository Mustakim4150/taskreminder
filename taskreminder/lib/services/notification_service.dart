import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../models/task_model.dart';
import 'alarm_channel.dart';
import 'db_service.dart';
import 'tts_service.dart';

/// Schedules both reminder types for a task and cancels them on demand.
///
/// Two things fire per task, independently:
///  1. Night-before reminder at 22:00 the day before scheduledAt.
///  2. Day-of reminder at the exact scheduledAt time.
///
/// Each fires (a) a visible/audible local notification, so the user has a
/// record even if TTS is missed, and (b) a spoken reminder that is designed
/// to bypass silent mode (native alarm+TTS on Android; AVAudioSession
/// `.playback` TTS on iOS once the app is foregrounded via the notification).
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'task_reminders';
  static const _channelName = 'Task Reminders';
  static const _channelDesc =
      'Night-before and day-of spoken reminders for scheduled tasks';

  Future<void> init() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(DateTime.now().timeZoneName == 'IST'
        ? 'Asia/Kolkata'
        : tz.local.name));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.max,
        playSound: true,
        // Full-screen intent + max importance ensures the notification (and
        // the alarm that triggers alongside it) surfaces even on a locked,
        // Do-Not-Disturb device, mirroring how alarm-clock apps behave.
      ));
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
      await AlarmChannel.requestReliabilityPermissions();
    }
  }

  /// Called when the user taps a notification (mainly relevant on iOS,
  /// where this is what brings the app to the foreground so TtsService can
  /// actually speak the reminder aloud, bypassing the mute switch).
  static Future<void> _onNotificationTapped(
      NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null) return;
    final parts = payload.split('|'); // "text|hindi|dayOf/nightBefore"
    if (parts.length < 2) return;
    final text = parts[0];
    final hindi = parts[1] == 'hi';
    await TtsService.instance
        .speak(text, hindi ? TaskLanguage.hindi : TaskLanguage.english);
  }

  /// Schedules both reminders for [task]. Skips a trigger that is already in
  /// the past (e.g. task created same-day, after 10pm).
  Future<void> scheduleForTask(TaskModel task) async {
    final hindi = task.language == TaskLanguage.hindi;
    final nightText =
        TtsService.buildNightBeforeText(task, hindi: hindi);
    final dayText = TtsService.buildDayOfText(task, hindi: hindi);

    if (task.nightBeforeTriggerAt.isAfter(DateTime.now())) {
      await _scheduleVisibleNotification(
        id: task.nightBeforeNotificationId,
        title: hindi ? 'कल का कार्यक्रम' : "Tomorrow's schedule",
        body: nightText,
        triggerAt: task.nightBeforeTriggerAt,
        payload: '$nightText|${hindi ? 'hi' : 'en'}|night',
      );
      await AlarmChannel.scheduleSpokenAlarm(
        alarmId: task.nightBeforeNotificationId,
        triggerAt: task.nightBeforeTriggerAt,
        text: nightText,
        languageCode: hindi ? 'hi-IN' : 'en-US',
      );
    }

    if (task.scheduledAt.isAfter(DateTime.now())) {
      await _scheduleVisibleNotification(
        id: task.dayOfNotificationId,
        title: hindi ? 'अभी का कार्य' : 'Task due now',
        body: dayText,
        triggerAt: task.scheduledAt,
        payload: '$dayText|${hindi ? 'hi' : 'en'}|dayof',
      );
      await AlarmChannel.scheduleSpokenAlarm(
        alarmId: task.dayOfNotificationId,
        triggerAt: task.scheduledAt,
        text: dayText,
        languageCode: hindi ? 'hi-IN' : 'en-US',
      );
    }
  }

  /// Re-arms alarms for every still-future, non-cancelled task. Native
  /// AlarmManager entries (Android) do not survive a device reboot, so this
  /// is called once on every app start (see main.dart) as a lightweight
  /// safety net — scheduling is idempotent since notification/alarm IDs are
  /// deterministic per task.
  Future<void> resyncAllActiveTasks() async {
    final tasks = await DbService.instance.getActiveTasks();
    for (final task in tasks) {
      await scheduleForTask(task);
    }
  }

  Future<void> cancelForTask(TaskModel task) async {
    await _plugin.cancel(task.nightBeforeNotificationId);
    await _plugin.cancel(task.dayOfNotificationId);
    await AlarmChannel.cancelSpokenAlarm(task.nightBeforeNotificationId);
    await AlarmChannel.cancelSpokenAlarm(task.dayOfNotificationId);
  }

  Future<void> _scheduleVisibleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime triggerAt,
    required String payload,
  }) async {
    final tzTime = tz.TZDateTime.from(triggerAt, tz.local);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
        iOS: DarwinNotificationDetails(
          interruptionLevel: InterruptionLevel.timeSensitive,
          presentSound: true,
          presentAlert: true,
        ),
      ),
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
