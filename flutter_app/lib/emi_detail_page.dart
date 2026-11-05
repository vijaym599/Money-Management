import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'amount_privacy.dart';
import 'emi_models.dart';

Future<void> showEmiLoanDetailsPage(
  BuildContext context, {
  required EmiLoan loan,
  required ValueListenable<List<EmiLoan>> emiLoansListenable,
  required bool isTamil,
  required VoidCallback onPayment,
  required VoidCallback onSharePdf,
  required Future<bool> Function(EmiPayment payment) onDeletePayment,
  required VoidCallback onClose,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => _EmiLoanDetailsPage(
        loan: loan,
        emiLoansListenable: emiLoansListenable,
        isTamil: isTamil,
        onPayment: onPayment,
        onSharePdf: onSharePdf,
        onDeletePayment: onDeletePayment,
        onClose: onClose,
      ),
    ),
  );
}

class _EmiLoanDetailsPage extends StatelessWidget {
  const _EmiLoanDetailsPage({
    required this.loan,
    required this.emiLoansListenable,
    required this.isTamil,
    required this.onPayment,
    required this.onSharePdf,
    required this.onDeletePayment,
    required this.onClose,
  });

  final EmiLoan loan;
  final ValueListenable<List<EmiLoan>> emiLoansListenable;
  final bool isTamil;
  final VoidCallback onPayment;
  final VoidCallback onSharePdf;
  final Future<bool> Function(EmiPayment payment) onDeletePayment;
  final VoidCallback onClose;

  String _tr(String ta, String en) => isTamil ? ta : en;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<List<EmiLoan>>(
        valueListenable: emiLoansListenable,
        builder: (context, loans, _) {
          final current = loans.firstWhere(
            (item) => item.id == loan.id,
            orElse: () => loan,
          );
          return _buildDetails(context, current);
        },
      );

  Widget _buildDetails(BuildContext context, EmiLoan loan) {
    String money(double value) => privateMoney(context, value);
    final date = MaterialLocalizations.of(context);
    final now = DateTime.now();
    final payments = [...loan.payments]
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: Text(loan.person),
        actions: [
          IconButton(
            tooltip: _tr('PDF பகிர்வு', 'Share PDF'),
            onPressed: onSharePdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _EmiSummaryHero(loan: loan, isTamil: isTamil, money: money),
                const SizedBox(height: 14),
                if (loan.isClosed)
                  _SectionCard(
                    title: _tr('மூடப்பட்ட EMI கடன்', 'Closed EMI loan'),
                    icon: Icons.inventory_2_outlined,
                    rows: [
                      _InfoRow(
                        label: _tr('மூடிய தேதி', 'Closed on'),
                        value: date.formatMediumDate(loan.closedAt!),
                        highlight: true,
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: loan.isSettled ? null : onPayment,
                            icon: const Icon(Icons.add_card_rounded),
                            label: Text(
                              _tr('EMI செலுத்தல் பதிவு', 'Record EMI payment'),
                            ),
                          ),
                        ),
                      ),
                      if (loan.canClose()) ...[
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: onClose,
                            icon: const Icon(Icons.task_alt_rounded),
                            label: Text(_tr('கடனை மூடு', 'Close loan')),
                          ),
                        ),
                      ],
                    ],
                  ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: _tr('EMI கணக்கு சுருக்கம்', 'EMI account summary'),
                  icon: Icons.account_balance_wallet_outlined,
                  rows: [
                    _InfoRow(
                      label: _tr('கடன் வகை', 'Loan type'),
                      value: loan.direction == 'given'
                          ? _tr('கொடுத்த கடன்', 'Lent')
                          : _tr('வாங்கிய கடன்', 'Borrowed'),
                    ),
                    if (loan.phone.isNotEmpty)
                      _InfoRow(
                        label: _tr('கைபேசி எண்', 'Mobile number'),
                        value: loan.phone,
                        highlight: true,
                      ),
                    _InfoRow(
                      label: _tr('வட்டி முறை', 'Interest method'),
                      value: loan.isReducing
                          ? _tr('குறையும் இருப்பு', 'Reducing balance')
                          : _tr('நிலையான வட்டி', 'Flat interest'),
                    ),
                    _InfoRow(
                      label: _tr('கடன் தொகை', 'Loan amount'),
                      value: money(loan.principal),
                    ),
                    _InfoRow(
                      label: _tr('மாத வட்டி', 'Monthly interest'),
                      value: '${loan.rate}%',
                    ),
                    _InfoRow(
                      label: _tr('கால அளவு', 'Tenure'),
                      value: isTamil
                          ? '${loan.tenureMonths} மாதங்கள்'
                          : '${loan.tenureMonths} months',
                    ),
                    _InfoRow(
                      label: _tr('மாத EMI', 'Monthly EMI'),
                      value: money(loan.monthlyEmi),
                      highlight: true,
                    ),
                    _InfoRow(
                      label: _tr('மொத்த வட்டி', 'Total interest'),
                      value: money(loan.totalInterest),
                    ),
                    _InfoRow(
                      label:
                          _tr('மொத்த திருப்பிச் செலுத்தல்', 'Total repayment'),
                      value: money(loan.totalRepayment),
                    ),
                    _InfoRow(
                      label: _tr('முதல்தொகை நிலுவை', 'Outstanding principal'),
                      value: money(loan.outstandingPrincipal),
                    ),
                    _InfoRow(
                      label: _tr('மொத்த நிலுவை', 'Outstanding balance'),
                      value: money(loan.outstandingBalance),
                      danger: loan.outstandingBalance > .009,
                    ),
                    _InfoRow(
                      label: _tr('செலுத்தியது', 'Collected'),
                      value: money(loan.totalPaid),
                    ),
                    _InfoRow(
                      label: _tr('வட்டி வருமானம்', 'Interest earned'),
                      value: money(loan.interestPaid),
                    ),
                    if (loan.overdueAmount(today: now) > .009)
                      _InfoRow(
                        label: _tr('தாமதமான தொகை', 'Overdue amount'),
                        value: money(loan.overdueAmount(today: now)),
                        danger: true,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: _tr('முக்கிய தேதிகள்', 'Important dates'),
                  icon: Icons.calendar_month_outlined,
                  rows: [
                    _InfoRow(
                      label: _tr('தொடக்க தேதி', 'Start date'),
                      value: date.formatMediumDate(loan.startDate),
                    ),
                    _InfoRow(
                      label: _tr('முதல் EMI தவணை', 'First EMI due date'),
                      value: date.formatMediumDate(loan.firstDueDate),
                    ),
                    if (loan.lastPaymentDate != null)
                      _InfoRow(
                        label: _tr('கடைசி செலுத்தல்', 'Last payment'),
                        value: date.formatMediumDate(loan.lastPaymentDate!),
                      ),
                  ],
                ),
                if (loan.note.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: _tr('குறிப்பு', 'Note'),
                    icon: Icons.notes_rounded,
                    rows: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(loan.note),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                _EmiScheduleCard(
                  loan: loan,
                  isTamil: isTamil,
                  money: money,
                ),
                const SizedBox(height: 14),
                _EmiPaymentHistoryCard(
                  payments: payments,
                  isTamil: isTamil,
                  money: money,
                  canDelete: !loan.isClosed,
                  onDelete: onDeletePayment,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension on EmiLoan {
  DateTime? get lastPaymentDate {
    if (payments.isEmpty) return null;
    return payments
        .map((payment) => payment.date)
        .reduce((latest, date) => date.isAfter(latest) ? date : latest);
  }
}

class _EmiSummaryHero extends StatelessWidget {
  const _EmiSummaryHero({
    required this.loan,
    required this.isTamil,
    required this.money,
  });

  final EmiLoan loan;
  final bool isTamil;
  final String Function(double) money;

  String _tr(String ta, String en) => isTamil ? ta : en;

  @override
  Widget build(BuildContext context) {
    final overdue = loan.overdueAmount() > .009;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: overdue
              ? [const Color(0xFFB3261E), const Color(0xFF7F1D1D)]
              : [const Color(0xFF7B2CF3), const Color(0xFF4A0799)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x337B2CF3),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _HeroPill(text: _tr('EMI கடன்', 'EMI loan')),
              const Spacer(),
              if (loan.isClosed)
                _HeroPill(text: _tr('மூடப்பட்டது', 'Closed'))
              else if (overdue)
                _HeroPill(text: _tr('தாமதம்', 'Overdue'), warning: true),
            ],
          ),
          const SizedBox(height: 17),
          Text(
            _tr('மொத்த நிலுவை', 'Outstanding balance'),
            style: TextStyle(color: Colors.white.withValues(alpha: .72)),
          ),
          const SizedBox(height: 3),
          Text(
            money(loan.outstandingBalance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _HeroValue(
                  label: _tr('மாத EMI', 'Monthly EMI'),
                  value: money(loan.monthlyEmi),
                ),
              ),
              Container(
                width: 1,
                height: 34,
                color: Colors.white.withValues(alpha: .25),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _HeroValue(
                  label: _tr('முதல்தொகை நிலுவை', 'Outstanding principal'),
                  value: money(loan.outstandingPrincipal),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.text, this.warning = false});

  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: warning
              ? const Color(0xFFFFE6E6)
              : Colors.white.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: warning ? const Color(0xFFC93636) : Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
      );
}

class _HeroValue extends StatelessWidget {
  const _HeroValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .68),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.rows,
  });

  final String title;
  final IconData icon;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 9),
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...rows,
            ],
          ),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.highlight = false,
    this.danger = false,
  });

  final String label;
  final String value;
  final bool highlight;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    Color? color;
    if (highlight) color = Theme.of(context).colorScheme.primary;
    if (danger) color = const Color(0xFFDC3C3C);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: .55),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmiScheduleCard extends StatelessWidget {
  const _EmiScheduleCard({
    required this.loan,
    required this.isTamil,
    required this.money,
  });

  final EmiLoan loan;
  final bool isTamil;
  final String Function(double) money;

  String _tr(String ta, String en) => isTamil ? ta : en;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.table_rows_outlined,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 9),
                  Text(
                    _tr('EMI தவணை அட்டவணை', 'EMI repayment schedule'),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            Container(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: .55),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      _tr('தவணை', 'No.'),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Text(
                      _tr('தேதி', 'Due date'),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      'EMI',
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      _tr('மீதம்', 'Balance'),
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
            for (final item in loan.schedule) _row(context, item),
          ],
        ),
      );

  Widget _row(BuildContext context, EmiInstallment item) {
    final status = loan.statusFor(item.number);
    final remaining = loan.remainingForInstallment(item.number);
    final color = switch (status) {
      EmiInstallmentStatus.paid => const Color(0xFF16856F),
      EmiInstallmentStatus.overdue => const Color(0xFFDC3C3C),
      EmiInstallmentStatus.partiallyPaid => const Color(0xFFF59E0B),
      EmiInstallmentStatus.pending => Theme.of(context).colorScheme.primary,
    };
    final label = switch (status) {
      EmiInstallmentStatus.paid => _tr('செலுத்தியது', 'Paid'),
      EmiInstallmentStatus.overdue => _tr('தாமதம்', 'Overdue'),
      EmiInstallmentStatus.partiallyPaid =>
        _tr('பகுதி செலுத்தியது', 'Partially paid'),
      EmiInstallmentStatus.pending => _tr('நிலுவை', 'Pending'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  '#${item.number}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                flex: 5,
                child: Text(
                  DateFormat('d MMM yyyy', isTamil ? 'ta' : 'en')
                      .format(item.dueDate),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  money(item.emi),
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  money(remaining),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(Icons.circle, size: 7, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$label • ${_tr('முதல்', 'Principal')} ${money(item.principal)} • ${_tr('வட்டி', 'Interest')} ${money(item.interest)}',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${_tr('செலுத்தியது', 'Paid')}: '
                '${money(loan.paidForInstallment(item.number))}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmiPaymentHistoryCard extends StatelessWidget {
  const _EmiPaymentHistoryCard({
    required this.payments,
    required this.isTamil,
    required this.money,
    required this.canDelete,
    required this.onDelete,
  });

  final List<EmiPayment> payments;
  final bool isTamil;
  final String Function(double) money;
  final bool canDelete;
  final Future<bool> Function(EmiPayment payment) onDelete;

  String _tr(String ta, String en) => isTamil ? ta : en;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.payments_outlined,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 9),
                  Text(
                    _tr('EMI செலுத்தல் வரலாறு', 'EMI payment history'),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            if (payments.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_tr('பதிவுகள் இல்லை', 'No payments yet')),
                ),
              )
            else
              for (final payment in payments)
                ListTile(
                  leading: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Color(0xFF16856F),
                  ),
                  title: Text(
                    money(payment.amount),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    [
                      _tr(
                        'தவணை #${payment.installmentNumber}',
                        'Instalment #${payment.installmentNumber}',
                      ),
                      MaterialLocalizations.of(context)
                          .formatMediumDate(payment.date),
                    ].join(' • '),
                  ),
                  trailing: canDelete
                      ? IconButton(
                          tooltip:
                              isTamil ? 'செலுத்தலை நீக்கு' : 'Delete payment',
                          onPressed: () async {
                            await onDelete(payment);
                          },
                          icon: const Icon(Icons.delete_outline_rounded),
                        )
                      : null,
                ),
          ],
        ),
      );
}
