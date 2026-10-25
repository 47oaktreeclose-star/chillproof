import 'temperature.dart';

class BusinessProfile {
  final String businessName;
  final String email;
  final String phone;
  final String companyNumber; // optional, may be empty

  const BusinessProfile({
    required this.businessName,
    required this.email,
    required this.phone,
    this.companyNumber = '',
  });

  Map<String, dynamic> toJson() => {
        'businessName': businessName,
        'email': email,
        'phone': phone,
        'companyNumber': companyNumber,
      };

  factory BusinessProfile.fromJson(Map<String, dynamic> j) => BusinessProfile(
        businessName: j['businessName'] as String? ?? '',
        email: j['email'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        companyNumber: j['companyNumber'] as String? ?? '',
      );
}

class StorageUnit {
  final int? id;
  final UnitType type;
  final String name;
  final int position;

  const StorageUnit({this.id, required this.type, required this.name, this.position = 0});

  StorageUnit copyWith({int? id, String? name, int? position}) => StorageUnit(
        id: id ?? this.id,
        type: type,
        name: name ?? this.name,
        position: position ?? this.position,
      );

  Map<String, Object?> toRow() => {
        if (id != null) 'id': id,
        'type': type.key,
        'name': name,
        'position': position,
        'archived': 0,
      };

  factory StorageUnit.fromRow(Map<String, Object?> r) => StorageUnit(
        id: r['id'] as int,
        type: UnitTypeX.fromKey(r['type'] as String),
        name: r['name'] as String,
        position: (r['position'] as int?) ?? 0,
      );
}

class Reading {
  final int unitId;
  final String unitName;
  final UnitType unitType;
  final double tempC;
  final TempStatus status;
  final String action; // corrective action, empty when OK

  const Reading({
    required this.unitId,
    required this.unitName,
    required this.unitType,
    required this.tempC,
    required this.status,
    this.action = '',
  });

  Map<String, Object?> toRow(int sessionId) => {
        'session_id': sessionId,
        'unit_id': unitId,
        'unit_name': unitName,
        'unit_type': unitType.key,
        'temp_c': tempC,
        'status': status.key,
        'action': action,
      };

  factory Reading.fromRow(Map<String, Object?> r) => Reading(
        unitId: r['unit_id'] as int,
        unitName: r['unit_name'] as String,
        unitType: UnitTypeX.fromKey(r['unit_type'] as String),
        tempC: (r['temp_c'] as num).toDouble(),
        status: TempStatusX.fromKey(r['status'] as String?),
        action: (r['action'] as String?) ?? '',
      );
}

class CheckSession {
  final int? id;
  final DateTime takenAt;
  final String checkedBy;
  final List<Reading> readings;

  const CheckSession({
    this.id,
    required this.takenAt,
    this.checkedBy = '',
    this.readings = const [],
  });

  TempStatus get status => worst(readings.map((r) => r.status));
  int get issues => readings.where((r) => r.status != TempStatus.ok).length;
}

/// A daily reminder time (24-hour clock).
class ReminderTime implements Comparable<ReminderTime> {
  final int hour;
  final int minute;
  const ReminderTime(this.hour, this.minute);

  String get key => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  static ReminderTime parse(String s) {
    final p = s.split(':');
    return ReminderTime(int.parse(p[0]), int.parse(p[1]));
  }

  String get label => key;

  @override
  int compareTo(ReminderTime o) => (hour * 60 + minute) - (o.hour * 60 + o.minute);

  @override
  bool operator ==(Object other) => other is ReminderTime && other.key == key;
  @override
  int get hashCode => key.hashCode;

  /// Sensible default times for a given number of checks per day.
  static List<ReminderTime> defaultsFor(int count) {
    switch (count) {
      case 1:
        return const [ReminderTime(9, 0)];
      case 2:
        return const [ReminderTime(9, 0), ReminderTime(17, 0)];
      case 3:
        return const [ReminderTime(8, 0), ReminderTime(13, 0), ReminderTime(18, 0)];
      case 4:
        return const [ReminderTime(8, 0), ReminderTime(12, 0), ReminderTime(16, 0), ReminderTime(20, 0)];
      default:
        // Spread evenly between 07:00 and 22:00.
        final out = <ReminderTime>[];
        final span = 15 * 60;
        for (var i = 0; i < count; i++) {
          final m = 7 * 60 + (span * i / (count - 1)).round();
          out.add(ReminderTime(m ~/ 60, (m % 60) - (m % 60) % 5));
        }
        return out;
    }
  }
}

enum ReminderStyle { notification, alarm }

class AppSettings {
  final TempScale scale;
  final List<ReminderTime> times;
  final bool remindersOn;
  final ReminderStyle style;
  final bool scheduleConfigured;

  const AppSettings({
    this.scale = TempScale.celsius,
    this.times = const [ReminderTime(9, 0), ReminderTime(17, 0)],
    this.remindersOn = true,
    this.style = ReminderStyle.notification,
    this.scheduleConfigured = false,
  });

  int get checksPerDay => times.length;

  AppSettings copyWith({
    TempScale? scale,
    List<ReminderTime>? times,
    bool? remindersOn,
    ReminderStyle? style,
    bool? scheduleConfigured,
  }) =>
      AppSettings(
        scale: scale ?? this.scale,
        times: times ?? this.times,
        remindersOn: remindersOn ?? this.remindersOn,
        style: style ?? this.style,
        scheduleConfigured: scheduleConfigured ?? this.scheduleConfigured,
      );

  Map<String, dynamic> toJson() => {
        'scale': scale.key,
        'times': times.map((t) => t.key).toList(),
        'remindersOn': remindersOn,
        'style': style.name,
        'scheduleConfigured': scheduleConfigured,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    final times = <ReminderTime>[
      ...((j['times'] as List?)?.map((e) => ReminderTime.parse(e as String)) ??
          const [ReminderTime(9, 0), ReminderTime(17, 0)]),
    ]..sort();
    return AppSettings(
      scale: TempScaleX.fromKey(j['scale'] as String?),
      times: times,
      remindersOn: j['remindersOn'] as bool? ?? true,
      style: j['style'] == 'alarm' ? ReminderStyle.alarm : ReminderStyle.notification,
      scheduleConfigured: j['scheduleConfigured'] as bool? ?? false,
    );
  }
}
