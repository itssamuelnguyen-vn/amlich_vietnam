import 'package:flutter/material.dart';

/// Colours of the tear-off calendar look: lacquer red and gold.
class LichColors extends ThemeExtension<LichColors> {
  const LichColors({
    required this.gold,
    required this.heroTop,
    required this.heroBottom,
    required this.onHero,
    required this.holiday,
    required this.goodDay,
  });

  final Color gold;
  final Color heroTop;
  final Color heroBottom;
  final Color onHero;
  final Color holiday;

  /// Marks auspicious (hoàng đạo) days on the normal background (the hero's [gold] is too light for the light theme).
  final Color goodDay;

  @override
  LichColors copyWith({
    Color? gold,
    Color? heroTop,
    Color? heroBottom,
    Color? onHero,
    Color? holiday,
    Color? goodDay,
  }) => LichColors(
    gold: gold ?? this.gold,
    heroTop: heroTop ?? this.heroTop,
    heroBottom: heroBottom ?? this.heroBottom,
    onHero: onHero ?? this.onHero,
    holiday: holiday ?? this.holiday,
    goodDay: goodDay ?? this.goodDay,
  );

  @override
  LichColors lerp(LichColors? other, double t) {
    if (other == null) return this;
    return LichColors(
      gold: Color.lerp(gold, other.gold, t)!,
      heroTop: Color.lerp(heroTop, other.heroTop, t)!,
      heroBottom: Color.lerp(heroBottom, other.heroBottom, t)!,
      onHero: Color.lerp(onHero, other.onHero, t)!,
      holiday: Color.lerp(holiday, other.holiday, t)!,
      goodDay: Color.lerp(goodDay, other.goodDay, t)!,
    );
  }
}

extension LichTheme on BuildContext {
  LichColors get lich => Theme.of(this).extension<LichColors>()!;
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFFB3261E), brightness: brightness).copyWith(
    primary: dark ? const Color(0xFFFF8E80) : const Color(0xFFB3261E),
    onPrimary: dark ? const Color(0xFF4A0B07) : Colors.white,
    surface: dark ? const Color(0xFF140E0C) : const Color(0xFFF8F1E7),
    surfaceContainerLow: dark ? const Color(0xFF211714) : const Color(0xFFFFFAF3),
    surfaceContainer: dark ? const Color(0xFF2B1F1B) : const Color(0xFFF3E8DA),
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
    ),
    extensions: [
      LichColors(
        gold: dark ? const Color(0xFFE9C46A) : const Color(0xFFF6D27A),
        heroTop: dark ? const Color(0xFF6B1E17) : const Color(0xFFC62828),
        heroBottom: dark ? const Color(0xFF2E0D0A) : const Color(0xFF7F1212),
        onHero: const Color(0xFFFFF4E6),
        holiday: dark ? const Color(0xFFFF8E80) : const Color(0xFFC62828),
        goodDay: dark ? const Color(0xFFE9C46A) : const Color(0xFFC08A1E),
      ),
    ],
  );
}
