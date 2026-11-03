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

/// Colour themes the user can pick. Holidays stay red in every one.
enum AppPalette {
  son(
    'Đỏ son',
    Color(0xFFB3261E),
    Color(0xFFFF8E80),
    (Color(0xFFC62828), Color(0xFF7F1212)),
    (Color(0xFF6B1E17), Color(0xFF2E0D0A)),
  ),
  ngoc(
    'Xanh ngọc',
    Color(0xFF00796B),
    Color(0xFF4DB6AC),
    (Color(0xFF00897B), Color(0xFF004D40)),
    (Color(0xFF00564C), Color(0xFF00201C)),
  ),
  lam(
    'Xanh lam',
    Color(0xFF1565C0),
    Color(0xFF90CAF9),
    (Color(0xFF1E88E5), Color(0xFF0D47A1)),
    (Color(0xFF123E73), Color(0xFF07172C)),
  ),
  tim(
    'Tím',
    Color(0xFF6A1B9A),
    Color(0xFFCE93D8),
    (Color(0xFF8E24AA), Color(0xFF4A148C)),
    (Color(0xFF4A1660), Color(0xFF1C0826)),
  ),
  dong(
    'Vàng đồng',
    Color(0xFF8D5A00),
    Color(0xFFFFC46B),
    (Color(0xFFB07A12), Color(0xFF5E3D00)),
    (Color(0xFF5C4300), Color(0xFF241A00)),
  );

  const AppPalette(this.label, this.primary, this.primaryDark, this.hero, this.heroDark);

  final String label;
  final Color primary;
  final Color primaryDark;

  /// Day-page gradient (top-left, bottom-right) in the light and dark themes.
  final (Color, Color) hero;
  final (Color, Color) heroDark;
}

ThemeData buildTheme(Brightness brightness, [AppPalette palette = AppPalette.son]) {
  final dark = brightness == Brightness.dark;
  final primary = dark ? palette.primaryDark : palette.primary;
  final scheme = ColorScheme.fromSeed(seedColor: palette.primary, brightness: brightness).copyWith(
    primary: primary,
    onPrimary: dark ? Color.lerp(primary, Colors.black, 0.75) : Colors.white,
    surface: dark ? const Color(0xFF140E0C) : const Color(0xFFF8F1E7),
    surfaceContainerLow: dark ? const Color(0xFF211714) : const Color(0xFFFFFAF3),
    surfaceContainer: dark ? const Color(0xFF2B1F1B) : const Color(0xFFF3E8DA),
  );
  final hero = dark ? palette.heroDark : palette.hero;
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
        // On the bronze page plain gold would not stand out, so it gets a paler cream gold.
        gold: palette == AppPalette.dong
            ? const Color(0xFFFFF0C2)
            : (dark ? const Color(0xFFE9C46A) : const Color(0xFFF6D27A)),
        heroTop: hero.$1,
        heroBottom: hero.$2,
        onHero: const Color(0xFFFFF4E6),
        holiday: dark ? const Color(0xFFFF8E80) : const Color(0xFFC62828),
        goodDay: dark ? const Color(0xFFE9C46A) : const Color(0xFFC08A1E),
      ),
    ],
  );
}
