import 'package:flutter/material.dart';

/// Colours from the vision document (Dungeon Realms - Game Vision).
abstract final class DR {
  static const bg = Color(0xff080b12);
  static const panel = Color(0xff111827);
  static const panelHi = Color(0xff1b2436);
  static const line = Color(0x1cffffff);
  static const text = Color(0xfff7f4e8);
  static const muted = Color(0xffaeb7c7);
  static const gold = Color(0xffffc94f);
  static const orange = Color(0xffff8a2b);
  static const green = Color(0xff82f16d);
  static const blue = Color(0xff4fd4ff);
  static const pink = Color(0xffff4bc8);
  static const purple = Color(0xff9f62ff);
  static const red = Color(0xffff5b4d);
  static const ink = Color(0xff1a1208);

  static Color tone(String tone) => switch (tone) {
    'green' => green,
    'blue' => blue,
    'red' => red,
    'pink' => pink,
    'purple' => purple,
    _ => gold,
  };

  static Color rarity(String id) => switch (id) {
    'uncommon' => const Color(0xff6fdc5a),
    'rare' => const Color(0xff4fa3ff),
    'epic' => const Color(0xffb26bff),
    'legendary' => const Color(0xffff9a2b),
    _ => const Color(0xffe8e6df),
  };

  static const titleFont = 'LilitaOne';
  static const bodyFont = 'Nunito';

  static TextStyle title(double size, {Color color = text}) => TextStyle(
    fontFamily: titleFont,
    fontSize: size,
    color: color,
    height: 1.0,
    shadows: const [Shadow(color: Color(0xcc000000), offset: Offset(0, 3), blurRadius: 6)],
  );

  static TextStyle body(double size, {Color color = text, FontWeight weight = FontWeight.w700}) =>
      TextStyle(fontFamily: bodyFont, fontSize: size, color: color, fontWeight: weight, height: 1.3);

  static BoxDecoration panelBox({double radius = 18, Color? border}) => BoxDecoration(
    gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xf0161d2c), Color(0xf00b0f18)]),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: border ?? line),
    boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 24, offset: Offset(0, 10))],
  );

  static const goldGradient = LinearGradient(colors: [gold, orange]);

  static ThemeData theme() => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    fontFamily: bodyFont,
    colorScheme: const ColorScheme.dark(primary: gold, secondary: orange, surface: panel),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontFamily: bodyFont, color: text),
    ),
    useMaterial3: true,
  );
}

/// Gold gradient call-to-action button (vision "cta-primary").
class GoldButton extends StatelessWidget {
  const GoldButton({super.key, required this.label, required this.onPressed, this.icon, this.compact = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              gradient: DR.goldGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [BoxShadow(color: Color(0x45ff8b2a), blurRadius: 24, offset: Offset(0, 10))],
            ),
            padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 22, vertical: compact ? 10 : 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, color: const Color(0xff271300), size: compact ? 18 : 20), const SizedBox(width: 8)],
                Text(
                  label,
                  style: DR.body(compact ? 14 : 16, color: const Color(0xff271300), weight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Translucent secondary button (vision "cta-ghost").
class GhostButton extends StatelessWidget {
  const GhostButton({super.key, required this.label, required this.onPressed, this.icon, this.compact = false, this.color});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool compact;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0x10ffffff),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color?.withValues(alpha: 0.5) ?? DR.line),
          ),
          padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 20, vertical: compact ? 9 : 13),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, color: color ?? DR.text, size: compact ? 17 : 19), const SizedBox(width: 8)],
              Text(
                label,
                style: DR.body(compact ? 14 : 15, color: color ?? DR.text, weight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
