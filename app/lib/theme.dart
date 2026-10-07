// Levlofit theme. Values come from DESIGN.md sections 2 and 3; change them there first.
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'icons.dart';

const accent = Color(0xFFFF6A1A); // Levlofit Orange: fills only
const graphite = Color(0xFF0E0E10);
const cloud = Color(0xFFF0EEE9);

// Role mapping: primary = accent, secondary = ink, tertiary = accent-text,
// surfaceContainerHighest = surface-2, onSurfaceVariant = muted, outline = border.
const _light = ColorScheme(
  brightness: Brightness.light,
  primary: accent,
  onPrimary: graphite,
  secondary: graphite,
  onSecondary: cloud,
  tertiary: Color(0xFFB8420B),
  onTertiary: cloud,
  error: Color(0xFFB3261E),
  onError: Colors.white,
  surface: Colors.white,
  onSurface: graphite,
  surfaceContainerHighest: Color(0xFFE6E3DC),
  onSurfaceVariant: Color(0xFF5B5953),
  outline: Color(0xFFD9D5CC),
  outlineVariant: Color(0xFFD9D5CC),
);

const _dark = ColorScheme(
  brightness: Brightness.dark,
  primary: accent,
  onPrimary: graphite,
  secondary: cloud,
  onSecondary: graphite,
  tertiary: Color(0xFFFF8A4C),
  onTertiary: graphite,
  error: Color(0xFFF2766B),
  onError: graphite,
  surface: Color(0xFF18181B),
  onSurface: cloud,
  surfaceContainerHighest: Color(0xFF222226),
  onSurfaceVariant: Color(0xFF9A9690),
  outline: Color(0xFF2A2A2E),
  outlineVariant: Color(0xFF2A2A2E),
);

final lightTheme = _build(_light, cloud);
final darkTheme = _build(_dark, graphite);

/// Geist Mono uppercase label: 11 px, 0.14 em tracking. Pass the text already uppercased.
TextStyle monoLabel(BuildContext context) =>
    GoogleFonts.geistMono(fontSize: 11, letterSpacing: 1.54, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurfaceVariant);

/// Geist Mono with tabular figures, for numbers that change.
TextStyle monoNumber(BuildContext context, {double size = 28}) => GoogleFonts.geistMono(
  fontSize: size,
  fontWeight: FontWeight.w500,
  color: Theme.of(context).colorScheme.onSurface,
  fontFeatures: const [FontFeature.tabularFigures()],
);

/// Inputs get a visible label above them, never placeholder-only.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );
}

/// Error line: icon + text, never colour alone. Announced by screen readers.
class ErrorLine extends StatelessWidget {
  const ErrorLine(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(LvIcons.warningCircle, size: 18, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: color, fontSize: 14, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

/// UI motion: 150-250 ms, ease-out on enter, none under reduced motion.
Duration motion(BuildContext context, [int ms = 220]) => MediaQuery.disableAnimationsOf(context) ? Duration.zero : Duration(milliseconds: ms);

/// The brand ease (DESIGN.md, logo motion): fast start, long soft settle.
const spring = Cubic(0.32, 0.72, 0, 1);

/// Fades and lifts its child into place once, staggered by [index] so lists arrive in order.
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    final d = motion(context, 520 + 60 * index.clamp(0, 8));
    if (d == Duration.zero) return child;
    // The stagger lives in the curve: each later item waits a little longer inside the same timeline.
    final delay = (60 * index.clamp(0, 8)) / d.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: d,
      curve: Interval(delay, 1, curve: spring),
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 18 * (1 - v)), child: c),
      ),
      child: child,
    );
  }
}

/// Wraps each item in a [Reveal], skipping plain spacers so the stagger counts only real content.
List<Widget> staggered(List<Widget> items) {
  var i = 0;
  return [for (final w in items) w is SizedBox && w.child == null ? w : Reveal(index: i++, child: w)];
}

/// Counts a number up from zero on first build. Keeps any decimals the value has.
class CountUp extends StatelessWidget {
  const CountUp(this.value, {super.key, required this.style});
  final String value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final n = num.tryParse(value);
    final d = motion(context, 900);
    if (n == null || d == Duration.zero) return Text(value, style: style);
    final decimals = value.contains('.') ? value.split('.').last.length : 0;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: n.toDouble()),
      duration: d,
      curve: spring,
      builder: (_, v, _) => Text(v.toStringAsFixed(decimals), style: style.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
    );
  }
}

/// Presses in slightly under the finger, like a physical key.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child});
  final Widget child;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) => setState(() => _down = v);

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _set(true),
    onPointerUp: (_) => _set(false),
    onPointerCancel: (_) => _set(false),
    child: AnimatedScale(scale: _down ? 0.98 : 1, duration: motion(context, 140), curve: Curves.easeOutCubic, child: widget.child),
  );
}

/// Page change: the new page rises a few pixels and fades in on the brand ease; no sideways slide.
class _RiseTransitions extends PageTransitionsBuilder {
  const _RiseTransitions();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> a, Animation<double> b, Widget child) {
    final inCurve = CurvedAnimation(parent: a, curve: spring, reverseCurve: Curves.easeInCubic);
    final outCurve = CurvedAnimation(parent: b, curve: spring);
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.6).animate(outCurve),
      child: FadeTransition(
        opacity: inCurve,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(inCurve),
          child: child,
        ),
      ),
    );
  }
}

ThemeData _build(ColorScheme c, Color bg) {
  final r12 = BorderRadius.circular(12);
  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
    borderRadius: r12,
    borderSide: BorderSide(color: color, width: width),
  );

  final text = GoogleFonts.geistTextTheme(ThemeData(brightness: c.brightness).textTheme)
      .copyWith(
        headlineMedium: GoogleFonts.geist(fontSize: 30, height: 1.1, fontWeight: FontWeight.w700, letterSpacing: -0.75),
        titleLarge: GoogleFonts.geist(fontSize: 22, height: 1.2, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        titleMedium: GoogleFonts.geist(fontSize: 17, height: 1.3, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.geist(fontSize: 16, height: 1.5),
        bodyMedium: GoogleFonts.geist(fontSize: 15, height: 1.5),
        labelLarge: GoogleFonts.geist(fontSize: 14, height: 1.3, fontWeight: FontWeight.w600),
        bodySmall: GoogleFonts.geist(fontSize: 13, height: 1.45),
      )
      .apply(bodyColor: c.onSurface, displayColor: c.onSurface);

  return ThemeData(
    colorScheme: c,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _RiseTransitions(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(), // keeps the iOS back swipe
        TargetPlatform.windows: _RiseTransitions(),
        TargetPlatform.macOS: _RiseTransitions(),
        TargetPlatform.linux: _RiseTransitions(),
        TargetPlatform.fuchsia: _RiseTransitions(),
      },
    ),
    scaffoldBackgroundColor: bg,
    textTheme: text,
    appBarTheme: AppBarTheme(backgroundColor: bg, foregroundColor: c.onSurface, elevation: 0, scrolledUnderElevation: 0),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        disabledBackgroundColor: c.surfaceContainerHighest,
        disabledForegroundColor: c.onSurfaceVariant,
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: r12),
        textStyle: GoogleFonts.geist(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.onSurface,
        side: BorderSide(color: c.onSurface),
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: r12),
        textStyle: GoogleFonts.geist(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.onSurface,
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: r12),
        textStyle: GoogleFonts.geist(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: c.onSurfaceVariant),
      border: border(c.outline),
      enabledBorder: border(c.outline),
      focusedBorder: border(c.onSurface, 1.5),
      errorBorder: border(c.error, 1.5),
      focusedErrorBorder: border(c.error, 1.5),
      errorStyle: TextStyle(color: c.error, fontSize: 13),
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.outline),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary, linearTrackColor: c.surfaceContainerHighest),
    dividerTheme: DividerThemeData(color: c.outline, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.onSurface,
      contentTextStyle: GoogleFonts.geist(color: c.surface, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: r12),
    ),
  );
}
