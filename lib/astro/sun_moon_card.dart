import 'package:flutter/material.dart';

import '../data/settings.dart';
import '../lunar/format.dart';
import '../theme.dart';
import '../widgets/day_sections.dart';
import '../widgets/moon_phase.dart';
import 'sun_moon.dart';

City currentCity(Settings s) => cities[s.cityIndex.clamp(0, cities.length - 1)];

/// Lets the user pick the city used for sun/moon times and the weather.
Future<void> pickCity(BuildContext context) async {
  final settings = SettingsScope.of(context);
  final chosen = await showDialog<int>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Chọn thành phố'),
      children: [
        for (var i = 0; i < cities.length; i++)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, i),
            child: Row(
              children: [
                Icon(
                  i == settings.value.cityIndex ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(cities[i].name),
              ],
            ),
          ),
      ],
    ),
  );
  if (chosen != null) await settings.update(settings.value.copyWith(cityIndex: chosen));
}

String _hm(DateTime? t) => t == null ? '—' : '${two(t.hour)}:${two(t.minute)}';

/// "Mặt trời & mặt trăng" for the selected day and city.
class SunMoonCard extends StatelessWidget {
  const SunMoonCard({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final city = currentCity(SettingsScope.of(context).value);
    final d = sunMoonDay(date, city);
    final scheme = Theme.of(context).colorScheme;
    final lich = context.lich;
    final length = d.dayLength;
    final from = DateTime(date.year, date.month, date.day);
    final full = nextPhase(from, 180);
    final newMoon = nextPhase(from, 0);
    final muted = TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant);

    Widget column(String label, String value) => Expanded(
      child: Column(
        children: [
          Text(label, style: muted),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ],
      ),
    );

    return SectionCard(
      icon: Icons.wb_twilight_rounded,
      title: 'Mặt trời & mặt trăng',
      trailing: TextButton.icon(
        onPressed: () => pickCity(context),
        icon: const Icon(Icons.place_outlined, size: 16),
        label: Text(city.name),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 36, child: Text('☀️', style: TextStyle(fontSize: 22))),
              column('Mọc', _hm(d.sunrise)),
              column('Lặn', _hm(d.sunset)),
              column('Ngày dài', length == null ? '—' : '${length.inHours}h${two(length.inMinutes % 60)}'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 36,
                child: MoonPhase(
                  lunarDay: ((d.waxing ? d.illumination : 2 - d.illumination) * 14.77 + 1).round().clamp(1, 30),
                  size: 24,
                  lit: lich.goodDay,
                  shadow: scheme.onSurfaceVariant.withValues(alpha: 0.25),
                ),
              ),
              column('Mọc', _hm(d.moonrise)),
              column('Lặn', _hm(d.moonset)),
              column('Độ sáng', '${(d.illumination * 100).round()}%'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Trăng tròn: ${two(full.day)}/${two(full.month)} lúc ${_hm(full)} · '
            'Trăng non: ${two(newMoon.day)}/${two(newMoon.month)} lúc ${_hm(newMoon)}',
            textAlign: TextAlign.center,
            style: muted,
          ),
        ],
      ),
    );
  }
}
