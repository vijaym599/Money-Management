import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadan_kanakku/app_services.dart';
import 'package:kadan_kanakku/emi_models.dart';
import 'package:kadan_kanakku/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> secureData;

  setUp(() {
    secureData = <String, String>{};
    FlutterSecureStoragePlatform.instance =
        TestFlutterSecureStoragePlatform(secureData);
    SharedPreferences.setMockInitialValues({});
  });

  test('PIN is hashed, verified and removable in encrypted storage', () async {
    final preferences = await SharedPreferences.getInstance();
    final storage = SecureDataStore.instance;

    await storage.setPin(preferences, '2468');

    expect(await storage.hasPin(preferences), isTrue);
    expect(await storage.verifyPin(preferences, '2468'), isTrue);
    expect(await storage.verifyPin(preferences, '1234'), isFalse);
    expect(secureData.values, isNot(contains('2468')));

    await storage.setBiometricEnabled(preferences, true);
    expect(await storage.biometricEnabled(preferences), isTrue);

    await storage.clearPin(preferences);
    expect(await storage.hasPin(preferences), isFalse);
    expect(await storage.biometricEnabled(preferences), isFalse);
  });

  test('legacy loan JSON migrates from preferences to secure storage',
      () async {
    SharedPreferences.setMockInitialValues({
      SecureDataStore.loansKey: '[{"id":"legacy"}]',
    });
    final preferences = await SharedPreferences.getInstance();

    final value = await SecureDataStore.instance.readLoans(preferences);

    expect(value, '[{"id":"legacy"}]');
    expect(secureData[SecureDataStore.loansKey], value);
    expect(preferences.getString(SecureDataStore.loansKey), isNull);
  });

  test('savings JSON migrates to encrypted storage', () async {
    SharedPreferences.setMockInitialValues({
      SecureDataStore.savingsKey: '[{"id":"saving"}]',
    });
    final preferences = await SharedPreferences.getInstance();

    final value = await SecureDataStore.instance.readSavings(preferences);

    expect(value, '[{"id":"saving"}]');
    expect(secureData[SecureDataStore.savingsKey], value);
    expect(preferences.getString(SecureDataStore.savingsKey), isNull);
  });

  test('EMI JSON migrates from preferences to encrypted storage', () async {
    SharedPreferences.setMockInitialValues({
      SecureDataStore.emiLoansKey: '[{"id":"emi"}]',
    });
    final preferences = await SharedPreferences.getInstance();

    final value = await SecureDataStore.instance.readEmiLoans(preferences);

    expect(value, '[{"id":"emi"}]');
    expect(secureData[SecureDataStore.emiLoansKey], value);
    expect(preferences.getString(SecureDataStore.emiLoansKey), isNull);
  });

  test('Tamil and English EMI statement generates a valid PDF', () async {
    final loan = EmiLoan(
      id: 'pdf-emi-loan',
      direction: 'taken',
      person: 'முருகன்',
      phone: '9876543210',
      principal: 100000,
      rate: 1,
      tenureMonths: 12,
      startDate: DateTime(2026, 1, 1),
      firstDueDate: DateTime(2026, 2, 1),
      interestMethod: 'reducing',
      note: '',
      payments: [
        EmiPayment(
          id: 'pdf-emi-payment',
          amount: 8884.88,
          date: DateTime(2026, 2, 1),
          installmentNumber: 1,
        ),
      ],
    );

    for (final isTamil in [true, false]) {
      final bytes = await PdfStatementService.instance.buildEmi(
        loan: loan,
        isTamil: isTamil,
      );
      expect(bytes.length, greaterThan(1000));
      expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
    }
  });

  test('Tamil and English loan statement generates a valid PDF', () async {
    final loan = Loan(
      id: 'pdf-loan',
      direction: 'given',
      person: 'முருகன்',
      phone: '9876543210',
      principal: 10000,
      rate: 2,
      dueDay: 5,
      startDate: DateTime(2026, 1, 1),
      note: '',
      payments: [
        LoanPayment(
          id: 'pdf-payment',
          type: 'interest',
          amount: 200,
          date: DateTime(2026, 1, 5),
          month: '2026-01',
        ),
      ],
    );

    for (final isTamil in [true, false]) {
      final bytes = await PdfStatementService.instance.buildLoan(
        loan: loan,
        isTamil: isTamil,
      );
      expect(bytes.length, greaterThan(1000));
      expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
    }
  });
}
