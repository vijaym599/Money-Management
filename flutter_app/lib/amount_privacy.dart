import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AmountPrivacyScope extends InheritedNotifier<ValueNotifier<bool>> {
  const AmountPrivacyScope({
    required ValueNotifier<bool> notifier,
    required super.child,
    super.key,
  }) : super(notifier: notifier);

  static bool isVisible(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AmountPrivacyScope>();
    return scope?.notifier?.value ?? true;
  }

  static void toggle(BuildContext context) {
    final notifier = context
        .dependOnInheritedWidgetOfExactType<AmountPrivacyScope>()
        ?.notifier;
    if (notifier != null) notifier.value = !notifier.value;
  }
}

String privateMoney(BuildContext context, double value) {
  if (!AmountPrivacyScope.isVisible(context)) return '₹ ••••••';
  return NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: value % 1 == 0 ? 0 : 2,
  ).format(value);
}
