package com.example.taskreminder

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Receives the AlarmManager broadcast at the exact scheduled instant and
 * immediately starts ReminderTtsService as a foreground service, which is
 * what actually plays the spoken reminder on the ALARM stream.
 *
 * Runs independently of the Flutter engine / Activity, so it fires even if
 * the app was swiped away from recents.
 */
class ReminderBroadcastReceiver : BroadcastReceiver() {

    companion object {
        const val EXTRA_ALARM_ID = "alarmId"
        const val EXTRA_TEXT = "text"
        const val EXTRA_LANGUAGE = "languageCode"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val text = intent.getStringExtra(EXTRA_TEXT) ?: return
        val languageCode = intent.getStringExtra(EXTRA_LANGUAGE) ?: "en-US"
        val alarmId = intent.getIntExtra(EXTRA_ALARM_ID, 0)

        val serviceIntent = Intent(context, ReminderTtsService::class.java).apply {
            putExtra(ReminderTtsService.EXTRA_TEXT, text)
            putExtra(ReminderTtsService.EXTRA_LANGUAGE, languageCode)
            putExtra(ReminderTtsService.EXTRA_ALARM_ID, alarmId)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}
