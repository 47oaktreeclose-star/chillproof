import 'package:flutter/material.dart';

import '../app_state.dart';
import '../db.dart';
import '../models.dart';
import '../temperature.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/extra_slot.dart';

class UnitsScreen extends StatelessWidget {
  const UnitsScreen({super.key});

  Future<void> _add(BuildContext context, UnitType t) async {
    final state = AppState.instance;
    if (!state.canAdd(t)) {
      final bought = await buyExtraSlot(context, t);
      if (!bought || !context.mounted) return;
    }
    final name = await promptText(context,
        title: 'Name your new ${t.label.toLowerCase()}',
        initial: defaultUnitName(t, state.countFor(t) + 1),
        action: 'Add');
    if (name == null || name.isEmpty) return;
    await state.addUnit(t, name);
  }

  Future<void> _rename(BuildContext context, StorageUnit u) async {
    final name = await promptText(context, title: 'Rename ${u.type.label.toLowerCase()}', initial: u.name);
    if (name == null || name.isEmpty) return;
    await AppState.instance.renameUnit(u, name);
  }

  Future<void> _remove(BuildContext context, StorageUnit u) async {
    if (AppState.instance.units.length <= 1) {
      showSnack(context, 'You need at least one fridge or freezer.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${u.name}?'),
        content: const Text('It will no longer appear in temperature checks. '
            'Past records for it are kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true) await AppState.instance.removeUnit(u);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final s = AppState.instance;
        return Scaffold(
          appBar: AppBar(title: const Text('Fridges & freezers')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              for (final t in UnitType.values) ...[
                SectionLabel('${t.plural} · ${s.countFor(t)} of ${s.maxFor(t)}'),
                Card(
                  child: Column(children: [
                    for (final u in (t == UnitType.fridge ? s.fridges : s.freezers)) ...[
                      ListTile(
                        leading: Icon(t.icon, color: Brand.iceDeep),
                        title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) => v == 'rename' ? _rename(context, u) : _remove(context, u),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'rename', child: Text('Rename')),
                            PopupMenuItem(value: 'remove', child: Text('Remove')),
                          ],
                        ),
                        onTap: () => _rename(context, u),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16, color: Brand.line),
                    ],
                    ListTile(
                      leading: Icon(
                        s.canAdd(t) ? Icons.add_circle_rounded : Icons.add_shopping_cart_rounded,
                        color: s.canAdd(t) ? Brand.navy : Brand.mint,
                      ),
                      title: Text(
                        s.canAdd(t) ? 'Add ${t.label.toLowerCase()}' : 'Buy an extra ${t.label.toLowerCase()} (£0.99)',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onTap: () => _add(context, t),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 16),
              const InfoBanner(
                icon: Icons.info_outline_rounded,
                text: 'Your plan includes ${AppState.baseFridges} fridges and ${AppState.baseFreezers} freezers. '
                    'Extra fridges and freezers are a one-off £0.99 each and stay with your Google account.',
              ),
            ],
          ),
        );
      },
    );
  }
}
