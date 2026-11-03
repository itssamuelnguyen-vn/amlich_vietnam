import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/backup.dart';
import '../data/settings.dart';
import '../events/event.dart';
import '../lunar/format.dart';
import '../lunar/lunar_calendar.dart';
import '../theme.dart';
import '../widgets/date_inputs.dart';
import '../widgets/day_sections.dart';
import 'counter.dart';

Future<void> openCounter(BuildContext context, DayCounter c) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CounterScreen(counterId: c.id!)));

Future<void> openCounterEditor(BuildContext context, {DayCounter? counter}) =>
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => CounterEditor(counter: counter), fullscreenDialog: true));

/// "Đếm ngày" card in the tools tab: the saved counters and a button to add one.
class CountersCard extends StatelessWidget {
  const CountersCard({super.key});

  @override
  Widget build(BuildContext context) {
    final counters = CounterScope.of(context).counters;
    final scheme = Theme.of(context).colorScheme;
    final now = today();
    return SectionCard(
      icon: Icons.favorite_outline_rounded,
      title: 'Đếm ngày',
      trailing: TextButton.icon(
        onPressed: () => openCounterEditor(context),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Tạo'),
      ),
      child: counters.isEmpty
          ? Text(
              'Lưu những cột mốc để luôn biết đã bao nhiêu ngày: ngày yêu nhau, ngày cưới, ngày con chào đời, '
              'ngày bỏ thuốc… hoặc đếm ngược tới một ngày sắp tới.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            )
          : Column(
              children: [
                for (final c in counters)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _CounterTile(counter: c, today: now),
                  ),
              ],
            ),
    );
  }
}

class _CounterTile extends StatelessWidget {
  const _CounterTile({required this.counter, required this.today});

  final DayCounter counter;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final color = eventColors[counter.color.clamp(0, eventColors.length - 1)];
    final future = counter.isFuture(today);
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => openCounter(context, counter),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text(counter.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      counter.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
                    ),
                    Text(
                      '${future ? 'Đến' : 'Từ'} ${two(counter.date.day)}/${two(counter.date.month)}/${counter.date.year}',
                      style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCount(counter.daysOn(today)),
                    style: TextStyle(fontFamily: 'serif', fontSize: 24, fontWeight: FontWeight.w700, color: color),
                  ),
                  Text(future ? 'ngày nữa' : 'ngày', style: TextStyle(fontSize: 12, color: color)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen view of one counter, love-day-app style: photo or gradient, the big day count, a years/months/days
/// breakdown and the coming milestones.
class CounterScreen extends StatelessWidget {
  const CounterScreen({super.key, required this.counterId});

  final int counterId;

  @override
  Widget build(BuildContext context) {
    final store = CounterScope.of(context);
    final counter = store.byId(counterId);
    if (counter == null) return const Scaffold(); // just deleted
    final settings = SettingsScope.of(context);
    final now = today();
    final color = eventColors[counter.color.clamp(0, eventColors.length - 1)];
    final future = counter.isFuture(now);
    final days = counter.daysOn(now);
    final ymd = future ? ymdBetween(now, counter.date) : ymdBetween(counter.date, now);
    final breakdown = [
      if (ymd.years > 0) '${ymd.years} năm',
      if (ymd.months > 0) '${ymd.months} tháng',
      if (ymd.days > 0 || (ymd.years == 0 && ymd.months == 0)) '${ymd.days} ngày',
    ].join(' ');
    final hasPhoto = counter.photo.isNotEmpty && File(counter.photo).existsSync();
    final pinned = settings.value.counterWidgetId == counter.id;
    final lunar = solarToLunar(counter.date);
    const onPhoto = Colors.white;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: onPhoto,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          IconButton(
            tooltip: pinned ? 'Đang hiện trên widget' : 'Hiện trên widget "Đếm ngày"',
            onPressed: () =>
                settings.update(settings.value.copyWith(counterWidgetId: () => pinned ? null : counter.id)),
            icon: Icon(pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined),
          ),
          IconButton(
            tooltip: 'Sửa',
            onPressed: () => openCounterEditor(context, counter: counter),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (hasPhoto)
            Image.file(File(counter.photo), fit: BoxFit.cover, cacheWidth: 1440)
          else
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color.lerp(color, Colors.white, 0.15)!, Color.lerp(color, Colors.black, 0.45)!],
                ),
              ),
            ),
          // Darkens photos so the text stays readable.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: hasPhoto ? 0.65 : 0.25),
                ],
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              children: [
                Center(child: Text(counter.emoji, style: const TextStyle(fontSize: 56))),
                const SizedBox(height: 8),
                Text(
                  counter.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: onPhoto, fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 24),
                Text(
                  future ? 'CÒN' : (counter.firstDayIsOne ? 'NGÀY THỨ' : 'ĐÃ ĐƯỢC'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: onPhoto.withValues(alpha: 0.85),
                    letterSpacing: 3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatCount(days),
                    style: const TextStyle(
                      fontFamily: 'serif',
                      fontSize: 96,
                      height: 1.05,
                      fontWeight: FontWeight.w700,
                      color: onPhoto,
                      shadows: [Shadow(blurRadius: 12, color: Colors.black38)],
                    ),
                  ),
                ),
                Text(
                  'ngày',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: onPhoto.withValues(alpha: 0.9), fontSize: 20),
                ),
                const SizedBox(height: 10),
                Text(
                  breakdown,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: onPhoto, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  '${future ? 'Đến' : 'Từ'} ${weekdayNames[counter.date.weekday - 1]}, '
                  '${two(counter.date.day)}/${two(counter.date.month)}/${counter.date.year} '
                  '(${lunar.day}/${lunar.month} âm)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: onPhoto.withValues(alpha: 0.8), fontSize: 13.5),
                ),
                if (!future) ...[const SizedBox(height: 28), _Milestones(counter: counter, today: now)],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Milestones extends StatelessWidget {
  const _Milestones({required this.counter, required this.today});

  final DayCounter counter;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final milestones = counter.upcomingMilestones(today);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CÁC MỐC SẮP TỚI',
            style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          for (final m in milestones)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(m.isAnniversary ? Icons.cake_outlined : Icons.flag_outlined, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.label,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${weekdayNames[m.date.weekday - 1]}, ${two(m.date.day)}/${two(m.date.month)}/${m.date.year}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'còn ${formatCount(daysBetween(today, m.date))} ngày',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class CounterEditor extends StatefulWidget {
  const CounterEditor({super.key, this.counter});

  final DayCounter? counter;

  @override
  State<CounterEditor> createState() => _CounterEditorState();
}

class _CounterEditorState extends State<CounterEditor> {
  late final _title = TextEditingController(text: widget.counter?.title ?? '');
  late DateTime _date = widget.counter?.date ?? today();
  late String _emoji = widget.counter?.emoji ?? '❤️';
  late int _color = widget.counter?.color ?? 0;
  late bool _firstDayIsOne = widget.counter?.firstDayIsOne ?? true;
  late bool _notify = widget.counter?.notify ?? true;
  late String _photo = widget.counter?.photo ?? '';
  bool _titleError = false;
  bool _saved = false;

  String get _original => widget.counter?.photo ?? '';

  /// Deletes a photo copied in this session that is about to be replaced or dropped.
  void _dropUnsaved(String path) {
    if (path.isNotEmpty && path != _original) _deleteFile(path);
  }

  @override
  void dispose() {
    if (!_saved) _dropUnsaved(_photo);
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final path = await FilePicker.pickImage();
      if (path == null) return;
      _dropUnsaved(_photo);
      setState(() => _photo = path);
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không mở được ảnh: ${e.message}')));
      }
    }
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = true);
      return;
    }
    final old = _original;
    _saved = true;
    await CounterScope.of(context).save(
      DayCounter(
        id: widget.counter?.id,
        title: title,
        date: _date,
        emoji: _emoji,
        color: _color,
        firstDayIsOne: _firstDayIsOne,
        notify: _notify,
        photo: _photo,
      ),
    );
    if (old.isNotEmpty && old != _photo) _deleteFile(old);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final c = widget.counter!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xoá bộ đếm?'),
        content: Text('"${c.title}" sẽ bị xoá vĩnh viễn.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xoá')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final settings = SettingsScope.of(context);
    await CounterScope.of(context).delete(c);
    if (settings.value.counterWidgetId == c.id) {
      await settings.update(settings.value.copyWith(counterWidgetId: () => null));
    }
    if (c.photo.isNotEmpty) _deleteFile(c.photo);
    if (mounted) Navigator.pop(context);
  }

  static void _deleteFile(String path) {
    try {
      File(path).deleteSync();
    } on FileSystemException {
      // Already gone.
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700);
    final hasPhoto = _photo.isNotEmpty && File(_photo).existsSync();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.counter == null ? 'Tạo bộ đếm ngày' : 'Sửa bộ đếm'),
        actions: [
          if (widget.counter != null)
            IconButton(tooltip: 'Xoá', onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded)),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(onPressed: _save, child: const Text('Lưu')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(
            controller: _title,
            autofocus: widget.counter == null,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            onChanged: (_) {
              if (_titleError) setState(() => _titleError = false);
            },
            decoration: InputDecoration(
              labelText: 'Tên',
              hintText: 'VD: Bên nhau, Ngày cưới, Bé Na chào đời…',
              errorText: _titleError ? 'Nhập tên bộ đếm' : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 16),
          SolarDateField(label: 'Ngày mốc', value: _date, onChanged: (d) => setState(() => _date = d)),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Ngày đã qua thì đếm số ngày từ đó tới nay; ngày sắp tới thì đếm ngược.',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ngày mốc là ngày thứ 1'),
            subtitle: const Text('Như các app đếm ngày yêu; tắt đi thì ngày mốc là ngày 0'),
            value: _firstDayIsOne,
            onChanged: (v) => setState(() => _firstDayIsOne = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Thông báo khi tới mốc'),
            subtitle: const Text('100, 200 … 1000 ngày, mỗi 1000 ngày và kỷ niệm hằng năm'),
            value: _notify,
            onChanged: (v) => setState(() => _notify = v),
          ),
          const SizedBox(height: 8),
          Text('Biểu tượng', style: label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in counterEmoji)
                ChoiceChip(
                  label: Text(e, style: const TextStyle(fontSize: 20)),
                  showCheckmark: false,
                  selected: _emoji == e,
                  onSelected: (_) => setState(() => _emoji = e),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Màu', style: label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: [
              for (var i = 0; i < eventColors.length; i++)
                GestureDetector(
                  onTap: () => setState(() => _color = i),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: eventColors[i],
                      shape: BoxShape.circle,
                      border: Border.all(color: i == _color ? scheme.onSurface : Colors.transparent, width: 3),
                    ),
                    child: i == _color ? const Icon(Icons.check_rounded, color: Colors.white) : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Ảnh nền', style: label),
          const SizedBox(height: 8),
          if (hasPhoto)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(File(_photo), height: 160, fit: BoxFit.cover, cacheWidth: 720),
            ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickPhoto,
                icon: const Icon(Icons.photo_outlined),
                label: Text(hasPhoto ? 'Đổi ảnh' : 'Chọn ảnh'),
              ),
              if (hasPhoto) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    _dropUnsaved(_photo);
                    setState(() => _photo = '');
                  },
                  child: const Text('Bỏ ảnh'),
                ),
              ],
            ],
          ),
          Text(
            'Ảnh được chép vào app; không có trong file sao lưu.',
            style: TextStyle(fontSize: 12, color: context.lich.goodDay),
          ),
        ],
      ),
    );
  }
}
