import 'package:flutter/material.dart';

import '../data/people.dart';
import '../lunar/almanac.dart';
import '../lunar/format.dart';
import '../lunar/lunar_calendar.dart';
import '../theme.dart';
import 'date_inputs.dart';
import 'day_sections.dart';

/// A day found by [findGoodDays].
typedef GoodDay = ({DateTime date, DayAlmanac almanac, int score});

/// Days in [from, to] suitable for [activity] that clash with none of [birthYears], best first then soonest.
List<GoodDay> findGoodDays(Activity activity, DateTime from, DateTime to, Iterable<int> birthYears) {
  final found = <GoodDay>[];
  for (var d = from; !d.isAfter(to); d = DateTime(d.year, d.month, d.day + 1)) {
    final a = DayAlmanac(d);
    final score = a.scoreFor(activity);
    if (score == null || birthYears.any(a.clashesWith)) continue;
    found.add((date: d, almanac: a, score: score));
  }
  found.sort((a, b) => b.score != a.score ? b.score.compareTo(a.score) : a.date.compareTo(b.date));
  return found;
}

/// "Chọn ngày tốt": pick an activity, a date range and whose ages to respect, then list the suitable days.
class GoodDaysCard extends StatefulWidget {
  const GoodDaysCard({super.key, required this.onShowDate});

  final ValueChanged<DateTime> onShowDate;

  @override
  State<GoodDaysCard> createState() => _GoodDaysCardState();
}

class _GoodDaysCardState extends State<GoodDaysCard> {
  Activity _activity = Activity.wedding;
  late DateTime _from = today();
  late DateTime _to = DateTime(_from.year, _from.month + 2, _from.day);
  final _excluded = <int>{}; // person ids left out
  List<GoodDay>? _results;

  void _search(List<Person> people) {
    final (a, b) = _from.isAfter(_to) ? (_to, _from) : (_from, _to);
    // Cap the range at two years so a search stays instant.
    final end = b.isAfter(DateTime(a.year + 2, a.month, a.day)) ? DateTime(a.year + 2, a.month, a.day) : b;
    final years = [
      for (final p in people)
        if (!_excluded.contains(p.id)) p.birthYear,
    ];
    setState(() => _results = findGoodDays(_activity, a, end, years));
  }

  @override
  Widget build(BuildContext context) {
    final people = PeopleScope.of(context).people;
    final scheme = Theme.of(context).colorScheme;
    final results = _results;
    return SectionCard(
      icon: Icons.event_available_outlined,
      title: 'Chọn ngày tốt',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final a in Activity.values)
                ChoiceChip(
                  label: Text(a.label),
                  selected: _activity == a,
                  onSelected: (_) => setState(() {
                    _activity = a;
                    _results = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SolarDateField(label: 'Từ ngày', value: _from, onChanged: (d) => setState(() => _from = d)),
          const SizedBox(height: 10),
          SolarDateField(label: 'Đến ngày', value: _to, onChanged: (d) => setState(() => _to = d)),
          if (people.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Tránh ngày xung tuổi', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                for (final p in people)
                  FilterChip(
                    label: Text('${p.name} (${chi[yearBranch(p.birthYear)]})'),
                    selected: !_excluded.contains(p.id),
                    onSelected: (on) => setState(() => on ? _excluded.remove(p.id) : _excluded.add(p.id!)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _search(people),
            icon: const Icon(Icons.search_rounded),
            label: const Text('Tìm ngày'),
          ),
          if (results != null) ...[
            const SizedBox(height: 12),
            Text(
              results.isEmpty
                  ? 'Không có ngày phù hợp trong khoảng này. Thử mở rộng khoảng ngày.'
                  : 'Có ${results.length} ngày phù hợp${results.length > 20 ? ', hiện 20 ngày tốt nhất' : ''}:',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            for (final r in results.take(20)) _ResultTile(day: r, onTap: () => widget.onShowDate(r.date)),
            const SizedBox(height: 6),
            Text(
              'Ngày được chọn: hoàng đạo, không phải Tam nương / Nguyệt kỵ, trực không kỵ việc này và không xung '
              'tuổi đã chọn. Theo quan niệm dân gian, chỉ để tham khảo.',
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.day, required this.onTap});

  final GoodDay day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lich = context.lich;
    final a = day.almanac;
    final d = day.date;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              child: Column(
                children: [
                  Text(
                    '${d.day}',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: lich.holiday,
                    ),
                  ),
                  Text('Th ${d.month}', style: TextStyle(fontSize: 11, color: lich.holiday)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${weekdayNames[d.weekday - 1]}, ${a.lunar.day}/${a.lunar.month} âm',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Trực ${a.truc.name} · sao ${a.mansion.$1.split(' ').first} · ${a.star.name}',
                    style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [for (var i = 0; i <= day.score; i++) Icon(Icons.star_rounded, size: 16, color: lich.goodDay)],
            ),
          ],
        ),
      ),
    );
  }
}
