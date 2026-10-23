import 'package:flutter_test/flutter_test.dart';
import 'package:kadan_kanakku/loan_reminder.dart';
import 'package:kadan_kanakku/models.dart';

void main() {
  Loan loan({
    double rate = 2,
    DateTime? interestStartDate,
    List<LoanPayment> payments = const [],
  }) =>
      Loan(
        id: 'loan-1',
        direction: 'given',
        person: 'Kumar',
        principal: 10000,
        rate: rate,
        dueDay: 5,
        startDate: DateTime(2026, 1, 10),
        interestStartDate: interestStartDate,
        note: '',
        phone: '9876543210',
        payments: payments,
      );

  group('WhatsApp share messages', () {
    test('reminder keeps amount due now separate from total outstanding', () {
      final message = LoanShareMessageBuilder.build(
        loan: loan(interestStartDate: DateTime(2026, 1, 10)),
        type: LoanShareType.reminder,
        language: LoanShareLanguage.english,
        today: DateTime(2026, 2, 10),
      );

      expect(message, contains('Overdue interest: ₹400'));
      expect(message, contains('Due date: 05-02-2026'));
      expect(message, contains('Amount due now: *₹400*'));
      expect(message, isNot(contains('Total outstanding')));
    });

    test('statement includes details, history, and paid/unpaid months', () {
      final currentLoan = loan(
        interestStartDate: DateTime(2026, 1, 10),
        payments: [
          LoanPayment(
            id: 'interest-jan',
            type: 'interest',
            amount: 200,
            date: DateTime(2026, 2, 5),
            month: '2026-01',
          ),
          LoanPayment(
            id: 'interest-feb',
            type: 'interest',
            amount: 50,
            date: DateTime(2026, 2, 7),
            month: '2026-02',
          ),
        ],
      );
      final message = LoanShareMessageBuilder.build(
        loan: currentLoan,
        type: LoanShareType.statement,
        language: LoanShareLanguage.english,
        today: DateTime(2026, 2, 10),
      );

      expect(message, contains('Original principal: ₹10,000'));
      expect(message, contains('Interest start date: 10-01-2026'));
      expect(message, contains('05-02-2026 · Interest · Jan 2026 · ₹200'));
      expect(message, contains('*Paid Interest Months*'));
      expect(message, contains('Jan 2026 · ₹200'));
      expect(message, contains('*Unpaid Interest Months*'));
      expect(message, contains('Feb 2026 · due ₹150 · paid ₹50'));
      expect(message, contains('Interest outstanding: ₹150'));
      expect(message, contains('Total outstanding: *₹10,150*'));
    });

    test('zero-interest statement hides all interest fields', () {
      final message = LoanShareMessageBuilder.build(
        loan: loan(rate: 0),
        type: LoanShareType.statement,
        language: LoanShareLanguage.english,
        today: DateTime(2026, 2, 10),
      );

      expect(message, isNot(contains('Interest start date')));
      expect(message, isNot(contains('Monthly interest')));
      expect(message, isNot(contains('Interest outstanding')));
      expect(message, isNot(contains('Interest Months')));
    });

    test('active total includes unpaid interest that is not due yet', () {
      final currentLoan = loan(
        interestStartDate: DateTime(2026, 3, 1),
      );
      final reminder = LoanShareMessageBuilder.build(
        loan: currentLoan,
        type: LoanShareType.reminder,
        language: LoanShareLanguage.english,
        today: DateTime(2026, 3, 2),
      );
      final statement = LoanShareMessageBuilder.build(
        loan: currentLoan,
        type: LoanShareType.statement,
        language: LoanShareLanguage.english,
        today: DateTime(2026, 3, 2),
      );

      expect(reminder, contains('Amount due now: *₹0*'));
      expect(statement, contains('Interest outstanding: ₹200'));
      expect(statement, contains('Total outstanding: *₹10,200*'));
    });

    test('reminder adjusts for partial and completed zero-interest loans', () {
      final partialPayment = LoanPayment(
        id: 'partial',
        type: 'principal',
        amount: 2500,
        date: DateTime(2026, 2, 12),
      );
      final partial = LoanShareMessageBuilder.build(
        loan: loan(rate: 0, payments: [partialPayment]),
        type: LoanShareType.reminder,
        language: LoanShareLanguage.english,
        today: DateTime(2026, 2, 12),
      );
      final fullPayment = LoanPayment(
        id: 'full',
        type: 'principal',
        amount: 10000,
        date: DateTime(2026, 2, 12),
      );
      final completed = LoanShareMessageBuilder.build(
        loan: loan(rate: 0, payments: [fullPayment]),
        type: LoanShareType.reminder,
        language: LoanShareLanguage.english,
        today: DateTime(2026, 2, 12),
      );

      expect(partial, contains('partial payment has been recorded'));
      expect(partial, contains('Principal balance: ₹7,500'));
      expect(completed, contains('fully settled'));
      expect(completed, contains('Amount due now: *₹0*'));
    });

    test('receipt uses recorded payment and its unique reference', () {
      final payment = LoanPayment(
        id: 'payment-unique-42',
        type: 'principal',
        amount: 2500,
        date: DateTime(2026, 2, 12),
      );
      final currentLoan = loan(rate: 0, payments: [payment]);
      final message = LoanShareMessageBuilder.build(
        loan: currentLoan,
        type: LoanShareType.paymentReceipt,
        language: LoanShareLanguage.english,
        payment: payment,
        today: DateTime(2026, 2, 12),
      );

      expect(message, contains('Receipt reference: MM-payment-unique-42'));
      expect(message, contains('Amount received: *₹2,500*'));
      expect(message, contains('Principal paid: ₹2,500'));
      expect(message, contains('Remaining balance: *₹7,500*'));
      expect(message, isNot(contains('Interest paid')));
    });

    test('never builds a receipt for an unrecorded payment', () {
      final unrecorded = LoanPayment(
        id: 'not-recorded',
        type: 'principal',
        amount: 500,
        date: DateTime(2026, 2, 12),
      );

      expect(
        () => LoanShareMessageBuilder.build(
          loan: loan(rate: 0),
          type: LoanShareType.paymentReceipt,
          language: LoanShareLanguage.english,
          payment: unrecorded,
          today: DateTime(2026, 2, 12),
        ),
        throwsArgumentError,
      );
    });

    test('both language mode includes English and Tamil versions', () {
      final message = LoanShareMessageBuilder.build(
        loan: loan(rate: 0),
        type: LoanShareType.reminder,
        language: LoanShareLanguage.both,
        today: DateTime(2026, 2, 10),
      );

      expect(message, contains('Loan Reminder'));
      expect(message, contains('கடன் நினைவூட்டல்'));
      expect(message, contains('────────────'));
    });
  });
}
