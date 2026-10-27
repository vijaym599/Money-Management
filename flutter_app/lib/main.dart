import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_services.dart';
import 'amount_privacy.dart';
import 'loan_detail_page.dart';
import 'loan_forms.dart';
import 'models.dart';
import 'premium_ui.dart';
import 'savings_form_page.dart';

export 'models.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KadanKanakkuApp());
}

const _languageKey = 'kadan-kanakku-language';
const _themeKey = 'kadan-kanakku-dark-mode';
const _nameKey = 'kadan-kanakku-profile-name';
const _phoneKey = 'kadan-kanakku-profile-phone';
const _profileImageKey = 'kadan-kanakku-profile-image-v1';
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
  String? _profileImageBase64;
  String? _loadError;
  List<Loan> _loans = [];
  List<SavingsEntry> _savings = [];
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
      final rawSavings =
          await SecureDataStore.instance.readSavings(preferences);
      final decodedSavings =
          rawSavings == null ? <Object?>[] : jsonDecode(rawSavings);
      if (decodedSavings is! List) {
        throw const FormatException('Saved savings are not a list.');
      }
      final savings = decodedSavings.map((item) {
        if (item is! Map) {
          throw const FormatException('Invalid savings record.');
        }
        return SavingsEntry.fromJson(Map<String, Object?>.from(item));
      }).toList();
      final appLockEnabled = await SecureDataStore.instance.hasPin(preferences);
      final biometricEnabled = appLockEnabled &&
          await SecureDataStore.instance.biometricEnabled(preferences);
      final notificationsEnabled =
          preferences.getBool(_notificationsKey) ?? false;
      if (!mounted) return;
      setState(() {
        _loans = loans;
        _savings = savings;
        _language = preferences.getString(_languageKey) == 'ta' ? 'ta' : 'en';
        _darkMode = preferences.getBool(_themeKey) ?? false;
        _profileName = preferences.getString(_nameKey) ?? '';
        _profilePhone = preferences.getString(_phoneKey) ?? '';
        _profileImageBase64 = preferences.getString(_profileImageKey);
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

  Future<bool> _saveSavings(List<SavingsEntry> savings) async {
    final json = jsonEncode(savings.map((entry) => entry.toJson()).toList());
    final preferences = await SharedPreferences.getInstance();
    if (await SecureDataStore.instance.writeSavings(preferences, json) &&
        mounted) {
      setState(() => _savings = savings);
      return true;
    }
    if (mounted) {
      _message(_tr(
        'சேமிப்பு விவரங்களை சேமிக்க முடியவில்லை.',
        'Could not save the savings data.',
      ));
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

  Future<void> _addSavings() async {
    final entry = await Navigator.of(_appContext).push<SavingsEntry>(
      MaterialPageRoute(
        builder: (_) => SavingsFormPage(isTamil: _isTamil),
      ),
    );
    if (entry != null) await _saveSavings([entry, ..._savings]);
  }

  Future<void> _editSavings(SavingsEntry entry) async {
    final updated = await Navigator.of(_appContext).push<SavingsEntry>(
      MaterialPageRoute(
        builder: (_) => SavingsFormPage(isTamil: _isTamil, entry: entry),
      ),
    );
    if (updated == null) return;
    await _saveSavings(
      _savings.map((item) => item.id == entry.id ? updated : item).toList(),
    );
  }

  Future<void> _deleteSavings(SavingsEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: _appContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(_tr('சேமிப்பை நீக்கவா?', 'Delete savings?')),
        content: Text(_tr(
          '${entry.name} சேமிப்பு பதிவை மட்டும் நீக்கும். உண்மையான வங்கி அல்லது பணம் பாதிக்கப்படாது.',
          'This only removes the ${entry.name} record. It does not affect the actual bank account or money.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_tr('ரத்து', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_tr('நீக்கு', 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _saveSavings(
      _savings.where((item) => item.id != entry.id).toList(),
    );
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
    _message(_tr('செலுத்தல் பதிவு செய்யப்பட்டது.', 'Payment recorded.'));
  }

  Future<bool> _deletePayment(Loan loan, LoanPayment payment) async {
    if (loan.isClosed) {
      _message(_tr(
        'மூடப்பட்ட கடனின் செலுத்தலை நீக்க முடியாது.',
        'Payments in a closed loan cannot be deleted.',
      ));
      return false;
    }
    final confirmed = await showDialog<bool>(
      context: _appContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(_tr('செலுத்தலை நீக்கவா?', 'Delete payment?')),
        content: Text(_tr(
          '${loan.person} கணக்கில் உள்ள ${privateMoney(_appContext, payment.amount)} செலுத்தல் நீக்கப்படும். நிலுவை மீண்டும் கணக்கிடப்படும்.',
          '${privateMoney(_appContext, payment.amount)} will be removed from ${loan.person}. Balances will be recalculated.',
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
    if (confirmed != true) return false;

    final updated = _loans
        .map((item) =>
            item.id == loan.id ? item.withoutPayment(payment.id) : item)
        .toList();
    final saved = await _saveLoans(updated);
    if (saved && mounted) {
      _message(_tr('செலுத்தல் நீக்கப்பட்டது.', 'Payment deleted.'));
    }
    return saved;
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
              labelText: _tr('தொடர்பு எண்', 'Contact number'),
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

  Future<void> _saveProfileImage(String? encodedImage) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = encodedImage == null
          ? await preferences.remove(_profileImageKey)
          : await preferences.setString(_profileImageKey, encodedImage);
      if (!saved) throw StateError('Local storage rejected the profile image.');
      if (!mounted) return;
      setState(() => _profileImageBase64 = encodedImage);
      _message(_tr(
        encodedImage == null
            ? 'சுயவிவரப் படம் நீக்கப்பட்டது.'
            : 'சுயவிவரப் படம் சேமிக்கப்பட்டது.',
        encodedImage == null
            ? 'Profile photo removed.'
            : 'Profile photo saved.',
      ));
    } catch (error) {
      debugPrint('Could not save profile image: $error');
      if (mounted) {
        _message(_tr(
          'சுயவிவரப் படத்தைச் சேமிக்க முடியவில்லை.',
          'Could not save the profile photo.',
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
        'format': 'loantrack-backup',
        'version': 3,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'loans': _loans.map((loan) => loan.toJson()).toList(),
        'savings': _savings.map((entry) => entry.toJson()).toList(),
        'profile': {
          'name': _profileName,
          'phone': _profilePhone,
          'imageBase64': _profileImageBase64,
        },
        'preferences': {
          'language': _language,
          'darkMode': _darkMode,
          'notifications': _notificationsEnabled,
        },
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
                final rawSavings = decoded is Map ? decoded['savings'] : null;
                final rawProfile = decoded is Map ? decoded['profile'] : null;
                final rawPreferences =
                    decoded is Map ? decoded['preferences'] : null;
                if (rawLoans is! List) {
                  throw const FormatException('Backup does not contain loans.');
                }
                final restoredLoans = rawLoans.map((item) {
                  if (item is! Map) {
                    throw const FormatException('Invalid loan record.');
                  }
                  return Loan.fromJson(Map<String, Object?>.from(item));
                }).toList();
                final restoredSavings = rawSavings == null
                    ? _savings
                    : rawSavings is List
                        ? rawSavings.map((item) {
                            if (item is! Map) {
                              throw const FormatException(
                                  'Invalid savings record.');
                            }
                            return SavingsEntry.fromJson(
                              Map<String, Object?>.from(item),
                            );
                          }).toList()
                        : throw const FormatException(
                            'Backup savings are invalid.');
                _validateRestoredData(restoredLoans, restoredSavings);
                final restoredProfile = _parseBackupProfile(rawProfile);
                final restoredPreferences =
                    _parseBackupPreferences(rawPreferences);
                if (!dialogContext.mounted) return;
                final confirmed = await showDialog<bool>(
                  context: dialogContext,
                  builder: (confirmContext) => AlertDialog(
                    title: Text(_tr('தரவை மீட்டமைக்கவா?', 'Restore backup?')),
                    content: Text(_tr(
                      '${restoredLoans.length} கடன் பதிவுகளும் ${restoredSavings.length} சேமிப்பு பதிவுகளும் மீட்டமைக்கப்படும்.',
                      '${restoredLoans.length} loan records and ${restoredSavings.length} savings records will be restored.',
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
                final loansSaved = await _saveLoans(restoredLoans);
                final savingsSaved = await _saveSavings(restoredSavings);
                if (!loansSaved || !savingsSaved) return;
                await _restoreBackupPreferences(
                  restoredProfile,
                  restoredPreferences,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) {
                  _message(_tr(
                    'காப்புப் பிரதி மீட்டமைக்கப்பட்டது.',
                    'Backup restored successfully.',
                  ));
                }
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

  void _validateRestoredData(
    List<Loan> loans,
    List<SavingsEntry> savings,
  ) {
    if (loans.length > 10000 || savings.length > 10000) {
      throw const FormatException('Backup contains too many records.');
    }
    final loanIds = <String>{};
    final paymentIds = <String>{};
    for (final loan in loans) {
      if (!loanIds.add(loan.id)) {
        throw const FormatException('Backup contains duplicate loan IDs.');
      }
      if (loan.payments.length > 50000) {
        throw const FormatException('A loan contains too many payments.');
      }
      for (final payment in loan.payments) {
        if (!paymentIds.add(payment.id)) {
          throw const FormatException('Backup contains duplicate payment IDs.');
        }
      }
    }
    final savingsIds = <String>{};
    for (final entry in savings) {
      if (!savingsIds.add(entry.id)) {
        throw const FormatException('Backup contains duplicate savings IDs.');
      }
    }
  }

  Map<String, String?>? _parseBackupProfile(Object? raw) {
    if (raw == null) return null;
    if (raw is! Map) throw const FormatException('Backup profile is invalid.');
    final name = raw['name'];
    final phone = raw['phone'];
    final image = raw['imageBase64'];
    if (name is! String ||
        phone is! String ||
        name.length > 100 ||
        phone.length > 30 ||
        (image != null && image is! String)) {
      throw const FormatException('Backup profile is invalid.');
    }
    if (image is String) {
      if (image.length > 1300000 || base64Decode(image).length > 900000) {
        throw const FormatException('Backup profile photo is too large.');
      }
    }
    return {
      'name': name.trim(),
      'phone': phone.trim(),
      'image': image as String?
    };
  }

  Map<String, Object?>? _parseBackupPreferences(Object? raw) {
    if (raw == null) return null;
    if (raw is! Map) {
      throw const FormatException('Backup preferences are invalid.');
    }
    final language = raw['language'];
    final darkMode = raw['darkMode'];
    final notifications = raw['notifications'];
    if ((language != 'ta' && language != 'en') ||
        darkMode is! bool ||
        notifications is! bool) {
      throw const FormatException('Backup preferences are invalid.');
    }
    return {
      'language': language,
      'darkMode': darkMode,
      'notifications': notifications,
    };
  }

  Future<void> _restoreBackupPreferences(
    Map<String, String?>? profile,
    Map<String, Object?>? preferences,
  ) async {
    if (profile == null && preferences == null) return;
    final store = await SharedPreferences.getInstance();
    if (profile != null) {
      await store.setString(_nameKey, profile['name'] ?? '');
      await store.setString(_phoneKey, profile['phone'] ?? '');
      final image = profile['image'];
      if (image == null) {
        await store.remove(_profileImageKey);
      } else {
        await store.setString(_profileImageKey, image);
      }
    }
    if (preferences != null) {
      await store.setString(_languageKey, preferences['language']! as String);
      await store.setBool(_themeKey, preferences['darkMode']! as bool);
      await store.setBool(
        _notificationsKey,
        preferences['notifications']! as bool,
      );
    }
    if (!mounted) return;
    setState(() {
      if (profile != null) {
        _profileName = profile['name'] ?? '';
        _profilePhone = profile['phone'] ?? '';
        _profileImageBase64 = profile['image'];
      }
      if (preferences != null) {
        _language = preferences['language']! as String;
        _darkMode = preferences['darkMode']! as bool;
        _notificationsEnabled = preferences['notifications']! as bool;
      }
    });
    await LoanNotificationService.instance.sync(
      loans: _loans,
      enabled: _notificationsEnabled,
      isTamil: _isTamil,
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = Locale(_language);
    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xff7b2cf3),
      brightness: _darkMode ? Brightness.dark : Brightness.light,
      surface: _darkMode ? const Color(0xff171020) : Colors.white,
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
            _darkMode ? const Color(0xff100b18) : const Color(0xfff8f6fc),
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
                      savings: _savings,
                      isTamil: _isTamil,
                      darkMode: _darkMode,
                      profileName: _profileName,
                      profilePhone: _profilePhone,
                      profileImageBase64: _profileImageBase64,
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
                      onAddSavings: _addSavings,
                      onEditSavings: _editSavings,
                      onDeleteSavings: _deleteSavings,
                      onDetails: (context, loan) => showLoanDetailsPage(
                        context,
                        loan: loan,
                        isTamil: _isTamil,
                        onPayment: () => _addPayment(loan),
                        onSharePdf: () => _shareLoanPdf(loan),
                        onDeletePayment: (payment) =>
                            _deletePayment(loan, payment),
                      ),
                      onLanguageChanged: _changeLanguage,
                      onThemeChanged: _changeTheme,
                      onProfileSaved: _saveProfile,
                      onProfileImageChanged: _saveProfileImage,
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
