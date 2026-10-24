import 'package:flutter_test/flutter_test.dart';
import 'package:kadan_kanakku/main.dart';

void main() {
  group('Loan interest ledger', () {
    test('calculates month interest and unpaid balance', () {
      final loan = Loan(
        id: 'loan-1',
        direction: 'given',
        person: 'குமார்',
        principal: 50000,
        rate: 2,
        dueDay: 5,
        startDate: DateTime(2026, 7, 1),
        note: '',
        payments: [
          LoanPayment(
            id: 'payment-1',
            type: 'interest',
            amount: 300,
            date: DateTime(2026, 8, 8),
            month: '2026-08',
          ),
        ],
      );

      final status = loan.statusFor('2026-08');
      expect(status.expected, 1000);
      expect(status.paid, 300);
      expect(status.remaining, 700);
    });

    test('applies principal repayments to following months', () {
      final loan = Loan(
        id: 'loan-2',
        direction: 'given',
        person: 'மீனா',
        principal: 50000,
        rate: 2,
        dueDay: 5,
        startDate: DateTime(2026, 7, 1),
        note: '',
        payments: [
          LoanPayment(
            id: 'payment-2',
            type: 'principal',
            amount: 10000,
            date: DateTime(2026, 9, 1),
          ),
        ],
      );

      expect(loan.interestForMonth('2026-08'), 1000);
      expect(loan.interestForMonth('2026-09'), 800);
      expect(loan.outstanding, 40000);
    });

    test('does not apply a mid-month repayment until the next month', () {
      final loan = Loan(
        id: 'loan-4',
        direction: 'given',
        person: 'குமார்',
        principal: 50000,
        rate: 2,
        dueDay: 5,
        startDate: DateTime(2026, 7, 1),
        note: '',
        payments: [
          LoanPayment(
            id: 'payment-4',
            type: 'principal',
            amount: 10000,
            date: DateTime(2026, 9, 2),
          ),
        ],
      );

      expect(loan.interestForMonth('2026-09'), 1000);
      expect(loan.interestForMonth('2026-10'), 800);
    });

    test('clamps a due day to the last day of the month', () {
      final loan = Loan(
        id: 'loan-5',
        direction: 'given',
        person: 'மீனா',
        principal: 10000,
        rate: 1,
        dueDay: 31,
        startDate: DateTime(2026, 1, 1),
        note: '',
        payments: const [],
      );

      expect(
        loan.statusFor('2026-02', today: DateTime(2026, 3, 1)).dueDate,
        DateTime(2026, 2, 28),
      );
    });

    test('preserves payment date and interest month in storage data', () {
      final loan = Loan(
        id: 'loan-3',
        direction: 'taken',
        person: 'ரவி',
        principal: 10000,
        rate: 1,
        dueDay: 10,
        startDate: DateTime(2026, 1, 1),
        note: '',
        payments: [
          LoanPayment(
            id: 'payment-3',
            type: 'interest',
            amount: 100,
            date: DateTime(2026, 2, 12),
            month: '2026-02',
          ),
        ],
      );

      final restored = Loan.fromJson(loan.toJson());
      expect(restored.payments.single.month, '2026-02');
      expect(restored.payments.single.date, DateTime(2026, 2, 12));
    });

    test('totals every overdue month and selects the oldest first', () {
      final loan = Loan(
        id: 'loan-arrears',
        direction: 'taken',
        person: 'ரவி',
        principal: 10000,
        rate: 1,
        dueDay: 5,
        startDate: DateTime(2026, 7, 1),
        note: '',
        payments: const [],
      );

      final today = DateTime(2026, 10, 23);
      expect(loan.overdueInterest(today: today), 300);
      expect(loan.overdueMonthCount(today: today), 3);
      expect(loan.oldestUnpaidMonth(today: today, dueOnly: true), '2026-07');
    });

    test('rejects an imported principal overpayment', () {
      final json = <String, Object?>{
        'id': 'invalid-loan',
        'direction': 'given',
        'person': 'குமார்',
        'principal': 1000,
        'rate': 2,
        'dueDay': 5,
        'startDate': '2026-01-01',
        'note': '',
        'payments': <Object?>[
          <String, Object?>{
            'id': 'invalid-payment',
            'type': 'principal',
            'amount': 1100,
            'date': '2026-02-01',
            'month': null,
          },
        ],
      };

      expect(() => Loan.fromJson(json), throwsFormatException);
    });

    test('stores a WhatsApp number and loads older loans without one', () {
      final loan = Loan(
        id: 'loan-contact',
        direction: 'given',
        person: 'Kumar',
        principal: 5000,
        rate: 2,
        dueDay: 5,
        startDate: DateTime(2026, 10, 1),
        note: '',
        phone: '9876543210',
        payments: const [],
      );

      expect(Loan.fromJson(loan.toJson()).phone, '9876543210');

      final oldData = Map<String, Object?>.from(loan.toJson())..remove('phone');
      expect(Loan.fromJson(oldData).phone, isEmpty);
    });

    test('closes only a settled loan and preserves closure in storage', () {
      final principalPayment = LoanPayment(
        id: 'principal-settlement',
        type: 'principal',
        amount: 5000,
        date: DateTime(2026, 10, 20),
      );
      final active = Loan(
        id: 'loan-to-close',
        direction: 'given',
        person: 'Kumar',
        principal: 5000,
        rate: 0,
        dueDay: 5,
        startDate: DateTime(2026, 10, 1),
        note: '',
        payments: [principalPayment],
      );

      expect(active.canClose(today: DateTime(2026, 10, 20)), isTrue);
      final closed = active.copyWith(closedAt: DateTime(2026, 10, 20));
      final restored = Loan.fromJson(closed.toJson());

      expect(restored.isClosed, isTrue);
      expect(restored.closedAt, DateTime(2026, 10, 20));
      expect(restored.canClose(today: DateTime(2026, 10, 21)), isFalse);
      expect(restored.settlementOutstanding(today: DateTime(2027, 1, 1)), 0);
    });

    test('older loan data remains active when closedAt is absent', () {
      final active = Loan(
        id: 'legacy-active-loan',
        direction: 'given',
        person: 'Kumar',
        principal: 5000,
        rate: 0,
        dueDay: 5,
        startDate: DateTime(2026, 10, 1),
        note: '',
        payments: const [],
      );
      final oldData = Map<String, Object?>.from(active.toJson())
        ..remove('closedAt');

      expect(Loan.fromJson(oldData).isClosed, isFalse);
    });

    test('keeps old records compatible and uses a separate interest date', () {
      final oldData = <String, Object?>{
        'id': 'old-loan',
        'direction': 'given',
        'person': 'Kumar',
        'principal': 10000,
        'rate': 2,
        'dueDay': 5,
        'startDate': '2026-01-10',
        'note': '',
        'payments': <Object?>[],
      };

      final restoredOldLoan = Loan.fromJson(oldData);
      expect(restoredOldLoan.interestStartDate, DateTime(2026, 1, 10));
      expect(restoredOldLoan.firstInterestDueDate, DateTime(2026, 2, 9));

      final updatedLoan = Loan(
        id: 'new-loan',
        direction: 'given',
        person: 'Kumar',
        principal: 10000,
        rate: 2,
        dueDay: 5,
        startDate: DateTime(2026, 1, 10),
        interestStartDate: DateTime(2026, 3, 1),
        note: '',
        payments: const [],
      );

      expect(updatedLoan.interestForMonth('2026-02'), 0);
      expect(updatedLoan.interestForMonth('2026-03'), 200);
      expect(
        Loan.fromJson(updatedLoan.toJson()).interestStartDate,
        DateTime(2026, 3, 1),
      );
    });

    test('uses a custom first due date and clamps later month-end dates', () {
      final loan = Loan(
        id: 'custom-dates',
        direction: 'given',
        person: 'Kumar',
        principal: 10000,
        rate: 2,
        dueDay: 31,
        startDate: DateTime(2026, 1, 10),
        interestStartDate: DateTime(2026, 1, 20),
        firstInterestDueDate: DateTime(2026, 2, 15),
        note: '',
        payments: const [],
      );

      expect(loan.statusFor('2026-01').dueDate, DateTime(2026, 2, 19));
      expect(loan.statusFor('2026-02').dueDate, DateTime(2026, 3, 19));
    });

    test('editing freezes paid periods and recalculates unpaid periods', () {
      final payment = LoanPayment(
        id: 'partial-interest',
        type: 'interest',
        amount: 50,
        date: DateTime(2026, 1, 6),
        month: '2026-01',
      );
      final original = Loan(
        id: 'safe-edit',
        direction: 'given',
        person: 'Kumar',
        principal: 10000,
        rate: 2,
        dueDay: 5,
        startDate: DateTime(2026, 1, 1),
        interestStartDate: DateTime(2026, 1, 1),
        firstInterestDueDate: DateTime(2026, 1, 5),
        note: '',
        payments: [payment],
      );

      final edited = original.withCalculationSettings(
        person: original.person,
        phone: original.phone,
        rate: 3,
        dueDay: 10,
        startDate: original.startDate,
        interestStartDate: DateTime(2026, 2, 1),
        firstInterestDueDate: DateTime(2026, 2, 10),
        note: original.note,
      );

      expect(identical(edited.payments.single, payment), isTrue);
      expect(edited.payments, hasLength(1));
      expect(edited.statusFor('2026-01').expected, 200);
      expect(edited.statusFor('2026-01').remaining, 150);
      expect(edited.statusFor('2026-01').dueDate, DateTime(2026, 1, 31));
      expect(edited.interestForMonth('2026-02'), 300);
    });

    test('zero-interest edit preserves only historical paid-period balance',
        () {
      final original = Loan(
        id: 'zero-edit',
        direction: 'given',
        person: 'Meena',
        principal: 10000,
        rate: 2,
        dueDay: 5,
        startDate: DateTime(2026, 1, 1),
        note: '',
        payments: [
          LoanPayment(
            id: 'partial',
            type: 'interest',
            amount: 50,
            date: DateTime(2026, 1, 5),
            month: '2026-01',
          ),
        ],
      );
      final edited = original.withCalculationSettings(
        person: original.person,
        phone: original.phone,
        rate: 0,
        dueDay: 5,
        startDate: original.startDate,
        interestStartDate: original.interestStartDate,
        firstInterestDueDate: original.firstInterestDueDate,
        note: original.note,
      );
      final restored = Loan.fromJson(edited.toJson());

      expect(restored.monthsThrough(DateTime(2026, 3, 1)), ['2026-01']);
      expect(restored.interestOutstanding(today: DateTime(2026, 3, 1)), 150);
      expect(restored.payments, hasLength(1));
      expect(restored.interestPeriodSnapshots, contains('2026-01'));
    });

    test('adds full interest only after a complete month', () {
      final loan = Loan(
        id: 'full-month-cycle',
        direction: 'given',
        person: 'Perumal',
        principal: 200000,
        rate: 2,
        dueDay: 5,
        startDate: DateTime(2026, 8, 1),
        interestStartDate: DateTime(2026, 8, 1),
        firstInterestDueDate: DateTime(2026, 8, 31),
        note: '',
        payments: const [],
      );

      expect(loan.overdueInterest(today: DateTime(2026, 8, 23)), 0);
      expect(
        loan.accruedInterest(today: DateTime(2026, 8, 23)),
        closeTo(4000 * 23 / 31, .01),
      );
      expect(loan.statusFor('2026-08').dueDate, DateTime(2026, 8, 31));
      expect(loan.statusFor('2026-09').dueDate, DateTime(2026, 9, 30));
      expect(loan.statusFor('2026-10').dueDate, DateTime(2026, 10, 31));
      expect(loan.overdueInterest(today: DateTime(2026, 10, 23)), 8000);
      expect(loan.overdueMonthCount(today: DateTime(2026, 10, 23)), 2);
    });
  });
}
