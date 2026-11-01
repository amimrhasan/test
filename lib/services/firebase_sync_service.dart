// lib/services/firebase_sync_service.dart
// অনুশীলন (Onushilon) — Dual Firebase Realtime Database & Auth Service

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/syllabus_data.dart';
import '../models/app_models.dart';

class FirebaseSyncService {
  // Primary Exam & Question Bank Firebase Config (study-room-exam)
  static const String examApiKey = 'AIzaSyAmQBVDAPxo0imaLYcsHG-3C5sOGCSgbSA';
  static const String examDbUrl =
      'https://study-room-exam-default-rtdb.asia-southeast1.firebasedatabase.app';

  // Companion Auth & Class Sync Config (hsc-study-room)
  static const String companionApiKey = 'AIzaSyCSASYsWY_ocH5Nw6dG-tWBSTQGXfEf-YQ';
  static const String classDbUrl =
      'https://hsc-study-room-default-rtdb.asia-southeast1.firebasedatabase.app';

  static const String localStateKey = 'onushilon_state_v5';
  static const String localAuthKey = 'onushilon_auth_session_v5';
  static const String localThemeKey = 'onushilon_theme_mode';

  static String normChap(String s) =>
      s.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();

  static String bankCompositeKey(String subj, String chap, String bankName) =>
      '${subj.trim()}|||${normChap(chap)}|||${bankName.trim().isEmpty ? "প্রশ্নব্যাংক" : bankName.trim()}';

  // Sign in with Email & Password against study-room-exam or companion hsc-study-room
  static Future<Map<String, dynamic>> signInWithEmailPassword(
      String email, String password) async {
    Future<Map<String, dynamic>> tryKey(String apiKey) async {
      final uri = Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey');
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email.trim(),
              'password': password,
              'returnSecureToken': true,
            }),
          )
          .timeout(const Duration(seconds: 12));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['idToken'] != null) {
        return {
          'email': body['email'] ?? email.trim(),
          'uid': body['localId'] ?? 'uid-${DateTime.now().millisecondsSinceEpoch}',
          'idToken': body['idToken'],
          'refreshToken': body['refreshToken'] ?? '',
        };
      }
      final errMsg = (body['error']?['message'] ?? 'LOGIN_FAILED').toString();
      throw Exception(errMsg);
    }

    try {
      return await tryKey(companionApiKey);
    } catch (_) {
      return await tryKey(examApiKey);
    }
  }

  static List<SubjectItem> buildDefaultSubjects() {
    return DefaultSyllabusData.defaultSubjects
        .map((m) => SubjectItem.fromMap(m))
        .toList();
  }

  static List<ChapterItem> buildDefaultChapters() {
    final list = <ChapterItem>[];
    var sIdx = 1;
    DefaultSyllabusData.rawSyllabusChapters.forEach((subjName, chaps) {
      var cIdx = 1;
      for (final cName in chaps) {
        list.add(ChapterItem(
          id: 'def-chap-$sIdx-$cIdx',
          subject: subjName,
          name: cName,
        ));
        cIdx++;
      }
      sIdx++;
    });
    return list;
  }

  static List<ChapterItem> ensureDefaultChaptersSeeded(
      List<ChapterItem> current, Set<String> deletedIds) {
    final list = List<ChapterItem>.from(current);
    final existingKeys = list
        .map((ch) => '${ch.subject}|||${normChap(ch.name)}')
        .toSet();
    final existingIds = list.map((ch) => ch.id).toSet();

    for (final defCh in buildDefaultChapters()) {
      if (deletedIds.contains(defCh.id)) continue;
      final key = '${defCh.subject}|||${normChap(defCh.name)}';
      if (!existingIds.contains(defCh.id) && !existingKeys.contains(key)) {
        list.add(defCh);
        existingIds.add(defCh.id);
        existingKeys.add(key);
      }
    }
    return list;
  }

  static Future<Map<String, dynamic>?> fetchExamCloudData() async {
    try {
      final res = await http
          .get(Uri.parse('$examDbUrl/study_room_exam_v1.json'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 && res.body.isNotEmpty && res.body != 'null') {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>?> fetchClassCloudSubjectsAndChapters(
      String? idToken) async {
    try {
      final q = (idToken != null && idToken.isNotEmpty)
          ? '?auth=${Uri.encodeComponent(idToken)}'
          : '';
      var res = await http
          .get(Uri.parse('$classDbUrl/study_room_v4.json$q'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200 && q.isNotEmpty) {
        res = await http
            .get(Uri.parse('$classDbUrl/study_room_v4.json'))
            .timeout(const Duration(seconds: 8));
      }
      if (res.statusCode == 200 && res.body.isNotEmpty && res.body != 'null') {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> pushExamCloudData(Map<String, dynamic> payload) async {
    try {
      final res = await http
          .put(
            Uri.parse('$examDbUrl/study_room_exam_v1.json'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
