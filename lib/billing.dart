import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Product IDs – these must be created with exactly these IDs in
/// Google Play Console (see PUBLISHING_GUIDE.md).
class ProductIds {
  /// Monthly subscription, £2.99/month.
  static const subscription = 'chillproof_monthly';

  /// One-off £0.99 purchases, each unlocking one extra fridge or freezer.
  /// Up to [maxExtras] of each can be bought.
  static const maxExtras = 10;
  static String extraFridge(int n) => 'extra_fridge_$n';
  static String extraFreezer(int n) => 'extra_freezer_$n';

  static Set<String> get all => {
        subscription,
        for (var i = 1; i <= maxExtras; i++) extraFridge(i),
        for (var i = 1; i <= maxExtras; i++) extraFreezer(i),
      };
}

enum BuyResult { success, cancelled, pending, error, unavailable }

/// Thin wrapper around Google Play Billing via the in_app_purchase plugin.
class Billing {
  Billing._();
  static final Billing instance = Billing._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool available = false;
  final Map<String, ProductDetails> products = {};

  /// Called whenever ownership changes: (subscribed, ownedExtraIds).
  void Function(bool? subscribed, Set<String> owned, {required bool fullRestore})? onEntitlements;

  Completer<void>? _restoreCompleter;
  final Map<String, Completer<BuyResult>> _pendingBuys = {};

  Future<void> init() async {
    try {
      available = await _iap.isAvailable();
    } catch (e) {
      available = false;
    }
    if (!available) return;
    _sub ??= _iap.purchaseStream.listen(_onPurchases, onError: (Object e) {
      debugPrint('purchaseStream error: $e');
    });
    try {
      final resp = await _iap.queryProductDetails(ProductIds.all);
      for (final p in resp.productDetails) {
        // A subscription may come back once per offer; keep the first.
        products.putIfAbsent(p.id, () => p);
      }
      if (resp.notFoundIDs.isNotEmpty) {
        debugPrint('Products not set up in Play Console: ${resp.notFoundIDs}');
      }
    } catch (e) {
      debugPrint('queryProductDetails failed: $e');
    }
  }

  String get subscriptionPrice => products[ProductIds.subscription]?.price ?? '£2.99';

  String extraPrice(String id) => products[id]?.price ?? '£0.99';

  bool hasProduct(String id) => products.containsKey(id);

  /// Asks Google Play which purchases this Google account owns.
  /// Returns false if Play could not be reached.
  Future<bool> restore() async {
    if (!available) return false;
    _restoreCompleter = Completer<void>();
    try {
      await _iap.restorePurchases();
      await _restoreCompleter!.future.timeout(const Duration(seconds: 12));
      return true;
    } catch (e) {
      debugPrint('restore failed: $e');
      return false;
    } finally {
      _restoreCompleter = null;
    }
  }

  Future<BuyResult> buy(String productId) async {
    if (!available) return BuyResult.unavailable;
    final product = products[productId];
    if (product == null) return BuyResult.unavailable;
    final c = Completer<BuyResult>();
    _pendingBuys[productId] = c;
    try {
      final started = await _iap.buyNonConsumable(
          purchaseParam: PurchaseParam(productDetails: product));
      if (!started) {
        _pendingBuys.remove(productId);
        return BuyResult.error;
      }
    } catch (e) {
      _pendingBuys.remove(productId);
      debugPrint('buy failed: $e');
      return BuyResult.error;
    }
    return c.future.timeout(const Duration(minutes: 10), onTimeout: () {
      _pendingBuys.remove(productId);
      return BuyResult.pending;
    });
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    final isRestore = _restoreCompleter != null && !_restoreCompleter!.isCompleted;
    bool? subscribed;
    final owned = <String>{};

    for (final p in list) {
      final ok = p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored;
      if (ok) {
        if (p.productID == ProductIds.subscription) {
          subscribed = true;
        } else {
          owned.add(p.productID);
        }
      }
      if (p.pendingCompletePurchase) {
        // Acknowledge the purchase or Google refunds it after 3 days.
        try {
          await _iap.completePurchase(p);
        } catch (e) {
          debugPrint('completePurchase failed: $e');
        }
      }
      final waiter = _pendingBuys.remove(p.productID);
      if (waiter != null && !waiter.isCompleted) {
        waiter.complete(switch (p.status) {
          PurchaseStatus.purchased || PurchaseStatus.restored => BuyResult.success,
          PurchaseStatus.canceled => BuyResult.cancelled,
          PurchaseStatus.pending => BuyResult.pending,
          PurchaseStatus.error => BuyResult.error,
        });
      }
    }

    if (isRestore) {
      // A restore lists everything currently owned, so absence means not owned.
      onEntitlements?.call(subscribed ?? false, owned, fullRestore: true);
      _restoreCompleter?.complete();
    } else if (subscribed != null || owned.isNotEmpty) {
      onEntitlements?.call(subscribed, owned, fullRestore: false);
    }
  }
}
