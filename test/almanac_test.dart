import 'package:amlich_vietnam/data/people.dart';
import 'package:amlich_vietnam/lunar/almanac.dart';
import 'package:amlich_vietnam/lunar/lunar_calendar.dart';
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

  // Read from doanhnghiephoinhap.vn daily pages on 2026-11-03.
  test('Lý Thuần Phong travel hours match a published almanac', () {
    final cases = {
      DateTime(2026, 3, 12): (const LunarDate(24, 1, 2026), 'Không Vong'),
      DateTime(2025, 12, 21): (const LunarDate(2, 11, 2025), 'Không Vong'),
      DateTime(2026, 6, 10): (const LunarDate(25, 4, 2026), 'Xích Khẩu'),
    };
    cases.forEach((date, e) {
      final lunar = solarToLunar(date);
      expect(lunar, e.$1, reason: '$date');
      expect(lyThuanPhong[lyThuanPhongHours(lunar)[0]].$1, e.$2, reason: '$date giờ Tý');
    });
    // 25/4/2026: Sửu Tiểu Cát, Dần Không Vong, Mão Đại An, Thìn Tốc Hỷ, Tỵ Lưu Niên, and Ngọ repeats Tý.
    final hours = lyThuanPhongHours(const LunarDate(25, 4, 2026)).map((i) => lyThuanPhong[i].$1).toList();
    expect(hours.sublist(1, 7), ['Tiểu Cát', 'Không Vong', 'Đại An', 'Tốc Hỷ', 'Lưu Niên', 'Xích Khẩu']);
  });

  test('Bành Tổ lines for the stem and branch of the day', () {
    final a = DayAlmanac(DateTime(2025, 12, 21)); // Giáp Tý
    expect(banhToCan[a.dayStem].$1, startsWith('Giáp bất khai thương'));
    expect(banhToChi[a.dayBranch].$1, startsWith('Tý bất vấn bốc'));
    final b = DayAlmanac(DateTime(2026, 3, 12)); // Ất Dậu
    expect(banhToCan[b.dayStem].$2, contains('gieo trồng'));
    expect(banhToChi[b.dayBranch].$1, startsWith('Dậu bất hội khách'));
  });

  test('house building: Kim lâu, Hoang ốc, Tam tai', () {
    expect(hoangOc(10).$1, 'Nhất Cát');
    expect(hoangOc(24).$1, 'Lục Hoang Ốc');
    expect(hoangOc(25).$1, 'Nhất Cát');
    expect(hoangOc(28).$1, 'Tứ Tấn Tài');
    expect(hoangOc(33).$1, 'Lục Hoang Ốc');
    expect(kimLau(37), startsWith('Kim lâu thân'));
    expect(kimLau(39), startsWith('Kim lâu thê'));
    expect(kimLau(38), isNull);
    // Born 1990 (Ngọ): Tam tai in Thân, Dậu, Tuất years.
    expect(HouseCheck(1990, 2028).tamTai, isTrue);
    expect(HouseCheck(1990, 2026).tamTai, isFalse);
    expect(HouseCheck(1990, 2026).age, 37);
  });

  test('couple compatibility', () {
    final c = CoupleCheck(1990, 1992); // Canh Ngọ (Thổ) and Nhâm Thân (Kim): Thổ sinh Kim
    expect(c.element, 'sinh');
    expect(c.stem, 'bình');
    expect(c.branch, 'bình');
    expect(c.score, 1);
    expect(CoupleCheck(1984, 1989).stem, 'hợp'); // Giáp – Kỷ
    expect(CoupleCheck(1984, 1990).stem, 'xung'); // Giáp – Canh
    expect(CoupleCheck(1984, 1990).branch, 'xung'); // Tý – Ngọ
    expect(CoupleCheck(1984, 1992).branch, 'hợp'); // Tý – Thân (tam hợp)
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
