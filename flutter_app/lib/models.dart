import 'dart:math' as math;

class LoanPayment {
  const LoanPayment({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    this.month,
  });

  final String id;
  final String type;
  final double amount;
  final DateTime date;
  final String? month;

  Map<String, Object?> toJson() => {
        'id': id,
        'type': type,
        'amount': amount,
        'date': _dateKey(date),
        'month': month,
      };

  factory LoanPayment.fromJson(Map<String, Object?> json) {
    final type = json['type'];
    final amount = json['amount'];
    final month = json['month'];
    if (json['id'] is! String ||
        (json['id'] as String).trim().isEmpty ||
        (type != 'interest' && type != 'principal') ||
        amount is! num ||
        !amount.isFinite ||
        amount <= 0 ||
        json['date'] is! String ||
        (month != null && month is! String) ||
        (type == 'interest' && !_isMonth(month as String?)) ||
        (type == 'principal' && month != null)) {
      throw const FormatException('Invalid payment record.');
    }
    return LoanPayment(
      id: json['id']! as String,
      type: type as String,
      amount: amount.toDouble(),
      date: _parseDate(json['date']! as String),
      month: month as String?,
    );
  }
}

class InterestStatus {
  const InterestStatus({
    required this.expected,
    required this.paid,
    required this.remaining,
    required this.dueDate,
    required this.due,
    required this.isDue,
    required this.overdueDays,
  });

  final double expected;
  final double paid;
  final double remaining;
  final DateTime dueDate;
  final bool due;
  final bool isDue;
  final int overdueDays;
}

class Loan {
  const Loan({
    required this.id,
    required this.direction,
    required this.person,
    required this.principal,
    required this.rate,
    required this.dueDay,
    required this.startDate,
    required this.note,
    required this.payments,
  });

  final String id;
  final String direction;
  final String person;
  final double principal;
  final double rate;
  final int dueDay;
  final DateTime startDate;
  final String note;
  final List<LoanPayment> payments;

  double get outstanding => math.max(
        0,
        principal -
            payments
                .where((payment) => payment.type == 'principal')
                .fold<double>(0, (sum, payment) => sum + payment.amount),
      );

  double get monthlyInterest => outstanding * rate / 100;

  double interestForMonth(String month) {
    if (!_isMonth(month) || month.compareTo(_monthKey(startDate)) < 0) {
      return 0;
    }
    final monthStart = '$month-01';
    final principalRepaidBeforeMonth = payments
        .where((payment) =>
            payment.type == 'principal' &&
            _dateKey(payment.date).compareTo(monthStart) <= 0)
        .fold<double>(0, (sum, payment) => sum + payment.amount);
    return math.max(0, principal - principalRepaidBeforeMonth) * rate / 100;
  }

  double paidInterestForMonth(String month) => payments
      .where((payment) => payment.type == 'interest' && payment.month == month)
      .fold<double>(0, (sum, payment) => sum + payment.amount);

  List<String> monthsThrough(DateTime date) {
    var cursor = DateTime(startDate.year, startDate.month);
    final last = DateTime(date.year, date.month);
    final result = <String>[];
    while (!cursor.isAfter(last)) {
      result.add(_monthKey(cursor));
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
    return result;
  }

  double overdueInterest({DateTime? today}) {
    final now = today ?? DateTime.now();
    return monthsThrough(now).fold<double>(0, (sum, month) {
      final status = statusFor(month, today: now);
      return sum + (status.due ? status.remaining : 0);
    });
  }

  int overdueMonthCount({DateTime? today}) {
    final now = today ?? DateTime.now();
    return monthsThrough(now)
        .where((month) => statusFor(month, today: now).isDue)
        .length;
  }

  String? oldestUnpaidMonth({DateTime? today, bool dueOnly = false}) {
    final now = today ?? DateTime.now();
    for (final month in monthsThrough(now)) {
      final status = statusFor(month, today: now);
      if (status.remaining > 0.009 && (!dueOnly || status.due)) return month;
    }
    return null;
  }

  InterestStatus statusFor(String month, {DateTime? today}) {
    if (!_isMonth(month)) {
      throw const FormatException('Month must use YYYY-MM format.');
    }
    final parts = month.split('-').map(int.parse).toList();
    final year = parts[0];
    final monthNumber = parts[1];
    final lastDay = DateTime(year, monthNumber + 1, 0).day;
    var dueDate = DateTime(year, monthNumber, math.min(dueDay, lastDay));
    if (startDate.isAfter(dueDate)) {
      final nextMonth = DateTime(year, monthNumber + 1, 1);
      dueDate = DateTime(
        nextMonth.year,
        nextMonth.month,
        math.min(
          dueDay,
          DateTime(nextMonth.year, nextMonth.month + 1, 0).day,
        ),
      );
    }
    final now = today ?? DateTime.now();
    final todayAtMidnight = DateTime(now.year, now.month, now.day);
    final expected = interestForMonth(month);
    final paid = paidInterestForMonth(month);
    final remaining = math.max(0.0, expected - paid);
    final due = expected > 0 && !dueDate.isAfter(todayAtMidnight);
    final isDue = due && remaining > 0.009;
    return InterestStatus(
      expected: expected,
      paid: paid,
      remaining: remaining,
      dueDate: dueDate,
      due: due,
      isDue: isDue,
      overdueDays: isDue ? todayAtMidnight.difference(dueDate).inDays : 0,
    );
  }

  List<String> get months => monthsThrough(DateTime.now());

  Map<String, Object?> toJson() => {
        'id': id,
        'direction': direction,
        'person': person,
        'principal': principal,
        'rate': rate,
        'dueDay': dueDay,
        'startDate': _dateKey(startDate),
        'note': note,
        'payments': payments.map((payment) => payment.toJson()).toList(),
      };

  factory Loan.fromJson(Map<String, Object?> json) {
    final direction = json['direction'];
    final principal = json['principal'];
    final rate = json['rate'];
    final dueDay = json['dueDay'];
    final rawPayments = json['payments'];
    final person = json['person'];
    if (json['id'] is! String ||
        (json['id'] as String).trim().isEmpty ||
        (direction != 'given' && direction != 'taken') ||
        person is! String ||
        person.trim().isEmpty ||
        principal is! num ||
        !principal.isFinite ||
        principal <= 0 ||
        rate is! num ||
        !rate.isFinite ||
        rate < 0 ||
        rate > 100 ||
        dueDay is! int ||
        dueDay < 1 ||
        dueDay > 31 ||
        json['startDate'] is! String ||
        (json['note'] != null && json['note'] is! String) ||
        rawPayments is! List) {
      throw const FormatException('Invalid loan record.');
    }
    final startDate = _parseDate(json['startDate']! as String);
    final payments = rawPayments.map((item) {
      if (item is! Map) throw const FormatException('Invalid payment record.');
      return LoanPayment.fromJson(Map<String, Object?>.from(item));
    }).toList();
    if (payments.any((payment) => payment.date.isBefore(startDate)) ||
        payments.any((payment) =>
            payment.type == 'interest' &&
            payment.month!.compareTo(_monthKey(startDate)) < 0) ||
        payments.map((payment) => payment.id).toSet().length !=
            payments.length ||
        payments
                .where((payment) => payment.type == 'principal')
                .fold<double>(0, (sum, payment) => sum + payment.amount) >
            principal.toDouble() + 0.009) {
      throw const FormatException('Invalid payment history.');
    }
    final loan = Loan(
      id: json['id']! as String,
      direction: direction as String,
      person: person.trim(),
      principal: principal.toDouble(),
      rate: rate.toDouble(),
      dueDay: dueDay,
      startDate: startDate,
      note: json['note'] as String? ?? '',
      payments: payments,
    );
    final interestMonths = payments
        .where((payment) => payment.type == 'interest')
        .map((payment) => payment.month!)
        .toSet();
    for (final month in interestMonths) {
      if (loan.paidInterestForMonth(month) >
          loan.interestForMonth(month) + 0.009) {
        throw const FormatException('Interest payment exceeds the balance.');
      }
    }
    return loan;
  }
}

bool _isMonth(String? value) =>
    value != null && RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(value);

String _monthKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime _parseDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null || _dateKey(date) != value) {
    throw const FormatException('Date must use YYYY-MM-DD format.');
  }
  return DateTime(date.year, date.month, date.day);
}
