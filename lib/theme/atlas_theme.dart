import 'package:flutter/material.dart';

@immutable
class AtlasPalette extends ThemeExtension<AtlasPalette> {
  const AtlasPalette({
    required this.page,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceMuted,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.input,
    required this.accent,
    required this.warningSurface,
    required this.warningBorder,
    required this.warningText,
  });

  final Color page;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceMuted;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color input;
  final Color accent;
  final Color warningSurface;
  final Color warningBorder;
  final Color warningText;

  static const dark = AtlasPalette(
    page: Color(0xFF0B1215),
    surface: Color(0xFF121D20),
    surfaceRaised: Color(0xFF172326),
    surfaceMuted: Color(0xFF131E21),
    border: Color(0xFF223236),
    textPrimary: Color(0xFFEAF2EE),
    textSecondary: Color(0xFFB6C8C2),
    textMuted: Color(0xFF8EA39C),
    input: Color(0xFF121D20),
    accent: Color(0xFF72D6C2),
    warningSurface: Color(0xFF211F19),
    warningBorder: Color(0xFF49402B),
    warningText: Color(0xFFC6B98F),
  );

  static const light = AtlasPalette(
    page: Color(0xFFF4F7F5),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF9FBFA),
    surfaceMuted: Color(0xFFEBF1EE),
    border: Color(0xFFD5E0DA),
    textPrimary: Color(0xFF182821),
    textSecondary: Color(0xFF425B51),
    textMuted: Color(0xFF60746C),
    input: Color(0xFFFFFFFF),
    accent: Color(0xFF176D5D),
    warningSurface: Color(0xFFFFF7E3),
    warningBorder: Color(0xFFE6D5A3),
    warningText: Color(0xFF6D571F),
  );

  static AtlasPalette of(BuildContext context) =>
      Theme.of(context).extension<AtlasPalette>() ?? dark;

  @override
  AtlasPalette copyWith({
    Color? page,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceMuted,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? input,
    Color? accent,
    Color? warningSurface,
    Color? warningBorder,
    Color? warningText,
  }) =>
      AtlasPalette(
        page: page ?? this.page,
        surface: surface ?? this.surface,
        surfaceRaised: surfaceRaised ?? this.surfaceRaised,
        surfaceMuted: surfaceMuted ?? this.surfaceMuted,
        border: border ?? this.border,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textMuted: textMuted ?? this.textMuted,
        input: input ?? this.input,
        accent: accent ?? this.accent,
        warningSurface: warningSurface ?? this.warningSurface,
        warningBorder: warningBorder ?? this.warningBorder,
        warningText: warningText ?? this.warningText,
      );

  @override
  AtlasPalette lerp(ThemeExtension<AtlasPalette>? other, double t) {
    if (other is! AtlasPalette) return this;
    return AtlasPalette(
      page: Color.lerp(page, other.page, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      input: Color.lerp(input, other.input, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      warningSurface: Color.lerp(warningSurface, other.warningSurface, t)!,
      warningBorder: Color.lerp(warningBorder, other.warningBorder, t)!,
      warningText: Color.lerp(warningText, other.warningText, t)!,
    );
  }
}

class AtlasThemes {
  static ThemeData dark() => _create(Brightness.dark, AtlasPalette.dark);
  static ThemeData light() => _create(Brightness.light, AtlasPalette.light);

  static ThemeData _create(Brightness brightness, AtlasPalette palette) {
    final scheme = ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: brightness,
      surface: palette.surface,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: palette.page,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: palette.textPrimary,
      ),
      textTheme: ThemeData(brightness: brightness).textTheme.apply(
            bodyColor: palette.textPrimary,
            displayColor: palette.textPrimary,
          ),
      sliderTheme: const SliderThemeData(trackHeight: 3),
      extensions: [palette],
    );
  }
}

extension AtlasBuildContext on BuildContext {
  AtlasPalette get atlas => AtlasPalette.of(this);
}
