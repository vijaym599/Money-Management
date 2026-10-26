import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_services.dart';
import 'amount_privacy.dart';
import 'loan_detail_page.dart';
import 'loan_reminder.dart';
import 'models.dart';
import 'premium_ui.dart';

export 'models.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KadanKanakkuApp());
}

const _languageKey = 'kadan-kanakku-language';
const _themeKey = 'kadan-kanakku-dark-mode';
const _nameKey = 'kadan-kanakku-profile-name';
const _phoneKey = 'kadan-kanakku-profile-phone';
const _notificationsKey = 'kadan-kanakku-notifications';

class _SmoothPageTransitionsBuilder extends PageTransitionsBuilder {
  const _SmoothPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curvedAnimation = animation.drive(
      CurveTween(curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curvedAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(.045, 0),
          end: Offset.zero,
        ).animate(curvedAnimation),
        child: child,
      ),
    );
  }
}

class KadanKanakkuApp extends StatefulWidget {
  const KadanKanakkuApp({super.key});

  @override
  State<KadanKanakkuApp> createState() => _KadanKanakkuAppState();
}

class _KadanKanakkuAppState extends State<KadanKanakkuApp>
    with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  final _amountVisibility = ValueNotifier<bool>(true);
  bool _loading = true;
  bool _darkMode = false;
  bool _notificationsEnabled = false;
  bool _appLockEnabled = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _locked = false;
  bool _authenticating = false;
  String _language = 'en';
  String _profileName = '';
  String _profilePhone = '';
  String? _loadError;
  List<Loan> _loans = [];
  int _selectedPage = 0;

  bool get _isTamil => _language == 'ta';

  String _tr(String tamil, String english) => _isTamil ? tamil : english;

  BuildContext get _appContext => _navigatorKey.currentContext!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _amountVisibility.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden) &&
        _appLockEnabled &&
        !_locked) {
      setState(() => _locked = true);
    } else if (state == AppLifecycleState.resumed &&
        _locked &&
        _biometricEnabled) {
      _unlockWithBiometrics();
    }
  }

  Future<void> _load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final rawLoans = await SecureDataStore.instance.readLoans(preferences);
      final decoded = rawLoans == null ? <Object?>[] : jsonDecode(rawLoans);
      if (decoded is! List) {
        throw const FormatException('Saved loans are not a list.');
      }
      final loans = decoded.map((item) {
        if (item is! Map) throw const FormatException('Invalid loan record.');
        return Loan.fromJson(Map<String, Object?>.from(item));
      }).toList();
      final appLockEnabled = await SecureDataStore.instance.hasPin(preferences);
      final biometricEnabled = appLockEnabled &&
          await SecureDataStore.instance.biometricEnabled(preferences);
      final notificationsEnabled =
          preferences.getBool(_notificationsKey) ?? false;
      if (!mounted) return;
      setState(() {
        _loans = loans;
        _language = preferences.getString(_languageKey) == 'ta' ? 'ta' : 'en';
        _darkMode = preferences.getBool(_themeKey) ?? false;
        _profileName = preferences.getString(_nameKey) ?? '';
        _profilePhone = preferences.getString(_phoneKey) ?? '';
        _appLockEnabled = appLockEnabled;
        _biometricEnabled = biometricEnabled;
        _notificationsEnabled = notificationsEnabled;
        _locked = appLockEnabled;
        _loading = false;
      });
      unawaited(_initializeDeviceServices(
        loans: loans,
        notificationsEnabled: notificationsEnabled,
        biometricEnabled: biometricEnabled,
      ));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = _tr(
          'சேமித்த தரவைப் படிக்க முடியவில்லை. அமைப்புகளில் காப்புப் பிரதியை மீட்டமைக்கவும்.',
          'Saved data could not be read. Restore a backup in Settings.',
        );
      });
      debugPrint('Could not load saved loans: $error');
    }
  }

  Future<void> _initializeDeviceServices({
    required List<Loan> loans,
    required bool notificationsEnabled,
    required bool biometricEnabled,
  }) async {
    final biometricAvailable =
        await DeviceAuthenticationService.instance.isAvailable();
    if (mounted) {
      setState(() => _biometricAvailable = biometricAvailable);
    }
    unawaited(LoanNotificationService.instance.sync(
      loans: loans,
      enabled: notificationsEnabled,
      isTamil: _isTamil,
    ));
    if (biometricEnabled && biometricAvailable && mounted) {
      await _unlockWithBiometrics();
    }
  }

  Future<bool> _store(String key, Object value) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = value is String
          ? await preferences.setString(key, value)
          : value is bool
              ? await preferences.setBool(key, value)
              : false;
      if (!saved) throw StateError('Local storage rejected the update.');
      return true;
    } catch (error) {
      debugPrint('Could not save local preferences: $error');
      if (mounted) {
        _message(_tr(
          'தரவைச் சேமிக்க முடியவில்லை. சாதனத்தில் இடம் உள்ளதா எனச் சரிபார்க்கவும்.',
          'Could not save data. Check the available storage on this device.',
        ));
      }
      return false;
    }
  }

  Future<bool> _saveLoans(List<Loan> loans) async {
    final json = jsonEncode(loans.map((loan) => loan.toJson()).toList());
    final preferences = await SharedPreferences.getInstance();
    if (await SecureDataStore.instance.writeLoans(preferences, json) &&
        mounted) {
      setState(() => _loans = loans);
      await LoanNotificationService.instance.sync(
        loans: loans,
        enabled: _notificationsEnabled,
        isTamil: _isTamil,
      );
      return true;
    }
    return false;
  }

  void _message(String message) {
    _messengerKey.currentState!
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addLoan() async {
    final loan = await Navigator.of(_appContext).push<Loan>(
      MaterialPageRoute(
        builder: (_) => LoanFormPage(isTamil: _isTamil),
      ),
    );
    if (loan != null) await _saveLoans([loan, ..._loans]);
  }

  Future<void> _editLoan(Loan loan) async {
    final candidate = await Navigator.of(_appContext).push<Loan>(
      MaterialPageRoute(
        builder: (_) => LoanFormPage(isTamil: _isTamil, loan: loan),
      ),
    );
    if (candidate == null || !mounted) return;
    final confirmed = await _showLoanEditPreview(loan, candidate);
    if (confirmed != true || !mounted) return;
    await _saveLoans(
      _loans.map((item) => item.id == loan.id ? candidate : item).toList(),
    );
  }

  Future<bool?> _showLoanEditPreview(Loan oldLoan, Loan newLoan) {
    final now = DateTime.now();
    final date = DateFormat('d MMM yyyy');
    String money(double value) => privateMoney(_appContext, value);
    final rows = <(String, String, String)>[
      (
        _tr('கடன் வழங்கிய தேதி', 'Loan given date'),
        date.format(oldLoan.startDate),
        date.format(newLoan.startDate),
      ),
      (
        _tr('வட்டி தொடங்கும் தேதி', 'Interest start date'),
        date.format(oldLoan.interestStartDate),
        date.format(newLoan.interestStartDate),
      ),
      (
        _tr('முதல் வட்டி தவணை', 'First interest due'),
        date.format(oldLoan.firstInterestDueDate),
        date.format(newLoan.firstInterestDueDate),
      ),
      (
        _tr('மாத வட்டி விகிதம்', 'Monthly interest rate'),
        '${oldLoan.rate}%',
        '${newLoan.rate}%',
      ),
      (
        _tr('மாத தவணை நாள்', 'Monthly due day'),
        '${oldLoan.dueDay}',
        '${newLoan.dueDay}',
      ),
      (
        _tr('செலுத்தாத மாதங்கள்', 'Unpaid overdue months'),
        '${oldLoan.overdueMonthCount(today: now)}',
        '${newLoan.overdueMonthCount(today: now)}',
      ),
      (
        _tr('வட்டி நிலுவை', 'Interest outstanding'),
        money(oldLoan.interestOutstanding(today: now)),
        money(newLoan.interestOutstanding(today: now)),
      ),
      (
        _tr('மொத்த நிலுவை', 'Total outstanding'),
        money(oldLoan.totalOutstanding(today: now)),
        money(newLoan.totalOutstanding(today: now)),
      ),
    ];
    return showDialog<bool>(
      context: _appContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(_tr('மாற்றங்களை உறுதிப்படுத்தவும்', 'Confirm changes')),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(dialogContext)
                        .colorScheme
                        .errorContainer
                        .withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(oldLoan.payments.isEmpty
                            ? _tr(
                                'இந்த மாற்றம் வட்டி அட்டவணை மற்றும் நிலுவையை மறுகணக்கிடும்.',
                                'This change recalculates the interest schedule and balances.',
                              )
                            : _tr(
                                'பதிவான பணப்பரிவர்த்தனைகள் மாற்றப்படாது. ஏற்கனவே வட்டி செலுத்திய மாதங்களின் பழைய கணக்கு பாதுகாக்கப்படும்; செலுத்தாத மாதங்கள் மட்டும் புதிய அமைப்பில் மறுகணக்கிடப்படும்.',
                                'Recorded transactions will not change. Periods with interest payments keep their historical calculation; only unpaid periods recalculate with the new settings.',
                              )),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(flex: 4, child: SizedBox()),
                    Expanded(
                      flex: 3,
                      child: Text(_tr('பழையது', 'Old'),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(_tr('புதியது', 'New'),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const Divider(),
                for (final row in rows) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 4,
                          child: Text(row.$1,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        Expanded(flex: 3, child: Text(row.$2)),
                        Expanded(flex: 3, child: Text(row.$3)),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_tr('ரத்து', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_tr('உறுதிசெய்து சேமி', 'Confirm & save')),
          ),
        ],
      ),
    );
  }

  Future<void> _addPayment(Loan loan) async {
    if (loan.isClosed) {
      _message(_tr(
        'மூடப்பட்ட கடனில் புதிய செலுத்தலை பதிவு செய்ய முடியாது.',
        'Payments cannot be added to a closed loan.',
      ));
      return;
    }
    final payment = await showDialog<LoanPayment>(
      context: _appContext,
      builder: (_) => PaymentFormDialog(loan: loan, isTamil: _isTamil),
    );
    if (payment == null) return;
    final updated = _loans
        .map((item) => item.id == loan.id
            ? item.copyWith(payments: [...item.payments, payment])
            : item)
        .toList();
    final saved = await _saveLoans(updated);
    if (!saved || !mounted) return;
    final updatedLoan = updated.firstWhere((item) => item.id == loan.id);
    await showLoanShareSheet(
      _appContext,
      loan: updatedLoan,
      appIsTamil: _isTamil,
      initialType: LoanShareType.paymentReceipt,
      payment: payment,
    );
  }

  Future<void> _closeLoan(Loan loan) async {
    final today = DateTime.now();
    if (!loan.canClose(today: today)) {
      final pending = loan.settlementOutstanding(today: today);
      _message(_tr(
        'கடனை மூடுவதற்கு முன் முதல்தொகை மற்றும் சேர்ந்த வட்டி முழுவதையும் செலுத்தவும். நிலுவை: ${privateMoney(_appContext, pending)}',
        'Settle the principal and accrued interest before closing. Remaining: ${privateMoney(_appContext, pending)}',
      ));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: _appContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(_tr('கடனை மூடவா?', 'Close this loan?')),
        content: Text(_tr(
          '${loan.person} கணக்கு மூடப்பட்ட கடன்கள் பகுதியில் பாதுகாப்பாக வைக்கப்படும்.',
          '${loan.person} will be moved to Closed loans and its history will be preserved.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_tr('ரத்து', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_tr('கடனை மூடு', 'Close loan')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final closedAt = DateTime(today.year, today.month, today.day);
    await _saveLoans(
      _loans
          .map((item) =>
              item.id == loan.id ? item.copyWith(closedAt: closedAt) : item)
          .toList(),
    );
  }

  Future<void> _editLoanPhone(Loan loan) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(text: loan.phone);
    final phone = await showDialog<String>(
      context: _appContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(_tr('தொடர்பு எண்', 'Contact number')),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.phone,
            maxLength: 18,
            decoration: InputDecoration(
              labelText: _tr('WhatsApp எண்', 'WhatsApp number'),
              hintText: '+91 98765 43210',
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) return null;
              final digits = value!.replaceAll(RegExp(r'\D'), '');
              if (digits.length < 10 || digits.length > 15) {
                return _tr(
                  'சரியான தொலைபேசி எண்ணை உள்ளிடவும்',
                  'Enter a valid phone number',
                );
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_tr('ரத்து', 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
            child: Text(_tr('சேமி', 'Save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (phone == null) return;
    await _saveLoans(
      _loans
          .map(
              (item) => item.id == loan.id ? item.copyWith(phone: phone) : item)
          .toList(),
    );
  }

  Future<void> _deleteLoan(Loan loan) async {
    if (!loan.isClosed) {
      _message(_tr(
        'செயலில் உள்ள கடனை நேரடியாக நீக்க முடியாது. முதலில் நிலுவையை முடித்து கடனை மூடவும்.',
        'An active loan cannot be deleted. Settle it and close the loan first.',
      ));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: _appContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(_tr('மூடப்பட்ட கடனை நீக்கவா?', 'Delete closed loan?')),
        content: Text(_tr(
          '${loan.person} மற்றும் அதன் செலுத்தல் வரலாறு நீக்கப்படும்.',
          '${loan.person} and its payment history will be deleted.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_tr('ரத்து', 'Cancel')),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_tr('நீக்கு', 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _saveLoans(_loans.where((item) => item.id != loan.id).toList());
    }
  }

  Future<void> _changeLanguage(String language) async {
    if (!await _store(_languageKey, language) || !mounted) return;
    setState(() => _language = language);
    await LoanNotificationService.instance.sync(
      loans: _loans,
      enabled: _notificationsEnabled,
      isTamil: language == 'ta',
    );
  }

  Future<void> _changeTheme(bool darkMode) async {
    if (!await _store(_themeKey, darkMode) || !mounted) return;
    setState(() => _darkMode = darkMode);
  }

  Future<void> _saveProfile(String name, String phone) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final nameSaved = await preferences.setString(_nameKey, name.trim());
      final phoneSaved = await preferences.setString(_phoneKey, phone.trim());
      if (!nameSaved || !phoneSaved) {
        throw StateError('Local storage rejected the profile update.');
      }
      if (mounted) {
        setState(() {
          _profileName = name.trim();
          _profilePhone = phone.trim();
        });
        _message(_tr('சுயவிவரம் சேமிக்கப்பட்டது.', 'Profile saved.'));
      }
    } catch (error) {
      debugPrint('Could not save profile: $error');
      if (mounted) {
        _message(_tr(
          'சுயவிவரத்தைச் சேமிக்க முடியவில்லை.',
          'Could not save the profile.',
        ));
      }
    }
  }

  Future<bool> _unlockWithPin(String pin) async {
    final preferences = await SharedPreferences.getInstance();
    final valid = await SecureDataStore.instance.verifyPin(preferences, pin);
    if (valid && mounted) setState(() => _locked = false);
    return valid;
  }

  Future<void> _unlockWithBiometrics() async {
    if (_authenticating || !_locked || !_biometricEnabled) return;
    _authenticating = true;
    final authenticated = await DeviceAuthenticationService.instance
        .authenticate(isTamil: _isTamil);
    _authenticating = false;
    if (authenticated && mounted) setState(() => _locked = false);
  }

  Future<void> _configureSecurity() async {
    final change = await showDialog<_SecurityChange>(
      context: _appContext,
      builder: (_) => _SecurityDialog(
        isTamil: _isTamil,
        lockEnabled: _appLockEnabled,
        biometricEnabled: _biometricEnabled,
        biometricAvailable: _biometricAvailable,
      ),
    );
    if (change == null) return;

    final preferences = await SharedPreferences.getInstance();
    if (_appLockEnabled) {
      final valid = await SecureDataStore.instance
          .verifyPin(preferences, change.currentPin);
      if (!valid) {
        _message(
            _tr('தற்போதைய PIN தவறாக உள்ளது.', 'Current PIN is incorrect.'));
        return;
      }
    }

    if (change.disable) {
      await SecureDataStore.instance.clearPin(preferences);
      if (!mounted) return;
      setState(() {
        _appLockEnabled = false;
        _biometricEnabled = false;
        _locked = false;
      });
      _message(_tr('App lock நிறுத்தப்பட்டது.', 'App lock disabled.'));
      return;
    }

    if (change.newPin.isNotEmpty) {
      await SecureDataStore.instance.setPin(preferences, change.newPin);
    }
    await SecureDataStore.instance
        .setBiometricEnabled(preferences, change.biometricEnabled);
    if (!mounted) return;
    setState(() {
      _appLockEnabled = true;
      _biometricEnabled = change.biometricEnabled;
    });
    _message(_tr(
      'PIN மற்றும் பாதுகாப்பு அமைப்புகள் சேமிக்கப்பட்டன.',
      'PIN and security settings saved.',
    ));
  }

  Future<void> _changeNotifications(bool enabled) async {
    var next = enabled;
    if (enabled) {
      next = await LoanNotificationService.instance.requestPermission();
      if (!next) {
        _message(_tr(
          'Notification அனுமதி வழங்கப்படவில்லை.',
          'Notification permission was not granted.',
        ));
      }
    }
    if (!await _store(_notificationsKey, next) || !mounted) return;
    setState(() => _notificationsEnabled = next);
    await LoanNotificationService.instance.sync(
      loans: _loans,
      enabled: next,
      isTamil: _isTamil,
    );
    if (next) {
      _message(_tr(
        'Due date-க்கு ஒரு நாள் முன்பும் அன்றும் reminder வரும்.',
        'Reminders will arrive one day before and on each due date.',
      ));
    }
  }

  Future<void> _shareLoanPdf(Loan loan) async {
    try {
      await PdfStatementService.instance.shareLoan(
        loan: loan,
        isTamil: _isTamil,
      );
    } catch (error) {
      debugPrint('Could not create PDF: $error');
      if (mounted) {
        _message(_tr(
          'PDF அறிக்கையை உருவாக்க முடியவில்லை.',
          'Could not create the PDF statement.',
        ));
      }
    }
  }

  Future<void> _showBackup() async {
    final controller = TextEditingController(
      text: jsonEncode({
        'version': 1,
        'loans': _loans.map((loan) => loan.toJson()).toList(),
      }),
    );
    await showDialog<void>(
      context: _appContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(_tr('தரவு காப்புப் பிரதி', 'Data backup')),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_tr(
                'கீழே உள்ள JSON-ஐ நகலெடுத்து பாதுகாப்பாக வைத்துக் கொள்ளுங்கள். மீட்டமைக்க, இந்தப் பெட்டியில் backup JSON-ஐ ஒட்டவும்.',
                'Copy this JSON and keep it safe. To restore, paste backup JSON into this field.',
              )),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                minLines: 5,
                maxLines: 10,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: _tr('காப்புப் பிரதி JSON', 'Backup JSON'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: controller.text));
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                _message(
                    _tr('காப்புப் பிரதி நகலெடுக்கப்பட்டது.', 'Backup copied.'));
              }
            },
            child: Text(_tr('நகலெடு', 'Copy')),
          ),
          TextButton(
            onPressed: () async {
              try {
                final decoded = jsonDecode(controller.text);
                final rawLoans = decoded is List
                    ? decoded
                    : decoded is Map
                        ? decoded['loans']
                        : null;
                if (rawLoans is! List) {
                  throw const FormatException('Backup does not contain loans.');
                }
                final restored = rawLoans.map((item) {
                  if (item is! Map) {
                    throw const FormatException('Invalid loan record.');
                  }
                  return Loan.fromJson(Map<String, Object?>.from(item));
                }).toList();
                if (!dialogContext.mounted) return;
                final confirmed = await showDialog<bool>(
                  context: dialogContext,
                  builder: (confirmContext) => AlertDialog(
                    title: Text(_tr('தரவை மீட்டமைக்கவா?', 'Restore backup?')),
                    content: Text(_tr(
                      '${_loans.length} தற்போதைய பதிவுகளுக்குப் பதிலாக ${restored.length} பதிவுகள் சேர்க்கப்படும்.',
                      '${restored.length} records will replace the current ${_loans.length} records.',
                    )),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(confirmContext, false),
                        child: Text(_tr('ரத்து', 'Cancel')),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(confirmContext, true),
                        child: Text(_tr('மீட்டமை', 'Restore')),
                      ),
                    ],
                  ),
                );
                if (confirmed != true || !dialogContext.mounted) return;
                await _saveLoans(restored);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (error) {
                debugPrint('Could not restore backup: $error');
                if (dialogContext.mounted) {
                  _message(_tr(
                    'காப்புப் பிரதி JSON சரியான வடிவில் இல்லை.',
                    'The backup JSON is invalid.',
                  ));
                }
              }
            },
            child: Text(_tr('மீட்டமை', 'Restore')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_tr('மூடு', 'Close')),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Locale(_language);
    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xff1769ff),
      brightness: _darkMode ? Brightness.dark : Brightness.light,
      surface: _darkMode ? const Color(0xff101a2b) : Colors.white,
    );
    return MaterialApp(
      builder: (context, child) => AmountPrivacyScope(
        notifier: _amountVisibility,
        child: child!,
      ),
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      debugShowCheckedModeBanner: false,
      title: 'LoanTrack',
      locale: locale,
      themeAnimationDuration: const Duration(milliseconds: 300),
      themeAnimationCurve: Curves.easeOutCubic,
      supportedLocales: const [Locale('ta'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: _SmoothPageTransitionsBuilder(),
            TargetPlatform.fuchsia: _SmoothPageTransitionsBuilder(),
            TargetPlatform.linux: _SmoothPageTransitionsBuilder(),
            TargetPlatform.windows: _SmoothPageTransitionsBuilder(),
          },
        ),
        colorScheme: colors,
        scaffoldBackgroundColor:
            _darkMode ? const Color(0xff081321) : const Color(0xfff5f7fb),
        fontFamily: 'sans-serif',
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: Colors.transparent,
          foregroundColor: colors.onSurface,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: _darkMode ? const Color(0xff101a2b) : Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor:
              _darkMode ? const Color(0xff142238) : const Color(0xfff6f8fc),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: colors.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xff1769ff), width: 1.5),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 72,
          elevation: 8,
          backgroundColor: _darkMode ? const Color(0xff101a2b) : Colors.white,
          indicatorColor: const Color(0xffe4edff),
          labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
                color: states.contains(WidgetState.selected)
                    ? const Color(0xff1769ff)
                    : colors.onSurfaceVariant,
                fontSize: 11,
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.w700
                    : FontWeight.w500,
              )),
          iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
                color: states.contains(WidgetState.selected)
                    ? const Color(0xff1769ff)
                    : colors.onSurfaceVariant,
              )),
        ),
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          showDragHandle: true,
        ),
      ),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 240),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: .985, end: 1).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey(_loading ? 'loading' : (_locked ? 'locked' : 'home')),
          child: _loading
              ? const PremiumSplash()
              : _locked
                  ? AppLockScreen(
                      isTamil: _isTamil,
                      biometricEnabled:
                          _biometricEnabled && _biometricAvailable,
                      onPinSubmitted: _unlockWithPin,
                      onBiometric: _unlockWithBiometrics,
                    )
                  : PremiumAppShell(
                      loans: _loans,
                      isTamil: _isTamil,
                      darkMode: _darkMode,
                      profileName: _profileName,
                      profilePhone: _profilePhone,
                      loadError: _loadError,
                      selectedPage: _selectedPage,
                      onPageChanged: (page) =>
                          setState(() => _selectedPage = page),
                      onAddLoan: _addLoan,
                      onEditLoan: _editLoan,
                      onPayment: _addPayment,
                      onEditPhone: _editLoanPhone,
                      onSharePdf: _shareLoanPdf,
                      onClose: _closeLoan,
                      onDelete: _deleteLoan,
                      onDetails: (context, loan) => showLoanDetailsPage(
                        context,
                        loan: loan,
                        isTamil: _isTamil,
                        onPayment: () => _addPayment(loan),
                        onShare: () => showLoanShareSheet(
                          context,
                          loan: loan,
                          appIsTamil: _isTamil,
                        ),
                      ),
                      onLanguageChanged: _changeLanguage,
                      onThemeChanged: _changeTheme,
                      onProfileSaved: _saveProfile,
                      appLockEnabled: _appLockEnabled,
                      biometricEnabled: _biometricEnabled,
                      biometricAvailable: _biometricAvailable,
                      notificationsEnabled: _notificationsEnabled,
                      onConfigureSecurity: _configureSecurity,
                      onNotificationsChanged: _changeNotifications,
                      onBackup: _showBackup,
                    ),
        ),
      ),
    );
  }
}

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({
    required this.isTamil,
    required this.biometricEnabled,
    required this.onPinSubmitted,
    required this.onBiometric,
    super.key,
  });

  final bool isTamil;
  final bool biometricEnabled;
  final Future<bool> Function(String pin) onPinSubmitted;
  final VoidCallback onBiometric;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final _pin = TextEditingController();
  bool _checking = false;
  String? _error;

  String _tr(String ta, String en) => widget.isTamil ? ta : en;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_pin.text.length < 4 || _checking) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    final valid = await widget.onPinSubmitted(_pin.text);
    if (!mounted || valid) return;
    setState(() {
      _checking = false;
      _error = _tr('PIN தவறாக உள்ளது', 'Incorrect PIN');
      _pin.clear();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF081B3A), Color(0xFF1769FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Card(
                    elevation: 18,
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircleAvatar(
                            radius: 34,
                            child: Icon(Icons.lock_rounded, size: 32),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _tr('கடன் கணக்கு பூட்டப்பட்டுள்ளது',
                                'LoanTrack is locked'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _tr('திறக்க உங்கள் PIN-ஐ உள்ளிடவும்',
                                'Enter your PIN to continue'),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 22),
                          TextField(
                            controller: _pin,
                            autofocus: !widget.biometricEnabled,
                            obscureText: true,
                            maxLength: 6,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            textAlign: TextAlign.center,
                            onSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'PIN',
                              errorText: _error,
                              counterText: '',
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _checking ? null : _submit,
                              child: _checking
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(_tr('திற', 'Unlock')),
                            ),
                          ),
                          if (widget.biometricEnabled) ...[
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: widget.onBiometric,
                              icon: const Icon(Icons.fingerprint_rounded),
                              label: Text(_tr('கைரேகை மூலம் திற',
                                  'Unlock with biometrics')),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _SecurityChange {
  const _SecurityChange({
    required this.currentPin,
    required this.newPin,
    required this.biometricEnabled,
    required this.disable,
  });

  final String currentPin;
  final String newPin;
  final bool biometricEnabled;
  final bool disable;
}

class _SecurityDialog extends StatefulWidget {
  const _SecurityDialog({
    required this.isTamil,
    required this.lockEnabled,
    required this.biometricEnabled,
    required this.biometricAvailable,
  });

  final bool isTamil;
  final bool lockEnabled;
  final bool biometricEnabled;
  final bool biometricAvailable;

  @override
  State<_SecurityDialog> createState() => _SecurityDialogState();
}

class _SecurityDialogState extends State<_SecurityDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPin = TextEditingController();
  final _newPin = TextEditingController();
  final _confirmPin = TextEditingController();
  late bool _biometric = widget.biometricEnabled;
  bool _disable = false;

  String _tr(String ta, String en) => widget.isTamil ? ta : en;

  @override
  void dispose() {
    _currentPin.dispose();
    _newPin.dispose();
    _confirmPin.dispose();
    super.dispose();
  }

  String? _pinValidator(String? value, {required bool required}) {
    if ((value ?? '').isEmpty && !required) return null;
    if (!RegExp(r'^\d{4,6}$').hasMatch(value ?? '')) {
      return _tr('4 முதல் 6 இலக்க PIN தேவை', 'Use a 4 to 6 digit PIN');
    }
    return null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (!_disable && _newPin.text != _confirmPin.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('PIN பொருந்தவில்லை', 'PINs do not match'))),
      );
      return;
    }
    Navigator.pop(
      context,
      _SecurityChange(
        currentPin: _currentPin.text,
        newPin: _newPin.text,
        biometricEnabled: _biometric,
        disable: _disable,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(_tr('App பாதுகாப்பு', 'App security')),
        content: SizedBox(
          width: 420,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.lockEnabled)
                    TextFormField(
                      controller: _currentPin,
                      obscureText: true,
                      maxLength: 6,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: _tr('தற்போதைய PIN', 'Current PIN'),
                        counterText: '',
                      ),
                      validator: (value) =>
                          _pinValidator(value, required: true),
                    ),
                  if (widget.lockEnabled)
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title:
                          Text(_tr('App lock-ஐ நிறுத்து', 'Disable app lock')),
                      value: _disable,
                      onChanged: (value) => setState(() => _disable = value),
                    ),
                  if (!_disable) ...[
                    TextFormField(
                      controller: _newPin,
                      obscureText: true,
                      maxLength: 6,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: widget.lockEnabled
                            ? _tr('புதிய PIN (மாற்ற மட்டும்)',
                                'New PIN (only to change)')
                            : _tr('புதிய PIN', 'New PIN'),
                        counterText: '',
                      ),
                      validator: (value) => _pinValidator(
                        value,
                        required: !widget.lockEnabled,
                      ),
                    ),
                    TextFormField(
                      controller: _confirmPin,
                      obscureText: true,
                      maxLength: 6,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: _tr('PIN உறுதிப்படுத்தவும்', 'Confirm PIN'),
                        counterText: '',
                      ),
                      validator: (value) => _newPin.text.isEmpty
                          ? null
                          : _pinValidator(value, required: true),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_tr('Biometric unlock', 'Biometric unlock')),
                      subtitle: Text(widget.biometricAvailable
                          ? _tr('கைரேகை / Face unlock பயன்படுத்தவும்',
                              'Use fingerprint or face unlock')
                          : _tr('இந்த சாதனத்தில் biometric கிடைக்கவில்லை',
                              'Biometrics are unavailable on this device')),
                      secondary: const Icon(Icons.fingerprint_rounded),
                      value: _biometric && widget.biometricAvailable,
                      onChanged: widget.biometricAvailable
                          ? (value) => setState(() => _biometric = value)
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_tr('ரத்து', 'Cancel')),
          ),
          FilledButton(
            onPressed: _save,
            child: Text(_tr('சேமி', 'Save')),
          ),
        ],
      );
}

class _HomePage extends StatefulWidget {
  const _HomePage({
    required this.loans,
    required this.isTamil,
    required this.profileName,
    required this.loadError,
    required this.onAdd,
    required this.onPayment,
    required this.onDelete,
    required this.selectedPage,
    required this.onPageChanged,
    required this.onBackup,
  });

  final List<Loan> loans;
  final bool isTamil;
  final String profileName;
  final String? loadError;
  final VoidCallback onAdd;
  final ValueChanged<Loan> onPayment;
  final ValueChanged<Loan> onDelete;
  final int selectedPage;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onBackup;

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  String _filter = 'all';
  String _search = '';

  bool get _ta => widget.isTamil;
  String _tr(String tamil, String english) => _ta ? tamil : english;
  String _money(double value) => privateMoney(context, value);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final given = widget.loans.where((loan) => loan.direction == 'given');
    final taken = widget.loans.where((loan) => loan.direction == 'taken');
    final interestDue = taken.fold<double>(
      0,
      (sum, loan) => sum + loan.overdueInterest(today: now),
    );
    final dueLoans = widget.loans
        .where((loan) => loan.overdueInterest(today: now) > 0.009)
        .toList();
    final shown = widget.loans.where((loan) {
      final matchesFilter = _filter == 'all' || loan.direction == _filter;
      return matchesFilter &&
          loan.person.toLowerCase().contains(_search.toLowerCase());
    }).toList();
    final today =
        MaterialLocalizations.of(context).formatMediumDate(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              child: Text('க', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('LoanTrack', style: TextStyle(fontSize: 17)),
                Text(
                  _tr('உங்கள் கணக்கு · உங்கள் கட்டுப்பாடு',
                      'Your money, in control'),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _tr('காப்புப் பிரதி', 'Backup'),
            onPressed: widget.onBackup,
            icon: const Icon(Icons.backup_outlined),
          ),
          IconButton(
            tooltip: _tr('அமைப்புகள்', 'Settings'),
            onPressed: () => widget.onPageChanged(1),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onAdd,
        icon: const Icon(Icons.add),
        label: Text(_tr('புதிய கடன்', 'New loan')),
      ),
      bottomNavigationBar: _AppNavigationBar(
        isTamil: _ta,
        selectedPage: widget.selectedPage,
        onPageChanged: widget.onPageChanged,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          Text(
            widget.profileName.isNotEmpty
                ? _tr('வணக்கம், ${widget.profileName}',
                    'Hello, ${widget.profileName}')
                : _tr('வணக்கம் 👋', 'Welcome 👋'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          Text(today, style: Theme.of(context).textTheme.bodyMedium),
          if (widget.loadError != null) ...[
            const SizedBox(height: 12),
            _Notice(text: widget.loadError!, error: true),
          ],
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 570;
              final cards = [
                _SummaryCard(
                  label: _tr('நான் கொடுத்தது', 'Lent'),
                  value: _money(given.fold<double>(
                    0,
                    (sum, loan) => sum + loan.outstanding,
                  )),
                  caption:
                      _tr('${given.length} கடன்கள்', '${given.length} loans'),
                  icon: Icons.north_east,
                  tint: const Color(0xffe1f3e8),
                ),
                _SummaryCard(
                  label: _tr('நான் வாங்கியது', 'Borrowed'),
                  value: _money(taken.fold<double>(
                    0,
                    (sum, loan) => sum + loan.outstanding,
                  )),
                  caption:
                      _tr('${taken.length} கடன்கள்', '${taken.length} loans'),
                  icon: Icons.south_west,
                  tint: const Color(0xffffead8),
                ),
                _SummaryCard(
                  label:
                      _tr('மொத்த செலுத்த வேண்டிய வட்டி', 'Total interest due'),
                  value: _money(interestDue),
                  caption:
                      _tr('நிலுவை மாதங்கள் அனைத்தும்', 'All overdue months'),
                  icon: Icons.schedule,
                  tint: const Color(0xffe8eafa),
                ),
              ];
              return wide
                  ? Row(
                      children: [
                        for (var i = 0; i < cards.length; i++) ...[
                          Expanded(child: cards[i]),
                          if (i != cards.length - 1) const SizedBox(width: 10),
                        ],
                      ],
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < cards.length; i++) ...[
                          cards[i],
                          if (i != cards.length - 1) const SizedBox(height: 10),
                        ],
                      ],
                    );
            },
          ),
          if (dueLoans.isNotEmpty) ...[
            const SizedBox(height: 22),
            _SectionTitle(
              title: _tr('மொத்த வட்டி நிலுவை', 'Total interest overdue'),
              trailing: '${dueLoans.length}',
            ),
            const SizedBox(height: 8),
            for (final loan in dueLoans)
              Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(_initial(loan.person))),
                  title: Text(loan.person),
                  subtitle: Text(_tr(
                    '${loan.overdueMonthCount(today: now)} மாதங்கள் நிலுவை',
                    '${loan.overdueMonthCount(today: now)} overdue months',
                  )),
                  trailing: Text(
                    _money(loan.overdueInterest(today: now)),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () => _showDetails(context, loan, _ta),
                ),
              ),
          ],
          const SizedBox(height: 22),
          _SectionTitle(
            title: _tr('என் கடன்கள்', 'My loans'),
            trailing: TextButton.icon(
              onPressed: widget.onBackup,
              icon: const Icon(Icons.download_outlined, size: 18),
              label: Text(_tr('காப்பு', 'Backup')),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            onChanged: (value) => setState(() => _search = value.trim()),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: _tr('பெயரைத் தேடு', 'Search by name'),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'all', label: Text(_tr('அனைத்தும்', 'All'))),
              ButtonSegment(
                  value: 'given', label: Text(_tr('கொடுத்தது', 'Lent'))),
              ButtonSegment(
                  value: 'taken', label: Text(_tr('வாங்கியது', 'Borrowed'))),
            ],
            selected: {_filter},
            onSelectionChanged: (selection) =>
                setState(() => _filter = selection.first),
          ),
          const SizedBox(height: 10),
          if (shown.isEmpty)
            _EmptyState(
              title: widget.loans.isEmpty
                  ? _tr('இன்னும் கடன் இல்லை', 'No loans yet')
                  : _tr('பொருத்தமான கடன் இல்லை', 'No matching loans'),
              subtitle: widget.loans.isEmpty
                  ? _tr(
                      'கடன் சேர்த்து வட்டி மற்றும் செலுத்தல்களைக் கண்காணிக்கத் தொடங்குங்கள்.',
                      'Add a loan to start tracking interest and payments.')
                  : _tr('தேடல் அல்லது வடிகட்டியை மாற்றிப் பாருங்கள்.',
                      'Try another search or filter.'),
              action: widget.loans.isEmpty
                  ? FilledButton.icon(
                      onPressed: widget.onAdd,
                      icon: const Icon(Icons.add),
                      label: Text(_tr('கடன் சேர்க்க', 'Add a loan')),
                    )
                  : null,
            )
          else
            for (final loan in shown)
              _LoanCard(
                loan: loan,
                isTamil: _ta,
                onPayment: () => widget.onPayment(loan),
                onDetails: () => _showDetails(context, loan, _ta),
                onDelete: () => widget.onDelete(loan),
              ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.tint,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: tint,
                child: Icon(icon, color: const Color(0xff176b58)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    Text(caption,
                        style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final Object? trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (trailing is String)
            Chip(
              label: Text(trailing! as String),
              visualDensity: VisualDensity.compact,
            )
          else if (trailing != null)
            trailing is Widget ? trailing! as Widget : const SizedBox.shrink(),
        ],
      );
}

class _AppNavigationBar extends StatelessWidget {
  const _AppNavigationBar({
    required this.isTamil,
    required this.selectedPage,
    required this.onPageChanged,
  });

  final bool isTamil;
  final int selectedPage;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) => NavigationBar(
        selectedIndex: selectedPage,
        onDestinationSelected: onPageChanged,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: isTamil ? 'முகப்பு' : 'Home',
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: isTamil ? 'அமைப்புகள்' : 'Settings',
          ),
        ],
      );
}

class _LoanCard extends StatelessWidget {
  const _LoanCard({
    required this.loan,
    required this.isTamil,
    required this.onPayment,
    required this.onDetails,
    required this.onDelete,
  });

  final Loan loan;
  final bool isTamil;
  final VoidCallback onPayment;
  final VoidCallback onDetails;
  final VoidCallback onDelete;

  String _tr(String ta, String en) => isTamil ? ta : en;
  String _money(BuildContext context, double value) =>
      privateMoney(context, value);

  @override
  Widget build(BuildContext context) {
    final status = loan.statusFor(DateFormat('yyyy-MM').format(DateTime.now()));
    final isGiven = loan.direction == 'given';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(_initial(loan.person))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loan.person,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        '${_tr(isGiven ? 'கொடுத்தது' : 'வாங்கியது', isGiven ? 'Lent' : 'Borrowed')} · ${loan.rate}% ${_tr('மாத வட்டி', 'monthly interest')}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: _tr('நீக்கு', 'Delete'),
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const Divider(height: 22),
            Row(
              children: [
                Expanded(
                  child: _AmountColumn(
                    label: _tr('நிலுவை முதல்தொகை', 'Principal outstanding'),
                    value: _money(context, loan.outstanding),
                  ),
                ),
                Expanded(
                  child: _AmountColumn(
                    label: _tr('மாத வட்டி', 'Monthly interest'),
                    value: _money(context, loan.monthlyInterest),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              status.remaining <= 0.009
                  ? _tr('இந்த மாத வட்டி செலுத்தப்பட்டது',
                      'This month interest is settled')
                  : _tr(
                      'இந்த மாத வட்டி ${_money(context, status.remaining)} மீதி · தேதி ${loan.dueDay}',
                      'Interest remaining ${_money(context, status.remaining)} · due day ${loan.dueDay}',
                    ),
              style: TextStyle(
                color: status.isDue
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (loan.note.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(loan.note, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onPayment,
                  icon: const Icon(Icons.add_card, size: 18),
                  label: Text(_tr('செலுத்தல் பதிவு', 'Record payment')),
                ),
                TextButton.icon(
                  onPressed: onDetails,
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: Text(_tr('விவரங்கள்', 'Details')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountColumn extends StatelessWidget {
  const _AmountColumn({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ],
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.subtitle,
    this.action,
  });
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        child: Column(
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 44, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 14),
              action!,
            ],
          ],
        ),
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.error});
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) => Card(
        color: error
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(text),
        ),
      );
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage({
    required this.isTamil,
    required this.darkMode,
    required this.profileName,
    required this.profilePhone,
    required this.onLanguageChanged,
    required this.onThemeChanged,
    required this.onProfileSaved,
    required this.onBackup,
    required this.selectedPage,
    required this.onPageChanged,
  });

  final bool isTamil;
  final bool darkMode;
  final String profileName;
  final String profilePhone;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<bool> onThemeChanged;
  final void Function(String name, String phone) onProfileSaved;
  final VoidCallback onBackup;
  final int selectedPage;
  final ValueChanged<int> onPageChanged;

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  String _tr(String ta, String en) => widget.isTamil ? ta : en;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profileName);
    _phoneController = TextEditingController(text: widget.profilePhone);
  }

  @override
  void didUpdateWidget(covariant _SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.profileName != oldWidget.profileName) {
      _nameController.text = widget.profileName;
    }
    if (widget.profilePhone != oldWidget.profilePhone) {
      _phoneController.text = widget.profilePhone;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_tr('அமைப்புகள்', 'Settings'))),
        bottomNavigationBar: _AppNavigationBar(
          isTamil: widget.isTamil,
          selectedPage: widget.selectedPage,
          onPageChanged: widget.onPageChanged,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(_tr('சுயவிவரம்', 'Profile'),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: _tr('உங்கள் பெயர்', 'Your name'),
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: _tr('தொலைபேசி எண்', 'Phone number'),
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => widget.onProfileSaved(
                  _nameController.text,
                  _phoneController.text,
                ),
                child: Text(_tr('சுயவிவரத்தைச் சேமி', 'Save profile')),
              ),
            ),
            const Divider(height: 30),
            Text(_tr('தோற்றம் மற்றும் மொழி', 'Appearance and language'),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_tr('இருண்ட தோற்றம்', 'Dark theme')),
              secondary: const Icon(Icons.dark_mode_outlined),
              value: widget.darkMode,
              onChanged: widget.onThemeChanged,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.language),
              title: Text(_tr('மொழி', 'Language')),
              trailing: DropdownButton<String>(
                value: widget.isTamil ? 'ta' : 'en',
                items: [
                  DropdownMenuItem(
                    value: 'ta',
                    child: Text(_tr('தமிழ்', 'Tamil')),
                  ),
                  const DropdownMenuItem(value: 'en', child: Text('English')),
                ],
                onChanged: (value) {
                  if (value != null) widget.onLanguageChanged(value);
                },
              ),
            ),
            const Divider(height: 30),
            Text(_tr('தரவு மற்றும் தனியுரிமை', 'Data and privacy'),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.backup_outlined),
              title: Text(_tr('காப்புப் பிரதி / மீட்டமை', 'Backup / restore')),
              subtitle: Text(_tr(
                'தரவு இந்தச் சாதனத்தில் மட்டும் சேமிக்கப்படும்.',
                'Your data is stored only on this device.',
              )),
              trailing: const Icon(Icons.chevron_right),
              onTap: widget.onBackup,
            ),
          ],
        ),
      );
}

class LoanFormPage extends StatefulWidget {
  const LoanFormPage({required this.isTamil, this.loan, super.key});
  final bool isTamil;
  final Loan? loan;

  @override
  State<LoanFormPage> createState() => _LoanFormPageState();
}

class _LoanFormPageState extends State<LoanFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _person = TextEditingController();
  final _phone = TextEditingController();
  final _principal = TextEditingController();
  final _rate = TextEditingController();
  final _dueDay = TextEditingController();
  final _note = TextEditingController();
  String _direction = 'given';
  bool _interestFree = false;
  late DateTime _loanDate;
  late DateTime _interestStartDate;
  late DateTime _firstInterestDueDate;

  bool get _editing => widget.loan != null;

  bool get _hasInterest =>
      !_interestFree && (double.tryParse(_rate.text) ?? 0) > 0;

  String _tr(String ta, String en) => widget.isTamil ? ta : en;

  @override
  void initState() {
    super.initState();
    final loan = widget.loan;
    final now = DateTime.now();
    _direction = loan?.direction ?? 'given';
    _person.text = loan?.person ?? '';
    _phone.text = loan?.phone ?? '';
    _principal.text = loan == null ? '' : _plainNumber(loan.principal);
    _rate.text = loan == null ? '2' : _plainNumber(loan.rate);
    _dueDay.text = (loan?.dueDay ?? 5).toString();
    _note.text = loan?.note ?? '';
    _interestFree = loan?.rate == 0;
    _loanDate = loan?.startDate ?? now;
    _interestStartDate = loan?.interestStartDate ?? now;
    _firstInterestDueDate = loan?.firstInterestDueDate ??
        _dueDateFor(_interestStartDate, int.parse(_dueDay.text));
  }

  String _plainNumber(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  DateTime _dueDateFor(DateTime start, int _) {
    final nextMonth = DateTime(start.year, start.month + 1, 1);
    final anniversary = DateTime(
      nextMonth.year,
      nextMonth.month,
      math.min(
        start.day,
        DateTime(nextMonth.year, nextMonth.month + 1, 0).day,
      ),
    );
    return anniversary.subtract(const Duration(days: 1));
  }

  @override
  void dispose() {
    _person.dispose();
    _phone.dispose();
    _principal.dispose();
    _rate.dispose();
    _dueDay.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickLoanDate() async {
    final now = DateTime.now();
    final paymentDates = widget.loan?.payments.map((payment) => payment.date);
    final earliestPayment = paymentDates == null || paymentDates.isEmpty
        ? null
        : paymentDates.reduce((a, b) => a.isBefore(b) ? a : b);
    final lastDate = earliestPayment == null || earliestPayment.isAfter(now)
        ? now
        : earliestPayment;
    final selected = await showDatePicker(
      context: context,
      initialDate: _loanDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(lastDate.year, lastDate.month, lastDate.day),
    );
    if (selected != null) {
      setState(() {
        _loanDate = selected;
        if (_interestStartDate.isBefore(selected)) {
          _interestStartDate = selected;
        }
        final minimumDue = _dueDateFor(
          _interestStartDate,
          int.tryParse(_dueDay.text) ?? 5,
        );
        if (_firstInterestDueDate.isBefore(minimumDue)) {
          _firstInterestDueDate = minimumDue;
        }
      });
    }
  }

  Future<void> _pickInterestStartDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _interestStartDate.isBefore(_loanDate)
          ? _loanDate
          : _interestStartDate,
      firstDate: _loanDate,
      lastDate: DateTime(now.year + 20, 12, 31),
    );
    if (selected != null) {
      setState(() {
        _interestStartDate = selected;
        final minimumDue =
            _dueDateFor(selected, int.tryParse(_dueDay.text) ?? 5);
        if (_firstInterestDueDate.isBefore(minimumDue)) {
          _firstInterestDueDate = minimumDue;
        }
      });
    }
  }

  Future<void> _pickFirstInterestDueDate() async {
    final now = DateTime.now();
    final minimumDueDate =
        _dueDateFor(_interestStartDate, int.tryParse(_dueDay.text) ?? 5);
    final selected = await showDatePicker(
      context: context,
      initialDate: _firstInterestDueDate.isBefore(minimumDueDate)
          ? minimumDueDate
          : _firstInterestDueDate,
      firstDate: minimumDueDate,
      lastDate: DateTime(now.year + 30, 12, 31),
    );
    if (selected != null) setState(() => _firstInterestDueDate = selected);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final principal = double.parse(_principal.text);
    final rate = double.parse(_rate.text);
    final dueDay = int.parse(_dueDay.text);
    final minimumFirstDueDate = _dueDateFor(_interestStartDate, dueDay);
    if (_firstInterestDueDate.isBefore(minimumFirstDueDate) && rate > 0) {
      _message(_tr(
        'முதல் வட்டி தவணை ஒரு முழு மாதம் முடிந்த பிறகே இருக்க வேண்டும்.',
        'First interest due date must be after one complete month.',
      ));
      return;
    }
    final existing = widget.loan;
    final result = existing == null
        ? Loan(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            direction: _direction,
            person: _person.text.trim(),
            phone: _phone.text.trim(),
            principal: principal,
            rate: rate,
            dueDay: dueDay,
            startDate: _loanDate,
            interestStartDate: _interestStartDate,
            firstInterestDueDate: _firstInterestDueDate,
            note: _note.text.trim(),
            payments: const [],
          )
        : existing.withCalculationSettings(
            person: _person.text.trim(),
            phone: _phone.text.trim(),
            rate: rate,
            dueDay: dueDay,
            startDate: _loanDate,
            interestStartDate: _interestStartDate,
            firstInterestDueDate: _firstInterestDueDate,
            note: _note.text.trim(),
          );
    Navigator.pop(context, result);
  }

  void _message(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty
          ? _tr('$label நிரப்பவும்', 'Enter $label')
          : null;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(_editing
              ? _tr('கடன் அமைப்புகளைத் திருத்து', 'Edit loan settings')
              : _tr('புதிய கடன்', 'New loan')),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                            value: 'given',
                            label: Text(_tr('நான் கொடுத்தது', 'I lent')),
                          ),
                          ButtonSegment(
                            value: 'taken',
                            label: Text(_tr('நான் வாங்கியது', 'I borrowed')),
                          ),
                        ],
                        selected: {_direction},
                        onSelectionChanged: _editing
                            ? null
                            : (value) => setState(() {
                                  _direction = value.first;
                                  if (_direction == 'taken' && _interestFree) {
                                    _interestFree = false;
                                    _rate.text = '2';
                                  }
                                }),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _person,
                        maxLength: 70,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: _tr('நபர் பெயர்', 'Person name'),
                        ),
                        validator: (value) =>
                            _required(value, _tr('பெயரை', 'Name')),
                      ),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        maxLength: 18,
                        decoration: InputDecoration(
                          labelText: _tr('WhatsApp எண் (விருப்பம்)',
                              'WhatsApp number (optional)'),
                          hintText: '+91 98765 43210',
                          prefixIcon: const Icon(Icons.phone_outlined),
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) return null;
                          final digits = value!.replaceAll(RegExp(r'\D'), '');
                          if (digits.length < 10 || digits.length > 15) {
                            return _tr(
                              'சரியான தொலைபேசி எண்ணை உள்ளிடவும்',
                              'Enter a valid phone number',
                            );
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: _principal,
                        readOnly: _editing,
                        onChanged: (_) => setState(() {}),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: _tr('முதல்தொகை (₹)', 'Principal (₹)'),
                        ),
                        validator: (value) {
                          final number = double.tryParse(value ?? '');
                          if (number == null ||
                              !number.isFinite ||
                              number <= 0) {
                            return _tr('சரியான தொகையை உள்ளிடவும்',
                                'Enter a valid amount');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      if (_direction == 'given') ...[
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                              _tr('வட்டி இல்லா கடன்', 'Interest-free loan')),
                          subtitle: Text(_tr(
                            'இந்த நபரிடம் வட்டி வசூலிக்கப்படாது',
                            'No interest will be charged to this person',
                          )),
                          secondary: const Icon(Icons.favorite_outline_rounded),
                          value: _interestFree,
                          onChanged: (value) => setState(() {
                            _interestFree = value;
                            _rate.text = value ? '0' : '2';
                          }),
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (!_interestFree) ...[
                        TextFormField(
                          controller: _rate,
                          onChanged: (_) => setState(() {}),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                              labelText:
                                  _tr('மாத வட்டி (%)', 'Monthly rate (%)')),
                          validator: (value) {
                            final number = double.tryParse(value ?? '');
                            if (number == null ||
                                !number.isFinite ||
                                number < 0 ||
                                number > 100) {
                              return _tr('0 முதல் 100 வரை உள்ளிடவும்',
                                  'Enter a value from 0 to 100');
                            }
                            return null;
                          },
                        ),
                        if (_hasInterest) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _dueDay,
                            onChanged: (_) => setState(() {}),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: _tr('மாத வட்டி தவணை நாள் (1–31)',
                                  'Monthly interest due day (1–31)'),
                            ),
                            validator: (value) {
                              final number = int.tryParse(value ?? '');
                              if (number == null || number < 1 || number > 31) {
                                return _tr('1 முதல் 31 வரை உள்ளிடவும்',
                                    'Enter a day from 1 to 31');
                              }
                              return null;
                            },
                          ),
                        ],
                      ],
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_tr('கடன் தேதி', 'Loan date')),
                        subtitle: Text(MaterialLocalizations.of(context)
                            .formatMediumDate(_loanDate)),
                        trailing: const Icon(Icons.calendar_month),
                        onTap: _pickLoanDate,
                      ),
                      if (_hasInterest)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(_tr(
                              'வட்டி தொடங்கும் தேதி', 'Interest start date')),
                          subtitle: Text(MaterialLocalizations.of(context)
                              .formatMediumDate(_interestStartDate)),
                          trailing: const Icon(Icons.calendar_month),
                          onTap: _pickInterestStartDate,
                        ),
                      if (_hasInterest)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(_tr(
                            'முதல் வட்டி தவணை தேதி',
                            'First interest due date',
                          )),
                          subtitle: Text(MaterialLocalizations.of(context)
                              .formatMediumDate(_firstInterestDueDate)),
                          trailing: const Icon(Icons.event_available_outlined),
                          onTap: _pickFirstInterestDueDate,
                        ),
                      TextFormField(
                        controller: _note,
                        maxLength: 120,
                        decoration: InputDecoration(
                          labelText:
                              _tr('குறிப்பு (விருப்பம்)', 'Note (optional)'),
                        ),
                      ),
                      if (_hasInterest &&
                          _principal.text.isNotEmpty &&
                          _rate.text.isNotEmpty &&
                          double.tryParse(_principal.text) != null &&
                          double.tryParse(_rate.text) != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _tr('மாத வட்டி: ', 'Monthly interest: ') +
                                NumberFormat.currency(
                                  locale: 'en_IN',
                                  symbol: '₹',
                                  decimalDigits: 2,
                                ).format(double.parse(_principal.text) *
                                    double.parse(_rate.text) /
                                    100),
                          ),
                        ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(_tr('ரத்து', 'Cancel')),
                          ),
                          const SizedBox(width: 10),
                          FilledButton(
                            onPressed: _submit,
                            child: Text(_editing
                                ? _tr('மாற்றங்களைப் பார்க்க', 'Review changes')
                                : _tr('சேமி', 'Save')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class PaymentFormDialog extends StatefulWidget {
  const PaymentFormDialog({
    required this.loan,
    required this.isTamil,
    super.key,
  });
  final Loan loan;
  final bool isTamil;

  @override
  State<PaymentFormDialog> createState() => _PaymentFormDialogState();
}

class _PaymentFormDialogState extends State<PaymentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  String _type = 'interest';
  late DateTime _paymentDate;
  late String _month;

  Loan get _loan => widget.loan;
  bool get _canPayInterest => _loan.months.any(
        (month) => _loan.statusFor(month).remaining > 0.009,
      );
  String _tr(String ta, String en) => widget.isTamil ? ta : en;
  double get _interestPayable =>
      _loan.accruedInterestForMonth(_month, today: _paymentDate);

  @override
  void initState() {
    super.initState();
    _paymentDate = DateTime.now();
    final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
    _month = _loan.oldestUnpaidMonth(dueOnly: true) ??
        _loan.oldestUnpaidMonth() ??
        currentMonth;
    final payable = _interestPayable;
    if (!_canPayInterest || payable <= 0.009) _type = 'principal';
    _amount.text =
        (_type == 'interest' ? payable : _loan.outstanding).toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  String _monthLabel(String month) {
    final date = DateTime(
        int.parse(month.substring(0, 4)), int.parse(month.substring(5, 7)));
    return MaterialLocalizations.of(context).formatMonthYear(date);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      LoanPayment(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: _type,
        amount: double.parse(_amount.text),
        date: _paymentDate,
        month: _type == 'interest' ? _month : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthOptions = _loan.months.isEmpty
        ? [DateFormat('yyyy-MM').format(DateTime.now())]
        : _loan.months.reversed.toList();
    if (!monthOptions.contains(_month)) _month = monthOptions.first;
    final maxAmount =
        _type == 'interest' ? _interestPayable : _loan.outstanding;

    return AlertDialog(
      title:
          Text(_tr('${_loan.person} · செலுத்தல்', '${_loan.person} · Payment')),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_canPayInterest) ...[
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'interest',
                        label: Text(_tr('வட்டி', 'Interest')),
                      ),
                      ButtonSegment(
                        value: 'principal',
                        label: Text(_tr('முதல்தொகை', 'Principal')),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (value) {
                      setState(() {
                        _type = value.first;
                        _amount.text = (_type == 'interest'
                                ? _interestPayable
                                : _loan.outstanding)
                            .toStringAsFixed(2);
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                ],
                if (_type == 'interest')
                  DropdownButtonFormField<String>(
                    initialValue: _month,
                    decoration: InputDecoration(
                      labelText: _tr('எந்த மாத வட்டி?', 'Interest month'),
                    ),
                    items: monthOptions
                        .map((month) => DropdownMenuItem(
                              value: month,
                              child: Text(_monthLabel(month)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _month = value;
                          _amount.text = _interestPayable.toStringAsFixed(2);
                        });
                      }
                    },
                  ),
                if (_type == 'interest') const SizedBox(height: 12),
                if (_type == 'interest')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _tr(
                        'வட்டி காலம்: ${MaterialLocalizations.of(context).formatMediumDate(_loan.interestPeriodStart(_month))} – ${MaterialLocalizations.of(context).formatMediumDate(_loan.interestPeriodEnd(_month))}',
                        'Interest period: ${MaterialLocalizations.of(context).formatMediumDate(_loan.interestPeriodStart(_month))} – ${MaterialLocalizations.of(context).formatMediumDate(_loan.interestPeriodEnd(_month))}',
                      ),
                    ),
                  ),
                if (_type == 'interest') const SizedBox(height: 12),
                TextFormField(
                  controller: _amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _tr('தொகை (₹)', 'Amount (₹)'),
                    helperText: _tr(
                      'அதிகபட்சம் ${maxAmount.toStringAsFixed(2)}',
                      'Maximum ${maxAmount.toStringAsFixed(2)}',
                    ),
                  ),
                  validator: (value) {
                    final amount = double.tryParse(value ?? '');
                    if (amount == null ||
                        !amount.isFinite ||
                        amount <= 0 ||
                        amount > maxAmount + 0.009) {
                      return _tr(
                        'நிலுவைத் தொகைக்குள் சரியான தொகையை உள்ளிடவும்',
                        'Enter a valid amount within the outstanding balance',
                      );
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_loan.direction == 'given'
                      ? _tr('பணம் பெற்ற தேதி', 'Payment received date')
                      : _tr('பணம் செலுத்திய தேதி', 'Payment paid date')),
                  subtitle: Text(MaterialLocalizations.of(context)
                      .formatMediumDate(_paymentDate)),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final today = DateTime.now();
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: _paymentDate,
                      firstDate: _loan.startDate,
                      lastDate: DateTime(today.year, today.month, today.day),
                    );
                    if (selected != null) {
                      setState(() {
                        _paymentDate = selected;
                        if (_type == 'interest') {
                          _amount.text = _interestPayable.toStringAsFixed(2);
                        }
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_tr('ரத்து', 'Cancel')),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_tr('பதிவு செய்', 'Record')),
        ),
      ],
    );
  }
}

Future<void> _showDetails(BuildContext context, Loan loan, bool isTamil) async {
  String tr(String ta, String en) => isTamil ? ta : en;
  String money(double value) => privateMoney(context, value);
  final now = DateTime.now();
  final months =
      loan.rate > 0 ? loan.monthsThrough(now).reversed.toList() : <String>[];
  final interestOutstanding = loan.interestOutstanding(today: now);
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (pageContext) => Scaffold(
        appBar: AppBar(title: Text(loan.person)),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  _DetailLine(
                    label: tr('கடன் வகை', 'Loan type'),
                    value: tr(
                        loan.direction == 'given'
                            ? 'நான் கொடுத்தது'
                            : 'நான் வாங்கியது',
                        loan.direction == 'given' ? 'Lent' : 'Borrowed'),
                  ),
                  if (loan.phone.isNotEmpty)
                    _DetailLine(
                      label: tr('WhatsApp எண்', 'WhatsApp number'),
                      value: loan.phone,
                    ),
                  _DetailLine(
                    label: tr('தொடக்க முதல்தொகை', 'Original principal'),
                    value: money(loan.principal),
                  ),
                  _DetailLine(
                    label: tr('நிலுவை முதல்தொகை', 'Outstanding principal'),
                    value: money(loan.outstanding),
                  ),
                  if (loan.rate > 0) ...[
                    _DetailLine(
                      label: tr('வட்டி நிலுவை', 'Interest outstanding'),
                      value: money(interestOutstanding),
                    ),
                    _DetailLine(
                      label: tr('மாத வட்டி', 'Monthly interest'),
                      value: '${loan.rate}% · ${money(loan.monthlyInterest)}',
                    ),
                    _DetailLine(
                      label: tr('வட்டி செலுத்தும் தேதி', 'Interest due day'),
                      value: '${loan.dueDay}',
                    ),
                  ],
                  _DetailLine(
                    label: tr('மொத்த நிலுவை', 'Total outstanding'),
                    value: money(loan.totalOutstanding(today: now)),
                  ),
                  _DetailLine(
                    label: tr('கடன் தேதி', 'Loan date'),
                    value: MaterialLocalizations.of(context)
                        .formatMediumDate(loan.startDate),
                  ),
                  if (loan.rate > 0)
                    _DetailLine(
                      label: tr('வட்டி தொடங்கும் தேதி', 'Interest start date'),
                      value: MaterialLocalizations.of(context)
                          .formatMediumDate(loan.interestStartDate),
                    ),
                  if (loan.rate > 0)
                    _DetailLine(
                      label: tr(
                          'முதல் வட்டி தவணை தேதி', 'First interest due date'),
                      value: MaterialLocalizations.of(context)
                          .formatMediumDate(loan.firstInterestDueDate),
                    ),
                  if (loan.lastPaymentDate != null)
                    _DetailLine(
                      label: tr('கடைசி பணம் பெற்ற தேதி', 'Last payment date'),
                      value: MaterialLocalizations.of(context)
                          .formatMediumDate(loan.lastPaymentDate!),
                    ),
                  if (loan.note.isNotEmpty)
                    _DetailLine(
                        label: tr('குறிப்பு', 'Note'), value: loan.note),
                  if (loan.hasInterestLedger) ...[
                    const Divider(),
                    Text(
                        tr('மாத வாரியான வட்டி கணக்கு',
                            'Monthly interest ledger'),
                        style: Theme.of(context).textTheme.titleMedium),
                    if (months.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(tr('பதிவுகள் இல்லை', 'No entries yet')),
                      ),
                    for (final month in months)
                      Builder(builder: (context) {
                        final status = loan.statusFor(month);
                        final date = DateTime(
                          int.parse(month.substring(0, 4)),
                          int.parse(month.substring(5, 7)),
                        );
                        final title = MaterialLocalizations.of(context)
                            .formatMonthYear(date);
                        final interestPayments = loan.payments
                            .where((payment) =>
                                payment.type == 'interest' &&
                                payment.month == month)
                            .toList();
                        return ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Text(title),
                          subtitle: Text(
                            '${tr('வட்டி', 'Interest')}: ${money(status.expected)} · ${tr('மீதி', 'Remaining')}: ${money(status.remaining)}',
                          ),
                          children: [
                            ListTile(
                              dense: true,
                              title: Text(status.isDue
                                  ? tr('நிலுவை', 'Overdue')
                                  : status.remaining <= 0.009
                                      ? tr('செலுத்தப்பட்டது', 'Paid')
                                      : tr('நிலுவையில் இல்லை', 'Not yet due')),
                              subtitle: Text(tr(
                                'செலுத்த வேண்டிய தேதி: ${MaterialLocalizations.of(context).formatMediumDate(status.dueDate)}',
                                'Due date: ${MaterialLocalizations.of(context).formatMediumDate(status.dueDate)}',
                              )),
                            ),
                            for (final payment in interestPayments)
                              ListTile(
                                dense: true,
                                leading: const Icon(Icons.check_circle_outline),
                                title: Text(money(payment.amount)),
                                subtitle: Text(MaterialLocalizations.of(context)
                                    .formatMediumDate(payment.date)),
                              ),
                          ],
                        );
                      }),
                  ],
                  if (loan.payments
                      .any((payment) => payment.type == 'principal')) ...[
                    const Divider(),
                    Text(
                        tr('முதல்தொகை திருப்பிச் செலுத்தல்கள்',
                            'Principal repayments'),
                        style: Theme.of(context).textTheme.titleMedium),
                    for (final payment
                        in loan.payments
                            .where((payment) => payment.type == 'principal')
                            .toList()
                          ..sort((a, b) => b.date.compareTo(a.date)))
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.payments_outlined),
                        title: Text(money(payment.amount)),
                        subtitle: Text(MaterialLocalizations.of(context)
                            .formatMediumDate(payment.date)),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

String _initial(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '?' : trimmed.characters.first;
}
