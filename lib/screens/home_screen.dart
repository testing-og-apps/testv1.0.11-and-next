import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/event.dart';
import '../providers/app_state.dart';
import '../utils.dart';
import '../widgets/avatar.dart';
import '../widgets/curved_nav.dart';
import 'calendar_screen.dart';
import 'event_detail_screen.dart';
import 'event_form_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _q = '';
  String? _cat;

  Future<void> _addEvent() async {
    final type = await showModalBottomSheet<EventType>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('What do you want to add?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            _TypeOption(icon: Icons.cake_outlined, title: 'Birthday', subtitle: 'Never forget a birthday', type: EventType.birthday),
            _TypeOption(icon: Icons.favorite_border_rounded, title: 'Anniversary', subtitle: 'Weddings, relationships, milestones', type: EventType.anniversary),
            _TypeOption(icon: Icons.star_border_rounded, title: 'Other', subtitle: 'Custom event', type: EventType.other),
          ]),
        ),
      ),
    );
    if (type == null || !mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => EventFormScreen(initialType: type)));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final q = _q.toLowerCase();
    final list = s.sorted.where((e) {
      if (_cat != null && e.category != _cat) return false;
      if (q.isEmpty) return true;
      return e.name.toLowerCase().contains(q) ||
          e.relationship.toLowerCase().contains(q) ||
          e.location.toLowerCase().contains(q);
    }).toList();

    final groups = <String, List<AnnuaEvent>>{'Today': [], 'This week': [], 'This month': [], 'Later': []};
    for (final e in list) {
      final d = e.daysUntil();
      groups[d == 0 ? 'Today' : d <= 7 ? 'This week' : d <= 30 ? 'This month' : 'Later']!.add(e);
    }

    final children = <Widget>[];
    groups.forEach((title, items) {
      if (items.isEmpty) return;
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(title.toUpperCase(),
            style: TextStyle(fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
      ));
      for (final e in items) {
        children.add(_EventTile(event: e, photo: e.photo == null ? null : s.storage.photoPath(e.photo!)));
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          // Fixed header: stays put while the list below scrolls.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
            child: Row(children: [
              Image.asset('assets/logo.png', height: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Annua',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w300, letterSpacing: 2, color: cs.onSurface)),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: deco(context, 'Search people', icon: Icons.search_rounded),
            ),
          ),
          if (s.categories.isNotEmpty)
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: const Text('All'),
                      selected: _cat == null,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _cat = null),
                    ),
                  ),
                  for (final c in s.categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(c),
                        selected: _cat == c,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _cat = c),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: CustomScrollView(slivers: [
          if (list.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.cake_outlined, size: 56, color: cs.outline),
                  const SizedBox(height: 12),
                  Text(s.events.isEmpty ? 'No events yet' : 'No matches', style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 4),
                  Text(s.events.isEmpty ? 'Add a birthday or anniversary to begin.' : 'Try a different search.',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                ]),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: SliverList(delegate: SliverChildListDelegate(children)),
            ),
            ]),
          ),
        ]),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: _addEvent,
        tooltip: 'Add event',
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 34),
      ),
      bottomNavigationBar: CurvedBottomBar(
        onCalendar: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen())),
        onSettings: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, this.photo});
  final AnnuaEvent event;
  final String? photo;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = event.daysUntil();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(id: event.id))),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: cardDeco(context),
          child: Row(children: [
            Avatar(name: event.name, path: photo),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(event.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text([event.subtitle, if (event.relationship.isNotEmpty) event.relationship].join(' · '),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
              ]),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              d == 0
                  ? Icon(Icons.celebration_rounded, color: cs.primary)
                  : Text('$d', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300, color: cs.primary)),
              Text(d == 0 ? 'Today' : d == 1 ? 'day' : 'days', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({required this.icon, required this.title, required this.subtitle, required this.type});
  final IconData icon;
  final String title, subtitle;
  final EventType type;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: cardDeco(context),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => Navigator.pop(context, type),
        leading: CircleAvatar(backgroundColor: cs.primaryContainer, child: Icon(icon, color: cs.onPrimaryContainer)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
