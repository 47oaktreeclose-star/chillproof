import 'package:flutter/material.dart';

import '../app_state.dart';
import '../billing.dart';
import '../temperature.dart';
import 'common.dart';

/// Buys one extra fridge or freezer slot (one-off £0.99). Returns true on success.
Future<bool> buyExtraSlot(BuildContext context, UnitType type) async {
  final state = AppState.instance;
  final billing = Billing.instance;
  final productId = state.nextExtraProduct(type);
  if (productId == null) {
    showSnack(context, 'You have reached the maximum number of ${type.plural.toLowerCase()}.');
    return false;
  }
  if (!billing.available || !billing.hasProduct(productId)) {
    await state.refreshEntitlements();
  }
  if (!context.mounted) return false;
  if (!billing.hasProduct(productId)) {
    showSnack(context, 'Extra ${type.plural.toLowerCase()} are not available right now. Please try again later.');
    return false;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(type.icon, size: 32),
      title: Text('Add an extra ${type.label.toLowerCase()}'),
      content: Text(
        'Unlock one more ${type.label.toLowerCase()} for a one-off payment of '
        '${billing.extraPrice(productId)}. This is not part of your monthly subscription '
        'and stays with your Google account.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('Buy ${billing.extraPrice(productId)}'),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;

  final r = await billing.buy(productId);
  if (r == BuyResult.success) state.grantPurchase(productId);
  if (!context.mounted) return r == BuyResult.success;
  switch (r) {
    case BuyResult.success:
      showSnack(context, 'Extra ${type.label.toLowerCase()} unlocked');
      return true;
    case BuyResult.pending:
      showSnack(context, 'Payment pending – your extra ${type.label.toLowerCase()} will unlock when it completes.');
    case BuyResult.cancelled:
      break;
    case BuyResult.error:
    case BuyResult.unavailable:
      showSnack(context, 'The purchase could not be completed. Please try again.');
  }
  return false;
}
