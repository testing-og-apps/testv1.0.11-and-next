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
    final phones = e.valuesOf('phone');
    Future<String?> chooseValue(String title, List<String> values, LinkPlatform p) async {
      if (values.length == 1) return values.first;
      return showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheet) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(sheet).size.height * .6),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 8), child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600))),
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  for (final v in values)
                    ListTile(
                      leading: PlatformIcon(p, size: 24),
                      title: Text(v),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.pop(sheet, v),
                    ),
                  const SizedBox(height: 8),
                ]),
              ),
            ]),
          ),
        ),
      );
    }

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
        if (phones.isNotEmpty) ...[
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: FilledButton.tonalIcon(
                  onPressed: () async {
                    final v = await chooseValue('Call', phones, platformOf('phone'));
                    if (v != null) openUri(Uri(scheme: 'tel', path: v));
                  },
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Call')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                  onPressed: () async {
                    final v = await chooseValue('Message', phones, platformOf('phone'));
                    if (v != null) openUri(Uri(scheme: 'sms', path: v));
                  },
                  icon: const Icon(Icons.sms_outlined),
                  label: const Text('Message')),
            ),
          ]),
        ],
        if (e.category.isNotEmpty || e.location.isNotEmpty || phones.isNotEmpty)
          section('Details', [
            if (e.category.isNotEmpty) row(Icons.label_outline_rounded, e.category),
            if (e.location.isNotEmpty) row(Icons.place_outlined, e.location),
            if (phones.isNotEmpty)
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  final v = await chooseValue('Phone numbers', phones, platformOf('phone'));
                  if (v != null) openUri(Uri(scheme: 'tel', path: v));
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Icon(Icons.phone_outlined, size: 18, color: cs.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(child: Text(phones.first)),
                    if (phones.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(10)),
                        child: Text('+${phones.length - 1} more', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onPrimaryContainer)),
                      ),
                  ]),
                ),
              ),
          ]),
        if (e.links.any((l) => l.key != 'phone' && l.value.isNotEmpty))
          section('Social & links', [
            LayoutBuilder(builder: (context, box) {
              final w = (box.maxWidth - 16) / 3; // three equal tiles per row
              return Wrap(spacing: 8, runSpacing: 8, children: [
                for (final p in linkPlatforms)
                  if (p.key != 'phone' && e.valuesOf(p.key).isNotEmpty)
                    _LinkTile(
                      width: w,
                      platform: p,
                      count: e.valuesOf(p.key).length,
                      onTap: () async {
                        final v = await chooseValue(p.label, e.valuesOf(p.key), p);
                        if (v != null) openUri(linkUri(p.key, v));
                      },
                    ),
              ]);
            }),
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

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.width, required this.platform, required this.count, required this.onTap});
  final double width;
  final LinkPlatform platform;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      height: 68,
      child: Stack(children: [
        Positioned.fill(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: .5)),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                PlatformIcon(platform, size: 24),
                const SizedBox(height: 6),
                Text(platform.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
        ),
        if (count > 1)
          Positioned(
            top: 4,
            right: 6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(9)),
              child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onPrimary)),
            ),
          ),
      ]),
    );
  }
}
