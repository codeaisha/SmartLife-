// lib/home_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'package:fl_chart/fl_chart.dart';

class HomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool)? updateTheme;

  const HomeScreen({super.key, required this.isDarkMode, this.updateTheme});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  bool _notificationsEnabled = true;

  // Persistent tasks & notes
  List<Map<String, dynamic>> tasks = [
    {
      'title': 'Finish DAA project',
      'done': false,
      'priority': 'High',
      'category': 'Work',
      'dueDate': DateTime.now().add(const Duration(days: 1)).toString()
    },
    {
      'title': 'Read Flutter docs',
      'done': true,
      'priority': 'Medium',
      'category': 'Learning',
      'dueDate': DateTime.now().toString()
    },
    {
      'title': 'Meeting at 4 PM',
      'done': false,
      'priority': 'High',
      'category': 'Work',
      'dueDate': DateTime.now().add(const Duration(days: 2)).toString()
    },
  ];

  List<Map<String, dynamic>> notes = [
    {'title': 'Flutter Notes', 'content': 'Check widget tree and state management.'},
    {'title': 'DAA Notes', 'content': 'Revise Greedy algorithms.'},
  ];

  // charts: weekly productivity and mood levels
  List<int> weeklyProductivity = [0, 0, 0, 0, 0, 0, 0];
  List<int> moodLevels = [0, 0, 0, 0, 0, 0, 0]; // 0..5 scale stored as ints for compatibility

  String searchQuery = '';
  bool _showRemindersOnly = false; // when tapping Reminders stat card

  @override
  void initState() {
    super.initState();
    _loadTasksFromPrefs(); // load persisted tasks (if any)
    // After load we schedule notifications and compute charts
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ----------------- Persistence: load & save tasks -----------------
  Future<void> _loadTasksFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final stored = prefs.getString('my_app_tasks_v1');
      if (stored != null) {
        final List decoded = jsonDecode(stored) as List;
        tasks = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      // if parsing fails we keep the default tasks
    }

    // load notification setting if present
    _notificationsEnabled = prefs.getBool('my_app_notifications_enabled') ?? true;

    // compute charts after loading
    _recalculateMoodAndProductivity();
    _scheduleNotifications();
    if (mounted) setState(() {});
  }

  Future<void> _saveTasksToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('my_app_tasks_v1', jsonEncode(tasks));
  }

  Future<void> _saveNotificationSetting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('my_app_notifications_enabled', _notificationsEnabled);
  }

  // ----------------- LOGOUT -----------------
  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isLoggedIn', false);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          isDarkMode: widget.isDarkMode,
          toggleTheme: widget.updateTheme,
        ),
      ),
    );
  }

  Future<void> _refreshDashboard() async {
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) setState(() {});
  }

  // ----------------- SIMPLE IN-APP REMINDERS -----------------
  void _scheduleNotifications() {
    // Clear previous timers by just scheduling new snackbars when the app runs.
    for (var task in tasks) {
      try {
        if (!(task['done'] ?? false)) {
          final due = DateTime.parse(task['dueDate']);
          final diff = due.difference(DateTime.now());
          if (diff.inSeconds > 0 && diff.inSeconds < 60 * 60 * 24 * 30) {
            // schedule reminders within next 30 days only (example)
            Timer(diff, () {
              if (_notificationsEnabled && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Reminder: ${task['title']} is due!')),
                );
              }
            });
          }
        }
      } catch (_) {
        // ignore parse errors
      }
    }
  }

  // ----------------- Helper: recalculate charts from tasks -----------------
  void _recalculateMoodAndProductivity() {
    // Reset weekly counts
    weeklyProductivity = List<int>.filled(7, 0);
    final completedPerDay = List<int>.filled(7, 0);
    final totalPerDay = List<int>.filled(7, 0);

    for (var t in tasks) {
      try {
        final dt = DateTime.parse(t['dueDate']);
        final idx = (dt.weekday - 1) % 7;
        totalPerDay[idx] += 1;
        if (t['done'] == true) {
          completedPerDay[idx] += 1;
        }
      } catch (_) {
        // invalid or non-ISO date: ignore
      }
    }

    // weeklyProductivity = completed tasks count per day (cap for chart if you want)
    for (int i = 0; i < 7; i++) {
      weeklyProductivity[i] = completedPerDay[i];
      // moodLevels on a 0-5 scale: proportion * 5, rounded
      if (totalPerDay[i] == 0) {
        moodLevels[i] = 0;
      } else {
        final ratio = completedPerDay[i] / totalPerDay[i];
        moodLevels[i] = (ratio * 5).round().clamp(0, 5);
      }
    }

    // ensure state updated
    if (mounted) setState(() {});
  }

  // convenience: call after any task change
  Future<void> _onTasksChanged() async {
    await _saveTasksToPrefs();
    _recalculateMoodAndProductivity();
    _scheduleNotifications();
  }

  // ----------------- BUILD -----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isDarkMode ? Colors.grey[900] : Colors.grey[100],
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _dashboardPage(),
          _tasksPage(),
          _notesPage(),
          _profilePage(),
          _settingsPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            _pageController.jumpToPage(index);
            // clear reminders-only filter when navigating away
            _showRemindersOnly = false;
          });
        },
        backgroundColor: Colors.deepPurple,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.task), label: 'Tasks'),
          BottomNavigationBarItem(icon: Icon(Icons.note), label: 'Notes'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
      floatingActionButton: _buildFABMenu(),
    );
  }

  // ----------------- DASHBOARD -----------------
  Widget _dashboardPage() {
    final completedTasks = tasks.where((t) => t['done']).length;
    final totalTasks = tasks.length;

    return RefreshIndicator(
      onRefresh: _refreshDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _welcomeCard(),
            const SizedBox(height: 20),
            _horizontalStats(completedTasks, totalTasks),
            const SizedBox(height: 20),
            _taskProgressPieChart(completedTasks, totalTasks),
            const SizedBox(height: 20),
            _weeklyProductivityBarChart(),
            const SizedBox(height: 20),
            _moodLineChart(),
            const SizedBox(height: 20),
            _aiSuggestionPanel(),
            const SizedBox(height: 20),
            if (_notificationsEnabled) _notificationCard(),
          ],
        ),
      ),
    );
  }

  Widget _welcomeCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF9575CD), Color(0xFF64B5F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(2, 4))],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const CircleAvatar(radius: 40, backgroundImage: AssetImage('images/user_avatar.png')),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Hello, Aisha 👋',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Text('Your AI-powered dashboard is ready!', style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              // Quick action example: go to tasks
              setState(() {
                _currentIndex = 1;
                _pageController.jumpToPage(1);
                _showRemindersOnly = false;
              });
            },
            icon: const Icon(Icons.arrow_forward, color: Colors.white),
          )
        ],
      ),
    );
  }

  // ---------- Modern horizontal stat cards (scrollable) ----------
  Widget _horizontalStats(int completed, int total) {
    final stats = [
      {'title': 'Tasks Completed', 'value': '$completed / $total', 'icon': Icons.check_circle, 'color': Colors.green, 'isEmoji': false},
      {'title': 'Reminders', 'value': '${(tasks.where((t) => !t['done']).length)}', 'icon': Icons.notifications_active, 'color': Colors.orange, 'isEmoji': false},
      {'title': 'Active Projects', 'value': '5', 'icon': Icons.work_outline, 'color': Colors.blueAccent, 'isEmoji': false},
      {'title': 'Mood Level', 'value': _predictMoodEmoji(), 'icon': Icons.emoji_emotions, 'color': Colors.purple, 'isEmoji': true},
    ];

    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stats.length,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = stats[index];
          return GestureDetector(
            onTap: () {
              // Navigate to tasks if user taps the first card
              if (index == 0) {
                setState(() {
                  _currentIndex = 1;
                  _pageController.jumpToPage(1);
                  _showRemindersOnly = false;
                });
              } else if (index == 1) {
                // Reminders card tapped -> show tasks filtered to 'Reminder' category
                setState(() {
                  _currentIndex = 1;
                  _pageController.jumpToPage(1);
                  _showRemindersOnly = true;
                });
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Showing reminders in Tasks')));
              } else {
                // other cards: just animate entry (no navigation)
              }
            },
            child: AnimatedStatCard(
              title: item['title'] as String,
              value: item['value'] as String,
              icon: item['icon'] as IconData,
              color: item['color'] as Color,
              isEmoji: item['isEmoji'] as bool,
            ),
          );
        },
      ),
    );
  }

  // ----------------- PIE CHART -----------------
  Widget _taskProgressPieChart(int completed, int total) {
    final pending = (total - completed).toDouble();
    final completedD = completed.toDouble();
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Task Progress', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(value: completedD, color: Colors.green, title: '$completed'),
                    PieChartSectionData(value: pending, color: Colors.red, title: '${total - completed}'),
                  ],
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // ----------------- BAR CHART (weekly productivity) -----------------
  Widget _weeklyProductivityBarChart() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Weekly Productivity', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (weeklyProductivity.reduce((a, b) => a > b ? a : b).toDouble() + 1).clamp(5, 20),
                  barGroups: List.generate(
                    weeklyProductivity.length,
                        (index) => BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: weeklyProductivity[index].toDouble(),
                          color: Colors.deepPurple,
                          width: 16,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                          final idx = value.toInt() % 7;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(days[idx], style: const TextStyle(fontSize: 12)),
                          );
                        },
                        reservedSize: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------- LINE CHART (mood) -----------------
  Widget _moodLineChart() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Mood Tracker', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 5,
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(
                          moodLevels.length, (i) => FlSpot(i.toDouble(), moodLevels[i].toDouble())),
                      isCurved: true,
                      barWidth: 3,
                      color: Colors.orangeAccent,
                      dotData: FlDotData(show: true),
                    )
                  ],
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // ----------------- AI SUGGESTION PANEL (motivational) -----------------
  Widget _aiSuggestionPanel() {
    final next = tasks.firstWhere((t) => !(t['done'] ?? false), orElse: () => {'title': 'No pending task'})['title'];
    final moodPrediction = _predictMood();

    String suggestion;
    if (moodPrediction.contains('Excellent') || moodPrediction.contains('Good')) {
      suggestion = "Amazing job, Aisha! Keep riding this momentum 🌟";
    } else if (moodPrediction.contains('Okay')) {
      suggestion = "Not bad — try finishing one more task to lift your mood ✨";
    } else {
      suggestion = "Take a short break and then start with a small task — you got this 💪";
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('AI Suggestions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(children: [const Icon(Icons.lightbulb_outline), const SizedBox(width: 8), Expanded(child: Text('Next Task: $next'))]),
          const SizedBox(height: 8),
          Row(children: [const Icon(Icons.insert_emoticon), const SizedBox(width: 8), Text('Mood Prediction: $moodPrediction')]),
          const SizedBox(height: 8),
          Row(children: [const Icon(Icons.auto_awesome), const SizedBox(width: 8), Expanded(child: Text('Motivation: $suggestion'))]),
        ]),
      ),
    );
  }

  String _predictMood() {
    // Derive mood from current tasks completion ratio
    if (tasks.isEmpty) return 'Neutral';
    final completed = tasks.where((t) => t['done'] == true).length;
    final total = tasks.length;
    final r = completed / (total == 0 ? 1 : total);

    if (r >= 0.8) return '😄 Excellent';
    if (r >= 0.5) return '🙂 Good';
    if (r >= 0.25) return '😐 Okay';
    return '😕 Low';
  }

  String _predictMoodEmoji() {
    final mood = _predictMood();
    if (mood.contains('Excellent')) return '😄';
    if (mood.contains('Good')) return '🙂';
    if (mood.contains('Okay')) return '😐';
    return '😕';
  }

  // ----------------- NOTIFICATIONS CARD -----------------
  Widget _notificationCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Notifications 🔔', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ...tasks.where((t) => !(t['done'] ?? false)).map((t) => _buildNotificationChip(t['title'], Colors.deepPurple)).toList(),
          ]),
        ]),
      ),
    );
  }

  Widget _buildNotificationChip(String label, Color color) {
    return Chip(label: Text(label, style: const TextStyle(color: Colors.white)), backgroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6));
  }

  // ----------------- TASKS PAGE -----------------
  Widget _tasksPage() {
    final filteredTasks = tasks.where((task) {
      final matchesSearch = task['title'].toString().toLowerCase().contains(searchQuery.toLowerCase());
      if (_showRemindersOnly) {
        return task['category']?.toString().toLowerCase() == 'reminder' && matchesSearch;
      }
      return matchesSearch;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(children: [
        const Text('Your Tasks', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        TextField(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search Tasks...', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
          onChanged: (val) {
            setState(() {
              searchQuery = val;
            });
          },
        ),
        const SizedBox(height: 16),
        Expanded(
          child: filteredTasks.isEmpty
              ? const Center(child: Text('No tasks found'))
              : ListView.builder(
            itemCount: filteredTasks.length,
            itemBuilder: (context, index) {
              final task = filteredTasks[index];
              return Dismissible(
                key: UniqueKey(),
                direction: DismissDirection.endToStart,
                background: Container(
                  padding: const EdgeInsets.only(right: 20),
                  alignment: Alignment.centerRight,
                  color: Colors.redAccent,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) {
                  setState(() {
                    tasks.remove(task);
                    _saveTasksToPrefs();
                    _recalculateMoodAndProductivity();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task deleted')));
                },
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 3,
                  child: ListTile(
                    leading: Checkbox(
                      value: task['done'] ?? false,
                      onChanged: (val) {
                        setState(() {
                          task['done'] = val ?? false;
                          _saveTasksToPrefs();
                          _recalculateMoodAndProductivity();
                        });
                      },
                    ),
                    title: Text(task['title'], style: TextStyle(decoration: (task['done'] ?? false) ? TextDecoration.lineThrough : null)),
                    subtitle: Text('Priority: ${task['priority']} • Category: ${task['category']} • Due: ${_formatDate(task['dueDate'])}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditTaskDialog(task),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  String _formatDate(dynamic d) {
    try {
      final dt = d is DateTime ? d : DateTime.parse(d.toString());
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return d.toString();
    }
  }

  // ----------------- NOTES PAGE -----------------
  Widget _notesPage() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(children: [
        const Text('Your Notes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 3,
                child: ListTile(
                  title: Text(note['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(note['content']),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () {
                      setState(() {
                        notes.removeAt(index);
                        _saveNotesToPrefs();
                      });
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  Future<void> _saveNotesToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('my_app_notes_v1', jsonEncode(notes));
  }

  // ----------------- PROFILE PAGE -----------------
  Widget _profilePage() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(children: [
        const CircleAvatar(radius: 50, backgroundImage: AssetImage('images/user_avatar.png')),
        const SizedBox(height: 16),
        const Text('Aisha Zafri', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('aishazafri6@gmail.com', style: TextStyle(fontSize: 16, color: Colors.grey)),
        const SizedBox(height: 20),
        ElevatedButton.icon(onPressed: _logout, icon: const Icon(Icons.logout), label: const Text('Logout')),
      ]),
    );
  }

  // ----------------- SETTINGS PAGE -----------------
  Widget _settingsPage() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SwitchListTile(
          title: const Text('Dark Mode'),
          value: widget.isDarkMode,
          onChanged: (val) {
            if (widget.updateTheme != null) widget.updateTheme!(val);
          },
        ),
        SwitchListTile(
          title: const Text('Enable Notifications'),
          value: _notificationsEnabled,
          onChanged: (val) {
            setState(() {
              _notificationsEnabled = val;
              _saveNotificationSetting();
            });
          },
        ),
      ]),
    );
  }

  // ----------------- FAB & Dialogs -----------------
  Widget _buildFABMenu() {
    return FloatingActionButton(
      backgroundColor: Colors.deepPurple,
      child: const Icon(Icons.add, color: Colors.white), // made '+' white
      onPressed: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (_) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Wrap(spacing: 12, runSpacing: 12, children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.task),
                  title: const Text('Add Task'),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddTaskDialog();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.note),
                  title: const Text('Add Note'),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddNoteDialog();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notifications),
                  title: const Text('Add Reminder (quick)'),
                  onTap: () {
                    Navigator.pop(context);
                    _showQuickReminderDialog();
                  },
                ),
              ]),
            );
          },
        );
      },
    );
  }

  void _showAddTaskDialog() {
    final titleCtrl = TextEditingController();
    String priority = 'Medium';
    String category = 'General';
    DateTime dueDate = DateTime.now().add(const Duration(days: 1));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Task'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: priority,
                items: const [
                  DropdownMenuItem(value: 'High', child: Text('High')),
                  DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'Low', child: Text('Low')),
                ],
                onChanged: (v) => priority = v ?? 'Medium',
                decoration: const InputDecoration(labelText: 'Priority'),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(labelText: 'Category'),
                onChanged: (v) => category = v,
              ),
              const SizedBox(height: 8),
              Row(children: [
                const Text('Due: '),
                const SizedBox(width: 8),
                Text('${dueDate.year}-${dueDate.month}-${dueDate.day}'),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: dueDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                    );
                    if (picked != null) {
                      setState(() {
                        dueDate = picked;
                      });
                    }
                  },
                  child: const Text('Pick'),
                )
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final t = titleCtrl.text.trim();
                if (t.isEmpty) return;
                setState(() {
                  tasks.add({
                    'title': t,
                    'done': false,
                    'priority': priority,
                    'category': category.isEmpty ? 'General' : category,
                    'dueDate': dueDate.toString()
                  });
                });
                _onTasksChanged(); // save + recalc + schedule
                Navigator.pop(context);
              },
              child: const Text('Add'),
            )
          ],
        );
      },
    );
  }

  // Helper to reopen dialog after picking date (simple UX)
  void _showAddTaskDialogWithInitial(String titleText, String priority, String category, DateTime dueDate) {
    final titleCtrl = TextEditingController(text: titleText);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Task'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: priority,
                items: const [
                  DropdownMenuItem(value: 'High', child: Text('High')),
                  DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'Low', child: Text('Low')),
                ],
                onChanged: (v) => priority = v ?? 'Medium',
                decoration: const InputDecoration(labelText: 'Priority'),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(labelText: 'Category'),
                controller: TextEditingController(text: category),
                onChanged: (v) => category = v,
              ),
              const SizedBox(height: 8),
              Row(children: [
                const Text('Due: '),
                const SizedBox(width: 8),
                Text('${dueDate.year}-${dueDate.month}-${dueDate.day}'),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: dueDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                    );
                    if (picked != null) {
                      Navigator.pop(context);
                      _showAddTaskDialogWithInitial(titleCtrl.text, priority, category, picked);
                    }
                  },
                  child: const Text('Pick'),
                )
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final t = titleCtrl.text.trim();
                if (t.isEmpty) return;
                setState(() {
                  tasks.add({
                    'title': t,
                    'done': false,
                    'priority': priority,
                    'category': category.isEmpty ? 'General' : category,
                    'dueDate': dueDate.toString()
                  });
                });
                _onTasksChanged();
                Navigator.pop(context);
              },
              child: const Text('Add'),
            )
          ],
        );
      },
    );
  }

  void _showEditTaskDialog(Map<String, dynamic> task) {
    final titleCtrl = TextEditingController(text: task['title']);
    String priority = task['priority'] ?? 'Medium';
    String category = task['category'] ?? 'General';
    DateTime dueDate;
    try {
      dueDate = DateTime.parse(task['dueDate']);
    } catch (_) {
      dueDate = DateTime.now().add(const Duration(days: 1));
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Task'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: priority,
                items: const [
                  DropdownMenuItem(value: 'High', child: Text('High')),
                  DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'Low', child: Text('Low')),
                ],
                onChanged: (v) => priority = v ?? 'Medium',
                decoration: const InputDecoration(labelText: 'Priority'),
              ),
              const SizedBox(height: 8),
              TextField(controller: TextEditingController(text: category), decoration: const InputDecoration(labelText: 'Category'), onChanged: (v) => category = v),
              const SizedBox(height: 8),
              Row(children: [
                const Text('Due: '),
                const SizedBox(width: 8),
                Text('${dueDate.year}-${dueDate.month}-${dueDate.day}'),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: dueDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                    );
                    if (picked != null) {
                      setState(() {
                        dueDate = picked;
                      });
                      Navigator.pop(context);
                      _showEditTaskDialog(task); // reopen with updated date
                    }
                  },
                  child: const Text('Pick'),
                )
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final t = titleCtrl.text.trim();
                if (t.isEmpty) return;
                setState(() {
                  task['title'] = t;
                  task['priority'] = priority;
                  task['category'] = category;
                  task['dueDate'] = dueDate.toString();
                });
                _onTasksChanged();
                Navigator.pop(context);
              },
              child: const Text('Save'),
            )
          ],
        );
      },
    );
  }

  void _showAddNoteDialog() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Note'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 8),
              TextField(controller: contentCtrl, decoration: const InputDecoration(labelText: 'Content'), maxLines: 4),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final t = titleCtrl.text.trim();
                if (t.isEmpty) return;
                setState(() {
                  notes.add({'title': t, 'content': contentCtrl.text.trim()});
                });
                _saveNotesToPrefs();
                Navigator.pop(context);
              },
              child: const Text('Add'),
            )
          ],
        );
      },
    );
  }

  void _showQuickReminderDialog() {
    final titleCtrl = TextEditingController();
    DateTime dueDate = DateTime.now().add(const Duration(hours: 1));
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Quick Reminder'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Reminder title')),
            const SizedBox(height: 8),
            Row(children: [
              Text('At: ${dueDate.hour}:${dueDate.minute.toString().padLeft(2, '0')}'),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                      context: context, initialDate: dueDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (picked != null) {
                    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(dueDate));
                    if (time != null) {
                      dueDate = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
                      Navigator.pop(context);
                      _showQuickReminderDialog(); // reopen to show updated date
                    }
                  }
                },
                child: const Text('Pick'),
              )
            ])
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final t = titleCtrl.text.trim();
                if (t.isEmpty) return;
                setState(() {
                  // quick reminders we store as tasks of category 'Reminder'
                  tasks.add({'title': t, 'done': false, 'priority': 'Medium', 'category': 'Reminder', 'dueDate': dueDate.toString()});
                });
                _onTasksChanged();
                Navigator.pop(context);
              },
              child: const Text('Add'),
            )
          ],
        );
      },
    );
  }
}

// ----------------- Animated Stat Card Widget -----------------
class AnimatedStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isEmoji;

  const AnimatedStatCard({super.key, required this.title, required this.value, required this.icon, required this.color, this.isEmoji = false});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, val, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - val)),
          child: Opacity(
            opacity: val,
            child: Container(
              width: 220,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(context).cardColor,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(2, 4))],
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                isEmoji
                    ? Text(value, style: const TextStyle(fontSize: 36))
                    : Icon(icon, size: 36, color: color),
                const SizedBox(height: 10),
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
              ]),
            ),
          ),
        );
      },
    );
  }
}
