import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/db_service.dart';
import '../services/notification_service.dart';
import '../widgets/task_tile.dart';
import 'add_task_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<TaskModel> _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final tasks = await DbService.instance.getActiveTasks();
    setState(() {
      _tasks = tasks;
      _loading = false;
    });
  }

  Future<void> _cancelTask(TaskModel task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this task?'),
        content: Text(task.description),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancel task')),
        ],
      ),
    );
    if (confirmed != true) return;

    final cancelled = task.copyWith(isCancelled: true);
    await DbService.instance.updateTask(cancelled);
    await NotificationService.instance.cancelForTask(task);
    await _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Task cancelled')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Task Reminder')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No upcoming tasks. Tap + to add one.\nकोई आगामी कार्य नहीं। जोड़ने के लिए + दबाएँ।',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    itemCount: _tasks.length,
                    itemBuilder: (ctx, i) {
                      final task = _tasks[i];
                      return TaskTile(
                        task: task,
                        onCancel: () => _cancelTask(task),
                        onPreview: () => previewTask(task),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
        onPressed: () async {
          final added = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const AddTaskScreen()),
          );
          if (added == true) _refresh();
        },
      ),
    );
  }
}
