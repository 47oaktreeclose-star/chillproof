import 'package:flutter/material.dart';

import '../app_state.dart';
import '../db.dart';
import '../models.dart';
import '../temperature.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'email_log_screen.dart';
import 'legal_screen.dart';
import 'records_screen.dart';
import 'schedule_screen.dart';
import 'session_detail_screen.dart';
import 'settings_screen.dart';
import 'take_temps_screen.dart';
import 'units_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<CheckSession> _today = [];
  CheckSession? _last;

  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final today = await AppDb.instance.sessions(from: startOfDay(now), to: startOfDay(now).add(const Duration(days: 1)));
    final last = await AppDb.instance.sessions(limit: 1);
    if (!mounted) return;
    setState(() {
      _today = today;
      _last = last.isEmpty ? null : last.first;
    });
  }

  ReminderTime? get _nextCheck {
    final s = AppState.instance.settings;
    final now = DateTime.now();
    final mins = now.hour * 60 + now.minute;
    for (final t in s.times) {
      if (t.hour * 60 + t.minute > mins) return t;
    }
    return s.times.isEmpty ? null : s.times.first;
  }

  void _go(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w)).then((_) => _load());

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final s = state.settings;
    final done = _today.length;
    final due = s.checksPerDay;
    final progress = due == 0 ? 1.0 : (done / due).clamp(0.0, 1.0);
    final next = _nextCheck;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: Brand.headerGradient,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const BrandLogo(size: 34),
                      const SizedBox(width: 10),
                      const Wordmark(size: 20, onDark: true),
                      const Spacer(),
                      IconButton(
                        onPressed: () => _go(const SettingsScreen()),
                        icon: const Icon(Icons.settings_rounded, color: Colors.white),
                        tooltip: 'Settings',
                      ),
                    ]),
                    const SizedBox(height: 18),
                    Text(state.profile?.businessName ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontFamily: 'Jakarta', fontWeight: FontWeight.w800, fontSize: 24)),
                    const SizedBox(height: 4),
                    Text(fmtDayDate(DateTime.now()),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('$done of $due checks done today',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: Colors.white.withValues(alpha: 0.15),
                              valueColor: AlwaysStoppedAnimation(done >= due ? Brand.mint : Brand.ice),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(width: 16),
                      if (next != null && s.remindersOn)
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('Next reminder', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                          Text(next.label,
                              style: const TextStyle(
                                  color: Colors.white, fontFamily: 'Jakarta', fontWeight: FontWeight.w800, fontSize: 20)),
                        ]),
                      const SizedBox(width: 8),
                    ]),
                  ]),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            sliver: SliverList.list(children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64), backgroundColor: Brand.iceDeep),
                onPressed: () => _go(const TakeTempsScreen()),
                icon: const Icon(Icons.thermostat_rounded, size: 26),
                label: const Text('Take temperatures', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '${state.fridges.length} fridge${state.fridges.length == 1 ? '' : 's'} · '
                  '${state.freezers.length} freezer${state.freezers.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: Brand.muted),
                ),
              ),
              const SectionLabel('Last check'),
              if (_last == null)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('No checks recorded yet. Tap "Take temperatures" to record your first one.',
                        style: TextStyle(color: Brand.muted, height: 1.4)),
                  ),
                )
              else
                _LastCheckCard(session: _last!, scale: s.scale, onTap: () => _go(SessionDetailScreen(session: _last!))),
              const SectionLabel('Manage'),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.45,
                children: [
                  _Tile(Icons.history_rounded, 'Records', 'All past checks', () => _go(const RecordsScreen())),
                  _Tile(Icons.mark_email_unread_rounded, 'Email log', 'Send to ${state.profile?.email ?? ''}',
                      () => _go(const EmailLogScreen())),
                  _Tile(Icons.alarm_rounded, 'Reminders', s.remindersOn ? s.times.map((t) => t.label).join(', ') : 'Off',
                      () => _go(const ScheduleScreen())),
                  _Tile(Icons.kitchen_rounded, 'Fridges & freezers', 'Add, rename, remove', () => _go(const UnitsScreen())),
                  _Tile(Icons.gavel_rounded, 'Food safety rules', 'UK temperature limits', () => _go(const LegalScreen())),
                  _Tile(Icons.settings_rounded, 'Settings', 'Business, units, plan', () => _go(const SettingsScreen())),
                ],
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _LastCheckCard extends StatelessWidget {
  final CheckSession session;
  final TempScale scale;
  final VoidCallback onTap;
  const _LastCheckCard({required this.session, required this.scale, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final st = session.status;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(fmtDateTime(session.takenAt),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              StatusChip(st,
                  label: st == TempStatus.ok
                      ? 'All OK'
                      : '${session.issues} issue${session.issues == 1 ? '' : 's'}'),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final r in session.readings)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: r.status == TempStatus.ok ? Brand.surface : r.status.tint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: '${r.unitName}  ', style: const TextStyle(color: Brand.muted, fontSize: 13)),
                    TextSpan(
                      text: formatTemp(r.tempC, scale),
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: r.status == TempStatus.ok ? Brand.ink : r.status.color),
                    ),
                  ])),
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _Tile(this.icon, this.title, this.subtitle, this.onTap);

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: Brand.iceDeep, size: 26),
              const Spacer(),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 2),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
            ]),
          ),
        ),
      );
}
