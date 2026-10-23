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

class InterestPeriodSnapshot {
  const InterestPeriodSnapshot({
    required this.expected,
    required this.dueDate,
  });

  final double expected;
  final DateTime dueDate;

  Map<String, Object?> toJson() => {
        'expected': expected,
        'dueDate': _dateKey(dueDate),
      };

  factory InterestPeriodSnapshot.fromJson(Map<String, Object?> json) {
    final expected = json['expected'];
    if (expected is! num ||
        !expected.isFinite ||
        expected < 0 ||
        json['dueDate'] is! String) {
      throw const FormatException('Invalid interest period snapshot.');
    }
    return InterestPeriodSnapshot(
      expected: expected.toDouble(),
      dueDate: _parseDate(json['dueDate']! as String),
    );
  }
}

class Loan {
  Loan({
    required this.id,
    required this.direction,
    required this.person,
    required this.principal,
    required this.rate,
    required this.dueDay,
    required this.startDate,
    DateTime? interestStartDate,
    DateTime? firstInterestDueDate,
    required this.note,
    required this.payments,
    this.phone = '',
    Map<String, InterestPeriodSnapshot> interestPeriodSnapshots = const {},
  })  : interestStartDate = interestStartDate ?? startDate,
        firstInterestDueDate = firstInterestDueDate ??
            _interestPeriodCompletionDate(interestStartDate ?? startDate),
        interestPeriodSnapshots = Map.unmodifiable(interestPeriodSnapshots);

  final String id;
  final String direction;
  final String person;
  final double principal;
  final double rate;
  final int dueDay;
  final DateTime startDate;
  final DateTime interestStartDate;
  final DateTime firstInterestDueDate;
  final String note;
  final List<LoanPayment> payments;
  final String phone;
  final Map<String, InterestPeriodSnapshot> interestPeriodSnapshots;

  Loan copyWith({
    String? direction,
    String? person,
    double? principal,
    double? rate,
    int? dueDay,
    DateTime? startDate,
    String? phone,
    List<LoanPayment>? payments,
    DateTime? interestStartDate,
    DateTime? firstInterestDueDate,
    String? note,
    Map<String, InterestPeriodSnapshot>? interestPeriodSnapshots,
  }) =>
      Loan(
        id: id,
        direction: direction ?? this.direction,
        person: person ?? this.person,
        principal: principal ?? this.principal,
        rate: rate ?? this.rate,
        dueDay: dueDay ?? this.dueDay,
        startDate: startDate ?? this.startDate,
        interestStartDate: interestStartDate ?? this.interestStartDate,
        firstInterestDueDate: firstInterestDueDate ?? this.firstInterestDueDate,
        note: note ?? this.note,
        payments: payments ?? this.payments,
        phone: phone ?? this.phone,
        interestPeriodSnapshots:
            interestPeriodSnapshots ?? this.interestPeriodSnapshots,
      );

  /// Applies new calculation settings without rewriting any transaction.
  /// Interest periods that already contain a payment are frozen to their
  /// original expected amount and due date, while unpaid periods recalculate.
  Loan withCalculationSettings({
    required String person,
    required String phone,
    required double rate,
    required int dueDay,
    required DateTime startDate,
    required DateTime interestStartDate,
    required DateTime firstInterestDueDate,
    required String note,
  }) {
    final snapshots = Map<String, InterestPeriodSnapshot>.from(
      interestPeriodSnapshots,
    );
    for (final month in payments
        .where((payment) => payment.type == 'interest')
        .map((payment) => payment.month!)
        .toSet()) {
      snapshots.putIfAbsent(
        month,
        () => InterestPeriodSnapshot(
          expected: interestForMonth(month),
          dueDate: statusFor(month).dueDate,
        ),
      );
    }
    return Loan(
      id: id,
      direction: direction,
      person: person,
      principal: principal,
      rate: rate,
      dueDay: dueDay,
      startDate: startDate,
      interestStartDate: interestStartDate,
      firstInterestDueDate: firstInterestDueDate,
      note: note,
      payments: payments,
      phone: phone,
      interestPeriodSnapshots: snapshots,
    );
  }

  double get outstanding => math.max(
        0,
        principal -
            payments
                .where((payment) => payment.type == 'principal')
                .fold<double>(0, (sum, payment) => sum + payment.amount),
      );

  double get monthlyInterest => outstanding * rate / 100;

  bool get hasInterestLedger =>
      rate > 0 ||
      interestPeriodSnapshots.isNotEmpty ||
      payments.any((payment) => payment.type == 'interest');

  DateTime? get lastPaymentDate {
    if (payments.isEmpty) return null;
    return payments
        .map((payment) => payment.date)
        .reduce((latest, date) => date.isAfter(latest) ? date : latest);
  }

  double interestOutstanding({DateTime? today}) =>
      overdueInterest(today: today);

  /// Interest payable when the account is settled on [today]. Completed
  /// periods are charged in full; the active period is prorated by days and
  /// is not treated as overdue.
  double accruedInterest({DateTime? today}) {
    final now = today ?? DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    return monthsThrough(day).fold<double>(
      0,
      (sum, month) => sum + accruedInterestForMonth(month, today: day),
    );
  }

  double accruedInterestForMonth(String month, {DateTime? today}) {
    final now = today ?? DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final status = statusFor(month, today: day);
    if (status.due) return status.remaining;

    final periodStart = _interestPeriodStart(month);
    if (day.isBefore(periodStart) || status.expected <= 0) return 0;
    final totalDays = status.dueDate.difference(periodStart).inDays + 1;
    final elapsedDays = day.difference(periodStart).inDays + 1;
    final ratio = math.min(1.0, math.max(0.0, elapsedDays / totalDays));
    final accrued = status.expected * ratio;
    return math.max(0.0, accrued - status.paid);
  }

  double totalOutstanding({DateTime? today}) =>
      outstanding + interestOutstanding(today: today);

  bool hasPartialPayments({DateTime? today}) =>
      payments.isNotEmpty && totalOutstanding(today: today) > 0.009;

  bool isCompleted({DateTime? today}) =>
      totalOutstanding(today: today) <= 0.009;

  double interestForMonth(String month) {
    if (!_isMonth(month)) return 0;
    final snapshot = interestPeriodSnapshots[month];
    if (snapshot != null) return snapshot.expected;
    if (rate <= 0 || month.compareTo(_monthKey(interestStartDate)) < 0) {
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
    final last = DateTime(date.year, date.month);
    final lastKey = _monthKey(last);
    final result = <String>{};
    if (rate > 0) {
      var cursor = DateTime(interestStartDate.year, interestStartDate.month);
      while (!cursor.isAfter(last)) {
        result.add(_monthKey(cursor));
        cursor = DateTime(cursor.year, cursor.month + 1);
      }
    }
    result.addAll(
      interestPeriodSnapshots.keys
          .where((month) => month.compareTo(lastKey) <= 0),
    );
    result.addAll(payments
        .where((payment) =>
            payment.type == 'interest' &&
            payment.month!.compareTo(lastKey) <= 0)
        .map((payment) => payment.month!));
    final sorted = result.toList()..sort();
    return sorted;
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
    final snapshot = interestPeriodSnapshots[month];
    final dueDate = snapshot?.dueDate ?? _interestDueDate(month);
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

  DateTime _interestDueDate(String month) {
    final parts = month.split('-').map(int.parse).toList();
    final offset = (parts[0] - interestStartDate.year) * 12 +
        parts[1] -
        interestStartDate.month;
    final minimumFirstDue = _interestPeriodCompletionDate(interestStartDate);
    final effectiveFirstDue = firstInterestDueDate.isBefore(minimumFirstDue)
        ? minimumFirstDue
        : firstInterestDueDate;
    return _addCalendarMonths(effectiveFirstDue, math.max(0, offset));
  }

  DateTime _interestPeriodStart(String month) {
    final parts = month.split('-').map(int.parse).toList();
    final offset = (parts[0] - interestStartDate.year) * 12 +
        parts[1] -
        interestStartDate.month;
    if (offset <= 0) {
      return DateTime(
        interestStartDate.year,
        interestStartDate.month,
        interestStartDate.day,
      );
    }
    final previousMonth = DateTime(
      interestStartDate.year,
      interestStartDate.month + offset - 1,
    );
    return _interestDueDate(_monthKey(previousMonth))
        .add(const Duration(days: 1));
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
        'interestStartDate': _dateKey(interestStartDate),
        'firstInterestDueDate': _dateKey(firstInterestDueDate),
        'note': note,
        'phone': phone,
        'payments': payments.map((payment) => payment.toJson()).toList(),
        'interestPeriodSnapshots': interestPeriodSnapshots.map(
          (month, snapshot) => MapEntry(month, snapshot.toJson()),
        ),
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
        (json['phone'] != null && json['phone'] is! String) ||
        rawPayments is! List) {
      throw const FormatException('Invalid loan record.');
    }
    final startDate = _parseDate(json['startDate']! as String);
    final rawInterestStartDate = json['interestStartDate'];
    if (rawInterestStartDate != null && rawInterestStartDate is! String) {
      throw const FormatException('Invalid interest start date.');
    }
    final interestStartDate = rawInterestStartDate == null
        ? startDate
        : _parseDate(rawInterestStartDate as String);
    final rawFirstInterestDueDate = json['firstInterestDueDate'];
    if (rawFirstInterestDueDate != null && rawFirstInterestDueDate is! String) {
      throw const FormatException('Invalid first interest due date.');
    }
    final firstInterestDueDate = rawFirstInterestDueDate == null
        ? _interestPeriodCompletionDate(interestStartDate)
        : _parseDate(rawFirstInterestDueDate as String);
    final rawSnapshots = json['interestPeriodSnapshots'];
    if (rawSnapshots != null && rawSnapshots is! Map) {
      throw const FormatException('Invalid interest period snapshots.');
    }
    final snapshots = <String, InterestPeriodSnapshot>{};
    if (rawSnapshots is Map) {
      for (final entry in rawSnapshots.entries) {
        if (entry.key is! String ||
            !_isMonth(entry.key as String) ||
            entry.value is! Map) {
          throw const FormatException('Invalid interest period snapshot.');
        }
        snapshots[entry.key as String] = InterestPeriodSnapshot.fromJson(
          Map<String, Object?>.from(entry.value as Map),
        );
      }
    }
    final payments = rawPayments.map((item) {
      if (item is! Map) throw const FormatException('Invalid payment record.');
      return LoanPayment.fromJson(Map<String, Object?>.from(item));
    }).toList();
    if (interestStartDate.isBefore(startDate) ||
        (rate > 0 && firstInterestDueDate.isBefore(interestStartDate)) ||
        payments.any((payment) => payment.date.isBefore(startDate)) ||
        payments.any((payment) =>
            payment.type == 'interest' &&
            payment.month!.compareTo(_monthKey(interestStartDate)) < 0 &&
            !snapshots.containsKey(payment.month)) ||
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
      interestStartDate: interestStartDate,
      firstInterestDueDate: firstInterestDueDate,
      note: json['note'] as String? ?? '',
      phone: (json['phone'] as String? ?? '').trim(),
      payments: payments,
      interestPeriodSnapshots: snapshots,
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

DateTime _interestPeriodCompletionDate(DateTime start) {
  final nextMonth = DateTime(start.year, start.month + 1, 1);
  final anniversary = DateTime(
    nextMonth.year,
    nextMonth.month,
    math.min(start.day, DateTime(nextMonth.year, nextMonth.month + 1, 0).day),
  );
  return anniversary.subtract(const Duration(days: 1));
}

DateTime _addCalendarMonths(DateTime date, int months) {
  final target = DateTime(date.year, date.month + months, 1);
  final lastDay = DateTime(target.year, target.month + 1, 0).day;
  return DateTime(target.year, target.month, math.min(date.day, lastDay));
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime _parseDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null || _dateKey(date) != value) {
    throw const FormatException('Date must use YYYY-MM-DD format.');
  }
  return DateTime(date.year, date.month, date.day);
}
