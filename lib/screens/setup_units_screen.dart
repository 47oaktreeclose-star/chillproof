import 'package:flutter/material.dart';

import '../app_state.dart';
import '../db.dart';
import '../models.dart';
import '../temperature.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/extra_slot.dart';

/// Step 3 of setup: how many fridges and freezers, and what they're called.
class SetupUnitsScreen extends StatefulWidget {
  const SetupUnitsScreen({super.key});
  @override
  State<SetupUnitsScreen> createState() => _SetupUnitsScreenState();
}

class _SetupUnitsScreenState extends State<SetupUnitsScreen> {
  final Map<UnitType, List<TextEditingController>> _names = {
    UnitType.fridge: [TextEditingController(text: defaultUnitName(UnitType.fridge, 1))],
    UnitType.freezer: [TextEditingController(text: defaultUnitName(UnitType.freezer, 1))],
  };
  bool _saving = false;

  @override
  void dispose() {
    for (final l in _names.values) {
      for (final c in l) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _setCount(UnitType t, int n) {
    final list = _names[t]!;
    setState(() {
      while (list.length < n) {
        list.add(TextEditingController(text: defaultUnitName(t, list.length + 1)));
      }
      while (list.length > n) {
        list.removeLast().dispose();
      }
    });
  }

  Future<void> _increase(UnitType t) async {
    final state = AppState.instance;
    final count = _names[t]!.length;
    if (count < state.maxFor(t)) {
      _setCount(t, count + 1);
      return;
    }
    final bought = await buyExtraSlot(context, t);
    if (bought && mounted) _setCount(t, count + 1);
  }

  Future<void> _continue() async {
    final total = _names.values.fold<int>(0, (a, l) => a + l.length);
    if (total == 0) {
      showSnack(context, 'Add at least one fridge or freezer');
      return;
    }
    setState(() => _saving = true);
    final units = <StorageUnit>[];
    for (final t in UnitType.values) {
      final list = _names[t]!;
      for (var i = 0; i < list.length; i++) {
        final n = list[i].text.trim();
        units.add(StorageUnit(type: t, name: n.isEmpty ? defaultUnitName(t, i + 1) : n));
      }
    }
    await AppState.instance.createInitialUnits(units);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              const StepHeader(
                step: 3,
                of: 4,
                title: 'Your fridges and freezers',
                subtitle: 'Choose how many you have, then give each a name you\'ll recognise, '
                    'like "Meat fridge" or "Bar freezer".',
              ),
              const SizedBox(height: 18),
              for (final t in UnitType.values) ...[
                _CounterCard(
                  type: t,
                  count: _names[t]!.length,
                  included: t == UnitType.fridge ? AppState.baseFridges : AppState.baseFreezers,
                  max: AppState.instance.maxFor(t),
                  onMinus: _names[t]!.isEmpty ? null : () => _setCount(t, _names[t]!.length - 1),
                  onPlus: () => _increase(t),
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < _names[t]!.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: _names[t]![i],
                      maxLength: 30,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        counterText: '',
                        labelText: '${t.label} ${i + 1} name',
                        prefixIcon: Icon(t.icon, color: Brand.iceDeep),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
              ],
              const InfoBanner(
                icon: Icons.info_outline_rounded,
                text: 'Your subscription includes up to ${AppState.baseFridges} fridges and '
                    '${AppState.baseFreezers} freezers. Tap + beyond that to add more for a '
                    'one-off £0.99 each. You can rename or change these later in Settings.',
              ),
              const SizedBox(height: 22),
              FilledButton(onPressed: _saving ? null : _continue, child: const Text('Continue')),
            ],
          ),
        ),
      ),
    );
  }
}

class _CounterCard extends StatelessWidget {
  final UnitType type;
  final int count;
  final int included;
  final int max;
  final VoidCallback? onMinus;
  final VoidCallback onPlus;
  const _CounterCard({
    required this.type,
    required this.count,
    required this.included,
    required this.max,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    final atLimit = count >= max;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: const Color(0xFFE6F6FD), borderRadius: BorderRadius.circular(14)),
            child: Icon(type.icon, color: Brand.iceDeep),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(type.plural, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              Text(
                max > included ? '$max available ($included included + ${max - included} extra)' : '$included included',
                style: const TextStyle(color: Brand.muted, fontSize: 13),
              ),
            ]),
          ),
          IconButton.outlined(onPressed: onMinus, icon: const Icon(Icons.remove_rounded)),
          SizedBox(
            width: 36,
            child: Text('$count',
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Jakarta', fontWeight: FontWeight.w800, fontSize: 22)),
          ),
          IconButton.filled(
            onPressed: onPlus,
            style: IconButton.styleFrom(backgroundColor: atLimit ? Brand.mint : Brand.navy),
            icon: Icon(atLimit ? Icons.add_shopping_cart_rounded : Icons.add_rounded),
            tooltip: atLimit ? 'Buy an extra ${type.label.toLowerCase()}' : 'Add',
          ),
        ]),
      ),
    );
  }
}
