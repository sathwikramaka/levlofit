// Gym check-in card (owner request 2026-11-12): the person's gym membership code, kept on this phone only, shown as a
// QR code (or barcode) on Today so it can be scanned at the gym door without opening another app.
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

import 'icons.dart';
import 'main.dart' show prefs;
import 'theme.dart';

typedef GymPass = ({String name, String code, bool qr});

GymPass? loadGymPass() {
  try {
    final code = prefs.getString('gym_code');
    if (code == null || code.isEmpty) return null;
    return (name: prefs.getString('gym_name') ?? 'Gym', code: code, qr: prefs.getBool('gym_qr') ?? true);
  } catch (_) {
    return null;
  }
}

Future<void> saveGymPass(GymPass? p) async {
  if (p == null) {
    for (final k in ['gym_code', 'gym_name', 'gym_qr']) {
      await prefs.remove(k);
    }
    return;
  }
  await prefs.setString('gym_code', p.code);
  await prefs.setString('gym_name', p.name);
  await prefs.setBool('gym_qr', p.qr);
}

/// The code drawn as a black-on-white symbol; the text itself where drawing is not available (the web app).
class GymCode extends StatelessWidget {
  const GymCode({super.key, required this.pass, this.size = 220});
  final GymPass pass;
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget text() => SelectableText(pass.code, textAlign: TextAlign.center, style: monoNumber(context, size: 20).copyWith(color: graphite));
    if (kIsWeb) return text();
    try {
      final px = (size * 3).round();
      final e = zx.encodeBarcode(
        contents: pass.code,
        params: EncodeParams(format: pass.qr ? Format.qrCode : Format.code128, width: px, height: pass.qr ? px : px ~/ 3, margin: 10),
      );
      if (!e.isValid || e.data == null) return text();
      return Image.memory(pngFromBytes(e.data!, e.width ?? px, e.height ?? px), width: size, filterQuality: FilterQuality.none, gaplessPlayback: true);
    } catch (_) {
      return text();
    }
  }
}

/// Today's card: a tap opens the code full screen at full brightness size.
class GymPassCard extends StatelessWidget {
  const GymPassCard({super.key, required this.pass});
  final GymPass pass;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showGymPass(context, pass),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(14)),
              child: Icon(LvIcons.qrCode, color: c.onPrimary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('GYM CHECK-IN', style: monoLabel(context)),
                Text(pass.name, style: t.titleMedium),
                Text('Tap to show your code', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
              ]),
            ),
            Icon(LvIcons.caretRight, size: 18, color: c.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }
}

Future<void> showGymPass(BuildContext context, GymPass pass) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(pass.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: graphite)),
            const SizedBox(height: 18),
            GymCode(pass: pass, size: 240),
            const SizedBox(height: 14),
            Text('Turn the screen brightness up if the reader struggles.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: charcoal)),
          ]),
        ),
      ),
    );

/// Settings: add, change or remove the code. Scan it from the membership card or app, or type it.
class GymPassEditor extends StatefulWidget {
  const GymPassEditor({super.key});

  @override
  State<GymPassEditor> createState() => _GymPassEditorState();
}

class _GymPassEditorState extends State<GymPassEditor> {
  final GymPass? _old = loadGymPass();
  late final _name = TextEditingController(text: _old?.name ?? '');
  late final _code = TextEditingController(text: _old?.code ?? '');
  late bool _qr = _old?.qr ?? true;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final got = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (scan) => Scaffold(
          appBar: AppBar(title: const Text('Scan your gym code')),
          body: ReaderWidget(
            codeFormat: Format.any,
            showGallery: false,
            showToggleCamera: false,
            onScan: (c) {
              if (c.isValid && c.text != null) Navigator.pop(scan, '${c.format == Format.qrCode ? 'qr' : 'bar'}|${c.text}');
            },
          ),
        ),
      ),
    );
    if (got == null || !mounted) return;
    final i = got.indexOf('|');
    setState(() {
      _qr = got.substring(0, i) == 'qr';
      _code.text = got.substring(i + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Gym check-in')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text('Your membership code shows on Today, ready for the gym door. It stays on this phone.', style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
        const SizedBox(height: 18),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Gym name'), textCapitalization: TextCapitalization.words),
        const SizedBox(height: 12),
        TextField(controller: _code, decoration: const InputDecoration(labelText: 'Membership code'), onChanged: (_) => setState(() {})),
        const SizedBox(height: 8),
        Row(children: [
          if (!kIsWeb) TextButton.icon(onPressed: _scan, icon: const Icon(LvIcons.qrCode, size: 18), label: const Text('Scan it')),
          const Spacer(),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [ButtonSegment(value: true, label: Text('QR')), ButtonSegment(value: false, label: Text('Barcode'))],
            selected: {_qr},
            onSelectionChanged: (s) => setState(() => _qr = s.first),
          ),
        ]),
        if (_code.text.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          Center(child: Container(color: Colors.white, padding: const EdgeInsets.all(12), child: GymCode(pass: (name: '', code: _code.text.trim(), qr: _qr), size: 160))),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _code.text.trim().isEmpty
              ? null
              : () async {
                  await saveGymPass((name: _name.text.trim().isEmpty ? 'Gym' : _name.text.trim(), code: _code.text.trim(), qr: _qr));
                  if (context.mounted) Navigator.pop(context, true);
                },
          child: const Text('Save'),
        ),
        if (_old != null)
          TextButton(
            onPressed: () async {
              await saveGymPass(null);
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Remove from this phone'),
          ),
      ]),
    );
  }
}
