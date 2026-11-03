import 'package:amlich_vietnam/astro/sun_moon.dart';
import 'package:flutter_test/flutter_test.dart';

// Reference values from the US Naval Observatory API (aa.usno.navy.mil/api/rstt/oneday, tz=7), read 2026-11-03.
void expectTime(DateTime? actual, int hour, int minute, int toleranceMinutes, String what) {
  expect(actual, isNotNull, reason: what);
  final diff = (actual!.hour * 60 + actual.minute - (hour * 60 + minute)).abs();
  expect(diff, lessThanOrEqualTo(toleranceMinutes), reason: '$what: $actual vs $hour:$minute');
}

void main() {
  const hanoi = City('Hà Nội', 21.0285, 105.8542);
  const saigon = City('TP. Hồ Chí Minh', 10.7769, 106.7009);

  test('sun and moon over Hà Nội on 3 and 20 November 2026', () {
    final d = sunMoonDay(DateTime(2026, 11, 3), hanoi);
    expectTime(d.sunrise, 6, 0, 2, 'sunrise');
    expectTime(d.sunset, 17, 20, 2, 'sunset');
    expectTime(d.moonrise, 0, 22, 6, 'moonrise');
    expectTime(d.moonset, 13, 28, 6, 'moonset');
    expect(d.illumination, closeTo(0.35, 0.04));
    expect(d.waxing, isFalse);

    final d20 = sunMoonDay(DateTime(2026, 11, 20), hanoi);
    expectTime(d20.sunrise, 6, 10, 2, 'sunrise 20/11');
    expectTime(d20.sunset, 17, 14, 2, 'sunset 20/11');
    expectTime(d20.moonset, 1, 34, 6, 'moonset 20/11');
    expectTime(d20.moonrise, 13, 53, 6, 'moonrise 20/11');
    expect(d20.illumination, closeTo(0.76, 0.04));
  });

  test('sun and moon over TP. Hồ Chí Minh on 21 June 2026', () {
    final d = sunMoonDay(DateTime(2026, 6, 21), saigon);
    expectTime(d.sunrise, 5, 32, 2, 'sunrise');
    expectTime(d.sunset, 18, 18, 2, 'sunset');
    expectTime(d.moonrise, 11, 19, 6, 'moonrise');
    expectTime(d.moonset, 23, 40, 6, 'moonset');
    expect(d.illumination, closeTo(0.43, 0.04));
  });

  test('next new and full moon (USNO: 9/11 14:02 and 24/11 21:53, UTC+7)', () {
    final from = DateTime(2026, 11, 3);
    final newMoon = nextPhase(from, 0);
    final fullMoon = nextPhase(from, 180);
    expect(newMoon.difference(DateTime(2026, 11, 9, 14, 2)).inMinutes.abs(), lessThan(90));
    expect(fullMoon.difference(DateTime(2026, 11, 24, 21, 53)).inMinutes.abs(), lessThan(90));
  });
}
