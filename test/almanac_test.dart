import 'package:amlich_vietnam/data/people.dart';
import 'package:amlich_vietnam/lunar/almanac.dart';
import 'package:amlich_vietnam/widgets/good_days_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  // Expected values were read from quantrimang.com/lich-am/<date> on 2026-11-02.
  test('trực, mansion and directions match a published almanac', () {
    final expected = {
      DateTime(2024, 2, 10): ('Mãn', 'Đê Thổ Lạc', 'Đông Bắc', 'Đông Nam'),
      DateTime(2026, 3, 15): ('Thu', 'Hư Nhật Thử', 'Đông Nam', 'Chính Bắc'),
      DateTime(2026, 3, 16): ('Khai', 'Nguy Nguyệt Yến', 'Đông Bắc', 'Chính Nam'),
      DateTime(2026, 3, 17): ('Bế', 'Thất Hỏa Trư', null, null),
      DateTime(2026, 11, 2): ('Phá', 'Tất Nguyệt Ô', 'Tây Bắc', 'Tây Nam'),
      DateTime(2026, 11, 3): ('Nguy', 'Chủy Hỏa Hầu', 'Tây Nam', 'Tây Nam'),
      DateTime(2026, 11, 4): ('Thành', 'Sâm Thủy Viên', null, null),
      DateTime(2026, 11, 7): ('Khai', null, null, null), // Lập đông: the term day already uses the new month
      DateTime(2026, 11, 9): ('Kiến', null, null, null),
      DateTime(2026, 11, 10): ('Trừ', 'Dực Hỏa Xà', null, null),
      DateTime(2026, 11, 12): ('Bình', null, null, null),
      DateTime(2026, 11, 13): ('Định', null, null, null),
      DateTime(2026, 11, 14): ('Chấp', null, null, null),
    };
    expected.forEach((date, e) {
      final a = DayAlmanac(date);
      expect(a.truc.name, e.$1, reason: '$date trực');
      if (e.$2 != null) expect(a.mansion.$1, e.$2, reason: '$date sao');
      if (e.$3 != null) expect(a.hyThan, e.$3, reason: '$date hỷ thần');
      if (e.$4 != null) expect(a.taiThan, e.$4, reason: '$date tài thần');
    });
  });

  test('mansion good/bad classes match the almanac', () {
    final good = {DateTime(2026, 11, 2): true, DateTime(2026, 11, 4): true, DateTime(2026, 3, 17): true};
    final bad = [3, 8, 10, 16, 21, 26, 29].map((d) => DateTime(2026, 11, d));
    good.forEach((d, g) => expect(DayAlmanac(d).mansion.$2, g, reason: '$d'));
    for (final d in bad) {
      expect(DayAlmanac(d).mansion.$2, isFalse, reason: '$d');
    }
    expect(mansions.where((m) => m.$2), hasLength(14));
  });

  test('clashes and harmonies', () {
    final a = DayAlmanac(DateTime(2026, 11, 2)); // Canh Thìn
    expect(a.clashesWith(1994), isTrue); // Giáp Tuất
    expect(a.clashesWith(1990), isFalse);
    expect(sixHarmonyOf(0), 1); // Tý–Sửu
    expect(sixHarmonyOf(4), 9); // Thìn–Dậu
    expect(tripleHarmonyOf(8), [0, 4]); // Thân–Tý–Thìn
    expect(fourClashOf(2), [2, 5, 8, 11]); // Dần Tỵ Thân Hợi
  });

  test('age info', () {
    expect(AgeInfo(1984).napAm, 'Hải Trung Kim');
    expect(AgeInfo(1990).canChi, 'Canh Ngọ');
    expect(AgeInfo(1990).napAm, 'Lộ Bàng Thổ');
    expect(AgeInfo(1990).element, 'Thổ');
    expect(AgeInfo(1990).ageIn(2026), 37);
    expect(AgeInfo(1954).napAm, 'Sa Trung Kim');
    expect(AgeInfo(1990).fourClash, ['Tý', 'Mão', 'Dậu']);
  });

  test('good days avoid bad days and clashing ages', () {
    final from = DateTime(2026, 11, 1);
    final to = DateTime(2026, 12, 31);
    final days = findGoodDays(Activity.wedding, from, to, [1994]);
    expect(days, isNotEmpty);
    for (final d in days) {
      expect(d.almanac.star.isGood, isTrue);
      expect(d.almanac.tamNuong || d.almanac.nguyetKy, isFalse);
      expect(d.almanac.truc.bad, isNot(contains(Activity.wedding)));
      expect(d.almanac.clashesWith(1994), isFalse);
    }
    // Best first.
    expect(days.first.score, greaterThanOrEqualTo(days.last.score));
  });

  testWidgets('family ages show clash warnings on the calendar and good-day search runs', (tester) async {
    usePhoneScreen(tester);
    // Today clashes with someone born in the year whose branch is opposite today's.
    final branchToday = DayAlmanac(DateTime.now()).clashBranch;
    final birthYear = [for (var y = 1960; y < 1972; y++) y].firstWhere((y) => yearBranch(y) == branchToday);
    await tester.pumpWidget(
      await testApp(
        people: [Person(name: 'Bố', birthYear: birthYear)],
      ),
    );
    await tester.dragUntilVisible(find.text('Xem ngày'), find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.textContaining('Xung tuổi Bố'), findsOneWidget);

    await tester.tap(find.text('Tiện ích').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tìm ngày'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tìm ngày'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ngày phù hợp'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
