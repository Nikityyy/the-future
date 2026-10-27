import 'package:flutter/widgets.dart';

/// Warm cream ground, deep ink, one navy for actions and one green for growth.
class C {
  const C._();

  static const ground = Color(0xFFF8F5EC);
  static const raised = Color(0xFFFFFDF8);
  static const ink = Color(0xFF16170F);
  static const ink2 = Color(0xFF6A695C);
  static const ink3 = Color(0xFFA09E8E);
  static const rule = Color(0x1F16170F);
  static const fill = Color(0x14343426);
  static const navy = Color(0xFF263248);
  static const green = Color(0xFF4A8B5A);
  static const greenInk = Color(0xFF2F6B40);
  static const greenSoft = Color(0xFFD9E7D6);
  static const loss = Color(0xFFA8432F);
  static const sand = Color(0xFFC7B58C);
  static const slate = Color(0xFF6C7A93);
}

const _serifFeatures = [FontFeature.tabularFigures()];

TextStyle serif(double size, {FontWeight weight = FontWeight.w400, Color color = C.ink, double? tracking, double height = 1.05, FontStyle style = FontStyle.normal}) =>
    TextStyle(
      fontFamily: 'Newsreader',
      fontSize: size,
      color: color,
      height: height,
      fontStyle: style,
      letterSpacing: tracking ?? -size * 0.025,
      fontVariations: [FontVariation('wght', weight.value.toDouble()), FontVariation('opsz', size.clamp(6, 72).toDouble())],
      decoration: TextDecoration.none,
    );

TextStyle sans(double size, {FontWeight weight = FontWeight.w400, Color color = C.ink, double height = 1.3, double tracking = 0}) => TextStyle(
      fontFamily: 'Geist',
      fontSize: size,
      color: color,
      height: height,
      letterSpacing: tracking,
      fontVariations: [FontVariation('wght', weight.value.toDouble())],
      decoration: TextDecoration.none,
    );

/// Serif numerals that keep their width, so a counting number does not jitter.
TextStyle figures(TextStyle s) => s.copyWith(fontFeatures: _serifFeatures);
