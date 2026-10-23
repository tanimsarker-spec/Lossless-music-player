import 'dart:io';
import 'package:flutter/material.dart';
import 'theme.dart';

class Cover extends StatelessWidget {
  const Cover({super.key, this.path, this.size, this.radius = 8});
  final String? path;
  final double? size;
  final double radius;

  Widget _placeholder() => Container(
        width: size,
        height: size,
        color: LColors.charcoal,
        alignment: Alignment.center,
        child: Icon(Icons.album, color: LColors.silverDim, size: (size ?? 120) * 0.45),
      );

  @override
  Widget build(BuildContext context) {
    final p = path;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: p == null
          ? _placeholder()
          : Image.file(
              File(p),
              width: size,
              height: size,
              fit: BoxFit.cover,
              cacheWidth: size == null ? 900 : (size! * 2).toInt(),
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => _placeholder(),
            ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
              fontSize: 11, letterSpacing: 1.6, color: LColors.silverDim),
        ),
      );
}

class InfoCard extends StatelessWidget {
  const InfoCard(this.text, {super.key, this.icon = Icons.info_outline, this.warn = false});
  final String text;
  final IconData icon;
  final bool warn;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: LColors.charcoal,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: warn ? const Color(0xFF8A6A1F) : LColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: warn ? const Color(0xFFE0B040) : LColors.silverDim),
            const SizedBox(width: 10),
            Expanded(
                child: Text(text,
                    style: const TextStyle(fontSize: 12.5, height: 1.4, color: LColors.silver))),
          ],
        ),
      );
}

String fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(h > 0 ? 2 : 1, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}
