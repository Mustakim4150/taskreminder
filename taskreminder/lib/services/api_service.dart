import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task_model.dart';

/// Talks to the Node.js/MongoDB backend so tasks are backed up and can sync
/// across a user's devices. The app fully functions offline without this —
/// scheduling and speaking reminders never depends on network access.
class ApiService {
  ApiService({required this.baseUrl, required this.authToken});

  /// e.g. https://your-backend.example.com/api
  final String baseUrl;

  /// Bearer token obtained at login/signup (see backend/routes/auth.js if you
  /// add authentication; a minimal single-user deployment can use a fixed
  /// device-generated token instead).
  final String authToken;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      };

  Future<void> pushTask(TaskModel task) async {
    await http.post(
      Uri.parse('$baseUrl/tasks'),
      headers: _headers,
      body: jsonEncode(task.toJson()),
    );
  }

  Future<void> deleteTask(String id) async {
    await http.delete(Uri.parse('$baseUrl/tasks/$id'), headers: _headers);
  }

  Future<List<TaskModel>> fetchTasks() async {
    final res = await http.get(Uri.parse('$baseUrl/tasks'), headers: _headers);
    if (res.statusCode != 200) return [];
    final List<dynamic> body = jsonDecode(res.body);
    return body.map((e) => TaskModel.fromJson(e)).toList();
  }
}
