import 'package:flutter/material.dart';

import '../lunar/format.dart';
import '../lunar/lunar_calendar.dart';

/// Day / month / year dropdowns for a lunar date, plus a leap-month checkbox when that year's leap month is chosen.
class LunarDateInput extends StatelessWidget {
  const LunarDateInput({super.key, required this.value, required this.onChanged});

  final LunarDate value;
  final ValueChanged<LunarDate> onChanged;

  void _set({int? day, int? month, int? year, bool? leap}) {
    final m = month ?? value.month;
    final y = year ?? value.year;
    // Keep the leap flag only while the chosen month is still that year's leap month.
    final isLeap = (leap ?? value.isLeap) && leapMonthOf(y) == m;
    onChanged(LunarDate(day ?? value.day, m, y, isLeap: isLeap));
  }

  @override
  Widget build(BuildContext context) {
    final canLeap = leapMonthOf(value.year) == value.month;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _Select(
                label: 'Ngày',
                value: value.day,
                items: [for (var d = 1; d <= 30; d++) d],
                onChanged: (v) => _set(day: v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Select(
                label: 'Tháng',
                value: value.month,
                items: [for (var m = 1; m <= 12; m++) m],
                onChanged: (v) => _set(month: v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _Select(
                label: 'Năm',
                value: value.year,
                items: [for (var y = 1900; y <= 2199; y++) y],
                format: (y) => '$y · ${canChiYear(y)}',
                onChanged: (v) => _set(year: v),
              ),
            ),
          ],
        ),
        if (canLeap)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: value.isLeap,
            onChanged: (v) => _set(leap: v ?? false),
            title: Text('Tháng ${value.month} nhuận'),
          ),
      ],
    );
  }
}

class _Select extends StatelessWidget {
  const _Select({required this.label, required this.value, required this.items, required this.onChanged, this.format});

  final String label;
  final int value;
  final List<int> items;
  final ValueChanged<int> onChanged;
  final String Function(int)? format;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          menuMaxHeight: 320,
          // The closed field shows only the number; the menu adds [format]'s detail.
          selectedItemBuilder: (_) => [
            for (final i in items) Align(alignment: Alignment.centerLeft, child: Text('$i')),
          ],
          items: [for (final i in items) DropdownMenuItem(value: i, child: Text(format?.call(i) ?? '$i'))],
          onChanged: (v) => onChanged(v!),
        ),
      ),
    );
  }
}

/// A tappable field showing a solar date and its lunar date; opens the date picker.
class SolarDateField extends StatelessWidget {
  const SolarDateField({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: DateTime(1900),
      lastDate: DateTime(2199, 12, 31),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lunar = solarToLunar(value);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          suffixIcon: const Icon(Icons.edit_calendar_rounded),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${weekdayNames[value.weekday - 1]}, ${two(value.day)}/${two(value.month)}/${value.year}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            Text(
              'Âm lịch: ${lunar.day}/${lunar.month}${lunar.isLeap ? ' nhuận' : ''} năm ${canChiYear(lunar.year)}',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
