import 'dart:math';

enum EventType { birthday, anniversary, other }
enum Recurrence { yearly, monthly }
enum AlertStyle { popup, vibrate, alarm }

class Reminder {
  int notifId;
  int daysBefore;
  int hour;
  int minute;
  AlertStyle style;

  Reminder({int? notifId, this.daysBefore = 0, this.hour = 9, this.minute = 0, this.style = AlertStyle.popup})
      : notifId = notifId ?? Random().nextInt(0x7FFFFFFF);

  Reminder copy() => Reminder(notifId: notifId, daysBefore: daysBefore, hour: hour, minute: minute, style: style);

  Map<String, dynamic> toJson() => {
        'notifId': notifId,
        'daysBefore': daysBefore,
        'hour': hour,
        'minute': minute,
        'style': style.name,
      };

  factory Reminder.fromJson(Map<String, dynamic> j) => Reminder(
        notifId: j['notifId'] as int?,
        daysBefore: j['daysBefore'] as int? ?? 0,
        hour: j['hour'] as int? ?? 9,
        minute: j['minute'] as int? ?? 0,
        style: switch (j['style'] as String?) {
          'alarm' => AlertStyle.alarm,
          _ => AlertStyle.popup, // old "vibrate" is now part of the notification
        },
      );
}

/// One contact / social entry (a person can have several of the same kind).
class LinkItem {
  final String key, value;
  const LinkItem(this.key, this.value);
  Map<String, String> toJson() => {'k': key, 'v': value};
}

class AnnuaEvent {
  final String id;
  String name;
  EventType type;
  String customTitle;
  DateTime date;
  bool yearKnown;
  Recurrence recurrence;
  String relationship;
  String category;
  String location;
  List<LinkItem> links;
  String notes;
  String? photo; // file name inside the app's photos folder
  List<Reminder> reminders;

  AnnuaEvent({
    required this.id,
    required this.name,
    required this.date,
    this.type = EventType.birthday,
    this.customTitle = '',
    this.yearKnown = true,
    this.recurrence = Recurrence.yearly,
    this.relationship = '',
    this.category = '',
    this.location = '',
    List<LinkItem>? links,
    this.notes = '',
    this.photo,
    List<Reminder>? reminders,
  })  : links = links ?? [],
        reminders = reminders ?? [];

  List<String> valuesOf(String key) => [for (final l in links) if (l.key == key && l.value.isNotEmpty) l.value];
  String get phone => valuesOf('phone').isEmpty ? '' : valuesOf('phone').first;
  String get whatsapp => valuesOf('whatsapp').isEmpty ? '' : valuesOf('whatsapp').first;

  /// First value per platform (kept in the saved file for older app versions).
  Map<String, String> get social {
    final m = <String, String>{};
    for (final l in links) {
      if (l.key != 'phone' && l.key != 'whatsapp' && l.value.isNotEmpty) m.putIfAbsent(l.key, () => l.value);
    }
    return m;
  }

  String get title => switch (type) {
        EventType.birthday => 'Birthday',
        EventType.anniversary => 'Anniversary',
        EventType.other => customTitle.trim().isEmpty ? 'Event' : customTitle.trim(),
      };

  static DateTime _clamp(int y, int m, int d) {
    final ny = y + (m - 1) ~/ 12;
    final nm = (m - 1) % 12 + 1;
    final last = DateTime(ny, nm + 1, 0).day;
    return DateTime(ny, nm, min(d, last));
  }

  /// First occurrence on or after [from] (date only).
  DateTime occurrenceOnOrAfter(DateTime from) {
    final d = DateTime(from.year, from.month, from.day);
    if (recurrence == Recurrence.monthly) {
      var c = _clamp(d.year, d.month, date.day);
      if (c.isBefore(d)) c = _clamp(d.year, d.month + 1, date.day);
      return c;
    }
    var c = _clamp(d.year, date.month, date.day);
    if (c.isBefore(d)) c = _clamp(d.year + 1, date.month, date.day);
    return c;
  }

  /// Whether this event falls on [day] (used by the calendar).
  bool occursOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    if (yearKnown && d.isBefore(DateTime(date.year, date.month, date.day))) return false;
    final c = recurrence == Recurrence.monthly ? _clamp(d.year, d.month, date.day) : _clamp(d.year, date.month, date.day);
    return c == d;
  }

  /// Subtitle for a specific occurrence date, e.g. "Birthday · Turning 21".
  String subtitleOn(DateTime day) {
    if (!yearKnown || recurrence != Recurrence.yearly) return title;
    final n = day.year - date.year;
    if (n <= 0) return title;
    final now = DateTime.now();
    final past = DateTime(day.year, day.month, day.day).isBefore(DateTime(now.year, now.month, now.day));
    return type == EventType.birthday ? '$title · ${past ? 'Turned' : 'Turning'} $n' : '$title · $n years';
  }

  DateTime get next => occurrenceOnOrAfter(DateTime.now());

  int daysUntil() {
    final now = DateTime.now();
    final a = DateTime.utc(now.year, now.month, now.day);
    final n = next;
    return DateTime.utc(n.year, n.month, n.day).difference(a).inDays;
  }

  /// Age / years for the upcoming occurrence (yearly events with a known year).
  int? get turning => (yearKnown && recurrence == Recurrence.yearly) ? next.year - date.year : null;

  String get subtitle {
    final t = turning;
    if (t == null || t <= 0) return title;
    return type == EventType.birthday ? '$title · Turning $t' : '$title · $t years';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'customTitle': customTitle,
        'date': date.toIso8601String(),
        'yearKnown': yearKnown,
        'recurrence': recurrence.name,
        'relationship': relationship,
        'category': category,
        'location': location,
        'phone': phone,
        'whatsapp': whatsapp,
        'social': social,
        'links': links.map((l) => l.toJson()).toList(),
        'notes': notes,
        'photo': photo,
        'reminders': reminders.map((r) => r.toJson()).toList(),
      };

  factory AnnuaEvent.fromJson(Map<String, dynamic> j) => AnnuaEvent(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        type: EventType.values.byName(j['type'] as String? ?? 'birthday'),
        customTitle: j['customTitle'] as String? ?? '',
        date: DateTime.parse(j['date'] as String),
        yearKnown: j['yearKnown'] as bool? ?? true,
        recurrence: Recurrence.values.byName(j['recurrence'] as String? ?? 'yearly'),
        relationship: j['relationship'] as String? ?? '',
        category: j['category'] as String? ?? '',
        location: j['location'] as String? ?? '',
        links: _linksFromJson(j),
        notes: j['notes'] as String? ?? '',
        photo: j['photo'] as String?,
        reminders: ((j['reminders'] as List?) ?? []).map((e) => Reminder.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      );
}

List<LinkItem> _linksFromJson(Map<String, dynamic> j) {
  final raw = j['links'];
  if (raw is List) {
    return [
      for (final e in raw)
        if (e is Map && (e['v'] as String? ?? '').isNotEmpty) LinkItem(e['k'] as String? ?? 'other', e['v'] as String),
    ];
  }
  // files saved by older versions: one phone, one WhatsApp and one value per platform
  return [
    if ((j['phone'] as String? ?? '').isNotEmpty) LinkItem('phone', j['phone'] as String),
    if ((j['whatsapp'] as String? ?? '').isNotEmpty) LinkItem('whatsapp', j['whatsapp'] as String),
    for (final e in Map<String, dynamic>.from((j['social'] as Map?) ?? {}).entries)
      if ((e.value as String? ?? '').isNotEmpty) LinkItem(e.key, e.value as String),
  ];
}
