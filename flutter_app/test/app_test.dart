import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadan_kanakku/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('adds a loan and saves an interest payment locally',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const KadanKanakkuApp());
    await tester.pumpAndSettle();

    expect(find.text('இன்னும் கடன் இல்லை'), findsOneWidget);
    await tester.tap(find.text('புதிய கடன்'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'அருண்');
    await tester.enterText(find.byType(TextFormField).at(1), '10000');
    await tester.enterText(find.byType(TextFormField).at(2), '2');
    await tester.ensureVisible(find.text('சேமி'));
    await tester.tap(find.text('சேமி'));
    await tester.pumpAndSettle();

    expect(find.text('அருண்'), findsWidgets);
    final paymentButton =
        find.widgetWithText(OutlinedButton, 'செலுத்தல் பதிவு').first;
    await tester.scrollUntilVisible(
      paymentButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(paymentButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('பதிவு செய்'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    final stored = jsonDecode(
      preferences.getString('kadan-kanakku-loans-v1')!,
    ) as List<dynamic>;
    final loan = Loan.fromJson(
      Map<String, Object?>.from(stored.single as Map),
    );
    expect(loan.person, 'அருண்');
    expect(loan.payments, hasLength(1));
    expect(loan.payments.single.type, 'interest');
    expect(loan.payments.single.amount, 200);
  });
}
