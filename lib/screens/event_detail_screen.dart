import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/event.dart';
import '../providers/app_state.dart';
import '../utils.dart';
import '../widgets/avatar.dart';
import 'event_form_screen.dart';

class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final e = s.byId(id);
    final cs = Theme.of(context).colorScheme;
    if (e == null) return const Scaffold(body: SizedBox.shrink());
    final d = e.daysUntil();
    String linkValue(String key) => key == 'whatsapp' ? e.whatsapp : (e.social[key] ?? '');

    Widget section(String title, List<Widget> kids) => Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.all(16),
          decoration: cardDeco(context),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title.toUpperCase(),
                style: TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
            const SizedBox(height: 10),
            ...kids,
          ]),
        );

    Widget row(IconData i, String t) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Icon(i, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(child: Text(t)),
          ]),
        );

    return Scaffold(
      appBar: AppBar(actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventFormScreen(event: e))),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Delete event?'),
                content: Text('${e.name} and its reminders will be removed.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
                ],
              ),
            );
            if (ok == true && context.mounted) {
              Navigator.pop(context);
              await s.remove(e.id);
            }
          },
        ),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 40), children: [
        Center(child: Avatar(name: e.name, radius: 52, path: e.photo == null ? null : s.storage.photoPath(e.photo!))),
        const SizedBox(height: 14),
        Center(child: Text(e.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600))),
        if (e.relationship.isNotEmpty)
          Center(child: Text(e.relationship, style: TextStyle(color: cs.onSurfaceVariant))),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.subtitle, style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(fmtDate(e.next), style: TextStyle(color: cs.onPrimaryContainer.withValues(alpha: .8))),
              ]),
            ),
            Text(daysLabel(d), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w300, color: cs.onPrimaryContainer)),
          ]),
        ),
        if (e.phone.isNotEmpty) ...[
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: FilledButton.tonalIcon(
                  onPressed: () => openUri(Uri(scheme: 'tel', path: e.phone)),
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Call')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                  onPressed: () => openUri(Uri(scheme: 'sms', path: e.phone)),
                  icon: const Icon(Icons.sms_outlined),
                  label: const Text('Message')),
            ),
          ]),
        ],
        if (e.category.isNotEmpty || e.location.isNotEmpty || e.phone.isNotEmpty || e.whatsapp.isNotEmpty)
          section('Details', [
            if (e.category.isNotEmpty) row(Icons.label_outline_rounded, e.category),
            if (e.location.isNotEmpty) row(Icons.place_outlined, e.location),
            if (e.phone.isNotEmpty) row(Icons.phone_outlined, e.phone),
            if (e.whatsapp.isNotEmpty) row(Icons.chat_bubble_outline_rounded, e.whatsapp),
          ]),
        if (e.social.isNotEmpty || e.whatsapp.isNotEmpty)
          section('Social & links', [
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final p in linkPlatforms)
                if (p.key != 'phone' && linkValue(p.key).isNotEmpty)
                  ActionChip(
                    avatar: PlatformIcon(p, size: 18),
                    label: Text(p.label),
                    onPressed: () => openUri(linkUri(p.key, linkValue(p.key))),
                  ),
            ]),
          ]),
        section('Reminders', [
          if (e.reminders.isEmpty) Text('No reminders set', style: TextStyle(color: cs.onSurfaceVariant)),
          for (final r in e.reminders)
            row(
              switch (r.style) {
                AlertStyle.popup => Icons.notifications_none_rounded,
                AlertStyle.vibrate => Icons.vibration_rounded,
                AlertStyle.alarm => Icons.alarm_rounded,
              },
              '${r.daysBefore == 0 ? 'On the day' : '${r.daysBefore} day${r.daysBefore > 1 ? 's' : ''} before'} · ${fmtTime(r.hour, r.minute)}',
            ),
        ]),
        if (e.notes.isNotEmpty) section('Notes', [Text(e.notes)]),
      ]),
    );
  }
}
