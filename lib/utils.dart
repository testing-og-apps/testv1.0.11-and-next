import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

final navKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String fmtDate(DateTime d, {bool year = true}) => '${d.day} ${_months[d.month - 1]}${year ? ' ${d.year}' : ''}';

String fmtTime(int h, int m) {
  final p = h >= 12 ? 'PM' : 'AM';
  final hh = h % 12 == 0 ? 12 : h % 12;
  return '$hh:${m.toString().padLeft(2, '0')} $p';
}

String daysLabel(int d) => d == 0 ? 'Today' : d == 1 ? 'Tomorrow' : 'in $d days';

String newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36) + Random().nextInt(9999).toString();

void toast(String msg) => messengerKey.currentState
  ?..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));

InputDecoration deco(BuildContext c, String label, {IconData? icon, String? hint}) {
  final cs = Theme.of(c).colorScheme;
  OutlineInputBorder b(Color col, [double w = 0]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: w == 0 ? BorderSide.none : BorderSide(color: col, width: w),
      );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon, size: 20),
    filled: true,
    fillColor: cs.surfaceContainerLow,
    border: b(cs.outline),
    enabledBorder: b(cs.outline),
    focusedBorder: b(cs.primary, 1.5),
  );
}

BoxDecoration cardDeco(BuildContext c) {
  final cs = Theme.of(c).colorScheme;
  return BoxDecoration(
    color: cs.surfaceContainerLow,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: cs.outlineVariant.withValues(alpha: .5)),
  );
}

/// A contact / social option the user can add to an event.
/// Keys `phone` and `whatsapp` are stored in their own event fields, the rest in `social`.
class LinkPlatform {
  final String key, label, base, hint;
  final IconData icon;
  final Color? color; // brand color; null = follow the theme text color
  final TextInputType keyboard;
  final String? asset; // brand logo (SVG); when null the Material [icon] is used
  const LinkPlatform(this.key, this.label, this.icon, this.color,
      {this.asset, this.base = '', this.hint = '@username or link', this.keyboard = TextInputType.url});
}

const linkPlatforms = <LinkPlatform>[
  LinkPlatform('phone', 'Phone number', Icons.call_rounded, Color(0xFF34A853), hint: 'Phone number', keyboard: TextInputType.phone),
  LinkPlatform('whatsapp', 'WhatsApp', Icons.link_rounded, Color(0xFF25D366), asset: 'assets/brands/whatsapp.svg', hint: 'With country code', keyboard: TextInputType.phone),
  LinkPlatform('email', 'Email', Icons.mail_rounded, Color(0xFFEA4335), hint: 'name@example.com', keyboard: TextInputType.emailAddress),
  LinkPlatform('facebook', 'Facebook', Icons.link_rounded, Color(0xFF1877F2), asset: 'assets/brands/facebook.svg', base: 'https://facebook.com/'),
  LinkPlatform('instagram', 'Instagram', Icons.link_rounded, Color(0xFFE4405F), asset: 'assets/brands/instagram.svg', base: 'https://instagram.com/'),
  LinkPlatform('messenger', 'Messenger', Icons.link_rounded, Color(0xFF0099FF), asset: 'assets/brands/messenger.svg', base: 'https://m.me/'),
  LinkPlatform('telegram', 'Telegram', Icons.link_rounded, Color(0xFF26A5E4), asset: 'assets/brands/telegram.svg', base: 'https://t.me/'),
  LinkPlatform('x', 'X', Icons.link_rounded, null, asset: 'assets/brands/x.svg', base: 'https://x.com/'),
  LinkPlatform('linkedin', 'LinkedIn', Icons.link_rounded, Color(0xFF0A66C2), asset: 'assets/brands/linkedin.svg', base: 'https://linkedin.com/in/'),
  LinkPlatform('youtube', 'YouTube', Icons.link_rounded, Color(0xFFFF0000), asset: 'assets/brands/youtube.svg', base: 'https://youtube.com/'),
  LinkPlatform('tiktok', 'TikTok', Icons.link_rounded, null, asset: 'assets/brands/tiktok.svg', base: 'https://tiktok.com/@'),
  LinkPlatform('other', 'Other link', Icons.link_rounded, null, hint: 'https://…'),
];

LinkPlatform platformOf(String key) => linkPlatforms.firstWhere((p) => p.key == key, orElse: () => linkPlatforms.last);

/// Brand logo (SVG) when we have one, otherwise a Material icon, tinted with the brand color.
class PlatformIcon extends StatelessWidget {
  const PlatformIcon(this.p, {super.key, this.size = 22});
  final LinkPlatform p;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = platformColor(context, p);
    if (p.asset == null) return Icon(p.icon, size: size, color: color);
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(p.asset!, fit: BoxFit.contain, colorFilter: ColorFilter.mode(color, BlendMode.srcIn)),
    );
  }
}

Color platformColor(BuildContext c, LinkPlatform p) => p.color ?? Theme.of(c).colorScheme.onSurface;

/// Where tapping a saved link should go.
Uri linkUri(String key, String value) {
  final v = value.trim();
  switch (key) {
    case 'phone':
      return Uri(scheme: 'tel', path: v);
    case 'whatsapp':
      return Uri.parse('https://wa.me/${v.replaceAll(RegExp(r'[^0-9]'), '')}');
    case 'email':
      return Uri(scheme: 'mailto', path: v);
  }
  if (v.startsWith('http')) return Uri.parse(v);
  final p = platformOf(key);
  if (p.base.isEmpty) return Uri.parse('https://$v');
  // YouTube handles keep their '@'; everything else is a plain username.
  final handle = key == 'youtube' ? v : v.replaceFirst('@', '');
  return Uri.parse('${p.base}$handle');
}

Future<void> openUri(Uri u) async {
  try {
    if (await launchUrl(u, mode: LaunchMode.externalApplication)) return;
  } catch (_) {}
  toast('Could not open link');
}
