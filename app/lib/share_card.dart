// Share cards: a small picture of a week or a level, drawn on the phone and handed to the share sheet as a PNG.
// Only what the person chose to share: sessions, minutes, lifts, levels. Never weight or calories.
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import 'icons.dart';
import 'mark.dart';
import 'theme.dart';

/// A square, always-dark card: a label, one big line, a line under it and up to three facts.
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.kicker, required this.big, required this.line, this.facts = const []});
  final String kicker; // e.g. 'MY WEEK  ·  3 TO 9 NOV'
  final String big; // e.g. '4 of 4 sessions'
  final String line;
  final List<(String, String)> facts; // (value, label)

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: darkTheme,
      child: Builder(builder: (context) {
        final c = Theme.of(context).colorScheme;
        return AspectRatio(
          aspectRatio: 1,
          child: Container(
            color: graphite,
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const LevloWordmark(fontSize: 18),
              const Spacer(),
              Text(kicker, style: monoLabel(context).copyWith(color: c.tertiary)),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(big, maxLines: 1, style: GoogleFonts.unbounded(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -1, color: cloud)),
              ),
              const SizedBox(height: 6),
              Text(line, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, color: c.onSurfaceVariant)),
              if (facts.isNotEmpty) ...[
                const SizedBox(height: 20),
                Row(children: [
                  for (final (value, label) in facts.take(3))
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(value, style: monoNumber(context, size: 22)),
                        Text(label, style: monoLabel(context)),
                      ]),
                    ),
                ]),
              ],
            ]),
          ),
        );
      }),
    );
  }
}

/// Shows [card] in a sheet; Share sends it as a 1080 px PNG with [text] beside it.
Future<void> showShareSheet(BuildContext context, ShareCard card, {required String fileName, required String text}) {
  final key = GlobalKey();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ClipRRect(borderRadius: BorderRadius.circular(cardRadius), child: RepaintBoundary(key: key, child: card)),
          const SizedBox(height: 16),
          Builder(
            builder: (button) => FilledButton.icon(
              icon: const Icon(LvIcons.shareNetwork, size: 18),
              label: const Text('Share'),
              onPressed: () async {
                final box = button.findRenderObject() as RenderBox?;
                try {
                  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
                  final image = await boundary.toImage(pixelRatio: 1080 / boundary.size.width);
                  final png = await image.toByteData(format: ImageByteFormat.png);
                  image.dispose();
                  await SharePlus.instance.share(ShareParams(
                    text: text,
                    files: [XFile.fromData(png!.buffer.asUint8List(), mimeType: 'image/png', name: fileName)],
                    fileNameOverrides: [fileName],
                    sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
                  ));
                } catch (_) {
                  if (sheet.mounted) {
                    ScaffoldMessenger.of(sheet).showSnackBar(const SnackBar(content: Text('Could not open sharing on this device.')));
                  }
                }
              },
            ),
          ),
        ]),
      ),
    ),
  );
}
