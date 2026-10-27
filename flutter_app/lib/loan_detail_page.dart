import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'amount_privacy.dart';
import 'models.dart';

Future<void> showLoanDetailsPage(
  BuildContext context, {
  required Loan loan,
  required bool isTamil,
  required VoidCallback onPayment,
  required VoidCallback onSharePdf,
  required Future<bool> Function(LoanPayment payment) onDeletePayment,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => _LoanDetailsPage(
        loan: loan,
        isTamil: isTamil,
        onPayment: onPayment,
        onSharePdf: onSharePdf,
        onDeletePayment: onDeletePayment,
      ),
    ),
  );
}

class _LoanDetailsPage extends StatelessWidget {
  const _LoanDetailsPage({
    required this.loan,
    required this.isTamil,
    required this.onPayment,
    required this.onSharePdf,
    required this.onDeletePayment,
  });

  final Loan loan;
  final bool isTamil;
  final VoidCallback onPayment;
  final VoidCallback onSharePdf;
  final Future<bool> Function(LoanPayment payment) onDeletePayment;

  String _tr(String tamil, String english) => isTamil ? tamil : english;

  @override
  Widget build(BuildContext context) {
    String money(double value) => privateMoney(context, value);
    final now = DateTime.now();
    final overdueInterest = loan.overdueInterest(today: now);
    final accruedInterest = loan.accruedInterest(today: now);
    final months =
        loan.rate > 0 ? loan.monthsThrough(now).reversed.toList() : <String>[];
    final date = MaterialLocalizations.of(context);

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
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _SummaryHero(
                  loan: loan,
                  accruedInterest: accruedInterest,
                  overdueInterest: overdueInterest,
                  isTamil: isTamil,
                  money: money,
                ),
                const SizedBox(height: 14),
                if (loan.isClosed)
                  _SectionCard(
                    title: _tr('மூடப்பட்ட கடன்', 'Closed loan'),
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
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: onPayment,
                      icon: const Icon(Icons.add_card_rounded),
                      label: Text(_tr('செலுத்தல் பதிவு', 'Record payment')),
                    ),
                  ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: _tr('கணக்கு சுருக்கம்', 'Account summary'),
                  icon: Icons.account_balance_wallet_outlined,
                  rows: [
                    _InfoRow(
                      label: _tr('கடன் வகை', 'Loan type'),
                      value: _tr(
                        loan.direction == 'given'
                            ? 'கொடுத்த கடன்'
                            : 'வாங்கிய கடன்',
                        loan.direction == 'given' ? 'Lent' : 'Borrowed',
                      ),
                    ),
                    if (loan.phone.isNotEmpty)
                      _InfoRow(
                        label: _tr('தொடர்பு எண்', 'Contact number'),
                        value: loan.phone,
                        highlight: true,
                      ),
                    _InfoRow(
                      label: _tr('அசல் முதல்தொகை', 'Original principal'),
                      value: money(loan.principal),
                    ),
                    _InfoRow(
                      label: _tr('முதல்தொகை நிலுவை', 'Principal outstanding'),
                      value: money(loan.outstanding),
                    ),
                    if (loan.rate > 0) ...[
                      _InfoRow(
                        label: _tr(
                          'இன்றுவரை சேர்ந்த வட்டி',
                          'Interest accrued to date',
                        ),
                        value: money(accruedInterest),
                      ),
                      if (overdueInterest > .009)
                        _InfoRow(
                          label: _tr('காலாவதியான வட்டி', 'Interest overdue'),
                          value: money(overdueInterest),
                          danger: true,
                        ),
                      _InfoRow(
                        label: _tr('மாத வட்டி', 'Monthly interest'),
                        value:
                            '${loan.rate}%  •  ${money(loan.monthlyInterest)}',
                      ),
                      _InfoRow(
                        label: _tr('வட்டி செலுத்தும் நாள்', 'Interest due day'),
                        value: '${loan.dueDay}',
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: _tr('முக்கிய தேதிகள்', 'Important dates'),
                  icon: Icons.calendar_month_outlined,
                  rows: [
                    _InfoRow(
                      label: _tr('கடன் தேதி', 'Loan date'),
                      value: date.formatMediumDate(loan.startDate),
                    ),
                    if (loan.rate > 0)
                      _InfoRow(
                        label:
                            _tr('வட்டி தொடங்கும் தேதி', 'Interest start date'),
                        value: date.formatMediumDate(loan.interestStartDate),
                      ),
                    if (loan.rate > 0)
                      _InfoRow(
                        label: _tr('முதல் வட்டி தவணை', 'First interest due'),
                        value: date.formatMediumDate(loan.firstInterestDueDate),
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
                  _NoteCard(
                    title: _tr('குறிப்பு', 'Note'),
                    note: loan.note,
                  ),
                ],
                if (loan.hasInterestLedger) ...[
                  const SizedBox(height: 14),
                  _LedgerCard(
                    loan: loan,
                    months: months,
                    isTamil: isTamil,
                    money: money,
                  ),
                ],
                if (loan.payments.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _PaymentHistoryCard(
                    title: _tr('செலுக்கை வரலாறு', 'Payment history'),
                    payments: loan.payments.toList()
                      ..sort((a, b) => b.date.compareTo(a.date)),
                    isTamil: isTamil,
                    money: money,
                    canDelete: !loan.isClosed,
                    onDelete: onDeletePayment,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentHistoryCard extends StatelessWidget {
  const _PaymentHistoryCard({
    required this.title,
    required this.payments,
    required this.isTamil,
    required this.money,
    required this.canDelete,
    required this.onDelete,
  });

  final String title;
  final List<LoanPayment> payments;
  final bool isTamil;
  final String Function(double) money;
  final bool canDelete;
  final Future<bool> Function(LoanPayment payment) onDelete;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 8),
              child: _SectionTitle(title: title, icon: Icons.payments_outlined),
            ),
            for (final payment in payments)
              ListTile(
                leading: const Icon(Icons.check_circle_outline_rounded,
                    color: Color(0xFF16856F)),
                title: Text(money(payment.amount),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text([
                  payment.type == 'interest'
                      ? (isTamil ? 'வட்டி' : 'Interest')
                      : (isTamil ? 'முதல்தொகை' : 'Principal'),
                  if (payment.month != null) payment.month!,
                  MaterialLocalizations.of(context)
                      .formatMediumDate(payment.date),
                ].join(' • ')),
                trailing: canDelete
                    ? IconButton(
                        tooltip:
                            isTamil ? 'செலுத்தலை நீக்கு' : 'Delete payment',
                        onPressed: () async {
                          final deleted = await onDelete(payment);
                          if (deleted && context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                        icon: const Icon(Icons.delete_outline_rounded),
                      )
                    : null,
              ),
          ],
        ),
      );
}

class _SummaryHero extends StatelessWidget {
  const _SummaryHero({
    required this.loan,
    required this.accruedInterest,
    required this.overdueInterest,
    required this.isTamil,
    required this.money,
  });

  final Loan loan;
  final double accruedInterest;
  final double overdueInterest;
  final bool isTamil;
  final String Function(double) money;

  @override
  Widget build(BuildContext context) {
    final overdue = overdueInterest > .009;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            const Color(0xFF4A0799),
          ],
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
              _HeroPill(
                text: isTamil
                    ? (loan.direction == 'given'
                        ? 'கொடுத்த கடன்'
                        : 'வாங்கிய கடன்')
                    : (loan.direction == 'given' ? 'Lent' : 'Borrowed'),
              ),
              const Spacer(),
              if (overdue)
                _HeroPill(
                  text: isTamil ? 'நிலுவை' : 'Overdue',
                  warning: true,
                ),
            ],
          ),
          const SizedBox(height: 17),
          Text(
            isTamil ? 'இன்றைய மொத்த கணக்கு' : 'Settlement total today',
            style: TextStyle(color: Colors.white.withValues(alpha: .72)),
          ),
          const SizedBox(height: 3),
          Text(
            money(loan.outstanding + accruedInterest),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -.5,
            ),
          ),
          if (loan.rate > 0) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _HeroValue(
                    label: isTamil ? 'முதல்தொகை' : 'Principal',
                    value: money(loan.outstanding),
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
                    label: isTamil ? 'சேர்ந்த வட்டி' : 'Accrued interest',
                    value: money(accruedInterest),
                  ),
                ),
              ],
            ),
          ],
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
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: .68), fontSize: 11)),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
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
              _SectionTitle(title: title, icon: icon),
              const SizedBox(height: 6),
              ...rows,
            ],
          ),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 9),
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
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

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.title, required this.note});
  final String title;
  final String note;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(title: title, icon: Icons.notes_rounded),
              const SizedBox(height: 10),
              Text(note, style: const TextStyle(height: 1.45)),
            ],
          ),
        ),
      );
}

class _LedgerCard extends StatelessWidget {
  const _LedgerCard({
    required this.loan,
    required this.months,
    required this.isTamil,
    required this.money,
  });
  final Loan loan;
  final List<String> months;
  final bool isTamil;
  final String Function(double) money;

  String _tr(String tamil, String english) => isTamil ? tamil : english;

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
              child: _SectionTitle(
                title: _tr('மாதாந்திர வட்டி கணக்கு', 'Monthly interest ledger'),
                icon: Icons.table_rows_outlined,
              ),
            ),
            if (months.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(_tr('பதிவுகள் இல்லை', 'No entries yet')),
              )
            else ...[
              Container(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: .55),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                child: _LedgerRow(
                  month: _tr('மாதம்', 'Month'),
                  expected: _tr('வட்டி', 'Interest'),
                  remaining: _tr('மீதி', 'Balance'),
                  header: true,
                ),
              ),
              for (final month in months) _monthRow(context, month),
            ],
          ],
        ),
      );

  Widget _monthRow(BuildContext context, String month) {
    final status = loan.statusFor(month);
    final date = DateTime(
      int.parse(month.substring(0, 4)),
      int.parse(month.substring(5, 7)),
    );
    final color = status.remaining <= .009
        ? const Color(0xFF16856F)
        : status.isDue
            ? const Color(0xFFDC3C3C)
            : const Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        children: [
          _LedgerRow(
            month: DateFormat('MMM yyyy').format(date),
            expected: money(status.expected),
            remaining: money(status.remaining),
            color: color,
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(Icons.circle, size: 7, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  status.remaining <= .009
                      ? _tr('முழுமையாக செலுத்தப்பட்டது', 'Paid in full')
                      : status.isDue
                          ? _tr('செலுத்த வேண்டியது', 'Payment overdue')
                          : _tr('இன்னும் தவணை வரவில்லை', 'Not yet due'),
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${_tr('செலுத்தியது', 'Paid')}: ${money(status.paid)}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.month,
    required this.expected,
    required this.remaining,
    this.header = false,
    this.color,
  });
  final String month;
  final String expected;
  final String remaining;
  final bool header;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: header ? 11 : 13,
      fontWeight: header ? FontWeight.w700 : FontWeight.w600,
      color: header ? Theme.of(context).colorScheme.onSurfaceVariant : null,
    );
    return Row(
      children: [
        Expanded(flex: 4, child: Text(month, style: style)),
        Expanded(
          flex: 3,
          child: Text(expected, textAlign: TextAlign.end, style: style),
        ),
        Expanded(
          flex: 3,
          child: Text(
            remaining,
            textAlign: TextAlign.end,
            style: style.copyWith(color: header ? style.color : color),
          ),
        ),
      ],
    );
  }
}
