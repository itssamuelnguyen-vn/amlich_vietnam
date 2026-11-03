import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../counters/counter_screens.dart';
import '../lunar/format.dart';
import '../lunar/lunar_calendar.dart';
import '../theme.dart';
import '../widgets/age_cards.dart';
import '../widgets/date_inputs.dart';
import '../widgets/day_sections.dart';
import '../widgets/good_days_card.dart';
import '../widgets/result_box.dart';

/// Tools: choosing a good day, ages and family, the distance between two dates, and date arithmetic.
class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key, required this.onShowDate});

  final ValueChanged<DateTime> onShowDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tiện ích', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          const CountersCard(),
          const SizedBox(height: 16),
          GoodDaysCard(onShowDate: onShowDate),
          const SizedBox(height: 16),
          const AgeLookupCard(),
          const SizedBox(height: 16),
          const FamilyCard(),
          const SizedBox(height: 16),
          const _DistanceCard(),
          const SizedBox(height: 16),
          _AddCard(onShowDate: onShowDate),
        ],
      ),
    );
  }
}

/// Working days (Monday–Friday) in [a, b], both included.
int workingDays(DateTime a, DateTime b) {
  final total = daysBetween(a, b) + 1;
  var count = total ~/ 7 * 5;
  for (var i = 0; i < total % 7; i++) {
    if ((a.weekday - 1 + i) % 7 < 5) count++;
  }
  return count;
}

class _DistanceCard extends StatefulWidget {
  const _DistanceCard();

  @override
  State<_DistanceCard> createState() => _DistanceCardState();
}

class _DistanceCardState extends State<_DistanceCard> {
  late DateTime _from = today();
  late DateTime _to = DateTime(today().year, 12, 31);
  bool _includeEnd = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (a, b) = _from.isAfter(_to) ? (_to, _from) : (_from, _to);
    final days = daysBetween(a, b) + (_includeEnd ? 1 : 0);
    final ymd = ymdBetween(a, _includeEnd ? DateTime(b.year, b.month, b.day + 1) : b);
    final parts = [
      if (ymd.years > 0) '${ymd.years} năm',
      if (ymd.months > 0) '${ymd.months} tháng',
      if (ymd.days > 0 || (ymd.years == 0 && ymd.months == 0)) '${ymd.days} ngày',
    ];

    return SectionCard(
      icon: Icons.straighten_rounded,
      title: 'Khoảng cách giữa hai ngày',
      child: Column(
        children: [
          SolarDateField(label: 'Từ ngày', value: _from, onChanged: (d) => setState(() => _from = d)),
          Center(
            child: IconButton(
              tooltip: 'Đảo hai ngày',
              onPressed: () => setState(() {
                final from = _from;
                _from = _to;
                _to = from;
              }),
              icon: const Icon(Icons.swap_vert_rounded),
            ),
          ),
          SolarDateField(label: 'Đến ngày', value: _to, onChanged: (d) => setState(() => _to = d)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tính cả ngày cuối'),
            value: _includeEnd,
            onChanged: (v) => setState(() => _includeEnd = v),
          ),
          ResultBox(
            big: '$days ngày',
            lines: [
              if (days >= 7) '= ${days ~/ 7} tuần${days % 7 > 0 ? ' ${days % 7} ngày' : ''}',
              if (days >= 28) '= ${parts.join(' ')}',
              '${workingDays(a, _includeEnd ? b : DateTime(b.year, b.month, b.day - 1)).clamp(0, days)} ngày làm việc (T2–T6)',
            ],
          ),
          if (_from.isAfter(_to))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '"Đến ngày" đang trước "Từ ngày", kết quả tính theo chiều ngược lại.',
                style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

enum _Unit { day, week, month, year }

class _AddCard extends StatefulWidget {
  const _AddCard({required this.onShowDate});

  final ValueChanged<DateTime> onShowDate;

  @override
  State<_AddCard> createState() => _AddCardState();
}

class _AddCardState extends State<_AddCard> {
  late DateTime _base = today();
  final _amount = TextEditingController(text: '100');
  bool _add = true;
  _Unit _unit = _Unit.day;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  DateTime? get _result {
    final n = int.tryParse(_amount.text);
    if (n == null) return null;
    final k = _add ? n : -n;
    final r = switch (_unit) {
      _Unit.day => DateTime(_base.year, _base.month, _base.day + k),
      _Unit.week => DateTime(_base.year, _base.month, _base.day + 7 * k),
      _Unit.month => _addMonths(_base, k),
      _Unit.year => _addMonths(_base, 12 * k),
    };
    return r.year < 1900 || r.year > 2199 ? null : r;
  }

  /// Keeps the day of month, clamped to the target month's length (31/01 + 1 month = 28 or 29/02).
  static DateTime _addMonths(DateTime d, int months) {
    final m = DateTime(d.year, d.month + months);
    return DateTime(m.year, m.month, math.min(d.day, daysInMonth(m.year, m.month)));
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final lunar = result == null ? null : solarToLunar(result);
    return SectionCard(
      icon: Icons.calculate_outlined,
      title: 'Cộng / trừ ngày',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SolarDateField(label: 'Ngày gốc', value: _base, onChanged: (d) => setState(() => _base = d)),
          const SizedBox(height: 12),
          Row(
            children: [
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: true, icon: Icon(Icons.add_rounded)),
                  ButtonSegment(value: false, icon: Icon(Icons.remove_rounded)),
                ],
                selected: {_add},
                onSelectionChanged: (s) => setState(() => _add = s.first),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    labelText: 'Số lượng',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<_Unit>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: _Unit.day, label: Text('Ngày')),
              ButtonSegment(value: _Unit.week, label: Text('Tuần')),
              ButtonSegment(value: _Unit.month, label: Text('Tháng')),
              ButtonSegment(value: _Unit.year, label: Text('Năm')),
            ],
            selected: {_unit},
            onSelectionChanged: (s) => setState(() => _unit = s.first),
          ),
          const SizedBox(height: 14),
          if (result == null)
            const ResultBox(big: '—', lines: ['Nhập số lượng (kết quả phải trong khoảng 1900–2199)'])
          else
            ResultBox(
              big: '${two(result.day)}/${two(result.month)}/${result.year}',
              lines: [
                weekdayNames[result.weekday - 1],
                'Âm lịch: ${lunar!.day}/${lunar.month}${lunar.isLeap ? ' nhuận' : ''} năm ${canChiYear(lunar.year)}',
              ],
              action: TextButton.icon(
                onPressed: () => widget.onShowDate(result),
                icon: const Icon(Icons.calendar_month_rounded),
                label: const Text('Xem trên lịch'),
                style: TextButton.styleFrom(foregroundColor: context.lich.gold),
              ),
            ),
        ],
      ),
    );
  }
}
