import 'package:flutter/material.dart';

/// A bar outline with a smooth, rounded dip in the middle that cradles the centre button.
class CurvedNotch extends NotchedShape {
  const CurvedNotch();

  @override
  Path getOuterPath(Rect host, Rect? guest) {
    if (guest == null || !host.overlaps(guest)) return Path()..addRect(host);
    final cx = guest.center.dx;
    final depth = (guest.bottom - host.top).clamp(0.0, host.height);
    final half = guest.width / 2 + 22; // the dip is a little wider than the button
    final top = host.top;
    return Path()
      ..moveTo(host.left, top)
      ..lineTo(cx - half, top)
      ..cubicTo(cx - half * 0.42, top, cx - half * 0.62, top + depth, cx, top + depth)
      ..cubicTo(cx + half * 0.62, top + depth, cx + half * 0.42, top, cx + half, top)
      ..lineTo(host.right, top)
      ..lineTo(host.right, host.bottom)
      ..lineTo(host.left, host.bottom)
      ..close();
  }
}

/// Bottom bar: Calendar (left), a docked "+" button in the curve (centre), Settings (right).
class CurvedBottomBar extends StatelessWidget {
  const CurvedBottomBar({super.key, required this.onCalendar, required this.onSettings});
  final VoidCallback onCalendar, onSettings;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BottomAppBar(
      shape: const CurvedNotch(),
      notchMargin: 8,
      height: 64,
      padding: EdgeInsets.zero,
      color: cs.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: Colors.black,
      child: Row(children: [
        Expanded(child: _Item(icon: Icons.calendar_month_rounded, label: 'Calendar', onTap: onCalendar)),
        const SizedBox(width: 96),
        Expanded(child: _Item(icon: Icons.settings_rounded, label: 'Settings', onTap: onSettings)),
      ]),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkResponse(
      onTap: onTap,
      radius: 40,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 26, color: cs.onSurfaceVariant),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      ]),
    );
  }
}
