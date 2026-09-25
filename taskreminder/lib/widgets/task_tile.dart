import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import '../services/tts_service.dart';

class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.onCancel,
    required this.onPreview,
  });

  final TaskModel task;
  final VoidCallback onCancel;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EEE, d MMM yyyy • h:mm a');
    final isHindi = task.language == TaskLanguage.hindi;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          child: Icon(isHindi ? Icons.translate : Icons.abc),
        ),
        title: Text(task.description,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(df.format(task.scheduledAt)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Preview voice',
              icon: const Icon(Icons.volume_up),
              onPressed: onPreview,
            ),
            IconButton(
              tooltip: 'Cancel task',
              icon: const Icon(Icons.delete_outline),
              onPressed: onCancel,
            ),
          ],
        ),
      ),
    );
  }
}

/// Convenience used by HomeScreen's preview button.
Future<void> previewTask(TaskModel task) async {
  final hindi = task.language == TaskLanguage.hindi;
  final text = TtsService.buildDayOfText(task, hindi: hindi);
  await TtsService.instance.speak(text, task.language);
}
