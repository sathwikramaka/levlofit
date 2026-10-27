// Keyframes for Levlofit's own exercise animations (move_animation.dart). Each move has its own path, worked out from
// its joint geometry and the cues in exercise_guide.dart; nothing is shared between unrelated moves. Frame checks:
// test/move_animation_test.dart and docs/EXERCISE_ANIMATIONS.md.
import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'move_animation.dart';

MoveKey _k(MovePose pose, int ms) => (pose: pose, ms: ms);

const _stand = Offset(-0.8, 53.9); // hip over the ankle (0, 4), legs straight
const _ankle = Offset(0, 4);
const _hang = Offset(1.5, -33); // relaxed arm from the shoulder

/// The hip and torso angle of a body held in one straight line from the ankle towards [shoulder].
({Offset hip, double torso}) _line(Offset ankle, Offset shoulder) {
  final u = (shoulder - ankle) / (shoulder - ankle).distance;
  return (hip: ankle + u * 49.7, torso: math.atan2(u.dx, u.dy) * 180 / math.pi);
}

// --- Squat (QChZi3x): bodyweight, arms reaching forward to balance, thighs to about parallel, heels down.
final squat = MoveAnimation(
  title: 'Squat',
  armsFromShoulder: true,
  view: Rect.fromLTRB(-38, -4, 62, 106),
  still: 1,
  keys: [
    _k(const MovePose(hip: _stand, torso: 3, handN: Offset(30, -9), ankleN: _ankle), 600),
    _k(const MovePose(hip: Offset(-10.5, 26.7), torso: 40, handN: Offset(31, -2), ankleN: _ankle), 1300),
    _k(const MovePose(hip: Offset(-10.5, 26.7), torso: 40, handN: Offset(31, -2), ankleN: _ankle), 250),
    _k(const MovePose(hip: _stand, torso: 3, handN: Offset(30, -9), ankleN: _ankle), 1000),
  ],
);

// --- Push-up (I4hDWkc): hands fixed, body one straight line pivoting on the toes, chest to just above the floor.
const _pushHand = Offset(40, 1);
final _toes = ankleOnBall(const Offset(-26.5, 0), 80);
final pushUp = () {
  final top = _line(_toes, const Offset(52.4, 32)), bottom = _line(_toes, const Offset(56, 12.5));
  MovePose p(({Offset hip, double torso}) l, double ua) =>
      MovePose(hip: l.hip, torso: l.torso, handN: _pushHand, ankleN: _toes, footN: 80, upperArm: ua);
  return MoveAnimation(
    title: 'Push-up',
    view: Rect.fromLTRB(-42, -4, 76, 62),
    props: MoveProps.mat,
    still: 1,
    keys: [_k(p(top, 1), 400), _k(p(bottom, 0.92), 1300), _k(p(bottom, 0.92), 200), _k(p(top, 1), 900)],
  );
}();

// --- Bench press (EIeI8Vf): lying face up, head left, feet flat; bar from over the shoulders to the lower chest.
final benchPress = () {
  MovePose p(Offset bar, double ua) =>
      MovePose(hip: const Offset(0, 30), torso: -87, handN: bar, ankleN: const Offset(26, 4), upperArm: ua);
  final top = p(const Offset(-29.5, 65.45), 1), bottom = p(const Offset(-23, 38.5), 0.72);
  return MoveAnimation(
    title: 'Bench press',
    view: Rect.fromLTRB(-58, -4, 42, 82),
    props: MoveProps.bench,
    still: 1,
    keys: [_k(top, 400), _k(bottom, 1500), _k(bottom, 200), _k(top, 1000)],
  );
}();

// --- Deadlift (ila4NZS): bar over the middle of the foot (x = 4) and travelling straight up close to the legs.
final deadlift = () {
  const arm = 33.6; // straight arms, just short of full reach
  MovePose p(Offset hip, double barY, {double head = 0}) =>
      MovePose(hip: hip, torso: hingeTorso(hip, Offset(4, barY), arm), head: head, handN: Offset(4, barY), ankleN: _ankle);
  final floor = p(const Offset(-20, 31.5), 12.9, head: -8), knee = p(const Offset(-11, 44), 30), top = p(_stand, 51);
  return MoveAnimation(
    title: 'Deadlift',
    hangFromBar: arm,
    view: Rect.fromLTRB(-42, -4, 56, 106),
    props: MoveProps.barbell,
    still: 0,
    keys: [_k(floor, 500), _k(knee, 750), _k(top, 650), _k(top, 400), _k(knee, 700), _k(floor, 700)],
  );
}();

// --- Shoulder press (znQUdHY): standing, dumbbells from the shoulders straight overhead, no lean back.
final shoulderPress = () {
  const bottom = MovePose(hip: _stand, torso: 1, handN: Offset(3, 2.5), ankleN: _ankle, upperArm: 0.5);
  const top = MovePose(hip: _stand, torso: 1, handN: Offset(1.5, 33.85), ankleN: _ankle);
  return MoveAnimation(
    title: 'Shoulder press',
    armsFromShoulder: true,
    view: Rect.fromLTRB(-40, -4, 56, 124),
    props: MoveProps.dumbbells,
    still: 0,
    keys: [_k(bottom, 400), _k(top, 1000), _k(top, 300), _k(bottom, 1400)],
  );
}();

// --- Dumbbell curl (no guide move yet): elbows still at the sides, the forearm turning about the elbow.
final dumbbellCurl = () {
  // The hand turns about the elbow, which stays just in front of the shoulder line.
  MovePose p(double deg) => MovePose(hip: _stand, torso: 1, handN: Offset.zero, elbowAt: const Offset(0.6, -16.95), forearm: deg, ankleN: _ankle);

  return MoveAnimation(
    title: 'Dumbbell curl',
    armsFromShoulder: true,
    view: Rect.fromLTRB(-40, -4, 56, 106),
    props: MoveProps.dumbbells,
    still: 1,
    keys: [_k(p(4), 400), _k(p(140), 1100), _k(p(140), 250), _k(p(4), 1600)],
  );
}();

// --- Pulldown (RVwzP10): seated, thighs under the pads, slight lean back; bar from overhead to the upper chest.
final pulldown = () {
  MovePose p(double torso, Offset bar, double ua) =>
      MovePose(hip: const Offset(0, 28), torso: torso, handN: bar, ankleN: const Offset(27, 4), upperArm: ua);
  final top = p(-12, const Offset(-5.5, 91.2), 1), bottom = p(-17, const Offset(2.5, 62), 0.55);
  return MoveAnimation(
    title: 'Pulldown',
    view: Rect.fromLTRB(-46, -4, 46, 118),
    props: MoveProps.pulldown,
    still: 1,
    keys: [_k(top, 500), _k(bottom, 1100), _k(bottom, 300), _k(top, 1400)],
  );
}();

// --- Lunge (RRWFUcw, IZVHb27): a long step forward, both knees bent with the back knee just off the floor, then
// push back to standing. The back foot stays on its ball while its heel rises.
final lunge = () {
  const ball = Offset(9.6, 0.9); // the back (far) foot's ball, which never moves
  MovePose p(Offset hip, double torso, Offset front, double frontFoot, double backHeel) => MovePose(
        hip: hip,
        torso: torso,
        handN: _hang,
        ankleN: front,
        footN: frontFoot,
        ballF: ball,
        footF: backHeel,
      );
  final stand = p(_stand, 2, _ankle, 0, 0);
  final swing = p(const Offset(8, 52), 3, const Offset(24, 12), -10, 25);
  final plant = p(const Offset(18, 48), 3, const Offset(48, 4), 0, 45);
  final bottom = p(const Offset(25, 29), 4, const Offset(48, 4), 0, 60);
  return MoveAnimation(
    title: 'Lunge',
    armsFromShoulder: true,
    view: Rect.fromLTRB(-30, -4, 80, 106),
    still: 3,
    keys: [
      _k(stand, 500), _k(swing, 400), _k(plant, 350), _k(bottom, 1000), _k(bottom, 200), _k(plant, 900),
      _k(swing, 400), _k(stand, 400),
    ],
  );
}();

// --- Plank (no guide move yet): from the knees onto forearms and toes, then a still hold, body one straight line.
final plank = () {
  final toes = ankleOnBall(const Offset(-40, 0), 80);
  const hand = Offset(57.5, 1.5);
  final straight = _line(toes, const Offset(40, 18));
  const kneelHip = Offset(11.1, 9.8);
  final kneel = MovePose(
    hip: kneelHip,
    torso: math.atan2(40 - kneelHip.dx, 18 - kneelHip.dy) * 180 / math.pi,
    handN: hand,
    ankleN: toes,
    footN: 80,
  );
  final hold = MovePose(hip: straight.hip, torso: straight.torso, handN: hand, ankleN: toes, footN: 80);
  return MoveAnimation(
    title: 'Plank',
    view: Rect.fromLTRB(-50, -4, 72, 46),
    props: MoveProps.mat,
    still: 1,
    keys: [_k(kneel, 600), _k(hold, 800), _k(hold, 2600), _k(kneel, 800)],
  );
}();

// --- Calf raise (bJYHBIN): up onto the balls of the feet, pause, lower slowly; the balls of the feet never move.
final calfRaise = () {
  MovePose p(double deg) {
    final a = ankleOnBall(const Offset(8, 0), deg);
    return MovePose(hip: _stand + (a - _ankle), torso: 2, handN: _hang, ankleN: a, ballN: const Offset(8, 0), footN: deg,
        ballF: const Offset(9.6, 0.9), footF: deg);
  }

  return MoveAnimation(
    title: 'Calf raise',
    armsFromShoulder: true,
    view: Rect.fromLTRB(-40, -4, 56, 110),
    still: 1,
    keys: [_k(p(0), 400), _k(p(35), 700), _k(p(35), 600), _k(p(0), 1100)],
  );
}();

/// All of Levlofit's own animations, by name, including ones no guide move uses yet.
final levlofitAnimations = <String, MoveAnimation>{
  'squat': squat,
  'push_up': pushUp,
  'bench_press': benchPress,
  'deadlift': deadlift,
  'dumbbell_curl': dumbbellCurl,
  'shoulder_press': shoulderPress,
  'pulldown': pulldown,
  'lunge': lunge,
  'plank': plank,
  'calf_raise': calfRaise,
};

/// Guide move id -> its animation. Only exact matches: same move, same equipment.
final moveVectorAnimations = <String, MoveAnimation>{
  'QChZi3x': squat,
  'I4hDWkc': pushUp,
  'EIeI8Vf': benchPress,
  'ila4NZS': deadlift,
  'znQUdHY': shoulderPress,
  'RVwzP10': pulldown,
  'RRWFUcw': lunge,
  'IZVHb27': lunge,
  'bJYHBIN': calfRaise,
};
