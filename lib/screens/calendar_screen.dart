import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/event.dart';
import '../providers/app_state.dart';
import '../utils.dart';
import '../widgets/avatar.dart';
import 'event_detail_screen.dart';

const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _dayLetters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

Color _typeColor(ColorScheme cs, EventType t) => switch (t) {
      EventType.birthday => cs.primary,
      EventType.anniversary => cs.tertiary,
      EventType.other => cs.secondary,
    };

/// Month calendar. Days that have events are highlighted; tapping one lifts up a sheet with that day's events.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const _base = 1200;
  final _ctl = PageController(initialPage: _base);
  final _now = DateTime.now();
  int _page = _base;

  DateTime _monthOf(int page) => DateTime(_now.year, _now.month + (page - _base));

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _go(int page) => _ctl.animateToPage(page, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);

  /// day-of-month -> events on that day
  Map<int, List<AnnuaEvent>> _byDay(List<AnnuaEvent> events, DateTime m) {
    final days = DateTime(m.year, m.month + 1, 0).day;
    final map = <int, List<AnnuaEvent>>{};
    for (var d = 1; d <= days; d++) {
      final date = DateTime(m.year, m.month, d);
      final list = events.where((e) => e.occursOn(date)).toList();
      if (list.isNotEmpty) map[d] = list;
    }
    return map;
  }

  void _openDay(DateTime date, List<AnnuaEvent> events) {
    final s = context.read<AppState>();
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(sheet).size.height * .7),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_weekdays[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(events.length == 1 ? '1 event' : '${events.length} events', style: TextStyle(color: cs.onSurfaceVariant)),
              const SizedBox(height: 14),
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  for (final e in events)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: cardDeco(sheet),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        onTap: () {
                          Navigator.pop(sheet);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(id: e.id)));
                        },
                        leading: Avatar(name: e.name, path: e.photo == null ? null : s.storage.photoPath(e.photo!), radius: 22),
                        title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text([e.subtitleOn(date), if (e.relationship.isNotEmpty) e.relationship].join(' · ')),
                        trailing: const Icon(Icons.chevron_right_rounded),
                      ),
                    ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final month = _monthOf(_page);
    final rowH = (MediaQuery.of(context).size.width - 32) / 7 * 1.12;
    final monthEvents = _byDay(s.events, month);
    final todayMonth = _page == _base;

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 12, 0),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context)),
              const Expanded(child: Text('Calendar', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600))),
              if (!todayMonth) TextButton.icon(onPressed: () => _go(_base), icon: const Icon(Icons.today_rounded, size: 18), label: const Text('Today')),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.chevron_left_rounded, size: 30), onPressed: () => _go(_page - 1)),
              Expanded(
                child: Center(
                  child: Text('${_months[month.month - 1]} ${month.year}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w300, letterSpacing: 1)),
                ),
              ),
              IconButton(icon: const Icon(Icons.chevron_right_rounded, size: 30), onPressed: () => _go(_page + 1)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(_dayLetters[i],
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1, color: cs.onSurfaceVariant)),
                    ),
                  ),
                ),
            ]),
          ),
          SizedBox(
            height: rowH * 6,
            child: PageView.builder(
              controller: _ctl,
              onPageChanged: (p) => setState(() => _page = p),
              itemBuilder: (context, page) => _MonthGrid(
                month: _monthOf(page),
                rowH: rowH,
                byDay: _byDay(s.events, _monthOf(page)),
                onDay: _openDay,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Wrap(spacing: 16, runSpacing: 4, children: [
              for (final t in EventType.values)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: _typeColor(cs, t), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(switch (t) { EventType.birthday => 'Birthday', EventType.anniversary => 'Anniversary', EventType.other => 'Other' },
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ]),
            ]),
          ),
          Expanded(
            child: monthEvents.isEmpty
                ? Center(child: Text('No events in ${_months[month.month - 1]}', style: TextStyle(color: cs.onSurfaceVariant)))
                : ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 20), children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('THIS MONTH',
                          style: TextStyle(fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
                    ),
                    for (final entry in monthEvents.entries)
                      for (final e in entry.value)
                        _MonthRow(
                          day: entry.key,
                          month: month,
                          event: e,
                          onTap: () => _openDay(DateTime(month.year, month.month, entry.key), entry.value),
                        ),
                  ]),
          ),
        ]),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.rowH, required this.byDay, required this.onDay});
  final DateTime month;
  final double rowH;
  final Map<int, List<AnnuaEvent>> byDay;
  final void Function(DateTime, List<AnnuaEvent>) onDay;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final lead = DateTime(month.year, month.month, 1).weekday % 7; // Sunday first
    final days = DateTime(month.year, month.month + 1, 0).day;
    final rows = ((lead + days) / 7).ceil();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        for (var r = 0; r < rows; r++)
          SizedBox(
            height: rowH,
            child: Row(children: [
              for (var c = 0; c < 7; c++)
                Expanded(child: _cell(context, cs, today, r * 7 + c - lead + 1, days)),
            ]),
          ),
      ]),
    );
  }

  Widget _cell(BuildContext context, ColorScheme cs, DateTime today, int day, int days) {
    if (day < 1 || day > days) return const SizedBox.shrink();
    final evs = byDay[day] ?? const <AnnuaEvent>[];
    final has = evs.isNotEmpty;
    final isToday = today.year == month.year && today.month == month.month && today.day == day;
    final types = evs.map((e) => e.type).toSet().toList();
    final size = rowH - 8;
    return Center(
      child: InkResponse(
        customBorder: const CircleBorder(),
        onTap: has ? () => onDay(DateTime(month.year, month.month, day), evs) : null,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: has ? cs.primaryContainer : null,
            border: isToday ? Border.all(color: cs.primary, width: 1.8) : null,
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$day',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: has || isToday ? FontWeight.w700 : FontWeight.w400,
                  color: has ? cs.onPrimaryContainer : cs.onSurface,
                )),
            if (has) ...[
              const SizedBox(height: 3),
              Row(mainAxisSize: MainAxisSize.min, children: [
                for (final t in types.take(3))
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(color: _typeColor(cs, t), shape: BoxShape.circle),
                  ),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}

class _MonthRow extends StatelessWidget {
  const _MonthRow({required this.day, required this.month, required this.event, required this.onTap});
  final int day;
  final DateTime month;
  final AnnuaEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final date = DateTime(month.year, month.month, day);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: cardDeco(context),
          child: Row(children: [
            SizedBox(
              width: 44,
              child: Column(children: [
                Text('$day', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: cs.primary)),
                Text(_weekdays[date.weekday - 1].substring(0, 3).toUpperCase(),
                    style: TextStyle(fontSize: 10, letterSpacing: 1, color: cs.onSurfaceVariant)),
              ]),
            ),
            const SizedBox(width: 10),
            Container(width: 3, height: 32, decoration: BoxDecoration(color: _typeColor(cs, event.type), borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(event.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                Text(event.subtitleOn(date), style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
