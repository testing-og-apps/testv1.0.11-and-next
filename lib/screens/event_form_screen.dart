import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/event.dart';
import '../providers/app_state.dart';
import '../utils.dart';
import '../widgets/avatar.dart';
import '../widgets/pickers.dart';

const _relationships = [
  PickerOption('Family', Icons.family_restroom_rounded),
  PickerOption('Partner', Icons.favorite_border_rounded),
  PickerOption('Parent', Icons.escalator_warning_rounded),
  PickerOption('Child', Icons.child_care_rounded),
  PickerOption('Sibling', Icons.people_outline_rounded),
  PickerOption('Relative', Icons.diversity_3_rounded),
  PickerOption('Friend', Icons.emoji_people_rounded),
  PickerOption('Colleague', Icons.work_outline_rounded),
  PickerOption('Classmate', Icons.school_outlined),
  PickerOption('Neighbor', Icons.home_outlined),
];
const _categoryDefaults = [
  PickerOption('Family', Icons.family_restroom_rounded),
  PickerOption('Friends', Icons.groups_outlined),
  PickerOption('Work', Icons.work_outline_rounded),
  PickerOption('School', Icons.school_outlined),
  PickerOption('Community', Icons.diversity_1_outlined),
  PickerOption('VIP', Icons.star_outline_rounded),
];

class EventFormScreen extends StatefulWidget {
  const EventFormScreen({super.key, this.event, this.initialType});
  final AnnuaEvent? event;
  final EventType? initialType;
  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _name, _custom, _rel, _cat, _loc, _notes;
  // Contact/social entries in the order added; the same platform may appear several times.
  final List<_LinkRow> _links = [];
  final List<TextEditingController> _trash = []; // removed link fields, disposed with the screen
  _LinkRow? _focusRow;
  late Country _defaultCountry;
  late EventType _type;
  late Recurrence _rec;
  late DateTime _date;
  late bool _yearKnown;
  late List<Reminder> _reminders;
  String? _photo; // stored file name
  String? _newPhoto; // freshly picked path

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _defaultCountry = countryByIso(context.read<AppState>().lastCountry);
    _name = TextEditingController(text: e?.name);
    _custom = TextEditingController(text: e?.customTitle);
    _rel = TextEditingController(text: e?.relationship);
    _cat = TextEditingController(text: e?.category);
    _loc = TextEditingController(text: e?.location);
    _notes = TextEditingController(text: e?.notes);
    if (e != null) {
      for (final l in e.links) {
        if (l.key == 'phone' || l.key == 'whatsapp') {
          final sp = splitPhone(l.value, _defaultCountry);
          _links.add(_LinkRow(l.key, TextEditingController(text: sp.national), sp.country));
        } else {
          _links.add(_LinkRow(l.key, TextEditingController(text: l.value), null));
        }
      }
    }
    _type = e?.type ?? widget.initialType ?? EventType.birthday;
    _rec = e?.recurrence ?? Recurrence.yearly;
    _date = e?.date ?? DateTime.now();
    _yearKnown = e?.yearKnown ?? true;
    _photo = e?.photo;
    _reminders = e?.reminders.map((r) => r.copy()).toList() ?? [Reminder()];
  }

  @override
  void dispose() {
    for (final c in [_name, _custom, _rel, _cat, _loc, _notes, for (final l in _links) l.ctl, ..._trash]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 600, imageQuality: 80);
    if (x != null) setState(() => _newPhoto = x.path);
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _editReminder([int? index]) async {
    final r = await showModalBottomSheet<Reminder>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ReminderSheet(initial: index == null ? Reminder() : _reminders[index].copy()),
    );
    if (r == null) return;
    setState(() => index == null ? _reminders.add(r) : _reminders[index] = r);
  }

  Future<void> _addLink() async {
    final available = linkPlatforms; // the same platform can be added more than once
    final p = await showModalBottomSheet<LinkPlatform>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Add contact or link', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 14, children: [
              for (final p in available)
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.pop(c, p),
                  child: SizedBox(
                    width: 82,
                    child: Column(children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(color: Theme.of(c).colorScheme.surfaceContainerHigh, shape: BoxShape.circle),
                        child: Center(child: PlatformIcon(p, size: 26)),
                      ),
                      const SizedBox(height: 6),
                      Text(p.label, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 12)),
                    ]),
                  ),
                ),
            ]),
          ]),
        ),
      ),
    );
    if (p == null) return;
    setState(() {
      final row = _LinkRow(p.key, TextEditingController(), (p.key == 'phone' || p.key == 'whatsapp') ? _defaultCountry : null);
      _links.add(row);
      _focusRow = row;
    });
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    final s = context.read<AppState>();
    final old = widget.event;
    final id = old?.id ?? newId();
    var photo = _photo;
    if (_newPhoto != null) photo = await s.storage.savePhoto(File(_newPhoto!), id);
    if (old?.photo != null && old!.photo != photo) await s.storage.deletePhoto(old.photo!);
    final links = <LinkItem>[];
    for (final l in _links) {
      final isNumber = l.key == 'phone' || l.key == 'whatsapp';
      final v = isNumber ? composePhone(l.country ?? _defaultCountry, l.ctl.text) : l.ctl.text.trim();
      if (v.isNotEmpty) links.add(LinkItem(l.key, v));
    }
    await s.upsert(AnnuaEvent(
      id: id,
      name: _name.text.trim(),
      type: _type,
      customTitle: _custom.text.trim(),
      date: _date,
      yearKnown: _yearKnown,
      recurrence: _rec,
      relationship: _rel.text.trim(),
      category: _cat.text.trim(),
      location: _loc.text.trim(),
      links: links,
      notes: _notes.text.trim(),
      photo: photo,
      reminders: _reminders,
    ));
    if (mounted) Navigator.pop(context);
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 26, bottom: 10),
        child: Text(t.toUpperCase(),
            style: TextStyle(
                fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final cs = Theme.of(context).colorScheme;
    final storedPath = _photo == null ? null : s.storage.photoPath(_photo!);
    final photoPath = _newPhoto ?? storedPath;
    final hasPhoto = photoPath != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event != null
            ? 'Edit event'
            : switch (_type) {
                EventType.birthday => 'New birthday',
                EventType.anniversary => 'New anniversary',
                EventType.other => 'New event',
              }),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
            label: Text(widget.event == null ? 'Save' : 'Save changes'),
          ),
        ),
      ),
      body: Form(
        key: _key,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
          Center(
            child: Stack(children: [
              GestureDetector(onTap: _pickPhoto, child: Avatar(name: _name.text, radius: 48, path: photoPath)),
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: hasPhoto ? () => setState(() { _photo = null; _newPhoto = null; }) : _pickPhoto,
                  child: CircleAvatar(
                    radius: 15,
                    backgroundColor: cs.primary,
                    child: Icon(hasPhoto ? Icons.close_rounded : Icons.add_a_photo_outlined, size: 16, color: cs.onPrimary),
                  ),
                ),
              ),
            ]),
          ),
          Center(child: Padding(padding: const EdgeInsets.only(top: 8), child: Text('Photo (optional)', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)))),
          const SizedBox(height: 16),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: deco(context, 'Name', icon: Icons.person_outline_rounded),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a name' : null,
            onChanged: (_) => setState(() {}),
          ),
          _label(widget.event == null && _type != EventType.other ? 'Date' : 'Event'),
          if (widget.event != null)
            SegmentedButton<EventType>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: EventType.birthday, label: Text('Birthday'), icon: Icon(Icons.cake_outlined)),
                ButtonSegment(value: EventType.anniversary, label: Text('Anniv.'), icon: Icon(Icons.favorite_border_rounded)),
                ButtonSegment(value: EventType.other, label: Text('Other'), icon: Icon(Icons.star_border_rounded)),
              ],
              selected: {_type},
              onSelectionChanged: (v) => setState(() => _type = v.first),
            ),
          if (_type == EventType.other) ...[
            if (widget.event != null) const SizedBox(height: 12),
            TextFormField(
              controller: _custom,
              textCapitalization: TextCapitalization.sentences,
              decoration: deco(context, 'Event name', icon: Icons.star_border_rounded, hint: 'e.g. Graduation'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please name this event' : null,
            ),
          ],
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _pickDate,
            child: InputDecorator(
              decoration: deco(context, 'Date', icon: Icons.event_outlined),
              child: Text(fmtDate(_date, year: _yearKnown)),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Year is known'),
            subtitle: const Text('Used to show age or years together'),
            value: _yearKnown,
            onChanged: (v) => setState(() => _yearKnown = v),
          ),
          SegmentedButton<Recurrence>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: Recurrence.yearly, label: Text('Every year'), icon: Icon(Icons.repeat_rounded)),
              ButtonSegment(value: Recurrence.monthly, label: Text('Every month'), icon: Icon(Icons.calendar_month_outlined)),
            ],
            selected: {_rec},
            onSelectionChanged: (v) => setState(() => _rec = v.first),
          ),
          _label('About'),
          Row(children: [
            Expanded(
              child: PickerField(
                label: 'Relationship',
                value: _rel.text,
                onTap: () async {
                  final v = await showOptionPicker(context, title: 'Relationship', options: _relationships, current: _rel.text);
                  if (v != null) setState(() => _rel.text = v);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PickerField(
                label: 'Category',
                value: _cat.text,
                onTap: () async {
                  final extra = s.categories.where((c) => !_categoryDefaults.any((o) => o.label.toLowerCase() == c.toLowerCase()));
                  final options = [..._categoryDefaults, for (final c in extra) PickerOption(c, Icons.label_outline_rounded)];
                  final v = await showOptionPicker(context, title: 'Category', options: options, current: _cat.text);
                  if (v != null) setState(() => _cat.text = v);
                },
              ),
            ),
          ]),
          const SizedBox(height: 12),
          TextFormField(controller: _loc, decoration: deco(context, 'Location / place', icon: Icons.place_outlined, hint: 'City, venue, address…')),
          _label('Contact & social links'),
          for (final row in _links)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Builder(builder: (context) {
                final p = platformOf(row.key);
                final same = _links.where((l) => l.key == row.key).toList();
                final label = same.length > 1 ? '${p.label} ${same.indexOf(row) + 1}' : p.label;
                final isNumber = row.key == 'phone' || row.key == 'whatsapp';
                void remove() => setState(() {
                      _links.remove(row);
                      _trash.add(row.ctl);
                    });
                if (!isNumber) {
                  return TextFormField(
                    controller: row.ctl,
                    autofocus: identical(row, _focusRow),
                    keyboardType: p.keyboard,
                    decoration: deco(context, label, hint: p.hint).copyWith(
                      prefixIcon: Padding(padding: const EdgeInsets.all(14), child: PlatformIcon(p, size: 22)),
                      suffixIcon: IconButton(icon: const Icon(Icons.close_rounded), onPressed: remove),
                    ),
                  );
                }
                final country = row.country ?? _defaultCountry;
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    PlatformIcon(p, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
                    IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.close_rounded), onPressed: remove),
                  ]),
                  Row(children: [
                    CountryButton(
                      country: country,
                      onTap: () async {
                        final c = await showCountryPicker(context, country);
                        if (c == null || !mounted) return;
                        setState(() {
                          row.country = c;
                          _defaultCountry = c;
                        });
                        context.read<AppState>().setLastCountry(c.iso);
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: row.ctl,
                        autofocus: identical(row, _focusRow),
                        keyboardType: TextInputType.phone,
                        decoration: deco(context, 'Phone number', hint: row.key == 'whatsapp' ? 'WhatsApp number' : 'Number'),
                      ),
                    ),
                  ]),
                ]);
              }),
            ),
          OutlinedButton.icon(onPressed: _addLink, icon: const Icon(Icons.add_rounded), label: Text(_links.isEmpty ? 'Add contact or link' : 'Add another')),
          _label('Reminders'),
          for (var i = 0; i < _reminders.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: cardDeco(context),
              child: ListTile(
                onTap: () => _editReminder(i),
                leading: Icon(switch (_reminders[i].style) {
                  AlertStyle.popup => Icons.notifications_none_rounded,
                  AlertStyle.vibrate => Icons.vibration_rounded,
                  AlertStyle.alarm => Icons.alarm_rounded,
                }),
                title: Text(_reminders[i].daysBefore == 0
                    ? 'On the day'
                    : '${_reminders[i].daysBefore} day${_reminders[i].daysBefore > 1 ? 's' : ''} before'),
                subtitle: Text('${fmtTime(_reminders[i].hour, _reminders[i].minute)} · ${switch (_reminders[i].style) {
                  AlertStyle.popup => 'Notification',
                  AlertStyle.vibrate => 'Notification',
                  AlertStyle.alarm => 'Alarm',
                }}'),
                trailing: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _reminders.removeAt(i))),
              ),
            ),
          OutlinedButton.icon(onPressed: () => _editReminder(), icon: const Icon(Icons.add_rounded), label: const Text('Add reminder')),
          _label('Notes'),
          TextFormField(controller: _notes, maxLines: 4, decoration: deco(context, 'Gift ideas, memories…')),
        ]),
      ),
    );
  }
}

class _ReminderSheet extends StatefulWidget {
  const _ReminderSheet({required this.initial});
  final Reminder initial;
  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  late Reminder r = widget.initial;
  static const _days = [0, 1, 2, 3, 7, 14, 30];
  late bool _custom = !_days.contains(widget.initial.daysBefore);
  late final TextEditingController _customCtl = TextEditingController(text: widget.initial.daysBefore.toString());

  @override
  void dispose() {
    _customCtl.dispose();
    super.dispose();
  }

  String get _when => r.daysBefore == 0 ? 'On the day' : '${r.daysBefore} day${r.daysBefore > 1 ? 's' : ''} before';

  String get _styleName => switch (r.style) {
        AlertStyle.popup => 'notification',
        AlertStyle.vibrate => 'notification',
        AlertStyle.alarm => 'alarm',
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Reminder', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('$_when at ${fmtTime(r.hour, r.minute)} · $_styleName',
            style: TextStyle(color: cs.primary, fontWeight: FontWeight.w500)),
        const SizedBox(height: 20),
        Text('WHEN', style: TextStyle(fontSize: 12, letterSpacing: 1.4, color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final d in _days)
            ChoiceChip(
              label: Text(d == 0 ? 'On the day' : '$d day${d > 1 ? 's' : ''} before'),
              selected: !_custom && r.daysBefore == d,
              onSelected: (_) => setState(() {
                _custom = false;
                r.daysBefore = d;
              }),
            ),
          ChoiceChip(
            avatar: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Custom'),
            selected: _custom,
            onSelected: (_) => setState(() {
              _custom = true;
              _customCtl.text = r.daysBefore.toString();
            }),
          ),
        ]),
        if (_custom) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _customCtl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
            decoration: deco(context, 'Days before the event', icon: Icons.event_available_outlined, hint: 'e.g. 5'),
            onChanged: (v) => setState(() => r.daysBefore = int.tryParse(v) ?? 0),
          ),
        ],
        const SizedBox(height: 20),
        Text('TIME', style: TextStyle(fontSize: 12, letterSpacing: 1.4, color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: r.hour, minute: r.minute));
            if (t != null) setState(() { r.hour = t.hour; r.minute = t.minute; });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: cardDeco(context),
            child: Row(children: [
              Icon(Icons.schedule_rounded, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(fmtTime(r.hour, r.minute), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500))),
              Text('Change', style: TextStyle(color: cs.primary)),
            ]),
          ),
        ),
        const SizedBox(height: 20),
        Text('HOW SHOULD WE ALERT YOU?', style: TextStyle(fontSize: 12, letterSpacing: 1.4, color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        _StyleCard(
          icon: Icons.notifications_active_outlined,
          title: 'Notification',
          desc: 'Sound and vibration. Lights up the screen if the phone is locked.',
          selected: r.style != AlertStyle.alarm,
          onTap: () => setState(() => r.style = AlertStyle.popup),
        ),
        _StyleCard(
          icon: Icons.alarm_rounded,
          title: 'Alarm',
          desc: 'Loud full-screen alarm that rings until you dismiss it.',
          selected: r.style == AlertStyle.alarm,
          onTap: () => setState(() => r.style = AlertStyle.alarm),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: () => Navigator.pop(context, r),
            child: const Text('Save reminder'),
          ),
        ),
      ]),
    );
  }
}

class _StyleCard extends StatelessWidget {
  const _StyleCard({required this.icon, required this.title, required this.desc, required this.selected, required this.onTap});
  final IconData icon;
  final String title, desc;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? cs.primaryContainer : cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? cs.primary : cs.outlineVariant.withValues(alpha: .5), width: selected ? 1.5 : 1),
          ),
          child: Row(children: [
            Icon(icon, color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              ]),
            ),
            if (selected) Icon(Icons.check_circle_rounded, color: cs.primary),
          ]),
        ),
      ),
    );
  }
}

class _LinkRow {
  _LinkRow(this.key, this.ctl, this.country);
  final String key;
  final TextEditingController ctl;
  Country? country; // phone / WhatsApp only
}
