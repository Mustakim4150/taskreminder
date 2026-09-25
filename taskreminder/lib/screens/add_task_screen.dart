import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/task_model.dart';
import '../services/db_service.dart';
import '../services/notification_service.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  TaskLanguage _language = TaskLanguage.english;
  DateTime? _date;
  TimeOfDay? _time;
  bool _saving = false;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_date == null || _time == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please pick both date and time')));
      return;
    }
    final scheduledAt = DateTime(
      _date!.year,
      _date!.month,
      _date!.day,
      _time!.hour,
      _time!.minute,
    );
    if (!scheduledAt.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please choose a future date/time')));
      return;
    }

    setState(() => _saving = true);
    final task = TaskModel(
      id: const Uuid().v4(),
      description: _descController.text.trim(),
      language: _language,
      scheduledAt: scheduledAt,
      createdAt: DateTime.now(),
    );

    await DbService.instance.insertTask(task);
    await NotificationService.instance.scheduleForTask(task);
    // Optionally sync to backend here:
    // await apiService.pushTask(task);

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Task')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Task description / कार्य का विवरण',
                hintText: 'e.g. Doctor appointment / डॉक्टर की अपॉइंटमेंट',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            Text('Description language / विवरण की भाषा',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<TaskLanguage>(
              segments: const [
                ButtonSegment(
                    value: TaskLanguage.english,
                    label: Text('English'),
                    icon: Icon(Icons.abc)),
                ButtonSegment(
                    value: TaskLanguage.hindi,
                    label: Text('हिन्दी'),
                    icon: Icon(Icons.translate)),
              ],
              selected: {_language},
              onSelectionChanged: (s) => setState(() => _language = s.first),
            ),
            const SizedBox(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(_date == null
                  ? 'Pick date / तारीख चुनें'
                  : '${_date!.year}-${_date!.month.toString().padLeft(2, '0')}-${_date!.day.toString().padLeft(2, '0')}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time),
              title: Text(_time == null
                  ? 'Pick time / समय चुनें'
                  : _time!.format(context)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickTime,
            ),
            const SizedBox(height: 8),
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  '🔔 You will hear this task spoken aloud at 10:00 PM the '
                  'night before, and again at the exact scheduled time — '
                  'even in silent or vibrate mode.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check),
              label: const Text('Save Task'),
            ),
          ],
        ),
      ),
    );
  }
}
