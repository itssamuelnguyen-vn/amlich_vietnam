import 'package:flutter/material.dart';

import '../data/settings.dart';
import '../events/event.dart';
import '../events/event_store.dart';
import '../lunar/format.dart';
import '../lunar/lunar_calendar.dart';
import '../theme.dart';
import '../widget/widget_bridge.dart';
import '../widgets/date_inputs.dart';

/// Opens the editor for a new event on [date], or for [event] when given.
Future<void> openEventEditor(BuildContext context, {DateTime? date, Event? event}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => EventEditor(initialDate: date ?? today(), event: event),
      fullscreenDialog: true,
    ),
  );
}

class EventEditor extends StatefulWidget {
  const EventEditor({super.key, required this.initialDate, this.event});

  final DateTime initialDate;
  final Event? event;

  @override
  State<EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<EventEditor> {
  late final _title = TextEditingController(text: widget.event?.title ?? '');
  late final _note = TextEditingController(text: widget.event?.note ?? '');
  late EventCalendar _calendar = widget.event?.calendar ?? EventCalendar.solar;
  late Repeat _repeat = widget.event?.repeat ?? Repeat.none;
  late int _color = widget.event?.color ?? 0;
  // New events remind a day ahead by default; that is what death anniversaries and birthdays need.
  late int _remindDays = widget.event?.remindDays ?? 1;
  late DateTime _solar;
  late LunarDate _lunar;
  bool _titleError = false;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    if (e == null) {
      _solar = widget.initialDate;
      _lunar = solarToLunar(_solar);
    } else if (e.isLunar) {
      _lunar = LunarDate(e.day, e.month, e.year, isLeap: e.leap);
      _solar = e.start;
    } else {
      _solar = DateTime(e.year, e.month, e.day);
      _lunar = solarToLunar(_solar);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  void _switchCalendar(EventCalendar c) {
    setState(() {
      // Carry the date over so switching does not lose the chosen day.
      if (c == EventCalendar.lunar) {
        _lunar = solarToLunar(_solar);
      } else {
        _solar = lunarToSolar(_lunar) ?? _solar;
      }
      _calendar = c;
    });
  }

  Future<void> _setReminder(int days) async {
    setState(() => _remindDays = days);
    if (days == Event.noReminder) return;
    final messenger = ScaffoldMessenger.of(context);
    if (!await WidgetBridge.requestNotificationPermission()) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Thông báo đang bị tắt. Bật lại trong Cài đặt của điện thoại để nhận nhắc nhở.')),
      );
    }
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = true);
      return;
    }
    final lunar = _calendar == EventCalendar.lunar;
    final event = Event(
      id: widget.event?.id,
      title: title,
      note: _note.text.trim(),
      calendar: _calendar,
      day: lunar ? _lunar.day : _solar.day,
      month: lunar ? _lunar.month : _solar.month,
      year: lunar ? _lunar.year : _solar.year,
      leap: lunar && _lunar.isLeap,
      repeat: _repeat,
      color: _color,
      remindDays: _remindDays,
    );
    await EventScope.of(context).save(event);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xoá sự kiện?'),
        content: Text('"${widget.event!.title}" sẽ bị xoá vĩnh viễn.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xoá')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await EventScope.of(context).delete(widget.event!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lunar = _calendar == EventCalendar.lunar;
    final lunarLength = daysInLunarMonth(_lunar.month, _lunar.year, isLeap: _lunar.isLeap);
    final lunarSolar = lunarToSolar(_lunar);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event == null ? 'Thêm sự kiện' : 'Sửa sự kiện'),
        actions: [
          if (widget.event != null)
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
            autofocus: widget.event == null,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            onChanged: (_) {
              if (_titleError) setState(() => _titleError = false);
            },
            decoration: InputDecoration(
              labelText: 'Tên sự kiện',
              hintText: 'VD: Giỗ ông nội, Sinh nhật mẹ…',
              errorText: _titleError ? 'Nhập tên sự kiện' : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 20),
          _Label('Ngày theo'),
          SegmentedButton<EventCalendar>(
            segments: const [
              ButtonSegment(value: EventCalendar.solar, label: Text('Dương lịch'), icon: Icon(Icons.wb_sunny_outlined)),
              ButtonSegment(value: EventCalendar.lunar, label: Text('Âm lịch'), icon: Icon(Icons.nightlight_outlined)),
            ],
            selected: {_calendar},
            onSelectionChanged: (s) => _switchCalendar(s.first),
          ),
          const SizedBox(height: 14),
          if (!lunar)
            SolarDateField(label: 'Ngày', value: _solar, onChanged: (d) => setState(() => _solar = d))
          else ...[
            LunarDateInput(value: _lunar, onChanged: (v) => setState(() => _lunar = v)),
            const SizedBox(height: 6),
            Text(
              lunarSolar != null
                  ? 'Dương lịch: ${weekdayNames[lunarSolar.weekday - 1]}, '
                        '${two(lunarSolar.day)}/${two(lunarSolar.month)}/${lunarSolar.year}'
                  : 'Tháng này năm ${_lunar.year} chỉ có $lunarLength ngày, sự kiện sẽ rơi vào ngày cuối tháng.',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ],
          const SizedBox(height: 20),
          _Label('Lặp lại'),
          SegmentedButton<Repeat>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: Repeat.none, label: Text('Không')),
              ButtonSegment(value: Repeat.monthly, label: Text('Hằng tháng')),
              ButtonSegment(value: Repeat.yearly, label: Text('Hằng năm')),
            ],
            selected: {_repeat},
            onSelectionChanged: (s) => setState(() => _repeat = s.first),
          ),
          if (lunar && _repeat == Repeat.yearly)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Phù hợp cho ngày giỗ, sinh nhật âm lịch. Năm có tháng nhuận vẫn tính theo tháng thường.',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
              ),
            ),
          const SizedBox(height: 20),
          _Label('Nhắc trước'),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final (days, label) in const [
                (Event.noReminder, 'Không nhắc'),
                (0, 'Đúng ngày'),
                (1, '1 ngày'),
                (3, '3 ngày'),
                (7, '7 ngày'),
              ])
                ChoiceChip(label: Text(label), selected: _remindDays == days, onSelected: (_) => _setReminder(days)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _remindDays == Event.noReminder
                  ? 'Không có thông báo cho sự kiện này.'
                  : 'Thông báo lúc ${two(SettingsScope.of(context).value.reminderHour)}:'
                        '${two(SettingsScope.of(context).value.reminderMinute)} (đổi giờ trong Cài đặt).',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
            ),
          ),
          const SizedBox(height: 20),
          _Label('Màu'),
          Wrap(
            spacing: 12,
            children: [
              for (var i = 0; i < eventColors.length; i++)
                GestureDetector(
                  onTap: () => setState(() => _color = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
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
          const SizedBox(height: 20),
          TextField(
            controller: _note,
            minLines: 3,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Ghi chú',
              alignLabelWithHint: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.lich.goodDay.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: context.lich.goodDay),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sự kiện được lưu trên máy. Đồng bộ Google Calendar sẽ có ở bản sau.',
                    style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
  );
}
