import 'package:amlich_vietnam/weather/weather.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// A real Open-Meteo response for Hà Nội, 2026-11-03 (trimmed to 3 days).
const _sample = '''
{"latitude":21.05448,"longitude":105.898476,"utc_offset_seconds":25200,"timezone":"Asia/Bangkok",
"daily":{"time":["2026-11-03","2026-11-04","2026-11-05"],"weather_code":[53,51,95],
"temperature_2m_max":[29.3,31.0,30.8],"temperature_2m_min":[23.2,23.8,24.5],
"precipitation_probability_max":[97,20,87]}}''';

void main() {
  test('parses an Open-Meteo daily forecast', () {
    final days = parseForecast(_sample);
    expect(days, hasLength(3));
    expect(days.first.date, DateTime(2026, 11, 3));
    expect(days.first.description, 'Mưa phùn');
    expect(days.first.range, '23–29°C');
    expect(days.first.rain, 97);
    expect(days.last.description, 'Dông');
  });

  test('every WMO code has a Vietnamese description', () {
    for (final code in [0, 1, 2, 3, 45, 48, 51, 61, 63, 65, 71, 80, 82, 95, 99]) {
      expect(weatherOf(code).$2, isNot('Không rõ'), reason: '$code');
    }
  });

  testWidgets('without a network the weather card offers a retry and nothing breaks', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(await testApp());
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(find.text('Thời tiết'), find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('Thử lại'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
