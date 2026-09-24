import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
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
  static const String _keyPrayerReminders = 'prayer_reminders_map';
  static const String _keyPrayerTimes = 'prayer_times_map';

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
          'لا حول ولا قوة إلا بالله',
          'اللهم صلِّ وسلم على نبينا محمد ﷺ',
          'حسبي الله ونعم الوكيل',
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

  Map<String, bool> getPrayerReminders() {
    final raw = prefs.getString(_keyPrayerReminders);
    if (raw == null) {
      return {
        'الفجر': true,
        'الظهر': true,
        'العصر': true,
        'المغرب': true,
        'العشاء': true,
        'أذكار الصباح': true,
        'أذكار المساء': true,
        'قيام الليل والوتر': true,
      };
    }
    final Map<String, dynamic> decoded = jsonDecode(raw);
    return decoded.map((k, v) => MapEntry(k, v as bool));
  }

  Future<void> setPrayerReminder(String title, bool enabled) async {
    final map = getPrayerReminders();
    map[title] = enabled;
    await prefs.setString(_keyPrayerReminders, jsonEncode(map));
  }

  Map<String, String> getPrayerTimes() {
    final raw = prefs.getString(_keyPrayerTimes);
    if (raw == null) {
      return {
        'الفجر': '04:45 ص',
        'الظهر': '12:15 م',
        'العصر': '03:45 م',
        'المغرب': '06:15 م',
        'العشاء': '07:45 م',
        'أذكار الصباح': '06:00 ص',
        'أذكار المساء': '05:00 م',
        'قيام الليل والوتر': '10:30 م',
      };
    }
    final Map<String, dynamic> decoded = jsonDecode(raw);
    return decoded.map((k, v) => MapEntry(k, v as String));
  }

  Future<void> setPrayerTime(String title, String time) async {
    final map = getPrayerTimes();
    map[title] = time;
    await prefs.setString(_keyPrayerTimes, jsonEncode(map));
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
  await initializeDateFormatting('ar', null);
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
              child: const Icon(Icons.fingerprint, size: 60, color: Colors.white),
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
    PrayersScreen(),
    StatisticsScreen(),
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
          NavigationDestination(icon: Icon(Icons.access_alarms), label: 'المنبه والصلوات'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'الإحصائيات'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'الإعدادات'),
        ],
      ),
    );
  }
}

// ==========================================
// 6. شاشة السبحة الإلكترونية (Home Screen)
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
              constraints: const BoxConstraints(maxHeight: 220),
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
// 7. شاشة الأذكار الشاملة (Adhkar Screen)
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
    'أذكار النوم',
    'أذكار الاستيقاظ',
    'بعد الصلاة',
    'الطعام والشراب',
    'أدعية مأثورة',
  ];

  late List<DhikrItem> _items;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initAdhkarData();
  }

  void _initAdhkarData() {
    final p = storage.getAdhkarProgress();

    _items = [
      // ================= أذكار الصباح =================
      DhikrItem(id: 'm01', category: 'أذكار الصباح', text: 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لاَ إِلَـهَ إِلاَّ اللهُ وَحْدَهُ لاَ شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.', virtue: 'إقرار بالتوحيد والملك لله أول النهار.', targetCount: 1, currentCount: p['m01'] ?? 0),
      DhikrItem(id: 'm02', category: 'أذكار الصباح', text: 'اللَّهُمَّ أَنْتَ رَبِّي لاَ إِلَهَ إِلاَّ أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لاَ يَغْفِرُ الذُّنُوبَ إِلاَّ أَنْتَ.', virtue: 'سيد الاستغفار؛ من قاله موقناً به فمات دخل الجنة.', targetCount: 1, currentCount: p['m02'] ?? 0),
      DhikrItem(id: 'm03', category: 'أذكار الصباح', text: 'رَضِيتُ بِاللهِ رَبّاً، وَبِالإِسْلاَمِ دِيناً، وَبِمُحَمَّدٍ ﷺ نَبِيّاً.', virtue: 'كان حقاً على الله أن يرضيه يوم القيامة.', targetCount: 3, currentCount: p['m03'] ?? 0),
      DhikrItem(id: 'm04', category: 'أذكار الصباح', text: 'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ.', virtue: 'لم يضره شيء حتى يمسي.', targetCount: 3, currentCount: p['m04'] ?? 0),
      DhikrItem(id: 'm05', category: 'أذكار الصباح', text: 'حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ.', virtue: 'كفاه الله ما أهمه من أمر دنياه وآخرته.', targetCount: 7, currentCount: p['m05'] ?? 0),
      DhikrItem(id: 'm06', category: 'أذكار الصباح', text: 'يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ، أَصْلِحْ لِي شَأْنِي كُلَّهُ وَلاَ تَكِلْنِي إِلَى نَفْسِي طَرْفَةَ عَيْنٍ.', virtue: 'تفويض واستغاثة برحمة الله.', targetCount: 1, currentCount: p['m06'] ?? 0),
      DhikrItem(id: 'm07', category: 'أذكار الصباح', text: 'سُبْحَانَ اللهِ وَبِحَمْدِهِ عَدَدَ خَلْقِهِ، وَرِضَا نَفْسِهِ، وَزِنَةَ عَرْشِهِ، وَمِدَادَ كَلِمَاتِهِ.', virtue: 'تعدل ساعات طويلة من الذكر والتسبيح.', targetCount: 3, currentCount: p['m07'] ?? 0),
      DhikrItem(id: 'm08', category: 'أذكار الصباح', text: 'اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي فِي بَصَرِي، لاَ إِلَهَ إِلاَّ أَنْتَ.', virtue: 'طلب العافية والسلامة في الحواس.', targetCount: 3, currentCount: p['m08'] ?? 0),
      DhikrItem(id: 'm09', category: 'أذكار الصباح', text: 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْكُفْرِ، وَالْفَقْرِ، وَأَعُوذُ بِكَ مِنْ عَذَابِ الْقَبْرِ، لاَ إِلَهَ إِلاَّ أَنْتَ.', virtue: 'استعاذة من خزي الدنيا وعذاب الآخرة.', targetCount: 3, currentCount: p['m09'] ?? 0),
      DhikrItem(id: 'm10', category: 'أذكار الصباح', text: 'اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي الدُّنْيَا وَالآخِرَةِ، اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي دِينِي وَدُنْيَايَ وَأَهْلِي وَمَالِي، اللَّهُمَّ اسْتُرْ عَوْرَاتِي وَآمِنْ رَوْعَاتِي.', virtue: 'دعاء الحفظ والستر الكامل.', targetCount: 1, currentCount: p['m10'] ?? 0),
      DhikrItem(id: 'm11', category: 'أذكار الصباح', text: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ.', virtue: 'حُطت خطاياه وإن كانت مثل زبد البحر.', targetCount: 100, currentCount: p['m11'] ?? 0),
      DhikrItem(id: 'm12', category: 'أذكار الصباح', text: 'لاَ إِلَهَ إِلاَّ اللهُ وَحْدَهُ لاَ شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.', virtue: 'حرز من الشيطان وعتق رقاب وكتابة حسنات.', targetCount: 100, currentCount: p['m12'] ?? 0),
      DhikrItem(id: 'm13', category: 'أذكار الصباح', text: 'أَصْبَحْنَا عَلَى فِطْرَةِ الإِسْلاَمِ، وَعَلَى كَلِمَةِ الإِخْلاَصِ، وَعَلَى دِينِ نَبِيِّنَا مُحَمَّدٍ ﷺ، وَعَلَى مِلَّةِ أَبِينَا إِبْرَاهِيمَ حَنِيفاً مُسْلِماً وَمَا كَانَ مِنَ الْمُشْرِكِينَ.', virtue: 'تجديد العهد على دين التوحيد.', targetCount: 1, currentCount: p['m13'] ?? 0),
      DhikrItem(id: 'm14', category: 'أذكار الصباح', text: 'اللَّهُمَّ بِكَ أَصْبَحْنَا، وَبِكَ أَمْسَيْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ وَإِلَيْكَ النُّشُورُ.', virtue: 'الاعتراف بنعمة الحياة والإحياء.', targetCount: 1, currentCount: p['m14'] ?? 0),
      DhikrItem(id: 'm15', category: 'أذكار الصباح', text: 'اللَّهُمَّ إِنِّي أَسْأَلُكَ عِلْماً نَافِعاً، وَرِزْقاً طَيِّباً، وَعَمَلاً مُتَقَبَّلاً.', virtue: 'دعاء مبارك في مطلع كل يوم.', targetCount: 1, currentCount: p['m15'] ?? 0),
      DhikrItem(id: 'm16', category: 'أذكار الصباح', text: 'أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ.', virtue: 'سنة نبوية جليلة تفتح الأرزاق.', targetCount: 100, currentCount: p['m16'] ?? 0),
      DhikrItem(id: 'm17', category: 'أذكار الصباح', text: 'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ.', virtue: 'من صلى عليّ عشراً حين يصبح وحين يمسي أدركته شفاعتي.', targetCount: 10, currentCount: p['m17'] ?? 0),

      // ================= أذكار المساء =================
      DhikrItem(id: 'e01', category: 'أذكار المساء', text: 'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لاَ إِلَـهَ إِلاَّ اللهُ وَحْدَهُ لاَ شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.', virtue: 'إقرار بالملك والحمد لله عند المساء.', targetCount: 1, currentCount: p['e01'] ?? 0),
      DhikrItem(id: 'e02', category: 'أذكار المساء', text: 'اللَّهُمَّ أَنْتَ رَبِّي لاَ إِلَهَ إِلاَّ أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لاَ يَغْفِرُ الذُّنُوبَ إِلاَّ أَنْتَ.', virtue: 'سيد الاستغفار في المساء.', targetCount: 1, currentCount: p['e02'] ?? 0),
      DhikrItem(id: 'e03', category: 'أذكار المساء', text: 'أَعُوذُ بِكَلِمَاتِ اللهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ.', virtue: 'لم يضره شيء ولا لدغة حشرة تلك الليلة.', targetCount: 3, currentCount: p['e03'] ?? 0),
      DhikrItem(id: 'e04', category: 'أذكار المساء', text: 'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ.', virtue: 'حفظ ووقاية حتى يصبح.', targetCount: 3, currentCount: p['e04'] ?? 0),
      DhikrItem(id: 'e05', category: 'أذكار المساء', text: 'رَضِيتُ بِاللهِ رَبّاً، وَبِالإِسْلاَمِ دِيناً، وَبِمُحَمَّدٍ ﷺ نَبِيّاً.', virtue: 'رضا تام يوم القيامة.', targetCount: 3, currentCount: p['e05'] ?? 0),
      DhikrItem(id: 'e06', category: 'أذكار المساء', text: 'اللَّهُمَّ بِكَ أَمْسَيْنَا، وَبِكَ أَصْبَحْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ وَإِلَيْكَ الْمَصِيرُ.', virtue: 'استشعار الرجوع إلى الله تعالى.', targetCount: 1, currentCount: p['e06'] ?? 0),
      DhikrItem(id: 'e07', category: 'أذكار المساء', text: 'يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ، أَصْلِحْ لِي شَأْنِي كُلَّهُ وَلاَ تَكِلْنِي إِلَى نَفْسِي طَرْفَةَ عَيْنٍ.', virtue: 'صلاح الأحوال في ليلتك.', targetCount: 1, currentCount: p['e07'] ?? 0),
      DhikrItem(id: 'e08', category: 'أذكار المساء', text: 'حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ.', virtue: 'كفاية الهموم والمخاوف.', targetCount: 7, currentCount: p['e08'] ?? 0),
      DhikrItem(id: 'e09', category: 'أذكار المساء', text: 'اللَّهُمَّ عَالِمَ الغَيْبِ وَالشَّهَادَةِ فَاطِرَ السَّمَوَاتِ وَالأَرْضِ، رَبَّ كُلِّ شَيْءٍ وَمَلِيكَهُ، أَعُوذُ بِكَ مِنْ شَرِّ نَفْسِي، وَمِنْ شَرِّ الشَّيْطَانِ وَشِرْكِهِ، وَأَنْ أَقْتَرِفَ عَلَى نَفْسِي سُوءاً أَوْ أَجُرَّهُ إِلَى مُسْلِمٍ.', virtue: 'عصمة من وساوس الإنس والجن.', targetCount: 1, currentCount: p['e09'] ?? 0),
      DhikrItem(id: 'e10', category: 'أذكار المساء', text: 'اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي دِينِي وَدُنْيَايَ وَأَهْلِي وَمَالِي، اللَّهُمَّ اسْتُرْ عَوْرَاتِي وَآمِنْ رَوْعَاتِي، وَاحْفَظْنِي مِنْ بَيْنِ يَدَيَّ وَمِنْ خَلْفِي وَعَنْ يَمِينِي وَعَنْ شِمَالِي وَمِنْ فَوْقِي، وَأَعُوذُ بِعَظَمَتِكَ أَنْ أُغْتَالَ مِنْ تَحْتِي.', virtue: 'حفظ إلهي شامل من جميع الجهات الست.', targetCount: 1, currentCount: p['e10'] ?? 0),
      DhikrItem(id: 'e11', category: 'أذكار المساء', text: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ.', virtue: 'مغفرة الذنوب ورفعة الدرجات.', targetCount: 100, currentCount: p['e11'] ?? 0),
      DhikrItem(id: 'e12', category: 'أذكار المساء', text: 'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ.', virtue: 'نيل الشفاعة ومغفرة الزلات.', targetCount: 10, currentCount: p['e12'] ?? 0),

      // ================= أذكار النوم =================
      DhikrItem(id: 's01', category: 'أذكار النوم', text: 'بِاسْمِكَ رَبِّي وَضَعْتُ جَنْبِي، وَبِكَ أَرْفَعُهُ، فَإِن أَمْسَكْتَ نَفْسِي فارْحَمْهَا، وَإِنْ أَرْسَلْتَهَا فَاحْفَظْهَا بِمَا تَحْفَظُ بِهِ عِبَادَكَ الصَّالِحِينَ.', virtue: 'حفظ الروح والجسد أثناء النوم.', targetCount: 1, currentCount: p['s01'] ?? 0),
      DhikrItem(id: 's02', category: 'أذكار النوم', text: 'اللَّهُمَّ خَلَقْتَ نَفْسِي وَأَنْتَ تَوَفَّاهَا، لَكَ مَمَاتُهَا وَمَحْيَاهَا، إِنْ أَحْيَيْتَهَا فَاحْفَظْهَا، وَإِنْ أَمَتَّهَا فَاغْفِرْ لَهَا، اللَّهُمَّ إِنِّي أَسْأَلُكَ العَافِيَةَ.', virtue: 'تسليم النفس لبارئها.', targetCount: 1, currentCount: p['s02'] ?? 0),
      DhikrItem(id: 's03', category: 'أذكار النوم', text: 'اللَّهُمَّ قِنِي عَذَابَكَ يَوْمَ تَبْعَثُ عِبَادَكَ.', virtue: 'يقال عند وضع اليد اليمنى تحت الخد الأيمن.', targetCount: 3, currentCount: p['s03'] ?? 0),
      DhikrItem(id: 's04', category: 'أذكار النوم', text: 'بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا.', virtue: 'ذكر النوم النبوي المأثور.', targetCount: 1, currentCount: p['s04'] ?? 0),
      DhikrItem(id: 's05', category: 'أذكار النوم', text: 'سُبْحَانَ اللَّهِ (33 مرة)، الْحَمْدُ لِلَّهِ (33 مرة)، اللَّهُ أَكْبَرُ (34 مرة).', virtue: 'خير للإنسان من خادم ويعطي قوة في البدن.', targetCount: 1, currentCount: p['s05'] ?? 0),
      DhikrItem(id: 's06', category: 'أذكار النوم', text: 'قراءة آية الكرسي: ﴿اللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ...﴾', virtue: 'لا يزال عليك من الله حافظ ولا يقربك شيطان حتى تصبح.', targetCount: 1, currentCount: p['s06'] ?? 0),
      DhikrItem(id: 's07', category: 'أذكار النوم', text: 'قراءة آخر آيتين من سورة البقرة: ﴿آمَنَ الرَّسُولُ بِمَا أُنزِلَ إِلَيْهِ مِن رَّبِّهِ وَالْمُؤْمِنُونَ...﴾', virtue: 'من قرأهما في ليلة كفتاه.', targetCount: 1, currentCount: p['s07'] ?? 0),
      DhikrItem(id: 's08', category: 'أذكار النوم', text: 'قراءة سورة الإخلاص والمعوذتين، والنفث في الكفين ومسح الجسد.', virtue: 'سنة نبوية للحفظ والوقاية.', targetCount: 3, currentCount: p['s08'] ?? 0),
      DhikrItem(id: 's09', category: 'أذكار النوم', text: 'اللَّهُمَّ أَسْلَمْتُ نَفْسِي إِلَيْكَ، وَفَوَّضْتُ أَمْرِي إِلَيْكَ، وَوَجَّهْتُ وَجْهِي إِلَيْكَ، وَأَلْجَأْتُ ظَهْرِي إِلَيْكَ، رَغْبَةً وَرَهْبَةً إِلَيْكَ، لاَ مَلْجَأَ وَلاَ مَنْجَا مِنْكَ إِلاَّ إِلَيْكَ، آمَنْتُ بِكِتَابِكَ الَّذِي أَنْزَلْتَ، وَبِنَبِيِّكَ الَّذِي أَرْسَلْتَ.', virtue: 'من مات من ليلته مات على الفطرة.', targetCount: 1, currentCount: p['s09'] ?? 0),

      // ================= أذكار الاستيقاظ =================
      DhikrItem(id: 'w01', category: 'أذكار الاستيقاظ', text: 'الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا وَإِلَيْهِ النُّشُورُ.', virtue: 'حمد الله على نعمة رد الروح والحياة.', targetCount: 1, currentCount: p['w01'] ?? 0),
      DhikrItem(id: 'w02', category: 'أذكار الاستيقاظ', text: 'الْحَمْدُ لِلَّهِ الَّذِي عَافَانِي فِي جَسَدِي، وَرَدَّ عَلَيَّ رُوحِي، وَأَذِنَ لِي بِذِكْرِهِ.', virtue: 'شكر الله على العافية والذكر.', targetCount: 1, currentCount: p['w02'] ?? 0),
      DhikrItem(id: 'w03', category: 'أذكار الاستيقاظ', text: 'لاَ إِلَهَ إِلاَّ اللهُ وَحْدَهُ لاَ شَرِيكَ لَهُ، لَهُ المُلْكُ وَلَهُ الحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، سُبْحَانَ اللهِ، وَالحَمْدُ لِلَّهِ، وَلاَ إِلَهَ إِلاَّ اللهُ، وَاللهُ أَكْبَرُ، وَلاَ حَوْلَ وَلاَ قُوَّةَ إِلاَّ بِاللهِ الْعَلِيِّ الْعَظِيمِ، رَبِّ اغْفِرْ لِي.', virtue: 'من تعارّ من الليل فقالها ثم دعا استجيب له أو توضأ وصلى قبلت صلاته.', targetCount: 1, currentCount: p['w03'] ?? 0),

      // ================= أذكار بعد الصلاة =================
      DhikrItem(id: 'p01', category: 'بعد الصلاة', text: 'أَسْتَغْفِرُ اللهَ، أَسْتَغْفِرُ اللهَ، أَسْتَغْفِرُ اللهَ.', virtue: 'البدء بالاستغفار بعد السلام مباشرة.', targetCount: 3, currentCount: p['p01'] ?? 0),
      DhikrItem(id: 'p02', category: 'بعد الصلاة', text: 'اللَّهُمَّ أَنْتَ السَّلاَمُ، وَمِنْكَ السَّلاَمُ، تَبَارَكْتَ يَا ذَا الْجَلاَلِ وَالإِكْرَامِ.', virtue: 'سنة نبوية مؤكدة دبر كل صلاة مكتوبة.', targetCount: 1, currentCount: p['p02'] ?? 0),
      DhikrItem(id: 'p03', category: 'بعد الصلاة', text: 'لاَ إِلَهَ إِلاَّ اللهُ وَحْدَهُ لاَ شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، اللَّهُمَّ لاَ مَانِعَ لِمَا أَعْطَيْتَ، وَلاَ مُعْطِيَ لِمَا مَنَعْتَ، وَلاَ يَنْفَعُ ذَا الْجَدِّ مِنْكَ الْجَدُّ.', virtue: 'إقرار بالقدر والتوكل.', targetCount: 1, currentCount: p['p03'] ?? 0),
      DhikrItem(id: 'p04', category: 'بعد الصلاة', text: 'لاَ إِلَهَ إِلاَّ اللهُ وَحْدَهُ لاَ شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ. لاَ حَوْلَ وَلاَ قُوَّةَ إِلاَّ بِاللهِ، لاَ إِلَهَ إِلاَّ اللهُ، وَلاَ نَعْبُدُ إِلاَّ إِيَّاهُ، لَهُ النِّعْمَةُ وَلَهُ الْفَضْلُ وَلَهُ الثَّنَاءُ الْحَسَنُ.', virtue: 'توحيد وإخلاص العبادة لله وحده.', targetCount: 1, currentCount: p['p04'] ?? 0),
      DhikrItem(id: 'p05', category: 'بعد الصلاة', text: 'سُبْحَانَ اللَّهِ (33)، الْحَمْدُ لِلَّهِ (33)، اللَّهُ أَكْبَرُ (33)، وتَمام المئة: لاَ إِلَهَ إِلاَّ اللهُ وَحْدَهُ لاَ شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.', virtue: 'غفرت خطاياه وإن كانت مثل زبد البحر.', targetCount: 1, currentCount: p['p05'] ?? 0),
      DhikrItem(id: 'p06', category: 'بعد الصلاة', text: 'قراءة آية الكرسي دبر كل صلاة.', virtue: 'من قرأها دبر كل صلاة لم يمنعه من دخول الجنة إلا أن يموت.', targetCount: 1, currentCount: p['p06'] ?? 0),
      DhikrItem(id: 'p07', category: 'بعد الصلاة', text: 'قراءة سورة الإخلاص، والفلق، والناس.', virtue: 'تقرأ مرة بعد الظهر والعصر والعشاء، وثلاثاً بعد الفجر والمغرب.', targetCount: 1, currentCount: p['p07'] ?? 0),
      DhikrItem(id: 'p08', category: 'بعد الصلاة', text: 'اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ، وَشُكْرِكَ، وَحُسْنِ عِبَادَتِكَ.', virtue: 'وصية رسول الله ﷺ لمعاذ بن جبل.', targetCount: 1, currentCount: p['p08'] ?? 0),

      // ================= أذكار الطعام والشراب =================
      DhikrItem(id: 'f01', category: 'الطعام والشراب', text: 'بِسْمِ اللهِ.', virtue: 'يمنع مشاركة الشيطان في الطعام والبركة فيه.', targetCount: 1, currentCount: p['f01'] ?? 0),
      DhikrItem(id: 'f02', category: 'الطعام والشراب', text: 'بِسْمِ اللَّهِ فِي أَوَّلِهِ وَآخِرِهِ.', virtue: 'يقال إذا نسي التسمية في أول الطعام.', targetCount: 1, currentCount: p['f02'] ?? 0),
      DhikrItem(id: 'f03', category: 'الطعام والشراب', text: 'الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنِي هَذَا وَرَزَقَنِيهِ مِنْ غَيْرِ حَوْلٍ مِنِّي وَلَا قُوَّةٍ.', virtue: 'غُفر له ما تقدم من ذنبه.', targetCount: 1, currentCount: p['f03'] ?? 0),
      DhikrItem(id: 'f04', category: 'الطعام والشراب', text: 'الْحَمْدُ لِلَّهِ حَمْداً كَثِيراً طَيِّباً مُبَارَكاً فِيهِ، غَيْرَ مَكْفِيٍّ وَلاَ مُوَدَّعٍ، وَلاَ مُسْتَغْنًى عَنْهُ رَبَّنَا.', virtue: 'حمد النبي ﷺ عند رفع مائدته.', targetCount: 1, currentCount: p['f04'] ?? 0),
      DhikrItem(id: 'f05', category: 'الطعام والشراب', text: 'اللَّهُمَّ بَارِكْ لَنَا فِيهِ وَأَطْعِمْنَا خَيْراً مِنْهُ (وإذا كان لبناً: اللَّهُمَّ بَارِكْ لَنَا فِيهِ وَزِدْنَا مِنْهُ).', virtue: 'دعاء البركة في الرزق والطعام.', targetCount: 1, currentCount: p['f05'] ?? 0),
      DhikrItem(id: 'f06', category: 'الطعام والشراب', text: 'أَفْطَرَ عِنْدَكُمُ الصَّائِمُونَ، وَأَكَلَ طَعَامَكُمُ الأَبْرَارُ، وَصَلَّتْ عَلَيْكُمُ المَلاَئِكَةُ.', virtue: 'دعاء الضيف لأهل الطعام بعد فراغه منه.', targetCount: 1, currentCount: p['f06'] ?? 0),
      DhikrItem(id: 'f07', category: 'الطعام والشراب', text: 'اللَّهُمَّ أَطْعِمْ مَنْ أَطْعَمَنِي، وَاسْقِ مَنْ سَقَانِي.', virtue: 'دعاء لمن يقدم لك الطعام أو يسقيك.', targetCount: 1, currentCount: p['f07'] ?? 0),

      // ================= أدعية مأثورة وجامعة =================
      DhikrItem(id: 'd01', category: 'أدعية مأثورة', text: 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ.', virtue: 'أكثر وأجمع دعاء كان يدعو به النبي ﷺ.', targetCount: 3, currentCount: p['d01'] ?? 0),
      DhikrItem(id: 'd02', category: 'أدعية مأثورة', text: 'يَا مُقَلِّبَ الْقُلُوبِ ثَبِّتْ قَلْبِي عَلَى دِينِكَ.', virtue: 'تثبيت الإيمان وحسن الخاتمة.', targetCount: 3, currentCount: p['d02'] ?? 0),
      DhikrItem(id: 'd03', category: 'أدعية مأثورة', text: 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَالْعَجْزِ وَالْكَسَلِ، وَالْبُخْلِ وَالْجُبْنِ، وَضَلَعِ الدَّيْنِ وَغَلَبَةِ الرِّجَالِ.', virtue: 'تفريج الكروب والديون والمخاوف.', targetCount: 3, currentCount: p['d03'] ?? 0),
      DhikrItem(id: 'd04', category: 'أدعية مأثورة', text: 'لاَ إِلَهَ إِلاَّ أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ الظَّالِمِينَ.', virtue: 'دعوة ذي النون؛ ما دعا بها مكروب إلا فرج الله عنه.', targetCount: 3, currentCount: p['d04'] ?? 0),
      DhikrItem(id: 'd05', category: 'أدعية مأثورة', text: 'اللَّهُمَّ إِنَّكَ عَفُوٌّ كَرِيمٌ تُحِبُّ الْعَفْوَ فَاعْفُ عَنِّي.', virtue: 'دعاء ليالي القدر والمغفرة العظمى.', targetCount: 3, currentCount: p['d05'] ?? 0),
      DhikrItem(id: 'd06', category: 'أدعية مأثورة', text: 'رَبِّ اغْفِرْ لِي وَلِوَالِدَيَّ وَارْحَمْهُمَا كَمَا رَبَّيَانِي صَغِيراً.', virtue: 'بر الوالدين ونيل رحمات الله الواسعة.', targetCount: 3, currentCount: p['d06'] ?? 0),
      DhikrItem(id: 'd07', category: 'أدعية مأثورة', text: 'رَبِّ اشْرَحْ لِي صَدْرِي وَيَسِّرْ لِي أَمْرِي وَاحْلُلْ عُقْدَةً مِّن لِّسَانِي يَفْقَهُوا قَوْلِي.', virtue: 'دعاء تيسير العسير وانشراح الصدر.', targetCount: 1, currentCount: p['d07'] ?? 0),
      DhikrItem(id: 'd08', category: 'أدعية مأثورة', text: 'اللَّهُمَّ اكْفِنِي بِحَلَالِكَ عَنْ حَرَامِكَ، وَأَغْنِنِي بِفَضْلِكَ عَمَّنْ سِوَاكَ.', virtue: 'قضاء الديون وجلب البركة في الرزق الحلال.', targetCount: 3, currentCount: p['d08'] ?? 0),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _cats.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('حصن المسلم والأذكار'),
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: _cats.map((c) => Tab(text: c)).toList(),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'ابحث في الأذكار والأدعية...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: _cats.map((cat) {
                  final list = _items.where((i) {
                    final matchCategory = i.category == cat;
                    if (_searchQuery.isEmpty) return matchCategory;
                    return matchCategory &&
                        (i.text.contains(_searchQuery) ||
                            (i.virtue != null && i.virtue!.contains(_searchQuery)));
                  }).toList();

                  if (list.isEmpty) {
                    return const Center(child: Text('لا توجد نتائج مطابقة للبحث'));
                  }

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
                                      fontSize: 16,
                                      height: 1.6,
                                      fontWeight: FontWeight.w600)),
                              if (item.virtue != null) ...[
                                const SizedBox(height: 8),
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
                                          fontWeight: FontWeight.bold, fontSize: 15)),
                                  FilledButton.icon(
                                    onPressed: isDone
                                        ? null
                                        : () async {
                                            if (storage.isVibrationEnabled) {
                                              HapticFeedback.lightImpact();
                                            }
                                            setState(() => item.currentCount++);
                                            await storage.saveAdhkarProgress(
                                                item.id, item.currentCount);
                                          },
                                    icon: Icon(isDone ? Icons.check : Icons.touch_app),
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
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 8. شاشة منبه الصلوات والأذكار (Prayers Screen)
// ==========================================
class PrayersScreen extends StatefulWidget {
  const PrayersScreen({super.key});

  @override
  State<PrayersScreen> createState() => _PrayersScreenState();
}

class _PrayersScreenState extends State<PrayersScreen> {
  late Map<String, bool> _reminders;
  late Map<String, String> _times;

  @override
  void initState() {
    super.initState();
    _reminders = storage.getPrayerReminders();
    _times = storage.getPrayerTimes();
  }

  void _pickTime(String prayerKey) async {
    final curTimeStr = _times[prayerKey] ?? '12:00 م';
    final parts = curTimeStr.replaceAll(' ص', '').replaceAll(' م', '').split(':');
    int hour = int.tryParse(parts[0]) ?? 12;
    int minute = int.tryParse(parts[1]) ?? 0;
    if (curTimeStr.contains('م') && hour != 12) hour += 12;
    if (curTimeStr.contains('ص') && hour == 12) hour = 0;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
    );

    if (picked != null) {
      final period = picked.hour >= 12 ? 'م' : 'ص';
      int formattedHour = picked.hourOfPeriod;
      if (formattedHour == 0) formattedHour = 12;
      final formattedMinute = picked.minute.toString().padLeft(2, '0');
      final newTimeStr = '$formattedHour:$formattedMinute $period';

      await storage.setPrayerTime(prayerKey, newTimeStr);
      setState(() {
        _times[prayerKey] = newTimeStr;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم ضبط توقيت منبه $prayerKey على $newTimeStr')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final prayers = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
    final athkarAlerts = ['أذكار الصباح', 'أذكار المساء', 'قيام الليل والوتر'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('منبه الصلوات والأذكار'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'اضغط على وقت الصلاة لتعديل التوقيت بدقة بحسب مدينتك وتفعيل التنبيه المطلوب.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text('مواقيت وتنبيهات الصلوات المفروضة',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...prayers.map((prayer) => _buildReminderTile(prayer, Icons.mosque)),
          const SizedBox(height: 20),
          const Text('تنبيهات الأذكار والنوافل اليومية',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...athkarAlerts.map((dhikr) => _buildReminderTile(dhikr, Icons.alarm)),
        ],
      ),
    );
  }

  Widget _buildReminderTile(String title, IconData icon) {
    final isEnabled = _reminders[title] ?? true;
    final timeStr = _times[title] ?? '--:--';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: InkWell(
          onTap: () => _pickTime(title),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.edit_calendar, size: 16, color: Colors.blueGrey),
                const SizedBox(width: 4),
                Text('الوقت المختار: $timeStr (تغيير)',
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
        trailing: Switch(
          value: isEnabled,
          onChanged: (val) async {
            await storage.setPrayerReminder(title, val);
            setState(() {
              _reminders[title] = val;
            });
          },
        ),
      ),
    );
  }
}

// ==========================================
// 9. شاشة الإحصائيات (Statistics Screen)
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
      appBar: AppBar(title: const Text('إحصائياتي والسجل')),
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
          _buildCard(context, 'عدد الجلسات المحفوظة', '${records.length}',
              Icons.format_list_numbered),
          const SizedBox(height: 16),
          const Text('آخر سجلات التسبيح المكتملة',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          if (records.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('لا توجد جلسات مسجلة بعد')),
            )
          else
            ...records.take(15).map((r) {
              final date = DateFormat('yyyy-MM-dd - hh:mm a', 'ar')
                  .format(r.timestamp);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
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
            }),
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
            title: const Text('حذف كافة البيانات وإعادة التعيين',
                style: TextStyle(color: Colors.red)),
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('تأكيد الحذف'),
                  content: const Text('هل أنت متأكد من رغبتك في حذف جميع الإحصائيات والأذكار المخصصة؟'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
                  ],
                ),
              );

              if (confirm == true) {
                await storage.resetAllData();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم مسح جميع البيانات بنجاح')));
                  setState(() {});
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
