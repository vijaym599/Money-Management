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
      expect(loan.overdueInterest(today: today), 400);
      expect(loan.overdueMonthCount(today: today), 4);
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
  });
}
