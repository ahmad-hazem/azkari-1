import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==========================================
// 1. نماذج البيانات (Models)
// ==========================================
class HistoryRecord {
  final String id;
  final String dhikrName;
  final int count;
  final DateTime timestamp;

  HistoryRecord({
    required this.id,
    required this.dhikrName,
    required this.count,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'dhikrName': dhikrName,
        'count': count,
        'timestamp': timestamp.toIso8601String(),
      };

  factory HistoryRecord.fromJson(Map<String, dynamic> json) => HistoryRecord(
        id: json['id'] as String,
        dhikrName: json['dhikrName'] as String,
        count: json['count'] as int,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

class DhikrItem {
  final String id;
  final String category;
  final String text;
  final String? virtue;
  final int targetCount;
  int currentCount;

  DhikrItem({
    required this.id,
    required this.category,
    required this.text,
    this.virtue,
    required this.targetCount,
    this.currentCount = 0,
  });

  bool get isCompleted => currentCount >= targetCount;
}

// ==========================================
// 2. خدمة التخزين المحلي (Storage Service)
// ==========================================
class StorageService {
  final SharedPreferences prefs;

  StorageService(this.prefs);

  static const String _keyThemeMode = 'theme_mode';
  static const String _keyVibration = 'vibration_enabled';
  static const String _keySound = 'sound_enabled';
  static const String _keyActiveDhikr = 'active_dhikr';
  static const String _keyDhikrList = 'custom_dhikr_list';
  static const String _keyTarget = 'current_target';
  static const String _keyDhikrCounts = 'dhikr_counts_map';
  static const String _keyHistory = 'history_records';
  static const String _keyAdhkarProgress = 'adhkar_card_progress';

  bool get isDarkMode => prefs.getBool(_keyThemeMode) ?? false;
  Future<void> setDarkMode(bool value) => prefs.setBool(_keyThemeMode, value);

  bool get isVibrationEnabled => prefs.getBool(_keyVibration) ?? true;
  Future<void> setVibrationEnabled(bool value) =>
      prefs.setBool(_keyVibration, value);

  bool get isSoundEnabled => prefs.getBool(_keySound) ?? false;
  Future<void> setSoundEnabled(bool value) => prefs.setBool(_keySound, value);

  String get activeDhikr => prefs.getString(_keyActiveDhikr) ?? 'سبحان الله';
  Future<void> setActiveDhikr(String value) =>
      prefs.setString(_keyActiveDhikr, value);

  int get currentTarget => prefs.getInt(_keyTarget) ?? 100;
  Future<void> setCurrentTarget(int value) => prefs.setInt(_keyTarget, value);

  List<String> getDhikrList() {
    return prefs.getStringList(_keyDhikrList) ??
        [
          'سبحان الله',
          'الحمد لله',
          'الله أكبر',
          'لا إله إلا الله',
          'أستغفر الله',
          'سبحان الله وبحمده',
          'سبحان الله العظيم',
          'اللهم صلِّ وسلم على نبينا محمد ﷺ',
        ];
  }

  Future<void> addCustomDhikr(String dhikr) async {
    final list = getDhikrList();
    if (!list.contains(dhikr)) {
      list.add(dhikr);
      await prefs.setStringList(_keyDhikrList, list);
    }
  }

  Map<String, int> getDhikrCounts() {
    final raw = prefs.getString(_keyDhikrCounts);
    if (raw == null) return {};
    final Map<String, dynamic> decoded = jsonDecode(raw);
    return decoded.map((k, v) => MapEntry(k, v as int));
  }

  int getCountForDhikr(String dhikr) => getDhikrCounts()[dhikr] ?? 0;

  Future<void> incrementDhikr(String dhikr) async {
    final counts = getDhikrCounts();
    counts[dhikr] = (counts[dhikr] ?? 0) + 1;
    await prefs.setString(_keyDhikrCounts, jsonEncode(counts));
  }

  Future<void> resetDhikr(String dhikr) async {
    final counts = getDhikrCounts();
    counts[dhikr] = 0;
    await prefs.setString(_keyDhikrCounts, jsonEncode(counts));
  }

  List<HistoryRecord> getHistory() {
    final raw = prefs.getStringList(_keyHistory);
    if (raw == null) return [];
    return raw.map((item) => HistoryRecord.fromJson(jsonDecode(item))).toList();
  }

  Future<void> addHistoryRecord(HistoryRecord record) async {
    final list = getHistory();
    list.insert(0, record);
    final serialized = list.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList(_keyHistory, serialized);
  }

  Map<String, int> getAdhkarProgress() {
    final raw = prefs.getString(_keyAdhkarProgress);
    if (raw == null) return {};
    final Map<String, dynamic> decoded = jsonDecode(raw);
    return decoded.map((k, v) => MapEntry(k, v as int));
  }

  Future<void> saveAdhkarProgress(String id, int count) async {
    final map = getAdhkarProgress();
    map[id] = count;
    await prefs.setString(_keyAdhkarProgress, jsonEncode(map));
  }

  Future<void> resetAllData() async {
    await prefs.clear();
  }
}

late StorageService storage;

// ==========================================
// 3. نقطة البداية (Main Application)
// ==========================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  storage = StorageService(prefs);
  runApp(const SobhatiApp());
}

class SobhatiApp extends StatefulWidget {
  const SobhatiApp({super.key});

  static _SobhatiAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_SobhatiAppState>()!;

  @override
  State<SobhatiApp> createState() => _SobhatiAppState();
}

class _SobhatiAppState extends State<SobhatiApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = storage.isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  void toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    const emeraldPrimary = Color(0xFF1B4D3E);
    const goldSecondary = Color(0xFFC5A059);

    return MaterialApp(
      title: 'سبحتي وأذكاري',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [Locale('ar', 'SA')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: emeraldPrimary,
          secondary: goldSecondary,
          surface: Colors.white,
          surfaceContainerHighest: Color(0xFFEBEFEA),
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F7F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: emeraldPrimary,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: goldSecondary,
          secondary: emeraldPrimary,
          surface: Color(0xFF1E2B25),
          surfaceContainerHighest: Color(0xFF263730),
        ),
        scaffoldBackgroundColor: const Color(0xFF121B17),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E2B25),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// ==========================================
// 4. شاشة البداية (Splash Screen)
// ==========================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary,
              ),
              child:
                  const Icon(Icons.fingerprint, size: 60, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              'سبحتي وأذكاري',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('ألا بذكر الله تطمئن القلوب',
                style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 5. شاشة التنقل الرئيسية (Navigation)
// ==========================================
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    AdhkarScreen(),
    StatisticsScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.touch_app), label: 'السبحة'),
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'الأذكار'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart), label: 'الإحصائيات'),
          NavigationDestination(icon: Icon(Icons.history), label: 'السجل'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'الإعدادات'),
        ],
      ),
    );
  }
}

// ==========================================
// 6. شاشة السبحة (Home Screen)
// ==========================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late String _currentDhikr;
  late int _target;
  late int _count;

  @override
  void initState() {
    super.initState();
    _currentDhikr = storage.activeDhikr;
    _target = storage.currentTarget;
    _count = storage.getCountForDhikr(_currentDhikr);
  }

  void _handleTap() async {
    if (storage.isVibrationEnabled) HapticFeedback.lightImpact();
    if (storage.isSoundEnabled) SystemSound.play(SystemSoundType.click);

    setState(() => _count++);
    await storage.incrementDhikr(_currentDhikr);

    if (_count == _target) {
      _showTargetDialog();
      await storage.addHistoryRecord(HistoryRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        dhikrName: _currentDhikr,
        count: _count,
        timestamp: DateTime.now(),
      ));
    }
  }

  void _showTargetDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ما شاء الله، أحسنت!', textAlign: TextAlign.center),
        content: Text('أتممت هدفك ($_target مرة) في ذكر "$_currentDhikr".',
            textAlign: TextAlign.center),
        actions: [
          Center(
            child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('متابعة التسبيح')),
          )
        ],
      ),
    );
  }

  void _resetCount() async {
    if (_count > 0) {
      await storage.addHistoryRecord(HistoryRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        dhikrName: _currentDhikr,
        count: _count,
        timestamp: DateTime.now(),
      ));
    }
    await storage.resetDhikr(_currentDhikr);
    setState(() => _count = 0);
  }

  void _selectDhikrDialog() {
    final list = storage.getDhikrList();
    final customCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            top: 16,
            left: 16,
            right: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('اختر الذكر',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: list.length,
                itemBuilder: (context, i) => ListTile(
                  title: Text(list[i]),
                  trailing: _currentDhikr == list[i]
                      ? const Icon(Icons.check, color: Color(0xFF1B4D3E))
                      : null,
                  onTap: () async {
                    await storage.setActiveDhikr(list[i]);
                    setState(() {
                      _currentDhikr = list[i];
                      _count = storage.getCountForDhikr(list[i]);
                    });
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: customCtrl,
                    decoration: const InputDecoration(
                        hintText: 'إضافة ذكر مخصص...',
                        border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    if (customCtrl.text.trim().isNotEmpty) {
                      final val = customCtrl.text.trim();
                      await storage.addCustomDhikr(val);
                      await storage.setActiveDhikr(val);
                      setState(() {
                        _currentDhikr = val;
                        _count = storage.getCountForDhikr(val);
                      });
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('إضافة'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _selectTargetDialog() {
    final targets = [33, 100, 300, 1000];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('تحديد الهدف',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: targets
                  .map((t) => ChoiceChip(
                        label: Text('$t'),
                        selected: _target == t,
                        onSelected: (selected) async {
                          if (selected) {
                            await storage.setCurrentTarget(t);
                            setState(() => _target = t);
                            Navigator.pop(ctx);
                          }
                        },
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_count / _target).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('سبحتي وأذكاري'),
        actions: [
          IconButton(
              icon: const Icon(Icons.flag_outlined),
              onPressed: _selectTargetDialog)
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: Column(
          children: [
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: ListTile(
                  title: Text(_currentDhikr,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 17)),
                  trailing: const Icon(Icons.arrow_drop_down),
                  onTap: _selectDhikrDialog,
                ),
              ),
            ),
            const Spacer(),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 240,
                  height: 240,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 15,
                          spreadRadius: 2)
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$_count',
                          style: const TextStyle(
                              fontSize: 52, fontWeight: FontWeight.bold)),
                      Text('الهدف: $_target',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton.icon(
                      onPressed: _resetCount,
                      icon: const Icon(Icons.refresh),
                      label: const Text('تصفير')),
                  FilledButton.tonalIcon(
                      onPressed: _selectDhikrDialog,
                      icon: const Icon(Icons.list),
                      label: const Text('تغيير الذكر')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 7. شاشة الأذكار (Adhkar Screen)
// ==========================================
class AdhkarScreen extends StatefulWidget {
  const AdhkarScreen({super.key});

  @override
  State<AdhkarScreen> createState() => _AdhkarScreenState();
}

class _AdhkarScreenState extends State<AdhkarScreen> {
  final List<String> _cats = [
    'أذكار الصباح',
    'أذكار المساء',
    'بعد الصلاة',
    'أذكار النوم',
    'أذكار الاستيقاظ'
  ];
  late List<DhikrItem> _items;

  @override
  void initState() {
    super.initState();
    final p = storage.getAdhkarProgress();
    _items = [
      DhikrItem(
          id: 'm1',
          category: 'أذكار الصباح',
          text: 'أَصْبَحْنَا وَأَصْبَحَ المُلْكُ لِلَّهِ، وَالحَمْدُ لِلَّهِ.',
          virtue: 'حفظ وبركة اليوم.',
          targetCount: 1,
          currentCount: p['m1'] ?? 0),
      DhikrItem(
          id: 'm2',
          category: 'أذكار الصباح',
          text: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ.',
          virtue: 'تُغفر بها الخطايا.',
          targetCount: 100,
          currentCount: p['m2'] ?? 0),
      DhikrItem(
          id: 'e1',
          category: 'أذكار المساء',
          text: 'أَمْسَيْنَا وَأَمْسَى المُلْكُ لِلَّهِ، وَالحَمْدُ لِلَّهِ.',
          virtue: 'استشعار الملك لله.',
          targetCount: 1,
          currentCount: p['e1'] ?? 0),
      DhikrItem(
          id: 'p1',
          category: 'بعد الصلاة',
          text:
              'أَسْتَغْفِرُ اللَّهَ (3 مرات)، اللَّهُمَّ أَنْتَ السَّلاَمُ وَمِنْكَ السَّلاَمُ.',
          virtue: 'سنة دبر الصلاة.',
          targetCount: 1,
          currentCount: p['p1'] ?? 0),
      DhikrItem(
          id: 's1',
          category: 'أذكار النوم',
          text: 'بِاسْمِكَ رَبِّي وَضَعْتُ جَنْبِي وَبِكَ أَرْفَعُهُ.',
          virtue: 'حفظ النفس في المنام.',
          targetCount: 1,
          currentCount: p['s1'] ?? 0),
      DhikrItem(
          id: 'w1',
          category: 'أذكار الاستيقاظ',
          text:
              'الحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا وَإِلَيْهِ النُّشُورُ.',
          virtue: 'حمد النعمة.',
          targetCount: 1,
          currentCount: p['w1'] ?? 0),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _cats.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الأذكار اليومية'),
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: _cats.map((c) => Tab(text: c)).toList(),
          ),
        ),
        body: TabBarView(
          children: _cats.map((cat) {
            final list = _items.where((i) => i.category == cat).toList();
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (ctx, i) {
                final item = list[i];
                final isDone = item.isCompleted;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(item.text,
                            style: const TextStyle(
                                fontSize: 17,
                                height: 1.5,
                                fontWeight: FontWeight.w600)),
                        if (item.virtue != null) ...[
                          const SizedBox(height: 6),
                          Text(item.virtue!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 13)),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${item.currentCount} / ${item.targetCount}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            FilledButton.icon(
                              onPressed: isDone
                                  ? null
                                  : () async {
                                      setState(() => item.currentCount++);
                                      await storage.saveAdhkarProgress(
                                          item.id, item.currentCount);
                                    },
                              icon:
                                  Icon(isDone ? Icons.check : Icons.touch_app),
                              label: Text(isDone ? 'تم' : 'قراءة'),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ==========================================
// 8. شاشة الإحصائيات (Statistics Screen)
// ==========================================
class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final records = storage.getHistory();
    int total = 0;
    int today = 0;
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);

    for (var r in records) {
      total += r.count;
      final rDate =
          DateTime(r.timestamp.year, r.timestamp.month, r.timestamp.day);
      if (rDate.isAtSameMomentAs(todayDate)) {
        today += r.count;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('إحصائياتي')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                  child: _buildCard(
                      context, 'تسبيح اليوم', '$today', Icons.today)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildCard(context, 'الإجمالي الكلي', '$total',
                      Icons.all_inclusive)),
            ],
          ),
          const SizedBox(height: 12),
          _buildCard(context, 'عدد السجلات المحفوظة', '${records.length}',
              Icons.format_list_numbered),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext ctx, String title, String val, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(ctx).colorScheme.primary, size: 28),
            const SizedBox(height: 10),
            Text(val,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(title,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 9. شاشة السجل (History Screen)
// ==========================================
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final records = storage.getHistory();

    return Scaffold(
      appBar: AppBar(title: const Text('سجل التسبيح')),
      body: records.isEmpty
          ? const Center(child: Text('لا يوجد سجلات حتى الآن'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: records.length,
              itemBuilder: (ctx, i) {
                final r = records[i];
                final date = DateFormat('yyyy-MM-dd - hh:mm a', 'ar')
                    .format(r.timestamp);
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.check)),
                    title: Text(r.dhikrName,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(date),
                    trailing: Text('${r.count} مرة',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                );
              },
            ),
    );
  }
}

// ==========================================
// 10. شاشة الإعدادات (Settings Screen)
// ==========================================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('الوضع الليلي'),
            secondary: const Icon(Icons.dark_mode),
            value: storage.isDarkMode,
            onChanged: (val) async {
              await storage.setDarkMode(val);
              if (mounted) {
                setState(() {});
                SobhatiApp.of(context).toggleTheme(val);
              }
            },
          ),
          SwitchListTile(
            title: const Text('الاهتزاز عند الضغط'),
            secondary: const Icon(Icons.vibration),
            value: storage.isVibrationEnabled,
            onChanged: (val) async {
              await storage.setVibrationEnabled(val);
              setState(() {});
            },
          ),
          SwitchListTile(
            title: const Text('الصوت عند الضغط'),
            secondary: const Icon(Icons.volume_up),
            value: storage.isSoundEnabled,
            onChanged: (val) async {
              await storage.setSoundEnabled(val);
              setState(() {});
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('حذف كافة البيانات',
                style: TextStyle(color: Colors.red)),
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            onTap: () async {
              await storage.resetAllData();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم مسح جميع البيانات')));
                setState(() {});
              }
            },
          ),
        ],
      ),
    );
  }
}
