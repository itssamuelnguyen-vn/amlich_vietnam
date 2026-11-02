import 'package:flutter/material.dart';

import '../data/people.dart';
import '../lunar/almanac.dart';
import '../lunar/lunar_calendar.dart';
import '../theme.dart';
import 'day_sections.dart';

/// "Xem ngày": trực, mansion, lucky directions, clashing and harmonious ages, and the family members the day clashes
/// with.
class AlmanacCard extends StatelessWidget {
  const AlmanacCard({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final a = DayAlmanac(date);
    final scheme = Theme.of(context).colorScheme;
    final lich = context.lich;
    final clashing = [
      for (final p in PeopleScope.of(context).people)
        if (a.clashesWith(p.birthYear)) p,
    ];
    final harmony = [...tripleHarmonyOf(a.dayBranch).map((b) => chi[b]), chi[sixHarmonyOf(a.dayBranch)]];

    return SectionCard(
      icon: Icons.auto_awesome_outlined,
      title: 'Xem ngày',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (a.tamNuong || a.nguyetKy || clashing.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (a.tamNuong) _Warning('Ngày Tam nương: kiêng việc lớn', lich.holiday),
                  if (a.nguyetKy) _Warning('Ngày Nguyệt kỵ: kiêng đi xa, việc lớn', lich.holiday),
                  for (final p in clashing) _Warning('Xung tuổi ${p.name} (${canChiYear(p.birthYear)})', lich.holiday),
                ],
              ),
            ),
          _Row('Trực', a.truc.name, a.truc.text),
          _Row(
            'Sao',
            a.mansion.$1,
            a.mansion.$2 ? 'Sao tốt (cát tú)' : 'Sao xấu (hung tú)',
            valueColor: a.mansion.$2 ? lich.goodDay : null,
          ),
          _Row('Xuất hành', 'Hỷ thần: ${a.hyThan}', 'Tài thần: ${a.taiThan}'),
          _Row('Tuổi xung', 'Tuổi ${chi[a.clashBranch]}', 'Lục xung với ngày ${chi[a.dayBranch]}'),
          _Row('Tuổi hợp', harmony.join(', '), 'Tam hợp và lục hợp'),
          const SizedBox(height: 6),
          Text(
            'Theo quan niệm dân gian, chỉ để tham khảo.',
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, this.detail, {this.valueColor});

  final String label;
  final String value;
  final String detail;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(fontWeight: FontWeight.w700, color: valueColor),
                ),
                Text(detail, style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.warning_amber_rounded, size: 15, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5),
          ),
        ),
      ],
    ),
  );
}
