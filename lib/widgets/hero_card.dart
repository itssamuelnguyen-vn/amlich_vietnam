import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/settings.dart';
import '../lunar/format.dart';
import '../lunar/holidays.dart';
import '../lunar/lunar_calendar.dart';
import '../lunar/proverbs.dart';
import '../theme.dart';
import 'moon_phase.dart';

/// The big calendar page ("tờ lịch") of the selected day, like a page of a Vietnamese tear-off calendar.
/// Swipe left or right for the next or previous day.
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.date,
    required this.isToday,
    required this.onPrev,
    required this.onNext,
    this.captureKey,
    this.onShare,
  });

  final DateTime date;
  final bool isToday;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  /// Key of the RepaintBoundary around the page, for sharing it as an image (the share button is outside it).
  final GlobalKey? captureKey;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final lich = context.lich;
    final page = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [lich.heroTop, lich.heroBottom],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeIn,
          // A tear-off calendar: the new page flips down from the top edge while the old one fades away.
          transitionBuilder: (child, anim) {
            final incoming = child.key == ValueKey(date);
            if (!incoming) return FadeTransition(opacity: anim, child: child);
            return AnimatedBuilder(
              animation: anim,
              child: child,
              builder: (context, child) => Transform(
                alignment: Alignment.topCenter,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..rotateX((1 - anim.value) * -math.pi / 2),
                child: child,
              ),
            );
          },
          child: _HeroContent(key: ValueKey(date), date: date, isToday: isToday),
        ),
      ),
    );
    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -150) onNext();
        if (v > 150) onPrev();
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: lich.heroBottom.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10)),
          ],
        ),
        child: Stack(
          children: [
            RepaintBoundary(key: captureKey, child: page),
            if (onShare != null)
              Positioned(
                right: 6,
                bottom: 6,
                child: IconButton(
                  tooltip: 'Chia sẻ tờ lịch',
                  onPressed: onShare,
                  icon: Icon(Icons.ios_share_rounded, color: lich.onHero.withValues(alpha: 0.85), size: 20),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeroContent extends StatelessWidget {
  const _HeroContent({super.key, required this.date, required this.isToday});

  final DateTime date;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final lich = context.lich;
    final lunar = solarToLunar(date);
    final star = dayStarOf(date, lunar);
    final holidays = holidaysOf(date, lunar, kinds: SettingsScope.of(context).value.holidayKinds);
    final onHero = lich.onHero;
    final soft = onHero.withValues(alpha: 0.75);
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.1;
    final canChi = [
      _CanChi('Năm', canChiYear(lunar.year), onHero, soft),
      _CanChi('Tháng', canChiMonth(lunar.month, lunar.year), onHero, soft),
      _CanChi('Ngày', canChiDay(date), onHero, soft),
    ];

    return Stack(
      children: [
        // Decorations: the year's animal in the corner and the binding holes of a tear-off calendar.
        Positioned(
          right: -24,
          bottom: -36,
          child: Opacity(opacity: 0.14, child: Text(yearAnimal(lunar.year), style: const TextStyle(fontSize: 170))),
        ),
        Positioned(
          top: 10,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 2; i++)
                Container(
                  width: 34,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'THÁNG ${date.month} · ${date.year}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: lich.gold, fontWeight: FontWeight.w700, letterSpacing: 2, fontSize: 13),
                    ),
                  ),
                  if (isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: lich.gold, borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        'HÔM NAY',
                        style: TextStyle(
                          color: lich.heroBottom,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 100,
                      height: 1.05,
                      fontWeight: FontWeight.w700,
                      color: onHero,
                      shadows: [
                        Shadow(color: Colors.black.withValues(alpha: 0.25), offset: const Offset(0, 3), blurRadius: 8),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          weekdayNames[date.weekday - 1],
                          style: TextStyle(color: onHero, fontSize: 24, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text('Tiết ${tietKhiOf(date)}', style: TextStyle(color: soft, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(vertical: 10),
                color: lich.gold.withValues(alpha: 0.35),
              ),
              Row(
                children: [
                  MoonPhase(
                    lunarDay: lunar.day,
                    size: 46,
                    lit: lich.gold,
                    shadow: Colors.black.withValues(alpha: 0.35),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ÂM LỊCH', style: TextStyle(color: lich.gold, fontSize: 11, letterSpacing: 1.5)),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${lunar.day} ',
                                style: const TextStyle(fontFamily: 'serif', fontSize: 30, fontWeight: FontWeight.w700),
                              ),
                              TextSpan(text: lunarMonthName(lunar), style: const TextStyle(fontSize: 16)),
                            ],
                          ),
                          style: TextStyle(color: onHero, height: 1.1),
                        ),
                      ],
                    ),
                  ),
                  if (!largeText) Column(crossAxisAlignment: CrossAxisAlignment.end, children: canChi),
                ],
              ),
              // With large text the stem-branch column no longer fits beside the lunar date, so it moves below.
              if (largeText)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(spacing: 14, runSpacing: 2, children: canChi),
                ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Pill(
                    icon: star.isGood ? Icons.auto_awesome : Icons.remove_circle_outline,
                    text: '${star.isGood ? 'Hoàng đạo' : 'Hắc đạo'} · ${star.name}',
                    background: star.isGood ? lich.gold : Colors.black.withValues(alpha: 0.28),
                    foreground: star.isGood ? lich.heroBottom : onHero,
                  ),
                  for (final h in holidays)
                    _Pill(icon: Icons.celebration, text: h, background: onHero, foreground: lich.heroTop),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.format_quote_rounded, color: lich.gold, size: 22),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      proverbOf(date),
                      style: TextStyle(color: soft, fontStyle: FontStyle.italic, fontSize: 14, height: 1.35),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CanChi extends StatelessWidget {
  const _CanChi(this.label, this.value, this.color, this.soft);

  final String label;
  final String value;
  final Color color;
  final Color soft;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: '$label ',
          style: TextStyle(color: soft, fontSize: 12),
        ),
        TextSpan(
          text: value,
          style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, required this.background, required this.foreground});

  final IconData icon;
  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: foreground),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: foreground, fontWeight: FontWeight.w700, fontSize: 12.5),
          ),
        ),
      ],
    ),
  );
}
