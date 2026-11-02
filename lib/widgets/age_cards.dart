import 'package:flutter/material.dart';

import '../data/people.dart';
import '../lunar/almanac.dart';
import '../lunar/format.dart';
import '../lunar/lunar_calendar.dart';
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

  Future<void> _save() async {
    final name = await showDialog<String>(context: context, builder: (_) => const _NameDialog());
    if (name == null || name.isEmpty || !mounted) return;
    await PeopleScope.of(context).add(Person(name: name, birthYear: _year));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã thêm $name vào tuổi cả nhà')));
    }
  }

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
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.person_add_alt_rounded),
            label: const Text('Lưu vào tuổi cả nhà'),
          ),
        ],
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog();

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Tên người này'),
    content: TextField(
      controller: _name,
      autofocus: true,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(hintText: 'VD: Bố, Mẹ, Bé Na…'),
      onSubmitted: (v) => Navigator.pop(context, v.trim()),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
      FilledButton(onPressed: () => Navigator.pop(context, _name.text.trim()), child: const Text('Lưu')),
    ],
  );
}

/// "Tuổi cả nhà": the saved family members. The calendar warns on days that clash with any of them.
class FamilyCard extends StatelessWidget {
  const FamilyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = PeopleScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final currentYear = solarToLunar(today()).year;
    return SectionCard(
      icon: Icons.family_restroom_rounded,
      title: 'Tuổi cả nhà',
      child: store.people.isEmpty
          ? Text(
              'Chưa có ai. Dùng "Tra tuổi" ở trên rồi bấm "Lưu vào tuổi cả nhà"; lịch sẽ báo những ngày xung tuổi.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            )
          : Column(
              children: [
                for (final p in store.people)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: scheme.primary.withValues(alpha: 0.12),
                      child: Text(AgeInfo(p.birthYear).animal, style: const TextStyle(fontSize: 20)),
                    ),
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      '${p.birthYear} · ${canChiYear(p.birthYear)} · ${AgeInfo(p.birthYear).ageIn(currentYear)} tuổi · '
                      'mệnh ${AgeInfo(p.birthYear).element}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Xoá ${p.name}',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => store.remove(p),
                    ),
                  ),
              ],
            ),
    );
  }
}
