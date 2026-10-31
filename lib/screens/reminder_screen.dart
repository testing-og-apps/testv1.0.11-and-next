import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/event.dart';
import '../providers/app_state.dart';
import '../utils.dart';
import '../widgets/avatar.dart';
import 'event_detail_screen.dart';

/// Full-screen reminder (also over the lock screen).
class ReminderScreen extends StatelessWidget {
  const ReminderScreen({super.key, required this.id, required this.notifId});
  final String id;
  final int notifId;

  Reminder? _reminder(AnnuaEvent e) {
    for (final r in e.reminders) {
      if (r.notifId == notifId) return r;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final e = s.byId(id);
    final cs = Theme.of(context).colorScheme;
    if (e == null) return const Scaffold(body: SizedBox.shrink());
    final r = _reminder(e);
    final d = e.daysUntil();
    final photo = e.photo == null ? null : s.storage.photoPath(e.photo!);

    Future<void> dismiss() async {
      if (r != null) await s.notifications.dismiss(e, r);
      if (context.mounted) Navigator.of(context).maybePop();
    }

    return PopScope(
      canPop: true,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [cs.primaryContainer, cs.surface],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.alarm_rounded, size: 30, color: cs.primary),
                        const SizedBox(height: 18),
                        Avatar(name: e.name, path: photo, radius: 76),
                        const SizedBox(height: 22),
                        Text(e.name,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w600, color: cs.onSurface)),
                        const SizedBox(height: 6),
                        Text(e.subtitleOn(e.next), textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: cs.onSurfaceVariant)),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(color: cs.primary.withValues(alpha: .15), borderRadius: BorderRadius.circular(20)),
                          child: Text(daysLabel(d), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: cs.primary)),
                        ),
                      ]),
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                    onPressed: dismiss,
                    child: const Text('Dismiss'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    if (r != null) await s.notifications.dismiss(e, r);
                    if (!context.mounted) return;
                    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => EventDetailScreen(id: e.id)));
                  },
                  child: const Text('Open profile'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
