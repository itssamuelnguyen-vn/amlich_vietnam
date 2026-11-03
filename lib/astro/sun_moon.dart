// Sun and moon rise/set, moon illumination and the next new/full moon, for a place in Vietnam (UTC+7).
// Low-precision formulas (sun: the "sunrise equation"; moon: the Astronomical Almanac's low-precision series),
// good to about a minute for the sun and a few minutes for the moon; checked against USNO data in
// test/sun_moon_test.dart.
import 'dart:math' as math;

const double _rad = math.pi / 180;

double _sin(double deg) => math.sin(deg * _rad);
double _cos(double deg) => math.cos(deg * _rad);
double _norm(double deg) => (deg % 360 + 360) % 360;

class City {
  const City(this.name, this.lat, this.lon);

  final String name;
  final double lat;
  final double lon;
}

const cities = [
  City('Hà Nội', 21.0285, 105.8542),
  City('Hải Phòng', 20.8449, 106.6881),
  City('Hạ Long', 20.9590, 107.0448),
  City('Lào Cai – Sa Pa', 22.3364, 103.8438),
  City('Điện Biên Phủ', 21.3860, 103.0230),
  City('Thanh Hóa', 19.8067, 105.7852),
  City('Vinh', 18.6796, 105.6813),
  City('Huế', 16.4637, 107.5909),
  City('Đà Nẵng', 16.0544, 108.2022),
  City('Quy Nhơn', 13.7820, 109.2196),
  City('Nha Trang', 12.2388, 109.1967),
  City('Buôn Ma Thuột', 12.6667, 108.0500),
  City('Đà Lạt', 11.9404, 108.4583),
  City('TP. Hồ Chí Minh', 10.7769, 106.7009),
  City('Vũng Tàu', 10.3460, 107.0843),
  City('Cần Thơ', 10.0452, 105.7469),
  City('Phú Quốc', 10.2899, 103.9840),
  City('Cà Mau', 9.1769, 105.1524),
];

/// Julian date (UT) of local [time] in UTC+7.
double _jd(DateTime time) {
  final utc = DateTime.utc(
    time.year,
    time.month,
    time.day,
    time.hour,
    time.minute,
    time.second,
  ).subtract(const Duration(hours: 7));
  return utc.millisecondsSinceEpoch / 86400000.0 + 2440587.5;
}

DateTime _local(double jd) {
  final utc = DateTime.fromMillisecondsSinceEpoch(((jd - 2440587.5) * 86400000).round(), isUtc: true);
  final l = utc.add(const Duration(hours: 7));
  return DateTime(l.year, l.month, l.day, l.hour, l.minute, l.second);
}

/// Sun's apparent ecliptic longitude (degrees) at Julian date [jd].
double _sunLongitude(double jd) {
  final n = jd - 2451545.0;
  final m = _norm(357.5291 + 0.98560028 * n);
  final c = 1.9148 * _sin(m) + 0.0200 * _sin(2 * m) + 0.0003 * _sin(3 * m);
  return _norm(m + c + 180 + 102.9372);
}

/// Moon's ecliptic longitude, latitude (degrees) and horizontal parallax (degrees) at [jd].
(double, double, double) _moon(double jd) {
  final t = (jd - 2451545.0) / 36525;
  final l =
      218.32 +
      481267.881 * t +
      6.29 * _sin(135.0 + 477198.87 * t) -
      1.27 * _sin(259.3 - 413335.36 * t) +
      0.66 * _sin(235.7 + 890534.22 * t) +
      0.21 * _sin(269.9 + 954397.74 * t) -
      0.19 * _sin(357.5 + 35999.05 * t) -
      0.11 * _sin(186.5 + 966404.03 * t);
  final b =
      5.13 * _sin(93.3 + 483202.02 * t) +
      0.28 * _sin(228.2 + 960400.89 * t) -
      0.28 * _sin(318.3 + 6003.15 * t) -
      0.17 * _sin(217.6 - 407332.21 * t);
  final p =
      0.9508 +
      0.0518 * _cos(135.0 + 477198.87 * t) +
      0.0095 * _cos(259.3 - 413335.36 * t) +
      0.0078 * _cos(235.7 + 890534.22 * t) +
      0.0028 * _cos(269.9 + 954397.74 * t);
  return (_norm(l), b, p);
}

/// Moon's altitude above the horizon (degrees) at [jd] for [city], minus the rise/set threshold.
double _moonAltitude(double jd, City city) {
  final (l, b, p) = _moon(jd);
  final t = (jd - 2451545.0) / 36525;
  final e = 23.4393 - 0.013 * t;
  final ra = math.atan2(_sin(l) * _cos(e) - math.tan(b * _rad) * _sin(e), _cos(l)) / _rad;
  final dec = math.asin(_sin(b) * _cos(e) + _cos(b) * _sin(e) * _sin(l)) / _rad;
  final gmst = _norm(280.46061837 + 360.98564736629 * (jd - 2451545.0));
  final h = gmst + city.lon - ra;
  final alt = math.asin(_sin(city.lat) * _sin(dec) + _cos(city.lat) * _cos(dec) * _cos(h)) / _rad;
  return alt - (0.7275 * p - 0.5667); // parallax, refraction and semi-diameter
}

class SunMoonDay {
  const SunMoonDay({
    this.sunrise,
    this.sunset,
    this.moonrise,
    this.moonset,
    required this.illumination,
    required this.waxing,
  });

  final DateTime? sunrise;
  final DateTime? sunset;
  final DateTime? moonrise;
  final DateTime? moonset;

  /// Illuminated fraction of the moon at local noon, 0–1.
  final double illumination;
  final bool waxing;

  Duration? get dayLength => sunrise == null || sunset == null ? null : sunset!.difference(sunrise!);
}

/// Sunrise and sunset ("sunrise equation", −0.833° for refraction and the sun's radius).
(DateTime?, DateTime?) sunTimes(DateTime date, City city) {
  final jdNoon = _jd(DateTime(date.year, date.month, date.day, 12));
  final n = (jdNoon - 2451545.0 + 0.0008).roundToDouble();
  final jStar = n - city.lon / 360;
  final m = _norm(357.5291 + 0.98560028 * jStar);
  final c = 1.9148 * _sin(m) + 0.0200 * _sin(2 * m) + 0.0003 * _sin(3 * m);
  final lambda = _norm(m + c + 180 + 102.9372);
  final transit = 2451545.0 + jStar + 0.0053 * _sin(m) - 0.0069 * _sin(2 * lambda);
  final dec = math.asin(_sin(lambda) * _sin(23.4397)) / _rad;
  final cosH = (_sin(-0.833) - _sin(city.lat) * _sin(dec)) / (_cos(city.lat) * _cos(dec));
  if (cosH.abs() > 1) return (null, null);
  final h = math.acos(cosH) / _rad;
  return (_local(transit - h / 360), _local(transit + h / 360));
}

/// Moonrise and moonset during the local day (either can be missing: the moon rises ~50 minutes later each day).
(DateTime?, DateTime?) moonTimes(DateTime date, City city) {
  final start = _jd(DateTime(date.year, date.month, date.day));
  const step = 10 / 1440; // 10 minutes
  DateTime? rise, set;
  var prev = _moonAltitude(start, city);
  for (var i = 1; i <= 144; i++) {
    final jd = start + i * step;
    final alt = _moonAltitude(jd, city);
    if ((prev < 0) != (alt < 0)) {
      final crossing = jd - step + step * prev / (prev - alt);
      if (prev < 0) {
        rise ??= _local(crossing);
      } else {
        set ??= _local(crossing);
      }
    }
    prev = alt;
  }
  return (rise, set);
}

/// Elongation of the moon east of the sun (0 new, 180 full), degrees.
double _elongation(double jd) => _norm(_moon(jd).$1 - _sunLongitude(jd));

SunMoonDay sunMoonDay(DateTime date, City city) {
  final (sunrise, sunset) = sunTimes(date, city);
  final (moonrise, moonset) = moonTimes(date, city);
  final e = _elongation(_jd(DateTime(date.year, date.month, date.day, 12)));
  return SunMoonDay(
    sunrise: sunrise,
    sunset: sunset,
    moonrise: moonrise,
    moonset: moonset,
    illumination: (1 - _cos(e)) / 2,
    waxing: e < 180,
  );
}

/// The next time after [from] that the elongation reaches [target] (0 new moon, 180 full moon), to the minute.
DateTime nextPhase(DateTime from, double target) {
  double off(double jd) => _norm(_elongation(jd) - target + 180) - 180; // −180..180, rising through 0
  var a = _jd(from);
  const step = 0.25;
  var fa = off(a);
  for (var i = 0; i < 160; i++) {
    final b = a + step;
    final fb = off(b);
    if (fa < 0 && fb >= 0) {
      var lo = a, hi = b;
      for (var k = 0; k < 20; k++) {
        final mid = (lo + hi) / 2;
        if (off(mid) < 0) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      return _local(hi);
    }
    a = b;
    fa = fb;
  }
  return from;
}
