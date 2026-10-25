// Temperature rules, conversions and formatting.
//
// Limits are based on UK food hygiene guidance (Food Standards Agency / GOV.UK):
//  * Chilled food must be kept at 8°C or below – a legal requirement in
//    England, Wales and Northern Ireland, and recommended in Scotland.
//  * The FSA recommends fridges run at 5°C or below (0–5°C).
//  * Frozen food should be kept at -18°C or colder.
// All values are stored in °C. Readings are shown to one decimal place.

import 'package:flutter/material.dart';

enum UnitType { fridge, freezer }

extension UnitTypeX on UnitType {
  String get key => this == UnitType.fridge ? 'fridge' : 'freezer';
  String get label => this == UnitType.fridge ? 'Fridge' : 'Freezer';
  String get plural => this == UnitType.fridge ? 'Fridges' : 'Freezers';
  IconData get icon =>
      this == UnitType.fridge ? Icons.kitchen_rounded : Icons.ac_unit_rounded;
  static UnitType fromKey(String k) =>
      k == 'freezer' ? UnitType.freezer : UnitType.fridge;
}

enum TempScale { celsius, fahrenheit }

extension TempScaleX on TempScale {
  String get symbol => this == TempScale.celsius ? '°C' : '°F';
  String get key => this == TempScale.celsius ? 'C' : 'F';
  static TempScale fromKey(String? k) =>
      k == 'F' ? TempScale.fahrenheit : TempScale.celsius;
}

double cToF(double c) => c * 9 / 5 + 32;
double fToC(double f) => (f - 32) * 5 / 9;

double toScale(double celsius, TempScale s) =>
    s == TempScale.celsius ? celsius : cToF(celsius);
double fromScale(double value, TempScale s) =>
    s == TempScale.celsius ? value : fToC(value);

/// Rounds to one decimal place in the display scale (the "0.0" format).
double round1(double v) => (v * 10).roundToDouble() / 10;

String formatTemp(double celsius, TempScale s, {bool withSymbol = true}) {
  final v = round1(toScale(celsius, s));
  final txt = (v == 0 ? 0.0 : v).toStringAsFixed(1);
  return withSymbol ? '$txt${s.symbol}' : txt;
}

/// Converts a value already in the display scale to °C, after rounding to
/// one decimal place in that scale so what you see is what is stored.
double displayToCelsius(double displayValue, TempScale s) =>
    fromScale(round1(displayValue), s);

enum TempStatus { ok, warning, critical }

extension TempStatusX on TempStatus {
  String get key => name;
  static TempStatus fromKey(String? k) => TempStatus.values
      .firstWhere((e) => e.name == k, orElse: () => TempStatus.ok);
  Color get color => switch (this) {
        TempStatus.ok => const Color(0xFF059669),
        TempStatus.warning => const Color(0xFFD97706),
        TempStatus.critical => const Color(0xFFDC2626),
      };
  Color get tint => switch (this) {
        TempStatus.ok => const Color(0xFFE7F8F1),
        TempStatus.warning => const Color(0xFFFFF4DF),
        TempStatus.critical => const Color(0xFFFDEBEB),
      };
  IconData get icon => switch (this) {
        TempStatus.ok => Icons.check_circle_rounded,
        TempStatus.warning => Icons.warning_amber_rounded,
        TempStatus.critical => Icons.error_rounded,
      };
  String get label => switch (this) {
        TempStatus.ok => 'OK',
        TempStatus.warning => 'Check',
        TempStatus.critical => 'Out of range',
      };
}

class TempAssessment {
  final TempStatus status;
  final String title;
  final String advice;
  final bool tooHigh;
  const TempAssessment(this.status, this.title, this.advice, {this.tooHigh = false});
}

class Limits {
  static const double fridgeLegalMax = 8.0; // °C – law (England, Wales, NI)
  static const double fridgeRecommendedMax = 5.0; // °C – FSA recommendation
  static const double fridgeMin = 0.0; // below this food may start to freeze
  static const double freezerTarget = -18.0; // °C – keep at or below
  static const double freezerAlarm = -15.0; // warmer than this = food at risk
  static const double freezerVeryCold = -26.0; // colder than this = unusual

  /// Slider range for each unit type, in °C.
  static (double, double) sliderRangeC(UnitType t) =>
      t == UnitType.fridge ? (-5.0, 15.0) : (-35.0, 5.0);

  /// Sensible "starting point" shown on the slider before a reading is taken.
  static double sliderStartC(UnitType t) => t == UnitType.fridge ? 3.0 : -18.0;
}

TempAssessment assess(UnitType type, double c, TempScale s) {
  String f(double v) => formatTemp(v, s);
  if (type == UnitType.fridge) {
    if (c > Limits.fridgeLegalMax) {
      return TempAssessment(
        TempStatus.critical,
        'Too warm – above the ${f(Limits.fridgeLegalMax)} legal limit',
        'Chilled food must be kept at ${f(Limits.fridgeLegalMax)} or below '
            '(the law in England, Wales and Northern Ireland, and recommended '
            'in Scotland). Re-check with a clean probe, move high-risk food to '
            'a working fridge, and discard food if it may be unsafe. '
            'Record what you did.',
        tooHigh: true,
      );
    }
    if (c > Limits.fridgeRecommendedMax) {
      return TempAssessment(
        TempStatus.warning,
        'Warmer than recommended (above ${f(Limits.fridgeRecommendedMax)})',
        'Still under the ${f(Limits.fridgeLegalMax)} legal limit, but the FSA '
            'recommends ${f(Limits.fridgeRecommendedMax)} or below. Check the '
            'door seal, avoid overloading, turn the thermostat down and '
            're-check soon.',
        tooHigh: true,
      );
    }
    if (c < Limits.fridgeMin) {
      return TempAssessment(
        TempStatus.warning,
        'Too cold – below ${f(Limits.fridgeMin)}',
        'Food may start to freeze, which can damage quality. '
            'Check the thermostat setting and re-check.',
      );
    }
    return const TempAssessment(TempStatus.ok, 'Within safe range', '');
  } else {
    if (c > Limits.freezerAlarm) {
      return TempAssessment(
        TempStatus.critical,
        'Too warm – food may be thawing',
        'Frozen food should be kept at ${f(Limits.freezerTarget)} or colder. '
            'If the freezer is not in a defrost cycle, check it is working, '
            'keep the door closed, and move food to another freezer. Thawed '
            'food should not be refrozen. Record what you did.',
        tooHigh: true,
      );
    }
    if (c > Limits.freezerTarget) {
      return TempAssessment(
        TempStatus.warning,
        'Warmer than ${f(Limits.freezerTarget)}',
        'Frozen food should be kept at ${f(Limits.freezerTarget)} or colder. '
            'This can happen briefly during defrost or after loading. Check '
            'the door seal and settings and re-check soon.',
        tooHigh: true,
      );
    }
    if (c < Limits.freezerVeryCold) {
      return TempAssessment(
        TempStatus.warning,
        'Colder than usual',
        'Freezers usually run between ${f(-22)} and ${f(-18)}. Very low '
            'readings are not a food safety risk but may mean a faulty probe '
            'or thermostat and higher energy bills.',
      );
    }
    return const TempAssessment(TempStatus.ok, 'Within safe range', '');
  }
}

TempStatus worst(Iterable<TempStatus> s) {
  if (s.contains(TempStatus.critical)) return TempStatus.critical;
  if (s.contains(TempStatus.warning)) return TempStatus.warning;
  return TempStatus.ok;
}

const correctiveActions = <String>[
  'Re-checked with a probe – reading confirmed',
  'Re-checked with a probe – reading now OK',
  'Thermostat adjusted',
  'Door closed / seal checked',
  'Food moved to another unit',
  'Food discarded',
  'Defrost cycle in progress',
  'Engineer called',
  'Other',
];
