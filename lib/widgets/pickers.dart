import 'package:flutter/material.dart';

import '../lunar/format.dart';
import '../lunar/lunar_calendar.dart';
import '../theme.dart';
import 'date_inputs.dart';

/// Dialog to jump to a month: year with arrows, then a 4×3 grid of months.
Future<DateTime?> showMonthPicker(BuildContext context, DateTime initial) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) => _MonthPickerDialog(initial: initial),
  );
}

class _MonthPickerDialog extends StatefulWidget {
  const _MonthPickerDialog({required this.initial});

  final DateTime initial;

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year = widget.initial.year;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = today();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: _year > 1900 ? () => setState(() => _year--) : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '$_year',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${yearAnimal(_year)} ${canChiYear(_year)}',
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _year < 2199 ? () => setState(() => _year++) : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.5,
              children: [
                for (var m = 1; m <= 12; m++)
                  _MonthButton(
                    label: 'Th $m',
                    selected: m == widget.initial.month && _year == widget.initial.year,
                    current: m == now.month && _year == now.year,
                    onTap: () => Navigator.pop(context, DateTime(_year, m)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => Navigator.pop(context, DateTime(now.year, now.month)),
              icon: const Icon(Icons.today_rounded),
              label: const Text('Tháng này'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthButton extends StatelessWidget {
  const _MonthButton({required this.label, required this.selected, required this.current, required this.onTap});

  final String label;
  final bool selected;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lich = context.lich;
    return Material(
      color: selected ? null : scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: selected ? LinearGradient(colors: [lich.heroTop, lich.heroBottom]) : null,
          border: current && !selected ? Border.all(color: scheme.primary, width: 1.5) : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w700, color: selected ? lich.onHero : scheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet converting a lunar date to the solar calendar. Pops with the solar date to show it on the calendar.
Future<DateTime?> showLunarConverter(BuildContext context, DateTime initial) {
  return showModalBottomSheet<DateTime>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _LunarConverter(initial: solarToLunar(initial)),
  );
}

class _LunarConverter extends StatefulWidget {
  const _LunarConverter({required this.initial});

  final LunarDate initial;

  @override
  State<_LunarConverter> createState() => _LunarConverterState();
}

class _LunarConverterState extends State<_LunarConverter> {
  late int _day = widget.initial.day;
  late int _month = widget.initial.month;
  late int _year = widget.initial.year;
  late bool _leap = widget.initial.isLeap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lich = context.lich;
    final leapMonth = leapMonthOf(_year);
    final canLeap = leapMonth == _month;
    final leap = _leap && canLeap;
    final result = lunarToSolar(LunarDate(_day, _month, _year, isLeap: leap));
    final length = daysInLunarMonth(_month, _year, isLeap: leap);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Đổi ngày âm sang dương', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            leapMonth == null
                ? 'Năm $_year không có tháng nhuận'
                : 'Năm $_year nhuận tháng $leapMonth · tháng này có $length ngày',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 16),
          LunarDateInput(
            value: LunarDate(_day, _month, _year, isLeap: leap),
            onChanged: (v) => setState(() {
              _day = v.day;
              _month = v.month;
              _year = v.year;
              _leap = v.isLeap;
            }),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(colors: [lich.heroTop, lich.heroBottom]),
            ),
            child: result == null
                ? Text(
                    'Tháng này chỉ có $length ngày',
                    style: TextStyle(color: lich.onHero, fontSize: 16, fontWeight: FontWeight.w600),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DƯƠNG LỊCH', style: TextStyle(color: lich.gold, fontSize: 11, letterSpacing: 1.5)),
                      Text(
                        '${weekdayNames[result.weekday - 1]}, ${two(result.day)}/${two(result.month)}/${result.year}',
                        style: TextStyle(color: lich.onHero, fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        _distance(result),
                        style: TextStyle(color: lich.onHero.withValues(alpha: 0.75), fontSize: 13),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: result == null ? null : () => Navigator.pop(context, result),
              icon: const Icon(Icons.calendar_month_rounded),
              label: const Text('Xem trên lịch'),
            ),
          ),
        ],
      ),
    );
  }

  static String _distance(DateTime d) {
    final days = daysBetween(today(), d);
    if (days == 0) return 'Chính là hôm nay';
    return days > 0 ? 'Còn $days ngày nữa' : 'Đã qua ${-days} ngày';
  }
}
