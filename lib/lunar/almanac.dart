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

// ---------------------------------------------------------------------------------------------------------------
// Giờ xuất hành Lý Thuần Phong, Bành Tổ bách kỵ

/// The six travel-hour states of Lý Thuần Phong, in the order they follow each other hour by hour.
const List<(String name, bool good, String meaning)> lyThuanPhong = [
  ('Đại An', true, 'Mọi việc tốt lành, nhà cửa yên ổn, người đi bình yên.'),
  ('Tốc Hỷ', true, 'Tin vui sắp tới, cầu tài, việc quan đều thuận; người đi có tin mừng.'),
  ('Lưu Niên', false, 'Việc khó thành, cầu tài mờ mịt, kiện cáo nên hoãn; người đi chưa có tin.'),
  ('Xích Khẩu', false, 'Dễ cãi cọ, thị phi; nên đề phòng, việc đi xa nên hoãn lại.'),
  ('Tiểu Cát', true, 'Rất tốt lành, buôn bán có lời, người đi sắp về, mọi việc hòa hợp.'),
  ('Không Vong', false, 'Còn gọi Tuyệt lộ: cầu tài không lợi, hay trái ý, đi xa dễ gặp hạn.'),
];

/// For each of the 12 two-hour periods (0 = giờ Tý), the Lý Thuần Phong state of [lunar]'s day: giờ Tý takes
/// position (month + day − 2) mod 6 and each later period moves one step, so giờ Tý and giờ Ngọ always match.
/// Checked against a published almanac on four dates (test/almanac_test.dart).
List<int> lyThuanPhongHours(LunarDate lunar) => [for (var h = 0; h < 12; h++) (lunar.month + lunar.day - 2 + h) % 6];

/// Bành Tổ's hundred taboos: (Hán Việt line, meaning) for each day stem and branch.
const List<(String, String)> banhToCan = [
  ('Giáp bất khai thương, tài vật hao vong', 'Ngày Giáp không nên mở kho, tiền của hao mất'),
  ('Ất bất tài thực, thiên chu bất trưởng', 'Ngày Ất không nên gieo trồng, ngàn gốc không lên'),
  ('Bính bất tu táo, tất kiến hỏa ương', 'Ngày Bính không nên sửa bếp, sẽ gặp tai họa về lửa'),
  ('Đinh bất thế đầu, đầu chủ sinh sang', 'Ngày Đinh không nên cắt tóc, đầu sẽ sinh nhọt'),
  ('Mậu bất thụ điền, điền chủ bất tường', 'Ngày Mậu không nên nhận ruộng đất, chủ không được lành'),
  ('Kỷ bất phá khoán, nhị chủ tịnh vong', 'Ngày Kỷ không nên phá bỏ giao kèo, hai bên đều thiệt'),
  ('Canh bất kinh lạc, chức cơ hư trướng', 'Ngày Canh không nên dệt cửi, khung cửi bỏ không'),
  ('Tân bất hợp tương, chủ nhân bất thường', 'Ngày Tân không nên làm tương, chủ không được nếm'),
  ('Nhâm bất ương thủy, cánh nan đê phòng', 'Ngày Nhâm không nên tháo nước, khó bề đề phòng'),
  ('Quý bất từ tụng, lý nhược địch cường', 'Ngày Quý không nên kiện tụng, lý yếu địch mạnh'),
];

const List<(String, String)> banhToChi = [
  ('Tý bất vấn bốc, tự nhạ tai ương', 'Ngày Tý không nên gieo quẻ hỏi, tự rước lấy tai ương'),
  ('Sửu bất quan đới, chủ bất hoàn hương', 'Ngày Sửu không nên làm lễ đội mũ, chủ không về quê'),
  ('Dần bất tế tự, quỷ thần bất thường', 'Ngày Dần không nên cúng tế, thần linh không hưởng'),
  ('Mão bất xuyên tỉnh, tuyền thủy bất hương', 'Ngày Mão không nên đào giếng, nước sẽ không trong lành'),
  ('Thìn bất khốc khấp, tất chủ trọng tang', 'Ngày Thìn không nên khóc lóc, dễ có trùng tang'),
  ('Tỵ bất viễn hành, tài vật phục tàng', 'Ngày Tỵ không nên đi xa, tiền của mất mát'),
  ('Ngọ bất thiêm cái, ốc chủ canh trương', 'Ngày Ngọ không nên lợp nhà, chủ nhà phải làm lại'),
  ('Mùi bất phục dược, độc khí nhập tràng', 'Ngày Mùi không nên uống thuốc, độc khí vào ruột'),
  ('Thân bất an sàng, quỷ túy nhập phòng', 'Ngày Thân không nên kê giường, ma quỷ vào phòng'),
  ('Dậu bất hội khách, tân chủ hữu thương', 'Ngày Dậu không nên hội khách, tân chủ có hại'),
  ('Tuất bất cật khuyển, tác quái thượng sàng', 'Ngày Tuất không nên ăn thịt chó, ma quái quấy nhiễu'),
  ('Hợi bất giá thú, bất lợi tân lang', 'Ngày Hợi không nên cưới gả, bất lợi cho chú rể'),
];

// ---------------------------------------------------------------------------------------------------------------
// Xem tuổi làm nhà: Kim lâu, Hoang ốc, Tam tai

/// Kim lâu by Vietnamese age (tuổi mụ) mod 9: 1 thân (self), 3 thê (spouse), 6 tử (children), 8 lục súc (livestock).
String? kimLau(int age) => switch (age % 9) {
  1 => 'Kim lâu thân (hại bản thân)',
  3 => 'Kim lâu thê (hại vợ/chồng)',
  6 => 'Kim lâu tử (hại con cái)',
  8 => 'Kim lâu lục súc (hại vật nuôi, tài sản)',
  _ => null,
};

/// Hoang ốc's six palaces; the 1st, 2nd and 4th are good.
const List<(String, bool)> hoangOcCung = [
  ('Nhất Cát', true),
  ('Nhì Nghi', true),
  ('Tam Địa Sát', false),
  ('Tứ Tấn Tài', true),
  ('Ngũ Thọ Tử', false),
  ('Lục Hoang Ốc', false),
];

/// Hoang ốc palace for a Vietnamese age: the sum of its digits mod 6 (10 is Nhất Cát, 24 is Lục Hoang Ốc, 25 Nhất Cát).
(String, bool) hoangOc(int age) {
  final digits = age.toString().split('').fold(0, (s, d) => s + int.parse(d));
  return hoangOcCung[(digits - 1) % 6];
}

/// The three years of Tam tai for someone born in a year of [branch]: Thân Tý Thìn → Dần Mão Thìn, Dần Ngọ Tuất →
/// Thân Dậu Tuất, Hợi Mão Mùi → Tỵ Ngọ Mùi, Tỵ Dậu Sửu → Hợi Tý Sửu.
List<int> tamTaiBranches(int branch) {
  final start = switch (branch % 4) {
    0 => 2, // Thân Tý Thìn
    2 => 8, // Dần Ngọ Tuất
    3 => 5, // Hợi Mão Mùi
    _ => 11, // Tỵ Dậu Sửu
  };
  return [start, (start + 1) % 12, (start + 2) % 12];
}

/// Building-a-house check for someone born in lunar year [birthYear], in lunar year [year].
class HouseCheck {
  HouseCheck(this.birthYear, this.year)
    : age = year - birthYear + 1,
      tamTai = tamTaiBranches(yearBranch(birthYear)).contains(yearBranch(year));

  final int birthYear;
  final int year;
  final int age;
  final bool tamTai;

  String? get kimLauText => kimLau(age);
  (String, bool) get hoangOcPalace => hoangOc(age);
  bool get good => kimLauText == null && hoangOcPalace.$2 && !tamTai;
}

// ---------------------------------------------------------------------------------------------------------------
// Xem tuổi vợ chồng

const _elements = ['Kim', 'Thủy', 'Mộc', 'Hỏa', 'Thổ']; // each produces the next

/// How element [a] relates to [b]: "sinh" (one produces the other), "khắc" (one overcomes the other) or "hòa" (same).
String elementRelation(String a, String b) {
  if (a == b) return 'hòa';
  final i = _elements.indexOf(a), j = _elements.indexOf(b);
  return (i + 1) % 5 == j || (j + 1) % 5 == i ? 'sinh' : 'khắc';
}

/// Stems that combine (Giáp–Kỷ, Ất–Canh, Bính–Tân, Đinh–Nhâm, Mậu–Quý) or clash (Giáp–Canh, Ất–Tân, Bính–Nhâm,
/// Đinh–Quý); Mậu and Kỷ clash with nothing.
String stemRelation(int a, int b) {
  final d = (a - b).abs();
  if (d == 5) return 'hợp';
  if (d == 6 || d == 4) {
    final pair = {a, b};
    const clashes = [
      {0, 6},
      {1, 7},
      {2, 8},
      {3, 9},
    ];
    if (clashes.any((c) => c.containsAll(pair))) return 'xung';
  }
  return 'bình';
}

/// Branches in triple or six harmony, in six clash (lục xung), or neither.
String branchRelation(int a, int b) {
  if (a == b) return 'bình';
  if (tripleHarmonyOf(a).contains(b) || sixHarmonyOf(a) == b) return 'hợp';
  if (clashOf(a) == b) return 'xung';
  return 'bình';
}

/// Marriage compatibility of two birth years: element, stem and branch, each "good", "neutral" or "bad".
class CoupleCheck {
  CoupleCheck(this.husband, this.wife);

  final int husband;
  final int wife;

  AgeInfo get h => AgeInfo(husband);
  AgeInfo get w => AgeInfo(wife);

  String get element => elementRelation(h.element, w.element);
  String get stem => stemRelation((husband + 6) % 10, (wife + 6) % 10);
  String get branch => branchRelation(h.branch, w.branch);

  /// 0–3 points: one each for elements that produce each other (or match), combining stems, harmonious branches;
  /// clashes take a point away.
  int get score {
    var s = 0;
    s += element == 'khắc' ? 0 : 1;
    s += stem == 'hợp' ? 1 : (stem == 'xung' ? -1 : 0);
    s += branch == 'hợp' ? 1 : (branch == 'xung' ? -1 : 0);
    return s.clamp(0, 3);
  }
}
