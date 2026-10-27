// The Handbook's front and back matter (owner request 2026-10-27: read like a real book, from an introduction and
// objectives through to a conclusion). Plain words, no new numbers: every figure here is one the chapters cite.
import 'package:flutter/material.dart';

import 'icons.dart';
import 'theme.dart';

typedef BookPage = ({String id, String label, String title, String lead, List<({String heading, String body})> sections});

const bookIntroduction = (
  id: 'introduction',
  label: 'INTRODUCTION',
  title: 'Welcome to your Handbook',
  lead: 'This is a short book about training and food, written so anyone can follow it. No jargon without an explanation, '
      'no fads, and every number tells you where it comes from.',
  sections: [
    (
      heading: 'Who it is for',
      body: 'Adults who want to get fitter, stronger or healthier, whether you have never trained or have trained for years. '
          'It is written for Indian kitchens and Indian bodies, so food examples are dal, roti, rice and paneer, not kale smoothies.',
    ),
    (
      heading: 'How it is built',
      body: 'Each chapter is short: a few minutes to read. It opens with the idea in one line, explains it simply, '
          'shows it in a picture where a picture helps, and ends with key points you can act on. '
          'Sources are listed at the end of every chapter.',
    ),
    (
      heading: 'How to read it',
      body: 'Read Part A from the start: it is the foundation the rest builds on. After that, jump to whatever you need. '
          'Use the search box when a word in your plan is unfamiliar. Each chapter ends with a link to the next one.',
    ),
    (
      heading: 'What it is not',
      body: 'It is general information from published guidelines, not medical advice, and it has not been reviewed by a doctor. '
          'If you have pain, an illness, a heart condition or are pregnant, talk to a doctor before training hard.',
    ),
  ],
);

const bookObjectives = (
  id: 'objectives',
  label: 'OBJECTIVES',
  title: 'What this Handbook will help you do',
  lead: 'By the end you should be able to make your own sensible choices about training and food, and know why your plan looks the way it does.',
  sections: [
    (heading: '1. Start safely', body: 'Know when you can begin straight away and when to see a doctor first.'),
    (heading: '2. Understand training', body: 'Know how the body gets fitter: a challenge, rest, and coming back a little stronger.'),
    (heading: '3. Train at the right effort', body: 'Judge how hard a set is by the reps you have left, so you push enough but stay safe.'),
    (heading: '4. Eat for your goal', body: 'Read your calorie and protein targets and build Indian meals that meet them.'),
    (heading: '5. Recover well', body: 'Use sleep, water and rest days as part of the plan, not as an afterthought.'),
    (heading: '6. Keep going', body: 'Track what matters, build habits that last, and move up a level when you are ready.'),
  ],
);

const bookConclusion = (
  id: 'conclusion',
  label: 'CONCLUSION',
  title: 'Putting it all together',
  lead: 'Fitness is not one perfect week. It is many ordinary weeks done reasonably well.',
  sections: [
    (
      heading: 'The short version',
      body: 'Move most days. Lift something challenging two or three times a week. Eat enough protein, plenty of plants and '
          'mostly home-cooked food. Drink water through the day. Sleep seven hours or more. Rest when you need it.',
    ),
    (
      heading: 'When progress stalls',
      body: 'Look at the basics before anything fancy: are you training as planned, eating to your targets and sleeping enough? '
          'Small fixes there beat any supplement.',
    ),
    (
      heading: 'Your next step',
      body: 'Open today\'s session or your meal plan and do one thing from this book today. Come back to any chapter whenever '
          'a question comes up. Levlofit AI can explain any part of it in your own words.',
    ),
  ],
);

class BookPageScreen extends StatelessWidget {
  const BookPageScreen({super.key, required this.page});
  final BookPage page;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: Text(page.label)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
        children: [
          Text(page.title, style: t.headlineMedium),
          const SizedBox(height: 12),
          Text(page.lead, style: t.titleMedium?.copyWith(height: 1.5)),
          const SizedBox(height: 24),
          for (final s in page.sections) ...[
            Text(s.heading, style: t.titleMedium),
            const SizedBox(height: 6),
            Text(s.body, style: t.bodyLarge?.copyWith(height: 1.6, color: muted)),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}

/// A front- or back-matter row for the Handbook's contents.
class BookPageTile extends StatelessWidget {
  const BookPageTile(this.page, {super.key});
  final BookPage page;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => BookPageScreen(page: page))),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(page.label, style: monoLabel(context).copyWith(color: c.tertiary)),
                const SizedBox(height: 4),
                Text(page.title, style: t.titleMedium),
              ]),
            ),
            Icon(LvIcons.caretRight, size: 18, color: c.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }
}
