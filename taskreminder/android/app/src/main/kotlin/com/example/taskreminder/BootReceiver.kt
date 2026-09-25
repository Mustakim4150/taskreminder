package com.example.taskreminder

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * AlarmManager entries do NOT survive a device reboot, so every alarm must
 * be re-scheduled afterwards. Because the task list lives in Flutter's
 * sqflite database, the simplest reliable approach — used here — is to
 * re-schedule from Dart: NotificationService.resyncAllActiveTasks() is
 * called every time the app starts (see main.dart), which is a no-op if
 * nothing changed and cheaply re-creates any alarms lost to a reboot.
 *
 * For a "never open the app" guarantee across reboots, upgrade this
 * receiver to run a headless Dart entrypoint via
 * `flutter_local_notifications`' `FlutterCallbackInformation` /
 * `android_alarm_manager_plus`'s headless isolate support, which can read
 * sqflite and re-arm alarms without the user launching the UI. That is a
 * reasonable v2 enhancement; documented here as a known follow-up rather
 * than silently glossed over.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            // Intentionally left minimal — see class doc above.
            // A production build should trigger a headless resync here.
        }
    }
}
