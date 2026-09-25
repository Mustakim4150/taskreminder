import UIKit
import Flutter
import AVFoundation
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Category `.playback` is the piece that lets audio (including
    // AVSpeechSynthesizer output driven by flutter_tts) play even when the
    // hardware mute/silent switch is engaged, and even under most Focus/DND
    // configurations. This must be active whenever TtsService.speak() runs.
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
      try session.setActive(true, options: .notifyOthersOnDeactivation)
    } catch {
      print("Failed to configure AVAudioSession: \(error)")
    }

    UNUserNotificationCenter.current().delegate = self

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Ensures the reminder notification banner/sound appears even while the
  // app is in the foreground, matching Android's behaviour.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound, .list])
  }
}

/*
 IMPORTANT — iOS platform limitation, stated plainly:

 Apple does not allow arbitrary background code execution at an exact wall-
 clock time for a fully-terminated app, the way Android's AlarmManager does.
 What this build gives you on iOS:

   1. A local notification (via flutter_local_notifications) is scheduled
      for the exact night-before and day-of times, with
      `interruptionLevel: .timeSensitive`, which is more likely to surface
      even in Focus modes.
   2. When the user taps that notification (or if the app happens to already
      be foregrounded/backgrounded-but-alive), TtsService speaks the
      reminder using the `.playback` AVAudioSession category configured
      above, which DOES bypass the physical mute switch.

 What it does NOT guarantee on iOS: automatically speaking with zero user
 interaction while the app is fully killed. To achieve that, Apple requires
 the "Critical Alerts" entitlement (`com.apple.developer.usernotifications.
 critical-alerts`), which is granted only to specific app categories (e.g.
 health, safety, home security) after a written request to Apple, and even
 then it plays a system sound rather than arbitrary custom TTS speech. Apps
 like alarm clocks work around this by staying alive via
 `UIBackgroundModes: audio` and keeping a silent looping sound active — an
 approach that is battery-costly and against App Store guidelines if used
 purely to defeat background limits. This is documented in the README
 "Platform Limitations" section so the trade-off is explicit rather than
 silently overpromised.
*/
