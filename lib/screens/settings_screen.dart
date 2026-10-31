import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/event.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import '../utils.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() job, {String? ok}) async {
    setState(() => _busy = true);
    try {
      await job();
      if (ok != null) toast(ok);
    } catch (e) {
      toast('Something went wrong: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _stamp {
    final n = DateTime.now();
    String t(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${t(n.month)}${t(n.day)}';
  }

  Future<void> _export(AppState s) => _run(() async {
        final data = utf8.encode(await s.backup.buildBackup(s.events));
        final path = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Annua backup',
          fileName: 'annua_backup_$_stamp.json',
          bytes: Uint8List.fromList(data),
        );
        if (path != null) toast('Backup saved');
      });

  Future<void> _share(AppState s) => _run(() async {
        final dir = await getTemporaryDirectory();
        final f = File('${dir.path}/annua_backup_$_stamp.json');
        await f.writeAsString(await s.backup.buildBackup(s.events));
        await Share.shareXFiles([XFile(f.path)], subject: 'Annua backup');
      });

  Future<bool?> _askMode() => showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Import backup'),
          content: const Text('Merge adds and updates events. Replace deletes everything currently in the app first.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Merge')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Replace')),
          ],
        ),
      );

  Future<void> _import(AppState s) async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
    final bytes = res?.files.single.bytes;
    if (bytes == null) return;
    final replace = await _askMode();
    if (replace == null) return;
    await _run(() async {
      final list = await s.backup.parseBackup(utf8.decode(bytes));
      await s.importEvents(list, replace: replace);
    }, ok: 'Imported successfully');
  }

  Future<void> _pickSound(AppState s, String slot, String title) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) {
        final cs = Theme.of(sheet).colorScheme;
        final cur = s.soundValue(slot);
        Widget opt(String value, String label, String? sub, {VoidCallback? preview}) => ListTile(
              leading: Icon(cur == value ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: cur == value ? cs.primary : cs.onSurfaceVariant),
              title: Text(label),
              subtitle: sub == null ? null : Text(sub),
              trailing: IconButton(icon: const Icon(Icons.play_arrow_rounded), onPressed: preview),
              onTap: () async {
                await s.notifications.stopPreview();
                await s.setSound(slot, value);
                if (sheet.mounted) Navigator.pop(sheet);
              },
            );
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 8), child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600))),
            opt('app', 'Annua default', null, preview: () => s.notifications.previewSound(slot, 'app')),
            opt('system', 'System default', null, preview: () => s.notifications.previewSound(slot, 'system')),
            ListTile(
              leading: Icon(cur.startsWith('content') ? Icons.radio_button_checked_rounded : Icons.library_music_outlined,
                  color: cur.startsWith('content') ? cs.primary : cs.onSurfaceVariant),
              title: const Text('Choose from device…'),
              subtitle: cur.startsWith('content') ? Text(s.soundLabel(slot)) : null,
              onTap: () async {
                await s.notifications.stopPreview();
                final r = await s.notifications.pickSound(slot, cur, title);
                if (r == null) {
                  toast('Sound picker is not available');
                } else if (r.uri.isNotEmpty) {
                  await s.setSound(slot, r.uri, name: r.name);
                }
                if (sheet.mounted) Navigator.pop(sheet);
              },
            ),
            const SizedBox(height: 8),
          ]),
        );
      },
    );
    await s.notifications.stopPreview();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;

    Widget section(String title, List<Widget> kids, {bool padded = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(title.toUpperCase(),
                  style: TextStyle(fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
            ),
            Container(
              width: double.infinity,
              decoration: cardDeco(context),
              clipBehavior: Clip.antiAlias,
              child: Column(children: kids),
            ),
          ]),
        );

    final themeName = {ThemeMode.system: 'Auto', ThemeMode.light: 'Light', ThemeMode.dark: 'Dark'}[s.themeMode]!;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Stack(children: [
        ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
          // ── Appearance: one tile that expands ──
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Container(
              decoration: cardDeco(context),
              clipBehavior: Clip.antiAlias,
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  shape: const Border(),
                  collapsedShape: const Border(),
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Appearance', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('$themeName · ${s.useDynamic ? 'System colors' : 'Custom color'}'),
                  trailing: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(color: s.useDynamic ? cs.primary : Color(s.accent), shape: BoxShape.circle),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ThemeMode>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(value: ThemeMode.system, label: Text('Auto'), icon: Icon(Icons.brightness_auto_outlined)),
                            ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
                            ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
                          ],
                          selected: {s.themeMode},
                          onSelectionChanged: (v) => s.setThemeMode(v.first),
                        ),
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Pure black in dark mode'),
                      subtitle: const Text('Saves battery on OLED screens'),
                      value: s.pureBlack,
                      onChanged: s.setPureBlack,
                    ),
                    SwitchListTile(
                      title: const Text('Use system colors'),
                      subtitle: const Text('Match your wallpaper (Android 12+)'),
                      value: s.useDynamic,
                      onChanged: s.setDynamic,
                    ),
                    Opacity(
                      opacity: s.useDynamic ? .35 : 1,
                      child: IgnorePointer(
                        ignoring: s.useDynamic,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          child: Wrap(spacing: 10, runSpacing: 10, children: [
                            for (final c in accentPalette)
                              GestureDetector(
                                onTap: () => s.setAccent(c),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Color(c),
                                    shape: BoxShape.circle,
                                    border: s.accent == c ? Border.all(color: cs.onSurface, width: 2.5) : null,
                                  ),
                                  child: s.accent == c ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
                                ),
                              ),
                          ]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── Backup: three buttons side by side ──
          section('Backup (on this device)', [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                Expanded(child: _BackupButton(icon: Icons.file_upload_outlined, label: 'Export', onTap: _busy ? null : () => _export(s))),
                const SizedBox(width: 8),
                Expanded(child: _BackupButton(icon: Icons.ios_share_rounded, label: 'Share', onTap: _busy ? null : () => _share(s))),
                const SizedBox(width: 8),
                Expanded(child: _BackupButton(icon: Icons.file_download_outlined, label: 'Import', onTap: _busy ? null : () => _import(s))),
              ]),
            ),
          ]),
          // ── Reminders (compact) ──
          section('Reminders', [
            FutureBuilder<({bool notifications, bool exact})>(
              future: s.notifications.health(),
              builder: (context, snap) {
                final h = snap.data;
                final ok = h == null || (h.notifications && h.exact);
                final problems = [
                  if (h != null && !h.notifications) 'Notifications are off',
                  if (h != null && !h.exact) 'Exact alarms are off',
                ];
                return ListTile(
                  leading: Icon(ok ? Icons.verified_outlined : Icons.warning_amber_rounded, color: ok ? null : cs.error),
                  title: Text(ok ? 'Reminders are ready' : 'Reminders need permission'),
                  subtitle: Text(ok ? 'Notifications and exact alarms are allowed' : problems.join(' · ')),
                  trailing: ok
                      ? null
                      : FilledButton.tonal(
                          onPressed: () async {
                            await s.notifications.requestPermissions();
                            await s.notifications.rescheduleAll(s.events);
                            if (mounted) setState(() {});
                          },
                          child: const Text('Fix'),
                        ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.battery_saver_outlined),
              title: const Text('Unrestricted battery'),
              subtitle: const Text('Stops the phone from delaying reminders'),
              onTap: s.notifications.requestBackgroundAccess,
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Test in 1 minute'),
              subtitle: const Text('Lock your phone and check it arrives on time'),
              onTap: () {
                s.notifications.scheduleTest(AlertStyle.popup);
                toast('Test reminder set — lock your screen and wait a minute');
              },
            ),
            ListTile(
              leading: const Icon(Icons.play_circle_outline_rounded),
              title: const Text('Send a test'),
              subtitle: const Text('Preview the notification and the alarm'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.notifications_none_rounded), onPressed: () => s.notifications.showTest(AlertStyle.popup)),
                IconButton(icon: const Icon(Icons.alarm_rounded), onPressed: () => s.notifications.showTest(AlertStyle.alarm)),
              ]),
            ),
          ]),
          // ── Sounds ──
          section('Sounds', [
            for (final e in const [
              ('notif', 'Notification sound', Icons.notifications_active_outlined),
              ('birthday', 'Birthday alarm sound', Icons.cake_outlined),
              ('event', 'Event alarm sound', Icons.event_outlined),
            ])
              ListTile(
                leading: Icon(e.$3),
                title: Text(e.$2),
                subtitle: Text(s.soundLabel(e.$1)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _pickSound(s, e.$1, e.$2),
              ),
          ]),
          // ── About the developer ──
          section('About developer', [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Row(children: [
                SvgPicture.asset('assets/brands/zeroex.svg', height: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Zeroex', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: 1)),
                    Text('Developer of Annua', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                  ]),
                ),
              ]),
            ),
            ListTile(
              leading: const Icon(Icons.language_rounded),
              title: const Text('Website'),
              subtitle: const Text('zeroex-0x.github.io'),
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () => openUri(Uri.parse('https://zeroex-0x.github.io/')),
            ),
            ListTile(
              leading: const Icon(Icons.favorite_border_rounded),
              title: const Text('Support developer'),
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () => openUri(Uri.parse('https://zeroex-0x.github.io/support.html')),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _SocialIcon(asset: 'assets/brands/telegram.svg', color: const Color(0xFF26A5E4), tooltip: 'Telegram', url: 'https://t.me/zeroex_0x'),
                const SizedBox(width: 18),
                _SocialIcon(asset: 'assets/brands/facebook.svg', color: const Color(0xFF1877F2), tooltip: 'Facebook', url: 'https://www.facebook.com/zeroex.0X'),
                const SizedBox(width: 18),
                _SocialIcon(asset: 'assets/brands/github.svg', color: cs.onSurface, tooltip: 'GitHub', url: 'https://github.com/Zeroex-0X'),
              ]),
            ),
          ]),
          Center(child: Text('Annua 1.0.11 · ${s.events.length} events', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12))),
        ]),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
      ]),
    );
  }
}

class _BackupButton extends StatelessWidget {
  const _BackupButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Opacity(
      opacity: onTap == null ? .5 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: cs.secondaryContainer.withValues(alpha: .6), borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Icon(icon, color: cs.onSecondaryContainer),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSecondaryContainer)),
          ]),
        ),
      ),
    );
  }
}

class _SocialIcon extends StatelessWidget {
  const _SocialIcon({required this.asset, required this.color, required this.tooltip, required this.url});
  final String asset, tooltip, url;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        radius: 30,
        onTap: () => openUri(Uri.parse(url)),
        child: Container(
          width: 48,
          height: 48,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: cs.surfaceContainerHigh, shape: BoxShape.circle),
          child: SvgPicture.asset(asset, colorFilter: ColorFilter.mode(color, BlendMode.srcIn)),
        ),
      ),
    );
  }
}
