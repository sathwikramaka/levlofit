// Optional body check (owner request 2026-10-27): the person picks one photo, agrees each time, and the body-check
// function returns neutral posture notes and focus areas. The photo is sent once and never stored. Off unless used.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'coach_chat.dart';
import 'main.dart';
import 'theme.dart';

typedef BodyCheckResult = ({List<String> observations, List<String> focus});

/// What each focus area suggests doing, in plain words. Levlofit's own mapping to its plan and library.
const focusAdvice = <String, String>{
  'upper body': 'More chest, back and shoulder work: push-ups, rows and presses.',
  'lower body': 'More leg work: squats, lunges and hinges.',
  'core': 'Core strength: dead bugs, side bridges and carries.',
  'posture and mobility': 'Posture and mobility: rows, stretches and the yoga poses in the library.',
  'conditioning': 'Conditioning: brisk walks, intervals and more daily steps.',
};

BodyCheckResult? parseResult(Object? data) {
  if (data is! Map) return null;
  final obs = data['observations'], focus = data['focus'];
  if (obs is! List || focus is! List) return null;
  return (observations: obs.whereType<String>().toList(), focus: focus.whereType<String>().where(focusAdvice.containsKey).toList());
}

/// The coach prompt that turns the focus areas into a plan change the person confirms in chat.
String coachPromptFor(BodyCheckResult r) => r.focus.isEmpty
    ? 'Help me decide what my training should focus on.'
    : 'My body check suggests focusing on ${r.focus.join(', ')}. How should I adjust my plan for that?';

const consentText = 'Your photo is sent once to Levlofit AI\'s provider (Groq, which may process it outside India) to write a few notes '
    'on posture and which areas to train. It is not saved by Levlofit or shown to anyone. No body-fat, weight or health '
    'judgement is made. You must be 18 or over. Wear fitted clothes; you can crop out your face.';

class BodyCheckCard extends StatefulWidget {
  const BodyCheckCard({super.key, @visibleForTesting this.pick, @visibleForTesting this.send});
  final Future<Uint8List?> Function()? pick; // tests
  final Future<Object?> Function(Map<String, String> body)? send; // tests

  @override
  State<BodyCheckCard> createState() => _BodyCheckCardState();
}

class _BodyCheckCardState extends State<BodyCheckCard> {
  bool _busy = false;
  String? _error;
  BodyCheckResult? _result;

  Future<bool> _agree() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Before you upload'),
          content: const Text(consentText),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('I agree, choose photo')),
          ],
        ),
      ) ??
      false;

  Future<void> _run() async {
    if (!await _agree()) return;
    Future<Uint8List?> pickFromGallery() async {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 80);
      return f?.readAsBytes();
    }

    final bytes = await (widget.pick?.call() ?? pickFromGallery());
    if (bytes == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final body = {'image': base64Encode(bytes), 'mime': 'image/jpeg'};
      final data = await (widget.send?.call(body) ?? supabase.functions.invoke('body-check', body: body).then((r) => r.data));
      final r = parseResult(data);
      if (!mounted) return;
      setState(() => r == null ? _error = 'The body check could not read that photo. Try another one.' : _result = r);
    } on FunctionException catch (e) {
      final msg = e.details is Map ? (e.details as Map)['error'] : null;
      if (mounted) setState(() => _error = msg is String ? msg : 'The body check is not available right now.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not reach Levlofit. Check your connection.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final r = _result;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: c.surfaceContainerHigh, borderRadius: BorderRadius.circular(24), border: Border.all(color: c.outline)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('BODY CHECK  ·  OPTIONAL', style: monoLabel(context)),
        const SizedBox(height: 8),
        Text('Get posture notes and training focus from one photo.', style: t.titleMedium),
        const SizedBox(height: 4),
        Text('Only if you want to. Nothing is saved.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
        const SizedBox(height: 12),
        if (r != null) ...[
          for (final o in r.observations) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('·  $o', style: t.bodyMedium)),
          if (r.focus.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('SUGGESTED FOCUS', style: monoLabel(context)),
            const SizedBox(height: 6),
            for (final f in r.focus) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(focusAdvice[f]!, style: t.bodyMedium)),
          ],
          const SizedBox(height: 8),
          FilledButton(onPressed: () => openCoach(context, prompt: coachPromptFor(r)), child: const Text('Adjust my plan with Levlofit AI')),
          const SizedBox(height: 4),
          Text('Notes from an AI model, not a medical or fitness assessment.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
        ],
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: ErrorLine(_error!)),
        OutlinedButton(
          onPressed: _busy ? null : _run,
          child: _busy
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(r == null ? 'Check a photo' : 'Check another photo'),
        ),
      ]),
    );
  }
}
