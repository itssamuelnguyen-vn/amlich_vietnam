import 'package:flutter/material.dart';

import '../data/settings.dart';
import '../events/event.dart';
import '../events/event_store.dart';
import '../lunar/format.dart';
import '../theme.dart';
import '../widgets/day_sections.dart';

/// A pregnancy counted from the first day of the last period (Naegele's rule: due 280 days later).
class Pregnancy {
  Pregnancy(this.start) : due = DateTime(start.year, start.month, start.day + 280);

  final DateTime start;
  final DateTime due;

  int daysOn(DateTime today) => daysBetween(start, today);

  /// (weeks, days) of gestation on [today].
  (int, int) ageOn(DateTime today) {
    final d = daysOn(today);
    return (d ~/ 7, d % 7);
  }

  int trimesterOn(DateTime today) {
    final w = daysOn(today) ~/ 7;
    return w < 14 ? 1 : (w < 28 ? 2 : 3);
  }

  DateTime weekStart(int week) => DateTime(start.year, start.month, start.day + week * 7);
}

/// Commonly recommended check-ups in Vietnam: (from week, to week, what).
const prenatalCheckups = [
  (11, 14, 'Siêu âm đo độ mờ da gáy, xét nghiệm sàng lọc (Double test/NIPT)'),
  (16, 19, 'Xét nghiệm sàng lọc Triple test (nếu bác sĩ chỉ định)'),
  (20, 25, 'Siêu âm hình thái thai nhi'),
  (24, 29, 'Xét nghiệm tiểu đường thai kỳ'),
  (30, 33, 'Siêu âm đánh giá tăng trưởng của bé'),
  (36, 41, 'Khám thai mỗi tuần, theo dõi tim thai và chuẩn bị sinh'),
];

/// "Theo dõi thai kỳ" in the tools tab.
class PregnancyCard extends StatelessWidget {
  const PregnancyCard({super.key});

  Future<void> _start(BuildContext context, {required bool byDueDate}) async {
    final settings = SettingsScope.of(context);
    final now = today();
    final picked = await showDatePicker(
      context: context,
      helpText: byDueDate ? 'Ngày dự sinh' : 'Ngày đầu của kỳ kinh cuối',
      initialDate: byDueDate ? DateTime(now.year, now.month + 6, now.day) : DateTime(now.year, now.month - 1, now.day),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null) return;
    final start = byDueDate ? DateTime(picked.year, picked.month, picked.day - 280) : picked;
    await settings.update(settings.value.copyWith(pregnancyStart: () => start));
  }

  Future<void> _addCheckups(BuildContext context, Pregnancy p) async {
    final events = EventScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final now = today();
    var added = 0;
    for (final (from, _, what) in prenatalCheckups) {
      final date = p.weekStart(from);
      final title = '🤰 Khám thai tuần $from';
      if (date.isBefore(now) || events.events.any((e) => e.title == title)) continue;
      await events.save(
        Event(
          title: title,
          note: what,
          calendar: EventCalendar.solar,
          day: date.day,
          month: date.month,
          year: date.year,
          color: 4,
          remindDays: 1,
        ),
      );
      added++;
    }
    messenger.showSnackBar(
      SnackBar(content: Text(added == 0 ? 'Các mốc khám đã có trong lịch' : 'Đã thêm $added mốc khám vào lịch')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final start = settings.value.pregnancyStart;
    final scheme = Theme.of(context).colorScheme;
    final lich = context.lich;
    final muted = TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant);

    if (start == null) {
      return SectionCard(
        icon: Icons.pregnant_woman_rounded,
        title: 'Theo dõi thai kỳ',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Biết tuần thai, ngày dự sinh và các mốc khám thai quan trọng.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _start(context, byDueDate: false),
              child: const Text('Nhập ngày đầu kỳ kinh cuối'),
            ),
            TextButton(
              onPressed: () => _start(context, byDueDate: true),
              child: const Text('Tôi đã biết ngày dự sinh'),
            ),
          ],
        ),
      );
    }

    final p = Pregnancy(start);
    final now = today();
    final (weeks, days) = p.ageOn(now);
    final left = daysBetween(now, p.due);
    final progress = (p.daysOn(now) / 280).clamp(0.0, 1.0);
    return SectionCard(
      icon: Icons.pregnant_woman_rounded,
      title: 'Theo dõi thai kỳ',
      trailing: PopupMenuButton<String>(
        tooltip: 'Tuỳ chọn',
        onSelected: (v) {
          if (v == 'change') _start(context, byDueDate: false);
          if (v == 'stop') settings.update(settings.value.copyWith(pregnancyStart: () => null));
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'change', child: Text('Đổi ngày')),
          PopupMenuItem(value: 'stop', child: Text('Kết thúc theo dõi')),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(colors: [lich.heroTop, lich.heroBottom]),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TUẦN THAI', style: TextStyle(color: lich.gold, fontSize: 11, letterSpacing: 1.5)),
                Text(
                  left < 0 ? 'Đã qua ngày dự sinh' : '$weeks tuần ${days > 0 ? '$days ngày' : ''}',
                  style: TextStyle(color: lich.onHero, fontFamily: 'serif', fontSize: 30, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Tam cá nguyệt thứ ${p.trimesterOn(now)} · dự sinh ${weekdayNames[p.due.weekday - 1]}, '
                  '${two(p.due.day)}/${two(p.due.month)}/${p.due.year}',
                  style: TextStyle(color: lich.onHero.withValues(alpha: 0.85)),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    color: lich.gold,
                    backgroundColor: lich.onHero.withValues(alpha: 0.2),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  left >= 0 ? 'Còn $left ngày nữa gặp bé' : 'Quá ngày dự sinh ${-left} ngày',
                  style: TextStyle(color: lich.onHero, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('Mốc khám thai', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          for (final (from, to, what) in prenatalCheckups)
            Builder(
              builder: (context) {
                final a = p.weekStart(from), b = p.weekStart(to);
                final status = now.isBefore(a)
                    ? 'còn ${daysBetween(now, a)} ngày'
                    : (now.isBefore(b) ? 'đang trong khoảng này' : 'đã qua');
                final active = !now.isBefore(a) && now.isBefore(b);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        active ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                        size: 18,
                        color: active ? lich.goodDay : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tuần $from–${to - 1} · ${two(a.day)}/${two(a.month)} – ${two(b.day)}/${two(b.month)}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text('$what · $status', style: muted),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _addCheckups(context, p),
            icon: const Icon(Icons.event_available_rounded),
            label: const Text('Thêm các mốc khám vào lịch'),
          ),
          const SizedBox(height: 6),
          Text(
            'Tuổi thai tính từ ngày đầu kỳ kinh cuối. Thông tin để tham khảo; lịch khám cụ thể theo chỉ định của bác sĩ.',
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
