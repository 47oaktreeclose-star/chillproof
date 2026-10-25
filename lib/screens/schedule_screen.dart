import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../reminders.dart';
import '../temperature.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// How many checks a day, at what times, and how to be reminded.
class ScheduleScreen extends StatefulWidget {
  final bool onboarding;
  const ScheduleScreen({super.key, this.onboarding = false});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late List<ReminderTime> _times;
  late bool _on;
  late ReminderStyle _style;
  late TempScale _scale;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = AppState.instance.settings;
    _times = [...s.times];
    _on = s.remindersOn;
    _style = s.style;
    _scale = s.scale;
  }

  void _setCount(int n) {
    setState(() => _times = ReminderTime.defaultsFor(n).toList());
  }

  Future<void> _pick(int i) async {
    final t = _times[i];
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: t.hour, minute: t.minute),
      helpText: 'Check ${i + 1} time',
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _times[i] = ReminderTime(picked.hour, picked.minute);
      _times.sort();
    });
  }

  Future<void> _save() async {
    if (_times.toSet().length != _times.length) {
      showSnack(context, 'Two checks are set for the same time. Please change one.');
      return;
    }
    setState(() => _saving = true);
    if (_on) {
      final allowed = await Reminders.requestPermissions();
      if (!allowed && mounted) {
        showSnack(context, 'Notifications are turned off for ChillProof. Turn them on in your phone settings to get reminders.');
      }
    }
    final s = AppState.instance.settings.copyWith(
      times: _times,
      remindersOn: _on,
      style: _style,
      scale: _scale,
      scheduleConfigured: true,
    );
    await AppState.instance.saveSettings(s);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!widget.onboarding) {
      showSnack(context, _on ? 'Reminders saved' : 'Schedule saved');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.onboarding ? null : AppBar(title: const Text('Checks & reminders')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            if (widget.onboarding) ...[
              const StepHeader(
                step: 4,
                of: 4,
                title: 'When do you check?',
                subtitle: 'Choose how many times a day you record temperatures. '
                    'We\'ll remind you at each time.',
              ),
              const SizedBox(height: 8),
            ],
            const SectionLabel('Checks per day'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (var n = 1; n <= 6; n++)
                    ChoiceChip(
                      label: Text('$n×'),
                      selected: _times.length == n,
                      onSelected: (_) => _setCount(n),
                      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                ]),
              ),
            ),
            const InfoBanner(
              icon: Icons.lightbulb_outline_rounded,
              text: 'Check at least once a day. Many kitchens check at opening and closing.',
            ),
            const SectionLabel('Check times'),
            Card(
              child: Column(children: [
                for (var i = 0; i < _times.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16, color: Brand.line),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFE6F6FD),
                      child: Text('${i + 1}', style: const TextStyle(color: Brand.iceDeep, fontWeight: FontWeight.w800)),
                    ),
                    title: Text(_times[i].label,
                        style: const TextStyle(fontFamily: 'Jakarta', fontWeight: FontWeight.w800, fontSize: 20)),
                    subtitle: Text('Check ${i + 1}'),
                    trailing: const Icon(Icons.edit_rounded, color: Brand.muted),
                    onTap: () => _pick(i),
                  ),
                ],
              ]),
            ),
            const SectionLabel('Reminders'),
            Card(
              child: Column(children: [
                SwitchListTile(
                  value: _on,
                  onChanged: (v) => setState(() => _on = v),
                  title: const Text('Remind me at these times', style: TextStyle(fontWeight: FontWeight.w600)),
                  secondary: const Icon(Icons.notifications_active_rounded, color: Brand.iceDeep),
                ),
                if (_on) ...[
                  const Divider(height: 1, color: Brand.line),
                  RadioGroup<ReminderStyle>(
                    groupValue: _style,
                    onChanged: (v) => setState(() => _style = v ?? _style),
                    child: const Column(children: [
                      RadioListTile<ReminderStyle>(
                        value: ReminderStyle.notification,
                        title: Text('Push notification'),
                        subtitle: Text('A normal notification with a sound.'),
                      ),
                      RadioListTile<ReminderStyle>(
                        value: ReminderStyle.alarm,
                        title: Text('Alarm'),
                        subtitle: Text('Loud alarm sound that repeats until you open it.'),
                      ),
                    ]),
                  ),
                ],
              ]),
            ),
            const SectionLabel('Temperature units'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SegmentedButton<TempScale>(
                  segments: const [
                    ButtonSegment(value: TempScale.celsius, label: Text('Celsius °C')),
                    ButtonSegment(value: TempScale.fahrenheit, label: Text('Fahrenheit °F')),
                  ],
                  selected: {_scale},
                  onSelectionChanged: (v) => setState(() => _scale = v.first),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(widget.onboarding ? 'Finish setup' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
