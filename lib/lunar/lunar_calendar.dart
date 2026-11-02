// Vietnamese lunar calendar, after Hồ Ngọc Đức's algorithm (https://www.informatik.uni-leipzig.de/~duc/amlich/).
// Everything is computed for UTC+7: the Vietnamese calendar differs from the Chinese one (UTC+8) in some years,
// e.g. Tết 1985 is 21/01 in Vietnam but 20/02 in China. Accurate for roughly 1800–2199.
import 'dart:math' as math;

const double _timeZone = 7.0;

/// A day of the lunar calendar. [isLeap] marks a day in a leap month (tháng nhuận).
class LunarDate {
  const LunarDate(this.day, this.month, this.year, {this.isLeap = false});

  final int day;
  final int month;
  final int year;
  final bool isLeap;

  @override
  bool operator ==(Object other) =>
      other is LunarDate && other.day == day && other.month == month && other.year == year && other.isLeap == isLeap;

  @override
  int get hashCode => Object.hash(day, month, year, isLeap);

  @override
  String toString() => '$day/$month${isLeap ? ' nhuận' : ''}/$year';
}

const List<String> can = ['Giáp', 'Ất', 'Bính', 'Đinh', 'Mậu', 'Kỷ', 'Canh', 'Tân', 'Nhâm', 'Quý'];
const List<String> chi = ['Tý', 'Sửu', 'Dần', 'Mão', 'Thìn', 'Tỵ', 'Ngọ', 'Mùi', 'Thân', 'Dậu', 'Tuất', 'Hợi'];

/// The 24 solar terms, starting at sun longitude 0° (Xuân phân, the March equinox), 15° apart.
const List<String> tietKhi = [
  'Xuân phân', 'Thanh minh', 'Cốc vũ', 'Lập hạ', 'Tiểu mãn', 'Mang chủng', //
  'Hạ chí', 'Tiểu thử', 'Đại thử', 'Lập thu', 'Xử thử', 'Bạch lộ', //
  'Thu phân', 'Hàn lộ', 'Sương giáng', 'Lập đông', 'Tiểu tuyết', 'Đại tuyết', //
  'Đông chí', 'Tiểu hàn', 'Đại hàn', 'Lập xuân', 'Vũ thủy', 'Kinh trập', //
];

/// Lucky hours per day branch (index chi % 6): '1' at position i means hour branch i is an auspicious hour (giờ hoàng đạo).
const List<String> _gioHoangDao = [
  '110100101100', '001101001011', '110011010010', //
  '101100110100', '001011001101', '010010110011', //
];

// ---------------------------------------------------------------------------------------------------------------
// Julian day numbers

/// Julian day number of a Gregorian (or, before 15/10/1582, Julian) date.
int jdFromDate(int dd, int mm, int yy) {
  final a = (14 - mm) ~/ 12;
  final y = yy + 4800 - a;
  final m = mm + 12 * a - 3;
  var jd = dd + (153 * m + 2) ~/ 5 + 365 * y + y ~/ 4 - y ~/ 100 + y ~/ 400 - 32045;
  if (jd < 2299161) jd = dd + (153 * m + 2) ~/ 5 + 365 * y + y ~/ 4 - 32083;
  return jd;
}

int jdFromDateTime(DateTime d) => jdFromDate(d.day, d.month, d.year);

/// Inverse of [jdFromDate]; the time of the result is midnight local time.
DateTime jdToDate(int jd) {
  int b, c;
  if (jd > 2299160) {
    final a = jd + 32044;
    b = (4 * a + 3) ~/ 146097;
    c = a - (b * 146097) ~/ 4;
  } else {
    b = 0;
    c = jd + 32082;
  }
  final d = (4 * c + 3) ~/ 1461;
  final e = c - (1461 * d) ~/ 4;
  final m = (5 * e + 2) ~/ 153;
  final day = e - (153 * m + 2) ~/ 5 + 1;
  final month = m + 3 - 12 * (m ~/ 10);
  final year = b * 100 + d - 4800 + m ~/ 10;
  return DateTime(year, month, day);
}

// ---------------------------------------------------------------------------------------------------------------
// Astronomy

/// Julian date (fractional, UTC) of the k-th new moon after 1/1/1900 13:52 UTC.
double _newMoon(int k) {
  final t = k / 1236.85;
  final t2 = t * t;
  final t3 = t2 * t;
  const dr = math.pi / 180;
  var jd1 = 2415020.75933 + 29.53058868 * k + 0.0001178 * t2 - 0.000000155 * t3;
  jd1 += 0.00033 * math.sin((166.56 + 132.87 * t - 0.009173 * t2) * dr);
  final m = 359.2242 + 29.10535608 * k - 0.0000333 * t2 - 0.00000347 * t3; // sun's mean anomaly
  final mpr = 306.0253 + 385.81691806 * k + 0.0107306 * t2 + 0.00001236 * t3; // moon's mean anomaly
  final f = 21.2964 + 390.67050646 * k - 0.0016528 * t2 - 0.00000239 * t3; // moon's argument of latitude
  var c1 = (0.1734 - 0.000393 * t) * math.sin(m * dr) + 0.0021 * math.sin(2 * dr * m);
  c1 = c1 - 0.4068 * math.sin(mpr * dr) + 0.0161 * math.sin(dr * 2 * mpr);
  c1 = c1 - 0.0004 * math.sin(dr * 3 * mpr);
  c1 = c1 + 0.0104 * math.sin(dr * 2 * f) - 0.0051 * math.sin(dr * (m + mpr));
  c1 = c1 - 0.0074 * math.sin(dr * (m - mpr)) + 0.0004 * math.sin(dr * (2 * f + m));
  c1 = c1 - 0.0004 * math.sin(dr * (2 * f - m)) - 0.0006 * math.sin(dr * (2 * f + mpr));
  c1 = c1 + 0.0010 * math.sin(dr * (2 * f - mpr)) + 0.0005 * math.sin(dr * (2 * mpr + m));
  final deltaT = t < -11
      ? 0.001 + 0.000839 * t + 0.0002261 * t2 - 0.00000845 * t3 - 0.000000081 * t * t3
      : -0.000278 + 0.000265 * t + 0.000262 * t2;
  return jd1 + c1 - deltaT;
}

/// Sun's apparent longitude in radians, normalised to [0, 2π), at Julian date [jdn] (UTC).
double _sunLongitude(double jdn) {
  final t = (jdn - 2451545.0) / 36525;
  final t2 = t * t;
  const dr = math.pi / 180;
  final m = 357.52910 + 35999.05030 * t - 0.0001559 * t2 - 0.00000048 * t * t2;
  final l0 = 280.46645 + 36000.76983 * t + 0.0003032 * t2;
  var dl = (1.914600 - 0.004817 * t - 0.000014 * t2) * math.sin(dr * m);
  dl = dl + (0.019993 - 0.000101 * t) * math.sin(dr * 2 * m) + 0.000290 * math.sin(dr * 3 * m);
  var l = (l0 + dl) * dr;
  l = l - math.pi * 2 * (l / (math.pi * 2)).floor();
  return l;
}

/// Which of [segments] equal arcs the sun is in at local midnight starting day [dayNumber].
int _sunSegment(int dayNumber, int segments) =>
    (_sunLongitude(dayNumber - 0.5 - _timeZone / 24) / math.pi * (segments / 2)).floor();

int _newMoonDay(int k) => (_newMoon(k) + 0.5 + _timeZone / 24).floor();

/// Day number of the start of lunar month 11 (the month containing the winter solstice) of year [yy].
int _lunarMonth11(int yy) {
  final off = jdFromDate(31, 12, yy) - 2415021;
  final k = (off / 29.530588853).floor();
  var nm = _newMoonDay(k);
  if (_sunSegment(nm, 12) >= 9) nm = _newMoonDay(k - 1);
  return nm;
}

/// For a 13-month year starting at month 11 [a11]: offset (1-based from a11) of the leap month,
/// the first month without a major solar term.
int _leapMonthOffset(int a11) {
  final k = ((a11 - 2415021.076998695) / 29.530588853 + 0.5).floor();
  var i = 1;
  var arc = _sunSegment(_newMoonDay(k + i), 12);
  int last;
  do {
    last = arc;
    i++;
    arc = _sunSegment(_newMoonDay(k + i), 12);
  } while (arc != last && i < 14);
  return i - 1;
}

// ---------------------------------------------------------------------------------------------------------------
// Conversions

LunarDate solarToLunar(DateTime date) {
  final dayNumber = jdFromDateTime(date);
  // The estimate k can be one lunation off near a new moon (e.g. 7/5/2054), so step until the month contains the day.
  var k = ((dayNumber - 2415021.076998695) / 29.530588853).floor() + 1;
  while (_newMoonDay(k) > dayNumber) {
    k--;
  }
  while (_newMoonDay(k + 1) <= dayNumber) {
    k++;
  }
  final monthStart = _newMoonDay(k);
  var a11 = _lunarMonth11(date.year);
  var b11 = a11;
  int lunarYear;
  if (a11 >= monthStart) {
    lunarYear = date.year;
    a11 = _lunarMonth11(date.year - 1);
  } else {
    lunarYear = date.year + 1;
    b11 = _lunarMonth11(date.year + 1);
  }
  final lunarDay = dayNumber - monthStart + 1;
  final diff = (monthStart - a11) ~/ 29;
  var isLeap = false;
  var lunarMonth = diff + 11;
  if (b11 - a11 > 365) {
    final leapDiff = _leapMonthOffset(a11);
    if (diff >= leapDiff) {
      lunarMonth = diff + 10;
      if (diff == leapDiff) isLeap = true;
    }
  }
  if (lunarMonth > 12) lunarMonth -= 12;
  if (lunarMonth >= 11 && diff < 4) lunarYear -= 1;
  return LunarDate(lunarDay, lunarMonth, lunarYear, isLeap: isLeap);
}

/// Day number of the first day of the given lunar month, or null when [isLeap] is set but that month is not leap.
int? _lunarMonthStart(int month, int year, bool isLeap) {
  int a11, b11;
  if (month < 11) {
    a11 = _lunarMonth11(year - 1);
    b11 = _lunarMonth11(year);
  } else {
    a11 = _lunarMonth11(year);
    b11 = _lunarMonth11(year + 1);
  }
  final k = (0.5 + (a11 - 2415021.076998695) / 29.530588853).floor();
  var off = month - 11;
  if (off < 0) off += 12;
  if (b11 - a11 > 365) {
    final leapOff = _leapMonthOffset(a11);
    var leapMonth = leapOff - 2;
    if (leapMonth < 0) leapMonth += 12;
    if (isLeap && month != leapMonth) return null;
    if (isLeap || off >= leapOff) off += 1;
  } else if (isLeap) {
    return null;
  }
  return _newMoonDay(k + off);
}

/// The solar date of [lunar], or null when it names a leap month that does not exist or a day past the month's end.
DateTime? lunarToSolar(LunarDate lunar) {
  final start = _lunarMonthStart(lunar.month, lunar.year, lunar.isLeap);
  if (start == null || lunar.day < 1 || lunar.day > daysInLunarMonth(lunar.month, lunar.year, isLeap: lunar.isLeap)) {
    return null;
  }
  return jdToDate(start + lunar.day - 1);
}

/// 29 or 30; 0 when the leap month does not exist.
int daysInLunarMonth(int month, int year, {bool isLeap = false}) {
  final start = _lunarMonthStart(month, year, isLeap);
  if (start == null) return 0;
  final k = ((start - 2415021.076998695) / 29.530588853 + 0.5).floor();
  return _newMoonDay(k + 1) - start;
}

/// The leap month of lunar year [year] (1–12), or null when the year has 12 months.
int? leapMonthOf(int year) {
  for (var m = 1; m <= 12; m++) {
    if (_lunarMonthStart(m, year, true) != null) return m;
  }
  return null;
}

// ---------------------------------------------------------------------------------------------------------------
// Can Chi, solar terms, lucky hours

String canChiYear(int lunarYear) => '${can[(lunarYear + 6) % 10]} ${chi[(lunarYear + 8) % 12]}';

/// A leap month shares the stem-branch of the regular month before it.
String canChiMonth(int lunarMonth, int lunarYear) =>
    '${can[(lunarYear * 12 + lunarMonth + 3) % 10]} ${chi[(lunarMonth + 1) % 12]}';

String canChiDay(DateTime date) {
  final jd = jdFromDateTime(date);
  return '${can[(jd + 9) % 10]} ${chi[(jd + 1) % 12]}';
}

/// Stem-branch of the first hour (the Rat hour, giờ Tý, 23h–1h) of [date].
String canChiHourTy(DateTime date) => '${can[(jdFromDateTime(date) - 1) * 2 % 10]} ${chi[0]}';

/// The solar term the sun is in at the end of [date].
String tietKhiOf(DateTime date) => tietKhi[_sunSegment(jdFromDateTime(date) + 1, 24)];

class LuckyHour {
  const LuckyHour(this.branch, this.startHour, this.endHour);

  final String branch;
  final int startHour;
  final int endHour;

  @override
  String toString() => '$branch ($startHour-${endHour}h)';
}

/// The six auspicious hours (giờ hoàng đạo) of [date].
List<LuckyHour> gioHoangDao(DateTime date) {
  final pattern = _gioHoangDao[(jdFromDateTime(date) + 1) % 12 % 6];
  return [
    for (var i = 0; i < 12; i++)
      if (pattern[i] == '1') LuckyHour(chi[i], (i * 2 + 23) % 24, (i * 2 + 1) % 24),
  ];
}

// ---------------------------------------------------------------------------------------------------------------
// Auspicious (hoàng đạo) and inauspicious (hắc đạo) days

const List<String> _dayStars = [
  'Thanh Long', 'Minh Đường', 'Thiên Hình', 'Chu Tước', 'Kim Quỹ', 'Kim Đường', //
  'Bạch Hổ', 'Ngọc Đường', 'Thiên Lao', 'Huyền Vũ', 'Tư Mệnh', 'Câu Trần', //
];
const Set<int> _goodStars = {0, 1, 4, 5, 7, 10};

/// The star ruling a day, which makes it auspicious (hoàng đạo) or inauspicious (hắc đạo).
class DayStar {
  const DayStar(this.name, this.isGood);

  final String name;
  final bool isGood;
}

/// Thanh Long falls on day branch Tý in months 1 and 7, Dần in 2 and 8, … Tuất in 6 and 12
/// (the traditional rhyme "Dần Thân gia Tý, Mão Dậu tại Dần, …"); the other stars follow in order. [lunar] must be `solarToLunar(date)`.
DayStar dayStarOf(DateTime date, LunarDate lunar) {
  final start = (lunar.month - 1) % 6 * 2;
  final index = ((jdFromDateTime(date) + 1) % 12 - start + 12) % 12;
  return DayStar(_dayStars[index], _goodStars.contains(index));
}

/// Zodiac animal (con giáp) of each branch (the Vietnamese zodiac has the cat for Mão).
const List<String> conGiap = ['🐭', '🐃', '🐯', '🐱', '🐉', '🐍', '🐴', '🐐', '🐵', '🐓', '🐶', '🐷'];

String yearAnimal(int lunarYear) => conGiap[(lunarYear + 8) % 12];

/// Branch of the solar-term month (tháng tiết) containing [date]: Dần from Lập xuân (315°), Mão from Kinh trập, and
/// so on. The day a term begins already belongs to the new month, so the sun is taken at the end of the day.
int solarTermMonthBranch(DateTime date) {
  final degrees = _sunLongitude(jdFromDateTime(date) + 1 - 0.5 - _timeZone / 24) * 180 / math.pi;
  return (2 + ((degrees - 315 + 360) % 360) ~/ 30) % 12;
}
