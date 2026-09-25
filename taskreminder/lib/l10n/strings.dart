/// Minimal bilingual UI copy. For a larger app, replace with Flutter's
/// official `flutter_localizations` + `.arb` files; kept simple here since
/// the bilingual requirement is really about the *task description and
/// voice output*, not the whole chrome of the app.
class Strings {
  static const en = {
    'appTitle': 'Task Reminder',
    'addTask': 'Add Task',
    'noTasks': 'No upcoming tasks. Tap + to add one.',
    'description': 'Task description',
    'pickDate': 'Pick date',
    'pickTime': 'Pick time',
    'language': 'Description language',
    'save': 'Save Task',
    'cancelTask': 'Cancel task',
    'preview': 'Preview voice',
    'nightBeforeAt': 'Night-before reminder: 10:00 PM',
    'dayOfAt': 'Day-of reminder at exact time',
  };

  static const hi = {
    'appTitle': 'कार्य अनुस्मारक',
    'addTask': 'कार्य जोड़ें',
    'noTasks': 'कोई आगामी कार्य नहीं। जोड़ने के लिए + दबाएँ।',
    'description': 'कार्य का विवरण',
    'pickDate': 'तारीख चुनें',
    'pickTime': 'समय चुनें',
    'language': 'विवरण की भाषा',
    'save': 'कार्य सहेजें',
    'cancelTask': 'कार्य रद्द करें',
    'preview': 'आवाज़ सुनें',
    'nightBeforeAt': 'रात का अनुस्मारक: रात 10:00 बजे',
    'dayOfAt': 'ठीक समय पर अनुस्मारक',
  };
}
