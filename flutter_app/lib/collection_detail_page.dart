import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'amount_privacy.dart';
import 'collection_models.dart';

Future<void> showCollectionDetailsPage(
  BuildContext context, {
  required CollectionLoan loan,
  required ValueListenable<List<CollectionLoan>> collectionLoansListenable,
  required bool isTamil,
  required VoidCallback onPayment,
  required VoidCallback onSharePdf,
  required Future<bool> Function(CollectionPayment payment) onDeletePayment,
  required Future<bool> Function() onSettle,
  required Future<bool> Function() onDelete,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => _CollectionLoanDetailsPage(
        loan: loan,
        collectionLoansListenable: collectionLoansListenable,
        isTamil: isTamil,
        onPayment: onPayment,
        onSharePdf: onSharePdf,
        onDeletePayment: onDeletePayment,
        onSettle: onSettle,
        onDelete: onDelete,
      ),
    ),
  );
}

class _CollectionLoanDetailsPage extends StatelessWidget {
  const _CollectionLoanDetailsPage({
    required this.loan,
    required this.collectionLoansListenable,
    required this.isTamil,
    required this.onPayment,
    required this.onSharePdf,
    required this.onDeletePayment,
    required this.onSettle,
    required this.onDelete,
  });

  final CollectionLoan loan;
  final ValueListenable<List<CollectionLoan>> collectionLoansListenable;
  final bool isTamil;
  final VoidCallback onPayment;
  final VoidCallback onSharePdf;
  final Future<bool> Function(CollectionPayment payment) onDeletePayment;
  final Future<bool> Function() onSettle;
  final Future<bool> Function() onDelete;

  String _tr(String ta, String en) => isTamil ? ta : en;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<List<CollectionLoan>>(
        valueListenable: collectionLoansListenable,
        builder: (context, loans, _) {
          final current = loans.firstWhere(
            (item) => item.id == loan.id,
            orElse: () => loan,
          );
          return _buildDetails(context, current);
        },
      );

  Widget _buildDetails(BuildContext context, CollectionLoan loan) {
    String money(double value) => privateMoney(context, value);
    final now = DateTime.now();
    final date = MaterialLocalizations.of(context);
    final periods = _displayPeriods(loan, now);
    final payments = [...loan.payments]
      ..sort((a, b) => b.date.compareTo(a.date));
    final overdue = loan.overdueAmount(today: now);
    final next = loan.nextUnpaidPeriod;

    return Scaffold(
      appBar: AppBar(
        title: Text(loan.person),
        actions: [
          IconButton(
            tooltip: _tr('PDF பகிர்வு', 'Share PDF'),
            onPressed: onSharePdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          if (loan.isClosed)
            IconButton(
              tooltip: _tr('நீக்கு', 'Delete'),
              onPressed: () async {
                final deleted = await onDelete();
                if (deleted && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _CollectionSummaryHero(loan: loan, isTamil: isTamil),
                const SizedBox(height: 14),
                if (loan.isClosed)
                  _InfoCard(
                    title:
                        _tr('மூடப்பட்ட வசூல் கடன்', 'Closed collection loan'),
                    icon: Icons.inventory_2_outlined,
                    rows: [
                      _InfoRow(
                        label: _tr('மூடிய தேதி', 'Closed on'),
                        value: date.formatMediumDate(loan.closedAt!),
                        highlight: true,
                      ),
                      _InfoRow(
                        label: _tr('மொத்தம் வசூலித்தது', 'Total collected'),
                        value: money(loan.totalCollected),
                        highlight: true,
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: FilledButton.icon(
                            onPressed: onPayment,
                            icon: const Icon(Icons.payments_rounded),
                            label: Text(
                              _tr('வசூல் பதிவு', 'Record collection'),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: onSettle,
                          icon: const Icon(Icons.done_all_rounded),
                          label: Text(_tr('தீர்த்து மூடு', 'Settle & close')),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 14),
                _InfoCard(
                  title: _tr('கணக்கு சுருக்கம்', 'Account summary'),
                  icon: Icons.account_balance_wallet_outlined,
                  rows: [
                    _InfoRow(
                      label: _tr('வசூல் வகை', 'Collection type'),
                      value: _collectionTypeText(loan),
                    ),
                    _InfoRow(
                      label: _tr('கடன் திசை', 'Loan direction'),
                      value: loan.direction == 'given'
                          ? _tr('நான் கொடுத்தது', 'I lent')
                          : _tr('நான் வாங்கியது', 'I borrowed'),
                    ),
                    if (loan.phone.isNotEmpty)
                      _InfoRow(
                        label: _tr('மொபைல் எண்', 'Mobile number'),
                        value: loan.phone,
                        highlight: true,
                      ),
                    _InfoRow(
                      label: _tr('முதல்தொகை', 'Principal'),
                      value: money(loan.principal),
                    ),
                    _InfoRow(
                      label: _tr('வட்டி விகிதம்', 'Interest rate'),
                      value:
                          '${_plain(loan.rate)}% ${_ratePeriodText(loan.ratePeriod)}',
                    ),
                    _InfoRow(
                      label: _tr('கால வட்டி விகிதம்', 'Periodic rate'),
                      value: '${_plain(loan.periodicRatePercent)}%',
                    ),
                    if (loan.isEmi)
                      _InfoRow(
                        label: _tr('தவணைகள்', 'Instalments'),
                        value: '${loan.tenureInstallments}',
                      ),
                    _InfoRow(
                      label: _tr('தொடக்க தேதி', 'Start date'),
                      value: date.formatMediumDate(loan.startDate),
                    ),
                    _InfoRow(
                      label: _tr('முதல் வசூல் தேதி', 'First collection date'),
                      value: date.formatMediumDate(loan.firstDueDate),
                    ),
                    _InfoRow(
                      label: _tr('வசூலித்த வட்டி', 'Collected interest'),
                      value: money(loan.totalCollectedInterest),
                    ),
                    _InfoRow(
                      label: _tr('வசூலித்த அசல்', 'Collected principal'),
                      value: money(loan.totalCollectedPrincipal),
                    ),
                    _InfoRow(
                      label: _tr('நிலுவை அசல்', 'Outstanding principal'),
                      value: money(loan.outstandingPrincipal),
                    ),
                    _InfoRow(
                      label: _tr('நிலுவை வட்டி', 'Pending interest'),
                      value: money(loan.pendingInterest(today: now)),
                    ),
                    if (overdue > .009)
                      _InfoRow(
                        label: _tr('தாமதத் தொகை', 'Overdue amount'),
                        value: money(overdue),
                        highlight: true,
                        color: const Color(0xFFEF5350),
                      ),
                    _InfoRow(
                      label: _tr('மொத்த நிலுவை', 'Total outstanding'),
                      value: money(loan.settlementOutstanding(today: now)),
                      highlight: true,
                    ),
                    if (loan.isEmi) ...[
                      _InfoRow(
                        label: _tr('மொத்த வட்டி', 'Total interest'),
                        value: money(loan.totalScheduledInterest),
                      ),
                      _InfoRow(
                        label: _tr(
                            'மொத்த திருப்பிச் செலுத்தல்', 'Total repayment'),
                        value: money(loan.totalScheduledRepayment),
                      ),
                    ],
                    if (next != null)
                      _InfoRow(
                        label: _tr('அடுத்த வசூல்', 'Next collection'),
                        value:
                            '${date.formatMediumDate(next.dueDate)} • ${money(loan.remainingForPeriod(next.number))}',
                        highlight: true,
                      ),
                    if (loan.note.isNotEmpty)
                      _InfoRow(
                        label: _tr('குறிப்பு', 'Note'),
                        value: loan.note,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                _InfoCard(
                  title: _tr('வசூல் அட்டவணை', 'Collection schedule'),
                  icon: Icons.event_note_outlined,
                  rows: const [],
                  child: Column(
                    children: [
                      for (var index = 0; index < periods.length; index++) ...[
                        _CollectionPeriodTile(
                          loan: loan,
                          period: periods[index],
                          isTamil: isTamil,
                          today: now,
                          money: money,
                        ),
                        if (index < periods.length - 1)
                          const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _InfoCard(
                  title: _tr('செலுத்தல் வரலாறு', 'Payment history'),
                  icon: Icons.history_rounded,
                  rows: const [],
                  child: payments.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            _tr('இன்னும் செலுத்தல் இல்லை.',
                                'No payments recorded yet.'),
                          ),
                        )
                      : Column(
                          children: [
                            for (var index = 0;
                                index < payments.length;
                                index++) ...[
                              _CollectionPaymentTile(
                                payment: payments[index],
                                isTamil: isTamil,
                                isClosed: loan.isClosed,
                                money: money,
                                onDelete: () => onDeletePayment(
                                  payments[index],
                                ),
                              ),
                              if (index < payments.length - 1)
                                const Divider(height: 1),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<CollectionPeriod> _displayPeriods(
    CollectionLoan loan,
    DateTime now,
  ) {
    if (loan.isEmi) return loan.emiSchedule;
    final periods = loan.scheduleThrough(now, extra: 6);
    if (periods.length <= 36) return periods;
    final oldest = loan.oldestUnpaidPeriod(today: now, dueOnly: true);
    final start = oldest == null
        ? periods.length - 24
        : periods.indexWhere((item) => item.number == oldest.number);
    final from = start < 0 ? periods.length - 24 : start;
    final safeFrom =
        from < 0 ? 0 : (from > periods.length ? periods.length : from);
    return periods.sublist(safeFrom);
  }

  String _plain(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  String _ratePeriodText(String value) => switch (value) {
        'weekly' => _tr('வாரத்திற்கு', 'per week'),
        'annual' => _tr('ஆண்டுக்கு', 'per year'),
        _ => _tr('மாதத்திற்கு', 'per month'),
      };

  String _collectionTypeText(CollectionLoan loan) {
    if (loan.isEmi) {
      if (loan.isWeekly) return _tr('வாராந்திர EMI', 'Weekly EMI');
      return _tr('மாதாந்திர EMI', 'Monthly EMI');
    }
    if (loan.isWeekly) {
      return _tr('வாராந்திர வட்டி', 'Weekly interest');
    }
    return _tr('மாதாந்திர வட்டி', 'Monthly interest');
  }
}

class _CollectionSummaryHero extends StatelessWidget {
  const _CollectionSummaryHero({required this.loan, required this.isTamil});

  final CollectionLoan loan;
  final bool isTamil;

  String _tr(String ta, String en) => isTamil ? ta : en;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final outstanding = loan.settlementOutstanding(today: now);
    final collected = loan.totalCollected;
    final total = outstanding + collected;
    final progress =
        total <= .009 ? 1.0 : (collected / total).clamp(0.0, 1.0).toDouble();
    final accent = loan.direction == 'given'
        ? const Color(0xFF1769FF)
        : const Color(0xFFF59E0B);
    String money(double value) => privateMoney(context, value);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            accent,
            Color.lerp(accent, Colors.black, .28) ?? accent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: .28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loan.isClosed
                          ? _tr('மூடப்பட்டது', 'Closed')
                          : _tr('மொத்த நிலுவை', 'Total outstanding'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      money(outstanding),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  loan.isEmi
                      ? (loan.isWeekly
                          ? _tr('வார EMI', 'Weekly EMI')
                          : _tr('மாத EMI', 'Monthly EMI'))
                      : (loan.isWeekly
                          ? _tr('வார வட்டி', 'Weekly interest')
                          : _tr('மாத வட்டி', 'Monthly interest')),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: .22),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HeroAmount(
                  label: _tr('வசூலித்தது', 'Collected'),
                  value: money(collected),
                ),
              ),
              Expanded(
                child: _HeroAmount(
                  label: _tr('அசல்', 'Principal'),
                  value: money(loan.principal),
                ),
              ),
              Expanded(
                child: _HeroAmount(
                  label: _tr('தாமதம்', 'Overdue'),
                  value: money(loan.overdueAmount(today: now)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            loan.isClosed
                ? _tr(
                    'மூடப்பட்டது ${DateFormat('dd MMM yyyy').format(loan.closedAt!)}',
                    'Closed ${DateFormat('dd MMM yyyy').format(loan.closedAt!)}',
                  )
                : (loan.phone.isEmpty
                    ? (loan.isEmi
                        ? (loan.isWeekly
                            ? _tr('வாராந்திர EMI', 'Weekly EMI')
                            : _tr('மாதாந்திர EMI', 'Monthly EMI'))
                        : (loan.isWeekly
                            ? _tr('வாராந்திர வட்டி', 'Weekly interest')
                            : _tr('மாதாந்திர வட்டி', 'Monthly interest')))
                    : loan.phone),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _HeroAmount extends StatelessWidget {
  const _HeroAmount({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.icon,
    required this.rows,
    this.child,
  });

  final String title;
  final IconData icon;
  final List<_InfoRow> rows;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
              if (rows.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (final row in rows) row,
              ],
              if (child != null) ...[
                const SizedBox(height: 8),
                child!,
              ],
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
    this.color,
  });

  final String label;
  final String value;
  final bool highlight;
  final Color? color;

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
                style: TextStyle(
                  fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      );
}

class _CollectionPeriodTile extends StatelessWidget {
  const _CollectionPeriodTile({
    required this.loan,
    required this.period,
    required this.isTamil,
    required this.today,
    required this.money,
  });

  final CollectionLoan loan;
  final CollectionPeriod period;
  final bool isTamil;
  final DateTime today;
  final String Function(double) money;

  String _tr(String ta, String en) => isTamil ? ta : en;

  @override
  Widget build(BuildContext context) {
    final status = loan.statusForPeriod(period.number, today: today);
    final remaining = loan.remainingForPeriod(period.number);
    final color = switch (status) {
      CollectionPeriodStatus.paid => const Color(0xFF16A34A),
      CollectionPeriodStatus.partiallyPaid => const Color(0xFFF59E0B),
      CollectionPeriodStatus.overdue => const Color(0xFFEF5350),
      CollectionPeriodStatus.pending => Theme.of(context).colorScheme.outline,
    };
    final label = switch (status) {
      CollectionPeriodStatus.paid => _tr('செலுத்தியது', 'Paid'),
      CollectionPeriodStatus.partiallyPaid => _tr('பகுதி', 'Partial'),
      CollectionPeriodStatus.overdue => _tr('தாமதம்', 'Overdue'),
      CollectionPeriodStatus.pending => _tr('நிலுவை', 'Pending'),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${period.number}',
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('dd MMM yyyy').format(period.dueDate),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  loan.isEmi
                      ? _tr(
                          'வட்டி ${money(period.expectedInterest)} • அசல் ${money(period.expectedPrincipal)}',
                          'Interest ${money(period.expectedInterest)} • Principal ${money(period.expectedPrincipal)}',
                        )
                      : _tr(
                          'வட்டி ${money(period.expectedInterest)}',
                          'Interest ${money(period.expectedInterest)}',
                        ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                remaining <= .009 ? _tr('முடிந்தது', 'Done') : money(remaining),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CollectionPaymentTile extends StatelessWidget {
  const _CollectionPaymentTile({
    required this.payment,
    required this.isTamil,
    required this.isClosed,
    required this.money,
    required this.onDelete,
  });

  final CollectionPayment payment;
  final bool isTamil;
  final bool isClosed;
  final String Function(double) money;
  final Future<bool> Function() onDelete;

  String _tr(String ta, String en) => isTamil ? ta : en;

  @override
  Widget build(BuildContext context) {
    final category = switch (payment.category) {
      'interest' => _tr('வட்டி', 'Interest'),
      'principal' => _tr('அசல்', 'Principal'),
      'settlement' => _tr('தீர்வு', 'Settlement'),
      _ => _tr('EMI', 'EMI'),
    };
    final allocations = payment.allocations
        .map(
          (item) =>
              '${item.periodNumber == null ? _tr('அசல்', 'Principal') : '#${item.periodNumber}'} • '
              '${money(item.total)}',
        )
        .join('  ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      DateFormat('dd MMM yyyy').format(payment.date),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    Text(category),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _tr(
                    'வட்டி ${money(payment.interestComponent)} • அசல் ${money(payment.principalComponent)}',
                    'Interest ${money(payment.interestComponent)} • Principal ${money(payment.principalComponent)}',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  allocations,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                money(payment.amount),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (!isClosed)
                IconButton(
                  tooltip: _tr('நீக்கு', 'Delete'),
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
