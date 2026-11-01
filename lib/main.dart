// lib/main.dart
// অনুশীলন (Onushilon) — প্রফেশনাল HSC ও এডমিশন MCQ প্র্যাকটিস এবং পরীক্ষা অ্যাপ

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import 'data/syllabus_data.dart';
import 'models/app_models.dart';
import 'services/firebase_sync_service.dart';
import 'widgets/tactile_widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OnushilonApp());
}

class OnushilonApp extends StatefulWidget {
  const OnushilonApp({super.key});

  @override
  State<OnushilonApp> createState() => _OnushilonAppState();
}

class _OnushilonAppState extends State<OnushilonApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(FirebaseSyncService.localThemeKey);
    if (saved == 'dark') {
      setState(() => _themeMode = ThemeMode.dark);
    } else if (saved == 'light') {
      setState(() => _themeMode = ThemeMode.light);
    }
  }

  Future<void> _toggleTheme() async {
    final next = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    setState(() => _themeMode = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        FirebaseSyncService.localThemeKey, next == ThemeMode.dark ? 'dark' : 'light');
  }

  @override
  Widget build(BuildContext context) {
    const lightPal = AppPalette(false);
    const darkPal = AppPalette(true);

    return MaterialApp(
      title: 'অনুশীলন',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: lightPal.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: lightPal.primary,
          brightness: Brightness.light,
          primary: lightPal.primary,
          surface: lightPal.card,
        ),
        fontFamily: 'Hind Siliguri',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkPal.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: darkPal.primary,
          brightness: Brightness.dark,
          primary: darkPal.primary,
          surface: darkPal.card,
        ),
        fontFamily: 'Hind Siliguri',
      ),
      home: OnushilonShell(onToggleTheme: _toggleTheme),
    );
  }
}

enum MainTab { home, exam, saved, settings }
enum ActiveScreen { mainTabs, confirmSetup, liveExam, examResult }

class OnushilonShell extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const OnushilonShell({super.key, required this.onToggleTheme});

  @override
  State<OnushilonShell> createState() => _OnushilonShellState();
}

class _OnushilonShellState extends State<OnushilonShell> {
  // Auth & Cloud Loading State
  Map<String, dynamic>? _authUser;
  bool _isDbLoading = false;
  String _dbLoadingText = 'ক্লাউড ডাটাবেইজ লোড হচ্ছে...';
  String _loginError = '';
  bool _obscurePassword = true;
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();

  // Core App Data State (mirrors exam_room_junaid HTML state)
  List<SubjectItem> _subjects = FirebaseSyncService.buildDefaultSubjects();
  List<ChapterItem> _chapters = FirebaseSyncService.buildDefaultChapters();
  List<QuestionItem> _bank = [];
  List<CustomExamItem> _customExams = [];
  List<ExamResultItem> _savedExams = [];
  List<String> _savedQuestions = [];
  Map<String, QuestionItem> _savedQuestionsData = {};
  Map<String, int> _unsavedTimestamps = {};
  List<ExamResultItem> _history = [];
  Set<String> _deletedIds = {};
  Map<String, int> _deletedBanksMap = {};

  // Navigation & View Sub-States
  MainTab _activeTab = MainTab.home;
  ActiveScreen _activeScreen = ActiveScreen.mainTabs;
  String _examHubMode = 'exam'; // 'exam' | 'practice'
  String _settingsSubTab = 'examBankTab'; // 'examBankTab' | 'hierarchyTab'
  String _savedSubTab = 'exams'; // 'exams' | 'questions'
  String _selectedProgressSubj = '';

  // Direct JSON Exam Form Controllers
  final TextEditingController _directTitleCtrl = TextEditingController();
  final TextEditingController _directMinutesCtrl = TextEditingController(text: '10');
  final TextEditingController _directJsonCtrl = TextEditingController();
  bool _directNegMarking = false;

  // Step 3/3 Practice Confirm Setup State
  String _step3SourceMode = 'bank'; // 'bank' | 'saved'
  String _step3Subject = DefaultSyllabusData.defaultSubjects.first['name']!;
  Set<String> _step3SelectedSavedSubjects = {};
  Set<String> _step3SelectedChapters = {};
  Set<String> _step3SelectedBanks = {};
  int _step3QCount = 10;
  int _step3Time = 10;
  bool _step3OnlyPrevWrong = false;
  bool _step3NegMarking = false;

  // Live Exam State
  String _liveExamTitle = 'পরীক্ষা';
  int _liveExamMinutes = 10;
  bool _liveExamNeg = false;
  List<QuestionItem> _liveExamQuestions = [];
  Map<String, String> _liveExamAnswers = {};
  Timer? _examTimer;
  int _secondsRemaining = 0;
  DateTime? _examStartedAt;
  final Map<int, GlobalKey> _questionItemKeys = {};

  // Result View State
  ExamResultItem? _currentResult;
  String _resultFilter = 'all'; // 'all' | 'good' | 'bad' | 'skip'

  // Saved View State
  String _savedFilterSubject = '';
  String _savedFilterChapter = '';
  final TextEditingController _savedSearchCtrl = TextEditingController();
  String _savedQuestionsMode = 'revision'; // 'revision' | 'practice'
  Map<String, String> _savedPracticeAnswers = {};
  Set<String> _selectedSavedQuestionIds = {};

  // Settings Question Bank Upload & Filter State
  String _importSubject = DefaultSyllabusData.defaultSubjects.first['name']!;
  String _importChapter = '';
  final TextEditingController _importNewChapCtrl = TextEditingController();
  final TextEditingController _importBankNameCtrl = TextEditingController();
  final TextEditingController _importJsonPasteCtrl = TextEditingController();
  String _bankManageSubjFilter = '';
  String _bankManageChapFilter = '';
  final TextEditingController _bankManageSearchCtrl = TextEditingController();

  // Settings Subject & Chapter CRUD State
  String _editingSubjectId = '';
  final TextEditingController _subjNameCtrl = TextEditingController();
  final TextEditingController _subjSubtitleCtrl = TextEditingController();
  final TextEditingController _subjThumbCtrl = TextEditingController();

  String _editingChapterId = '';
  String _chapParentSubject = DefaultSyllabusData.defaultSubjects.first['name']!;
  final TextEditingController _chapNameCtrl = TextEditingController();
  final TextEditingController _chapThumbCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initLocalAndCloudState();
  }

  @override
  void dispose() {
    _examTimer?.cancel();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _directTitleCtrl.dispose();
    _directMinutesCtrl.dispose();
    _directJsonCtrl.dispose();
    _savedSearchCtrl.dispose();
    _importNewChapCtrl.dispose();
    _importBankNameCtrl.dispose();
    _importJsonPasteCtrl.dispose();
    _bankManageSearchCtrl.dispose();
    _subjNameCtrl.dispose();
    _subjSubtitleCtrl.dispose();
    _subjThumbCtrl.dispose();
    _chapNameCtrl.dispose();
    _chapThumbCtrl.dispose();
    super.dispose();
  }

  Future<void> _initLocalAndCloudState() async {
    final prefs = await SharedPreferences.getInstance();
    final rawState = prefs.getString(FirebaseSyncService.localStateKey);
    if (rawState != null && rawState.isNotEmpty) {
      try {
        final parsed = jsonDecode(rawState) as Map<String, dynamic>;
        _applyNormalizedMap(parsed);
      } catch (_) {}
    }

    final rawAuth = prefs.getString(FirebaseSyncService.localAuthKey);
    if (rawAuth != null && rawAuth.isNotEmpty) {
      try {
        final parsedAuth = jsonDecode(rawAuth) as Map<String, dynamic>;
        if ((parsedAuth['email'] ?? '').toString().isNotEmpty) {
          setState(() => _authUser = parsedAuth);
          await _pullFromFirebaseCloud(showToast: false);
        }
      } catch (_) {}
    }
  }

  void _applyNormalizedMap(Map<String, dynamic> map) {
    final delList = (map['deletedIds'] is List) ? (map['deletedIds'] as List) : const [];
    final delSet = delList.map((e) => e.toString()).toSet();

    final rawSubjs = (map['subjects'] is List) ? (map['subjects'] as List) : const [];
    var subjs = rawSubjs
        .whereType<Map>()
        .map((m) => SubjectItem.fromMap(m))
        .where((s) => !delSet.contains(s.id))
        .toList();
    if (subjs.isEmpty) {
      subjs = FirebaseSyncService.buildDefaultSubjects();
    } else {
      final others = subjs.where((s) => s.name == 'অন্যান্য' || s.id == 'subj-others').toList();
      final rest = subjs.where((s) => s.name != 'অন্যান্য' && s.id != 'subj-others').toList();
      subjs = [...rest, ...others];
    }

    final rawChaps = (map['chapters'] is List) ? (map['chapters'] as List) : const [];
    var chaps = rawChaps
        .whereType<Map>()
        .map((m) => ChapterItem.fromMap(m))
        .where((c) => !delSet.contains(c.id))
        .toList();
    chaps = FirebaseSyncService.ensureDefaultChaptersSeeded(chaps, delSet);

    final delBanks = <String, int>{};
    if (map['deletedBanksMap'] is Map) {
      (map['deletedBanksMap'] as Map).forEach((k, v) {
        delBanks[k.toString()] = int.tryParse(v.toString()) ?? 0;
      });
    }

    final rawBank = (map['bank'] is List)
        ? (map['bank'] as List)
        : (map['bank'] is Map ? (map['bank'] as Map).values.toList() : const []);
    final bankList = <QuestionItem>[];
    final seenIds = <String>{};
    for (var i = 0; i < rawBank.length; i++) {
      if (rawBank[i] is! Map) continue;
      final q = QuestionItem.fromMap(rawBank[i] as Map, index: i);
      if (delSet.contains(q.id) || seenIds.contains(q.id)) continue;
      final comp = FirebaseSyncService.bankCompositeKey(q.subject, q.chapter, q.sourcePdf);
      if ((delBanks[comp] ?? 0) > 0) continue;
      seenIds.add(q.id);
      bankList.add(q);
    }

    final rawCustom = (map['customExams'] is List) ? (map['customExams'] as List) : const [];
    final customList = rawCustom
        .whereType<Map>()
        .map((m) => CustomExamItem.fromMap(m))
        .where((c) => !delSet.contains(c.id))
        .toList();

    final rawSavedEx = (map['savedExams'] is List) ? (map['savedExams'] as List) : const [];
    final savedExList = rawSavedEx
        .whereType<Map>()
        .map((m) => ExamResultItem.fromMap(m))
        .where((e) => !delSet.contains(e.id))
        .toList();

    final rawHist = (map['history'] is List) ? (map['history'] as List) : const [];
    final histList = rawHist
        .whereType<Map>()
        .map((m) => ExamResultItem.fromMap(m))
        .where((h) => !delSet.contains(h.id))
        .toList();

    final unsavedMap = <String, int>{};
    if (map['unsavedTimestamps'] is Map) {
      (map['unsavedTimestamps'] as Map).forEach((k, v) {
        unsavedMap[k.toString()] = int.tryParse(v.toString()) ?? 0;
      });
    }

    final savedQData = <String, QuestionItem>{};
    if (map['savedQuestionsData'] is Map) {
      (map['savedQuestionsData'] as Map).forEach((k, v) {
        if (v is Map && !delSet.contains(k.toString())) {
          savedQData[k.toString()] = QuestionItem.fromMap(v);
        }
      });
    }

    final rawSavedQIds = (map['savedQuestions'] is List) ? (map['savedQuestions'] as List) : const [];
    final savedQIds = <String>[];
    for (final id in rawSavedQIds) {
      final qid = id.toString();
      if (qid.isNotEmpty && !delSet.contains(qid) && !savedQIds.contains(qid)) {
        savedQIds.add(qid);
      }
    }

    // Ensure all saved question objects have backups in savedQData
    void backupFrom(List<QuestionItem> list) {
      for (final q in list) {
        if (savedQIds.contains(q.id) && !savedQData.containsKey(q.id)) {
          savedQData[q.id] = q;
        }
      }
    }

    backupFrom(bankList);
    for (final c in customList) {
      backupFrom(c.questions);
    }
    for (final s in savedExList) {
      backupFrom(s.questions);
    }
    for (final h in histList) {
      backupFrom(h.questions);
    }

    setState(() {
      _subjects = subjs;
      _chapters = chaps;
      _bank = bankList;
      _customExams = customList;
      _savedExams = savedExList;
      _savedQuestions = savedQIds;
      _savedQuestionsData = savedQData;
      _unsavedTimestamps = unsavedMap;
      _history = histList;
      _deletedIds = delSet;
      _deletedBanksMap = delBanks;
    });
  }

  Map<String, dynamic> _buildStatePayload() {
    return {
      'subjects': _subjects.map((s) => s.toMap()).toList(),
      'subjectOrder': _subjects.map((s) => s.id).toList(),
      'chapters': _chapters.map((c) => c.toMap()).toList(),
      'chapterOrder': _chapters.map((c) => c.id).toList(),
      'bank': _bank.map((q) => q.toMap()).toList(),
      'deletedBanksMap': _deletedBanksMap,
      'customExams': _customExams.map((c) => c.toMap()).toList(),
      'savedExams': _savedExams.map((e) => e.toMap()).toList(),
      'savedQuestions': _savedQuestions,
      'savedQuestionsData': _savedQuestionsData.map((k, v) => MapEntry(k, v.toMap())),
      'unsavedTimestamps': _unsavedTimestamps,
      'deletedIds': _deletedIds.toList(),
      'history': _history.map((h) => h.toMap()).toList(),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  Future<void> _saveStateAndSync() async {
    final payload = _buildStatePayload();
    final prefs = await SharedPreferences.getInstance();
    // Save compact state locally
    await prefs.setString(FirebaseSyncService.localStateKey, jsonEncode(payload));
    // Push to Firebase Realtime Database (study-room-exam)
    unawaited(FirebaseSyncService.pushExamCloudData(payload));
  }

  Future<void> _pullFromFirebaseCloud({bool showToast = false}) async {
    setState(() {
      _isDbLoading = true;
      _dbLoadingText = showToast
          ? 'ক্লাউড থেকে সর্বশেষ ডাটা সিঙ্ক হচ্ছে...'
          : 'অনুগ্রহ করে অপেক্ষা করুন, ডাটা সিঙ্ক করা হচ্ছে...';
    });

    try {
      final classCloud = await FirebaseSyncService.fetchClassCloudSubjectsAndChapters(
          _authUser?['idToken']?.toString());
      final examCloud = await FirebaseSyncService.fetchExamCloudData();

      final merged = _buildStatePayload();
      if (classCloud != null) {
        if (classCloud['subjects'] != null) merged['subjects'] = classCloud['subjects'];
        if (classCloud['chapters'] != null) merged['chapters'] = classCloud['chapters'];
      }
      if (examCloud != null) {
        if (examCloud['subjects'] != null) merged['subjects'] = examCloud['subjects'];
        if (examCloud['chapters'] != null) merged['chapters'] = examCloud['chapters'];
        if (examCloud['bank'] != null) merged['bank'] = examCloud['bank'];
        if (examCloud['customExams'] != null) merged['customExams'] = examCloud['customExams'];
        if (examCloud['savedExams'] != null) merged['savedExams'] = examCloud['savedExams'];
        if (examCloud['savedQuestions'] != null) {
          merged['savedQuestions'] = examCloud['savedQuestions'];
        }
        if (examCloud['savedQuestionsData'] != null) {
          merged['savedQuestionsData'] = examCloud['savedQuestionsData'];
        }
        if (examCloud['history'] != null) merged['history'] = examCloud['history'];
        if (examCloud['deletedIds'] != null) merged['deletedIds'] = examCloud['deletedIds'];
        if (examCloud['deletedBanksMap'] != null) {
          merged['deletedBanksMap'] = examCloud['deletedBanksMap'];
        }
      }

      _applyNormalizedMap(merged);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(FirebaseSyncService.localStateKey, jsonEncode(_buildStatePayload()));

      if (showToast && mounted) {
        _showAppDialog(
          title: 'ক্লাউড সিঙ্ক সফল!',
          message:
              'মোট ${DefaultSyllabusData.toBanglaNum(_chapters.length)}টি অধ্যায় এবং ${DefaultSyllabusData.toBanglaNum(_bank.length)}টি প্রশ্ন সফলভাবে সিঙ্ক হয়েছে।',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDbLoading = false);
      }
    }
  }

  // Helper Dialog
  Future<bool> _showAppDialog({
    required String title,
    required String message,
    bool isConfirm = false,
    bool isDanger = false,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final pal = AppPalette(isDark);
        return Dialog(
          backgroundColor: pal.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: pal.border, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isDanger ? pal.redSoft : pal.primarySoft,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    isDanger ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                    color: isDanger ? pal.red : pal.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: pal.muted, height: 1.45),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    if (isConfirm) ...[
                      Expanded(
                        child: TactileButton(
                          label: 'বাতিল',
                          variant: TactileBtnVariant.ghost,
                          onPressed: () => Navigator.pop(ctx, false),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: TactileButton(
                        label: 'ঠিক আছে',
                        variant: isDanger ? TactileBtnVariant.danger : TactileBtnVariant.primary,
                        onPressed: () => Navigator.pop(ctx, true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return res ?? false;
  }

  Future<String?> _showPromptDialog({
    required String title,
    required String message,
    String initialValue = '',
  }) async {
    final ctrl = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final pal = AppPalette(isDark);
        return Dialog(
          backgroundColor: pal.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: pal.border, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(message,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13.5, color: pal.muted)),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: pal.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TactileButton(
                        label: 'বাতিল',
                        variant: TactileBtnVariant.ghost,
                        onPressed: () => Navigator.pop(ctx, null),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TactileButton(
                        label: 'নিশ্চিত করো',
                        variant: TactileBtnVariant.primary,
                        onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==================== AUTH GATE HANDLER ====================
  Future<void> _handleLoginSubmit() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    setState(() => _loginError = '');

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _loginError = 'অনুগ্রহ করে একটি সঠিক ইমেইল এড্রেস লিখুন।');
      return;
    }
    if (pass.length < 4) {
      setState(() => _loginError = 'অনুগ্রহ করে সঠিক পাসওয়ার্ড লিখুন।');
      return;
    }

    setState(() {
      _isDbLoading = true;
      _dbLoadingText = 'লগইন যাচাই করা হচ্ছে...';
    });

    try {
      final session = await FirebaseSyncService.signInWithEmailPassword(email, pass);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(FirebaseSyncService.localAuthKey, jsonEncode(session));
      setState(() {
        _authUser = session;
        _passCtrl.clear();
      });
      await _pullFromFirebaseCloud(showToast: false);
    } catch (e) {
      final code = e.toString();
      if (code.contains('INVALID') ||
          code.contains('PASSWORD') ||
          code.contains('EMAIL_NOT_FOUND')) {
        setState(() => _loginError = 'ইমেইল অথবা পাসওয়ার্ড সঠিক নয়!');
      } else {
        setState(() => _loginError = 'লগইন করা যায়নি। ইমেইল ও পাসওয়ার্ড চেক করে আবার চেষ্টা করো।');
      }
    } finally {
      if (mounted) setState(() => _isDbLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    final ok = await _showAppDialog(
      title: 'লগআউট করবেন?',
      message: 'আপনি কি নিশ্চিত যে অনুশীলন অ্যাপ থেকে লগআউট করতে চান?',
      isConfirm: true,
      isDanger: true,
    );
    if (!ok) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(FirebaseSyncService.localAuthKey);
    setState(() => _authUser = null);
  }

  // ==================== QUESTION HELPERS ====================
  List<QuestionItem> _getQuestionsForSubject(String subjName) {
    final t = subjName.trim();
    return _bank.where((q) => q.subject.trim() == t).toList();
  }

  List<QuestionItem> _getQuestionsForChapter(String subjName, String chapName) {
    final tSubj = subjName.trim();
    final tChap = FirebaseSyncService.normChap(chapName);
    return _bank
        .where((q) =>
            q.subject.trim() == tSubj && FirebaseSyncService.normChap(q.chapter) == tChap)
        .toList();
  }

  List<String> _getChaptersForSubject(String subjName) {
    final tSubj = subjName.trim();
    final direct = _chapters.where((c) => c.subject.trim() == tSubj).map((c) => c.name).toList();
    final seen = direct.map(FirebaseSyncService.normChap).toSet();
    final out = List<String>.from(direct);
    for (final q in _bank) {
      if (q.subject.trim() == tSubj && q.chapter.trim().isNotEmpty) {
        final nk = FirebaseSyncService.normChap(q.chapter);
        if (!seen.contains(nk)) {
          seen.add(nk);
          out.add(q.chapter.trim());
        }
      }
    }
    return out;
  }

  List<QuestionItem> _getAllSavedQuestionObjects() {
    final map = <String, QuestionItem>{};
    _savedQuestionsData.forEach((k, v) {
      if (_savedQuestions.contains(k) && !_deletedIds.contains(k)) {
        map[k] = v;
      }
    });
    void scanList(List<QuestionItem> list) {
      for (final q in list) {
        if (_savedQuestions.contains(q.id) && !_deletedIds.contains(q.id)) {
          map[q.id] = q;
          _savedQuestionsData[q.id] = q;
        }
      }
    }

    scanList(_bank);
    for (final c in _customExams) {
      scanList(c.questions);
    }
    for (final s in _savedExams) {
      scanList(s.questions);
    }
    for (final h in _history) {
      scanList(h.questions);
    }

    final reversedIds = _savedQuestions.reversed.where((id) => map.containsKey(id)).toList();
    return reversedIds.map((id) => map[id]!).toList();
  }

  List<QuestionItem> _normalizeUploadedQuestions(
      List<dynamic> rawList, String bankName, String subjectName, String chapterName) {
    final out = <QuestionItem>[];
    for (var i = 0; i < rawList.length; i++) {
      if (rawList[i] is! Map) continue;
      final q = QuestionItem.fromMap(
        rawList[i] as Map,
        index: i,
        defaultBank: bankName,
        defaultSubj: subjectName,
        defaultChap: chapterName,
      );
      if ((q.question.isNotEmpty || q.svg.isNotEmpty) && q.options.length >= 2) {
        out.add(q);
      }
    }
    return out;
  }

  // ==================== STEP 3 PRACTICE SETUP LOGIC ====================
  String _makeStep3BankKey(String chapName, String bankName) =>
      '${FirebaseSyncService.normChap(chapName)}|||${bankName.trim().isEmpty ? "প্রশ্নব্যাংক" : bankName.trim()}';

  List<Map<String, dynamic>> _getAvailableStep3Banks() {
    final subjQs = _getQuestionsForSubject(_step3Subject);
    final selNorms = _step3SelectedChapters.map(FirebaseSyncService.normChap).toSet();
    final relevant = selNorms.isNotEmpty
        ? subjQs.where((q) => selNorms.contains(FirebaseSyncService.normChap(q.chapter))).toList()
        : subjQs;
    final map = <String, Map<String, dynamic>>{};
    for (final q in relevant) {
      final chap = q.chapter.trim().isEmpty ? 'সাধারণ' : q.chapter.trim();
      final bName = q.sourcePdf.trim().isEmpty ? 'প্রশ্নব্যাংক' : q.sourcePdf.trim();
      final key = _makeStep3BankKey(chap, bName);
      map.putIfAbsent(
          key, () => {'key': key, 'bankName': bName, 'chapter': chap, 'count': 0});
      map[key]!['count'] = (map[key]!['count'] as int) + 1;
    }
    return map.values.toList();
  }

  List<QuestionItem> _getFilteredStep3Questions() {
    if (_step3SourceMode == 'saved') {
      if (_step3SelectedChapters.isEmpty) return [];
      var pool = _getAllSavedQuestionObjects();
      if (_step3SelectedSavedSubjects.isNotEmpty) {
        pool = pool
            .where((q) => _step3SelectedSavedSubjects
                .contains(q.subject.trim().isEmpty ? 'সাধারণ' : q.subject.trim()))
            .toList();
      }
      final selNorms = _step3SelectedChapters.map(FirebaseSyncService.normChap).toSet();
      return pool
          .where((q) => selNorms.contains(FirebaseSyncService.normChap(
              q.chapter.trim().isEmpty ? 'সাধারণ অধ্যায়' : q.chapter.trim())))
          .toList();
    }
    if (_step3SelectedChapters.isEmpty) return [];
    final selNorms = _step3SelectedChapters.map(FirebaseSyncService.normChap).toSet();
    var pool = _getQuestionsForSubject(_step3Subject)
        .where((q) => selNorms.contains(FirebaseSyncService.normChap(q.chapter)))
        .toList();
    if (_step3SelectedBanks.isNotEmpty) {
      pool = pool
          .where((q) => _step3SelectedBanks.contains(_makeStep3BankKey(q.chapter, q.sourcePdf)))
          .toList();
    } else if (_getAvailableStep3Banks().isNotEmpty) {
      return [];
    }
    return pool;
  }

  void _openPracticeChapterSetup(String subjName) {
    final qs = _getQuestionsForSubject(subjName);
    setState(() {
      _step3SourceMode = 'bank';
      _step3Subject = subjName;
      _step3SelectedChapters = {};
      _step3SelectedBanks = {};
      _step3QCount = qs.isNotEmpty ? (qs.length < 15 ? qs.length : 15) : 10;
      _step3Time = _step3QCount;
      _step3NegMarking = false;
      _step3OnlyPrevWrong = false;
      _activeScreen = ActiveScreen.confirmSetup;
    });
  }

  void _openSavedQuestionsExamSetup() {
    final allSaved = _getAllSavedQuestionObjects();
    if (allSaved.isEmpty) {
      _showAppDialog(
        title: 'সেইভ করা প্রশ্ন নেই',
        message: 'প্রথমে পরীক্ষার ফলাফল পেইজ থেকে কিছু প্রশ্ন বুকমার্ক/সেইভ করো।',
      );
      return;
    }
    final allSubjs = allSaved
        .map((q) => q.subject.trim().isEmpty ? 'সাধারণ' : q.subject.trim())
        .toSet();
    setState(() {
      _step3SourceMode = 'saved';
      _step3SelectedSavedSubjects = _savedFilterSubject.isNotEmpty &&
              allSubjs.contains(_savedFilterSubject)
          ? {_savedFilterSubject}
          : allSubjs;
      _step3SelectedChapters =
          _savedFilterChapter.isNotEmpty ? {_savedFilterChapter} : {};
      _step3QCount = allSaved.length < 15 ? allSaved.length : 15;
      _step3Time = _step3QCount;
      _step3NegMarking = false;
      _activeScreen = ActiveScreen.confirmSetup;
    });
  }

  // ==================== START & SUBMIT LIVE EXAM ====================
  void _startLiveExam({
    required List<QuestionItem> questions,
    required int minutes,
    required bool negMarking,
    required String title,
  }) {
    final shuffled = List<QuestionItem>.from(questions)..shuffle();
    _questionItemKeys.clear();
    for (var i = 0; i < shuffled.length; i++) {
      _questionItemKeys[i] = GlobalKey();
    }
    _examTimer?.cancel();
    setState(() {
      _liveExamQuestions = shuffled;
      _liveExamAnswers = {};
      _liveExamMinutes = minutes < 1 ? 1 : minutes;
      _liveExamNeg = negMarking;
      _liveExamTitle = title;
      _secondsRemaining = _liveExamMinutes * 60;
      _examStartedAt = DateTime.now();
      _activeScreen = ActiveScreen.liveExam;
    });

    _examTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _activeScreen != ActiveScreen.liveExam) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        timer.cancel();
        _submitLiveExam();
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  void _submitLiveExam() {
    _examTimer?.cancel();
    var correct = 0;
    var wrong = 0;
    var skip = 0;
    var gradable = 0;
    final wrongIds = <String>[];

    for (final q in _liveExamQuestions) {
      final ans = QuestionItem.resolveAnswerLabel(q.answer, q.options);
      q.answer = ans;
      if (ans == null) continue;
      gradable++;
      final chosen = _liveExamAnswers[q.id];
      if (chosen == null) {
        skip++;
      } else if (chosen == ans) {
        correct++;
      } else {
        wrong++;
        wrongIds.add(q.id);
      }
    }

    final rawScore = _liveExamNeg ? (correct - wrong * 0.25).clamp(0.0, double.infinity) : correct.toDouble();
    final scoreFormatted = rawScore == rawScore.roundToDouble()
        ? rawScore.toInt().toString()
        : rawScore.toStringAsFixed(2);
    final accuracy = gradable > 0 ? ((correct / gradable) * 100).round() : 0;
    final elapsedMin = _examStartedAt != null
        ? DateTime.now().difference(_examStartedAt!).inMinutes.clamp(1, 999)
        : 1;
    final nowStr =
        '${DefaultSyllabusData.toBanglaNum(DateTime.now().day)}/${DefaultSyllabusData.toBanglaNum(DateTime.now().month)}/${DefaultSyllabusData.toBanglaNum(DateTime.now().year)}';

    final resItem = ExamResultItem(
      id: 'res-${DateTime.now().millisecondsSinceEpoch}',
      title: _liveExamTitle,
      date: nowStr,
      correct: correct,
      wrong: wrong,
      skip: skip,
      gradable: gradable,
      total: _liveExamQuestions.length,
      accuracy: accuracy,
      elapsedMin: elapsedMin,
      scoreFormatted: scoreFormatted,
      negMarking: _liveExamNeg,
      wrongIds: wrongIds,
      questions: _liveExamQuestions,
      answers: Map<String, String>.from(_liveExamAnswers),
    );

    setState(() {
      _currentResult = resItem;
      _history.add(resItem);
      _resultFilter = 'all';
      _activeScreen = ActiveScreen.examResult;
    });
    _saveStateAndSync();
  }

  // ==================== BUILD ROOT ====================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pal = AppPalette(isDark);

    return Stack(
      children: [
        if (_authUser == null)
          _buildLoginGate(pal, isDark)
        else
          _buildAuthenticatedApp(pal, isDark),
        if (_isDbLoading) _buildCloudLoadingOverlay(pal),
      ],
    );
  }

  // Cloud Database Loading Overlay (matching .db-loading-overlay)
  Widget _buildCloudLoadingOverlay(AppPalette pal) {
    return Material(
      color: Colors.black.withOpacity(0.55),
      child: Center(
        child: Container(
          width: 340,
          margin: const EdgeInsets.all(20),
          child: TactileCard(
            radius: 26,
            bottomDepth: 5,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: pal.border, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: pal.primary.withOpacity(0.28),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: pal.primary,
                        alignment: Alignment.center,
                        child: const Text(
                          'অনু',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: 38,
                  height: 38,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.5,
                    color: pal.primary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'ক্লাউড ডাটাবেইজ লোড হচ্ছে...',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  _dbLoadingText,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: pal.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Mandatory Login Gate (matching .auth-gate-overlay)
  Widget _buildLoginGate(AppPalette pal, bool isDark) {
    return Scaffold(
      backgroundColor: pal.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 12,
              right: 16,
              child: TactileCard(
                padding: const EdgeInsets.all(9),
                radius: 12,
                bottomDepth: 3,
                onTap: widget.onToggleTheme,
                child: Icon(
                  isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                  size: 20,
                  color: pal.text,
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: TactileCard(
                    radius: 28,
                    bottomDepth: 6,
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: pal.primary.withOpacity(0.3),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              'assets/images/app_icon.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: pal.primary,
                                alignment: Alignment.center,
                                child: const Text(
                                  'অনুশীলন',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'অনুশীলন',
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
                          decoration: BoxDecoration(
                            color: pal.primarySoft,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: pal.primarySoft3d),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_outline_rounded, size: 15, color: pal.primary),
                              const SizedBox(width: 6),
                              Text(
                                'প্রাইভেট স্টাডি পোর্টাল • লগইন আবশ্যক',
                                style: TextStyle(
                                  color: pal.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        if (_loginError.isNotEmpty)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                            decoration: BoxDecoration(
                              color: pal.redSoft,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: pal.redSoft3d, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: pal.red, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _loginError,
                                    style: TextStyle(
                                      color: pal.red,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'ইমেইল এড্রেস',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: pal.text,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'yourname@example.com',
                            prefixIcon: Icon(Icons.mail_outline_rounded, color: pal.muted),
                            filled: true,
                            fillColor: pal.bg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(color: pal.border),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'পাসওয়ার্ড',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: pal.text,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passCtrl,
                          obscureText: _obscurePassword,
                          onSubmitted: (_) => _handleLoginSubmit(),
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            prefixIcon: Icon(Icons.lock_outline_rounded, color: pal.muted),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscurePassword = !_obscurePassword),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: pal.muted,
                              ),
                            ),
                            filled: true,
                            fillColor: pal.bg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(color: pal.border),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TactileButton(
                          label: 'লগইন করে প্রবেশ করো',
                          icon: const Icon(Icons.login_rounded),
                          isBlock: true,
                          onPressed: _handleLoginSubmit,
                        ),
                      ],
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

  // ==================== AUTHENTICATED SHELL ====================
  Widget _buildAuthenticatedApp(AppPalette pal, bool isDark) {
    if (_activeScreen == ActiveScreen.confirmSetup) {
      return _buildConfirmSetupScreen(pal);
    }
    if (_activeScreen == ActiveScreen.liveExam) {
      return _buildLiveExamScreen(pal);
    }
    if (_activeScreen == ActiveScreen.examResult && _currentResult != null) {
      return _buildExamResultScreen(pal, _currentResult!);
    }

    final isDesktop = MediaQuery.of(context).size.width >= 860;

    return Scaffold(
      backgroundColor: pal.bg,
      appBar: isDesktop
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(64),
              child: Container(
                decoration: BoxDecoration(
                  color: pal.card,
                  border: Border(bottom: BorderSide(color: pal.border, width: 1.5)),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _activeTab = MainTab.home),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: pal.border, width: 1.5),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.asset(
                                    'assets/images/app_icon.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: pal.primary,
                                      alignment: Alignment.center,
                                      child: const Text('অনু',
                                          style: TextStyle(
                                              color: Colors.white, fontWeight: FontWeight.w900)),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'অনুশীলন',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        TactileCard(
                          padding: const EdgeInsets.all(8),
                          radius: 12,
                          bottomDepth: 3,
                          onTap: () => _pullFromFirebaseCloud(showToast: true),
                          child: Icon(Icons.cloud_sync_outlined, size: 20, color: pal.primary),
                        ),
                        const SizedBox(width: 8),
                        TactileCard(
                          padding: const EdgeInsets.all(8),
                          radius: 12,
                          bottomDepth: 3,
                          onTap: _handleLogout,
                          child: Icon(Icons.logout_rounded, size: 20, color: pal.text),
                        ),
                        const SizedBox(width: 8),
                        TactileCard(
                          padding: const EdgeInsets.all(8),
                          radius: 12,
                          bottomDepth: 3,
                          onTap: widget.onToggleTheme,
                          child: Icon(
                            isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                            size: 20,
                            color: pal.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDesktop) _buildDesktopSidebar(pal, isDark),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 26 : 14,
                isDesktop ? 22 : 16,
                isDesktop ? 26 : 14,
                36,
              ),
              child: _buildCurrentTabBody(pal),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isDesktop ? null : _buildMobileBottomNav(pal),
    );
  }

  Widget _buildDesktopSidebar(AppPalette pal, bool isDark) {
    Widget navBtn(MainTab tab, IconData icon, String title) {
      final active = _activeTab == tab;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TactileCard(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          radius: 15,
          bottomDepth: 3.5,
          bgColor: active ? pal.primary : pal.cardAlt,
          borderColor: active ? pal.primary3d : pal.border,
          bottomBorderColor: active ? pal.primary3d : pal.border3d,
          onTap: () => setState(() => _activeTab = tab),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: active ? Colors.white.withOpacity(0.22) : pal.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: active ? pal.onPrimary : pal.primary),
              ),
              const SizedBox(width: 11),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: active ? pal.onPrimary : pal.text,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: 244,
      height: MediaQuery.of(context).size.height,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pal.card,
        border: Border(right: BorderSide(color: pal.border, width: 1.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _activeTab = MainTab.home),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset('assets/images/app_icon.png', width: 42, height: 42),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Text(
                      'অনুশীলন',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(color: pal.border),
          const SizedBox(height: 8),
          navBtn(MainTab.home, Icons.home_outlined, 'Home'),
          navBtn(MainTab.exam, Icons.assignment_turned_in_outlined, 'Exam'),
          navBtn(MainTab.saved, Icons.bookmark_border_rounded, 'Saved'),
          navBtn(MainTab.settings, Icons.settings_outlined, 'Settings'),
          const Spacer(),
          Divider(color: pal.border),
          if (_authUser != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                (_authUser!['email'] ?? '').toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: pal.muted),
              ),
            ),
          const SizedBox(height: 6),
          TactileButton(
            label: isDark ? 'লাইট মোড' : 'ডার্ক মোড',
            icon: Icon(isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round),
            variant: TactileBtnVariant.ghost,
            isBlock: true,
            onPressed: widget.onToggleTheme,
          ),
          const SizedBox(height: 8),
          TactileButton(
            label: 'লগআউট',
            icon: const Icon(Icons.logout_rounded),
            variant: TactileBtnVariant.danger,
            isBlock: true,
            onPressed: _handleLogout,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBottomNav(AppPalette pal) {
    Widget navItem(MainTab tab, IconData icon, String label) {
      final active = _activeTab == tab;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _activeTab = tab),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 54,
                height: 31,
                decoration: BoxDecoration(
                  color: active ? pal.primarySoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: active ? pal.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: active ? pal.onPrimary : pal.muted,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w700,
                  color: active ? pal.primary : pal.muted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: pal.card,
        border: Border(top: BorderSide(color: pal.border, width: 1.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            navItem(MainTab.home, Icons.home_outlined, 'Home'),
            navItem(MainTab.exam, Icons.assignment_turned_in_outlined, 'Exam'),
            navItem(MainTab.saved, Icons.bookmark_border_rounded, 'Saved'),
            navItem(MainTab.settings, Icons.settings_outlined, 'Settings'),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTabBody(AppPalette pal) {
    switch (_activeTab) {
      case MainTab.home:
        return _buildHomeView(pal);
      case MainTab.exam:
        return _buildExamHubView(pal);
      case MainTab.saved:
        return _buildSavedView(pal);
      case MainTab.settings:
        return _buildSettingsView(pal);
    }
  }

  // ==================== 1. HOME VIEW ====================
  Widget _buildHomeView(AppPalette pal) {
    final totalExams = _history.length;
    final avgAcc = totalExams > 0
        ? (_history.fold<int>(0, (a, b) => a + b.accuracy) / totalExams).round()
        : 0;
    final totalSaved = _savedExams.length + _savedQuestions.length;

    final targetSubj = _selectedProgressSubj.isNotEmpty
        ? _selectedProgressSubj
        : (_subjects.isNotEmpty ? _subjects.first.name : 'পদার্থ বিজ্ঞান ১ম পত্র');
    final chapsForTarget = _chapters.where((c) => c.subject == targetSubj).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero Banner
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF033A20),
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.only(bottom: 5),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF07884B), Color(0xFF04522E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 14,
              runSpacing: 14,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset('assets/images/app_icon.png', width: 48, height: 48),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'অনুশীলন',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'MCQ Practice & Exam Room',
                          style: TextStyle(color: Color(0xFFD8F3E5), fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    TactileButton(
                      label: 'প্র্যাকটিস পরীক্ষা →',
                      variant: TactileBtnVariant.secondary,
                      onPressed: () => setState(() {
                        _examHubMode = 'practice';
                        _activeTab = MainTab.exam;
                      }),
                    ),
                    TactileButton(
                      label: 'পরীক্ষা দাও',
                      variant: TactileBtnVariant.primary,
                      onPressed: () => setState(() {
                        _examHubMode = 'exam';
                        _activeTab = MainTab.exam;
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 4 Stat Cards
        LayoutBuilder(
          builder: (ctx, constraints) {
            final isWide = constraints.maxWidth >= 640;
            final cards = [
              _buildStatCard(
                pal,
                value: DefaultSyllabusData.toBanglaNum(totalExams),
                label: 'দেওয়া পরীক্ষা',
                onTap: () => setState(() => _activeTab = MainTab.exam),
              ),
              _buildStatCard(
                pal,
                value: '${DefaultSyllabusData.toBanglaNum(avgAcc)}%',
                label: 'গড় একুরেসি',
                onTap: () => setState(() => _activeTab = MainTab.exam),
              ),
              _buildStatCard(
                pal,
                value: DefaultSyllabusData.toBanglaNum(_bank.length),
                label: 'প্রশ্নব্যাংকের প্রশ্ন',
                onTap: () => setState(() {
                  _examHubMode = 'practice';
                  _activeTab = MainTab.exam;
                }),
              ),
              _buildStatCard(
                pal,
                value: DefaultSyllabusData.toBanglaNum(totalSaved),
                label: 'সেইভড প্রশ্ন ও পরীক্ষা',
                onTap: () => setState(() => _activeTab = MainTab.saved),
              ),
            ];
            return GridView.count(
              crossAxisCount: isWide ? 4 : 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: isWide ? 2.1 : 1.9,
              children: cards,
            );
          },
        ),
        const SizedBox(height: 18),

        // Detailed Subject & Chapter Progress Card
        TactileCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bar_chart_rounded, color: pal.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'পড়াশোনার অগ্রগতি (বিষয় ও অধ্যায়ভিত্তিক চার্ট)',
                        style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  DropdownButtonHideUnderline(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: pal.bg,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: pal.border, width: 1.5),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedProgressSubj.isEmpty ? '' : _selectedProgressSubj,
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('সকল বিষয় (সারসংক্ষেপ)',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          ),
                          ..._subjects.map(
                            (s) => DropdownMenuItem(
                              value: s.name,
                              child: Text(s.name,
                                  style: const TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _selectedProgressSubj = v ?? ''),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: pal.cardAlt,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: pal.border, width: 1.5),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 68,
                      height: 68,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: (avgAcc / 100).clamp(0.0, 1.0),
                            strokeWidth: 7,
                            backgroundColor: pal.border,
                            color: pal.blue,
                          ),
                          Center(
                            child: Text(
                              '${DefaultSyllabusData.toBanglaNum(avgAcc)}%',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${DefaultSyllabusData.toBanglaNum(avgAcc)}% গড় একুরেসি',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'মোট দেওয়া পরীক্ষা: ${DefaultSyllabusData.toBanglaNum(totalExams)}টি',
                            style: TextStyle(fontSize: 12.5, color: pal.muted),
                          ),
                          Text(
                            'প্রশ্নব্যাংক: ${DefaultSyllabusData.toBanglaNum(_bank.length)}টি প্রশ্ন',
                            style: TextStyle(
                                fontSize: 12.5, color: pal.blue, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Subject-wise accuracy bars
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: pal.cardAlt,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: pal.border, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'বিষয়ভিত্তিক পরীক্ষার একুরেসি ও প্রশ্নব্যাংক চার্ট',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    ...(_selectedProgressSubj.isNotEmpty
                            ? _subjects.where((s) => s.name == _selectedProgressSubj)
                            : _subjects.take(6))
                        .map((subj) {
                      final bankCount = _bank.where((q) => q.subject == subj.name).length;
                      final subjExams = _history
                          .where((h) =>
                              h.title.contains(subj.name) ||
                              h.questions.any((q) => q.subject == subj.name))
                          .toList();
                      final exAcc = subjExams.isNotEmpty
                          ? (subjExams.fold<int>(0, (a, b) => a + b.accuracy) / subjExams.length)
                              .round()
                          : 0;
                      return InkWell(
                        onTap: () => setState(() => _selectedProgressSubj = subj.name),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(subj.name,
                                        style: const TextStyle(
                                            fontSize: 13, fontWeight: FontWeight.w800)),
                                  ),
                                  Text(
                                    'প্রশ্নব্যাংক: ${DefaultSyllabusData.toBanglaNum(bankCount)}টি • পরীক্ষা: ${DefaultSyllabusData.toBanglaNum(exAcc)}%',
                                    style: TextStyle(fontSize: 11.5, color: pal.muted),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value: (exAcc / 100).clamp(0.0, 1.0),
                                  minHeight: 7,
                                  backgroundColor: pal.border,
                                  color: pal.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'অধ্যায়ভিত্তিক অগ্রগতি — $targetSubj',
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                  TactileButton(
                    label: 'প্র্যাকটিস করো ›',
                    variant: TactileBtnVariant.secondary,
                    isSmall: true,
                    onPressed: () => _openPracticeChapterSetup(targetSubj),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...chapsForTarget.take(8).map((ch) {
                final chapQs = _getQuestionsForChapter(targetSubj, ch.name).length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => _openPracticeChapterSetup(targetSubj),
                    child: Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: pal.cardAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: pal.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              ch.name,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                            ),
                          ),
                          Text(
                            'প্রশ্নব্যাংক: ${DefaultSyllabusData.toBanglaNum(chapQs)}টি',
                            style: TextStyle(
                                fontSize: 12, color: pal.primary, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Recent Exam Results Card
        TactileCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'সাম্প্রতিক পরীক্ষার ফলাফল',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  TactileButton(
                    label: 'Exam-এ যাও',
                    variant: TactileBtnVariant.ghost,
                    isSmall: true,
                    onPressed: () => setState(() => _activeTab = MainTab.exam),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_history.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: Text(
                      'এখনো কোনো পরীক্ষা দেওয়া হয়নি',
                      style: TextStyle(color: pal.muted, fontWeight: FontWeight.w700),
                    ),
                  ),
                )
              else
                ..._history.reversed.take(5).map((h) => Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: pal.border)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(h.title,
                                    style: const TextStyle(
                                        fontSize: 14, fontWeight: FontWeight.w800)),
                                Text(
                                  '${h.date} • একুরেসি ${DefaultSyllabusData.toBanglaNum(h.accuracy)}%',
                                  style: TextStyle(fontSize: 12, color: pal.muted),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${DefaultSyllabusData.toBanglaNum(h.scoreFormatted)}/${DefaultSyllabusData.toBanglaNum(h.total)}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: pal.primary,
                            ),
                          ),
                        ],
                      ),
                    )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    AppPalette pal, {
    required String value,
    required String label,
    required VoidCallback onTap,
  }) {
    return TactileCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: pal.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: pal.muted),
          ),
        ],
      ),
    );
  }

  // ==================== 2. EXAM HUB VIEW ====================
  Future<void> _pickDirectJsonFiles() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: true,
        withData: true,
      );
      if (res == null || res.files.isEmpty) return;

      if (res.files.length == 1) {
        final f = res.files.first;
        final content = utf8.decode(f.bytes ?? []);
        setState(() {
          _directJsonCtrl.text = content;
          if (_directTitleCtrl.text.trim().isEmpty) {
            _directTitleCtrl.text = f.name.replaceAll(RegExp(r'\.json$', caseSensitive: false), '');
          }
        });
      } else {
        final combined = <dynamic>[];
        final names = <String>[];
        for (final f in res.files) {
          if (f.bytes == null) continue;
          final txt = utf8.decode(f.bytes!);
          final parsed = jsonDecode(txt);
          if (parsed is List) {
            final bName = f.name.replaceAll(RegExp(r'\.json$', caseSensitive: false), '');
            names.add(bName);
            combined.addAll(parsed);
          }
        }
        setState(() {
          _directJsonCtrl.text = const JsonEncoder.withIndent('  ').convert(combined);
          if (_directTitleCtrl.text.trim().isEmpty) {
            _directTitleCtrl.text = names.join(' + ');
          }
        });
      }
    } catch (e) {
      _showAppDialog(
        title: 'JSON ফাইল রিড ত্রুটি',
        message: 'নির্বাচিত ফাইলে সঠিক JSON Array পাওয়া যায়নি।',
        isDanger: true,
      );
    }
  }

  void _startDirectJsonExam() {
    final title = _directTitleCtrl.text.trim();
    if (title.isEmpty) {
      _showAppDialog(
        title: 'পরীক্ষার নাম প্রয়োজন',
        message: 'অনুগ্রহ করে পরীক্ষার নাম লেখো।',
        isDanger: true,
      );
      return;
    }
    final rawJson = _directJsonCtrl.text.trim();
    if (rawJson.isEmpty) {
      _showAppDialog(
        title: 'JSON কোড প্রয়োজন',
        message: 'অনুগ্রহ করে JSON ফাইল আপলোড করো অথবা JSON কোড পেস্ট করো।',
        isDanger: true,
      );
      return;
    }
    try {
      final parsed = jsonDecode(rawJson);
      if (parsed is! List) {
        throw Exception('JSON অবশ্যই প্রশ্নের একটি Array হতে হবে।');
      }
      final qs = _normalizeUploadedQuestions(parsed, title, title, 'JSON Exam');
      if (qs.isEmpty) {
        throw Exception('সঠিক ফরম্যাটের কোনো প্রশ্ন পাওয়া যায়নি।');
      }
      final mins = (int.tryParse(_directMinutesCtrl.text.trim()) ?? qs.length).clamp(1, 300);
      final cex = CustomExamItem(
        id: 'cex-${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        createdAt:
            '${DefaultSyllabusData.toBanglaNum(DateTime.now().day)}/${DefaultSyllabusData.toBanglaNum(DateTime.now().month)}/${DefaultSyllabusData.toBanglaNum(DateTime.now().year)}',
        minutes: mins,
        negMarking: _directNegMarking,
        questions: qs,
      );
      setState(() {
        _customExams.add(cex);
        _directTitleCtrl.clear();
        _directJsonCtrl.clear();
      });
      _saveStateAndSync();
      _startLiveExam(
        questions: qs,
        minutes: mins,
        negMarking: _directNegMarking,
        title: title,
      );
    } catch (e) {
      _showAppDialog(
        title: 'পরীক্ষা শুরু করা যায়নি',
        message: e.toString(),
        isDanger: true,
      );
    }
  }

  Widget _buildExamHubView(AppPalette pal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Mode Tabs (পরীক্ষা / প্র্যাকটিস)
        TactileCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildExamTopTabBtn(pal, 'exam', Icons.description_outlined, 'পরীক্ষা'),
              const SizedBox(width: 24),
              _buildExamTopTabBtn(pal, 'practice', Icons.fact_check_outlined, 'প্র্যাকটিস'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_examHubMode == 'exam') ...[
          TactileCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'নতুন পরীক্ষা শুরু করো (JSON)',
                      style: TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800),
                    ),
                    TactileButton(
                      label: 'Template কপি',
                      variant: TactileBtnVariant.ghost,
                      isSmall: true,
                      onPressed: () {
                        Clipboard.setData(
                            const ClipboardData(text: DefaultSyllabusData.sampleTemplateJson));
                        _showAppDialog(
                          title: 'Template কপি হয়েছে!',
                          message: 'স্যাম্পল JSON Template ক্লিপবোর্ডে কপি করা হয়েছে।',
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('পরীক্ষার নাম *',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                TextField(
                  controller: _directTitleCtrl,
                  decoration: InputDecoration(
                    hintText: 'যেমন: ভেক্টর অধ্যায় ফাইনাল মডেল টেস্ট',
                    filled: true,
                    fillColor: pal.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('সময় (মিনিট)',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 5),
                          TextField(
                            controller: _directMinutesCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: pal.bg,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('নেগেটিভ মার্কিং',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: _directNegMarking ? pal.primarySoft : pal.bg,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: _directNegMarking ? pal.primary : pal.border,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _directNegMarking ? 'চালু (-০.২৫)' : 'বন্ধ (০.০০)',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: _directNegMarking ? pal.primary : pal.text,
                                  ),
                                ),
                                Switch(
                                  value: _directNegMarking,
                                  activeColor: pal.primary,
                                  onChanged: (v) => setState(() => _directNegMarking = v),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TactileButton(
                  label: 'এক বা একাধিক JSON ফাইল আপলোড করো',
                  icon: const Icon(Icons.upload_file_rounded),
                  variant: TactileBtnVariant.secondary,
                  isBlock: true,
                  onPressed: _pickDirectJsonFiles,
                ),
                const SizedBox(height: 12),
                const Text('অথবা JSON কোড পেস্ট করো *',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                TextField(
                  controller: _directJsonCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: '[{"question":"প্রশ্ন?","options":[{"label":"ক","text":"..."}],"answer":"ক"}]',
                    filled: true,
                    fillColor: pal.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  ),
                ),
                const SizedBox(height: 14),
                TactileButton(
                  label: 'পরীক্ষা শুরু করো',
                  icon: const Icon(Icons.play_arrow_rounded),
                  variant: TactileBtnVariant.primary,
                  isBlock: true,
                  onPressed: _startDirectJsonExam,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TactileCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'আগের পরীক্ষাসমূহ (${DefaultSyllabusData.toBanglaNum(_customExams.length)}টি)',
                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
                    ),
                    if (_customExams.isNotEmpty)
                      TactileButton(
                        label: 'সব ডিলিট',
                        variant: TactileBtnVariant.danger,
                        isSmall: true,
                        onPressed: () async {
                          final ok = await _showAppDialog(
                            title: 'সব পেস্ট করা পরীক্ষা ডিলিট করবেন?',
                            message: 'আপনি কি নিশ্চিত যে সব পেস্ট করা পরীক্ষা মুছে ফেলতে চান?',
                            isConfirm: true,
                            isDanger: true,
                          );
                          if (ok) {
                            setState(() {
                              for (final c in _customExams) {
                                _deletedIds.add(c.id);
                              }
                              _customExams.clear();
                            });
                            _saveStateAndSync();
                          }
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_customExams.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'এখনো কোনো JSON পরীক্ষা পেস্ট বা আপলোড করা হয়নি।',
                        style: TextStyle(color: pal.muted),
                      ),
                    ),
                  )
                else
                  ..._customExams.reversed.map((cex) => Container(
                        margin: const EdgeInsets.only(bottom: 9),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: pal.cardAlt,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: pal.border, width: 1.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(cex.title,
                                      style: const TextStyle(
                                          fontSize: 14.5, fontWeight: FontWeight.w800)),
                                  Text(
                                    '${DefaultSyllabusData.toBanglaNum(cex.questions.length)}টি প্রশ্ন • ${DefaultSyllabusData.toBanglaNum(cex.minutes)} মিনিট • ${cex.createdAt}',
                                    style: TextStyle(fontSize: 12, color: pal.muted),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                TactileButton(
                                  label: 'পরীক্ষা দাও',
                                  variant: TactileBtnVariant.primary,
                                  isSmall: true,
                                  onPressed: () => _startLiveExam(
                                    questions: cex.questions,
                                    minutes: cex.minutes,
                                    negMarking: cex.negMarking,
                                    title: cex.title,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                TactileButton(
                                  label: 'ডিলিট',
                                  variant: TactileBtnVariant.danger,
                                  isSmall: true,
                                  onPressed: () {
                                    setState(() {
                                      _deletedIds.add(cex.id);
                                      _customExams.removeWhere((x) => x.id == cex.id);
                                    });
                                    _saveStateAndSync();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      )),
              ],
            ),
          ),
        ] else ...[
          Text(
            'বিষয় নির্বাচন করো (${DefaultSyllabusData.toBanglaNum(_subjects.length)}টি)',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final cols = constraints.maxWidth >= 900
                  ? 3
                  : (constraints.maxWidth >= 560 ? 2 : 1);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _subjects.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.15,
                ),
                itemBuilder: (ctx, idx) {
                  final subj = _subjects[idx];
                  final qsCount = _getQuestionsForSubject(subj.name).length;
                  final chapsCount = _getChaptersForSubject(subj.name).length;
                  return TactileCard(
                    padding: EdgeInsets.zero,
                    onTap: () => _openPracticeChapterSetup(subj.name),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SubjectArtBanner(
                            subject: subj,
                            topBadge: 'প্র্যাকটিস',
                            rightBadge: '${DefaultSyllabusData.toBanglaNum(chapsCount)}টি অধ্যায়',
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(13),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    subj.subtitle.isNotEmpty
                                        ? subj.subtitle
                                        : 'HSC Academic & Admission',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        color: pal.muted,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    subj.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.w800),
                                  ),
                                  const Spacer(),
                                  Divider(color: pal.border, height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${DefaultSyllabusData.toBanglaNum(qsCount)}টি প্রশ্ন',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: pal.primary),
                                      ),
                                      Text(
                                        'অধ্যায় ›',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: pal.muted),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildExamTopTabBtn(AppPalette pal, String mode, IconData icon, String title) {
    final active = _examHubMode == mode;
    return InkWell(
      onTap: () => setState(() => _examHubMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? pal.primary : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: active ? pal.primary : pal.muted),
            const SizedBox(width: 7),
            Text(
              title,
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: active ? pal.primary : pal.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 3. CONFIRM SETUP SCREEN (Step 3/3) ====================
  Widget _buildConfirmSetupScreen(AppPalette pal) {
    final isSavedMode = _step3SourceMode == 'saved';
    final allChaps = isSavedMode
        ? _getAllSavedQuestionObjects()
            .map((q) => q.chapter.trim().isEmpty ? 'সাধারণ অধ্যায়' : q.chapter.trim())
            .toSet()
            .toList()
        : _getChaptersForSubject(_step3Subject);
    final availBanks = isSavedMode ? <Map<String, dynamic>>[] : _getAvailableStep3Banks();
    final matchingPool = _getFilteredStep3Questions();
    final wrongIds = _history.expand((h) => h.wrongIds).toSet();
    final wrongPool = matchingPool.where((q) => wrongIds.contains(q.id)).toList();

    return Scaffold(
      backgroundColor: pal.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              TactileCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => setState(() => _activeScreen = ActiveScreen.mainTabs),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    ),
                    Expanded(
                      child: Text(
                        isSavedMode ? 'সেইভ করা প্রশ্নের পরীক্ষা সেটআপ' : _step3Subject,
                        style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(
                        color: pal.primarySoft,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        isSavedMode ? 'সেইভ করা প্রশ্ন' : 'প্র্যাকটিস',
                        style: TextStyle(
                            color: pal.primary, fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 1. Chapter Selection Card
              TactileCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '১. অধ্যায় নির্বাচন করো',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                        TactileButton(
                          label: _step3SelectedChapters.length == allChaps.length &&
                                  allChaps.isNotEmpty
                              ? 'সব আনসিলেক্ট'
                              : 'সব অধ্যায় সিলেক্ট',
                          variant: TactileBtnVariant.ghost,
                          isSmall: true,
                          onPressed: () {
                            setState(() {
                              if (_step3SelectedChapters.length == allChaps.length) {
                                _step3SelectedChapters.clear();
                                _step3SelectedBanks.clear();
                              } else {
                                _step3SelectedChapters = allChaps.toSet();
                                if (!isSavedMode) {
                                  for (final q in _getQuestionsForSubject(_step3Subject)) {
                                    _step3SelectedBanks
                                        .add(_makeStep3BankKey(q.chapter, q.sourcePdf));
                                  }
                                }
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'নির্বাচিত প্রশ্ন: ${DefaultSyllabusData.toBanglaNum(matchingPool.length)}টি',
                      style: TextStyle(
                          fontSize: 12.5, color: pal.primary, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    ...allChaps.map((chName) {
                      final isSel = _step3SelectedChapters.contains(chName);
                      final cnt = isSavedMode
                          ? _getAllSavedQuestionObjects()
                              .where((q) =>
                                  FirebaseSyncService.normChap(q.chapter) ==
                                  FirebaseSyncService.normChap(chName))
                              .length
                          : _getQuestionsForChapter(_step3Subject, chName).length;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              if (isSel) {
                                _step3SelectedChapters.remove(chName);
                                final norm = FirebaseSyncService.normChap(chName);
                                _step3SelectedBanks
                                    .removeWhere((k) => k.startsWith('$norm|||'));
                              } else {
                                _step3SelectedChapters.add(chName);
                                for (final q in _getQuestionsForChapter(_step3Subject, chName)) {
                                  _step3SelectedBanks
                                      .add(_makeStep3BankKey(q.chapter, q.sourcePdf));
                                }
                              }
                              final nextPool = _getFilteredStep3Questions();
                              if (nextPool.isNotEmpty) {
                                _step3QCount = _step3QCount.clamp(1, nextPool.length);
                                _step3Time = _step3QCount;
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSel ? pal.primarySoft : pal.bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSel ? pal.primary : pal.border,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSel
                                      ? Icons.check_box_rounded
                                      : Icons.check_box_outline_blank_rounded,
                                  color: isSel ? pal.primary : pal.muted,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    chName,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: isSel ? pal.primary : pal.text,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: pal.card,
                                    borderRadius: BorderRadius.circular(99),
                                    border: Border.all(color: pal.border),
                                  ),
                                  child: Text(
                                    '${DefaultSyllabusData.toBanglaNum(cnt)}টি',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: isSel ? pal.primary : pal.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. JSON Bank Selector (for practice mode)
              if (!isSavedMode) ...[
                TactileCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '২. অধ্যায়ের JSON ফাইল / প্রশ্নব্যাংক নির্বাচন করো',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      if (availBanks.isEmpty)
                        Text(
                          'এই অধ্যায়ে এখনো কোনো প্রশ্নব্যাংক যুক্ত করা নেই। Settings থেকে JSON প্রশ্ন আপলোড করো।',
                          style: TextStyle(fontSize: 12.5, color: pal.muted),
                        )
                      else
                        ...availBanks.map((b) {
                          final bKey = b['key'] as String;
                          final isSel = _step3SelectedBanks.contains(bKey);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  if (isSel) {
                                    _step3SelectedBanks.remove(bKey);
                                  } else {
                                    _step3SelectedBanks.add(bKey);
                                    _step3SelectedChapters.add(b['chapter'] as String);
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSel ? pal.primarySoft : pal.bg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSel ? pal.primary : pal.border,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSel
                                          ? Icons.check_box_rounded
                                          : Icons.check_box_outline_blank_rounded,
                                      color: isSel ? pal.primary : pal.muted,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${b['bankName']} (${b['chapter']})',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isSel ? pal.primary : pal.text,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${DefaultSyllabusData.toBanglaNum(b['count'])}টি',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: pal.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // 3. Question Count & 4. Exam Time
              Row(
                children: [
                  Expanded(
                    child: TactileCard(
                      onTap: () async {
                        final res = await _showPromptDialog(
                          title: 'প্রশ্নের সংখ্যা',
                          message: 'কতটি প্রশ্নের পরীক্ষা দিতে চাও?',
                          initialValue: _step3QCount.toString(),
                        );
                        if (res != null) {
                          final v = int.tryParse(res);
                          if (v != null && v > 0) setState(() => _step3QCount = v);
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('৩. প্রশ্নের সংখ্যা',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: pal.bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: pal.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${DefaultSyllabusData.toBanglaNum(_step3QCount)}',
                                    style: const TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.w900)),
                                Text('টি প্রশ্ন',
                                    style: TextStyle(fontSize: 12.5, color: pal.muted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TactileCard(
                      onTap: () async {
                        final res = await _showPromptDialog(
                          title: 'পরীক্ষার সময় (মিনিট)',
                          message: 'পরীক্ষার জন্য কত মিনিট নির্ধারণ করতে চাও?',
                          initialValue: _step3Time.toString(),
                        );
                        if (res != null) {
                          final v = int.tryParse(res);
                          if (v != null && v > 0) setState(() => _step3Time = v);
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('৪. পরীক্ষার সময়',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: pal.bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: pal.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${DefaultSyllabusData.toBanglaNum(_step3Time)}',
                                    style: const TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.w900)),
                                Text('মিনিট',
                                    style: TextStyle(fontSize: 12.5, color: pal.muted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Bottom Setup Bar
              TactileCard(
                child: Column(
                  children: [
                    if (!isSavedMode)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('শুধু পূর্বের ভুল করা প্রশ্নসমূহ',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                                Text(
                                  wrongPool.isNotEmpty
                                      ? '${DefaultSyllabusData.toBanglaNum(wrongPool.length)}টি ভুল করা প্রশ্ন আছে'
                                      : 'কোনো ভুল করা প্রশ্ন নেই',
                                  style: TextStyle(fontSize: 12, color: pal.muted),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _step3OnlyPrevWrong,
                            activeColor: pal.primary,
                            onChanged: (v) => setState(() => _step3OnlyPrevWrong = v),
                          ),
                        ],
                      ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _step3NegMarking ? pal.primarySoft : pal.bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _step3NegMarking ? pal.primary : pal.border,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _step3NegMarking ? 'নেগেটিভ মার্কিং চালু (-০.২৫)' : 'নেগেটিভ মার্কিং বন্ধ (০.০০)',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: _step3NegMarking ? pal.primary : pal.text,
                            ),
                          ),
                          Switch(
                            value: _step3NegMarking,
                            activeColor: pal.primary,
                            onChanged: (v) => setState(() => _step3NegMarking = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TactileButton(
                      label: 'পরীক্ষা শুরু করো',
                      icon: const Icon(Icons.play_arrow_rounded),
                      variant: TactileBtnVariant.primary,
                      isBlock: true,
                      onPressed: () {
                        if (_step3SelectedChapters.isEmpty) {
                          _showAppDialog(
                            title: 'অধ্যায় নির্বাচন করো',
                            message: 'পরীক্ষা শুরু করার জন্য অন্তত ১টি অধ্যায় সিলেক্ট করো।',
                          );
                          return;
                        }
                        var pool = _getFilteredStep3Questions();
                        if (!isSavedMode && _step3OnlyPrevWrong) {
                          pool = wrongPool;
                        }
                        if (pool.isEmpty) {
                          _showAppDialog(
                            title: 'প্রশ্ন নেই',
                            message:
                                'নির্বাচিত অধ্যায়ে কোনো প্রশ্ন পাওয়া যায়নি। Settings থেকে এই অধ্যায়ে JSON প্রশ্ন আপলোড করো।',
                          );
                          return;
                        }
                        final shuffled = List<QuestionItem>.from(pool)..shuffle();
                        final count = _step3QCount.clamp(1, shuffled.length);
                        final chosen = shuffled.take(count).toList();
                        _startLiveExam(
                          questions: chosen,
                          minutes: _step3Time,
                          negMarking: _step3NegMarking,
                          title: isSavedMode
                              ? 'সেইভ করা প্রশ্নের পরীক্ষা'
                              : '$_step3Subject — প্র্যাকটিস পরীক্ষা',
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== 4. LIVE SCROLLING EXAM SCREEN ====================
  String _formatClock(int sec) {
    final s = sec < 0 ? 0 : sec;
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  void _showQuestionNavigatorSheet(AppPalette pal, {required bool isResultMode}) {
    final questions = isResultMode ? (_currentResult?.questions ?? []) : _liveExamQuestions;
    final answers = isResultMode ? (_currentResult?.answers ?? {}) : _liveExamAnswers;

    showModalBottomSheet(
      context: context,
      backgroundColor: pal.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'সব প্রশ্ন এক নজরে',
                    style: TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  itemCount: questions.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.25,
                  ),
                  itemBuilder: (ctx, i) {
                    final q = questions[i];
                    final chosen = answers[q.id];
                    Color bg = pal.cardAlt;
                    Color border = pal.border;
                    Color fg = pal.text;

                    if (isResultMode) {
                      if (chosen != null && chosen == q.answer) {
                        bg = const Color(0x2E10B981);
                        border = const Color(0xFF10B981);
                        fg = const Color(0xFF10B981);
                      } else if (chosen != null && chosen != q.answer) {
                        bg = const Color(0x2EEF4444);
                        border = const Color(0xFFEF4444);
                        fg = const Color(0xFFEF4444);
                      }
                    } else if (chosen != null) {
                      bg = const Color(0x2E6366F1);
                      border = const Color(0xFF6366F1);
                      fg = const Color(0xFF6366F1);
                    }

                    return InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        final keyContext = _questionItemKeys[i]?.currentContext;
                        if (keyContext != null) {
                          Scrollable.ensureVisible(
                            keyContext,
                            duration: const Duration(milliseconds: 300),
                          );
                        }
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: border, width: 1.5),
                        ),
                        child: Text(
                          DefaultSyllabusData.toBanglaNum(i + 1),
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800, color: fg),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLiveExamScreen(AppPalette pal) {
    final ansCount = _liveExamAnswers.length;
    final totalCount = _liveExamQuestions.isEmpty ? 1 : _liveExamQuestions.length;

    return Scaffold(
      backgroundColor: pal.bg,
      appBar: AppBar(
        backgroundColor: pal.card,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () async {
            final ok = await _showAppDialog(
              title: 'বের হবেন?',
              message: 'বের হলে বর্তমান পরীক্ষার অগ্রগতি হারাবেন।',
              isConfirm: true,
              isDanger: true,
            );
            if (ok) {
              _examTimer?.cancel();
              setState(() => _activeScreen = ActiveScreen.mainTabs);
            }
          },
        ),
        centerTitle: true,
        title: Column(
          children: [
            Text(_liveExamTitle,
                style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
            Text(
              'সময়ঃ ${DefaultSyllabusData.toBanglaNum(_liveExamMinutes)} মিনিট • পূর্ণমানঃ ${DefaultSyllabusData.toBanglaNum(_liveExamQuestions.length)} • নেগেটিভঃ ${_liveExamNeg ? "০.২৫" : "নেই"}',
              style: TextStyle(fontSize: 11.5, color: pal.muted, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 64),
        child: FloatingActionButton.extended(
          backgroundColor: pal.blue,
          foregroundColor: Colors.white,
          onPressed: () => _showQuestionNavigatorSheet(pal, isResultMode: false),
          icon: const Icon(Icons.grid_view_rounded, size: 18),
          label: const Text('প্রশ্ন লিস্ট', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
              itemCount: _liveExamQuestions.length,
              itemBuilder: (ctx, idx) {
                final q = _liveExamQuestions[idx];
                final chosen = _liveExamAnswers[q.id];

                return Container(
                  key: _questionItemKeys[idx],
                  margin: const EdgeInsets.only(bottom: 14),
                  child: TactileCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (q.stimulus.isNotEmpty)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: pal.bg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border(left: BorderSide(color: pal.primary, width: 4)),
                            ),
                            child: MathScienceText(
                              'উদ্দীপক:\n${q.stimulus}',
                              style: const TextStyle(fontSize: 14, height: 1.55),
                            ),
                          ),
                        QuestionMediaView(rawMedia: q.svg),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: MathScienceText(
                                '${DefaultSyllabusData.toBanglaNum(idx + 1)}. ${q.question}',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                              decoration: BoxDecoration(
                                color: pal.bg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: pal.border),
                              ),
                              child: Text(
                                '১',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: pal.muted),
                              ),
                            ),
                          ],
                        ),
                        ReferenceBadgePill(reference: q.reference),
                        const SizedBox(height: 12),
                        ...q.options.map((opt) {
                          final isSelected = chosen == opt.label;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: InkWell(
                              onTap: () {
                                setState(() => _liveExamAnswers[q.id] = opt.label);
                              },
                              borderRadius: BorderRadius.circular(15),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0x1F6366F1)
                                      : pal.cardAlt,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF6366F1)
                                        : pal.border,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 30,
                                      height: 30,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected
                                            ? const Color(0xFF4F46E5)
                                            : pal.card,
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFF4F46E5)
                                              : pal.muted,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Text(
                                        opt.label,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: isSelected ? Colors.white : pal.text,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: MathScienceText(
                                        opt.text,
                                        style: const TextStyle(
                                            fontSize: 14.5, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Fixed Exam Footer Bar (matching .exam-fixed-footer)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF065F35), Color(0xFF044325)],
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Timer Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _secondsRemaining <= 60
                          ? const Color(0x47D93645)
                          : Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.22)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined, color: Colors.white, size: 18),
                        const SizedBox(width: 7),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('বাকি সময়',
                                style: TextStyle(color: Colors.white70, fontSize: 10.5)),
                            Text(
                              _formatClock(_secondsRemaining),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Submit CTA
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF05663A),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      final ok = await _showAppDialog(
                        title: 'তুমি কি সাবমিট করতে চাও?',
                        message:
                            'তুমি ${DefaultSyllabusData.toBanglaNum(ansCount)}/${DefaultSyllabusData.toBanglaNum(_liveExamQuestions.length)}টি প্রশ্নের উত্তর দিয়েছো।',
                        isConfirm: true,
                      );
                      if (ok) _submitLiveExam();
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: const Text('সাবমিট করো',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900)),
                  ),

                  // Answered Counter
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.22)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('উত্তর দিয়েছো',
                            style: TextStyle(color: Colors.white70, fontSize: 10.5)),
                        Text(
                          '${DefaultSyllabusData.toBanglaNum(ansCount)}/${DefaultSyllabusData.toBanglaNum(_liveExamQuestions.length)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        SizedBox(
                          width: 48,
                          height: 4,
                          child: LinearProgressIndicator(
                            value: (ansCount / totalCount).clamp(0.0, 1.0),
                            backgroundColor: Colors.white24,
                            color: const Color(0xFF4ADE80),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 5. RESULT REVIEW SCREEN ====================
  Widget _buildExamResultScreen(AppPalette pal, ExamResultItem res) {
    final isExamSaved = _savedExams.any((e) => e.id == res.id);
    final filteredEntries = <MapEntry<int, QuestionItem>>[];
    for (var i = 0; i < res.questions.length; i++) {
      final q = res.questions[i];
      final a = res.answers[q.id];
      final isGood = q.answer != null && a == q.answer;
      final isBad = q.answer != null && a != null && a != q.answer;
      final isSkip = a == null;
      if (_resultFilter == 'good' && !isGood) continue;
      if (_resultFilter == 'bad' && !isBad) continue;
      if (_resultFilter == 'skip' && !isSkip) continue;
      filteredEntries.add(MapEntry(i, q));
    }

    return Scaffold(
      backgroundColor: pal.bg,
      appBar: AppBar(
        backgroundColor: pal.card,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => setState(() => _activeScreen = ActiveScreen.mainTabs),
        ),
        centerTitle: true,
        title: const Text('রেজাল্ট', style: TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TactileButton(
              label: isExamSaved ? 'সেইভড পরীক্ষা' : 'সেইভ রেজাল্ট',
              icon: Icon(isExamSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
              variant: isExamSaved ? TactileBtnVariant.primary : TactileBtnVariant.secondary,
              isSmall: true,
              onPressed: () {
                setState(() {
                  if (isExamSaved) {
                    _savedExams.removeWhere((e) => e.id == res.id);
                    _unsavedTimestamps[res.id] = DateTime.now().millisecondsSinceEpoch;
                  } else {
                    res.savedAt = DateTime.now().millisecondsSinceEpoch;
                    _savedExams.add(res);
                  }
                });
                _saveStateAndSync();
              },
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // Top 3 Result Summary Boxes (মার্কস, একুরেসি, সময়)
          Row(
            children: [
              Expanded(
                child: _buildResSummaryBox(
                  pal,
                  headTitle: 'মার্কস',
                  headColor: const Color(0xFF10B981),
                  valueText:
                      '${DefaultSyllabusData.toBanglaNum(res.scoreFormatted)}/${DefaultSyllabusData.toBanglaNum(res.gradable)}',
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildResSummaryBox(
                  pal,
                  headTitle: 'একুরেসি',
                  headColor: const Color(0xFF9333EA),
                  valueText: '${DefaultSyllabusData.toBanglaNum(res.accuracy)}%',
                  icon: Icons.adjust_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildResSummaryBox(
                  pal,
                  headTitle: 'সময়',
                  headColor: const Color(0xFF0EA5E9),
                  valueText: '${DefaultSyllabusData.toBanglaNum(res.elapsedMin)} মিনিট',
                  icon: Icons.access_time_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3 Filter Pills (সঠিক / ভুল / স্কিপ)
          Row(
            children: [
              Expanded(
                child: _buildResFilterPill(
                  pal,
                  filterKey: 'good',
                  dotColor: const Color(0xFF10B981),
                  label: '${DefaultSyllabusData.toBanglaNum(res.correct)} সঠিক',
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _buildResFilterPill(
                  pal,
                  filterKey: 'bad',
                  dotColor: const Color(0xFFEF4444),
                  label: '${DefaultSyllabusData.toBanglaNum(res.wrong)} ভুল',
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _buildResFilterPill(
                  pal,
                  filterKey: 'skip',
                  dotColor: const Color(0xFFF59E0B),
                  label: '${DefaultSyllabusData.toBanglaNum(res.skip)} স্কিপ',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Question Review Cards
          ...filteredEntries.map((entry) {
            final idx = entry.key;
            final q = entry.value;
            final a = res.answers[q.id];
            final isSavedQ = _savedQuestions.contains(q.id);

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TactileCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (q.stimulus.isNotEmpty)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: pal.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border(left: BorderSide(color: pal.primary, width: 4)),
                        ),
                        child: MathScienceText('উদ্দীপক:\n${q.stimulus}'),
                      ),
                    QuestionMediaView(rawMedia: q.svg),
                    MathScienceText('${DefaultSyllabusData.toBanglaNum(idx + 1)}. ${q.question}'),
                    ReferenceBadgePill(reference: q.reference),
                    const SizedBox(height: 10),
                    ...q.options.map((opt) {
                      final isCorrectOpt = opt.label == q.answer;
                      final isUserOpt = a == opt.label;
                      Color bg = pal.cardAlt;
                      Color border = pal.border;
                      String badgeText = '';

                      if (isCorrectOpt && a == null) {
                        bg = const Color(0x24F59E0B);
                        border = const Color(0xFFF59E0B);
                        badgeText = '✓ সঠিক উত্তর';
                      } else if (isCorrectOpt && isUserOpt) {
                        bg = const Color(0x2410B981);
                        border = const Color(0xFF10B981);
                        badgeText = '✓ তোমার উত্তর (সঠিক)';
                      } else if (isCorrectOpt) {
                        bg = const Color(0x2410B981);
                        border = const Color(0xFF10B981);
                        badgeText = '✓ সঠিক উত্তর';
                      } else if (isUserOpt && !isCorrectOpt) {
                        bg = const Color(0x24EF4444);
                        border = const Color(0xFFEF4444);
                        badgeText = '✕ তোমার উত্তর';
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: border, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: pal.card,
                                border: Border.all(color: border, width: 1.5),
                              ),
                              child: Text(opt.label,
                                  style: const TextStyle(
                                      fontSize: 12.5, fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: MathScienceText(opt.text)),
                            if (badgeText.isNotEmpty)
                              Text(
                                badgeText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: border,
                                ),
                              ),
                          ],
                        ),
                      );
                    }),

                    // Explanation Box
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: pal.primarySoft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: pal.primarySoft3d),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '✓ সঠিক উত্তর: ${q.answer ?? "—"}',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: pal.primary,
                            ),
                          ),
                          const SizedBox(height: 5),
                          MathScienceText(
                            q.explanation.isNotEmpty
                                ? q.explanation
                                : 'সঠিক উত্তর: ${q.answer ?? "—"}',
                            style: const TextStyle(fontSize: 13.5, height: 1.5),
                          ),
                          SourceBadgePill(source: q.source),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            '${q.subject} • ${q.chapter}',
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: pal.primary),
                          ),
                        ),
                        TactileButton(
                          label: isSavedQ ? 'সেইভড প্রশ্ন' : 'প্রশ্ন সেইভ',
                          icon: Icon(
                              isSavedQ ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
                          variant: isSavedQ ? TactileBtnVariant.primary : TactileBtnVariant.ghost,
                          isSmall: true,
                          onPressed: () {
                            setState(() {
                              if (isSavedQ) {
                                _savedQuestions.remove(q.id);
                                _savedQuestionsData.remove(q.id);
                                _unsavedTimestamps[q.id] = DateTime.now().millisecondsSinceEpoch;
                              } else {
                                q.savedAt = DateTime.now().millisecondsSinceEpoch;
                                _savedQuestions.add(q.id);
                                _savedQuestionsData[q.id] = q;
                              }
                            });
                            _saveStateAndSync();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildResSummaryBox(
    AppPalette pal, {
    required String headTitle,
    required Color headColor,
    required String valueText,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: headColor, width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: headColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Text(
              headTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: headColor),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    valueText,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResFilterPill(
    AppPalette pal, {
    required String filterKey,
    required Color dotColor,
    required String label,
  }) {
    final active = _resultFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _resultFilter = active ? 'all' : filterKey),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: active ? dotColor.withOpacity(0.15) : pal.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? dotColor : pal.border, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: active ? dotColor : pal.text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 6. SAVED VIEW ====================
  Widget _buildSavedView(AppPalette pal) {
    final term = _savedSearchCtrl.text.trim().toLowerCase();
    final allSavedQs = _getAllSavedQuestionObjects();
    var filteredSavedQs = allSavedQs;
    if (_savedFilterSubject.isNotEmpty) {
      filteredSavedQs =
          filteredSavedQs.where((q) => q.subject == _savedFilterSubject).toList();
    }
    if (_savedFilterChapter.isNotEmpty) {
      filteredSavedQs =
          filteredSavedQs.where((q) => q.chapter == _savedFilterChapter).toList();
    }
    if (term.isNotEmpty) {
      filteredSavedQs = filteredSavedQs
          .where((q) =>
              '${q.question} ${q.stimulus} ${q.reference} ${q.subject} ${q.chapter}'
                  .toLowerCase()
                  .contains(term))
          .toList();
    }

    final combinedExams = [
      ..._savedExams.reversed,
      ..._history.reversed
          .where((h) => !_savedExams.any((s) => s.id == h.id)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bookmark_rounded, color: pal.primary),
                const SizedBox(width: 7),
                const Text(
                  'সেইভ করা পরীক্ষা ও প্রশ্ন',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TactileButton(
                  label: 'সেইভ করা পরীক্ষা',
                  variant: _savedSubTab == 'exams'
                      ? TactileBtnVariant.primary
                      : TactileBtnVariant.ghost,
                  isSmall: true,
                  onPressed: () => setState(() => _savedSubTab = 'exams'),
                ),
                const SizedBox(width: 8),
                TactileButton(
                  label: 'সেইভ করা প্রশ্ন',
                  variant: _savedSubTab == 'questions'
                      ? TactileBtnVariant.primary
                      : TactileBtnVariant.ghost,
                  isSmall: true,
                  onPressed: () => setState(() => _savedSubTab = 'questions'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Filter Bar
        TactileCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _savedFilterSubject,
                        items: [
                          const DropdownMenuItem(value: '', child: Text('সকল বিষয়')),
                          ..._subjects.map(
                            (s) => DropdownMenuItem(value: s.name, child: Text(s.name)),
                          ),
                        ],
                        onChanged: (v) => setState(() {
                          _savedFilterSubject = v ?? '';
                          _savedFilterChapter = '';
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _savedSearchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'প্রশ্ন বা পরীক্ষা খুঁজুন...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        filled: true,
                        fillColor: pal.bg,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (_savedSubTab == 'exams') ...[
          if (combinedExams.isEmpty)
            TactileCard(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('কোনো সেইভ করা পরীক্ষা পাওয়া যায়নি',
                      style: TextStyle(color: pal.muted, fontWeight: FontWeight.w700)),
                ),
              ),
            )
          else
            ...combinedExams.map((ex) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TactileCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ex.title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                          'স্কোর: ${DefaultSyllabusData.toBanglaNum(ex.scoreFormatted)}/${DefaultSyllabusData.toBanglaNum(ex.gradable)} • একুরেসি: ${DefaultSyllabusData.toBanglaNum(ex.accuracy)}% • ${ex.date}',
                          style: TextStyle(fontSize: 12.5, color: pal.muted),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TactileButton(
                              label: 'উত্তর ও ব্যাখ্যা দেখো',
                              variant: TactileBtnVariant.secondary,
                              isSmall: true,
                              onPressed: () => setState(() {
                                _currentResult = ex;
                                _resultFilter = 'all';
                                _activeScreen = ActiveScreen.examResult;
                              }),
                            ),
                            TactileButton(
                              label: 'পুনরায় পরীক্ষা দাও',
                              variant: TactileBtnVariant.primary,
                              isSmall: true,
                              onPressed: () => _startLiveExam(
                                questions: ex.questions,
                                minutes: ex.questions.length,
                                negMarking: ex.negMarking,
                                title: ex.title,
                              ),
                            ),
                            TactileButton(
                              label: 'ডিলিট',
                              variant: TactileBtnVariant.danger,
                              isSmall: true,
                              onPressed: () {
                                setState(() {
                                  _deletedIds.add(ex.id);
                                  _savedExams.removeWhere((x) => x.id == ex.id);
                                  _history.removeWhere((x) => x.id == ex.id);
                                });
                                _saveStateAndSync();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )),
        ] else ...[
          // Saved Questions Mode Bar
          TactileCard(
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text(
                  _savedQuestionsMode == 'practice' ? 'প্র্যাকটিস মোড' : 'রিভিশন মোড',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TactileButton(
                      label: 'রিভিশন মোড',
                      variant: _savedQuestionsMode == 'revision'
                          ? TactileBtnVariant.primary
                          : TactileBtnVariant.ghost,
                      isSmall: true,
                      onPressed: () => setState(() => _savedQuestionsMode = 'revision'),
                    ),
                    TactileButton(
                      label: 'প্র্যাকটিস মোড',
                      variant: _savedQuestionsMode == 'practice'
                          ? TactileBtnVariant.primary
                          : TactileBtnVariant.ghost,
                      isSmall: true,
                      onPressed: () => setState(() => _savedQuestionsMode = 'practice'),
                    ),
                    TactileButton(
                      label: 'পরীক্ষা দাও (সিলেক্ট করে) →',
                      variant: TactileBtnVariant.secondary,
                      isSmall: true,
                      onPressed: _openSavedQuestionsExamSetup,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (filteredSavedQs.isEmpty)
            TactileCard(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('কোনো সেইভ করা প্রশ্ন পাওয়া যায়নি',
                      style: TextStyle(color: pal.muted, fontWeight: FontWeight.w700)),
                ),
              ),
            )
          else
            ...filteredSavedQs.asMap().entries.map((entry) {
              final idx = entry.key;
              final q = entry.value;
              final isPractice = _savedQuestionsMode == 'practice';
              final chosen = _savedPracticeAnswers[q.id];
              final showAnswer = !isPractice || chosen != null;

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TactileCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              '${q.subject} • ${q.chapter}',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: pal.primary),
                            ),
                          ),
                          TactileButton(
                            label: 'আনসেইভ',
                            variant: TactileBtnVariant.danger,
                            isSmall: true,
                            onPressed: () {
                              setState(() {
                                _savedQuestions.remove(q.id);
                                _savedQuestionsData.remove(q.id);
                                _unsavedTimestamps[q.id] = DateTime.now().millisecondsSinceEpoch;
                              });
                              _saveStateAndSync();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (q.stimulus.isNotEmpty)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: pal.bg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border(left: BorderSide(color: pal.primary, width: 4)),
                          ),
                          child: MathScienceText('উদ্দীপক:\n${q.stimulus}'),
                        ),
                      QuestionMediaView(rawMedia: q.svg),
                      MathScienceText(
                          '${DefaultSyllabusData.toBanglaNum(idx + 1)}. ${q.question}'),
                      ReferenceBadgePill(reference: q.reference),
                      const SizedBox(height: 10),
                      ...q.options.map((opt) {
                        Color bg = pal.cardAlt;
                        Color border = pal.border;
                        if (showAnswer) {
                          if (opt.label == q.answer) {
                            bg = const Color(0x2410B981);
                            border = const Color(0xFF10B981);
                          } else if (chosen == opt.label && chosen != q.answer) {
                            bg = const Color(0x24EF4444);
                            border = const Color(0xFFEF4444);
                          }
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: isPractice
                                ? () => setState(() => _savedPracticeAnswers[q.id] = opt.label)
                                : null,
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: border, width: 1.5),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: pal.card,
                                      border: Border.all(color: border, width: 1.5),
                                    ),
                                    child: Text(opt.label,
                                        style: const TextStyle(
                                            fontSize: 12.5, fontWeight: FontWeight.w800)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(child: MathScienceText(opt.text)),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      if (showAnswer)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: pal.primarySoft,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: pal.primarySoft3d),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '✓ সঠিক উত্তর: ${q.answer ?? "—"}',
                                style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: pal.primary),
                              ),
                              const SizedBox(height: 5),
                              MathScienceText(
                                'ব্যাখ্যা: ${q.explanation.isNotEmpty ? q.explanation : "দেওয়া নেই।"}',
                                style: const TextStyle(fontSize: 13.5),
                              ),
                              SourceBadgePill(source: q.source),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ],
    );
  }

  // ==================== 7. SETTINGS VIEW ====================
  Future<void> _pickPracticeBankJsonFiles() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: true,
        withData: true,
      );
      if (res == null || res.files.isEmpty) return;

      final combined = <dynamic>[];
      for (final f in res.files) {
        if (f.bytes == null) continue;
        final txt = utf8.decode(f.bytes!);
        final parsed = jsonDecode(txt);
        if (parsed is List) {
          final bName = f.name.replaceAll(RegExp(r'\.json$', caseSensitive: false), '');
          for (final item in parsed) {
            if (item is Map) {
              combined.add({...item, 'sourcePdf': item['sourcePdf'] ?? bName});
            }
          }
          if (_importBankNameCtrl.text.trim().isEmpty && res.files.length == 1) {
            _importBankNameCtrl.text = bName;
          }
        }
      }
      setState(() {
        _importJsonPasteCtrl.text = const JsonEncoder.withIndent('  ').convert(combined);
      });
    } catch (_) {
      _showAppDialog(
        title: 'JSON ফাইল ত্রুটি',
        message: 'নির্বাচিত ফাইলে সঠিক JSON Array পাওয়া যায়নি।',
        isDanger: true,
      );
    }
  }

  void _saveUploadedPracticeBank() {
    final subj = _importSubject.isNotEmpty ? _importSubject : _subjects.first.name;
    final chap = _importChapter == '__NEW__'
        ? _importNewChapCtrl.text.trim()
        : (_importChapter.isNotEmpty
            ? _importChapter
            : (_getChaptersForSubject(subj).isNotEmpty
                ? _getChaptersForSubject(subj).first
                : 'সাধারণ'));
    if (chap.isEmpty) {
      _showAppDialog(
        title: 'অধ্যায় সিলেক্ট করো',
        message: 'অনুগ্রহ করে অধ্যায় সিলেক্ট করো অথবা নতুন অধ্যায়ের নাম লেখো।',
        isDanger: true,
      );
      return;
    }
    final rawText = _importJsonPasteCtrl.text.trim();
    if (rawText.isEmpty) {
      _showAppDialog(
        title: 'JSON কোড প্রয়োজন',
        message: 'JSON ফাইল নির্বাচন করুন অথবা JSON কোড পেস্ট করুন।',
        isDanger: true,
      );
      return;
    }
    try {
      final parsed = jsonDecode(rawText);
      if (parsed is! List) throw Exception('JSON অবশ্যই একটি Array হতে হবে।');
      final bankName = _importBankNameCtrl.text.trim().isNotEmpty
          ? _importBankNameCtrl.text.trim()
          : '$subj — $chap';
      final compKey = FirebaseSyncService.bankCompositeKey(subj, chap, bankName);
      _deletedBanksMap.remove(compKey);

      final newQs = _normalizeUploadedQuestions(parsed, bankName, subj, chap);
      if (newQs.isEmpty) {
        throw Exception('সঠিক question ও অন্তত ২টি options-সহ কোনো প্রশ্ন পাওয়া যায়নি।');
      }

      if (!_chapters.any((c) =>
          c.subject == subj &&
          FirebaseSyncService.normChap(c.name) == FirebaseSyncService.normChap(chap))) {
        _chapters.add(ChapterItem(
          id: 'chap-${DateTime.now().millisecondsSinceEpoch}',
          subject: subj,
          name: chap,
        ));
      }

      setState(() {
        _bank.addAll(newQs);
        _importJsonPasteCtrl.clear();
        _importBankNameCtrl.clear();
        _importNewChapCtrl.clear();
      });
      _saveStateAndSync();
      _showAppDialog(
        title: 'আপলোড সফল!',
        message:
            '${DefaultSyllabusData.toBanglaNum(newQs.length)}টি প্রশ্ন “$subj › $chap” অধ্যায়ে সংরক্ষিত হয়েছে।',
      );
    } catch (e) {
      _showAppDialog(title: 'আপলোড ব্যর্থ', message: e.toString(), isDanger: true);
    }
  }

  Widget _buildSettingsView(AppPalette pal) {
    final chapsForImport = _getChaptersForSubject(_importSubject);
    if (_importChapter.isEmpty && chapsForImport.isNotEmpty) {
      _importChapter = chapsForImport.first;
    }

    // Group banks for management
    final bankGroupMap = <String, Map<String, dynamic>>{};
    for (final q in _bank) {
      final comp = FirebaseSyncService.bankCompositeKey(q.subject, q.chapter, q.sourcePdf);
      bankGroupMap.putIfAbsent(
          comp,
          () => {
                'compKey': comp,
                'subject': q.subject,
                'chapter': q.chapter,
                'bankName': q.sourcePdf,
                'count': 0,
              });
      bankGroupMap[comp]!['count'] = (bankGroupMap[comp]!['count'] as int) + 1;
    }
    final bankGroups = bankGroupMap.values.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.settings_outlined, color: pal.primary),
            const SizedBox(width: 8),
            const Text('Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 12),

        // 2 Settings Tab Cards (প্রশ্নব্যাংক ও ব্যাকআপ / বিষয় ও অধ্যায়)
        Row(
          children: [
            Expanded(
              child: TactileCard(
                bgColor: _settingsSubTab == 'examBankTab' ? pal.primarySoft : pal.card,
                borderColor: _settingsSubTab == 'examBankTab' ? pal.primary : pal.border,
                onTap: () => setState(() => _settingsSubTab = 'examBankTab'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'প্রশ্নব্যাংক ও ব্যাকআপ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _settingsSubTab == 'examBankTab' ? pal.primary : pal.text,
                      ),
                    ),
                    Text('JSON প্রশ্ন ও ব্যাকআপ',
                        style: TextStyle(fontSize: 11.5, color: pal.muted)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TactileCard(
                bgColor: _settingsSubTab == 'hierarchyTab' ? pal.primarySoft : pal.card,
                borderColor: _settingsSubTab == 'hierarchyTab' ? pal.primary : pal.border,
                onTap: () => setState(() => _settingsSubTab = 'hierarchyTab'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'বিষয় ও অধ্যায়',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _settingsSubTab == 'hierarchyTab' ? pal.primary : pal.text,
                      ),
                    ),
                    Text('বিষয় ও অধ্যায় পরিচালনা',
                        style: TextStyle(fontSize: 11.5, color: pal.muted)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_settingsSubTab == 'examBankTab') ...[
          TactileCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'প্র্যাকটিস প্রশ্নব্যাংক আপলোড করুন (JSON)',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                const Text('বিষয় সিলেক্ট করুন *',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                DropdownButtonFormField<String>(
                  value: _subjects.any((s) => s.name == _importSubject)
                      ? _importSubject
                      : _subjects.first.name,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: pal.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  ),
                  items: _subjects
                      .map((s) => DropdownMenuItem(value: s.name, child: Text(s.name)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    final chaps = _getChaptersForSubject(v);
                    setState(() {
                      _importSubject = v;
                      _importChapter = chaps.isNotEmpty ? chaps.first : '__NEW__';
                    });
                  },
                ),
                const SizedBox(height: 12),
                const Text('অধ্যায় সিলেক্ট করুন *',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: chapsForImport.contains(_importChapter) ? _importChapter : '__NEW__',
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: pal.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  ),
                  items: [
                    ...chapsForImport.map(
                        (c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))),
                    const DropdownMenuItem(
                        value: '__NEW__', child: Text('+ নতুন অধ্যায়ের নাম লিখুন...')),
                  ],
                  onChanged: (v) => setState(() => _importChapter = v ?? '__NEW__'),
                ),
                if (_importChapter == '__NEW__') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _importNewChapCtrl,
                    decoration: InputDecoration(
                      hintText: 'নতুন অধ্যায়ের নাম লিখুন...',
                      filled: true,
                      fillColor: pal.bg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Text('প্রশ্নব্যাংকের নাম (ঐচ্ছিক)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                TextField(
                  controller: _importBankNameCtrl,
                  decoration: InputDecoration(
                    hintText: 'যেমন: ভেক্টর প্র্যাকটিস সেট ১',
                    filled: true,
                    fillColor: pal.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  ),
                ),
                const SizedBox(height: 12),
                TactileButton(
                  label: 'এক বা একাধিক JSON ফাইল নির্বাচন করুন',
                  icon: const Icon(Icons.upload_file_rounded),
                  variant: TactileBtnVariant.secondary,
                  isBlock: true,
                  onPressed: _pickPracticeBankJsonFiles,
                ),
                const SizedBox(height: 12),
                const Text('অথবা JSON কোড পেস্ট করুন',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                TextField(
                  controller: _importJsonPasteCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: '[{"question":"প্রশ্ন?","options":[{"label":"ক","text":"..."}],"answer":"ক"}]',
                    filled: true,
                    fillColor: pal.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  ),
                ),
                const SizedBox(height: 12),
                TactileButton(
                  label: 'প্রশ্নব্যাংকে সংরক্ষণ করুন',
                  variant: TactileBtnVariant.primary,
                  isBlock: true,
                  onPressed: _saveUploadedPracticeBank,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Saved Question Banks Management Card
          TactileCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'সংরক্ষিত প্রশ্নব্যাংকসমূহ (${DefaultSyllabusData.toBanglaNum(bankGroups.length)}টি)',
                  style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                if (bankGroups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: Text('এখনো কোনো প্রশ্নব্যাংক সংরক্ষিত নেই।',
                          style: TextStyle(color: pal.muted)),
                    ),
                  )
                else
                  ...bankGroups.map((bg) {
                    final compKey = bg['compKey'] as String;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 9),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: pal.cardAlt,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: pal.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${bg['bankName']}',
                                    style: const TextStyle(
                                        fontSize: 14, fontWeight: FontWeight.w800)),
                                Text(
                                  '${bg['subject']} › ${bg['chapter']} • ${DefaultSyllabusData.toBanglaNum(bg['count'])}টি প্রশ্ন',
                                  style: TextStyle(fontSize: 12, color: pal.muted),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              TactileButton(
                                label: 'রিনেম',
                                variant: TactileBtnVariant.secondary,
                                isSmall: true,
                                onPressed: () async {
                                  final newName = await _showPromptDialog(
                                    title: 'ব্যাংক রিনেম করুন',
                                    message: 'প্রশ্নব্যাংকের নতুন নাম দিন:',
                                    initialValue: bg['bankName'].toString(),
                                  );
                                  if (newName != null && newName.isNotEmpty) {
                                    setState(() {
                                      for (final q in _bank) {
                                        if (FirebaseSyncService.bankCompositeKey(
                                                q.subject, q.chapter, q.sourcePdf) ==
                                            compKey) {
                                          q.sourcePdf = newName;
                                        }
                                      }
                                    });
                                    _saveStateAndSync();
                                  }
                                },
                              ),
                              const SizedBox(width: 6),
                              TactileButton(
                                label: 'ডিলিট',
                                variant: TactileBtnVariant.danger,
                                isSmall: true,
                                onPressed: () async {
                                  final ok = await _showAppDialog(
                                    title: 'ডিলিট নিশ্চিত করুন',
                                    message:
                                        'আপনি কি নিশ্চিত যে "${bg['bankName']}" মুছে ফেলতে চান?',
                                    isConfirm: true,
                                    isDanger: true,
                                  );
                                  if (ok) {
                                    setState(() {
                                      _deletedBanksMap[compKey] =
                                          DateTime.now().millisecondsSinceEpoch;
                                      _bank.removeWhere((q) =>
                                          FirebaseSyncService.bankCompositeKey(
                                              q.subject, q.chapter, q.sourcePdf) ==
                                          compKey);
                                    });
                                    _saveStateAndSync();
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Full Backup & Restore Card
          TactileCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('সম্পূর্ণ ডাটা ব্যাকআপ ও রিস্টোর',
                    style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    TactileButton(
                      label: 'ব্যাকআপ শেয়ার / এক্সপোর্ট',
                      icon: const Icon(Icons.download_rounded),
                      variant: TactileBtnVariant.primary,
                      isSmall: true,
                      onPressed: () {
                        final jsonStr =
                            const JsonEncoder.withIndent('  ').convert(_buildStatePayload());
                        Share.share(jsonStr, subject: 'onushilon-full-backup.json');
                      },
                    ),
                    TactileButton(
                      label: 'ব্যাকআপ রিস্টোর (JSON)',
                      icon: const Icon(Icons.restore_rounded),
                      variant: TactileBtnVariant.secondary,
                      isSmall: true,
                      onPressed: () async {
                        final res = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['json'],
                          withData: true,
                        );
                        if (res == null || res.files.isEmpty || res.files.first.bytes == null) {
                          return;
                        }
                        try {
                          final txt = utf8.decode(res.files.first.bytes!);
                          final parsed = jsonDecode(txt) as Map<String, dynamic>;
                          _applyNormalizedMap(parsed);
                          await _saveStateAndSync();
                          _showAppDialog(
                            title: 'ব্যাকআপ রিস্টোর সফল!',
                            message: 'তোমার সকল বিষয়, অধ্যায় ও পরীক্ষার ডাটা রিস্টোর হয়েছে।',
                          );
                        } catch (e) {
                          _showAppDialog(
                              title: 'রিস্টোর ব্যর্থ', message: e.toString(), isDanger: true);
                        }
                      },
                    ),
                    TactileButton(
                      label: 'ডিফল্ট রিসেট',
                      variant: TactileBtnVariant.danger,
                      isSmall: true,
                      onPressed: () async {
                        final ok = await _showAppDialog(
                          title: 'ডিফল্ট ক্লিয়ার রিসেট?',
                          message:
                              'সকল পরীক্ষার ডাটা মুছে ১৪টি ডিফল্ট বিষয়ে রিসেট করতে চাও?',
                          isConfirm: true,
                          isDanger: true,
                        );
                        if (ok) {
                          setState(() {
                            _subjects = FirebaseSyncService.buildDefaultSubjects();
                            _chapters = FirebaseSyncService.buildDefaultChapters();
                            _bank.clear();
                            _customExams.clear();
                            _savedExams.clear();
                            _savedQuestions.clear();
                            _savedQuestionsData.clear();
                            _history.clear();
                            _deletedIds.clear();
                            _deletedBanksMap.clear();
                          });
                          _saveStateAndSync();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ] else ...[
          // Subject & Chapter Hierarchy Management
          TactileCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _editingSubjectId.isEmpty
                      ? '১. বিষয় (Subject) এড / এডিট'
                      : 'বিষয় এডিট করো',
                  style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _subjNameCtrl,
                  decoration: InputDecoration(
                    labelText: 'বিষয়ের নাম *',
                    filled: true,
                    fillColor: pal.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _subjSubtitleCtrl,
                  decoration: InputDecoration(
                    labelText: 'সাবটাইটেল / সংক্ষিপ্ত বিবরণ',
                    filled: true,
                    fillColor: pal.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _subjThumbCtrl,
                  decoration: InputDecoration(
                    labelText: 'থাম্বনেইল ছবির লিংক (URL - ঐচ্ছিক)',
                    filled: true,
                    fillColor: pal.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  ),
                ),
                const SizedBox(height: 12),
                TactileButton(
                  label: _editingSubjectId.isEmpty ? 'বিষয় সেইভ করুন' : 'বিষয় আপডেট করুন',
                  variant: TactileBtnVariant.primary,
                  isBlock: true,
                  onPressed: () {
                    final name = _subjNameCtrl.text.trim();
                    if (name.isEmpty) return;
                    setState(() {
                      if (_editingSubjectId.isNotEmpty) {
                        for (final s in _subjects) {
                          if (s.id == _editingSubjectId) {
                            s.name = name;
                            s.subtitle = _subjSubtitleCtrl.text.trim();
                            s.thumb = _subjThumbCtrl.text.trim();
                          }
                        }
                      } else {
                        _subjects.add(SubjectItem(
                          id: 'subj-${DateTime.now().millisecondsSinceEpoch}',
                          name: name,
                          subtitle: _subjSubtitleCtrl.text.trim(),
                          thumb: _subjThumbCtrl.text.trim(),
                        ));
                      }
                      _editingSubjectId = '';
                      _subjNameCtrl.clear();
                      _subjSubtitleCtrl.clear();
                      _subjThumbCtrl.clear();
                    });
                    _saveStateAndSync();
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'সকল বিষয়সমূহ (${DefaultSyllabusData.toBanglaNum(_subjects.length)}টি)',
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                ..._subjects.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final s = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: pal.cardAlt,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: pal.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${DefaultSyllabusData.toBanglaNum(idx + 1)}. ${s.name}',
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                          ),
                        ),
                        Row(
                          children: [
                            TactileButton(
                              label: 'এডিট',
                              variant: TactileBtnVariant.ghost,
                              isSmall: true,
                              onPressed: () => setState(() {
                                _editingSubjectId = s.id;
                                _subjNameCtrl.text = s.name;
                                _subjSubtitleCtrl.text = s.subtitle;
                                _subjThumbCtrl.text = s.thumb;
                              }),
                            ),
                            const SizedBox(width: 6),
                            TactileButton(
                              label: 'ডিলিট',
                              variant: TactileBtnVariant.danger,
                              isSmall: true,
                              onPressed: () {
                                if (_subjects.length <= 1) return;
                                setState(() {
                                  _deletedIds.add(s.id);
                                  _subjects.removeWhere((x) => x.id == s.id);
                                });
                                _saveStateAndSync();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Chapter Manager Card
          TactileCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('২. বিষয়ের অধীনে অধ্যায় এড / এডিট',
                    style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _subjects.any((s) => s.name == _chapParentSubject)
                      ? _chapParentSubject
                      : _subjects.first.name,
                  decoration: InputDecoration(
                    labelText: 'বিষয় নির্বাচন করুন *',
                    filled: true,
                    fillColor: pal.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  ),
                  items: _subjects
                      .map((s) => DropdownMenuItem(value: s.name, child: Text(s.name)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _chapParentSubject = v);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _chapNameCtrl,
                  decoration: InputDecoration(
                    labelText: 'অধ্যায়ের নাম *',
                    filled: true,
                    fillColor: pal.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  ),
                ),
                const SizedBox(height: 12),
                TactileButton(
                  label: _editingChapterId.isEmpty ? 'অধ্যায় সেইভ করুন' : 'অধ্যায় আপডেট করুন',
                  variant: TactileBtnVariant.primary,
                  isBlock: true,
                  onPressed: () {
                    final name = _chapNameCtrl.text.trim();
                    if (name.isEmpty) return;
                    setState(() {
                      if (_editingChapterId.isNotEmpty) {
                        for (final c in _chapters) {
                          if (c.id == _editingChapterId) {
                            c.subject = _chapParentSubject;
                            c.name = name;
                          }
                        }
                      } else {
                        _chapters.add(ChapterItem(
                          id: 'chap-${DateTime.now().millisecondsSinceEpoch}',
                          subject: _chapParentSubject,
                          name: name,
                        ));
                      }
                      _editingChapterId = '';
                      _chapNameCtrl.clear();
                    });
                    _saveStateAndSync();
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'নির্বাচিত বিষয়ের অধ্যায়সমূহ ($_chapParentSubject)',
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                ..._chapters
                    .where((c) => c.subject == _chapParentSubject)
                    .toList()
                    .asMap()
                    .entries
                    .map((entry) {
                  final idx = entry.key;
                  final ch = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: pal.cardAlt,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: pal.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${DefaultSyllabusData.toBanglaNum(idx + 1)}. ${ch.name}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                          ),
                        ),
                        Row(
                          children: [
                            TactileButton(
                              label: 'এডিট',
                              variant: TactileBtnVariant.ghost,
                              isSmall: true,
                              onPressed: () => setState(() {
                                _editingChapterId = ch.id;
                                _chapParentSubject = ch.subject;
                                _chapNameCtrl.text = ch.name;
                              }),
                            ),
                            const SizedBox(width: 6),
                            TactileButton(
                              label: 'ডিলিট',
                              variant: TactileBtnVariant.danger,
                              isSmall: true,
                              onPressed: () {
                                setState(() {
                                  _deletedIds.add(ch.id);
                                  _chapters.removeWhere((x) => x.id == ch.id);
                                });
                                _saveStateAndSync();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
