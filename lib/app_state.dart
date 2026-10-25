import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'billing.dart';
import 'db.dart';
import 'models.dart';
import 'reminders.dart';
import 'temperature.dart';

/// Single source of truth for the app. Screens listen to it and rebuild.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  static const baseFridges = 5;
  static const baseFreezers = 3;

  late SharedPreferences _prefs;
  bool loaded = false;

  BusinessProfile? profile;
  AppSettings settings = const AppSettings();
  List<StorageUnit> units = [];

  bool subscribed = false;
  DateTime? subscriptionCheckedAt;
  Set<String> ownedExtras = {};

  /// Lets you click through the app in debug builds without a Play purchase.
  bool debugBypass = false;

  List<StorageUnit> get fridges => units.where((u) => u.type == UnitType.fridge).toList();
  List<StorageUnit> get freezers => units.where((u) => u.type == UnitType.freezer).toList();

  int get extraFridges =>
      List.generate(ProductIds.maxExtras, (i) => ProductIds.extraFridge(i + 1))
          .where(ownedExtras.contains)
          .length;
  int get extraFreezers =>
      List.generate(ProductIds.maxExtras, (i) => ProductIds.extraFreezer(i + 1))
          .where(ownedExtras.contains)
          .length;

  int maxFor(UnitType t) =>
      t == UnitType.fridge ? baseFridges + extraFridges : baseFreezers + extraFreezers;
  int countFor(UnitType t) => t == UnitType.fridge ? fridges.length : freezers.length;
  bool canAdd(UnitType t) => countFor(t) < maxFor(t);

  /// The next extra-slot product to buy for this type, or null if all bought.
  String? nextExtraProduct(UnitType t) {
    for (var i = 1; i <= ProductIds.maxExtras; i++) {
      final id = t == UnitType.fridge ? ProductIds.extraFridge(i) : ProductIds.extraFreezer(i);
      if (!ownedExtras.contains(id)) return id;
    }
    return null;
  }

  bool get hasAccess => subscribed || debugBypass;

  // ---------------------------------------------------------------- loading

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs.getString('profile');
    if (p != null) profile = BusinessProfile.fromJson(jsonDecode(p) as Map<String, dynamic>);
    final s = _prefs.getString('settings');
    if (s != null) settings = AppSettings.fromJson(jsonDecode(s) as Map<String, dynamic>);
    subscribed = _prefs.getBool('subscribed') ?? false;
    final checked = _prefs.getInt('subscriptionCheckedAt');
    subscriptionCheckedAt = checked == null ? null : DateTime.fromMillisecondsSinceEpoch(checked);
    ownedExtras = (_prefs.getStringList('ownedExtras') ?? const []).toSet();
    units = await AppDb.instance.activeUnits();

    // If we have not been able to confirm the subscription with Google Play
    // for over 7 days (e.g. offline), stop trusting the cached value.
    if (subscribed &&
        (subscriptionCheckedAt == null ||
            DateTime.now().difference(subscriptionCheckedAt!) > const Duration(days: 7))) {
      subscribed = false;
    }

    loaded = true;
    notifyListeners();
  }

  /// Connects to Google Play and refreshes what this account owns.
  Future<void> refreshEntitlements() async {
    Billing.instance.onEntitlements = _onEntitlements;
    await Billing.instance.init();
    await Billing.instance.restore();
  }

  void _onEntitlements(bool? isSubscribed, Set<String> owned, {required bool fullRestore}) {
    if (fullRestore) {
      subscribed = isSubscribed ?? false;
      // Never drop extras we believe are owned because of a partial response.
      ownedExtras = {...owned, if (owned.isEmpty) ...ownedExtras};
      subscriptionCheckedAt = DateTime.now();
    } else {
      if (isSubscribed == true) {
        subscribed = true;
        subscriptionCheckedAt = DateTime.now();
      }
      ownedExtras = {...ownedExtras, ...owned};
    }
    _prefs.setBool('subscribed', subscribed);
    if (subscriptionCheckedAt != null) {
      _prefs.setInt('subscriptionCheckedAt', subscriptionCheckedAt!.millisecondsSinceEpoch);
    }
    _prefs.setStringList('ownedExtras', ownedExtras.toList());
    notifyListeners();
  }

  /// Records a just-completed purchase immediately.
  void grantPurchase(String productId) => _onEntitlements(
      productId == ProductIds.subscription ? true : null,
      productId == ProductIds.subscription ? <String>{} : {productId},
      fullRestore: false);

  // ---------------------------------------------------------------- profile

  Future<void> saveProfile(BusinessProfile p) async {
    profile = p;
    await _prefs.setString('profile', jsonEncode(p.toJson()));
    notifyListeners();
  }

  Future<void> saveSettings(AppSettings s, {bool reschedule = true}) async {
    settings = s;
    await _prefs.setString('settings', jsonEncode(s.toJson()));
    notifyListeners();
    if (reschedule) {
      try {
        await Reminders.schedule(s);
      } catch (e) {
        debugPrint('Reminder scheduling failed: $e');
      }
    }
  }

  void enableDebugBypass() {
    if (kDebugMode) {
      debugBypass = true;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------- units

  /// Creates the initial set of units during setup.
  Future<void> createInitialUnits(List<StorageUnit> list) async {
    var pos = 0;
    for (final u in list) {
      await AppDb.instance.insertUnit(u.copyWith(position: pos++));
    }
    units = await AppDb.instance.activeUnits();
    notifyListeners();
  }

  Future<bool> addUnit(UnitType t, String name) async {
    if (!canAdd(t)) return false;
    final pos = units.isEmpty ? 0 : units.map((u) => u.position).reduce((a, b) => a > b ? a : b) + 1;
    await AppDb.instance.insertUnit(StorageUnit(type: t, name: name, position: pos));
    units = await AppDb.instance.activeUnits();
    notifyListeners();
    return true;
  }

  Future<void> renameUnit(StorageUnit u, String name) async {
    await AppDb.instance.renameUnit(u.id!, name);
    units = await AppDb.instance.activeUnits();
    notifyListeners();
  }

  Future<void> removeUnit(StorageUnit u) async {
    await AppDb.instance.archiveUnit(u.id!);
    units = await AppDb.instance.activeUnits();
    notifyListeners();
  }

  // ---------------------------------------------------------------- checks

  Future<CheckSession> submitCheck(List<Reading> readings, String checkedBy) async {
    final s = CheckSession(takenAt: DateTime.now(), checkedBy: checkedBy.trim(), readings: readings);
    final id = await AppDb.instance.saveSession(s);
    notifyListeners();
    return CheckSession(id: id, takenAt: s.takenAt, checkedBy: s.checkedBy, readings: readings);
  }

  // ---------------------------------------------------------------- reset

  Future<void> deleteEverything() async {
    await Reminders.cancelAll();
    await AppDb.instance.wipe();
    final keepExtras = ownedExtras;
    await _prefs.clear();
    // Purchases belong to the Google account, so keep them.
    await _prefs.setStringList('ownedExtras', keepExtras.toList());
    await _prefs.setBool('subscribed', subscribed);
    if (subscriptionCheckedAt != null) {
      await _prefs.setInt('subscriptionCheckedAt', subscriptionCheckedAt!.millisecondsSinceEpoch);
    }
    profile = null;
    settings = const AppSettings();
    units = [];
    notifyListeners();
  }
}
