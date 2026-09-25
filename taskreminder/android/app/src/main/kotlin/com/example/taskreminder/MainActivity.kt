package com.example.taskreminder

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter <-> native bridge. Flutter schedules/cancels alarms here; the real
 * work of waking up and speaking happens in ReminderBroadcastReceiver and
 * ReminderTtsService, which run independently of whether the Flutter engine
 * / app process is alive.
 */
class MainActivity : FlutterActivity() {

    private val channelName = "com.example.taskreminder/alarm"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scheduleSpokenAlarm" -> {
                        val alarmId = call.argument<Int>("alarmId")!!
                        val triggerAtMillis = call.argument<Long>("triggerAtMillis")!!
                        val text = call.argument<String>("text")!!
                        val languageCode = call.argument<String>("languageCode")!!
                        scheduleAlarm(alarmId, triggerAtMillis, text, languageCode)
                        result.success(null)
                    }
                    "cancelSpokenAlarm" -> {
                        val alarmId = call.argument<Int>("alarmId")!!
                        cancelAlarm(alarmId)
                        result.success(null)
                    }
                    "requestReliabilityPermissions" -> {
                        requestBatteryOptimizationExemption()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun scheduleAlarm(
        alarmId: Int,
        triggerAtMillis: Long,
        text: String,
        languageCode: String
    ) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, ReminderBroadcastReceiver::class.java).apply {
            putExtra(ReminderBroadcastReceiver.EXTRA_ALARM_ID, alarmId)
            putExtra(ReminderBroadcastReceiver.EXTRA_TEXT, text)
            putExtra(ReminderBroadcastReceiver.EXTRA_LANGUAGE, languageCode)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            alarmId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // setExactAndAllowWhileIdle fires even during Doze, which is what
        // lets a reminder speak on time while the phone has been idle in a
        // pocket for hours. This is the same class of API alarm-clock apps use.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (alarmManager.canScheduleExactAlarms()) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent
                )
            } else {
                // Falls back to an inexact alarm; the app also requests the
                // exact-alarm permission from NotificationService.init().
                alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
            }
        } else {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent
            )
        }
    }

    private fun cancelAlarm(alarmId: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, ReminderBroadcastReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            alarmId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()
    }

    /** Battery optimisation can delay or drop alarms on some OEM skins. */
    private fun requestBatteryOptimizationExemption() {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = android.net.Uri.parse("package:$packageName")
            }
            startActivity(intent)
        }
    }
}
