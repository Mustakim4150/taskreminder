import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/task_model.dart';

/// Speaks reminder text aloud.
///
/// - On Android, the *real* silent-mode-bypassing speech for scheduled
///   reminders happens natively (see ReminderTtsService.kt) so it works even
///   when the app process is dead. This Dart service is used only for the
///   in-app "preview" button and for any speaking done while the app is
///   already in the foreground.
/// - On iOS, this service is what actually speaks the reminder, configured
///   with AVAudioSession category `.playback` (set in AppDelegate.swift),
///   which plays even when the hardware mute switch is on.
class TtsService {
  TtsService._internal();
  static final TtsService instance = TtsService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _initialised = false;

  Future<void> _ensureInit() async {
    if (_initialised) return;
    if (Platform.isIOS) {
      // Category `.playback` + option `.duckOthers` is what allows audio to
      // play while the ringer/silent switch is engaged on iOS.
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.duckOthers,
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
        ],
        IosTextToSpeechAudioMode.spokenAudio,
      );
    }
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _initialised = true;
  }

  Future<void> speak(String text, TaskLanguage language) async {
    await _ensureInit();
    await _tts.setLanguage(language == TaskLanguage.hindi ? 'hi-IN' : 'en-US');
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();

  /// Builds the exact sentence to be spoken for the night-before reminder.
  static String buildNightBeforeText(TaskModel task, {required bool hindi}) {
    final date = _formatDate(task.scheduledAt, hindi: hindi);
    final time = _formatTime(task.scheduledAt, hindi: hindi);
    if (hindi) {
      return 'याद दिलाना: कल $date को $time बजे, आपका कार्य है: ${task.description}।';
    }
    return 'Reminder: Tomorrow, $date at $time, you have: ${task.description}.';
  }

  /// Builds the exact sentence to be spoken for the day-of reminder.
  static String buildDayOfText(TaskModel task, {required bool hindi}) {
    final time = _formatTime(task.scheduledAt, hindi: hindi);
    if (hindi) {
      return 'अभी $time बजे, आपका कार्य है: ${task.description}।';
    }
    return 'Now at $time: ${task.description}.';
  }

  static String _formatDate(DateTime dt, {required bool hindi}) {
    const monthsEn = [
      'January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December'
    ];
    const monthsHi = [
      'जनवरी', 'फरवरी', 'मार्च', 'अप्रैल', 'मई', 'जून', 'जुलाई',
      'अगस्त', 'सितंबर', 'अक्टूबर', 'नवंबर', 'दिसंबर'
    ];
    final months = hindi ? monthsHi : monthsEn;
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  static String _formatTime(DateTime dt, {required bool hindi}) {
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12
        ? (hindi ? 'शाम' : 'PM')
        : (hindi ? 'सुबह' : 'AM');
    return hindi ? '$hour12:$minute $period' : '$hour12:$minute $period';
  }
}
