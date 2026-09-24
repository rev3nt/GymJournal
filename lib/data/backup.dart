import 'dart:convert';

import '../domain/models.dart';

const backupFormatVersion = 1;
const backupAppId = 'lift_log';

class BackupData {
  const BackupData({
    required this.templates,
    required this.workouts,
    this.exportedAt,
    this.version = backupFormatVersion,
  });

  final List<WorkoutTemplate> templates;
  final List<WorkoutSession> workouts;
  final DateTime? exportedAt;
  final int version;
}

class BackupCodec {
  const BackupCodec();

  String encode(BackupData data) {
    final map = <String, dynamic>{
      'version': data.version,
      'app': backupAppId,
      'exportedAt': (data.exportedAt ?? DateTime.now().toUtc()).toIso8601String(),
      'templates': data.templates.map(_templateToJson).toList(),
      'workouts': data.workouts.map(_sessionToJson).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  BackupData decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Файл не похож на резервную копию Lift Log');
    }
    final map = Map<String, dynamic>.from(decoded);
    final app = map['app'];
    if (app != null && app != backupAppId) {
      throw const FormatException('Это не резервная копия Lift Log');
    }
    final version = map['version'];
    if (version is! int || version < 1 || version > backupFormatVersion) {
      throw const FormatException('Неподдерживаемая версия резервной копии');
    }

    final templatesRaw = map['templates'];
    final workoutsRaw = map['workouts'];
    if (templatesRaw is! List || workoutsRaw is! List) {
      throw const FormatException('В файле нет шаблонов или тренировок');
    }

    final templates = templatesRaw.map((e) {
      if (e is! Map) throw const FormatException('Повреждён шаблон в файле');
      return _templateFromJson(Map<String, dynamic>.from(e));
    }).toList();

    final workouts = workoutsRaw.map((e) {
      if (e is! Map) throw const FormatException('Повреждена тренировка в файле');
      return _sessionFromJson(Map<String, dynamic>.from(e));
    }).toList();

    final activeCount = workouts.where((w) => w.finishedAt == null).length;
    if (activeCount > 1) {
      throw const FormatException('В копии больше одной активной тренировки');
    }

    return BackupData(
      version: version,
      exportedAt: _parseDate(map['exportedAt']),
      templates: templates,
      workouts: workouts,
    );
  }

  Map<String, dynamic> _templateToJson(WorkoutTemplate tpl) => {
        'id': tpl.id,
        'name': tpl.name,
        'exercises': tpl.exercises
            .map((e) => {
                  'id': e.id,
                  'name': e.name,
                  'targetSets': e.targetSets,
                })
            .toList(),
      };

  WorkoutTemplate _templateFromJson(Map<String, dynamic> json) {
    final exercisesRaw = json['exercises'];
    if (exercisesRaw is! List) {
      throw const FormatException('У шаблона нет списка упражнений');
    }
    return WorkoutTemplate(
      id: _reqString(json, 'id'),
      name: _reqString(json, 'name'),
      exercises: exercisesRaw.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return TemplateExercise(
          id: _reqString(m, 'id'),
          name: _reqString(m, 'name'),
          targetSets: _asInt(m['targetSets'], fallback: 4),
        );
      }).toList(),
    );
  }

  Map<String, dynamic> _sessionToJson(WorkoutSession session) => {
        'id': session.id,
        'name': session.name,
        'startedAt': session.startedAt.toIso8601String(),
        'finishedAt': session.finishedAt?.toIso8601String(),
        'tonnage': session.tonnage,
        'exercises': session.exercises.map(_exerciseToJson).toList(),
      };

  Map<String, dynamic> _exerciseToJson(WorkoutExercise ex) => {
        'id': ex.id,
        'name': ex.name,
        'targetSets': ex.targetSets,
        'volume': ex.volume,
        'best1rm': ex.best1rm,
        'sets': ex.sets.map(_approachToJson).toList(),
      };

  Map<String, dynamic> _approachToJson(Approach set) => {
        'id': set.id,
        'at': set.at.toIso8601String(),
        'legs': set.legs
            .map((leg) => {
                  'id': leg.id,
                  'weight': leg.weight,
                  'reps': leg.reps,
                  'type': leg.type.name,
                  'at': leg.at.toIso8601String(),
                })
            .toList(),
      };

  WorkoutSession _sessionFromJson(Map<String, dynamic> json) {
    final exercisesRaw = json['exercises'];
    if (exercisesRaw is! List) {
      throw const FormatException('У тренировки нет списка упражнений');
    }
    final startedAt = _parseDate(json['startedAt']);
    if (startedAt == null) {
      throw const FormatException('У тренировки нет даты начала');
    }
    return WorkoutSession(
      id: _reqString(json, 'id'),
      name: _reqString(json, 'name'),
      startedAt: startedAt,
      finishedAt: _parseDate(json['finishedAt']),
      tonnage: _asDouble(json['tonnage']),
      exercises: exercisesRaw.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return _exerciseFromJson(m);
      }).toList(),
    );
  }

  WorkoutExercise _exerciseFromJson(Map<String, dynamic> json) {
    final setsRaw = json['sets'];
    if (setsRaw is! List) {
      throw const FormatException('У упражнения нет подходов');
    }
    return WorkoutExercise(
      id: _reqString(json, 'id'),
      name: _reqString(json, 'name'),
      targetSets: _asInt(json['targetSets'], fallback: 4),
      volume: _asDouble(json['volume']),
      best1rm: _asDouble(json['best1rm']),
      sets: setsRaw.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return _approachFromJson(m);
      }).toList(),
    );
  }

  Approach _approachFromJson(Map<String, dynamic> json) {
    final legsRaw = json['legs'];
    if (legsRaw is! List) {
      throw const FormatException('У подхода нет частей');
    }
    final at = _parseDate(json['at']) ?? DateTime.now();
    return Approach(
      id: _reqString(json, 'id'),
      at: at,
      legs: legsRaw.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        final legAt = _parseDate(m['at']) ?? at;
        return SetLeg(
          id: _reqString(m, 'id'),
          weight: _asDouble(m['weight']),
          reps: _asInt(m['reps']),
          type: SetType.fromName(m['type'] as String?),
          at: legAt,
        );
      }).toList(),
    );
  }

  String _reqString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('В файле нет поля "$key"');
    }
    return value;
  }

  int _asInt(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  double _asDouble(Object? value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }
}
