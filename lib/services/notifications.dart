import 'dart:io';
import 'dart:typed_data';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/event.dart';
import '../utils.dart';

/// What a tapped / launched notification refers to.
typedef ReminderRef = ({String eventId, int notifId, AlertStyle style});

/// Required (even if empty) so the "Dismiss" button works without opening the app.
/// The button itself cancels the notification natively (cancelNotification: true).
@pragma('vm:entry-point')
void annuaBackgroundNotificationResponse(NotificationResponse r) {}

/// All reminder scheduling and presentation lives here.
///
/// Delivery rules (why reminders fire on time):
///  * every reminder is an exact alarm (`exactAllowWhileIdle`) – works in Doze, no status-bar icon;
///  * USE_EXACT_ALARM is declared, so Android 13+ grants exact alarms automatically;
///  * the app asks to be exempt from battery optimisation (Settings → "Run in background");
///  * the alarm style opens a full-screen reminder over the lock screen and wakes the display.
class Notifications {
  final _p = FlutterLocalNotificationsPlugin();

  /// Resolves an event's photo file (used as the notification's large icon).
  String? Function(AnnuaEvent e)? photoResolver;

  /// Set when the app was cold-started by tapping / full-screen-launching a reminder.
  ReminderRef? launch;

  static const _brand = Color(0xFFB8935A);
  static const _packageName = 'com.zeroex.annua';

  /// Sound choice per slot: 'notif', 'birthday' (alarm) and 'event' (alarm).
  /// Value: 'app' (bundled), 'system' (phone default) or a content:// uri.
  Map<String, String> sounds = {};
  static const _raw = {'notif': 'annua_notification', 'birthday': 'annua_birthday_alarm', 'event': 'annua_event_alarm'};
  static const _soundChannel = MethodChannel('annua/sound');
  final Set<String> _known = {};

  String _soundValue(String slot) => sounds[slot] ?? 'app';

  AndroidNotificationSound? _soundFor(String slot) {
    final v = _soundValue(slot);
    if (v == 'app') return RawResourceAndroidNotificationSound(_raw[slot]);
    if (v == 'system') return slot == 'notif' ? null : const UriAndroidNotificationSound('content://settings/system/alarm_alert');
    return UriAndroidNotificationSound(v);
  }

  // A channel's sound can't change once created, so the sound is part of the channel id.
  String _soundKey(String slot) {
    final v = _soundValue(slot);
    return v == 'app' ? 'app' : v == 'system' ? 'sys' : v.hashCode.toUnsigned(32).toRadixString(16);
  }

  Future<({String uri, String name})?> pickSound(String slot, String current, String title) async {
    try {
      final r = await _soundChannel.invokeMethod<Map>('pick', {
        'type': slot == 'notif' ? 2 : 4,
        'current': current.startsWith('content') ? current : '',
        'title': title,
      });
      if (r == null) return null;
      return (uri: (r['uri'] as String?) ?? '', name: (r['name'] as String?) ?? 'Custom');
    } catch (_) {
      return null;
    }
  }

  Future<void> previewSound(String slot, String value) async {
    try {
      await _soundChannel.invokeMethod('preview', {
        'raw': value == 'app' ? _raw[slot] : null,
        'uri': value == 'app' ? null : (value == 'system' ? (slot == 'notif' ? 'default_notification' : 'default_alarm') : value),
      });
    } catch (_) {}
  }

  Future<void> stopPreview() async {
    try {
      await _soundChannel.invokeMethod('stop');
    } catch (_) {}
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<void> init(void Function(ReminderRef ref) onOpen) async {
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
    } catch (_) {}
    await _p.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_annua'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) {
        if (r.actionId == 'dismiss') return;
        final ref = _parse(r.payload);
        if (ref != null) onOpen(ref);
      },
      onDidReceiveBackgroundNotificationResponse: annuaBackgroundNotificationResponse,
    );
    final d = await _p.getNotificationAppLaunchDetails();
    if (d?.didNotificationLaunchApp ?? false) {
      final r = d!.notificationResponse;
      if (r != null && r.actionId != 'dismiss') launch = _parse(r.payload);
    }
  }

  String _payload(AnnuaEvent e, Reminder r) => '${e.id}|${r.notifId}|${r.style.name}';

  ReminderRef? _parse(String? p) {
    if (p == null) return null;
    final parts = p.split('|');
    if (parts.length < 3) return null;
    final style = AlertStyle.values.where((s) => s.name == parts[2]);
    return (eventId: parts[0], notifId: int.tryParse(parts[1]) ?? 0, style: style.isEmpty ? AlertStyle.popup : style.first);
  }

  // ---------- Permissions ----------

  Future<bool> requestPermissions() async {
    final a = _android;
    final i = _p.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    var ok = true;
    if (a != null) {
      ok = await a.requestNotificationsPermission() ?? false;
      try {
        await a.requestExactAlarmsPermission();
      } catch (_) {}
    }
    if (i != null) ok = await i.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    return ok;
  }

  /// Lets reminders light up the screen over the lock screen (needs a grant on Android 14+).
  Future<void> requestFullScreen() async {
    try {
      await _android?.requestFullScreenIntentPermission();
    } catch (_) {}
  }

  /// Whether the two permissions reminders depend on are currently granted.
  Future<({bool notifications, bool exact})> health() async {
    final a = _android;
    if (a == null) return (notifications: true, exact: true);
    var n = false, e = false;
    try {
      n = await a.areNotificationsEnabled() ?? false;
    } catch (_) {}
    try {
      e = await a.canScheduleExactNotifications() ?? false;
    } catch (_) {}
    return (notifications: n, exact: e);
  }

  /// Schedules a real test through the same path as normal reminders, so the user can lock
  /// the phone and check that it arrives on time.
  Future<void> scheduleTest(AlertStyle s, {int seconds = 60}) async {
    final when = tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));
    final d = _details(s, title: 'Annua', body: 'Delivered on time — your reminders are working.');
    Future<void> go(AndroidScheduleMode m) =>
        _p.zonedSchedule(999998, 'Annua', 'Delivered on time — your reminders are working.', when, d, androidScheduleMode: m);
    try {
      await go(AndroidScheduleMode.exactAllowWhileIdle);
    } catch (_) {
      try {
        await go(AndroidScheduleMode.inexactAllowWhileIdle);
      } catch (_) {}
    }
  }

  /// Asks Android not to delay Annua's alarms (battery optimisation / Doze).
  Future<void> requestBackgroundAccess() async {
    if (!Platform.isAndroid) return;
    try {
      await const AndroidIntent(
        action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
        data: 'package:$_packageName',
      ).launch();
    } catch (_) {
      try {
        await const AndroidIntent(action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS').launch();
      } catch (_) {}
    }
  }

  // ---------- Presentation ----------

  NotificationDetails _details(AlertStyle s, {required String title, required String body, String? photo, EventType type = EventType.birthday}) {
    final vib = Int64List.fromList([0, 500, 250, 500, 250, 800]);
    final style = BigTextStyleInformation(body, contentTitle: title);
    final large = (photo != null && File(photo).existsSync()) ? FilePathAndroidBitmap(photo) : null;
    final AndroidNotificationDetails android;
    if (s == AlertStyle.alarm) {
      final slot = type == EventType.birthday ? 'birthday' : 'event';
      final id = 'annua_a3_${slot}_${_soundKey(slot)}';
      _known.add(id);
      android = AndroidNotificationDetails(
          id, slot == 'birthday' ? 'Birthday alarms' : 'Event alarms',
          channelDescription: 'Loud, persistent alarms',
          importance: Importance.max, priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          sound: _soundFor(slot),
          fullScreenIntent: true, autoCancel: false,
          enableVibration: true, vibrationPattern: vib,
          additionalFlags: Int32List.fromList(<int>[4]) /* FLAG_INSISTENT: repeat until dismissed */,
          color: _brand, largeIcon: large, styleInformation: style,
          actions: const [
            AndroidNotificationAction('dismiss', 'Dismiss', cancelNotification: true, showsUserInterface: false),
          ]);
    } else {
      // Notification: sound + vibration, heads-up, and it lights the screen when the phone is locked.
      final id = 'annua_n3_${_soundKey('notif')}';
      _known.add(id);
      android = AndroidNotificationDetails(
          id, 'Notifications',
          channelDescription: 'Birthday and event reminders',
          importance: Importance.max, priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.public,
          sound: _soundFor('notif'),
          playSound: true, enableVibration: true, vibrationPattern: vib,
          fullScreenIntent: true,
          color: _brand, largeIcon: large, styleInformation: style);
    }
    return NotificationDetails(
      android: android,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        interruptionLevel: s == AlertStyle.alarm ? InterruptionLevel.timeSensitive : InterruptionLevel.active,
      ),
    );
  }

  String _title(AnnuaEvent e) => switch (e.type) {
        EventType.birthday => "${e.name}'s birthday",
        EventType.anniversary => "${e.name}'s anniversary",
        EventType.other => '${e.name} · ${e.title}',
      };

  // Repeating notifications reuse their text every year, so nothing year-specific (like an age) goes here.
  String _body(Reminder r, DateTime occ) {
    final when = r.daysBefore == 0
        ? 'Today'
        : r.daysBefore == 1
            ? 'Tomorrow'
            : 'In ${r.daysBefore} days';
    return '$when · ${fmtDate(occ, year: false)}';
  }

  // ---------- Scheduling ----------

  ({DateTime occ, tz.TZDateTime fire}) _fire(AnnuaEvent e, Reminder r) {
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime at(DateTime o) {
      final d = o.subtract(Duration(days: r.daysBefore));
      return tz.TZDateTime(tz.local, d.year, d.month, d.day, r.hour, r.minute);
    }

    var occ = e.occurrenceOnOrAfter(DateTime(now.year, now.month, now.day));
    var t = at(occ);
    if (!t.isAfter(now)) {
      occ = e.occurrenceOnOrAfter(occ.add(const Duration(days: 1)));
      t = at(occ);
    }
    return (occ: occ, fire: t);
  }

  Future<void> _scheduleOne(AnnuaEvent e, Reminder r) async {
    final f = _fire(e, r);
    final photo = photoResolver?.call(e);
    final repeat = e.recurrence == Recurrence.yearly ? DateTimeComponents.dateAndTime : DateTimeComponents.dayOfMonthAndTime;
    Future<void> go(AndroidScheduleMode mode) => _p.zonedSchedule(
          r.notifId, _title(e), _body(r, f.occ), f.fire,
          _details(r.style, title: _title(e), body: _body(r, f.occ), photo: photo, type: e.type),
          androidScheduleMode: mode, payload: _payload(e, r), matchDateTimeComponents: repeat);
    try {
      await go(AndroidScheduleMode.exactAllowWhileIdle);
    } catch (_) {
      try {
        await go(AndroidScheduleMode.inexactAllowWhileIdle);
      } catch (_) {}
    }
  }

  Future<void> scheduleEvent(AnnuaEvent e) async {
    for (final r in e.reminders) {
      await _scheduleOne(e, r);
    }
  }

  Future<void> cancelEvent(AnnuaEvent e) async {
    for (final r in e.reminders) {
      await _p.cancel(r.notifId);
    }
  }

  Future<void> rescheduleAll(List<AnnuaEvent> events) async {
    await _p.cancelAll();
    _known.clear();
    for (final e in events) {
      await scheduleEvent(e);
    }
    // Drop channels from older versions / previous sound choices.
    try {
      final list = await _android?.getNotificationChannels() ?? [];
      for (final c in list) {
        if (c.id.startsWith('annua_') && !_known.contains(c.id)) await _android?.deleteNotificationChannel(c.id);
      }
    } catch (_) {}
  }

  /// Stops a ringing / shown reminder. Cancelling by id also drops the yearly schedule, so re-arm it.
  Future<void> dismiss(AnnuaEvent e, Reminder r) async {
    await _p.cancel(r.notifId);
    await _scheduleOne(e, r);
  }

  Future<void> showTest(AlertStyle s, {EventType type = EventType.birthday}) => _p.show(
        999999,
        'Annua',
        'This is how your ${s == AlertStyle.alarm ? 'alarm' : 'notification'} will look.',
        _details(s, title: 'Annua', body: 'This is how your ${s == AlertStyle.alarm ? 'alarm' : 'notification'} will look.', type: type),
      );
}
