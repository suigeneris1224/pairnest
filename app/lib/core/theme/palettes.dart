import 'package:flutter/material.dart';

/// A couple-selectable color theme. Exposed to widgets as a [ThemeExtension]
/// so any widget can read it with `context.pn`.
@immutable
class PairnestPalette extends ThemeExtension<PairnestPalette> {
  const PairnestPalette({
    required this.id,
    required this.name,
    required this.tagline,
    required this.primary,
    required this.primaryDeep,
    required this.soft,
    required this.accent,
    required this.background,
    required this.surface,
    required this.text,
    required this.muted,
    required this.border,
    required this.birdA,
    required this.birdB,
    required this.heading,
    this.isDark = false,
  });

  final String id;
  final String name;
  final String tagline;
  final Color primary;
  final Color primaryDeep;
  final Color soft;
  final Color accent;
  final Color background;
  final Color surface;
  final Color text;
  final Color muted;
  final Color border;
  final Color birdA;
  final Color birdB;

  /// Deep tone for headings, e.g. the names on Home.
  final Color heading;
  final bool isDark;

  Color get onPrimary => isDark ? const Color(0xFF141A2A) : Colors.white;

  @override
  PairnestPalette copyWith() => this;

  /// Blends every color so switching themes crossfades smoothly.
  @override
  PairnestPalette lerp(covariant PairnestPalette? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    final next = t < 0.5 ? this : other;
    return PairnestPalette(
      id: next.id,
      name: next.name,
      tagline: next.tagline,
      primary: mix(primary, other.primary),
      primaryDeep: mix(primaryDeep, other.primaryDeep),
      soft: mix(soft, other.soft),
      accent: mix(accent, other.accent),
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      text: mix(text, other.text),
      muted: mix(muted, other.muted),
      border: mix(border, other.border),
      birdA: mix(birdA, other.birdA),
      birdB: mix(birdB, other.birdB),
      heading: mix(heading, other.heading),
      isDark: next.isDark,
    );
  }
}

const _cream = Color(0xFFF8F2E7);
const _paper = Color(0xFFFFFCF6);
const _ink = Color(0xFF2D3A32);
const _inkMuted = Color(0xFF7D857E);
const _line = Color(0xFFEDE5D6);
const _peach = Color(0xFFF2A27E);
const _sage = Color(0xFF6F9B7A);

const sagePalette = PairnestPalette(
  id: 'sage',
  name: 'Sage Green',
  tagline: 'Calm & balanced',
  primary: Color(0xFF5B8C6E),
  primaryDeep: Color(0xFF3E7055),
  soft: Color(0xFFE3EDE2),
  accent: _peach,
  background: _cream,
  surface: _paper,
  text: _ink,
  muted: _inkMuted,
  border: _line,
  birdA: Color(0xFF2E7D57),
  birdB: Color(0xFF6DB38B),
  heading: Color(0xFF24443F),
);

const oceanPalette = PairnestPalette(
  id: 'ocean',
  name: 'Ocean Blue',
  tagline: 'Fresh & peaceful',
  primary: Color(0xFF4A86C0),
  primaryDeep: Color(0xFF2F6A9F),
  soft: Color(0xFFDDEAF6),
  accent: _peach,
  background: Color(0xFFF6F4EE),
  surface: _paper,
  text: Color(0xFF26364A),
  muted: Color(0xFF7A8594),
  border: Color(0xFFE6E4DC),
  birdA: Color(0xFF2F6EA8),
  birdB: Color(0xFF78AEDC),
  heading: Color(0xFF1F3A57),
);

const lavenderPalette = PairnestPalette(
  id: 'lavender',
  name: 'Lavender',
  tagline: 'Soft & romantic',
  primary: Color(0xFF9077BF),
  primaryDeep: Color(0xFF6F559F),
  soft: Color(0xFFECE3F6),
  accent: _peach,
  background: Color(0xFFF8F3EE),
  surface: _paper,
  text: Color(0xFF3A3047),
  muted: Color(0xFF857D90),
  border: Color(0xFFEDE4E4),
  birdA: Color(0xFF6F559F),
  birdB: Color(0xFFA993D1),
  heading: Color(0xFF3E2F5C),
);

const peachPalette = PairnestPalette(
  id: 'peach',
  name: 'Peach',
  tagline: 'Warm & cheerful',
  primary: Color(0xFFE3845F),
  primaryDeep: Color(0xFFC4653F),
  soft: Color(0xFFFBE4D7),
  accent: _sage,
  background: Color(0xFFFAF2E8),
  surface: _paper,
  text: Color(0xFF45302A),
  muted: Color(0xFF8F7D76),
  border: Color(0xFFF0E1D4),
  birdA: Color(0xFFD06A45),
  birdB: Color(0xFFF0A27E),
  heading: Color(0xFF5A3426),
);

const midnightPalette = PairnestPalette(
  id: 'midnight',
  name: 'Midnight',
  tagline: 'Bold & modern',
  primary: Color(0xFF8EA9E0),
  primaryDeep: Color(0xFF8EA9E0),
  soft: Color(0xFF2C3654),
  accent: _peach,
  background: Color(0xFF161C2C),
  surface: Color(0xFF20283D),
  text: Color(0xFFEEF0F6),
  muted: Color(0xFF9AA3B8),
  border: Color(0xFF2F3953),
  birdA: Color(0xFF4F6FB0),
  birdB: Color(0xFF8EA9E0),
  heading: Color(0xFFEEF0F6),
  isDark: true,
);

const allPalettes = [sagePalette, oceanPalette, lavenderPalette, peachPalette, midnightPalette];

PairnestPalette paletteById(String? id) => allPalettes.firstWhere((p) => p.id == id, orElse: () => sagePalette);

extension PairnestThemeX on BuildContext {
  PairnestPalette get pn => Theme.of(this).extension<PairnestPalette>()!;
}
