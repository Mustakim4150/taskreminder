package com.example.taskreminder

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import androidx.core.app.NotificationCompat
import java.util.Locale

/**
 * This is the piece that makes reminders "speak aloud even in silent mode".
 *
 * How the bypass works:
 *  - Android's ringer/silent/vibrate mode mutes the RING and NOTIFICATION
 *    audio streams, but it does NOT mute the ALARM stream (this is why an
 *    alarm clock app still rings when your phone is silenced).
 *  - We create a native android.speech.tts.TextToSpeech engine and pass
 *    Engine.KEY_PARAM_STREAM = STREAM_ALARM in the speak() params, so the
 *    synthesized audio is routed onto that stream.
 *  - We also request AudioFocus with AudioAttributes.USAGE_ALARM, which
 *    tells the system "treat this like an alarm" (ducking/pausing other
 *    audio, and — critically — ignoring Do-Not-Disturb's stream muting for
 *    everything except priority-only DND profiles that explicitly block
 *    alarms too).
 *  - Running inside a foreground Service (not just an Activity) means this
 *    works even if the user isn't currently in the app, as long as the OS
 *    delivered the AlarmManager broadcast that started us.
 *
 * Limits: a user-enabled "Total silence" DND mode on some OEMs can still
 * mute the alarm stream by design — there is no API to override that, by
 * Android's own policy (same restriction every alarm-clock app has).
 */
class ReminderTtsService : Service(), TextToSpeech.OnInitListener {

    companion object {
        const val EXTRA_TEXT = "text"
        const val EXTRA_LANGUAGE = "languageCode"
        const val EXTRA_ALARM_ID = "alarmId"
        private const val NOTIF_CHANNEL_ID = "reminder_tts_service"
        private const val NOTIF_ID = 9001
    }

    private var tts: TextToSpeech? = null
    private var pendingText: String = ""
    private var pendingLanguage: String = "en-US"
    private lateinit var audioManager: AudioManager
    private var focusRequest: AudioFocusRequest? = null

    override fun onCreate() {
        super.onCreate()
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        pendingText = intent?.getStringExtra(EXTRA_TEXT) ?: return START_NOT_STICKY
        pendingLanguage = intent.getStringExtra(EXTRA_LANGUAGE) ?: "en-US"

        startForeground(NOTIF_ID, buildForegroundNotification())
        requestAlarmAudioFocus()
        tts = TextToSpeech(this, this)
        return START_NOT_STICKY
    }

    override fun onInit(status: Int) {
        if (status != TextToSpeech.SUCCESS) {
            stopSelfCleanly()
            return
        }
        val locale = if (pendingLanguage.startsWith("hi")) Locale("hi", "IN") else Locale.US
        val result = tts?.setLanguage(locale)
        if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
            // Fall back to English if the Hindi voice pack isn't installed.
            tts?.setLanguage(Locale.US)
        }

        tts?.setSpeechRate(0.9f)
        tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) {}
            override fun onDone(utteranceId: String?) = stopSelfCleanly()
            override fun onError(utteranceId: String?) = stopSelfCleanly()
        })

        // The key line: force the ALARM stream so silent/vibrate mode
        // does not mute this speech.
        val params = Bundle().apply {
            putInt(TextToSpeech.Engine.KEY_PARAM_STREAM, AudioManager.STREAM_ALARM)
        }
        tts?.speak(pendingText, TextToSpeech.QUEUE_FLUSH, params, "reminder_utterance")
    }

    private fun requestAlarmAudioFocus() {
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(attrs)
                .build()
            audioManager.requestAudioFocus(focusRequest!!)
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(
                null, AudioManager.STREAM_ALARM, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT
            )
        }

        // Make sure the alarm stream volume is audible even if the user has
        // it turned all the way down (mirrors what alarm-clock apps do).
        val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
        val currentVol = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
        if (currentVol < maxVol / 2) {
            audioManager.setStreamVolume(AudioManager.STREAM_ALARM, maxVol / 2, 0)
        }
    }

    private fun buildForegroundNotification(): android.app.Notification {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIF_CHANNEL_ID,
                "Speaking reminder",
                NotificationManager.IMPORTANCE_LOW
            )
            manager.createNotificationChannel(channel)
        }
        return NotificationCompat.Builder(this, NOTIF_CHANNEL_ID)
            .setContentTitle("Speaking your reminder")
            .setContentText(pendingText.take(60))
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setOngoing(true)
            .build()
    }

    private fun stopSelfCleanly() {
        focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
        tts?.stop()
        tts?.shutdown()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
        tts?.shutdown()
        super.onDestroy()
    }
}
