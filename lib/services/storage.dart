import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../models/event.dart';

class Storage {
  late Directory _dir;
  late File _file;

  Future<void> init() async {
    _dir = await getApplicationDocumentsDirectory();
    _file = File('${_dir.path}/annua_events.json');
    await Directory('${_dir.path}/photos').create(recursive: true);
  }

  Future<List<AnnuaEvent>> load() async {
    if (!await _file.exists()) return [];
    try {
      final list = jsonDecode(await _file.readAsString()) as List;
      return list.map((e) => AnnuaEvent.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<AnnuaEvent> events) =>
      _file.writeAsString(jsonEncode(events.map((e) => e.toJson()).toList()));

  String photoPath(String name) => '${_dir.path}/photos/$name';

  Future<String> savePhoto(File src, String eventId) async {
    final name = '${eventId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await src.copy(photoPath(name));
    return name;
  }

  Future<void> writePhoto(String name, Uint8List bytes) => File(photoPath(name)).writeAsBytes(bytes);

  Future<void> deletePhoto(String name) async {
    final f = File(photoPath(name));
    if (await f.exists()) await f.delete();
  }
}
