// Levlofit's own exercise animations. A jointed figure drawn in Flutter and posed from keyframes, one set per move.
// Original work: no third-party art, nothing downloaded, so it ships in a paid app and plays offline.
//
// World units: the standing figure is about 100 tall (1 unit ≈ 1.75 cm for a 175 cm person), y points up and the
// floor is y = 0. Side view, facing +x; lying face up the head is on the left. Knees and elbows come from two-bone
// inverse kinematics, so bones never stretch, feet stay where they are planted and hands stay on the bar.
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

enum DemoFigure { man, woman }

/// Which figure demonstrates. The app sets it from the profile and the choice on a move page.
final demoFigure = ValueNotifier(DemoFigure.man);

// Bone lengths, shared by both figures so every movement is the same checked path.
const thighLen = 25.0, shinLen = 25.0, torsoLen = 30.0, upperArmLen = 17.0, forearmLen = 17.0, neckLen = 9.0, headR = 6.5;

/// Foot in its own frame (flat, toes towards +x), relative to the ankle.
const _ball = Offset(8, -4), _heel = Offset(-3, -4), _toe = Offset(11, -3.5);

/// Where the far-side limbs sit, seen through the body.
const _depth = Offset(1.6, 0.9);

Offset _rot(Offset v, double deg) {
  final a = deg * math.pi / 180, c = math.cos(a), s = math.sin(a);
  return Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
}

/// Unit vector [deg] degrees from straight up, positive towards +x.
Offset _dir(double deg) => Offset(math.sin(deg * math.pi / 180), math.cos(deg * math.pi / 180));

/// The ankle position that keeps the ball of the foot at [ball] with the heel raised [deg] degrees.
Offset ankleOnBall(Offset ball, double deg) => ball - _rot(_ball, -deg);

/// One keyframe. Hands are world points, or offsets from the shoulder when the move's arms follow the body.
class MovePose {
  const MovePose({
    required this.hip,
    required this.torso,
    required this.handN,
    required this.ankleN,
    this.head = 0,
    this.handF,
    this.ankleF,
    this.footN = 0,
    this.footF,
    this.ballN,
    this.ballF,
    this.elbowAt,
    this.forearm = 0,
    this.upperArm = 1,
  });

  final Offset hip;
  final double torso; // degrees from vertical, positive leaning towards the facing side
  final double head; // neck flexion relative to the torso, degrees
  final Offset handN, ankleN;
  final Offset? handF, ankleF; // null: mirror the near side, seen through the body
  final double footN; // heel raise, degrees (0 flat)
  final double? footF;
  final double upperArm; // projected length of the upper arm when it moves out to the side (1 = in the view plane)
  final Offset? ballN, ballF; // a foot pivoting on its ball: the ankle follows the heel raise, so the ball stays put
  final Offset? elbowAt; // a forearm turning about a still elbow (placed as [handN] would be); the hand follows [forearm]
  final double forearm; // degrees from hanging straight down, positive forwards

  Offset get shoulder => hip + _dir(torso) * torsoLen;

  static MovePose lerp(MovePose a, MovePose b, double t) {
    Offset o(Offset x, Offset y) => Offset.lerp(x, y, t)!;
    double d(double x, double y) => lerpDouble(x, y, t)!;
    return MovePose(
      hip: o(a.hip, b.hip),
      torso: d(a.torso, b.torso),
      head: d(a.head, b.head),
      handN: o(a.handN, b.handN),
      handF: a.handF == null && b.handF == null ? null : o(a.handF ?? a.handN + _depth, b.handF ?? b.handN + _depth),
      ankleN: o(a.ankleN, b.ankleN),
      ankleF: a.ankleF == null && b.ankleF == null ? null : o(a.ankleF ?? a.ankleN + _depth, b.ankleF ?? b.ankleN + _depth),
      footN: d(a.footN, b.footN),
      footF: a.footF == null && b.footF == null ? null : d(a.footF ?? a.footN, b.footF ?? b.footN),
      ballN: a.ballN == null || b.ballN == null ? null : o(a.ballN!, b.ballN!),
      ballF: a.ballF == null || b.ballF == null ? null : o(a.ballF!, b.ballF!),
      elbowAt: a.elbowAt == null || b.elbowAt == null ? null : o(a.elbowAt!, b.elbowAt!),
      forearm: d(a.forearm, b.forearm),
      upperArm: d(a.upperArm, b.upperArm),
    );
  }
}

/// A keyframe and the time taken to reach it from the one before (the first key's time closes the loop).
typedef MoveKey = ({MovePose pose, int ms});

/// Solved joint positions for one frame.
class Joints {
  Joints._(this.hip, this.shoulder, this.head, this.facing, this.near, this.far);
  final Offset hip, shoulder, head, facing;
  final Limbs near, far;
}

class Limbs {
  const Limbs(this.hip, this.knee, this.ankle, this.heel, this.ball, this.toe, this.shoulder, this.elbow, this.hand, this.handTarget);
  final Offset hip, knee, ankle, heel, ball, toe, shoulder, elbow, hand, handTarget;
}

/// Two-bone IK: the middle joint for bones [a] and [b] from [root] towards [target], bent to the left of the
/// root-to-target line when [left] (counter-clockwise), else to the right. Out of reach, the limb straightens.
Offset bend(Offset root, Offset target, double a, double b, {required bool left}) {
  final d = target - root;
  final len = d.distance;
  final u = len == 0 ? const Offset(1, 0) : d / len;
  final dist = len.clamp((a - b).abs() + 1e-6, a + b - 1e-6);
  final x = (a * a - b * b + dist * dist) / (2 * dist);
  final h = math.sqrt(math.max(0, a * a - x * x));
  final perp = left ? Offset(-u.dy, u.dx) : Offset(u.dy, -u.dx);
  return root + u * x + perp * h;
}

/// The torso angle that hangs straight arms of length [arm] from the shoulders to [bar], shoulders above the bar.
double hingeTorso(Offset hip, Offset bar, double arm) {
  final d = (bar - hip).distance;
  final a = (torsoLen * torsoLen - arm * arm + d * d) / (2 * d);
  final h = math.sqrt(math.max(0, torsoLen * torsoLen - a * a));
  final u = (bar - hip) / d;
  final p1 = hip + u * a + Offset(-u.dy, u.dx) * h, p2 = hip + u * a + Offset(u.dy, -u.dx) * h;
  final s = p1.dy > p2.dy ? p1 : p2;
  return math.atan2(s.dx - hip.dx, s.dy - hip.dy) * 180 / math.pi;
}

Offset _reach(Offset root, Offset mid, Offset target, double b) {
  final d = target - mid;
  return d.distance <= b ? target : mid + d / d.distance * b;
}

class MoveAnimation {
  const MoveAnimation({
    required this.title,
    required this.keys,
    required this.view,
    this.armsFromShoulder = false,
    this.elbowsForward = false,
    this.still = 1,
    this.props = MoveProps.none,
    this.hangFromBar,
  });

  final String title;
  final List<MoveKey> keys;
  final Rect view; // the world area drawn, fixed for the whole loop
  final bool armsFromShoulder; // hands are offsets from the shoulder
  final bool elbowsForward; // elbows bend towards the facing side (default: behind, as in a curl or push-up)
  final int still; // the key shown when animations are turned off: the working position
  final MoveProps props;
  final double? hangFromBar; // arms held straight at this length: every frame, the torso is set from the hip and bar

  Duration get period => Duration(milliseconds: keys.fold(0, (s, k) => s + k.ms));

  /// The pose [t] (0..1) of the way through the loop, eased between keys.
  MovePose poseAt(double t) {
    final total = period.inMilliseconds;
    var at = (t % 1) * total;
    for (var i = 1; i <= keys.length; i++) {
      final k = keys[i % keys.length];
      if (at <= k.ms) {
        final p = MovePose.lerp(keys[i - 1].pose, k.pose, Curves.easeInOut.transform(k.ms == 0 ? 1 : at / k.ms));
        if (hangFromBar case final arm?) {
          return MovePose(hip: p.hip, torso: hingeTorso(p.hip, p.handN, arm), head: p.head, handN: p.handN, ankleN: p.ankleN, footN: p.footN);
        }
        return p;
      }
      at -= k.ms;
    }
    return keys.first.pose;
  }

  Joints solve(MovePose p) {
    final shoulder = p.shoulder;
    final facing = Offset(_dir(p.torso).dy, -_dir(p.torso).dx);
    final head = shoulder + _dir(p.torso + p.head) * neckLen;
    Limbs limb(Offset hipJ, Offset shoulderJ, Offset handT, Offset ankle, double foot) {
      final knee = bend(hipJ, ankle, thighLen, shinLen, left: true);
      final base = armsFromShoulder ? shoulderJ : Offset.zero;
      final target = p.elbowAt == null
          ? base + handT
          : base + p.elbowAt! + _dir(180 - p.forearm) * (forearmLen - 0.05);
      final ua = upperArmLen * p.upperArm;
      final elbow = bend(shoulderJ, target, ua, forearmLen, left: elbowsForward);
      Offset f(Offset v) => ankle + _rot(v, -foot);
      // Toes bend at the ball: with the heel up they stay flat on the floor.
      final toe = f(_ball) + _rot(_toe - _ball, -math.min(foot, 0.0));
      return Limbs(hipJ, knee, _reach(hipJ, knee, ankle, shinLen), f(_heel), f(_ball), toe, shoulderJ, elbow,
          _reach(shoulderJ, elbow, target, forearmLen), target);
    }

    final footF = p.footF ?? p.footN;
    final ankleN = p.ballN == null ? p.ankleN : ankleOnBall(p.ballN!, p.footN);
    final ankleF = p.ballF != null ? ankleOnBall(p.ballF!, footF) : p.ankleF ?? ankleN + _depth;
    final near = limb(p.hip, shoulder, p.handN, ankleN, p.footN);
    final far = limb(p.hip + _depth, shoulder + _depth, p.handF ?? p.handN + (armsFromShoulder ? Offset.zero : _depth), ankleF, footF);
    return Joints._(p.hip, shoulder, head, facing, near, far);
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Drawing

class FigureStyle {
  const FigureStyle({
    required this.skin,
    required this.hair,
    required this.top,
    required this.bottom,
    required this.legCover,
    required this.shoe,
    required this.trim,
    required this.limbScale,
    required this.chest,
    required this.waist,
    required this.ponytail,
  });

  final Color skin, hair, top, bottom, shoe, trim;
  final double legCover; // how far down the thigh the shorts or leggings reach (1 = to the knee, 2 = to the ankle)
  final double limbScale, chest, waist;
  final bool ponytail;

  static const _ink = Color(0xFF1C1C21), _orange = Color(0xFFFF6A1A), _skin = Color(0xFFA9714F);

  static const man = FigureStyle(
    skin: _skin,
    hair: Color(0xFF1E1714),
    top: _ink,
    bottom: _orange,
    legCover: 0.75,
    shoe: _ink,
    trim: _orange,
    limbScale: 1,
    chest: 15,
    waist: 12.5,
    ponytail: false,
  );
  static const woman = FigureStyle(
    skin: Color(0xFFB27A57),
    hair: Color(0xFF1E1714),
    top: _orange,
    bottom: _ink,
    legCover: 1.8,
    shoe: _ink,
    trim: _orange,
    limbScale: 0.88,
    chest: 13.5,
    waist: 11,
    ponytail: true,
  );

  static FigureStyle of(DemoFigure f) => f == DemoFigure.man ? man : woman;
}

const _steel = Color(0xFF3A3A42), _steelLight = Color(0xFF8A8A94), _pad = Color(0xFF2A2A30), _floor = Color(0xFFE9E5DD);

enum PropLayer { back, middle, front, top }

/// The equipment for a move, drawn in layers around the figure: behind it, between its far and near sides, in front
/// of the body but under the near arm, and on top of everything.
class MoveProps {
  const MoveProps._(this._draw);
  final void Function(Canvas c, Joints j, PropLayer layer)? _draw;
  void draw(Canvas c, Joints j, PropLayer layer) => _draw?.call(c, j, layer);

  static const none = MoveProps._(null);

  static void _plate(Canvas c, Offset at) {
    c.drawCircle(at, 12.5, Paint()..color = _steel);
    c.drawCircle(at, 12.5, Paint()
      ..color = const Color(0xFFFF6A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4);
    c.drawCircle(at, 8.5, Paint()
      ..color = const Color(0xFF4A4A54)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8);
    c.drawCircle(at, 2.2, Paint()..color = _steelLight);
  }

  static void _dumbbell(Canvas c, Offset at) {
    c.drawCircle(at, 4.6, Paint()..color = _steel);
    c.drawCircle(at, 4.6, Paint()
      ..color = const Color(0xFFFF6A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9);
    c.drawCircle(at, 1.3, Paint()..color = _steelLight);
  }

  /// A barbell seen end on: the near plate in front of the body, under the near hand that grips the bar.
  static const barbell = MoveProps._(_barbell);
  static void _barbell(Canvas c, Joints j, PropLayer layer) {
    if (layer == PropLayer.front) _plate(c, j.near.handTarget);
  }

  static const dumbbells = MoveProps._(_dumbbells);
  static void _dumbbells(Canvas c, Joints j, PropLayer layer) {
    if (layer == PropLayer.middle) _dumbbell(c, j.far.handTarget);
    if (layer == PropLayer.top) _dumbbell(c, j.near.handTarget);
  }

  static const bench = MoveProps._(_bench);
  static void _bench(Canvas c, Joints j, PropLayer layer) {
    if (layer == PropLayer.back) {
      final legs = Paint()
        ..color = _steel
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round;
      c.drawLine(const Offset(-40, 22), const Offset(-40, 0), legs);
      c.drawLine(const Offset(8, 22), const Offset(8, 0), legs);
      c.drawLine(const Offset(-46, 0.6), const Offset(-34, 0.6), legs);
      c.drawLine(const Offset(2, 0.6), const Offset(14, 0.6), legs);
      c.drawRRect(RRect.fromLTRBR(-50, 20, 14, 26, const Radius.circular(2.5)), Paint()..color = _pad);
      _uprights(c);
    }
    if (layer == PropLayer.front) _plate(c, j.near.handTarget);
  }

  static void _uprights(Canvas c) {
    final p = Paint()
      ..color = _steelLight
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    c.drawLine(const Offset(-37, 0), const Offset(-37, 68), p);
    c.drawLine(const Offset(-37, 66), const Offset(-32, 66), p);
  }

  static const pulldown = MoveProps._(_pulldown);
  static void _pulldown(Canvas c, Joints j, PropLayer layer) {
    if (layer == PropLayer.back) {
      final frame = Paint()
        ..color = _steel
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      c.drawLine(const Offset(-30, 0), const Offset(-30, 112), frame); // column
      c.drawLine(const Offset(-30, 112), const Offset(-6, 112), frame); // top arm
      c.drawRRect(RRect.fromLTRBR(-38, 2, -32, 40, const Radius.circular(1.5)), Paint()..color = _pad); // stack
      c.drawLine(const Offset(-30, 4), const Offset(10, 4), frame); // base
      c.drawLine(const Offset(0, 4), const Offset(0, 22), frame); // seat post
      c.drawRRect(RRect.fromLTRBR(-10, 20, 12, 25, const Radius.circular(2.5)), Paint()..color = _pad); // seat
      c.drawLine(const Offset(20, 22), const Offset(20, 36), frame..strokeWidth = 2); // knee pad post
      c.drawLine(const Offset(0, 18), const Offset(20, 22), frame);
      c.drawCircle(const Offset(-6, 112), 3, Paint()..color = _steelLight); // pulley
      final hand = j.near.handTarget;
      c.drawLine(Offset(hand.dx, hand.dy + 1), const Offset(-6, 109), Paint()
        ..color = _steelLight
        ..strokeWidth = 0.7);
    }
    if (layer == PropLayer.middle) {
      final hand = j.near.handTarget;
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: hand, width: 4, height: 4), const Radius.circular(2)), Paint()..color = _steel);
    }
    if (layer == PropLayer.front) {
      // The knee pad sits on top of the thighs.
      c.drawRRect(RRect.fromLTRBR(14, 34, 28, 39.5, const Radius.circular(2.8)), Paint()..color = _pad);
    }
  }

  /// A mat for floor moves.
  static const mat = MoveProps._(_mat);
  static void _mat(Canvas c, Joints j, PropLayer layer) {
    if (layer == PropLayer.back) {
      c.drawRRect(RRect.fromLTRBR(-48, -1.2, 72, 0.6, const Radius.circular(0.6)), Paint()..color = const Color(0xFFFF6A1A).withValues(alpha: 0.85));
    }
  }
}

class MovePainter extends CustomPainter {
  MovePainter(this.move, this.figure, this.t, {this.pose}) : super(repaint: t);
  final MoveAnimation move;
  final FigureStyle figure;
  final Animation<double>? t;
  final MovePose? pose; // a fixed frame (still mode, tests)

  @override
  void paint(Canvas canvas, Size size) {
    final p = pose ?? move.poseAt(t?.value ?? 0);
    final j = move.solve(p);
    final v = move.view;
    final scale = math.min(size.width / v.width, size.height / v.height);
    canvas.save();
    canvas.translate((size.width - v.width * scale) / 2, (size.height + v.height * scale) / 2);
    canvas.scale(scale, -scale);
    canvas.translate(-v.left, -v.top);
    paintFigure(canvas, move, j, figure);
    canvas.restore();
  }

  @override
  bool shouldRepaint(MovePainter old) => old.move != move || old.figure != figure || old.pose != pose || old.t != t;
}

/// Draws one solved frame in world units (y up).
void paintFigure(Canvas c, MoveAnimation move, Joints j, FigureStyle f) {
  // Floor and its contact shadow.
  c.drawRect(Rect.fromLTRB(move.view.left, -3, move.view.right, 0), Paint()..color = _floor);
  final contact = [j.near.heel, j.near.ball, j.far.heel, j.far.ball].map((o) => o.dx);
  c.drawOval(
    Rect.fromLTRB(contact.reduce(math.min) - 4, -1.6, contact.reduce(math.max) + 4, 1.0),
    Paint()..color = Colors.black.withValues(alpha: 0.10),
  );
  move.props.draw(c, j, PropLayer.back);

  final s = f.limbScale;
  Paint stroke(Color c, double w) => Paint()
    ..color = c
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;

  void leg(Limbs l, {required bool far}) {
    Color shade(Color c) => far ? Color.lerp(c, Colors.black, 0.28)! : c;
    // Thigh and shin, then clothing over them.
    c.drawLine(l.hip, l.knee, stroke(shade(f.skin), 8.6));
    c.drawLine(l.knee, l.ankle, stroke(shade(f.skin), 6.4));
    final cover = f.legCover;
    final mid = Offset.lerp(l.hip, l.knee, math.min(cover, 1))!;
    c.drawLine(l.hip, mid, stroke(shade(f.bottom), 9.4));
    if (cover > 1) c.drawLine(l.knee, Offset.lerp(l.knee, l.ankle, cover - 1)!, stroke(shade(f.bottom), 7.0));
    if (cover > 1) c.drawCircle(l.knee, 4.4, Paint()..color = shade(f.bottom));
    // Shoe: heel to toe, with a coloured sole line.
    final shoe = Path()
      ..moveTo(l.heel.dx, l.heel.dy)
      ..lineTo(l.ankle.dx, l.ankle.dy)
      ..lineTo(l.toe.dx, l.toe.dy)
      ..lineTo(l.ball.dx, l.ball.dy)
      ..close();
    c.drawPath(shoe, stroke(shade(f.shoe), 4.2));
    c.drawPath(shoe, Paint()..color = shade(f.shoe));
    c.drawLine(l.heel, l.ball, stroke(shade(f.trim), 1.3));
  }

  void arm(Limbs l, {required bool far}) {
    Color shade(Color c) => far ? Color.lerp(c, Colors.black, 0.28)! : c;
    c.drawLine(l.shoulder, l.elbow, stroke(shade(f.skin), 5.6 * s));
    c.drawLine(l.elbow, l.hand, stroke(shade(f.skin), 4.6 * s));
    c.drawCircle(l.hand, 2.9 * s, Paint()..color = shade(f.skin));
  }

  arm(j.far, far: true);
  leg(j.far, far: true);
  move.props.draw(c, j, PropLayer.middle);

  // Torso: a tapered shape from the pelvis to the chest, a little deeper on the front.
  final up = (j.shoulder - j.hip) / torsoLen;
  final front = j.facing;
  final torso = Path()
    ..moveTo((j.hip - front * (f.waist * 0.45)).dx, (j.hip - front * (f.waist * 0.45)).dy);
  void to(Offset o) => torso.lineTo(o.dx, o.dy);
  void curve(Offset ctrl, Offset o) => torso.quadraticBezierTo(ctrl.dx, ctrl.dy, o.dx, o.dy);
  final backTop = j.shoulder - front * (f.chest * 0.42) - up * 1.5;
  curve(j.hip + up * 14 - front * (f.waist * 0.52), backTop);
  curve(j.shoulder + up * 3.2 - front * 1, j.shoulder + front * (f.chest * 0.38) + up * 0.8);
  curve(j.shoulder + front * (f.chest * 0.62) - up * 6, j.hip + up * 13 + front * (f.waist * 0.5));
  to(j.hip + front * (f.waist * 0.55) - up * 1.5);
  curve(j.hip - up * 4.5, j.hip - front * (f.waist * 0.45));
  torso.close();
  c.drawPath(torso, Paint()..color = f.top);
  // Waistband and the hip cap of the shorts or leggings.
  c.drawCircle(j.hip - up * 0.5, f.waist * 0.5, Paint()..color = f.bottom);
  c.drawLine(j.hip + up * 4 - front * (f.waist * 0.5), j.hip + up * 4 + front * (f.waist * 0.52), stroke(f.trim, 1.4));

  // Neck and head.
  final headUp = (j.head - j.shoulder) / neckLen;
  c.drawLine(j.shoulder + up * 1.5, j.head - headUp * 3, stroke(f.skin, 4.6));
  c.drawCircle(j.head, headR, Paint()..color = f.skin);
  final face = Offset(headUp.dy, -headUp.dx);
  // Nose, so the facing direction reads at small sizes.
  final nose = Path()
    ..moveTo((j.head + face * (headR - 0.4) + headUp * 1.2).dx, (j.head + face * (headR - 0.4) + headUp * 1.2).dy);
  void nTo(Offset o) => nose.lineTo(o.dx, o.dy);
  nTo(j.head + face * (headR + 1.4) - headUp * 0.6);
  nTo(j.head + face * (headR - 0.4) - headUp * 1.2);
  nose.close();
  c.drawPath(nose, Paint()..color = f.skin);
  // Hair: a cap over the back and top of the head.
  final hairRect = Rect.fromCircle(center: j.head, radius: headR + 0.6);
  final a0 = math.atan2(face.dy, face.dx);
  c.drawArc(hairRect, a0 + math.pi * 0.32, math.pi * 1.1, true, Paint()..color = f.hair);
  if (f.ponytail) {
    final base = j.head - face * (headR * 0.9) + headUp * (headR * 0.35);
    final tail = Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo((base - face * 6 + headUp * 1).dx, (base - face * 6 + headUp * 1).dy, (base - face * 5.5 - headUp * 8).dx,
          (base - face * 5.5 - headUp * 8).dy)
      ..quadraticBezierTo((base - face * 2 - headUp * 4).dx, (base - face * 2 - headUp * 4).dy, (base - headUp * 1.6).dx, (base - headUp * 1.6).dy)
      ..close();
    c.drawPath(tail, Paint()..color = f.hair);
    c.drawCircle(base, 1.4, Paint()..color = f.trim);
  }

  leg(j.near, far: false);
  move.props.draw(c, j, PropLayer.front);
  arm(j.near, far: false);
  move.props.draw(c, j, PropLayer.top);
}

/// Plays a move's animation in a loop from code (no network, no files). With the system setting to remove
/// animations, it shows the working position still.
class MoveAnimationView extends StatefulWidget {
  const MoveAnimationView(this.move, {super.key, this.label, this.figure});
  final MoveAnimation move;
  final String? label;
  final DemoFigure? figure; // null: follow [demoFigure]

  @override
  State<MoveAnimationView> createState() => _MoveAnimationViewState();
}

class _MoveAnimationViewState extends State<MoveAnimationView> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.move.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void didUpdateWidget(MoveAnimationView old) {
    super.didUpdateWidget(old);
    if (old.move != widget.move) _c.duration = widget.move.period;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: widget.label,
      image: true,
      child: RepaintBoundary(
        child: ValueListenableBuilder(
          valueListenable: demoFigure,
          builder: (_, f, _) => CustomPaint(
            size: Size.infinite,
            painter: MovePainter(widget.move, FigureStyle.of(widget.figure ?? f), still ? null : _c,
                pose: still ? widget.move.keys[widget.move.still].pose : null),
          ),
        ),
      ),
    );
  }
}
