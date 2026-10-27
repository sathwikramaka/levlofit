import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levlo/exercise_guide.dart';
import 'package:levlo/move_animation.dart';
import 'package:levlo/move_animations.dart';

// Levlofit's own animations: every frame keeps bones whole, feet planted, hands on the weight and nothing below the
// floor, and each move follows its own path. Set LEVLOFIT_RENDER_DIR to also write contact sheets for review.

const _samples = 120;

Iterable<(double, Joints)> _frames(MoveAnimation m) sync* {
  for (var i = 0; i < _samples; i++) {
    final t = i / _samples;
    yield (t, m.solve(m.poseAt(t)));
  }
}

double _spread(Iterable<Offset> pts) {
  final l = pts.toList();
  var worst = 0.0;
  for (final a in l) {
    for (final b in l) {
      worst = math.max(worst, (a - b).distance);
    }
  }
  return worst;
}

/// The angle at [b] between [a] and [c], degrees.
double _angle(Offset a, Offset b, Offset c) {
  final u = a - b, v = c - b;
  return math.acos(((u.dx * v.dx + u.dy * v.dy) / (u.distance * v.distance)).clamp(-1, 1)) * 180 / math.pi;
}

void main() {
  test('ten animations, each linked only to guide moves that exist, and none shared by different moves', () {
    expect(levlofitAnimations, hasLength(10));
    for (final id in moveVectorAnimations.keys) {
      expect(moveGuide.containsKey(id), isTrue, reason: id);
    }
    // The two Lunge entries in the guide are the same move; every other move has its own animation.
    final byAnim = <MoveAnimation, Set<String>>{};
    for (final e in moveVectorAnimations.entries) {
      (byAnim[e.value] ??= {}).add(moveGuide[e.key]!.name);
    }
    for (final names in byAnim.values) {
      expect(names, hasLength(1), reason: '$names share one animation');
    }
    final paths = {for (final m in levlofitAnimations.values) [for (final k in m.keys) '${k.pose.hip} ${k.pose.handN} ${k.pose.forearm} ${k.pose.footN}'].join()};
    expect(paths, hasLength(10), reason: 'no two animations share a keyframe path');
  });

  for (final MapEntry(key: name, value: m) in levlofitAnimations.entries) {
    group(name, () {
      test('bones keep their length, hands reach their target, nothing goes below the floor', () {
        for (final (t, j) in _frames(m)) {
          for (final l in [j.near, j.far]) {
            expect((l.knee - l.hip).distance, closeTo(thighLen, 0.01), reason: 't=$t');
            expect((l.ankle - l.knee).distance, lessThanOrEqualTo(shinLen + 0.01), reason: 't=$t');
            expect((l.hand - l.handTarget).distance, lessThan(0.8), reason: 'hand off the weight at t=$t');
            expect((l.ankle - l.knee).distance, closeTo(shinLen, 0.6), reason: 'foot torn from the shin at t=$t');
            for (final p in [l.heel, l.ball, l.toe, l.knee, l.elbow, l.hand]) {
              expect(p.dy, greaterThan(-1.0), reason: 'below the floor at t=$t');
            }
            // Knees bend only forwards (no hyperextension): the knee is never behind the hip-ankle line.
            final a = l.ankle - l.hip, k = l.knee - l.hip;
            expect(a.dx * k.dy - a.dy * k.dx, greaterThanOrEqualTo(-0.5), reason: 'knee bends backwards at t=$t');
          }
          expect(j.hip.dy, greaterThan(4), reason: 'hips above the floor');
        }
      });

      test('the still frame is a real key and the loop has a sensible tempo', () {
        expect(m.still, inInclusiveRange(0, m.keys.length - 1));
        expect(m.period.inMilliseconds, inInclusiveRange(2400, 6000));
      });
    });
  }

  test('squat: feet flat and still, thighs reach about parallel, heels stay down', () {
    final f = _frames(squat).map((e) => e.$2).toList();
    expect(_spread(f.map((j) => j.near.heel)), lessThan(0.01));
    expect(_spread(f.map((j) => j.near.ball)), lessThan(0.01));
    final deepest = f.reduce((a, b) => a.hip.dy < b.hip.dy ? a : b);
    final thigh = deepest.near.knee - deepest.hip;
    expect(math.atan2(thigh.dy, thigh.dx).abs() * 180 / math.pi, lessThan(15), reason: 'thigh within 15° of parallel');
  });

  test('push-up: hands and toes fixed, body straight, elbows bend to about 70° at the bottom', () {
    final f = _frames(pushUp).map((e) => e.$2).toList();
    expect(_spread(f.map((j) => j.near.ball)), lessThan(0.01));
    expect(_spread(f.map((j) => j.near.hand)), lessThan(0.8));
    for (final j in f) {
      expect(_angle(j.shoulder, j.hip, j.near.ankle), greaterThan(174), reason: 'hips sag or pike');
    }
    final bottom = f.reduce((a, b) => a.shoulder.dy < b.shoulder.dy ? a : b);
    expect(_angle(bottom.near.shoulder, bottom.near.elbow, bottom.near.hand), inInclusiveRange(55, 100));
    expect(bottom.shoulder.dy, lessThan(15), reason: 'chest close to the floor');
  });

  test('bench press: bar from over the shoulders to the chest, lying still, feet planted', () {
    final f = _frames(benchPress).map((e) => e.$2).toList();
    expect(_spread(f.map((j) => j.hip)), lessThan(0.01));
    expect(_spread(f.map((j) => j.near.heel)), lessThan(0.01));
    final top = f.reduce((a, b) => a.near.hand.dy > b.near.hand.dy ? a : b);
    expect((top.near.hand.dx - top.shoulder.dx).abs(), lessThan(1.5), reason: 'locked out over the shoulders');
    expect(_angle(top.near.shoulder, top.near.elbow, top.near.hand), greaterThan(165));
    final bottom = f.reduce((a, b) => a.near.hand.dy < b.near.hand.dy ? a : b);
    expect(bottom.near.hand.dx, greaterThan(bottom.shoulder.dx + 4), reason: 'touches the lower chest, not the neck');
  });

  test('deadlift: bar stays over the middle of the foot, arms straight, feet planted', () {
    final f = _frames(deadlift).map((e) => e.$2).toList();
    for (final j in f) {
      expect(j.near.handTarget.dx, closeTo(4, 0.01));
      expect(_angle(j.near.shoulder, j.near.elbow, j.near.hand), greaterThan(160), reason: 'arms stay long');
    }
    expect(_spread(f.map((j) => j.near.ball)), lessThan(0.01));
    final top = f.reduce((a, b) => a.hip.dy > b.hip.dy ? a : b);
    expect(_angle(top.shoulder, top.hip, top.near.knee), greaterThan(170), reason: 'stands tall at the top');
  });

  test('shoulder press: hands travel up over the shoulder, ending straight-armed overhead, torso still', () {
    final f = _frames(shoulderPress).map((e) => e.$2).toList();
    expect(_spread(f.map((j) => j.shoulder)), lessThan(0.01), reason: 'no lean back');
    final top = f.reduce((a, b) => a.near.hand.dy > b.near.hand.dy ? a : b);
    expect(_angle(top.near.shoulder, top.near.elbow, top.near.hand), greaterThan(165));
    expect((top.near.hand.dx - top.shoulder.dx).abs(), lessThan(3));
  });

  test('curl: elbow stays at the side while the hand turns about it', () {
    final f = _frames(dumbbellCurl).map((e) => e.$2).toList();
    expect(_spread(f.map((j) => j.near.elbow)), lessThan(1.6));
    final top = f.reduce((a, b) => a.near.hand.dy > b.near.hand.dy ? a : b);
    expect(_angle(top.near.shoulder, top.near.elbow, top.near.hand), lessThan(50));
  });

  test('pulldown: seated still, bar comes from overhead to the upper chest with elbows down', () {
    final f = _frames(pulldown).map((e) => e.$2).toList();
    expect(_spread(f.map((j) => j.hip)), lessThan(0.01));
    final bottom = f.reduce((a, b) => a.near.hand.dy < b.near.hand.dy ? a : b);
    expect(bottom.near.hand.dy, inInclusiveRange(bottom.shoulder.dy, bottom.shoulder.dy + 9), reason: 'about upper-chest height');
    expect(bottom.near.elbow.dy, lessThan(bottom.shoulder.dy), reason: 'elbows pulled down');
    final top = f.reduce((a, b) => a.near.hand.dy > b.near.hand.dy ? a : b);
    expect(_angle(top.near.shoulder, top.near.elbow, top.near.hand), greaterThan(165));
  });

  test('lunge: back ball of the foot never moves, both knees near 90°, front knee over the foot', () {
    final f = _frames(lunge).map((e) => e.$2).toList();
    expect(_spread(f.map((j) => j.far.ball)), lessThan(0.01));
    final bottom = f.reduce((a, b) => a.hip.dy < b.hip.dy ? a : b);
    expect(_angle(bottom.near.hip, bottom.near.knee, bottom.near.ankle), inInclusiveRange(80, 105));
    expect(bottom.far.knee.dy, lessThan(9), reason: 'back knee just off the floor');
    expect(bottom.near.knee.dx, lessThan(bottom.near.toe.dx), reason: 'front knee does not pass the toes');
  });

  test('plank: forearms and toes still, a straight line during the hold', () {
    final f = _frames(plank).toList();
    expect(_spread(f.map((e) => e.$2.near.ball)), lessThan(0.01));
    for (final (t, j) in f) {
      if (t > 0.3 && t < 0.75) {
        expect(_angle(j.shoulder, j.hip, j.near.ankle), greaterThan(174), reason: 't=$t');
        expect(_angle(j.near.shoulder, j.near.elbow, j.near.hand), inInclusiveRange(75, 105), reason: 'elbow under the shoulder');
      }
    }
  });

  test('calf raise: balls of the feet fixed, heels rise about 35°', () {
    final f = _frames(calfRaise).map((e) => e.$2).toList();
    expect(_spread(f.map((j) => j.near.ball)), lessThan(0.01));
    expect(f.map((j) => j.near.heel.dy).reduce(math.max), greaterThan(3));
  });

  testWidgets('both figures render every move without errors', (tester) async {
    for (final m in levlofitAnimations.values) {
      for (final fig in DemoFigure.values) {
        await tester.pumpWidget(MaterialApp(home: SizedBox(width: 200, height: 200, child: MoveAnimationView(m, figure: fig))));
        await tester.pump(const Duration(milliseconds: 700));
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('with animations turned off it draws one still frame and runs no ticker', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(data: const MediaQueryData(disableAnimations: true), child: SizedBox(width: 200, height: 200, child: MoveAnimationView(squat))),
    ));
    expect(tester.binding.transientCallbackCount, 0);
  });

  test('drawing a frame is cheap: 1000 frames of every move', () {
    final sw = Stopwatch()..start();
    for (final m in levlofitAnimations.values) {
      for (var i = 0; i < 1000; i++) {
        final rec = ui.PictureRecorder();
        paintFigure(Canvas(rec), m, m.solve(m.poseAt(i / 1000)), FigureStyle.man);
        rec.endRecording().dispose();
      }
    }
    // 10,000 frames; a 60 fps budget is 16 ms per frame for everything on screen.
    expect(sw.elapsedMilliseconds / 10000, lessThan(0.5), reason: '${sw.elapsedMilliseconds} ms');
  });

  final out = Platform.environment['LEVLOFIT_RENDER_DIR'];
  testWidgets('contact sheets for review', (tester) async {
    await tester.runAsync(() async {
      for (final MapEntry(key: name, value: m) in levlofitAnimations.entries) {
        const cell = 220.0, cols = 8;
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        c.drawRect(const Rect.fromLTWH(0, 0, cell * cols, cell * 2), Paint()..color = Colors.white);
        for (var row = 0; row < 2; row++) {
          for (var i = 0; i < cols; i++) {
            c.save();
            c.translate(i * cell, row * cell);
            MovePainter(m, row == 0 ? FigureStyle.man : FigureStyle.woman, null, pose: m.poseAt(i / cols)).paint(c, const Size(cell, cell));
            c.restore();
          }
        }
        final img = await rec.endRecording().toImage((cell * cols).toInt(), (cell * 2).toInt());
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
      }
    });
  }, skip: out == null);
}
