import 'package:flutter/material.dart';

import '../data/birthdays.dart';
import '../data/people.dart';
import '../events/event_store.dart';
import '../lunar/almanac.dart';
import '../lunar/format.dart';
import '../lunar/lunar_calendar.dart';
import '../theme.dart';
import 'day_sections.dart';
import 'result_box.dart';

/// "Tra tuổi": age, zodiac, nạp âm element, harmonious and clashing branches for a lunar birth year.
class AgeLookupCard extends StatefulWidget {
  const AgeLookupCard({super.key});

  @override
  State<AgeLookupCard> createState() => _AgeLookupCardState();
}

class _AgeLookupCardState extends State<AgeLookupCard> {
  int _year = 1990;

  Future<void> _save() => showPersonSheet(context, Person(name: '', birthYear: _year));

  @override
  Widget build(BuildContext context) {
    final info = AgeInfo(_year);
    final currentYear = solarToLunar(today()).year;
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      icon: Icons.person_search_outlined,
      title: 'Tra tuổi',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<int>(
            initialValue: _year,
            isExpanded: true,
            menuMaxHeight: 360,
            decoration: InputDecoration(
              labelText: 'Năm sinh (âm lịch)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            items: [
              for (var y = currentYear; y >= 1900; y--)
                DropdownMenuItem(value: y, child: Text('$y · ${canChiYear(y)}')),
            ],
            onChanged: (y) => setState(() => _year = y!),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Text(
              'Sinh trước Tết thì chọn năm âm lịch trước đó.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
          ResultBox(
            big: '${info.animal} ${info.canChi}',
            lines: [
              'Năm nay ${info.ageIn(currentYear)} tuổi (tuổi âm)',
              'Mệnh ${info.element} · ${info.napAm}',
              'Tam hợp: ${info.tripleHarmony.join(', ')} · Lục hợp: ${info.sixHarmony}',
              'Tứ hành xung: ${info.fourClash.join(', ')}',
              for (final y in [currentYear, currentYear + 1]) _houseLine(HouseCheck(_year, y)),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.person_add_alt_rounded),
            label: const Text('Lưu vào Cả nhà'),
          ),
        ],
      ),
    );
  }
}

/// "Làm nhà năm 2026 (37 tuổi): tốt" or the problems found.
String _houseLine(HouseCheck c) {
  final problems = [?c.kimLauText, if (!c.hoangOcPalace.$2) c.hoangOcPalace.$1, if (c.tamTai) 'Tam tai'];
  return 'Làm nhà năm ${c.year} (${c.age} tuổi): ${problems.isEmpty ? 'tốt (${c.hoangOcPalace.$1})' : 'phạm ${problems.join(', ')}'}';
}

/// "Xem tuổi vợ chồng": elements, stems and branches of two birth years.
class CoupleCard extends StatefulWidget {
  const CoupleCard({super.key});

  @override
  State<CoupleCard> createState() => _CoupleCardState();
}

class _CoupleCardState extends State<CoupleCard> {
  int _husband = 1990;
  int _wife = 1992;

  static const _verdict = ['Nên cân nhắc', 'Bình thường', 'Khá hợp', 'Rất hợp'];

  Widget _picker(String label, int value, ValueChanged<int> onChanged) {
    final currentYear = solarToLunar(today()).year;
    return DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      menuMaxHeight: 360,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      items: [
        for (var y = currentYear; y >= 1900; y--) DropdownMenuItem(value: y, child: Text('$y · ${canChiYear(y)}')),
      ],
      onChanged: (y) => onChanged(y!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = CoupleCheck(_husband, _wife);
    final scheme = Theme.of(context).colorScheme;
    String mark(String relation, {required List<String> good, required List<String> bad}) =>
        good.contains(relation) ? '✓' : (bad.contains(relation) ? '✗' : '–');
    return SectionCard(
      icon: Icons.favorite_border_rounded,
      title: 'Xem tuổi vợ chồng',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _picker('Chồng', _husband, (y) => setState(() => _husband = y))),
              const SizedBox(width: 10),
              Expanded(child: _picker('Vợ', _wife, (y) => setState(() => _wife = y))),
            ],
          ),
          const SizedBox(height: 12),
          ResultBox(
            big: _verdict[c.score],
            lines: [
              '${mark(c.element, good: ['sinh', 'hòa'], bad: ['khắc'])} Mệnh: ${c.h.element} và ${c.w.element} '
                  '(${c.element == 'khắc' ? 'tương khắc' : (c.element == 'sinh' ? 'tương sinh' : 'cùng hành')})',
              '${mark(c.stem, good: ['hợp'], bad: ['xung'])} Thiên can: ${c.h.canChi.split(' ').first} – '
                  '${c.w.canChi.split(' ').first} (${c.stem})',
              '${mark(c.branch, good: ['hợp'], bad: ['xung'])} Địa chi: ${c.h.canChi.split(' ').last} – '
                  '${c.w.canChi.split(' ').last} (${c.branch})',
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Xét mệnh nạp âm, thiên can và địa chi. Theo quan niệm dân gian, chỉ để tham khảo.',
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

/// Adds or edits a family member, with an optional solar or lunar birthday.
Future<void> showPersonSheet(BuildContext context, Person person) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _PersonSheet(person: person),
);

class _PersonSheet extends StatefulWidget {
  const _PersonSheet({required this.person});

  final Person person;

  @override
  State<_PersonSheet> createState() => _PersonSheetState();
}

class _PersonSheetState extends State<_PersonSheet> {
  late final _name = TextEditingController(text: widget.person.name);
  late int _year = widget.person.birthYear;
  late bool _hasBirthday = widget.person.hasBirthday;
  late bool _lunar = widget.person.birthLunar;
  late int _day = widget.person.birthDay ?? 1;
  late int _month = widget.person.birthMonth ?? 1;
  bool _nameError = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = true);
      return;
    }
    await saveWithBirthday(
      PeopleScope.of(context),
      EventScope.of(context),
      widget.person.copyWith(
        name: name,
        birthYear: _year,
        birthDay: () => _hasBirthday ? _day : null,
        birthMonth: () => _hasBirthday ? _month : null,
        birthLunar: _lunar,
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    await removeWithBirthday(PeopleScope.of(context), EventScope.of(context), widget.person);
    if (mounted) Navigator.pop(context);
  }

  Widget _select(String label, int value, int max, ValueChanged<int> onChanged) => DropdownButtonFormField<int>(
    key: ValueKey('$label$max'),
    initialValue: value.clamp(1, max),
    isExpanded: true,
    menuMaxHeight: 320,
    decoration: InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
    items: [for (var i = 1; i <= max; i++) DropdownMenuItem(value: i, child: Text('$i'))],
    onChanged: (v) => onChanged(v!),
  );

  @override
  Widget build(BuildContext context) {
    final currentYear = solarToLunar(today()).year;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.person.id == null ? 'Thêm người' : 'Sửa thông tin',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (widget.person.id != null)
                  IconButton(tooltip: 'Xoá', onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              autofocus: widget.person.id == null,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) {
                if (_nameError) setState(() => _nameError = false);
              },
              decoration: InputDecoration(
                labelText: 'Tên',
                hintText: 'VD: Bố, Mẹ, Bé Na…',
                errorText: _nameError ? 'Nhập tên' : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _year,
              isExpanded: true,
              menuMaxHeight: 360,
              decoration: InputDecoration(
                labelText: 'Năm sinh (âm lịch)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              items: [
                for (var y = currentYear; y >= 1900; y--)
                  DropdownMenuItem(value: y, child: Text('$y · ${canChiYear(y)}')),
              ],
              onChanged: (y) => setState(() => _year = y!),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Nhớ sinh nhật'),
              subtitle: const Text('Tạo sự kiện lặp hằng năm, nhắc trước 1 ngày'),
              value: _hasBirthday,
              onChanged: (v) => setState(() => _hasBirthday = v),
            ),
            if (_hasBirthday) ...[
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Dương lịch')),
                  ButtonSegment(value: true, label: Text('Âm lịch')),
                ],
                selected: {_lunar},
                onSelectionChanged: (v) => setState(() => _lunar = v.first),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _select('Ngày', _day, _lunar ? 30 : 31, (v) => setState(() => _day = v))),
                  const SizedBox(width: 10),
                  Expanded(child: _select('Tháng', _month, 12, (v) => setState(() => _month = v))),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _lunar
                      ? 'Sinh nhật âm lịch: mỗi năm rơi vào ngày dương khác nhau, app tự tính.'
                      : 'Sinh nhật theo dương lịch.',
                  style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('Lưu')),
          ],
        ),
      ),
    );
  }
}

/// "Cả nhà": family members with their age, element and next birthday. The calendar warns on days that clash with
/// them; birthdays become yearly events.
class FamilyCard extends StatelessWidget {
  const FamilyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = PeopleScope.of(context);
    final events = EventScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final now = today();
    final currentYear = solarToLunar(now).year;
    return SectionCard(
      icon: Icons.family_restroom_rounded,
      title: 'Cả nhà',
      trailing: TextButton.icon(
        onPressed: () => showPersonSheet(context, Person(name: '', birthYear: currentYear - 30)),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Thêm'),
      ),
      child: store.people.isEmpty
          ? Text(
              'Thêm tuổi và sinh nhật của mọi người: lịch sẽ báo ngày xung tuổi, nhắc sinh nhật (cả âm lịch) và '
              'cho biết sắp tròn bao nhiêu tuổi.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            )
          : Column(
              children: [
                for (final p in store.people)
                  Builder(
                    builder: (context) {
                      final info = AgeInfo(p.birthYear);
                      final next = nextBirthday(p, events, now);
                      final left = next == null ? 0 : daysBetween(now, next.date);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () => showPersonSheet(context, p),
                        leading: CircleAvatar(
                          backgroundColor: scheme.primary.withValues(alpha: 0.12),
                          child: Text(info.animal, style: const TextStyle(fontSize: 20)),
                        ),
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${p.birthYear} · ${info.canChi} · ${info.ageIn(currentYear)} tuổi · mệnh ${info.element}',
                            ),
                            if (next != null)
                              Text(
                                '🎂 ${p.birthDay}/${p.birthMonth}${p.birthLunar ? ' âm' : ''} · tròn ${next.age} tuổi · '
                                '${left == 0 ? 'hôm nay!' : 'còn $left ngày'}',
                                style: TextStyle(color: context.lich.goodDay, fontWeight: FontWeight.w600),
                              ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                      );
                    },
                  ),
              ],
            ),
    );
  }
}
