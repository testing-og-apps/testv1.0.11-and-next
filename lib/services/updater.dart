import 'dart:convert';
import 'dart:io';
import '../utils.dart';

class UpdateInfo {
  final String version, notes, url;
  const UpdateInfo({required this.version, required this.notes, required this.url});
}

/// Looks at the latest GitHub Release of [kUpdateRepo]. Nothing is downloaded or installed
/// automatically: the user decides in Settings → App update.
class Updater {
  static List<int> _parts(String v) => v
      .replaceFirst(RegExp(r'^[vV]'), '')
      .split('+')
      .first
      .split('.')
      .map((x) => int.tryParse(x) ?? 0)
      .toList();

  static bool _newer(String a, String b) {
    final x = _parts(a), y = _parts(b);
    for (var i = 0; i < 3; i++) {
      final xi = i < x.length ? x[i] : 0, yi = i < y.length ? y[i] : 0;
      if (xi != yi) return xi > yi;
    }
    return false;
  }

  /// Returns null when the app is up to date (or no release exists yet). Throws on network errors.
  static Future<UpdateInfo?> check() async {
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await c.getUrl(Uri.parse('https://api.github.com/repos/$kUpdateRepo/releases/latest'));
      req.headers.set('Accept', 'application/vnd.github+json');
      req.headers.set('User-Agent', 'Annua-app');
      final res = await req.close().timeout(const Duration(seconds: 10));
      if (res.statusCode == 404) return null;
      if (res.statusCode != 200) throw HttpException('status ${res.statusCode}');
      final j = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
      final tag = j['tag_name'] as String? ?? '';
      if (tag.isEmpty || !_newer(tag, kAppVersion)) return null;
      var url = j['html_url'] as String? ?? '';
      for (final a in (j['assets'] as List? ?? const [])) {
        final name = ((a as Map)['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk')) {
          url = a['browser_download_url'] as String? ?? url;
          break;
        }
      }
      return UpdateInfo(version: tag.replaceFirst(RegExp(r'^[vV]'), ''), notes: (j['body'] as String? ?? '').trim(), url: url);
    } finally {
      c.close(force: true);
    }
  }
}
