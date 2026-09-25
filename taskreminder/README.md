# Task Reminder — Bilingual Voice Reminder App

A cross-platform (Flutter) task reminder app that **speaks reminders aloud**
the night before (10:00 PM) and again at the exact scheduled time — in
English or Hindi — and is engineered to keep speaking even when the phone is
in silent or vibrate mode. Includes an optional Node.js + MongoDB backend
for cross-device backup/sync.

> **Important, upfront:** this document and the attached source cannot be
> "installed" directly — a phone installs a compiled `.apk` (Android) or
> `.ipa` (iOS), not raw source code. Compiling requires the Flutter/Android
> SDK toolchain (and, for iOS, a Mac + Xcode + an Apple Developer account),
> none of which exist in the environment that generated this project. §0
> below gives you the fastest real path to an installed app on your phone.

---

## 0. Getting an Installable App Onto Your Phone

### Option A — Cloud build, no computer needed (recommended)
This project now includes `.github/workflows/build-apk.yml`, a GitHub
Actions workflow that compiles a real `app-release.apk` in the cloud every
time you push the code. You only need a free GitHub account — not Flutter,
not Android Studio, not even a laptop with much disk space.

1. Create a new **public or private** repo on github.com (e.g. `taskreminder`).
2. Upload the contents of the unzipped project to that repo — easiest via
   the GitHub web UI's "Add file → Upload files" (drag the whole folder),
   or via `git`:
   ```bash
   cd taskreminder
   git init
   git add .
   git commit -m "Initial commit"
   git branch -M main
   git remote add origin https://github.com/<you>/taskreminder.git
   git push -u origin main
   ```
3. On GitHub, open the **Actions** tab of your repo. A run called
   "Build Android APK" starts automatically (takes ~3–5 minutes).
4. When it finishes (green check), click into the run → scroll to
   **Artifacts** → download `taskreminder-app-release` (a zip containing
   `app-release.apk`).
5. Transfer that `.apk` to your Android phone (email it to yourself, use
   Google Drive, or a USB cable).
6. On the phone, tap the `.apk` file. If prompted, allow "Install from this
   source" / "Install unknown apps" for whichever app you opened it with
   (Files, Chrome, Gmail, etc.) — Android will ask this once per source app.
7. Tap **Install**. The app icon appears on your home screen.

This produces a genuinely installable, working APK — it's signed with a
default debug key, which is fine for installing on your own device but not
for publishing to the Play Store (see §8 for that).

### Option B — Build it yourself locally (Android)
If you'd rather build on your own machine:
```bash
# 1. Install Flutter: https://docs.flutter.dev/get-started/install
# 2. Install Android Studio (for the Android SDK) and accept licenses:
flutter doctor --android-licenses

cd taskreminder
flutter pub get
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```
Copy that `.apk` to your phone the same way as step 5–7 above.

Or skip the manual copy entirely and install straight to a phone connected
by USB (with Developer Options → USB debugging enabled):
```bash
flutter devices           # confirm your phone is detected
flutter install           # builds and installs directly over USB
```

### Option C — iOS
iOS is intentionally not covered by Option A: Apple requires every app,
even ones you install only on your own phone, to be signed with an Apple
Developer account and built on a Mac with Xcode — there's no cloud-CI
shortcut that avoids that requirement. If you have a Mac:
```bash
cd taskreminder/ios && pod install && cd ..
flutter build ipa --release   # requires a signing team set up in Xcode
```
Then install via Xcode ("Devices and Simulators" window) or TestFlight.
A free Apple ID lets you sideload onto your own device for 7 days at a
time; a paid Apple Developer Program membership ($99/yr) removes that limit
and is required for TestFlight/App Store distribution.

---



## 1. Architecture Overview

```
┌─────────────────────────────┐         ┌──────────────────────────────┐
│         Flutter App         │  HTTPS  │      Node.js Backend          │
│  (Android / iOS, offline-   │◄───────►│  Express + MongoDB (Atlas)    │
│   first, all scheduling &   │  sync   │  - stores tasks per user      │
│   TTS happens on-device)    │  only   │  - NOT on the critical path   │
└──────────────┬───────────────┘         │    for reminders to fire     │
               │                          └──────────────────────────────┘
    ┌──────────┴──────────┐
    │                     │
┌───▼────┐          ┌─────▼─────┐
│ sqflite │          │ flutter_  │
│ (local  │          │ local_    │
│  tasks) │          │ notifications│
└─────────┘          └─────┬─────┘
                            │ platform channel
                 ┌──────────┴───────────┐
                 │                      │
          ┌──────▼──────┐        ┌──────▼───────┐
          │   Android    │        │     iOS      │
          │ AlarmManager │        │ UNNotification│
          │      +       │        │      +       │
          │ Foreground   │        │ AVAudioSession│
          │ Service +    │        │  .playback    │
          │ native TTS on│        │  + flutter_tts│
          │ STREAM_ALARM │        │               │
          └──────────────┘        └───────────────┘
```

**Design principle: reminders never depend on the network or the backend.**
All scheduling and speech happen entirely on-device (local DB + OS alarm
APIs + on-device TTS engine), so a reminder fires correctly even in
airplane mode. The backend is purely for backup and multi-device sync.

---

## 2. Technology Stack

| Layer | Choice | Why |
|---|---|---|
| Frontend | **Flutter 3.x** (Dart) | One codebase for Android + iOS; still allows dropping to native Kotlin/Swift exactly where the OS forces you to (audio-stream routing, exact alarms). |
| Local storage | **sqflite** (SQLite) | Reliable offline task store; simple relational shape fits one `tasks` table. |
| Notifications | **flutter_local_notifications** + **timezone** | Cross-platform scheduling API, DST-safe via `timezone` package. |
| Voice (Android) | **Native Kotlin** `android.speech.tts.TextToSpeech` on `STREAM_ALARM`, run from a foreground `Service` started by an `AlarmManager` broadcast | The *only* reliable way to guarantee speech plays through silent/vibrate mode and survives the app being killed. |
| Voice (iOS) | **flutter_tts** (`AVSpeechSynthesizer`) with `AVAudioSession` category `.playback` | Bypasses the hardware mute switch; see §5 for the honest limitation on fully-killed-app delivery. |
| Backend | **Node.js + Express** | Small, well-understood REST layer. |
| Backend DB | **MongoDB (Atlas)** via Mongoose | Flexible schema, easy free-tier hosting, natural fit for per-user task documents. |
| Auth | **JWT**, device-id bootstrap (`/api/auth/device`) | Minimal viable identity for a personal-use deployment; swappable for real login. |

---

## 3. Project Layout

```
taskreminder/
├── pubspec.yaml
├── lib/
│   ├── main.dart                        # app entry, resyncs alarms on boot
│   ├── models/task_model.dart           # Task entity + trigger-time math
│   ├── services/
│   │   ├── db_service.dart              # sqflite CRUD
│   │   ├── notification_service.dart    # schedules visible notifications
│   │   ├── alarm_channel.dart           # MethodChannel -> native Android
│   │   ├── tts_service.dart             # Dart-side TTS (iOS + previews)
│   │   └── api_service.dart             # optional backend sync
│   ├── screens/
│   │   ├── home_screen.dart             # task list, cancel, preview
│   │   └── add_task_screen.dart         # bilingual task creation form
│   ├── widgets/task_tile.dart
│   └── l10n/strings.dart
├── android/app/src/main/
│   ├── AndroidManifest.xml              # permissions, receivers, service
│   └── kotlin/.../taskreminder/
│       ├── MainActivity.kt              # platform channel handler
│       ├── ReminderBroadcastReceiver.kt # fires at exact alarm time
│       ├── ReminderTtsService.kt        # ★ the silent-mode bypass ★
│       └── BootReceiver.kt              # reboot-recovery hook
├── android/{build.gradle, settings.gradle, gradle.properties,
│           app/build.gradle, app/src/main/res/...}
│                                         # standard Flutter/Gradle scaffold
│                                         # (needed to compile; app icon here
│                                         # is a placeholder — see §9 for note)
├── .github/workflows/build-apk.yml      # cloud-builds a real .apk on push
├── ios/Runner/AppDelegate.swift         # AVAudioSession .playback setup
└── backend/
    ├── server.js
    ├── models/Task.js
    ├── routes/tasks.js
    ├── middleware/auth.js
    └── package.json
```

---

## 4. How Scheduling Works

For every task, two independent triggers are armed:

1. **Night-before**: `TaskModel.nightBeforeTriggerAt` = 22:00 on
   `scheduledAt.date - 1 day`.
2. **Day-of**: exactly `scheduledAt`.

For each trigger, `NotificationService.scheduleForTask()`:
- Schedules a **visible** local notification (so there's always a fallback
  record even if audio is missed), using
  `AndroidScheduleMode.exactAllowWhileIdle` / iOS `.timeSensitive`.
- On Android, also calls `AlarmChannel.scheduleSpokenAlarm()`, which sets a
  **native** `AlarmManager.setExactAndAllowWhileIdle` alarm independent of
  Flutter's engine.

`TaskModel.nightBeforeNotificationId` / `dayOfNotificationId` derive a
stable 32-bit int ID from the task's uuid, so scheduling is naturally
idempotent (re-scheduling replaces rather than duplicates) and cancellation
just needs the `TaskModel` you already have.

Cancelling a task (`HomeScreen._cancelTask`) marks it cancelled in the DB
and calls `NotificationService.cancelForTask()`, which cancels both the
visible notification and the native alarm for both triggers.

---

## 5. How the Silent-Mode Bypass Works (and its real limits)

### Android — works reliably, including with the app fully killed
1. `AlarmManager.setExactAndAllowWhileIdle(RTC_WAKEUP, ...)` wakes the
   device at the exact millisecond, even during Doze.
2. The resulting broadcast starts `ReminderTtsService` as a **foreground
   service** (`startForegroundService`), so it's not subject to Android's
   background-execution limits.
3. Inside that service, a native `TextToSpeech` instance speaks with
   `Bundle().putInt(TextToSpeech.Engine.KEY_PARAM_STREAM, AudioManager.STREAM_ALARM)`.
   **The ALARM stream is the same one every alarm-clock app uses, and it is
   not muted by Ringer/Silent/Vibrate mode** — only a phone-wide "Total
   silence" DND profile can mute it, by Android's own design, and no app
   (including a real alarm clock) can override that.
4. `AudioFocusRequest` is built with `AudioAttributes.USAGE_ALARM`, which
   also ducks/pauses any other audio (e.g. music) so the reminder is heard.
5. The service also nudges the alarm-stream volume up if it's very low, the
   same courtesy alarm-clock apps extend.

### iOS — works while the app is alive; honest limitation when fully killed
1. `AVAudioSession.setCategory(.playback, mode: .spokenAudio)` is configured
   in `AppDelegate.swift`. Audio played under `.playback` **does** play even
   with the hardware mute switch engaged — this part is real and reliable.
2. A local notification is scheduled with `interruptionLevel: .timeSensitive`
   for the exact trigger time, which surfaces even under most Focus modes.
3. When the user taps that notification (or if the app is already
   foregrounded/suspended-but-alive), `TtsService.speak()` runs and is
   audible over mute.
4. **What iOS does not allow**: running arbitrary custom-text TTS
   automatically, with zero user interaction, while the app is fully
   terminated. That requires Apple's **Critical Alerts** entitlement, which
   is granted only for specific categories (health, safety, home security)
   after a written request, and even then plays a system sound rather than
   custom speech. This trade-off is documented rather than glossed over —
   see the comment block at the bottom of `AppDelegate.swift`.

**Practical recommendation:** ship Android as the primary, fully-automatic
experience; on iOS, the time-sensitive notification plus tap-to-hear flow
is the honest, App-Store-compliant ceiling without a Critical Alerts grant.

---

## 6. Setup & Deployment

### 6.1 Prerequisites
- Flutter SDK ≥ 3.22 (`flutter --version`)
- Android Studio (SDK 34) and/or Xcode 15+
- Node.js ≥ 18, and a MongoDB Atlas cluster (or local `mongod`)

### 6.2 Flutter app
```bash
cd taskreminder
flutter pub get

# Android
flutter run -d android
flutter build apk --release          # or: flutter build appbundle --release

# iOS (on macOS, with a signing team configured in Xcode)
cd ios && pod install && cd ..
flutter run -d ios
flutter build ipa --release
```
Android package name / iOS bundle id used throughout the native code is
`com.example.taskreminder` — rename it (Android: package + folder structure
+ manifest; iOS: bundle identifier in Xcode) before publishing.

First run on Android will prompt for:
- Notification permission (Android 13+)
- "Allow exact alarms" (Android 12+) — required, the app requests it via
  `requestExactAlarmsPermission()`
- Battery-optimisation exemption prompt (`requestReliabilityPermissions()`)

### 6.3 Backend
```bash
cd backend
cp .env.example .env        # fill in MONGODB_URI and a strong JWT_SECRET
npm install
npm run dev                 # or: npm start
```
Deploy target of your choice (Render, Railway, Fly.io, a small VM, etc.).
Point the Flutter app's `ApiService(baseUrl: ...)` at the deployed URL; call
`POST /api/auth/device` once per install to obtain a token, store it
locally, and pass it into `ApiService`.

### 6.4 Enabling Hindi TTS voices
- **Android**: Settings → System → Languages → Text-to-speech output →
  install the Hindi (hi-IN) voice data for the device's TTS engine (Google
  TTS ships this by default on most devices; some OEM skins need a manual
  download).
- **iOS**: Settings → Accessibility → Spoken Content → Voices → add a Hindi
  voice. `flutter_tts` will fall back to English automatically if the
  requested locale isn't installed (`setLanguage` returns
  `LANG_MISSING_DATA`), which is handled in `ReminderTtsService.onInit`.

---

## 7. Testing Guide

**Unit/isolated:**
- `TaskModel.nightBeforeTriggerAt` — verify 22:00 the calendar day before
  `scheduledAt`, including month/year rollovers.
- `TtsService.buildNightBeforeText` / `buildDayOfText` — snapshot the
  generated English and Hindi sentences for a few sample dates/times.

**Manual, on a real device (emulators can't test silent-mode audio):**
1. Create a task ~2–3 minutes in the future. Confirm the day-of visible
   notification and spoken reminder both fire on time.
2. Put the phone in **silent mode** and repeat — confirm you still hear the
   reminder (Android via ALARM stream; iOS by tapping the notification).
3. Put the phone in **vibrate mode** and repeat.
4. Force-stop the app (Android: Settings → Apps → Task Reminder → Force
   stop) after scheduling a near-future task, then wait for the trigger —
   confirms the foreground-service path works without the app running.
5. Reboot the device with a future task pending, reopen the app once
   (triggers `resyncAllActiveTasks()`), then confirm the reminder still
   fires — this validates the reboot-recovery path described in §5/`BootReceiver.kt`.
6. Create one English-description task and one Hindi-description task;
   confirm each is spoken in the correct language.
7. Cancel a task and confirm no notification/speech occurs at either of its
   trigger times.
8. Create a task for "tomorrow" before 10:00 PM today, and one for "today"
   after 10:00 PM — confirm the night-before trigger is correctly skipped
   when it would already be in the past (see the `isAfter(DateTime.now())`
   guards in `NotificationService.scheduleForTask`).

**Backend:**
```bash
curl -X POST http://localhost:4000/api/auth/device -H "Content-Type: application/json" -d '{}'
# use the returned token as Authorization: Bearer <token> for:
curl -X POST http://localhost:4000/api/tasks -H "Authorization: Bearer <token>" -H "Content-Type: application/json" \
  -d '{"id":"test-1","description":"Doctor visit","language":"english","scheduledAt":"2026-10-01T10:00:00.000Z"}'
curl http://localhost:4000/api/tasks -H "Authorization: Bearer <token>"
curl -X DELETE http://localhost:4000/api/tasks/test-1 -H "Authorization: Bearer <token>"
```

---

## 8. Signing a Release Build for the Play Store

The debug-signed release build from §0 is fine for installing on your own
device but Google Play requires your own **upload key**:
```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA \
  -keysize 2048 -validity 10000 -alias upload
```
Create `android/key.properties` (do not commit this file):
```
storePassword=<your password>
keyPassword=<your password>
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```
Then replace the `release { signingConfig signingConfigs.debug }` block in
`android/app/build.gradle` with a `signingConfigs.release` block that reads
those properties, and point `buildTypes.release.signingConfig` at it — this
is the standard Flutter Play Store signing flow documented at
https://docs.flutter.dev/deployment/android#sign-the-app.

## 9. Known Follow-ups (v2)

- Headless Dart re-arm of alarms straight from `BootReceiver` (currently
  relies on the user opening the app once after a reboot — see the comment
  in `BootReceiver.kt`).
- Real login (email/OTP or Google/Apple Sign-In) in place of the bootstrap
  device-id JWT.
- Editing an existing task (currently: cancel + recreate).
- Snooze / "speak again in 5 minutes" action button.
- Apply for Apple's Critical Alerts entitlement if the app's use case
  qualifies, to close the iOS fully-killed-app gap described in §5.
- The app icon shipped in `android/app/src/main/res/**/ic_launcher*` is a
  simple placeholder vector so the project compiles out of the box. Swap in
  a real design with the `flutter_launcher_icons` package
  (https://pub.dev/packages/flutter_launcher_icons) before publishing.
