import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'amount_privacy.dart';
import 'emi_models.dart';

class EmiLoanFormPage extends StatefulWidget {
  const EmiLoanFormPage({required this.isTamil, super.key});

  final bool isTamil;

  @override
  State<EmiLoanFormPage> createState() => _EmiLoanFormPageState();
}

class _EmiLoanFormPageState extends State<EmiLoanFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _person = TextEditingController();
  final _phone = TextEditingController();
  final _principal = TextEditingController();
  final _rate = TextEditingController(text: '1');
  final _tenure = TextEditingController(text: '12');
  final _note = TextEditingController();
  String _direction = 'given';
  String _method = 'reducing';
  DateTime _startDate = DateTime.now();
  DateTime _firstDueDate = _addMonths(DateTime.now(), 1);

  String _tr(String ta, String en) => widget.isTamil ? ta : en;

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

  static DateTime _addMonths(DateTime date, int months) {
    final target = DateTime(date.year, date.month + months, 1);
    final lastDay = DateTime(target.year, target.month + 1, 0).day;
    return DateTime(target.year, target.month, math.min(date.day, lastDay));
  }

  EmiLoan? get _preview {
    final principal = double.tryParse(_principal.text);
    final rate = double.tryParse(_rate.text);
    final tenure = int.tryParse(_tenure.text);
    if (principal == null ||
        principal <= 0 ||
        rate == null ||
        rate < 0 ||
        rate > 100 ||
        tenure == null ||
        tenure < 1 ||
        tenure > 600) {
      return null;
    }
    return EmiLoan(
      id: 'preview',
      direction: _direction,
      person: _person.text,
      phone: _phone.text,
      principal: principal,
      rate: rate,
      tenureMonths: tenure,
      startDate: _startDate,
      firstDueDate:
          _firstDueDate.isBefore(_startDate) ? _startDate : _firstDueDate,
      interestMethod: _method,
      note: '',
    );
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (selected == null) return;
    setState(() {
      _startDate = selected;
      if (_firstDueDate.isBefore(_startDate)) {
        _firstDueDate = _addMonths(_startDate, 1);
      }
    });
  }

  Future<void> _pickFirstDueDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate:
          _firstDueDate.isBefore(_startDate) ? _startDate : _firstDueDate,
      firstDate: _startDate,
      lastDate: DateTime(now.year + 30, 12, 31),
    );
    if (selected != null) setState(() => _firstDueDate = selected);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_firstDueDate.isBefore(_startDate)) {
      _message(_tr(
        'முதல் EMI தேதி கடன் தொடக்க தேதிக்குப் பிறகு இருக்க வேண்டும்.',
        'The first EMI due date must be on or after the start date.',
      ));
      return;
    }
    Navigator.pop(
      context,
      EmiLoan(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        direction: _direction,
        person: _person.text.trim(),
        phone: _phone.text.trim(),
        principal: double.parse(_principal.text),
        rate: double.parse(_rate.text),
        tenureMonths: int.parse(_tenure.text),
        startDate: _startDate,
        firstDueDate: _firstDueDate,
        interestMethod: _method,
        note: _note.text.trim(),
      ),
    );
  }

  void _message(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty
          ? _tr('$label நிரப்பவும்', 'Enter $label')
          : null;

  Widget _previewCard(BuildContext context) {
    final loan = _preview;
    if (loan == null) return const SizedBox.shrink();
    String money(double value) => privateMoney(context, value);
    return Container(
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
                  _tr('EMI முன்னோட்டம்', 'EMI preview'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          _previewRow(
            context,
            _tr('மாத EMI', 'Monthly EMI'),
            money(loan.monthlyEmi),
            strong: true,
          ),
          _previewRow(
            context,
            _tr('மொத்த வட்டி', 'Total interest'),
            money(loan.totalInterest),
          ),
          _previewRow(
            context,
            _tr('மொத்த திருப்பிச் செலுத்தல்', 'Total repayment'),
            money(loan.totalRepayment),
          ),
          _previewRow(
            context,
            _tr('முதல் தவணை', 'First instalment'),
            DateFormat('d MMM yyyy', widget.isTamil ? 'ta' : 'en')
                .format(loan.schedule.first.dueDate),
          ),
        ],
      ),
    );
  }

  Widget _previewRow(
    BuildContext context,
    String label,
    String value, {
    bool strong = false,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
                fontSize: strong ? 17 : 14,
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(_tr('புதிய EMI கடன்', 'New EMI loan')),
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
                        ),
                        validator: (value) =>
                            _required(value, _tr('பெயரை', 'name')),
                      ),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        maxLength: 18,
                        decoration: InputDecoration(
                          labelText: _tr('கைபேசி எண்', 'Mobile number'),
                          hintText: '+91 98765 43210',
                          prefixIcon: const Icon(Icons.phone_outlined),
                        ),
                        validator: (value) {
                          final digits =
                              (value ?? '').replaceAll(RegExp(r'\D'), '');
                          if (digits.length < 10 || digits.length > 15) {
                            return _tr(
                              'சரியான கைபேசி எண்ணை உள்ளிடவும்',
                              'Enter a valid mobile number',
                            );
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: _principal,
                        onChanged: (_) => setState(() {}),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: _tr('கடன் தொகை (₹)', 'Loan amount (₹)'),
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
                      Row(
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
                                  'மாத வட்டி (%)',
                                  'Monthly interest rate (%)',
                                ),
                              ),
                              validator: (value) {
                                final number = double.tryParse(value ?? '');
                                if (number == null ||
                                    !number.isFinite ||
                                    number < 0 ||
                                    number > 100) {
                                  return _tr(
                                      '0 முதல் 100 வரை', 'Enter 0 to 100');
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _tenure,
                              onChanged: (_) => setState(() {}),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: _tr(
                                  'கால அளவு (மாதங்கள்)',
                                  'Tenure (months)',
                                ),
                              ),
                              validator: (value) {
                                final number = int.tryParse(value ?? '');
                                if (number == null ||
                                    number < 1 ||
                                    number > 600) {
                                  return _tr(
                                      '1 முதல் 600 வரை', 'Enter 1 to 600');
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _tr('வட்டி கணக்கீட்டு முறை', 'Interest calculation'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                            value: 'reducing',
                            label: Text(_tr(
                              'குறையும் இருப்பு',
                              'Reducing balance',
                            )),
                          ),
                          ButtonSegment(
                            value: 'flat',
                            label: Text(_tr('நிலையான வட்டி', 'Flat interest')),
                          ),
                        ],
                        selected: {_method},
                        onSelectionChanged: (value) =>
                            setState(() => _method = value.first),
                      ),
                      const SizedBox(height: 10),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_tr('தொடக்க தேதி', 'Start date')),
                        subtitle: Text(
                          MaterialLocalizations.of(context)
                              .formatMediumDate(_startDate),
                        ),
                        trailing: const Icon(Icons.calendar_month),
                        onTap: _pickStartDate,
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_tr(
                          'முதல் EMI தவணை தேதி',
                          'First EMI due date',
                        )),
                        subtitle: Text(
                          MaterialLocalizations.of(context)
                              .formatMediumDate(_firstDueDate),
                        ),
                        trailing: const Icon(Icons.event_available_outlined),
                        onTap: _pickFirstDueDate,
                      ),
                      TextFormField(
                        controller: _note,
                        maxLength: 120,
                        minLines: 1,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText:
                              _tr('குறிப்பு (விருப்பம்)', 'Note (optional)'),
                          prefixIcon: const Icon(Icons.notes_rounded),
                        ),
                      ),
                      const SizedBox(height: 8),
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
                          FilledButton(
                            onPressed: _submit,
                            child:
                                Text(_tr('EMI கடனைச் சேமி', 'Save EMI loan')),
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

class EmiPaymentDialog extends StatefulWidget {
  const EmiPaymentDialog({
    required this.loan,
    required this.isTamil,
    super.key,
  });

  final EmiLoan loan;
  final bool isTamil;

  @override
  State<EmiPaymentDialog> createState() => _EmiPaymentDialogState();
}

class _EmiPaymentDialogState extends State<EmiPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  late int _installmentNumber;
  late DateTime _paymentDate;

  EmiLoan get _loan => widget.loan;

  String _tr(String ta, String en) => widget.isTamil ? ta : en;

  List<EmiInstallment> get _unpaid => _loan.schedule
      .where((item) => _loan.remainingForInstallment(item.number) > 0.009)
      .toList();

  @override
  void initState() {
    super.initState();
    _paymentDate = DateTime.now();
    final overdue = _loan.oldestOverdueInstallment;
    _installmentNumber =
        (overdue ?? _loan.nextUnpaidInstallment ?? _loan.schedule.first).number;
    _amount.text =
        _loan.remainingForInstallment(_installmentNumber).toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  String _statusLabel(EmiInstallmentStatus status) => switch (status) {
        EmiInstallmentStatus.paid => _tr('செலுத்தியது', 'Paid'),
        EmiInstallmentStatus.partiallyPaid =>
          _tr('பகுதி செலுத்தியது', 'Partially paid'),
        EmiInstallmentStatus.overdue => _tr('தாமதம்', 'Overdue'),
        EmiInstallmentStatus.pending => _tr('நிலுவை', 'Pending'),
      };

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      EmiPayment(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        amount: double.parse(_amount.text),
        date: _paymentDate,
        installmentNumber: _installmentNumber,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _loan.remainingForInstallment(_installmentNumber);
    final installment = _loan.schedule[_installmentNumber - 1];
    final status = _loan.statusFor(_installmentNumber);
    final dueLabel =
        MaterialLocalizations.of(context).formatMediumDate(installment.dueDate);
    return AlertDialog(
      title: Text(
        _tr('${_loan.person} · EMI செலுத்தல்', '${_loan.person} · EMI payment'),
      ),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_unpaid.isEmpty)
                  Text(_tr(
                    'அனைத்து EMI தவணைகளும் செலுத்தப்பட்டுவிட்டன.',
                    'All EMI instalments are already paid.',
                  ))
                else ...[
                  DropdownButtonFormField<int>(
                    initialValue: _installmentNumber,
                    decoration: InputDecoration(
                      labelText: _tr('EMI தவணை', 'EMI instalment'),
                    ),
                    items: _unpaid
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.number,
                            child: Text(
                              '#${item.number} • '
                              '${MaterialLocalizations.of(context).formatMediumDate(item.dueDate)} • '
                              '${_money(context, _loan.remainingForInstallment(item.number))}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _installmentNumber = value;
                        _amount.text = _loan
                            .remainingForInstallment(value)
                            .toStringAsFixed(
                              2,
                            );
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _tr(
                            'தவணை #$_installmentNumber • $dueLabel • ${_statusLabel(status)}',
                            'Instalment #$_installmentNumber • $dueLabel • ${_statusLabel(status)}',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _tr(
                            'முதல் ${_money(context, installment.principal)} • வட்டி ${_money(context, installment.interest)}',
                            'Principal ${_money(context, installment.principal)} • Interest ${_money(context, installment.interest)}',
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _tr(
                            'மீதம் ${_money(context, remaining)}',
                            'Remaining ${_money(context, remaining)}',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: _tr('தொகை (₹)', 'Amount (₹)'),
                      helperText: _tr(
                        'அதிகபட்சம் ${remaining.toStringAsFixed(2)}',
                        'Maximum ${remaining.toStringAsFixed(2)}',
                      ),
                    ),
                    validator: (value) {
                      final amount = double.tryParse(value ?? '');
                      if (amount == null ||
                          !amount.isFinite ||
                          amount <= 0 ||
                          amount > remaining + 0.009) {
                        return _tr(
                          'இந்த தவணையின் மீதத் தொகைக்குள் உள்ளிடவும்',
                          'Enter an amount within this instalment balance',
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
                    subtitle: Text(
                      MaterialLocalizations.of(context)
                          .formatMediumDate(_paymentDate),
                    ),
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
                        setState(() => _paymentDate = selected);
                      }
                    },
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
        if (_unpaid.isNotEmpty)
          FilledButton(
            onPressed: _submit,
            child: Text(_tr('பதிவு செய்', 'Record')),
          ),
      ],
    );
  }
}

String _money(BuildContext context, double value) =>
    privateMoney(context, value);
