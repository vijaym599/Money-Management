import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'collection_models.dart';

class CollectionLoanFormPage extends StatefulWidget {
  const CollectionLoanFormPage({required this.isTamil, super.key});

  final bool isTamil;

  @override
  State<CollectionLoanFormPage> createState() => _CollectionLoanFormPageState();
}

class _CollectionLoanFormPageState extends State<CollectionLoanFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _person = TextEditingController();
  final _phone = TextEditingController();
  final _principal = TextEditingController();
  final _rate = TextEditingController(text: '1');
  final _tenure = TextEditingController(text: '12');
  final _note = TextEditingController();
  String _direction = 'given';
  String _typeKey = 'monthly_interest';
  String _ratePeriod = 'monthly';
  late DateTime _startDate;
  late DateTime _firstDueDate;

  String _tr(String ta, String en) => widget.isTamil ? ta : en;

  CollectionLoanType get _type => collectionTypeFromKey(_typeKey);

  bool get _isEmi => _type.isEmi;

  bool get _isWeekly => _type.isWeekly;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _firstDueDate = _defaultFirstDue(_startDate);
  }

  @override
  void dispose() {
    _person.dispose();
    _phone.dispose();
    _principal.dispose();
    _rate.dispose();
    _tenure.dispose();
    _note.dispose();
    super.dispose();
  }

  DateTime _defaultFirstDue(DateTime start) =>
      _isWeekly ? start.add(const Duration(days: 7)) : _addMonths(start, 1);

  static DateTime _addMonths(DateTime date, int months) {
    final target = DateTime(date.year, date.month + months, 1);
    final lastDay = DateTime(target.year, target.month + 1, 0).day;
    return DateTime(target.year, target.month, math.min(date.day, lastDay));
  }

  void _changeType(String key) {
    final previous = _type;
    setState(() {
      _typeKey = key;
      if (_isWeekly != previous.isWeekly) {
        _firstDueDate = _defaultFirstDue(_startDate);
      }
    });
  }

  Future<void> _pickStartDate() async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year, today.month, today.day),
    );
    if (selected == null) return;
    setState(() {
      _startDate = selected;
      _firstDueDate = _defaultFirstDue(selected);
    });
  }

  Future<void> _pickFirstDueDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate:
          _firstDueDate.isBefore(_startDate) ? _startDate : _firstDueDate,
      firstDate: _startDate,
      lastDate: DateTime(DateTime.now().year + 50, 12, 31),
    );
    if (selected != null) setState(() => _firstDueDate = selected);
  }

  double? get _previewPrincipal => double.tryParse(_principal.text.trim());

  double? get _previewRate => double.tryParse(_rate.text.trim());

  int? get _previewTenure => int.tryParse(_tenure.text.trim());

  CollectionLoan? get _previewLoan {
    final principal = _previewPrincipal;
    final rate = _previewRate;
    if (principal == null || !principal.isFinite || principal <= 0) return null;
    if (rate == null || !rate.isFinite || rate < 0 || rate > 100) return null;
    final tenure = _isEmi ? (_previewTenure ?? 0) : 0;
    if (_isEmi && (tenure < 1 || tenure > 5200)) return null;
    return CollectionLoan(
      id: 'preview',
      direction: _direction,
      person: _person.text.trim().isEmpty ? 'Preview' : _person.text.trim(),
      phone: _phone.text.trim(),
      principal: principal,
      rate: rate,
      ratePeriod: _ratePeriod,
      type: _type,
      startDate: _startDate,
      firstDueDate: _firstDueDate,
      tenureInstallments: tenure,
      note: _note.text.trim(),
    );
  }

  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty
          ? _tr('$label தேவை', 'Enter $label')
          : null;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (!_firstDueDate.isAfter(_startDate)) {
      _message(_tr(
        'முதல் வசூல் தேதி தொடக்க தேதிக்குப் பிறகு இருக்க வேண்டும்.',
        'First collection date must be after the start date.',
      ));
      return;
    }
    final principal = double.parse(_principal.text.trim());
    final rate = double.parse(_rate.text.trim());
    final tenure = _isEmi ? int.parse(_tenure.text.trim()) : 0;
    final loan = CollectionLoan(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      direction: _direction,
      person: _person.text.trim(),
      phone: _phone.text.trim(),
      principal: principal,
      rate: rate,
      ratePeriod: _ratePeriod,
      type: _type,
      startDate: _startDate,
      firstDueDate: _firstDueDate,
      tenureInstallments: tenure,
      note: _note.text.trim(),
    );
    Navigator.pop(context, loan);
  }

  void _message(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  String _typeLabel(CollectionLoanType type) => switch (type) {
        CollectionLoanType.monthlyInterestOnly =>
          _tr('மாதாந்திர வட்டி மட்டும்', 'Monthly interest only'),
        CollectionLoanType.weeklyInterestOnly =>
          _tr('வாராந்திர வட்டி மட்டும்', 'Weekly interest only'),
        CollectionLoanType.monthlyEmi => _tr('மாதாந்திர EMI', 'Monthly EMI'),
        CollectionLoanType.weeklyEmi => _tr('வாராந்திர EMI', 'Weekly EMI'),
      };

  String _ratePeriodLabel(String value) => switch (value) {
        'weekly' => _tr('வாரத்திற்கு', 'Weekly'),
        'annual' => _tr('ஆண்டுக்கு', 'Annual'),
        _ => _tr('மாதத்திற்கு', 'Monthly'),
      };

  String _money(double value) => NumberFormat.currency(
        locale: 'en_IN',
        symbol: '₹',
        decimalDigits: value % 1 == 0 ? 0 : 2,
      ).format(value);

  Widget _previewCard(BuildContext context) {
    final loan = _previewLoan;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_graph_rounded, size: 20),
                const SizedBox(width: 8),
                Text(
                  _tr('கணக்கு முன்னோட்டம்', 'Calculation preview'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (loan == null)
              Text(
                _tr(
                  'முதல்தொகை மற்றும் வட்டி விகிதத்தை உள்ளிட்டால் கணக்கு காட்டப்படும்.',
                  'Enter the principal and interest rate to preview the schedule.',
                ),
              )
            else ...[
              _previewRow(
                _tr('வசூல் வகை', 'Collection type'),
                _typeLabel(loan.type),
              ),
              _previewRow(
                _tr('கால வட்டி விகிதம்', 'Periodic rate'),
                '${_plain(loan.periodicRatePercent)}%',
              ),
              if (!loan.isEmi)
                _previewRow(
                  _tr('முதல் வட்டி', 'First interest'),
                  _money(loan.periodFor(1).expectedInterest),
                )
              else ...[
                _previewRow(
                  _tr('தவணைத் தொகை', 'Instalment amount'),
                  _money(loan.emiSchedule.isEmpty
                      ? 0
                      : loan.emiSchedule.first.expectedTotal),
                ),
                _previewRow(
                  _tr('மொத்த வட்டி', 'Total interest'),
                  _money(loan.totalScheduledInterest),
                ),
                _previewRow(
                  _tr('மொத்த திருப்பிச் செலுத்தல்', 'Total repayment'),
                  _money(loan.totalScheduledRepayment),
                ),
              ],
              _previewRow(
                _tr('அடுத்த வசூல் தேதி', 'Next collection date'),
                DateFormat('dd MMM yyyy').format(loan.firstDueDate),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _plain(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  Widget _previewRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(_tr('புதிய வசூல் கடன்', 'New collection loan')),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
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
                        onSelectionChanged: (value) =>
                            setState(() => _direction = value.first),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _person,
                        maxLength: 70,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText:
                              _tr('கடன் வாங்கியவர் பெயர்', 'Borrower name'),
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                        ),
                        validator: (value) =>
                            _required(value, _tr('பெயர்', 'Name')),
                      ),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        maxLength: 18,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9+\- ]'),
                          ),
                        ],
                        decoration: InputDecoration(
                          labelText: _tr(
                            'மொபைல் எண் (விருப்பம்)',
                            'Mobile number (optional)',
                          ),
                          hintText: '+91 98765 43210',
                          prefixIcon: const Icon(Icons.phone_outlined),
                        ),
                        validator: (value) {
                          final text = (value ?? '').trim();
                          if (text.isEmpty) return null;
                          final digits = text.replaceAll(RegExp(r'\D'), '');
                          if (digits.length < 10 || digits.length > 15) {
                            return _tr(
                              'சரியான மொபைல் எண்ணை உள்ளிடவும்',
                              'Enter a valid mobile number',
                            );
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        initialValue: _typeKey,
                        decoration: InputDecoration(
                          labelText: _tr('வசூல் வகை', 'Collection type'),
                          prefixIcon: const Icon(Icons.event_repeat_rounded),
                        ),
                        items: CollectionLoanType.values
                            .map(
                              (type) => DropdownMenuItem(
                                value: type.key,
                                child: Text(_typeLabel(type)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) _changeType(value);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _principal,
                        onChanged: (_) => setState(() {}),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: _tr('அசல் தொகை (₹)', 'Loan principal (₹)'),
                          prefixIcon: const Icon(Icons.currency_rupee_rounded),
                        ),
                        validator: (value) {
                          final number = double.tryParse((value ?? '').trim());
                          if (number == null ||
                              !number.isFinite ||
                              number <= 0) {
                            return _tr(
                              'சரியான தொகையை உள்ளிடவும்',
                              'Enter a valid amount',
                            );
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _rate,
                              onChanged: (_) => setState(() {}),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText: _tr(
                                    'வட்டி விகிதம் (%)', 'Interest rate (%)'),
                              ),
                              validator: (value) {
                                final number =
                                    double.tryParse((value ?? '').trim());
                                if (number == null ||
                                    !number.isFinite ||
                                    number < 0 ||
                                    number > 100) {
                                  return _tr(
                                    '0 முதல் 100 வரை உள்ளிடவும்',
                                    'Enter a value from 0 to 100',
                                  );
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _ratePeriod,
                              decoration: InputDecoration(
                                labelText: _tr(
                                  'வட்டி காலம்',
                                  'Rate period',
                                ),
                              ),
                              items: const ['weekly', 'monthly', 'annual']
                                  .map(
                                    (period) => DropdownMenuItem(
                                      value: period,
                                      child: Text(_ratePeriodLabel(period)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _ratePeriod = value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _tr(
                          'விகிதம் தானாக வார/மாத காலத்திற்கு மாற்றப்படும்.',
                          'The rate is converted automatically to the weekly or monthly collection period.',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (_isEmi) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _tenure,
                          onChanged: (_) => setState(() {}),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: _isWeekly
                                ? _tr(
                                    'தவணைகள் (வாரங்கள்)',
                                    'Number of instalments (weeks)',
                                  )
                                : _tr(
                                    'தவணைகள் (மாதங்கள்)',
                                    'Number of instalments (months)',
                                  ),
                            prefixIcon: const Icon(Icons.timeline_rounded),
                          ),
                          validator: (value) {
                            final number = int.tryParse((value ?? '').trim());
                            if (number == null || number < 1 || number > 5200) {
                              return _tr(
                                '1 முதல் 5200 வரை உள்ளிடவும்',
                                'Enter a value from 1 to 5200',
                              );
                            }
                            return null;
                          },
                        ),
                      ],
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_month_rounded),
                        title: Text(_tr('கடன் தொடக்க தேதி', 'Loan start date')),
                        subtitle: Text(
                          MaterialLocalizations.of(context)
                              .formatMediumDate(_startDate),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _pickStartDate,
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_available_rounded),
                        title: Text(
                          _tr('முதல் வசூல் தேதி', 'First payment due date'),
                        ),
                        subtitle: Text(
                          MaterialLocalizations.of(context)
                              .formatMediumDate(_firstDueDate),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _pickFirstDueDate,
                      ),
                      const SizedBox(height: 4),
                      Card(
                        child: ExpansionTile(
                          leading: const Icon(Icons.notes_rounded),
                          title: Text(_tr('குறிப்பு', 'Note')),
                          childrenPadding:
                              const EdgeInsets.fromLTRB(14, 0, 14, 14),
                          children: [
                            TextFormField(
                              controller: _note,
                              maxLength: 160,
                              minLines: 1,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: _tr(
                                  'விருப்பக் குறிப்பு',
                                  'Optional note',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _previewCard(context),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(_tr('ரத்து', 'Cancel')),
                          ),
                          const SizedBox(width: 10),
                          FilledButton.icon(
                            onPressed: _submit,
                            icon: const Icon(Icons.save_rounded),
                            label: Text(_tr('சேமி', 'Save')),
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

class CollectionPaymentDialog extends StatefulWidget {
  const CollectionPaymentDialog({
    required this.loan,
    required this.isTamil,
    super.key,
  });

  final CollectionLoan loan;
  final bool isTamil;

  @override
  State<CollectionPaymentDialog> createState() =>
      _CollectionPaymentDialogState();
}

class _CollectionPaymentDialogState extends State<CollectionPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  late DateTime _date;
  late String _category;
  late int? _periodNumber;

  CollectionLoan get _loan => widget.loan;

  String _tr(String ta, String en) => widget.isTamil ? ta : en;

  List<CollectionPeriod> get _periods {
    final today = DateTime.now();
    final start = _loan.oldestUnpaidPeriod(dueOnly: false)?.number ?? 1;
    final result = <CollectionPeriod>[];
    final limit = _loan.isEmi ? _loan.tenureInstallments : start + 11;
    for (var number = start; number <= limit; number++) {
      if (number > _loan.tenureInstallments && _loan.isEmi) break;
      final period = _loan.periodFor(number);
      if (_loan.remainingForPeriod(number) > collectionTolerance) {
        result.add(period);
      }
      if (!_loan.isEmi && result.length >= 12) break;
    }
    if (result.isEmpty) {
      result.add(_loan.periodFor(start));
    }
    if (_loan.isEmi &&
        _loan.oldestUnpaidPeriod(today: today, dueOnly: true) == null) {
      return result;
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
    _category = _loan.isEmi ? 'emi' : 'interest';
    final next = _loan.oldestUnpaidPeriod(dueOnly: false);
    _periodNumber = next?.number ?? 1;
    _amount.text = _defaultAmount();
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  String _defaultAmount() {
    if (_loan.isEmi) {
      final number = _periodNumber ?? 1;
      return _plain(_loan.remainingForPeriod(number));
    }
    if (_category == 'principal') return _plain(_loan.outstandingPrincipal);
    final number = _periodNumber ?? 1;
    return _plain(_loan.remainingInterestForPeriod(number));
  }

  String _plain(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: _loan.startDate,
      lastDate: DateTime(DateTime.now().year + 5, 12, 31),
    );
    if (selected != null) setState(() => _date = selected);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amount.text.trim());
    final paymentId = DateTime.now().microsecondsSinceEpoch.toString();
    try {
      final updated = _loan.recordPayment(
        id: paymentId,
        amount: amount,
        date: _date,
        category: _category,
        periodNumber: _category == 'principal' ? null : _periodNumber,
      );
      Navigator.pop(context, updated.payments.last);
    } on ArgumentError catch (error) {
      _message(error.message?.toString() ??
          _tr('தொகை மீதமுள்ள அளவை விட அதிகம்.', 'Amount exceeds the balance.'));
    } on StateError catch (error) {
      _message(error.message);
    }
  }

  void _message(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  String _money(double value) => NumberFormat.currency(
        locale: 'en_IN',
        symbol: '₹',
        decimalDigits: value % 1 == 0 ? 0 : 2,
      ).format(value);

  String _categoryLabel(String value) => switch (value) {
        'interest' => _tr('வட்டி', 'Interest'),
        'principal' => _tr('அசல் திருப்பம்', 'Principal repayment'),
        'settlement' => _tr('தீர்வு', 'Settlement'),
        _ => _tr('EMI தவணை', 'EMI instalment'),
      };

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(
          _loan.isEmi
              ? _tr('EMI வசூல்', 'Collect EMI')
              : _tr('வட்டி வசூல்', 'Collect interest'),
        ),
        content: SizedBox(
          width: 420,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_loan.isEmi)
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'interest',
                          label: Text(_tr('வட்டி', 'Interest')),
                        ),
                        ButtonSegment(
                          value: 'principal',
                          label: Text(_tr('அசல்', 'Principal')),
                        ),
                      ],
                      selected: {_category},
                      onSelectionChanged: (value) {
                        setState(() {
                          _category = value.first;
                          _amount.text = _defaultAmount();
                        });
                      },
                    ),
                  if (_category != 'principal') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _periodNumber,
                      decoration: InputDecoration(
                        labelText: _loan.isEmi
                            ? _tr('EMI தவணை', 'EMI instalment')
                            : _tr('வட்டி காலம்', 'Interest period'),
                      ),
                      items: _periods
                          .map(
                            (period) => DropdownMenuItem(
                              value: period.number,
                              child: Text(
                                '${DateFormat('dd MMM yyyy').format(period.dueDate)} • ${_money(_loan.remainingForPeriod(period.number))}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _periodNumber = value;
                          _amount.text = _defaultAmount();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _tr(
                        'தேர்ந்தெடுத்த தவணைக்கு முழு அல்லது பகுதி தொகையை வசூலிக்கலாம். மீதமுள்ள தொகை அடுத்த தவணைக்கு செல்லும்.',
                        'Collect a full or partial amount. Any excess is applied to the next instalment.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: _tr('தொகை (₹)', 'Amount (₹)'),
                      prefixIcon: const Icon(Icons.currency_rupee_rounded),
                    ),
                    validator: (value) {
                      final number = double.tryParse((value ?? '').trim());
                      if (number == null || !number.isFinite || number <= 0) {
                        return _tr(
                          'சரியான தொகையை உள்ளிடவும்',
                          'Enter a valid amount',
                        );
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_month_rounded),
                    title: Text(_tr('செலுத்திய தேதி', 'Payment date')),
                    subtitle: Text(
                      MaterialLocalizations.of(context).formatMediumDate(_date),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _category == 'principal'
                        ? _tr(
                            'மீதமுள்ள அசல்: ${_money(_loan.outstandingPrincipal)}',
                            'Outstanding principal: ${_money(_loan.outstandingPrincipal)}',
                          )
                        : _tr(
                            'தேர்ந்தெடுத்த தவணை நிலுவை: ${_money(_loan.remainingForPeriod(_periodNumber ?? 1))}',
                            'Selected instalment balance: ${_money(_loan.remainingForPeriod(_periodNumber ?? 1))}',
                          ),
                    style: Theme.of(context).textTheme.bodySmall,
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
            child: Text(_categoryLabel(_category)),
          ),
        ],
      );
}
