import 'package:flutter_test/flutter_test.dart';
import 'package:kadan_kanakku/emi_models.dart';

EmiLoan _loan({
  String interestMethod = 'reducing',
  List<EmiPayment> payments = const [],
  DateTime? closedAt,
}) =>
    EmiLoan(
      id: 'emi-test',
      direction: 'taken',
      person: 'Arun',
      phone: '9876543210',
      principal: 100000,
      rate: 1,
      tenureMonths: 12,
      startDate: DateTime(2026, 1, 1),
      firstDueDate: DateTime(2026, 2, 1),
      interestMethod: interestMethod,
      note: 'Test loan',
      payments: payments,
      closedAt: closedAt,
    );

void main() {
  test('reducing balance schedule settles the principal', () {
    final loan = _loan();

    expect(loan.schedule, hasLength(12));
    expect(loan.schedule.first.dueDate, DateTime(2026, 2, 1));
    expect(loan.schedule.last.dueDate, DateTime(2027, 1, 1));
    expect(loan.monthlyEmi, closeTo(8884.88, 0.05));
    expect(loan.totalInterest, closeTo(6618.55, 1));
    expect(
      loan.schedule.fold<double>(0, (sum, item) => sum + item.principal),
      closeTo(100000, 0.01),
    );
    expect(loan.schedule.last.closingPrincipal, 0);
  });

  test('flat interest schedule uses the selected method', () {
    final loan = _loan(interestMethod: 'flat');

    expect(loan.monthlyEmi, closeTo(9333.33, 0.02));
    expect(loan.totalInterest, closeTo(12000, 0.01));
    expect(
      loan.schedule.fold<double>(0, (sum, item) => sum + item.principal),
      closeTo(100000, 0.01),
    );
  });

  test('partial, advance and overdue states use the explicit date', () {
    final loan = _loan();
    final payment = EmiPayment(
      id: 'payment-1',
      amount: 500,
      date: DateTime(2026, 1, 15),
      installmentNumber: 1,
    );
    final partial = loan.withPayment(payment);
    final early = DateTime(2026, 1, 15);
    final overdueDay = DateTime(2026, 2, 15);

    expect(partial.paidForInstallment(1), 500);
    expect(
      partial.remainingForInstallment(1),
      closeTo(loan.schedule.first.emi - 500, 0.01),
    );
    expect(
      partial.statusFor(1, today: early),
      EmiInstallmentStatus.partiallyPaid,
    );
    expect(partial.isAdvancePaymentFor(1, today: early), isTrue);
    expect(
      partial.statusFor(1, today: overdueDay),
      EmiInstallmentStatus.overdue,
    );
    expect(partial.overdueCount(today: overdueDay), 1);
    expect(
      partial.overdueAmount(today: overdueDay),
      closeTo(loan.schedule.first.emi - 500, 0.01),
    );
    expect(
      loan.statusFor(3, today: overdueDay),
      EmiInstallmentStatus.pending,
    );
  });

  test('paying all instalments settles and closes the loan', () {
    var loan = _loan();
    for (final installment in loan.schedule) {
      loan = loan.withPayment(
        EmiPayment(
          id: 'payment-${installment.number}',
          amount: installment.emi,
          date: installment.dueDate,
          installmentNumber: installment.number,
        ),
      );
    }

    expect(loan.totalPaid, closeTo(loan.totalRepayment, 0.01));
    expect(loan.outstandingBalance, 0);
    expect(loan.outstandingPrincipal, 0);
    expect(loan.isSettled, isTrue);
    expect(loan.canClose(), isTrue);
    expect(loan.nextUnpaidInstallment, isNull);

    final closed = loan.close(DateTime(2027, 2, 1));
    expect(closed.isClosed, isTrue);
    expect(closed.canClose(), isFalse);
  });

  test('removing a payment restores the outstanding balance', () {
    final loan = _loan();
    final payment = EmiPayment(
      id: 'payment-1',
      amount: loan.schedule.first.emi,
      date: loan.schedule.first.dueDate,
      installmentNumber: 1,
    );
    final paid = loan.withPayment(payment);
    final restored = paid.withoutPayment(payment.id);

    expect(paid.remainingForInstallment(1), 0);
    expect(restored.remainingForInstallment(1), loan.schedule.first.emi);
    expect(restored.payments, isEmpty);
  });

  test('JSON round-trip preserves EMI loan data and validates records', () {
    final payment = EmiPayment(
      id: 'payment-1',
      amount: 1000,
      date: DateTime(2026, 2, 1),
      installmentNumber: 1,
    );
    final loan = _loan(payments: [payment]);
    final json = loan.toJson();
    final restored = EmiLoan.fromJson(json);

    expect(json['loanType'], 'emi');
    expect(restored.id, loan.id);
    expect(restored.person, loan.person);
    expect(restored.principal, loan.principal);
    expect(restored.monthlyEmi, loan.monthlyEmi);
    expect(restored.payments.single.id, payment.id);
    expect(restored.payments.single.installmentNumber, 1);

    expect(
      () => EmiLoan.fromJson({...json, 'rate': 101}),
      throwsFormatException,
    );
    expect(
      () => EmiLoan.fromJson({
        ...json,
        'payments': [
          {
            'id': 'too-large',
            'amount': loan.schedule.first.emi + 1,
            'date': '2026-02-01',
            'installmentNumber': 1,
          },
        ],
      }),
      throwsFormatException,
    );
  });
}
