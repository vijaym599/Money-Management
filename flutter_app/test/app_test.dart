import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadan_kanakku/app_services.dart';
import 'package:kadan_kanakku/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final secureData = <String, String>{};

  setUp(() {
    secureData.clear();
    FlutterSecureStoragePlatform.instance =
        TestFlutterSecureStoragePlatform(secureData);
  });

  testWidgets('uses English for a fresh install', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const KadanKanakkuApp());
    await tester.pumpAndSettle();

    expect(find.text('No loans yet'), findsOneWidget);
    expect(find.text('New loan'), findsWidgets);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('amount privacy toggle masks values across pages',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final loan = Loan(
      id: 'privacy-test-loan',
      direction: 'given',
      person: 'Kumar',
      principal: 5000,
      rate: 0,
      dueDay: 5,
      startDate: DateTime(2026, 1, 1),
      note: '',
      payments: const [],
    );
    secureData[SecureDataStore.loansKey] = jsonEncode([loan.toJson()]);

    await tester.pumpWidget(const KadanKanakkuApp());
    await tester.pumpAndSettle();

    expect(find.text('₹5,000'), findsWidgets);
    await tester.tap(find.byTooltip('Hide amounts'));
    await tester.pump();
    expect(find.text('₹ ••••••'), findsWidgets);
    expect(find.text('₹5,000'), findsNothing);

    await tester.tap(find.text('Loans'));
    await tester.pumpAndSettle();
    expect(find.text('₹ ••••••'), findsWidgets);
    expect(find.text('₹5,000'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('adds a loan and saves an interest payment locally',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'kadan-kanakku-language': 'ta',
    });
    await tester.pumpWidget(const KadanKanakkuApp());
    await tester.pumpAndSettle();

    expect(find.text('இன்னும் கடன் இல்லை'), findsOneWidget);
    await tester.tap(find.text('புதிய கடன்'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'அருண்');
    await tester.enterText(find.byType(TextFormField).at(1), '9876543210');
    await tester.enterText(find.byType(TextFormField).at(2), '10000');
    await tester.enterText(find.byType(TextFormField).at(3), '2');
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

    expect(find.text('பணம் பெற்ற ரசீது'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'நகலெடு'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'WhatsApp'), findsOneWidget);

    final stored = jsonDecode(
      secureData[SecureDataStore.loansKey]!,
    ) as List<dynamic>;
    final loan = Loan.fromJson(
      Map<String, Object?>.from(stored.single as Map),
    );
    expect(loan.person, 'அருண்');
    expect(loan.phone, '9876543210');
    expect(loan.payments, hasLength(1));
    expect(loan.payments.single.type, 'interest');
    expect(loan.payments.single.amount, greaterThan(0));
    expect(loan.payments.single.amount, lessThan(200));
  });

  testWidgets('premium navigation and interest calculator work',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'kadan-kanakku-language': 'ta',
    });
    await tester.pumpWidget(const KadanKanakkuApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('கடன்கள்'));
    await tester.pumpAndSettle();
    expect(find.text('0 செயலில் • 0 மூடப்பட்டது'), findsOneWidget);

    await tester.tap(find.text('நபர்கள்'));
    await tester.pumpAndSettle();
    expect(find.text('நபர்கள் இல்லை'), findsOneWidget);

    await tester.tap(find.text('அறிக்கை'));
    await tester.pumpAndSettle();
    expect(find.text('அறிக்கை தரவு இல்லை'), findsOneWidget);

    await tester.tap(find.text('சுயவிவரம்'));
    await tester.pumpAndSettle();
    expect(find.text('தனிப்பட்ட விவரங்கள்'), findsOneWidget);

    await tester.tap(find.text('முகப்பு'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('கணக்கீடு'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('கணக்கீடு'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '10000');
    await tester.enterText(fields.at(1), '2');
    await tester.enterText(fields.at(2), '3');
    await tester.tap(find.text('கணக்கிடு'));
    await tester.pumpAndSettle();

    expect(find.text('₹600'), findsOneWidget);
    expect(find.text('மொத்த தொகை: ₹10,600'), findsOneWidget);

    await tester.tap(find.text('தேதிகள்'));
    await tester.pumpAndSettle();
    expect(find.text('தொடக்க தேதி'), findsOneWidget);
    expect(find.text('முடிவு தேதி'), findsOneWidget);
  });

  testWidgets('creates and lists an interest-free loan separately',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'kadan-kanakku-language': 'ta',
    });
    await tester.pumpWidget(const KadanKanakkuApp());
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(FloatingActionButton, 'புதிய கடன்'),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'முருகன்');
    await tester.enterText(find.byType(TextFormField).at(1), '9123456789');
    await tester.enterText(find.byType(TextFormField).at(2), '5000');
    await tester.ensureVisible(find.text('வட்டி இல்லா கடன்'));
    await tester.tap(find.text('வட்டி இல்லா கடன்'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('சேமி'));
    await tester.tap(find.text('சேமி'));
    await tester.pumpAndSettle();

    final stored = jsonDecode(
      secureData[SecureDataStore.loansKey]!,
    ) as List<dynamic>;
    final loan = Loan.fromJson(
      Map<String, Object?>.from(stored.single as Map),
    );
    expect(loan.rate, 0);
    expect(loan.principal, 5000);
    expect(loan.phone, '9123456789');

    await tester.tap(find.text('கடன்கள்'));
    await tester.pumpAndSettle();

    final filterScroller = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.horizontal,
    );
    await tester.drag(filterScroller.first, const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('வட்டி இல்லாமல்'));
    await tester.pumpAndSettle();

    expect(find.text('வட்டி இல்லா கடன்கள்'), findsOneWidget);
    expect(find.text('முருகன்'), findsOneWidget);
    expect(find.text('முதல்தொகை நிலுவை'), findsOneWidget);
    expect(find.text('கடன் தேதி'), findsOneWidget);
    expect(find.text('₹5,000'), findsWidgets);
  });

  testWidgets('settled loan closes before it can be permanently deleted',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final today = DateTime.now();
    final settledLoan = Loan(
      id: 'settled-close-flow',
      direction: 'given',
      person: 'Kumar',
      principal: 5000,
      rate: 0,
      dueDay: 5,
      startDate: DateTime(today.year - 1, 1, 1),
      note: '',
      payments: [
        LoanPayment(
          id: 'full-principal-payment',
          type: 'principal',
          amount: 5000,
          date: today,
        ),
      ],
    );
    secureData[SecureDataStore.loansKey] = jsonEncode([settledLoan.toJson()]);

    await tester.pumpWidget(const KadanKanakkuApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Loans'));
    await tester.pumpAndSettle();

    expect(find.text('Close loan'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);
    await tester.tap(find.text('Close loan'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Close loan').last);
    await tester.pumpAndSettle();

    var stored = jsonDecode(secureData[SecureDataStore.loansKey]!) as List;
    expect(Loan.fromJson(Map<String, Object?>.from(stored.single)).isClosed,
        isTrue);

    final filterScroller = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.horizontal,
    );
    await tester.drag(filterScroller.first, const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Closed'));
    await tester.pumpAndSettle();
    expect(find.text('Kumar'), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    stored = jsonDecode(secureData[SecureDataStore.loansKey]!) as List;
    expect(stored, isEmpty);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('app lock rejects a wrong PIN and unlocks with the saved PIN',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'kadan-kanakku-language': 'ta',
    });
    final preferences = await SharedPreferences.getInstance();
    await SecureDataStore.instance.setPin(preferences, '2468');

    await tester.pumpWidget(const KadanKanakkuApp());
    await tester.pumpAndSettle();

    expect(find.text('கடன் கணக்கு பூட்டப்பட்டுள்ளது'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1111');
    await tester.tap(find.text('திற'));
    await tester.pumpAndSettle();
    expect(find.text('PIN தவறாக உள்ளது'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '2468');
    await tester.tap(find.text('திற'));
    await tester.pumpAndSettle();
    expect(find.text('முகப்பு'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('reports show advanced analytics from real loan data',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'kadan-kanakku-language': 'ta',
    });
    final loan = Loan(
      id: 'analytics-loan',
      direction: 'given',
      person: 'குமார்',
      principal: 10000,
      rate: 2,
      dueDay: 5,
      startDate: DateTime(2026, 1, 1),
      note: '',
      payments: const [],
    );
    secureData[SecureDataStore.loansKey] = jsonEncode([loan.toJson()]);

    await tester.pumpWidget(const KadanKanakkuApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('அறிக்கை'));
    await tester.pumpAndSettle();

    expect(find.text('மேம்பட்ட நிதி பகுப்பாய்வு'), findsOneWidget);
    expect(find.text('வட்டி வசூல் விகிதம்'), findsOneWidget);
    expect(find.text('வட்டி நிலுவை காலப் பகுப்பு'), findsOneWidget);
    expect(find.text('குமார்'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('people with one loan open the redesigned detail page directly',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'kadan-kanakku-language': 'ta',
    });
    final loan = Loan(
      id: 'direct-person-loan',
      direction: 'given',
      person: 'Perumal Sasi',
      phone: '9566455321',
      principal: 200000,
      rate: 2,
      dueDay: 5,
      startDate: DateTime(2026, 8, 1),
      note: 'Direct detail flow',
      payments: const [],
    );
    secureData[SecureDataStore.loansKey] = jsonEncode([loan.toJson()]);

    await tester.pumpWidget(const KadanKanakkuApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.people_outline_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perumal Sasi'));
    await tester.pumpAndSettle();

    expect(find.text('கணக்கு சுருக்கம்'), findsOneWidget);
    expect(find.text('செலுத்தல் பதிவு'), findsOneWidget);
    expect(find.text('1 loan accounts'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('மாதாந்திர வட்டி கணக்கு'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('முக்கிய தேதிகள்'), findsOneWidget);
    expect(find.text('மாதாந்திர வட்டி கணக்கு'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
