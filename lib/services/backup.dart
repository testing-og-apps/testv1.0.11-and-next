import 'dart:convert';
import 'dart:io';
import '../models/event.dart';
import 'storage.dart';

class BackupService {
  BackupService(this.storage);
  final Storage storage;

  // ---------- Local export / import (no cloud) ----------
  Future<String> buildBackup(List<AnnuaEvent> events) async {
    final out = <Map<String, dynamic>>[];
    for (final e in events) {
      final j = e.toJson();
      if (e.photo != null) {
        final f = File(storage.photoPath(e.photo!));
        if (await f.exists()) j['photoData'] = base64Encode(await f.readAsBytes());
      }
      out.add(j);
    }
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'annua',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'events': out,
    });
  }

  Future<List<AnnuaEvent>> parseBackup(String source) async {
    final m = jsonDecode(source);
    if (m is! Map || m['app'] != 'annua') throw const FormatException('This is not an Annua backup file.');
    final result = <AnnuaEvent>[];
    for (final raw in (m['events'] as List)) {
      final j = Map<String, dynamic>.from(raw as Map);
      final e = AnnuaEvent.fromJson(j);
      final data = j['photoData'] as String?;
      if (data != null && e.photo != null) await storage.writePhoto(e.photo!, base64Decode(data));
      result.add(e);
    }
    return result;
  }
}
