import 'package:flutter/material.dart';

import '../app_state.dart';
import '../db.dart';
import '../export.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

enum LogPeriod { today, week, month, thisMonth, lastMonth, custom }

class EmailLogScreen extends StatefulWidget {
  const EmailLogScreen({super.key});
  @override
  State<EmailLogScreen> createState() => _EmailLogScreenState();
}

class _EmailLogScreenState extends State<EmailLogScreen> {
  LogPeriod _period = LogPeriod.week;
  DateTimeRange? _custom;
  List<CheckSession>? _sessions;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  (DateTime, DateTime) get _range {
    final today = startOfDay(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));
    return switch (_period) {
      LogPeriod.today => (today, tomorrow),
      LogPeriod.week => (today.subtract(const Duration(days: 6)), tomorrow),
      LogPeriod.month => (today.subtract(const Duration(days: 29)), tomorrow),
      LogPeriod.thisMonth => (DateTime(today.year, today.month, 1), tomorrow),
      LogPeriod.lastMonth => (DateTime(today.year, today.month - 1, 1), DateTime(today.year, today.month, 1)),
      LogPeriod.custom => _custom == null
          ? (today, tomorrow)
          : (startOfDay(_custom!.start), startOfDay(_custom!.end).add(const Duration(days: 1))),
    };
  }

  String _label(LogPeriod p) => switch (p) {
        LogPeriod.today => 'Today',
        LogPeriod.week => 'Last 7 days',
        LogPeriod.month => 'Last 30 days',
        LogPeriod.thisMonth => 'This month',
        LogPeriod.lastMonth => 'Last month',
        LogPeriod.custom => _custom == null
            ? 'Choose dates…'
            : '${fmtDateShort(_custom!.start)} – ${fmtDateShort(_custom!.end)}',
      };

  Future<void> _load() async {
    setState(() => _sessions = null);
    final (from, to) = _range;
    final list = await AppDb.instance.sessions(from: from, to: to);
    if (mounted) setState(() => _sessions = list);
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: _custom ?? DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now),
    );
    if (r == null) return;
    setState(() {
      _custom = r;
      _period = LogPeriod.custom;
    });
    _load();
  }

  LogExporter _exporter() {
    final (from, to) = _range;
    final s = AppState.instance;
    return LogExporter(
      profile: s.profile!,
      scale: s.settings.scale,
      from: from,
      to: to,
      sessions: _sessions ?? const [],
    );
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    final outcome = await _exporter().send();
    if (!mounted) return;
    setState(() => _busy = false);
    switch (outcome) {
      case SendOutcome.opened:
        break;
      case SendOutcome.sharedInstead:
        showSnack(context, 'No email app found, so we opened the share menu instead.');
      case SendOutcome.failed:
        showSnack(context, 'Couldn\'t open an email app. Set up an email account on this phone and try again.');
    }
  }

  Future<void> _preview() async {
    setState(() => _busy = true);
    try {
      await _exporter().preview();
    } catch (_) {
      if (mounted) showSnack(context, 'Couldn\'t open the preview.');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final email = AppState.instance.profile?.email ?? '';
    final sessions = _sessions;
    final issues = sessions?.fold<int>(0, (a, s) => a + s.issues) ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Email temperature log')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const SectionLabel('Period'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final p in LogPeriod.values)
                ChoiceChip(
                  label: Text(_label(p)),
                  selected: _period == p,
                  onSelected: (_) {
                    if (p == LogPeriod.custom) {
                      _pickCustom();
                    } else {
                      setState(() => _period = p);
                      _load();
                    }
                  },
                ),
            ]),
            const SectionLabel('Summary'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: sessions == null
                    ? const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          _Stat('${sessions.length}', 'checks'),
                          _Stat('${sessions.fold<int>(0, (a, s) => a + s.readings.length)}', 'readings'),
                          _Stat('$issues', 'issues', color: issues == 0 ? Brand.mint : const Color(0xFFDC2626)),
                        ]),
                      ]),
              ),
            ),
            const SectionLabel('Send to'),
            Card(
              child: ListTile(
                leading: const Icon(Icons.alternate_email_rounded, color: Brand.iceDeep),
                title: Text(email, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Your registered business email'),
              ),
            ),
            const SizedBox(height: 14),
            const InfoBanner(
              icon: Icons.picture_as_pdf_rounded,
              text: 'Your email app will open with the log in the message and a PDF attached, '
                  'laid out like a paper fridge/freezer temperature record. Just tap send.',
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy || sessions == null ? null : _send,
              icon: const Icon(Icons.send_rounded),
              label: const Text('Email log'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy || sessions == null ? null : _preview,
              icon: const Icon(Icons.visibility_rounded),
              label: const Text('Preview / print PDF'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;
  const _Stat(this.value, this.label, {this.color});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontFamily: 'Jakarta', fontWeight: FontWeight.w800, fontSize: 28, color: color ?? Brand.ink)),
          Text(label, style: const TextStyle(color: Brand.muted)),
        ]),
      );
}
