import 'dart:io';
import 'package:flutter/material.dart';

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.path, this.radius = 26});
  final String name;
  final String? path;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final has = path != null && File(path!).existsSync();
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();
    return CircleAvatar(
      radius: radius,
      backgroundColor: cs.primaryContainer,
      foregroundImage: has ? FileImage(File(path!)) : null,
      child: Text(initials, style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w600, fontSize: radius * .6)),
    );
  }
}
