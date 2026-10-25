import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../db.dart';
import '../models.dart';
import '../temperature.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'session_detail_screen.dart';

/// Walks through every fridge then freezer, one at a time, then submits.
class TakeTempsScreen extends StatefulWidget {
  const TakeTempsScreen({super.key});
  @override
  State<TakeTempsScreen> createState() => _TakeTempsScreenState();
}

class _TakeTempsScreenState extends State<TakeTempsScreen> {
  late final List<StorageUnit> _units;
  late final TempScale _scale;
  final Map<int, double> _valuesC = {};
  final Map<int, String> _actions = {};
  final Map<int, String> _otherNotes = {};
  Map<int, double> _last = {};
  int _index = 0;
  bool _submitting = false;
  final _checkedBy = TextEditingController();
  final _textCtrl = TextEditingController();
  final _otherCtrl = TextEditingController();
  String? _actionError;

  @override
  void initState() {
    super.initState();
    final s = AppState.instance;
    _units = [...s.fridges, ...s.freezers];
    _scale = s.settings.scale;
    AppDb.instance.lastReadingByUnit().then((m) {
      if (mounted) setState(() => _last = m);
    });
    _syncFields();
  }

  @override
  void dispose() {
    _checkedBy.dispose();
    _textCtrl.dispose();
    _otherCtrl.dispose();
    super.dispose();
  }

  bool get _onReview => _index >= _units.length;
  StorageUnit get _unit => _units[_index];

  void _syncFields() {
    if (_onReview) return;
    final v = _valuesC[_unit.id];
    _textCtrl.text = v == null ? '' : formatTemp(v, _scale, withSymbol: false);
    _otherCtrl.text = _otherNotes[_unit.id] ?? '';
    _actionError = null;
  }

  void _setFromDisplay(double display, {bool updateText = true}) {
    setState(() {
      _valuesC[_unit.id!] = displayToCelsius(display, _scale);
      final a = assess(_unit.type, _valuesC[_unit.id!]!, _scale);
      if (a.status == TempStatus.ok) _actions.remove(_unit.id);
      _actionError = null;
      if (updateText) _textCtrl.text = round1(display).toStringAsFixed(1);
    });
  }

  void _onTyped(String raw) {
    final t = raw.replaceAll(',', '.').trim();
    final v = double.tryParse(t);
    if (v == null) {
      setState(() => _valuesC.remove(_unit.id));
      return;
    }
    final c = fromScale(v, _scale);
    if (c < -60 || c > 60) return; // ignore obviously wrong input
    _setFromDisplay(v, updateText: false);
  }

  void _nudge(double delta) {
    final current = _valuesC[_unit.id];
    final display = current == null ? toScale(Limits.sliderStartC(_unit.type), _scale) : toScale(current, _scale);
    HapticFeedback.selectionClick();
    _setFromDisplay(display + delta);
  }

  bool _validateCurrent() {
    final v = _valuesC[_unit.id];
    if (v == null) {
      showSnack(context, 'Enter the temperature for ${_unit.name}');
      return false;
    }
    final a = assess(_unit.type, v, _scale);
    if (a.status != TempStatus.ok) {
      final action = _actions[_unit.id];
      if (action == null) {
        setState(() => _actionError = 'Choose what you did about this reading');
        return false;
      }
      if (action == 'Other' && _otherCtrl.text.trim().isEmpty) {
        setState(() => _actionError = 'Describe the action you took');
        return false;
      }
    }
    _otherNotes[_unit.id!] = _otherCtrl.text.trim();
    return true;
  }

  void _next() {
    if (!_validateCurrent()) return;
    final v = _valuesC[_unit.id]!;
    final a = assess(_unit.type, v, _scale);
    if (a.status == TempStatus.critical && !_warnedFor.contains(_unit.id)) {
      _warnedFor.add(_unit.id!);
      _showCriticalDialog(a);
      return;
    }
    setState(() {
      _index++;
      _syncFields();
    });
  }

  final Set<int> _warnedFor = {};

  Future<void> _showCriticalDialog(TempAssessment a) async {
    final reading = formatTemp(_valuesC[_unit.id]!, _scale);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(a.tooHigh ? Icons.local_fire_department_rounded : Icons.ac_unit_rounded,
            color: TempStatus.critical.color, size: 36),
        title: Text('${_unit.name}: $reading'),
        content: Text('${a.title}.\n\n${a.advice}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _warnedFor.remove(_unit.id);
            },
            child: const Text('Re-enter reading'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44), backgroundColor: TempStatus.critical.color),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _index++;
                _syncFields();
              });
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _back() {
    if (_index == 0) return;
    if (!_onReview) _otherNotes[_unit.id!] = _otherCtrl.text.trim();
    setState(() {
      _index--;
      _syncFields();
    });
  }

  void _jumpTo(int i) => setState(() {
        _index = i;
        _syncFields();
      });

  String _actionText(int unitId) {
    final a = _actions[unitId];
    if (a == null) return '';
    if (a == 'Other') return _otherNotes[unitId]?.isNotEmpty == true ? _otherNotes[unitId]! : 'Other';
    return a;
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final readings = <Reading>[
      for (final u in _units)
        () {
          final c = _valuesC[u.id]!;
          final a = assess(u.type, c, _scale);
          return Reading(
            unitId: u.id!,
            unitName: u.name,
            unitType: u.type,
            tempC: c,
            status: a.status,
            action: a.status == TempStatus.ok ? '' : _actionText(u.id!),
          );
        }(),
    ];
    final session = await AppState.instance.submitCheck(readings, _checkedBy.text);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => SessionDetailScreen(session: session, justSaved: true)),
    );
  }

  Future<bool> _confirmDiscard() async {
    if (_valuesC.isEmpty) return true;
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard this check?'),
        content: const Text('The readings you have entered will not be saved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep going')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard')),
        ],
      ),
    );
    return r ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_index > 0 && !_onReview) {
          _back();
          return;
        }
        if (_onReview) {
          _back();
          return;
        }
        if (await _confirmDiscard() && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              if (await _confirmDiscard() && context.mounted) Navigator.of(context).pop();
            },
          ),
          title: Text(_onReview ? 'Review & submit' : 'Take temperatures'),
        ),
        body: SafeArea(
          child: Column(children: [
            _Progress(index: _index, total: _units.length),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _onReview ? _buildReview() : _buildUnitPage(),
              ),
            ),
            _buildBottomBar(),
          ]),
        ),
      ),
    );
  }

  Widget _buildBottomBar() => Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Brand.line))),
        child: Row(children: [
          if (_index > 0)
            Expanded(
              flex: 2,
              child: OutlinedButton(onPressed: _submitting ? null : _back, child: const Text('Back')),
            ),
          if (_index > 0) const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: _onReview
                ? FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Brand.mint, minimumSize: const Size.fromHeight(52)),
                    onPressed: _submitting ? null : _submit,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Submit'),
                  )
                : FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: _next,
                    child: Text(_index == _units.length - 1 ? 'Review' : 'Next'),
                  ),
          ),
        ]),
      );

  Widget _buildUnitPage() {
    final u = _unit;
    final v = _valuesC[u.id];
    final (minC, maxC) = Limits.sliderRangeC(u.type);
    final minD = round1(toScale(minC, _scale));
    final maxD = round1(toScale(maxC, _scale));
    final sliderD = (v == null ? toScale(Limits.sliderStartC(u.type), _scale) : toScale(v, _scale)).clamp(minD, maxD);
    final a = v == null ? null : assess(u.type, v, _scale);
    final last = _last[u.id];
    final target = u.type == UnitType.fridge
        ? 'Aim for ${formatTemp(Limits.fridgeRecommendedMax, _scale)} or below · legal max ${formatTemp(Limits.fridgeLegalMax, _scale)}'
        : 'Keep at ${formatTemp(Limits.freezerTarget, _scale)} or colder';

    return ListView(
      key: ValueKey('unit-${u.id}'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: const Color(0xFFE6F6FD), borderRadius: BorderRadius.circular(16)),
            child: Icon(u.type.icon, color: Brand.iceDeep, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u.name, style: Theme.of(context).textTheme.headlineSmall),
              Text(u.type.label, style: const TextStyle(color: Brand.muted)),
            ]),
          ),
        ]),
        const SizedBox(height: 6),
        Text(target, style: const TextStyle(color: Brand.muted, fontSize: 13)),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
            child: Column(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                IconButton.filledTonal(
                  onPressed: () => _nudge(-0.1),
                  icon: const Icon(Icons.remove_rounded),
                  iconSize: 28,
                  tooltip: 'Down 0.1',
                ),
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d{0,3}([.,]\d?)?'))],
                    style: TextStyle(
                      fontFamily: 'Jakarta',
                      fontWeight: FontWeight.w800,
                      fontSize: 52,
                      color: a == null ? Brand.ink : (a.status == TempStatus.ok ? Brand.ink : a.status.color),
                    ),
                    decoration: InputDecoration(
                      hintText: '0.0',
                      hintStyle: TextStyle(color: Brand.muted.withValues(alpha: 0.35)),
                      suffixText: _scale.symbol,
                      suffixStyle: const TextStyle(fontSize: 22, color: Brand.muted, fontWeight: FontWeight.w600),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: _onTyped,
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () => _nudge(0.1),
                  icon: const Icon(Icons.add_rounded),
                  iconSize: 28,
                  tooltip: 'Up 0.1',
                ),
              ]),
              const SizedBox(height: 6),
              Text(v == null ? 'Type the reading or use the slider' : 'Reading entered',
                  style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
              const SizedBox(height: 10),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: a?.status.color ?? Brand.iceDeep,
                  thumbColor: a?.status.color ?? Brand.iceDeep,
                  inactiveTrackColor: Brand.line,
                ),
                child: Slider(
                  value: sliderD.toDouble(),
                  min: minD,
                  max: maxD,
                  divisions: ((maxD - minD) * 10).round(),
                  label: '${round1(sliderD.toDouble()).toStringAsFixed(1)}${_scale.symbol}',
                  onChanged: (d) {
                    FocusScope.of(context).unfocus();
                    _setFromDisplay(d);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('${minD.toStringAsFixed(0)}${_scale.symbol}', style: const TextStyle(color: Brand.muted, fontSize: 12)),
                  Text('${maxD.toStringAsFixed(0)}${_scale.symbol}', style: const TextStyle(color: Brand.muted, fontSize: 12)),
                ]),
              ),
            ]),
          ),
        ),
        if (last != null) ...[
          const SizedBox(height: 10),
          Text('Last reading: ${formatTemp(last, _scale)}',
              textAlign: TextAlign.center, style: const TextStyle(color: Brand.muted, fontSize: 13)),
        ],
        const SizedBox(height: 14),
        if (a != null) _AssessmentCard(a),
        if (a != null && a.status != TempStatus.ok) ...[
          const SizedBox(height: 14),
          Text('What did you do about it?', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _actions[u.id],
            isExpanded: true,
            decoration: InputDecoration(
              hintText: 'Choose corrective action',
              errorText: _actionError,
              prefixIcon: const Icon(Icons.build_circle_outlined),
            ),
            items: [
              for (final s in correctiveActions) DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (s) => setState(() {
              if (s == null) return;
              _actions[u.id!] = s;
              _actionError = null;
            }),
          ),
          if (_actions[u.id] == 'Other') ...[
            const SizedBox(height: 10),
            TextField(
              controller: _otherCtrl,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Describe the action taken'),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildReview() {
    final statuses = [
      for (final u in _units) assess(u.type, _valuesC[u.id]!, _scale).status,
    ];
    final overall = worst(statuses);
    return ListView(
      key: const ValueKey('review'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: overall.tint, borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            Icon(overall.icon, color: overall.color, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                overall == TempStatus.ok
                    ? 'All ${_units.length} readings are within range.'
                    : '${statuses.where((s) => s != TempStatus.ok).length} reading(s) need attention. '
                        'Your corrective actions will be saved with this check.',
                style: TextStyle(color: Brand.ink.withValues(alpha: 0.9), fontWeight: FontWeight.w600, height: 1.35),
              ),
            ),
          ]),
        ),
        const SectionLabel('Readings'),
        Card(
          child: Column(children: [
            for (var i = 0; i < _units.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16, color: Brand.line),
              ListTile(
                onTap: () => _jumpTo(i),
                leading: Icon(_units[i].type.icon, color: Brand.iceDeep),
                title: Text(_units[i].name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: statuses[i] == TempStatus.ok
                    ? null
                    : Text(_actionText(_units[i].id!), maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(formatTemp(_valuesC[_units[i].id]!, _scale),
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: statuses[i] == TempStatus.ok ? Brand.ink : statuses[i].color)),
                  const SizedBox(width: 8),
                  Icon(statuses[i].icon, color: statuses[i].color, size: 20),
                ]),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 6),
        const Text('Tap a reading to change it.', style: TextStyle(color: Brand.muted, fontSize: 12.5)),
        const SectionLabel('Checked by'),
        TextField(
          controller: _checkedBy,
          maxLength: 30,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Your name or initials (optional)',
            prefixIcon: Icon(Icons.person_rounded),
            counterText: '',
          ),
        ),
        const SizedBox(height: 12),
        Text('The date and time will be recorded when you tap Submit.',
            style: TextStyle(color: Brand.muted.withValues(alpha: 0.9), fontSize: 12.5)),
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  final int index;
  final int total;
  const _Progress({required this.index, required this.total});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: LinearProgressIndicator(
              value: total == 0 ? 1 : (index / total).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Brand.line,
              valueColor: const AlwaysStoppedAnimation(Brand.iceDeep),
            ),
          ),
          const SizedBox(height: 6),
          Text(index >= total ? 'All $total recorded' : 'Unit ${index + 1} of $total',
              style: const TextStyle(color: Brand.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _AssessmentCard extends StatelessWidget {
  final TempAssessment a;
  const _AssessmentCard(this.a);
  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: a.status.tint,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: a.status.color.withValues(alpha: 0.3)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(a.status.icon, color: a.status.color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.title, style: TextStyle(color: a.status.color, fontWeight: FontWeight.w800, fontSize: 15)),
              if (a.advice.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(a.advice, style: TextStyle(color: Brand.ink.withValues(alpha: 0.85), height: 1.4)),
              ],
            ]),
          ),
        ]),
      );
}
