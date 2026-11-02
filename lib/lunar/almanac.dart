// Traditional day-selection data (xem ngày tốt xấu). These are folk beliefs and sources disagree on details; the
// rules here were checked against a popular Vietnamese almanac (quantrimang.com/lich-am) on several dates.
import 'lunar_calendar.dart';

/// Activities people commonly pick a day for.
enum Activity {
  wedding('Cưới hỏi'),
  opening('Khai trương'),
  construction('Động thổ, xây nhà'),
  moving('Về nhà mới'),
  travel('Xuất hành'),
  contract('Ký kết, giao dịch');

  const Activity(this.label);

  final String label;
}

/// One of the 12 trực, with what it suits and what to avoid.
class Truc {
  const Truc(this.name, this.text, {this.good = const {}, this.bad = const {}});

  final String name;
  final String text;
  final Set<Activity> good;
  final Set<Activity> bad;
}

const _all = {...Activity.values};

const List<Truc> trucs = [
  Truc(
    'Kiến',
    'Tốt cho xuất hành, cưới hỏi; tránh động thổ',
    good: {Activity.travel, Activity.wedding},
    bad: {Activity.construction},
  ),
  Truc('Trừ', 'Tốt mọi việc', good: _all),
  Truc('Mãn', 'Nên cầu tài, cầu phúc, tế tự'),
  Truc('Bình', 'Tốt mọi việc', good: _all),
  Truc(
    'Định',
    'Tốt cho cầu tài, ký hợp đồng, yến tiệc; tránh kiện tụng, tranh chấp, chữa bệnh',
    good: {Activity.contract},
  ),
  Truc(
    'Chấp',
    'Tốt cho khởi công xây dựng; tránh xuất hành, di chuyển, khai trương',
    good: {Activity.construction},
    bad: {Activity.travel, Activity.moving, Activity.opening},
  ),
  Truc('Phá', 'Chỉ nên chữa bệnh, phá dỡ nhà cửa, đồ vật', bad: _all),
  Truc('Nguy', 'Xấu mọi việc', bad: _all),
  Truc(
    'Thành',
    'Tốt cho xuất hành, khai trương, cưới hỏi; tránh kiện tụng, tranh chấp',
    good: {Activity.travel, Activity.opening, Activity.wedding},
  ),
  Truc('Thu', 'Tốt cho thu hoạch; kỵ khởi công, xuất hành, an táng', bad: {Activity.construction, Activity.travel}),
  Truc(
    'Khai',
    'Tốt mọi việc trừ động thổ, an táng',
    good: {Activity.wedding, Activity.opening, Activity.moving, Activity.travel, Activity.contract},
    bad: {Activity.construction},
  ),
  Truc('Bế', 'Xấu mọi việc, trừ đắp đê, lấp hố, rãnh', bad: _all),
];

/// The 28 lunar mansions (nhị thập bát tú), in order from Giác.
const List<(String, bool)> mansions = [
  ('Giác Mộc Giao', true), ('Cang Kim Long', false), ('Đê Thổ Lạc', false), ('Phòng Nhật Thố', true), //
  ('Tâm Nguyệt Hồ', false), ('Vĩ Hỏa Hổ', true), ('Cơ Thủy Báo', true), ('Đẩu Mộc Giải', true), //
  ('Ngưu Kim Ngưu', false), ('Nữ Thổ Bức', false), ('Hư Nhật Thử', false), ('Nguy Nguyệt Yến', false), //
  ('Thất Hỏa Trư', true), ('Bích Thủy Du', true), ('Khuê Mộc Lang', false), ('Lâu Kim Cẩu', true), //
  ('Vị Thổ Trĩ', true), ('Mão Nhật Kê', false), ('Tất Nguyệt Ô', true), ('Chủy Hỏa Hầu', false), //
  ('Sâm Thủy Viên', true), ('Tỉnh Mộc Hãn', true), ('Quỷ Kim Dương', false), ('Liễu Thổ Chương', false), //
  ('Tinh Nhật Mã', false), ('Trương Nguyệt Lộc', true), ('Dực Hỏa Xà', false), ('Chẩn Thủy Dẫn', true), //
];

/// Direction of the joy god (Hỷ thần) by day stem: "Giáp Kỷ Đông Bắc, Ất Canh Tây Bắc, …".
const _hyThan = [
  'Đông Bắc',
  'Tây Bắc',
  'Tây Nam',
  'Chính Nam',
  'Đông Nam',
  'Đông Bắc',
  'Tây Bắc',
  'Tây Nam',
  'Chính Nam',
  'Đông Nam',
];

/// Direction of the wealth god (Tài thần) by day stem.
const _taiThan = [
  'Đông Nam',
  'Đông Nam',
  'Chính Đông',
  'Chính Đông',
  'Chính Bắc',
  'Chính Nam',
  'Tây Nam',
  'Tây Nam',
  'Chính Tây',
  'Tây Bắc',
];

/// Lunar days avoided for big events.
const tamNuongDays = {3, 7, 13, 18, 22, 27};
const nguyetKyDays = {5, 14, 23};

/// Branch indexes (0 = Tý) that clash with [branch] (lục xung).
int clashOf(int branch) => (branch + 6) % 12;

/// The other two branches of [branch]'s triple harmony (tam hợp): Thân–Tý–Thìn, Dần–Ngọ–Tuất, …
List<int> tripleHarmonyOf(int branch) => [(branch + 4) % 12, (branch + 8) % 12];

/// The branch in six harmony (lục hợp) with [branch]: Tý–Sửu, Dần–Hợi, Mão–Tuất, Thìn–Dậu, Tỵ–Thân, Ngọ–Mùi.
int sixHarmonyOf(int branch) => (13 - branch) % 12;

/// The four branches that clash with each other (tứ hành xung) as a group containing [branch].
List<int> fourClashOf(int branch) => [for (var i = 0; i < 4; i++) (branch % 3 + 3 * i) % 12];

/// Everything the almanac says about one day.
class DayAlmanac {
  DayAlmanac(this.date) : lunar = solarToLunar(date) {
    final jd = jdFromDateTime(date);
    dayBranch = (jd + 1) % 12;
    dayStem = (jd + 9) % 10;
    truc = trucs[(dayBranch - solarTermMonthBranch(date) + 12) % 12];
    mansion = mansions[(jd + 11) % 28];
    star = dayStarOf(date, lunar);
  }

  final DateTime date;
  final LunarDate lunar;
  late final int dayBranch;
  late final int dayStem;
  late final Truc truc;
  late final (String, bool) mansion;
  late final DayStar star;

  String get hyThan => _hyThan[dayStem];
  String get taiThan => _taiThan[dayStem];
  bool get tamNuong => tamNuongDays.contains(lunar.day);
  bool get nguyetKy => nguyetKyDays.contains(lunar.day);
  int get clashBranch => clashOf(dayBranch);

  /// Whether someone born in lunar year [birthYear] clashes with this day (their branch is opposite the day's).
  bool clashesWith(int birthYear) => yearBranch(birthYear) == clashBranch;

  /// Score for [activity], or null when the day is unsuitable: it must be hoàng đạo, not Tam nương or Nguyệt kỵ, and
  /// its trực must not be bad for the activity. 1 point each for a trực good for it and a good mansion.
  int? scoreFor(Activity activity) {
    if (!star.isGood || tamNuong || nguyetKy || truc.bad.contains(activity)) return null;
    return (truc.good.contains(activity) ? 1 : 0) + (mansion.$2 ? 1 : 0);
  }
}

int yearBranch(int lunarYear) => (lunarYear + 8) % 12;

/// Nạp âm (the element of a stem-branch pair), indexed by sexagenary position / 2, from Giáp Tý.
const List<String> _napAm = [
  'Hải Trung Kim', 'Lư Trung Hỏa', 'Đại Lâm Mộc', 'Lộ Bàng Thổ', 'Kiếm Phong Kim', 'Sơn Đầu Hỏa', //
  'Giản Hạ Thủy', 'Thành Đầu Thổ', 'Bạch Lạp Kim', 'Dương Liễu Mộc', 'Tuyền Trung Thủy', 'Ốc Thượng Thổ', //
  'Tích Lịch Hỏa', 'Tùng Bách Mộc', 'Trường Lưu Thủy', 'Sa Trung Kim', 'Sơn Hạ Hỏa', 'Bình Địa Mộc', //
  'Bích Thượng Thổ', 'Kim Bạch Kim', 'Phú Đăng Hỏa', 'Thiên Hà Thủy', 'Đại Trạch Thổ', 'Thoa Xuyến Kim', //
  'Tang Đố Mộc', 'Đại Khê Thủy', 'Sa Trung Thổ', 'Thiên Thượng Hỏa', 'Thạch Lựu Mộc', 'Đại Hải Thủy', //
];

/// What the almanac says about someone born in lunar year [birthYear].
class AgeInfo {
  AgeInfo(this.birthYear);

  final int birthYear;

  String get canChi => canChiYear(birthYear);
  int get branch => yearBranch(birthYear);
  String get animal => conGiap[branch];

  /// "Sa Trung Kim".
  String get napAm => _napAm[((birthYear - 4) % 60) ~/ 2];

  /// "Kim", "Mộc", … (the last word of [napAm]).
  String get element => napAm.split(' ').last;

  /// Vietnamese age (tuổi mụ): 1 at birth, +1 every Tết.
  int ageIn(int lunarYear) => lunarYear - birthYear + 1;

  List<String> get tripleHarmony => [for (final b in tripleHarmonyOf(branch)) chi[b]];
  String get sixHarmony => chi[sixHarmonyOf(branch)];
  List<String> get fourClash => [
    for (final b in fourClashOf(branch))
      if (b != branch) chi[b],
  ];
}
