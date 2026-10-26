import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

class SecureDataStore {
  SecureDataStore._();

  static final instance = SecureDataStore._();

  static const loansKey = 'kadan-kanakku-loans-v1';
  static const savingsKey = 'kadan-kanakku-savings-v1';
  static const _pinSaltKey = 'app-lock-pin-salt-v1';
  static const _pinHashKey = 'app-lock-pin-hash-v1';
  static const _biometricKey = 'app-lock-biometric-v1';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(migrateWithBackup: true),
  );
  static const _platformTimeout = Duration(seconds: 2);

  Future<String?> readLoans(SharedPreferences preferences) async {
    try {
      final encrypted =
          await _storage.read(key: loansKey).timeout(_platformTimeout);
      if (encrypted != null) return encrypted;

      final legacy = preferences.getString(loansKey);
      if (legacy != null) {
        await _storage
            .write(key: loansKey, value: legacy)
            .timeout(_platformTimeout);
        await preferences.remove(loansKey);
      }
      return legacy;
    } catch (error) {
      debugPrint('Secure storage read unavailable: $error');
      return preferences.getString(loansKey);
    }
  }

  Future<bool> writeLoans(
    SharedPreferences preferences,
    String value,
  ) async {
    try {
      await _storage
          .write(key: loansKey, value: value)
          .timeout(_platformTimeout);
      await preferences.remove(loansKey);
      return true;
    } catch (error) {
      debugPrint('Secure storage write unavailable: $error');
      return preferences.setString(loansKey, value);
    }
  }

  Future<String?> readSavings(SharedPreferences preferences) async {
    try {
      final encrypted =
          await _storage.read(key: savingsKey).timeout(_platformTimeout);
      if (encrypted != null) return encrypted;

      final legacy = preferences.getString(savingsKey);
      if (legacy != null) {
        await _storage
            .write(key: savingsKey, value: legacy)
            .timeout(_platformTimeout);
        await preferences.remove(savingsKey);
      }
      return legacy;
    } catch (error) {
      debugPrint('Secure savings read unavailable: $error');
      return preferences.getString(savingsKey);
    }
  }

  Future<bool> writeSavings(
    SharedPreferences preferences,
    String value,
  ) async {
    try {
      await _storage
          .write(key: savingsKey, value: value)
          .timeout(_platformTimeout);
      await preferences.remove(savingsKey);
      return true;
    } catch (error) {
      debugPrint('Secure savings write unavailable: $error');
      return preferences.setString(savingsKey, value);
    }
  }

  Future<String?> _readSecret(
    SharedPreferences preferences,
    String key,
  ) async {
    try {
      return await _storage.read(key: key).timeout(_platformTimeout);
    } catch (_) {
      return preferences.getString(key);
    }
  }

  Future<void> _writeSecret(
    SharedPreferences preferences,
    String key,
    String value,
  ) async {
    try {
      await _storage.write(key: key, value: value).timeout(_platformTimeout);
      await preferences.remove(key);
    } catch (_) {
      await preferences.setString(key, value);
    }
  }

  Future<void> _deleteSecret(
    SharedPreferences preferences,
    String key,
  ) async {
    try {
      await _storage.delete(key: key).timeout(_platformTimeout);
    } catch (_) {
      // The fallback below still clears test/unsupported-platform storage.
    }
    await preferences.remove(key);
  }

  Future<bool> hasPin(SharedPreferences preferences) async =>
      (await _readSecret(preferences, _pinHashKey)) != null;

  Future<bool> verifyPin(
    SharedPreferences preferences,
    String pin,
  ) async {
    final salt = await _readSecret(preferences, _pinSaltKey);
    final expected = await _readSecret(preferences, _pinHashKey);
    if (salt == null || expected == null) return false;
    return _constantTimeEquals(_hashPin(pin, salt), expected);
  }

  Future<void> setPin(SharedPreferences preferences, String pin) async {
    final random = Random.secure();
    final salt = base64UrlEncode(
      List<int>.generate(24, (_) => random.nextInt(256)),
    );
    await _writeSecret(preferences, _pinSaltKey, salt);
    await _writeSecret(preferences, _pinHashKey, _hashPin(pin, salt));
  }

  Future<void> clearPin(SharedPreferences preferences) async {
    await _deleteSecret(preferences, _pinSaltKey);
    await _deleteSecret(preferences, _pinHashKey);
    await setBiometricEnabled(preferences, false);
  }

  Future<bool> biometricEnabled(SharedPreferences preferences) async =>
      (await _readSecret(preferences, _biometricKey)) == 'true';

  Future<void> setBiometricEnabled(
    SharedPreferences preferences,
    bool enabled,
  ) =>
      _writeSecret(preferences, _biometricKey, enabled.toString());

  String _hashPin(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  bool _constantTimeEquals(String left, String right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var i = 0; i < left.length; i++) {
      difference |= left.codeUnitAt(i) ^ right.codeUnitAt(i);
    }
    return difference == 0;
  }
}

class DeviceAuthenticationService {
  DeviceAuthenticationService._();

  static final instance = DeviceAuthenticationService._();
  final LocalAuthentication _authentication = LocalAuthentication();

  Future<bool> isAvailable() async {
    try {
      return await (() async =>
              await _authentication.isDeviceSupported() &&
              (await _authentication.getAvailableBiometrics()).isNotEmpty)()
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({required bool isTamil}) async {
    try {
      return await _authentication
          .authenticate(
            localizedReason: isTamil
                ? 'கடன் கணக்கைத் திறக்க உங்கள் அடையாளத்தை உறுதிப்படுத்தவும்'
                : 'Authenticate to unlock your loan accounts',
            biometricOnly: true,
            persistAcrossBackgrounding: true,
          )
          .timeout(const Duration(seconds: 45));
    } catch (error) {
      debugPrint('Biometric authentication failed: $error');
      return false;
    }
  }
}

class LoanNotificationService {
  LoanNotificationService._();

  static final instance = LoanNotificationService._();
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      await _plugin
          .initialize(
            settings: const InitializationSettings(
              android: AndroidInitializationSettings('@mipmap/ic_launcher'),
              iOS: DarwinInitializationSettings(),
            ),
          )
          .timeout(const Duration(seconds: 3));
      _initialized = true;
    } catch (error) {
      debugPrint('Notification initialization unavailable: $error');
    }
  }

  Future<bool> requestPermission() async {
    await initialize();
    if (!_initialized) return false;
    try {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          true;
    } catch (error) {
      debugPrint('Notification permission unavailable: $error');
      return false;
    }
  }

  Future<void> sync({
    required List<Loan> loans,
    required bool enabled,
    required bool isTamil,
  }) async {
    await initialize();
    if (!_initialized) return;
    try {
      await _plugin.cancelAllPendingNotifications();
      if (!enabled) return;

      final now = tz.TZDateTime.now(tz.local);
      var notificationId = 1000;
      var scheduled = 0;
      for (final loan in loans.where(
        (item) => !item.isClosed && item.outstanding > .009 && item.rate > 0,
      )) {
        var cursor = DateTime(now.year, now.month);
        for (var index = 0; index < 12 && scheduled < 400; index++) {
          final month =
              '${cursor.year.toString().padLeft(4, '0')}-${cursor.month.toString().padLeft(2, '0')}';
          final status = loan.statusFor(month, today: now);
          if (status.remaining > .009) {
            final due = tz.TZDateTime(
              tz.local,
              status.dueDate.year,
              status.dueDate.month,
              status.dueDate.day,
              9,
            );
            final reminder = due.subtract(const Duration(days: 1));
            for (final entry in <(tz.TZDateTime, bool)>[
              (reminder, true),
              (due, false),
            ]) {
              if (!entry.$1.isAfter(now) || scheduled >= 400) continue;
              final before = entry.$2;
              await _plugin.zonedSchedule(
                id: notificationId++,
                title: isTamil
                    ? (before ? 'நாளை கடன் தவணை' : 'இன்று கடன் தவணை')
                    : (before
                        ? 'Loan payment due tomorrow'
                        : 'Loan payment due today'),
                body: isTamil
                    ? '${loan.person} • ${_money(status.remaining)} வட்டி செலுத்த வேண்டும்'
                    : '${loan.person} • ${_money(status.remaining)} interest is due',
                scheduledDate: entry.$1,
                notificationDetails: const NotificationDetails(
                  android: AndroidNotificationDetails(
                    'loan_due_reminders',
                    'Loan due reminders',
                    channelDescription:
                        'Upcoming and due loan payment reminders',
                    importance: Importance.high,
                    priority: Priority.high,
                  ),
                  iOS: DarwinNotificationDetails(),
                ),
                androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
                payload: loan.id,
              );
              scheduled++;
            }
          }
          cursor = DateTime(cursor.year, cursor.month + 1);
        }
      }
    } catch (error) {
      debugPrint('Could not schedule reminders: $error');
    }
  }
}

class PdfStatementService {
  PdfStatementService._();

  static final instance = PdfStatementService._();

  Future<void> shareLoan({
    required Loan loan,
    required bool isTamil,
  }) async {
    final safeName =
        loan.person.replaceAll(RegExp(r'[^\w\u0B80-\u0BFF]+'), '_');
    await Printing.sharePdf(
      bytes: await buildLoan(loan: loan, isTamil: isTamil),
      filename: 'LoanTrack-$safeName-statement.pdf',
    );
  }

  Future<Uint8List> buildLoan({
    required Loan loan,
    required bool isTamil,
  }) async {
    final fontData = await rootBundle.load('assets/fonts/NotoSansTamil.ttf');
    final font = pw.Font.ttf(fontData);
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: font),
    );
    final now = DateTime.now();
    final overdue = loan.overdueInterest(today: now);
    final months = loan.monthsThrough(now).reversed.toList();
    final payments = [...loan.payments]
      ..sort((a, b) => b.date.compareTo(a.date));
    final blue = PdfColor.fromHex('#1769FF');
    final navy = PdfColor.fromHex('#081B3A');

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 12),
          decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: blue, width: 2)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                isTamil ? 'கடன் கணக்கு அறிக்கை' : 'Loan Account Statement',
                style: pw.TextStyle(
                  color: navy,
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(DateFormat('dd-MM-yyyy').format(now)),
            ],
          ),
        ),
        build: (_) => [
          pw.SizedBox(height: 18),
          pw.Text(
            loan.person,
            style: pw.TextStyle(
              color: blue,
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (loan.phone.isNotEmpty) pw.Text(loan.phone),
          pw.SizedBox(height: 16),
          _summaryTable(loan, overdue, isTamil),
          if (loan.hasInterestLedger) ...[
            pw.SizedBox(height: 22),
            pw.Text(
              isTamil ? 'மாத வாரியான கணக்கு' : 'Monthly account ledger',
              style: const pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: isTamil
                  ? ['மாதம்', 'வட்டி', 'செலுத்தியது', 'நிலுவை', 'நிலை']
                  : ['Month', 'Interest', 'Paid', 'Balance', 'Status'],
              data: months.map((month) {
                final status = loan.statusFor(month, today: now);
                return [
                  month,
                  _money(status.expected),
                  _money(status.paid),
                  _money(status.remaining),
                  isTamil
                      ? (status.isDue ? 'நிலுவை' : 'சரி')
                      : (status.isDue ? 'Overdue' : 'Current'),
                ];
              }).toList(),
              headerStyle: const pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration: pw.BoxDecoration(color: navy),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellPadding: const pw.EdgeInsets.all(6),
            ),
          ],
          if (loan.payments.isNotEmpty) ...[
            pw.SizedBox(height: 22),
            pw.Text(
              isTamil ? 'செலுத்தல் வரலாறு' : 'Payment history',
              style: const pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: isTamil
                  ? ['தேதி', 'வகை', 'மாதம்', 'தொகை']
                  : ['Date', 'Type', 'Month', 'Amount'],
              data: payments
                  .map((payment) => [
                        DateFormat('dd-MM-yyyy').format(payment.date),
                        payment.type == 'interest'
                            ? (isTamil ? 'வட்டி' : 'Interest')
                            : (isTamil ? 'முதல்தொகை' : 'Principal'),
                        payment.month ?? '—',
                        _money(payment.amount),
                      ])
                  .toList(),
              headerStyle: const pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration: pw.BoxDecoration(color: navy),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellPadding: const pw.EdgeInsets.all(6),
            ),
          ],
        ],
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
      ),
    );

    return document.save();
  }

  pw.Widget _summaryTable(Loan loan, double overdue, bool isTamil) {
    final rows = <List<String>>[
      [
        isTamil ? 'கடன் வகை' : 'Loan type',
        loan.direction == 'given'
            ? (isTamil ? 'கொடுத்தது' : 'Lent')
            : (isTamil ? 'வாங்கியது' : 'Borrowed')
      ],
      [isTamil ? 'முதல்தொகை' : 'Principal', _money(loan.principal)],
      [
        isTamil ? 'கடன் தேதி' : 'Loan date',
        DateFormat('dd-MM-yyyy').format(loan.startDate)
      ],
      if (loan.rate > 0) ...[
        [
          isTamil ? 'வட்டி தொடங்கும் தேதி' : 'Interest start date',
          DateFormat('dd-MM-yyyy').format(loan.interestStartDate)
        ],
        [
          isTamil ? 'முதல் வட்டி தவணை தேதி' : 'First interest due date',
          DateFormat('dd-MM-yyyy').format(loan.firstInterestDueDate)
        ],
        [
          isTamil ? 'மாத வட்டி தவணை நாள்' : 'Monthly interest due day',
          '${loan.dueDay}'
        ],
        [
          isTamil ? 'மாத வட்டி' : 'Monthly interest',
          '${loan.rate}% • ${_money(loan.monthlyInterest)}'
        ],
      ],
      [
        isTamil ? 'முதல்தொகை நிலுவை' : 'Principal outstanding',
        _money(loan.outstanding)
      ],
      if (overdue > 0.009)
        [isTamil ? 'வட்டி நிலுவை' : 'Interest outstanding', _money(overdue)],
      [
        isTamil ? 'மொத்த நிலுவை' : 'Total outstanding',
        _money(loan.totalOutstanding())
      ],
      if (loan.lastPaymentDate != null)
        [
          isTamil ? 'கடைசி பணம் பெற்ற தேதி' : 'Last payment date',
          DateFormat('dd-MM-yyyy').format(loan.lastPaymentDate!)
        ],
    ];
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: rows
          .map(
            (row) => pw.TableRow(
              children: row
                  .map(
                    (cell) => pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(cell),
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
    );
  }
}

String _money(double value) => NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: value % 1 == 0 ? 0 : 2,
    ).format(value);
