// Supplement reference (owner request 2026-11-12): what each common supplement is for, when to take it, the official
// reference intake and upper limit, cautions and sources. Read from assets/supplements.json, the same file coach-chat
// uses (supabase/functions/_shared/supplements.json; a test keeps them equal). General information, not a
// prescription; not clinician-reviewed.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'icons.dart';
import 'theme.dart';

typedef Supp = ({
  String id,
  String name,
  List<String> aliases,
  String what,
  String evidence,
  String timing,
  String when,
  String reference,
  String caution,
  String who,
  List<String> sources,
});

typedef SuppGuide = ({Map<String, String> timings, List<Supp> items});

SuppGuide parseSuppGuide(String json) {
  final d = jsonDecode(json) as Map<String, dynamic>;
  return (
    timings: (d['timings'] as Map).cast<String, String>(),
    items: [
      for (final m in (d['items'] as List).cast<Map<String, dynamic>>())
        (
          id: m['id'] as String,
          name: m['name'] as String,
          aliases: (m['aliases'] as List).cast<String>(),
          what: m['what'] as String,
          evidence: m['evidence'] as String,
          timing: m['timing'] as String,
          when: m['when'] as String,
          reference: m['reference'] as String,
          caution: m['caution'] as String,
          who: m['who'] as String,
          sources: (m['sources'] as List).cast<String>(),
        ),
    ],
  );
}

/// Loaded once at start (main.dart); empty until then, so screens and tests without it still work.
SuppGuide suppGuide = (timings: const {}, items: const []);

Future<void> loadSuppGuide() async {
  try {
    suppGuide = parseSuppGuide(await rootBundle.loadString('assets/supplements.json'));
  } catch (_) {} // the Diet tab then lists supplements without timing
}

String _norm(String s) => ' ${s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim()} ';

/// The reference entry for a name the person typed ("Vit D3 60k", "Omega 3 capsules", "B12"), or null. Longest alias
/// wins, so "vitamin b12" is not read as plain "b12" elsewhere and "fish oil" beats "oil".
Supp? matchSupp(String typed, [SuppGuide? guide]) {
  final g = guide ?? suppGuide;
  final t = _norm(typed);
  Supp? best;
  var len = 0;
  for (final s in g.items) {
    for (final a in [s.name, ...s.aliases]) {
      final n = _norm(a);
      if (n.trim().isNotEmpty && t.contains(n) && n.length > len) {
        best = s;
        len = n.length;
      }
    }
  }
  return best;
}

/// Which meal a supplement goes with, by its timing: the meal's index in [meals], or null when it belongs around
/// training on a rest day, or before or during, not with a meal. [fats] are each meal's fat in grams.
int? mealFor(String timing, List<double> fats, {int? pre, int? post}) {
  if (fats.isEmpty) return null;
  return switch (timing) {
    'morning' || 'any_meal' => 0,
    'evening' => fats.length - 1,
    // The fattiest of the later main meals (lunch onwards); fat helps absorb vitamin D and omega-3.
    'fat_meal' => () {
        var best = fats.length > 1 ? 1 : 0;
        for (var i = best; i < fats.length; i++) {
          if (fats[i] > fats[best]) best = i;
        }
        return best;
      }(),
    'pre' => pre,
    'post' => post,
    _ => null, // empty stomach, or during training
  };
}

/// Optional suggestions for this person, with the reason. Never added to the plan on their own: the person chooses.
/// [taking] are the ids already in their list or plan.
List<({Supp item, String why})> suggestSupps({required String? dietType, required List<String> goals, required Set<String> taking, SuppGuide? guide}) {
  final g = guide ?? suppGuide;
  Supp? by(String id) => g.items.where((s) => s.id == id).firstOrNull;
  final veg = dietType == 'vegetarian' || dietType == 'vegan';
  final strength = goals.any((x) => const {'strength', 'bodybuilding', 'powerlifting', 'calisthenics', 'hyrox', 'crossfit'}.contains(x));
  return [
    if (by('vitamin_d') case final s? when !taking.contains(s.id))
      (item: s, why: 'Low vitamin D is common in India. Ask for a blood test first; take it if your level is low or your doctor advises.'),
    if (by('b12') case final s? when veg && !taking.contains(s.id))
      (item: s, why: 'A ${dietType == 'vegan' ? 'vegan' : 'vegetarian'} diet gives little B12; many vegetarians in India are low.'),
    if (by('omega3') case final s? when !taking.contains(s.id))
      (item: s, why: veg ? 'You eat no fish: algal oil gives the EPA and DHA that plant foods lack.' : 'Worth it if you eat oily fish less than twice a week.'),
    if (by('creatine') case final s? when strength && !taking.contains(s.id))
      (item: s, why: 'The best-supported supplement for strength and muscle, cheap and safe for healthy people.'),
  ];
}

const _grade = {'strong': 'Strong evidence', 'moderate': 'Moderate evidence', 'limited': 'Limited evidence', 'weak': 'Weak evidence'};

/// One supplement in full: what it is for, when, how much (reference intakes), cautions, who it suits, sources.
Future<void> showSuppSheet(BuildContext context, Supp s) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, scroll) => ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(22, 0, 22, 28), children: [
          Text(s.name, style: Theme.of(sheet).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(_grade[s.evidence] ?? s.evidence, style: monoLabel(sheet).copyWith(color: Theme.of(sheet).colorScheme.tertiary)),
          for (final (label, text) in [('WHAT IT DOES', s.what), ('WHEN TO TAKE IT', s.when), ('HOW MUCH', s.reference), ('WHO IT SUITS', s.who), ('CAUTION', s.caution)]) ...[
            const SizedBox(height: 16),
            Text(label, style: monoLabel(sheet)),
            const SizedBox(height: 4),
            Text(text, style: Theme.of(sheet).textTheme.bodyLarge),
          ],
          const SizedBox(height: 16),
          Text('SOURCES', style: monoLabel(sheet)),
          for (final src in s.sources) Padding(padding: const EdgeInsets.only(top: 4), child: Text(src, style: Theme.of(sheet).textTheme.bodySmall)),
          const SizedBox(height: 14),
          Text('General information, not a prescription. With a health condition, pregnancy or medicines, ask your doctor or pharmacist first.',
              style: Theme.of(sheet).textTheme.bodySmall?.copyWith(color: Theme.of(sheet).colorScheme.onSurfaceVariant)),
        ]),
      ),
    );

/// Every supplement in the reference, for the Handbook and Diet.
class SuppGuideScreen extends StatelessWidget {
  const SuppGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Supplement guide')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
        Text('What each supplement does, when to take it and how much is safe, from NIH, ICMR-NIN and ISSN. None is required: food comes first.',
            style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
        const SizedBox(height: 12),
        for (final s in suppGuide.items)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: c.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius)),
            child: ListTile(
              onTap: () => showSuppSheet(context, s),
              title: Text(s.name, style: t.titleMedium),
              subtitle: Text('${_grade[s.evidence]}  ·  ${suppGuide.timings[s.timing] ?? ''}', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
              trailing: Icon(LvIcons.caretRight, size: 16, color: c.onSurfaceVariant),
            ),
          ),
      ]),
    );
  }
}
