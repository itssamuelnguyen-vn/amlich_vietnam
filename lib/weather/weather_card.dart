import 'package:flutter/material.dart';

import '../astro/sun_moon.dart';
import '../astro/sun_moon_card.dart';
import '../data/settings.dart';
import '../lunar/format.dart';
import '../widgets/day_sections.dart';
import 'weather.dart';

/// "Thời tiết 7 ngày" for the chosen city; tapping a day shows it on the calendar.
class WeatherCard extends StatefulWidget {
  const WeatherCard({super.key, required this.selected, required this.onTap});

  final DateTime selected;
  final ValueChanged<DateTime> onTap;

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  City? _requested;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Fetch on first show and when the city changes only: this also runs whenever the forecast notifies, and
    // refetching then would loop forever while offline.
    final city = currentCity(SettingsScope.of(context).value);
    if (city == _requested) return;
    _requested = city;
    final weather = WeatherScope.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) => weather.refresh(city));
  }

  @override
  Widget build(BuildContext context) {
    final weather = WeatherScope.of(context);
    final city = currentCity(SettingsScope.of(context).value);
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      icon: Icons.cloud_outlined,
      title: 'Thời tiết',
      trailing: TextButton.icon(
        onPressed: () => pickCity(context),
        icon: const Icon(Icons.place_outlined, size: 16),
        label: Text(city.name),
      ),
      child: weather.forecast.isEmpty
          ? Row(
              children: [
                Expanded(
                  child: Text(
                    weather.loading ? 'Đang tải…' : (weather.error ?? 'Chưa có dữ liệu'),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
                if (!weather.loading)
                  TextButton(onPressed: () => weather.refresh(city, force: true), child: const Text('Thử lại')),
              ],
            )
          : SizedBox(
              height: 118,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final d in weather.forecast)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Material(
                        color: sameDay(d.date, widget.selected)
                            ? scheme.primary.withValues(alpha: 0.12)
                            : scheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => widget.onTap(d.date),
                          child: SizedBox(
                            width: 72,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  sameDay(d.date, today()) ? 'Hôm nay' : weekdayShort[d.date.weekday - 1],
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                                ),
                                Text(d.emoji, style: const TextStyle(fontSize: 26)),
                                Text('${d.max.round()}° / ${d.min.round()}°', style: const TextStyle(fontSize: 12.5)),
                                if (d.rain != null)
                                  Text('💧${d.rain}%', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
