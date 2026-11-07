import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event.dart';
import '../screens/event_detail_screen.dart';
import '../services/backup.dart';
import '../services/notifications.dart';
import '../screens/reminder_screen.dart';
import '../services/storage.dart';
import '../utils.dart';

class AppState extends ChangeNotifier {
  final storage = Storage();
  late final BackupService backup;
  final notifications = Notifications();
  late SharedPreferences _prefs;

  List<AnnuaEvent> events = [];
  ThemeMode themeMode = ThemeMode.light;
  int accent = 0xFFF59E0B;
  bool useDynamic = false;
  bool pureBlack = false;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await storage.init();
    backup = BackupService(storage);
    themeMode = ThemeMode.values[_prefs.getInt('themeMode') ?? ThemeMode.light.index];
    accent = _prefs.getInt('accent') ?? accent;
    useDynamic = _prefs.getBool('useDynamic') ?? false;
    pureBlack = _prefs.getBool('pureBlack') ?? false;
    events = await storage.load();
    notifications.photoResolver = (e) => e.photo == null ? null : storage.photoPath(e.photo!);
    _syncSounds();
    await notifications.init(openReminder);
    pendingLaunch = notifications.launch;
    await notifications.rescheduleAll(events);
  }

  /// Runs at every start: asks for whatever reminders still need (notifications, exact alarms);
  /// the lock-screen and battery prompts are shown once.
  Future<void> askStartupPermissions() async {
    final h = await notifications.health();
    if (!h.notifications || !h.exact) await notifications.requestPermissions();
    if (!(_prefs.getBool('permsAsked') ?? false)) {
      await _prefs.setBool('permsAsked', true);
      await notifications.requestFullScreen();
      await notifications.requestBackgroundAccess();
    }
    await notifications.rescheduleAll(events);
  }

  // ---------- Sounds ----------
  static const soundSlots = ['notif', 'birthday', 'event'];
  String soundValue(String slot) => _prefs.getString('snd_$slot') ?? 'app';
  String soundLabel(String slot) {
    final v = soundValue(slot);
    return v == 'app' ? 'Annua default' : v == 'system' ? 'System default' : (_prefs.getString('sndn_$slot') ?? 'Custom');
  }

  void _syncSounds() => notifications.sounds = {for (final k in soundSlots) k: soundValue(k)};

  Future<void> setSound(String slot, String value, {String name = ''}) async {
    await _prefs.setString('snd_$slot', value);
    await _prefs.setString('sndn_$slot', name);
    _syncSounds();
    notifyListeners();
    await notifications.rescheduleAll(events);
  }

  /// Set when the app was started by a reminder; handled once the first screen is up.
  ReminderRef? pendingLaunch;

  void consumeLaunch() {
    final r = pendingLaunch;
    pendingLaunch = null;
    if (r != null) openReminder(r);
  }

  /// Opens what a reminder points at: the full-screen reminder for alarms, the profile otherwise.
  void openReminder(ReminderRef r) {
    if (byId(r.eventId) == null) return;
    final nav = navKey.currentState;
    if (nav == null) return;
    nav.push(MaterialPageRoute(
      builder: (_) => r.style == AlertStyle.alarm
          ? ReminderScreen(id: r.eventId, notifId: r.notifId)
          : EventDetailScreen(id: r.eventId),
    ));
  }

  // ---------- Appearance ----------
  void setThemeMode(ThemeMode m) { themeMode = m; _prefs.setInt('themeMode', m.index); notifyListeners(); }
  void setAccent(int c) { accent = c; _prefs.setInt('accent', c); notifyListeners(); }
  void setDynamic(bool v) { useDynamic = v; _prefs.setBool('useDynamic', v); notifyListeners(); }
  void setPureBlack(bool v) { pureBlack = v; _prefs.setBool('pureBlack', v); notifyListeners(); }

  // ---------- Events ----------
  AnnuaEvent? byId(String id) {
    for (final e in events) {
      if (e.id == id) return e;
    }
    return null;
  }

  List<AnnuaEvent> get sorted => [...events]..sort((a, b) => a.daysUntil().compareTo(b.daysUntil()));

  /// Country (ISO code) last picked for a phone/WhatsApp number; Bangladesh by default.
  String get lastCountry => _prefs.getString('lastCountry') ?? 'BD';
  Future<void> setLastCountry(String iso) => _prefs.setString('lastCountry', iso);

  List<String> get categories =>
      events.map((e) => e.category).where((c) => c.isNotEmpty).toSet().toList()..sort();

  Future<void> upsert(AnnuaEvent e) async {
    final i = events.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      await notifications.cancelEvent(events[i]);
      events[i] = e;
    } else {
      events.add(e);
    }
    await _persist();
    await notifications.scheduleEvent(e);
  }

  Future<void> remove(String id) async {
    final e = byId(id);
    if (e == null) return;
    await notifications.cancelEvent(e);
    if (e.photo != null) await storage.deletePhoto(e.photo!);
    events.remove(e);
    await _persist();
  }

  Future<void> importEvents(List<AnnuaEvent> incoming, {required bool replace}) async {
    await notifications.rescheduleAll(const []);
    if (replace) {
      events = [...incoming];
    } else {
      for (final e in incoming) {
        final i = events.indexWhere((x) => x.id == e.id);
        i >= 0 ? events[i] = e : events.add(e);
      }
    }
    await _persist();
    await notifications.rescheduleAll(events);
  }

  Future<void> _persist() async {
    await storage.save(events);
    notifyListeners();
  }
}
