import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'models.dart';

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
    _firstInterestDueDate =
        loan?.firstInterestDueDate ?? _dueDateFor(_interestStartDate);
    if (loan == null) {
      _dueDay.text = _firstInterestDueDate.day.toString();
    }
  }

  String _plainNumber(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  DateTime _dueDateFor(DateTime start) {
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
        if (!_editing) {
          _interestStartDate = selected;
          _firstInterestDueDate = _dueDateFor(selected);
          _dueDay.text = _firstInterestDueDate.day.toString();
        } else {
          if (_interestStartDate.isBefore(selected)) {
            _interestStartDate = selected;
          }
          final minimumDue = _dueDateFor(_interestStartDate);
          if (_firstInterestDueDate.isBefore(minimumDue)) {
            _firstInterestDueDate = minimumDue;
          }
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
        final minimumDue = _dueDateFor(selected);
        if (_firstInterestDueDate.isBefore(minimumDue)) {
          _firstInterestDueDate = minimumDue;
        }
      });
    }
  }

  Future<void> _pickFirstInterestDueDate() async {
    final now = DateTime.now();
    final minimumDueDate = _dueDateFor(_interestStartDate);
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
    final dueDay =
        _editing ? int.parse(_dueDay.text) : _firstInterestDueDate.day;
    final minimumFirstDueDate = _dueDateFor(_interestStartDate);
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

  Widget _phoneField() => TextFormField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        maxLength: 18,
        decoration: InputDecoration(
          labelText:
              _tr('தொடர்பு எண் (விருப்பம்)', 'Contact number (optional)'),
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
      );

  Widget _noteField() => TextFormField(
        controller: _note,
        maxLength: 120,
        minLines: 1,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: _tr('குறிப்பு (விருப்பம்)', 'Note (optional)'),
          prefixIcon: const Icon(Icons.notes_rounded),
        ),
      );

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
                        if (_editing && _hasInterest) ...[
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
                      if (_editing && _hasInterest)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(_tr(
                              'வட்டி தொடங்கும் தேதி', 'Interest start date')),
                          subtitle: Text(MaterialLocalizations.of(context)
                              .formatMediumDate(_interestStartDate)),
                          trailing: const Icon(Icons.calendar_month),
                          onTap: _pickInterestStartDate,
                        ),
                      if (_editing && _hasInterest)
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
                      if (!_editing && _hasInterest)
                        _AutomaticScheduleCard(
                          isTamil: widget.isTamil,
                          loanDate: _loanDate,
                          dueDate: _firstInterestDueDate,
                        ),
                      const SizedBox(height: 10),
                      Card(
                        child: ExpansionTile(
                          initiallyExpanded:
                              _phone.text.isNotEmpty || _note.text.isNotEmpty,
                          leading: const Icon(Icons.tune_rounded),
                          title: Text(_tr(
                            'கூடுதல் விவரங்கள்',
                            'Optional details',
                          )),
                          subtitle: Text(_tr(
                            'தொடர்பு எண் மற்றும் குறிப்பு',
                            'Contact number and note',
                          )),
                          childrenPadding:
                              const EdgeInsets.fromLTRB(14, 4, 14, 14),
                          children: [
                            _phoneField(),
                            const SizedBox(height: 8),
                            _noteField(),
                          ],
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

class _AutomaticScheduleCard extends StatelessWidget {
  const _AutomaticScheduleCard({
    required this.isTamil,
    required this.loanDate,
    required this.dueDate,
  });

  final bool isTamil;
  final DateTime loanDate;
  final DateTime dueDate;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  isTamil ? 'தானியங்கி வட்டி அட்டவணை' : 'Automatic schedule',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'AUTO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: _ScheduleDate(
                  label: isTamil ? 'கடன் தேதி' : 'Loan date',
                  value: localizations.formatMediumDate(loanDate),
                  icon: Icons.calendar_today_outlined,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward_rounded, size: 18),
              ),
              Expanded(
                child: _ScheduleDate(
                  label: isTamil ? 'முதல் வட்டி தேதி' : 'First interest due',
                  value: localizations.formatMediumDate(dueDate),
                  icon: Icons.event_available_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isTamil
                ? 'ஒரு முழு மாத வட்டி காலம் முடிந்ததும் due date தானாக அமைக்கப்பட்டுள்ளது.'
                : 'The due date is set automatically after one complete interest month.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleDate extends StatelessWidget {
  const _ScheduleDate({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 5),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
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
