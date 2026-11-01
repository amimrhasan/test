// lib/models/app_models.dart
import '../data/syllabus_data.dart';

class SubjectItem {
  String id;
  String name;
  String subtitle;
  String thumb;
  int color1;
  int color2;
  String symbol;
  String formula;
  String bottomLabel;

  SubjectItem({
    required this.id,
    required this.name,
    this.subtitle = '',
    this.thumb = '',
    this.color1 = 0xFF07884B,
    this.color2 = 0xFF04522E,
    this.symbol = 'অনু',
    this.formula = 'HSC & Admission',
    this.bottomLabel = 'অনুশীলন',
  });

  factory SubjectItem.fromMap(Map<dynamic, dynamic> map) {
    final name = (map['name'] ?? 'বিষয়').toString();
    final def = DefaultSyllabusData.defaultSubjects.firstWhere(
      (d) => d['id'] == map['id'] || d['name'] == name,
      orElse: () => const {
        'c1': '0xFF07884B',
        'c2': '0xFF04522E',
        'symbol': 'অনু',
        'formula': 'HSC Study Room',
        'bottomLabel': 'Subject',
      },
    );
    return SubjectItem(
      id: (map['id'] ?? 'subj-${DateTime.now().millisecondsSinceEpoch}').toString(),
      name: name,
      subtitle: (map['subtitle'] ?? def['subtitle'] ?? '').toString(),
      thumb: (map['thumb'] ?? '').toString(),
      color1: int.tryParse(def['c1'] ?? '0xFF07884B') ?? 0xFF07884B,
      color2: int.tryParse(def['c2'] ?? '0xFF04522E') ?? 0xFF04522E,
      symbol: def['symbol'] ?? (name.length >= 2 ? name.substring(0, 2) : 'অনু'),
      formula: def['formula'] ?? 'HSC & Admission',
      bottomLabel: def['bottomLabel'] ?? name,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'subtitle': subtitle,
        'thumb': thumb,
      };
}

class ChapterItem {
  String id;
  String subject;
  String name;
  String thumb;

  ChapterItem({
    required this.id,
    required this.subject,
    required this.name,
    this.thumb = '',
  });

  factory ChapterItem.fromMap(Map<dynamic, dynamic> map) {
    return ChapterItem(
      id: (map['id'] ?? 'chap-${DateTime.now().millisecondsSinceEpoch}').toString(),
      subject: (map['subject'] ?? '').toString(),
      name: (map['name'] ?? 'অধ্যায়').toString(),
      thumb: (map['thumb'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'subject': subject,
        'courseId': '',
        'name': name,
        'thumb': thumb,
      };
}

class OptionItem {
  String label;
  String text;
  String media;

  OptionItem({
    required this.label,
    required this.text,
    this.media = '',
  });

  factory OptionItem.fromDynamic(dynamic raw, int index) {
    final fallbackLabel = index < DefaultSyllabusData.banglaOptionLetters.length
        ? DefaultSyllabusData.banglaOptionLetters[index]
        : '${index + 1}';
    if (raw is String) {
      return OptionItem(label: fallbackLabel, text: raw);
    }
    if (raw is Map) {
      final label = (raw['label'] ?? raw['লেবেল'] ?? fallbackLabel).toString().trim();
      final text = (raw['text'] ?? raw['টেক্সট'] ?? label).toString();
      final media = (raw['svg'] ?? raw['image'] ?? raw['img'] ?? raw['imageUrl'] ?? raw['ছবি'] ?? '').toString().trim();
      return OptionItem(label: label.isEmpty ? fallbackLabel : label, text: text, media: media);
    }
    return OptionItem(label: fallbackLabel, text: raw?.toString() ?? '');
  }

  Map<String, dynamic> toMap() => {
        'label': label,
        'text': text,
        if (media.isNotEmpty) 'image': media,
      };
}

class QuestionItem {
  String id;
  String subject;
  String chapter;
  String sourcePdf;
  String stimulus;
  String svg;
  String question;
  String reference;
  List<OptionItem> options;
  String? answer;
  String explanation;
  String source;
  int createdAt;
  int savedAt;

  QuestionItem({
    required this.id,
    required this.subject,
    required this.chapter,
    required this.sourcePdf,
    this.stimulus = '',
    this.svg = '',
    required this.question,
    this.reference = '',
    required this.options,
    this.answer,
    this.explanation = '',
    this.source = '',
    this.createdAt = 0,
    this.savedAt = 0,
  });

  static String? resolveAnswerLabel(dynamic rawAns, List<OptionItem> opts) {
    if (rawAns == null) return null;
    if (rawAns is num) {
      final idx = rawAns.toInt();
      if (idx >= 0 && idx < opts.length) return opts[idx].label;
      if (idx >= 1 && idx <= opts.length) return opts[idx - 1].label;
    }
    final s = rawAns.toString().trim();
    if (s.isEmpty) return null;
    if (opts.any((o) => o.label.trim() == s)) return s;
    final enInt = int.tryParse(s);
    if (enInt != null) {
      if (enInt >= 0 && enInt < opts.length) return opts[enInt].label;
      if (enInt >= 1 && enInt <= opts.length) return opts[enInt - 1].label;
    }
    const bnDigits = '০১২৩৪৫৬৭৮৯';
    if (RegExp(r'^[০-৯]+$').hasMatch(s)) {
      var converted = '';
      for (var i = 0; i < s.length; i++) {
        final pos = bnDigits.indexOf(s[i]);
        converted += pos >= 0 ? pos.toString() : s[i];
      }
      final idx = int.tryParse(converted);
      if (idx != null) {
        if (idx >= 0 && idx < opts.length) return opts[idx].label;
        if (idx >= 1 && idx <= opts.length) return opts[idx - 1].label;
      }
    }
    const engMap = {'a': 0, 'b': 1, 'c': 2, 'd': 3, 'e': 4, 'f': 5};
    if (s.length == 1 && engMap.containsKey(s.toLowerCase())) {
      final idx = engMap[s.toLowerCase()]!;
      if (idx < opts.length) return opts[idx].label;
      return DefaultSyllabusData.banglaOptionLetters[idx];
    }
    for (final o in opts) {
      if (o.text.trim() == s) return o.label;
    }
    return s;
  }

  static String formatSourceField(dynamic rawSource, Map<dynamic, dynamic> map) {
    var pdf = (map['pdfName'] ?? map['pdf'] ?? map['file'] ?? map['পিডিএফ'] ?? '').toString().trim();
    var page = (map['page'] ?? map['pageNo'] ?? map['পৃষ্ঠা'] ?? '').toString().trim();
    var mcq = (map['questionNo'] ?? map['qNo'] ?? map['mcqNo'] ?? map['mcq'] ?? map['প্রশ্ন নং'] ?? map['এমসিকিউ'] ?? '').toString().trim();

    if (rawSource is Map) {
      pdf = (rawSource['pdf'] ?? rawSource['pdfName'] ?? rawSource['file'] ?? rawSource['পিডিএফ'] ?? pdf).toString().trim();
      page = (rawSource['page'] ?? rawSource['pageNo'] ?? rawSource['পৃষ্ঠা'] ?? page).toString().trim();
      mcq = (rawSource['questionNo'] ?? rawSource['qNo'] ?? rawSource['mcq'] ?? rawSource['mcqNo'] ?? rawSource['প্রশ্ন নং'] ?? rawSource['এমসিকিউ'] ?? mcq).toString().trim();
    } else if (rawSource is String && rawSource.trim().isNotEmpty) {
      final clean = rawSource.trim().replaceFirst(RegExp(r'^(?:সোর্স|source)\s*[:：-]\s*', caseSensitive: false), '');
      if (pdf.isEmpty && page.isEmpty && mcq.isEmpty) {
        return clean;
      }
    }
    final parts = <String>[];
    if (pdf.isNotEmpty) parts.add(pdf);
    if (page.isNotEmpty) parts.add('পৃষ্ঠা $page');
    if (mcq.isNotEmpty) parts.add('প্রশ্ন $mcq');
    return parts.join(' • ');
  }

  factory QuestionItem.fromMap(Map<dynamic, dynamic> map, {int index = 0, String? defaultBank, String? defaultSubj, String? defaultChap}) {
    final rawOpts = map['options'] ?? map['অপশন'];
    final optsList = <OptionItem>[];
    if (rawOpts is List) {
      for (var i = 0; i < rawOpts.length; i++) {
        optsList.add(OptionItem.fromDynamic(rawOpts[i], i));
      }
    } else if (rawOpts is Map) {
      final values = rawOpts.values.toList();
      for (var i = 0; i < values.length; i++) {
        optsList.add(OptionItem.fromDynamic(values[i], i));
      }
    }

    final rawAns = map['answer'] ?? map['ans'] ?? map['উত্তর'];
    final resolvedAns = resolveAnswerLabel(rawAns, optsList);

    return QuestionItem(
      id: (map['id'] ?? 'q-${DateTime.now().millisecondsSinceEpoch}-$index').toString(),
      subject: (defaultSubj ?? map['subject'] ?? 'পদার্থ বিজ্ঞান ১ম পত্র').toString().trim(),
      chapter: (defaultChap ?? map['chapter'] ?? 'সাধারণ').toString().trim(),
      sourcePdf: (defaultBank ?? map['sourcePdf'] ?? 'প্রশ্নব্যাংক').toString().trim(),
      stimulus: (map['stimulus'] ?? map['uddipok'] ?? map['উদ্দীপক'] ?? map['stem'] ?? '').toString().trim(),
      svg: (map['svg'] ?? map['svgImage'] ?? map['imageSvg'] ?? map['image'] ?? map['img'] ?? map['imageUrl'] ?? map['ছবি'] ?? map['চিত্র'] ?? '').toString().trim(),
      question: (map['question'] ?? map['q'] ?? map['প্রশ্ন'] ?? '').toString().trim(),
      reference: (map['reference'] ?? map['ref'] ?? map['board'] ?? map['রেফারেন্স'] ?? '').toString().trim(),
      options: optsList,
      answer: resolvedAns,
      explanation: (map['explanation'] ?? map['exp'] ?? map['ব্যাখ্যা'] ?? map['ব্যাখা'] ?? '').toString().trim(),
      source: formatSourceField(map['source'] ?? map['সোর্স'] ?? map['sourceInfo'], map),
      createdAt: int.tryParse((map['createdAt'] ?? DateTime.now().millisecondsSinceEpoch).toString()) ?? DateTime.now().millisecondsSinceEpoch,
      savedAt: int.tryParse((map['savedAt'] ?? 0).toString()) ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'subject': subject,
        'chapter': chapter,
        'sourcePdf': sourcePdf,
        'stimulus': stimulus,
        'svg': svg,
        'question': question,
        'reference': reference,
        'options': options.map((o) => o.toMap()).toList(),
        'answer': answer,
        'explanation': explanation,
        'source': source,
        'createdAt': createdAt,
        if (savedAt > 0) 'savedAt': savedAt,
      };
}

class CustomExamItem {
  String id;
  String title;
  String createdAt;
  int minutes;
  bool negMarking;
  List<QuestionItem> questions;

  CustomExamItem({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.minutes,
    required this.negMarking,
    required this.questions,
  });

  factory CustomExamItem.fromMap(Map<dynamic, dynamic> map) {
    final rawQs = map['questions'] is List
        ? map['questions'] as List
        : (map['questions'] is Map ? (map['questions'] as Map).values.toList() : const []);
    final qs = <QuestionItem>[];
    for (var i = 0; i < rawQs.length; i++) {
      if (rawQs[i] is Map) {
        qs.add(QuestionItem.fromMap(rawQs[i] as Map, index: i));
      }
    }
    return CustomExamItem(
      id: (map['id'] ?? 'cex-${DateTime.now().millisecondsSinceEpoch}').toString(),
      title: (map['title'] ?? 'পরীক্ষা').toString(),
      createdAt: (map['createdAt'] ?? '').toString(),
      minutes: int.tryParse((map['minutes'] ?? 10).toString()) ?? 10,
      negMarking: map['negMarking'] != false,
      questions: qs,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'createdAt': createdAt,
        'minutes': minutes,
        'negMarking': negMarking,
        'questions': questions.map((q) => q.toMap()).toList(),
      };
}

class ExamResultItem {
  String id;
  String title;
  String date;
  int correct;
  int wrong;
  int skip;
  int gradable;
  int total;
  int accuracy;
  int elapsedMin;
  String scoreFormatted;
  bool negMarking;
  List<String> wrongIds;
  List<QuestionItem> questions;
  Map<String, String> answers;
  int savedAt;

  ExamResultItem({
    required this.id,
    required this.title,
    required this.date,
    required this.correct,
    required this.wrong,
    required this.skip,
    required this.gradable,
    required this.total,
    required this.accuracy,
    required this.elapsedMin,
    required this.scoreFormatted,
    this.negMarking = true,
    required this.wrongIds,
    required this.questions,
    required this.answers,
    this.savedAt = 0,
  });

  factory ExamResultItem.fromMap(Map<dynamic, dynamic> map) {
    final rawQs = map['questions'] is List
        ? map['questions'] as List
        : (map['questions'] is Map ? (map['questions'] as Map).values.toList() : const []);
    final qs = <QuestionItem>[];
    for (var i = 0; i < rawQs.length; i++) {
      if (rawQs[i] is Map) {
        qs.add(QuestionItem.fromMap(rawQs[i] as Map, index: i));
      }
    }
    final ansMap = <String, String>{};
    if (map['answers'] is Map) {
      (map['answers'] as Map).forEach((k, v) {
        if (v != null) ansMap[k.toString()] = v.toString();
      });
    }
    final wIds = <String>[];
    if (map['wrongIds'] is List) {
      for (final x in (map['wrongIds'] as List)) {
        if (x != null) wIds.add(x.toString());
      }
    }
    final correct = int.tryParse((map['correct'] ?? 0).toString()) ?? 0;
    final wrong = int.tryParse((map['wrong'] ?? wIds.length).toString()) ?? 0;
    final skip = int.tryParse((map['skip'] ?? 0).toString()) ?? 0;
    final total = int.tryParse((map['total'] ?? qs.length).toString()) ?? qs.length;
    final gradable = int.tryParse((map['gradable'] ?? total).toString()) ?? total;
    final accuracy = int.tryParse((map['accuracy'] ?? 0).toString()) ?? 0;

    return ExamResultItem(
      id: (map['id'] ?? 'res-${DateTime.now().millisecondsSinceEpoch}').toString(),
      title: (map['title'] ?? 'পরীক্ষা').toString(),
      date: (map['submittedAt'] ?? map['date'] ?? '').toString(),
      correct: correct,
      wrong: wrong,
      skip: skip,
      gradable: gradable,
      total: total,
      accuracy: accuracy,
      elapsedMin: int.tryParse((map['elapsedMin'] ?? 1).toString()) ?? 1,
      scoreFormatted: (map['scoreFormatted'] ?? correct.toString()).toString(),
      negMarking: map['negMarking'] != false,
      wrongIds: wIds,
      questions: qs,
      answers: ansMap,
      savedAt: int.tryParse((map['savedAt'] ?? 0).toString()) ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'date': date,
        'submittedAt': date,
        'correct': correct,
        'wrong': wrong,
        'skip': skip,
        'gradable': gradable,
        'total': total,
        'accuracy': accuracy,
        'elapsedMin': elapsedMin,
        'scoreFormatted': scoreFormatted,
        'negMarking': negMarking,
        'wrongIds': wrongIds,
        'questions': questions.map((q) => q.toMap()).toList(),
        'answers': answers,
        if (savedAt > 0) 'savedAt': savedAt,
      };
}
