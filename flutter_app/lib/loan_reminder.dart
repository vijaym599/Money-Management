import 'package:intl/intl.dart';

import 'models.dart';

enum LoanReminderStatus { active, overdueInterest, partialPayment, completed }

enum LoanShareType { reminder, statement, paymentReceipt }

enum LoanShareLanguage { english, tamil, both }

class LoanReminderContent {
  const LoanReminderContent({
    required this.status,
    required this.message,
    required this.interestOutstanding,
    required this.totalOutstanding,
    required this.unpaidInterestMonths,
  });

  final LoanReminderStatus status;
  final String message;
  final double interestOutstanding;
  final double totalOutstanding;
  final List<String> unpaidInterestMonths;
}

class LoanShareMessageBuilder {
  const LoanShareMessageBuilder._();

  static String build({
    required Loan loan,
    required LoanShareType type,
    required LoanShareLanguage language,
    LoanPayment? payment,
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    if (type == LoanShareType.paymentReceipt &&
        (payment == null ||
            !loan.payments.any((item) => item.id == payment.id))) {
      throw ArgumentError('A receipt requires a recorded payment.');
    }

    String localized(bool isTamil) {
      switch (type) {
        case LoanShareType.reminder:
          return _reminder(loan, isTamil, now);
        case LoanShareType.statement:
          return _statement(loan, isTamil, now);
        case LoanShareType.paymentReceipt:
          return _receipt(loan, payment!, isTamil, now);
      }
    }

    switch (language) {
      case LoanShareLanguage.english:
        return localized(false);
      case LoanShareLanguage.tamil:
        return localized(true);
      case LoanShareLanguage.both:
        return '${localized(false)}\n\n────────────\n\n${localized(true)}';
    }
  }

  static String _reminder(Loan loan, bool isTamil, DateTime now) {
    final status = _status(loan, now);
    final overdue = loan.interestOutstanding(today: now);
    final amountDueNow = overdue > 0.009
        ? overdue
        : loan.rate > 0 || status == LoanReminderStatus.completed
            ? 0.0
            : loan.outstanding;
    final oldestMonth = loan.oldestUnpaidMonth(today: now, dueOnly: true);
    final dueDate = oldestMonth == null
        ? _nextInterestDueDate(loan, now)
        : loan.statusFor(oldestMonth, today: now).dueDate;
    final lines = <String>[
      isTamil ? '*கடன் நினைவூட்டல்*' : '*Loan Reminder*',
      '',
      isTamil ? 'வணக்கம் ${loan.person},' : 'Hello ${loan.person},',
      _reminderIntro(status, isTamil),
    ];
    if (overdue > 0.009) {
      lines.add(
        '• ${isTamil ? 'காலதாமத வட்டி' : 'Overdue interest'}: ${_money(overdue)}',
      );
    }
    if (dueDate != null && status != LoanReminderStatus.completed) {
      lines.add(
        '• ${isTamil ? 'செலுத்த வேண்டிய தேதி' : 'Due date'}: ${_date(dueDate)}',
      );
    }
    lines.add(
      '• ${isTamil ? 'இப்போது செலுத்த வேண்டியது' : 'Amount due now'}: *${_money(amountDueNow)}*',
    );
    final principalIsRelevant = loan.outstanding > 0.009 &&
        (loan.rate <= 0 ||
            loan.outstanding < loan.principal - 0.009 ||
            status == LoanReminderStatus.partialPayment);
    if (principalIsRelevant) {
      lines.add(
        '• ${isTamil ? 'முதல்தொகை இருப்பு' : 'Principal balance'}: ${_money(loan.outstanding)}',
      );
    }
    lines.addAll(['', _reminderClosing(status, isTamil)]);
    return lines.join('\n');
  }

  static String _statement(Loan loan, bool isTamil, DateTime now) {
    final interestOutstanding = _unpaidInterest(loan, now);
    final paidMonths = <String>[];
    final unpaidMonths = <String>[];
    for (final month in loan.monthsThrough(now)) {
      final item = loan.statusFor(month, today: now);
      if (item.expected <= 0.009) continue;
      if (item.remaining <= 0.009) {
        paidMonths.add(_interestMonthLine(month, item, isTamil, paid: true));
      } else {
        unpaidMonths.add(_interestMonthLine(month, item, isTamil, paid: false));
      }
    }
    final payments = [...loan.payments]..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
      });
    final lines = <String>[
      isTamil ? '* கடன் அறிக்கை*' : '* Loan Statement*',
      '',
      '• ${isTamil ? 'நபர்' : 'Borrower'}: ${loan.person}',
      '• ${isTamil ? 'அசல் முதல்தொகை' : 'Original principal'}: ${_money(loan.principal)}',
      '• ${isTamil ? 'கடன் தேதி' : 'Loan date'}: ${_date(loan.startDate)}',
    ];
    if (loan.rate > 0) {
      lines.addAll([
        '• ${isTamil ? 'வட்டி தொடங்கும் தேதி' : 'Interest start date'}: ${_date(loan.interestStartDate)}',
        '• ${isTamil ? 'முதல் வட்டி தவணை தேதி' : 'First interest due date'}: ${_date(loan.firstInterestDueDate)}',
        '• ${isTamil ? 'மாத வட்டி தவணை நாள்' : 'Monthly interest due day'}: ${loan.dueDay}',
        '• ${isTamil ? 'மாத வட்டி விகிதம்' : 'Monthly interest rate'}: ${_rate(loan.rate)}%',
        '• ${isTamil ? 'தற்போதைய மாத வட்டி' : 'Current monthly interest'}: ${_money(loan.monthlyInterest)}',
      ]);
    }
    lines.addAll([
      '',
      isTamil ? '*செலுத்தல் வரலாறு*' : '*Payment History*',
      if (payments.isEmpty)
        (isTamil ? 'பதிவுகள் இல்லை' : 'No payments recorded'),
      ...payments.map((payment) {
        final type = payment.type == 'principal'
            ? (isTamil ? 'முதல்தொகை' : 'Principal')
            : (isTamil ? 'வட்டி' : 'Interest');
        final month = payment.month == null
            ? ''
            : ' · ${_monthLabelFromKey(payment.month!, isTamil)}';
        return '• ${_date(payment.date)} · $type$month · ${_money(payment.amount)}';
      }),
    ]);
    if (loan.hasInterestLedger) {
      lines.addAll([
        '',
        isTamil ? '*செலுத்திய வட்டி மாதங்கள்*' : '*Paid Interest Months*',
        if (paidMonths.isEmpty) (isTamil ? 'எதுவும் இல்லை' : 'None'),
        ...paidMonths,
        '',
        isTamil ? '*செலுத்தாத வட்டி மாதங்கள்*' : '*Unpaid Interest Months*',
        if (unpaidMonths.isEmpty) (isTamil ? 'எதுவும் இல்லை' : 'None'),
        ...unpaidMonths,
      ]);
    }
    lines.addAll([
      '',
      isTamil ? '*நிலுவை சுருக்கம்*' : '*Outstanding Summary*',
      '• ${isTamil ? 'முதல்தொகை நிலுவை' : 'Principal outstanding'}: ${_money(loan.outstanding)}',
      if (interestOutstanding > 0.009)
        '• ${isTamil ? 'வட்டி நிலுவை' : 'Interest outstanding'}: ${_money(interestOutstanding)}',
      '• ${isTamil ? 'மொத்த நிலுவை' : 'Total outstanding'}: *${_money(_shareTotal(loan, now))}*',
    ]);
    return lines.join('\n');
  }

  static String _receipt(
    Loan loan,
    LoanPayment payment,
    bool isTamil,
    DateTime now,
  ) {
    final principalPaid = payment.type == 'principal' ? payment.amount : 0.0;
    final interestPaid = payment.type == 'interest' ? payment.amount : 0.0;
    return <String>[
      isTamil
          ? '*Money MM – பணம் பெற்ற ரசீது*'
          : '*Money MM – Payment Receipt*',
      '',
      '• ${isTamil ? 'நபர்' : 'Borrower'}: ${loan.person}',
      '• ${isTamil ? 'ரசீது எண்' : 'Receipt reference'}: MM-${payment.id}',
      '• ${isTamil ? 'பணம் பெற்ற தேதி' : 'Payment date'}: ${_date(payment.date)}',
      '• ${isTamil ? 'பெற்ற தொகை' : 'Amount received'}: *${_money(payment.amount)}*',
      '• ${isTamil ? 'முதல்தொகைக்கு செலுத்தியது' : 'Principal paid'}: ${_money(principalPaid)}',
      if (loan.rate > 0)
        '• ${isTamil ? 'வட்டிக்கு செலுத்தியது' : 'Interest paid'}: ${_money(interestPaid)}',
      if (payment.month != null)
        '• ${isTamil ? 'வட்டி மாதம்' : 'Interest month'}: ${_monthLabelFromKey(payment.month!, isTamil)}',
      '• ${isTamil ? 'மீதமுள்ள தொகை' : 'Remaining balance'}: *${_money(_shareTotal(loan, now))}*',
      '',
      isTamil
          ? 'பணம் பெறப்பட்டு கணக்கில் பதிவு செய்யப்பட்டது. நன்றி.'
          : 'Payment received and recorded successfully. Thank you.',
    ].join('\n');
  }

  static String _interestMonthLine(
    String month,
    InterestStatus status,
    bool isTamil, {
    required bool paid,
  }) {
    if (paid) {
      return '• ${_monthLabelFromKey(month, isTamil)} · ${_money(status.paid)}';
    }
    final paidPart = status.paid > 0.009
        ? ' · ${isTamil ? 'செலுத்தியது' : 'paid'} ${_money(status.paid)}'
        : '';
    return '• ${_monthLabelFromKey(month, isTamil)} · '
        '${isTamil ? 'மீதி' : 'due'} ${_money(status.remaining)}$paidPart '
        '· ${_date(status.dueDate)}';
  }

  static LoanReminderStatus _status(Loan loan, DateTime now) {
    if (_shareTotal(loan, now) <= 0.009) {
      return LoanReminderStatus.completed;
    }
    if (loan.overdueInterest(today: now) > 0.009) {
      return LoanReminderStatus.overdueInterest;
    }
    if (loan.hasPartialPayments(today: now)) {
      return LoanReminderStatus.partialPayment;
    }
    return LoanReminderStatus.active;
  }

  static double _unpaidInterest(Loan loan, DateTime now) =>
      loan.monthsThrough(now).fold<double>(0, (sum, month) {
        return sum + loan.statusFor(month, today: now).remaining;
      });

  static double _shareTotal(Loan loan, DateTime now) =>
      loan.outstanding + _unpaidInterest(loan, now);

  static DateTime? _nextInterestDueDate(Loan loan, DateTime now) {
    if (loan.rate <= 0 || _shareTotal(loan, now) <= 0.009) return null;
    var cursor = DateTime(now.year, now.month);
    for (var count = 0; count < 2; count++) {
      final month = _monthKey(cursor);
      if (month.compareTo(_monthKey(loan.interestStartDate)) >= 0) {
        final status = loan.statusFor(month, today: now);
        if (status.remaining > 0.009 && !status.dueDate.isBefore(_day(now))) {
          return status.dueDate;
        }
      }
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
    return null;
  }

  static String _reminderIntro(LoanReminderStatus status, bool isTamil) {
    switch (status) {
      case LoanReminderStatus.active:
        return isTamil
            ? 'உங்கள் கடன் கணக்கு செயலில் உள்ளது.'
            : 'Your loan account is active.';
      case LoanReminderStatus.overdueInterest:
        return isTamil
            ? 'உங்கள் வட்டி செலுத்தல் காலதாமதமாகியுள்ளது.'
            : 'Your interest payment is overdue.';
      case LoanReminderStatus.partialPayment:
        return isTamil
            ? 'உங்கள் பகுதி செலுத்தல் பதிவு செய்யப்பட்டுள்ளது.'
            : 'Your partial payment has been recorded.';
      case LoanReminderStatus.completed:
        return isTamil
            ? 'உங்கள் கடன் முழுமையாக முடிக்கப்பட்டது.'
            : 'Your loan has been fully settled.';
    }
  }

  static String _reminderClosing(LoanReminderStatus status, bool isTamil) {
    switch (status) {
      case LoanReminderStatus.overdueInterest:
        return isTamil
            ? 'நிலுவைத் தொகையை விரைவில் செலுத்தவும். நன்றி.'
            : 'Please pay the overdue amount at your earliest convenience. Thank you.';
      case LoanReminderStatus.completed:
        return isTamil
            ? 'முழுத் தொகையும் பெறப்பட்டது. நன்றி.'
            : 'Payment has been received in full. Thank you.';
      case LoanReminderStatus.active:
      case LoanReminderStatus.partialPayment:
        return isTamil
            ? 'இந்த நினைவூட்டலை கவனத்தில் கொள்ளவும். நன்றி.'
            : 'Please note this reminder. Thank you.';
    }
  }

  static String _date(DateTime value) => DateFormat('dd-MM-yyyy').format(value);

  static String _monthLabelFromKey(String month, bool isTamil) {
    final parts = month.split('-');
    return _monthLabel(
        DateTime(int.parse(parts[0]), int.parse(parts[1])), isTamil);
  }

  static String _monthLabel(DateTime value, bool isTamil) {
    const english = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    const tamil = [
      'ஜன',
      'பிப்',
      'மார்',
      'ஏப்',
      'மே',
      'ஜூன்',
      'ஜூலை',
      'ஆக',
      'செப்',
      'அக்',
      'நவ',
      'டிச'
    ];
    final month = (isTamil ? tamil : english)[value.month - 1];
    return '$month ${value.year}';
  }

  static String _monthKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

  static DateTime _day(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static String _rate(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();

  static String _money(double value) => NumberFormat.currency(
        locale: 'en_IN',
        symbol: '₹',
        decimalDigits: value % 1 == 0 ? 0 : 2,
      ).format(value);
}

class LoanReminderBuilder {
  const LoanReminderBuilder._();

  static LoanReminderContent build({
    required Loan loan,
    required bool isTamil,
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    final unpaidMonths = loan.monthsThrough(now).where((month) {
      return loan.statusFor(month, today: now).isDue;
    }).toList();
    return LoanReminderContent(
      status: LoanShareMessageBuilder._status(loan, now),
      message: LoanShareMessageBuilder.build(
        loan: loan,
        type: LoanShareType.reminder,
        language: isTamil ? LoanShareLanguage.tamil : LoanShareLanguage.english,
        today: now,
      ),
      interestOutstanding: loan.interestOutstanding(today: now),
      totalOutstanding: loan.totalOutstanding(today: now),
      unpaidInterestMonths: List.unmodifiable(unpaidMonths),
    );
  }
}
