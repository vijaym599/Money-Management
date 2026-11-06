import 'package:flutter_test/flutter_test.dart';
import 'package:kadan_kanakku/collection_models.dart';

CollectionLoan _loan({
  CollectionLoanType type = CollectionLoanType.monthlyInterestOnly,
  double principal = 10000,
  double rate = 2,
  String ratePeriod = 'monthly',
  int tenureInstallments = 0,
  DateTime? firstDueDate,
  List<CollectionPayment> payments = const [],
  DateTime? closedAt,
}) =>
    CollectionLoan(
      id: 'collection-test',
      direction: 'given',
      person: 'Meena',
      phone: '9876543210',
      principal: principal,
      rate: rate,
      ratePeriod: ratePeriod,
      type: type,
      startDate: DateTime(2026, 1, 1),
      firstDueDate: firstDueDate ??
          (type.isWeekly ? DateTime(2026, 1, 8) : DateTime(2026, 2, 1)),
      tenureInstallments: tenureInstallments,
      note: 'Test collection',
      payments: payments,
      closedAt: closedAt,
    );

void main() {
  test('monthly interest only builds periods and tracks partial payments', () {
    final loan = _loan();
    final first = loan.periodFor(1);
    final partial = loan.recordPayment(
      id: 'partial-1',
      amount: 100,
      date: DateTime(2026, 1, 15),
      category: 'interest',
    );

    expect(first.startDate, DateTime(2026, 1, 1));
    expect(first.dueDate, DateTime(2026, 2, 1));
    expect(first.expectedInterest, 200);
    expect(partial.paidForPeriod(1), 100);
    expect(partial.remainingForPeriod(1), 100);
    expect(
      partial.statusForPeriod(1, today: DateTime(2026, 1, 15)),
      CollectionPeriodStatus.partiallyPaid,
    );
    expect(
      partial.isAdvancePaymentFor(1, today: DateTime(2026, 1, 15)),
      isTrue,
    );
    expect(
      partial.statusForPeriod(1, today: DateTime(2026, 2, 2)),
      CollectionPeriodStatus.overdue,
    );
    expect(partial.overdueAmount(today: DateTime(2026, 2, 2)), 100);
    expect(partial.overdueCount(today: DateTime(2026, 2, 2)), 1);
  });

  test('principal repayment reduces future interest-only periods', () {
    final loan = _loan();
    final reduced = loan.recordPayment(
      id: 'principal-1',
      amount: 2000,
      date: DateTime(2026, 1, 15),
      category: 'principal',
    );

    expect(reduced.outstandingPrincipal, 8000);
    expect(reduced.periodFor(1).expectedInterest, 200);
    expect(reduced.periodFor(2).expectedInterest, 160);
    expect(reduced.totalCollectedPrincipal, 2000);
  });

  test('weekly interest only uses seven-day periods', () {
    final loan = _loan(
      type: CollectionLoanType.weeklyInterestOnly,
      rate: 1,
      ratePeriod: 'weekly',
    );
    final schedule = loan.scheduleThrough(DateTime(2026, 1, 22));

    expect(schedule, hasLength(3));
    expect(schedule[0].dueDate, DateTime(2026, 1, 8));
    expect(schedule[1].dueDate, DateTime(2026, 1, 15));
    expect(schedule[2].dueDate, DateTime(2026, 1, 22));
    expect(schedule[0].expectedInterest, 100);
    expect(schedule[1].startDate, DateTime(2026, 1, 9));
  });

  test('monthly EMI reducing schedule settles the principal', () {
    final loan = _loan(
      type: CollectionLoanType.monthlyEmi,
      principal: 100000,
      rate: 1,
      tenureInstallments: 12,
    );

    expect(loan.emiSchedule, hasLength(12));
    expect(loan.emiSchedule.first.expectedInterest, 1000);
    expect(loan.emiSchedule.first.expectedTotal, closeTo(8884.88, 0.02));
    expect(loan.emiSchedule.last.dueDate, DateTime(2027, 1, 1));
    expect(
      loan.emiSchedule.fold<double>(
        0,
        (sum, item) => sum + item.expectedPrincipal,
      ),
      closeTo(100000, 0.02),
    );
    expect(loan.emiSchedule.last.openingPrincipal, lessThan(9000));
    expect(loan.totalScheduledRepayment, greaterThan(100000));
  });

  test('weekly EMI schedule pays instalments and closes', () {
    var loan = _loan(
      type: CollectionLoanType.weeklyEmi,
      rate: 1,
      ratePeriod: 'weekly',
      tenureInstallments: 8,
    );

    expect(loan.emiSchedule, hasLength(8));
    expect(loan.emiSchedule[0].dueDate, DateTime(2026, 1, 8));
    expect(loan.emiSchedule[1].dueDate, DateTime(2026, 1, 15));

    for (final item in loan.emiSchedule) {
      loan = loan.recordPayment(
        id: 'emi-${item.number}',
        amount: item.expectedTotal,
        date: item.dueDate,
        category: 'emi',
      );
    }

    expect(loan.totalCollected, closeTo(loan.totalScheduledRepayment, 0.02));
    expect(loan.outstandingBalance, 0);
    expect(loan.outstandingPrincipal, 0);
    expect(loan.isSettled, isTrue);
    expect(loan.canClose(), isTrue);
    expect(loan.nextUnpaidPeriod, isNull);

    final closed = loan.close(DateTime(2026, 3, 1));
    expect(closed.isClosed, isTrue);
    expect(closed.canClose(), isFalse);
  });

  test('interest-only settlement closes the loan', () {
    final loan = _loan(
      type: CollectionLoanType.weeklyInterestOnly,
      rate: 1,
      ratePeriod: 'weekly',
      firstDueDate: DateTime(2026, 1, 8),
    );
    final settled = loan
        .settle(id: 'settlement-1', date: DateTime(2026, 1, 10))
        .close(DateTime(2026, 1, 10));

    expect(settled.outstandingPrincipal, 0);
    expect(settled.settlementOutstanding(today: DateTime(2026, 1, 10)), 0);
    expect(settled.payments.single.category, 'settlement');
    expect(settled.isClosed, isTrue);
  });

  test('payment validation rejects invalid amounts and categories', () {
    final loan = _loan();

    expect(
      () => loan.recordPayment(
        id: 'too-much',
        amount: 201,
        date: DateTime(2026, 1, 15),
        category: 'interest',
      ),
      throwsArgumentError,
    );
    expect(
      () => loan.recordPayment(
        id: 'before-start',
        amount: 10,
        date: DateTime(2025, 12, 31),
        category: 'interest',
      ),
      throwsArgumentError,
    );
    expect(
      () => loan.recordPayment(
        id: 'emi-on-interest',
        amount: 10,
        date: DateTime(2026, 1, 15),
        category: 'emi',
      ),
      throwsArgumentError,
    );
    final closed = loan
        .recordPayment(
          id: 'closed-loan',
          amount: 10,
          date: DateTime(2026, 1, 15),
          category: 'interest',
        )
        .close(DateTime(2026, 1, 15));
    expect(
      () => closed.recordPayment(
        id: 'after-close',
        amount: 10,
        date: DateTime(2026, 1, 16),
        category: 'interest',
      ),
      throwsStateError,
    );
  });

  test('JSON round-trip preserves collections and validates records', () {
    final loan = _loan(
      type: CollectionLoanType.weeklyEmi,
      rate: 1,
      ratePeriod: 'weekly',
      tenureInstallments: 8,
    );
    final paid = loan.recordPayment(
      id: 'emi-1',
      amount: loan.emiSchedule.first.expectedTotal,
      date: loan.emiSchedule.first.dueDate,
      category: 'emi',
    );
    final json = paid.toJson();
    final restored = CollectionLoan.fromJson(json);

    expect(json['loanType'], 'collection');
    expect(json['collectionType'], 'weekly_emi');
    expect(restored.id, paid.id);
    expect(restored.type, CollectionLoanType.weeklyEmi);
    expect(restored.tenureInstallments, 8);
    expect(restored.emiSchedule, hasLength(8));
    expect(restored.payments.single.id, 'emi-1');
    expect(restored.remainingForPeriod(1), 0);

    expect(
      () => CollectionLoan.fromJson({
        ...json,
        'collectionType': 'daily_interest',
      }),
      throwsFormatException,
    );
    expect(
      () => CollectionLoan.fromJson({...json, 'rate': 101}),
      throwsFormatException,
    );
    expect(
      () => CollectionLoan.fromJson({...json, 'tenureInstallments': 0}),
      throwsFormatException,
    );
    expect(
      () => CollectionLoan.fromJson({
        ...json,
        'payments': [
          paid.payments.single.toJson(),
          paid.payments.single.toJson(),
        ],
      }),
      throwsFormatException,
    );
  });
}
