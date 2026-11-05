import 'dart:math' as math;

const emiInterestMethods = <String>{'reducing', 'flat'};
const emiTolerance = 0.009;

double roundEmiMoney(double value) =>
    ((value * 100) + (value >= 0 ? 1e-7 : -1e-7)).roundToDouble() / 100;

class EmiPayment {
  const EmiPayment({
    required this.id,
    required this.amount,
    required this.date,
    required this.installmentNumber,
  });

  final String id;
  final double amount;
  final DateTime date;
  final int installmentNumber;

  Map<String, Object?> toJson() => {
        'id': id,
        'amount': amount,
        'date': _dateKey(date),
        'installmentNumber': installmentNumber,
      };

  factory EmiPayment.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final amount = json['amount'];
    final date = json['date'];
    final installmentNumber = json['installmentNumber'];
    if (id is! String ||
        id.trim().isEmpty ||
        amount is! num ||
        !amount.isFinite ||
        amount <= 0 ||
        date is! String ||
        installmentNumber is! int ||
        installmentNumber < 1) {
      throw const FormatException('Invalid EMI payment record.');
    }
    return EmiPayment(
      id: id,
      amount: amount.toDouble(),
      date: _parseDate(date),
      installmentNumber: installmentNumber,
    );
  }
}

class EmiInstallment {
  const EmiInstallment({
    required this.number,
    required this.dueDate,
    required this.emi,
    required this.principal,
    required this.interest,
    required this.openingPrincipal,
    required this.closingPrincipal,
  });

  final int number;
  final DateTime dueDate;
  final double emi;
  final double principal;
  final double interest;
  final double openingPrincipal;
  final double closingPrincipal;
}

enum EmiInstallmentStatus {
  paid,
  partiallyPaid,
  pending,
  overdue,
}

class EmiLoan {
  EmiLoan({
    required this.id,
    required this.direction,
    required this.person,
    required this.phone,
    required this.principal,
    required this.rate,
    required this.tenureMonths,
    required this.startDate,
    required this.firstDueDate,
    required this.interestMethod,
    required this.note,
    List<EmiPayment> payments = const [],
    this.closedAt,
  }) : payments = List.unmodifiable(payments);

  final String id;
  final String direction;
  final String person;
  final String phone;
  final double principal;
  final double rate;
  final int tenureMonths;
  final DateTime startDate;
  final DateTime firstDueDate;
  final String interestMethod;
  final String note;
  final List<EmiPayment> payments;
  final DateTime? closedAt;

  late final List<EmiInstallment> schedule = _buildSchedule();

  bool get isClosed => closedAt != null;

  bool get isReducing => interestMethod == 'reducing';

  double get monthlyEmi => schedule.isEmpty ? 0 : schedule.first.emi;

  double get totalInterest => roundEmiMoney(
        schedule.fold<double>(0, (sum, item) => sum + item.interest),
      );

  double get totalRepayment => roundEmiMoney(
        schedule.fold<double>(0, (sum, item) => sum + item.emi),
      );

  double get totalPaid => roundEmiMoney(
        payments.fold<double>(0, (sum, payment) => sum + payment.amount),
      );

  double get outstandingBalance => roundEmiMoney(
        schedule.fold<double>(
          0,
          (sum, item) =>
              sum + math.max(0, item.emi - paidForInstallment(item.number)),
        ),
      );

  double get outstandingPrincipal => roundEmiMoney(
        math.max(
          0,
          principal -
              schedule.fold<double>(
                0,
                (sum, item) => sum + _allocationFor(item).principal,
              ),
        ),
      );

  double get interestPaid => roundEmiMoney(
        schedule.fold<double>(
          0,
          (sum, item) => sum + _allocationFor(item).interest,
        ),
      );

  double get principalPaid => roundEmiMoney(
        schedule.fold<double>(
          0,
          (sum, item) => sum + _allocationFor(item).principal,
        ),
      );

  bool get isSettled => outstandingBalance <= emiTolerance;

  EmiInstallment? get nextUnpaidInstallment {
    for (final item in schedule) {
      if (remainingForInstallment(item.number) > emiTolerance) return item;
    }
    return null;
  }

  EmiInstallment? get oldestOverdueInstallment {
    final today = DateTime.now();
    for (final item in schedule) {
      if (_isPastDue(item, today) &&
          remainingForInstallment(item.number) > emiTolerance) {
        return item;
      }
    }
    return null;
  }

  double paidForInstallment(int number) => roundEmiMoney(
        payments
            .where((payment) => payment.installmentNumber == number)
            .fold<double>(0, (sum, payment) => sum + payment.amount),
      );

  double remainingForInstallment(int number) {
    final installment = schedule.firstWhere(
      (item) => item.number == number,
      orElse: () => schedule.last,
    );
    return roundEmiMoney(
      math.max(0, installment.emi - paidForInstallment(number)),
    );
  }

  EmiInstallmentStatus statusFor(int number, {DateTime? today}) {
    final installment = schedule.firstWhere(
      (item) => item.number == number,
      orElse: () => schedule.last,
    );
    final paid = paidForInstallment(number);
    final remaining = roundEmiMoney(math.max(0, installment.emi - paid));
    if (remaining <= emiTolerance) return EmiInstallmentStatus.paid;
    if (_isPastDue(installment, today ?? DateTime.now())) {
      return EmiInstallmentStatus.overdue;
    }
    if (paid > emiTolerance) return EmiInstallmentStatus.partiallyPaid;
    return EmiInstallmentStatus.pending;
  }

  bool isPartialFor(int number) {
    final paid = paidForInstallment(number);
    return paid > emiTolerance &&
        remainingForInstallment(number) > emiTolerance;
  }

  bool isAdvancePaymentFor(int number, {DateTime? today}) {
    final installment = schedule.firstWhere(
      (item) => item.number == number,
      orElse: () => schedule.last,
    );
    final paid = paidForInstallment(number);
    final day = today ?? DateTime.now();
    final todayAtMidnight = DateTime(day.year, day.month, day.day);
    return paid > emiTolerance &&
        DateTime(
          installment.dueDate.year,
          installment.dueDate.month,
          installment.dueDate.day,
        ).isAfter(todayAtMidnight);
  }

  double overdueAmount({DateTime? today}) {
    final day = today ?? DateTime.now();
    return roundEmiMoney(
      schedule.fold<double>(0, (sum, item) {
        if (!_isPastDue(item, day)) return sum;
        return sum + remainingForInstallment(item.number);
      }),
    );
  }

  int overdueCount({DateTime? today}) {
    final day = today ?? DateTime.now();
    return schedule
        .where((item) =>
            _isPastDue(item, day) &&
            remainingForInstallment(item.number) > emiTolerance)
        .length;
  }

  double upcomingDue({DateTime? today, int days = 30}) {
    final day = _midnight(today ?? DateTime.now());
    final end = day.add(Duration(days: days));
    return roundEmiMoney(
      schedule.fold<double>(0, (sum, item) {
        final due = _midnight(item.dueDate);
        if (due.isBefore(day) || due.isAfter(end)) return sum;
        return sum + remainingForInstallment(item.number);
      }),
    );
  }

  bool canClose() => !isClosed && isSettled;

  EmiLoan copyWith({
    String? phone,
    String? note,
    List<EmiPayment>? payments,
    DateTime? closedAt,
  }) =>
      EmiLoan(
        id: id,
        direction: direction,
        person: person,
        phone: phone ?? this.phone,
        principal: principal,
        rate: rate,
        tenureMonths: tenureMonths,
        startDate: startDate,
        firstDueDate: firstDueDate,
        interestMethod: interestMethod,
        note: note ?? this.note,
        payments: payments ?? this.payments,
        closedAt: closedAt ?? this.closedAt,
      );

  EmiLoan withPayment(EmiPayment payment) =>
      copyWith(payments: [...payments, payment]);

  EmiLoan withoutPayment(String paymentId) => copyWith(
        payments: payments.where((payment) => payment.id != paymentId).toList(),
      );

  EmiLoan close(DateTime date) => copyWith(closedAt: date);

  Map<String, Object?> toJson() => {
        'loanType': 'emi',
        'id': id,
        'direction': direction,
        'person': person,
        'phone': phone,
        'principal': principal,
        'rate': rate,
        'tenureMonths': tenureMonths,
        'startDate': _dateKey(startDate),
        'firstDueDate': _dateKey(firstDueDate),
        'interestMethod': interestMethod,
        'note': note,
        'closedAt': closedAt == null ? null : _dateKey(closedAt!),
        'payments': payments.map((payment) => payment.toJson()).toList(),
      };

  factory EmiLoan.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final direction = json['direction'];
    final person = json['person'];
    final phone = json['phone'];
    final principal = json['principal'];
    final rate = json['rate'];
    final tenureMonths = json['tenureMonths'];
    final startDate = json['startDate'];
    final firstDueDate = json['firstDueDate'];
    final interestMethod = json['interestMethod'];
    final note = json['note'];
    final rawClosedAt = json['closedAt'];
    final rawPayments = json['payments'];
    if (id is! String ||
        id.trim().isEmpty ||
        (direction != 'given' && direction != 'taken') ||
        person is! String ||
        person.trim().isEmpty ||
        phone is! String ||
        principal is! num ||
        !principal.isFinite ||
        principal <= 0 ||
        rate is! num ||
        !rate.isFinite ||
        rate < 0 ||
        rate > 100 ||
        tenureMonths is! int ||
        tenureMonths < 1 ||
        tenureMonths > 600 ||
        startDate is! String ||
        firstDueDate is! String ||
        interestMethod is! String ||
        !emiInterestMethods.contains(interestMethod) ||
        note is! String ||
        (rawClosedAt != null && rawClosedAt is! String) ||
        rawPayments is! List) {
      throw const FormatException('Invalid EMI loan record.');
    }
    final parsedStartDate = _parseDate(startDate);
    final parsedFirstDueDate = _parseDate(firstDueDate);
    final parsedClosedAt =
        rawClosedAt == null ? null : _parseDate(rawClosedAt as String);
    if (parsedFirstDueDate.isBefore(parsedStartDate) ||
        (parsedClosedAt != null && parsedClosedAt.isBefore(parsedStartDate))) {
      throw const FormatException('Invalid EMI loan dates.');
    }
    final payments = rawPayments.map((item) {
      if (item is! Map) {
        throw const FormatException('Invalid EMI payment record.');
      }
      return EmiPayment.fromJson(Map<String, Object?>.from(item));
    }).toList();
    if (payments.map((payment) => payment.id).toSet().length !=
        payments.length) {
      throw const FormatException('Duplicate EMI payment IDs.');
    }
    final loan = EmiLoan(
      id: id,
      direction: direction as String,
      person: person.trim(),
      phone: phone.trim(),
      principal: principal.toDouble(),
      rate: rate.toDouble(),
      tenureMonths: tenureMonths,
      startDate: parsedStartDate,
      firstDueDate: parsedFirstDueDate,
      interestMethod: interestMethod,
      note: note.trim(),
      payments: payments,
      closedAt: parsedClosedAt,
    );
    for (final payment in payments) {
      if (payment.installmentNumber > loan.tenureMonths ||
          payment.date.isBefore(parsedStartDate)) {
        throw const FormatException('Invalid EMI payment history.');
      }
      if (loan.paidForInstallment(payment.installmentNumber) >
          loan.schedule[payment.installmentNumber - 1].emi + emiTolerance) {
        throw const FormatException('EMI payment exceeds the instalment.');
      }
    }
    if (loan.isClosed && !loan.isSettled) {
      throw const FormatException('A closed EMI loan must be settled.');
    }
    return loan;
  }

  List<EmiInstallment> _buildSchedule() {
    final monthlyRate = rate / 100;
    final count = tenureMonths;
    if (count < 1) return const [];
    final items = <EmiInstallment>[];
    var balance = principal;
    if (isReducing) {
      final factor = math.pow(1 + monthlyRate, count).toDouble();
      final rawEmi = monthlyRate <= 0
          ? principal / count
          : principal * monthlyRate * factor / (factor - 1);
      final emi = roundEmiMoney(rawEmi);
      for (var number = 1; number <= count; number++) {
        final opening = roundEmiMoney(balance);
        final interest = roundEmiMoney(balance * monthlyRate);
        final isLast = number == count;
        var principalPart = isLast ? opening : roundEmiMoney(emi - interest);
        if (principalPart > opening) principalPart = opening;
        if (principalPart < 0) principalPart = 0;
        final closing = roundEmiMoney(math.max(0, opening - principalPart));
        items.add(
          EmiInstallment(
            number: number,
            dueDate: _addCalendarMonths(firstDueDate, number - 1),
            emi: roundEmiMoney(principalPart + interest),
            principal: principalPart,
            interest: interest,
            openingPrincipal: opening,
            closingPrincipal: closing,
          ),
        );
        balance = closing;
      }
      return items;
    }

    final monthlyInterest = roundEmiMoney(principal * monthlyRate);
    final totalInterest = roundEmiMoney(monthlyInterest * count);
    final flatEmi = roundEmiMoney((principal + totalInterest) / count);
    for (var number = 1; number <= count; number++) {
      final opening = roundEmiMoney(balance);
      final interest = monthlyInterest;
      final isLast = number == count;
      var principalPart = isLast ? opening : roundEmiMoney(flatEmi - interest);
      if (principalPart > opening) principalPart = opening;
      if (principalPart < 0) principalPart = 0;
      final closing = roundEmiMoney(math.max(0, opening - principalPart));
      items.add(
        EmiInstallment(
          number: number,
          dueDate: _addCalendarMonths(firstDueDate, number - 1),
          emi: roundEmiMoney(principalPart + interest),
          principal: principalPart,
          interest: interest,
          openingPrincipal: opening,
          closingPrincipal: closing,
        ),
      );
      balance = closing;
    }
    return items;
  }

  ({double interest, double principal}) _allocationFor(EmiInstallment item) {
    var remaining = paidForInstallment(item.number);
    final interest = roundEmiMoney(math.min(remaining, item.interest));
    remaining = math.max(0, remaining - interest);
    final principalPart = roundEmiMoney(math.min(remaining, item.principal));
    return (interest: interest, principal: principalPart);
  }

  bool _isPastDue(EmiInstallment item, DateTime day) {
    final due = _midnight(item.dueDate);
    final today = _midnight(day);
    return due.isBefore(today) &&
        remainingForInstallment(item.number) > emiTolerance;
  }
}

DateTime _midnight(DateTime value) =>
    DateTime(value.year, value.month, value.day);

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
