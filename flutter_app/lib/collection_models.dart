import 'dart:math' as math;

const collectionTolerance = 0.009;

const collectionTypeKeys = <String>{
  'monthly_interest',
  'weekly_interest',
  'monthly_emi',
  'weekly_emi',
};

const collectionRatePeriods = <String>{'weekly', 'monthly', 'annual'};

const collectionPaymentCategories = <String>{
  'interest',
  'principal',
  'emi',
  'settlement',
};

double roundCollectionMoney(double value) =>
    ((value * 100) + (value >= 0 ? 1e-7 : -1e-7)).roundToDouble() / 100;

enum CollectionLoanType {
  monthlyInterestOnly,
  weeklyInterestOnly,
  monthlyEmi,
  weeklyEmi,
}

extension CollectionLoanTypeDetails on CollectionLoanType {
  String get key => switch (this) {
        CollectionLoanType.monthlyInterestOnly => 'monthly_interest',
        CollectionLoanType.weeklyInterestOnly => 'weekly_interest',
        CollectionLoanType.monthlyEmi => 'monthly_emi',
        CollectionLoanType.weeklyEmi => 'weekly_emi',
      };

  bool get isEmi =>
      this == CollectionLoanType.monthlyEmi ||
      this == CollectionLoanType.weeklyEmi;

  bool get isWeekly =>
      this == CollectionLoanType.weeklyInterestOnly ||
      this == CollectionLoanType.weeklyEmi;

  String get frequency => isWeekly ? 'weekly' : 'monthly';
}

CollectionLoanType collectionTypeFromKey(String key) => switch (key) {
      'monthly_interest' => CollectionLoanType.monthlyInterestOnly,
      'weekly_interest' => CollectionLoanType.weeklyInterestOnly,
      'monthly_emi' => CollectionLoanType.monthlyEmi,
      'weekly_emi' => CollectionLoanType.weeklyEmi,
      _ => throw const FormatException('Invalid collection type.'),
    };

class CollectionAllocation {
  const CollectionAllocation({
    required this.periodNumber,
    required this.interest,
    required this.principal,
  });

  final int? periodNumber;
  final double interest;
  final double principal;

  double get total => roundCollectionMoney(interest + principal);

  Map<String, Object?> toJson() => {
        'periodNumber': periodNumber,
        'interest': interest,
        'principal': principal,
      };

  factory CollectionAllocation.fromJson(Map<String, Object?> json) {
    final periodNumber = json['periodNumber'];
    final interest = json['interest'];
    final principal = json['principal'];
    if ((periodNumber != null && (periodNumber is! int || periodNumber < 1)) ||
        interest is! num ||
        !interest.isFinite ||
        interest < 0 ||
        principal is! num ||
        !principal.isFinite ||
        principal < 0 ||
        (interest == 0 && principal == 0)) {
      throw const FormatException('Invalid collection allocation.');
    }
    return CollectionAllocation(
      periodNumber: periodNumber as int?,
      interest: interest.toDouble(),
      principal: principal.toDouble(),
    );
  }
}

class CollectionPayment {
  const CollectionPayment({
    required this.id,
    required this.amount,
    required this.date,
    required this.category,
    required this.allocations,
  });

  final String id;
  final double amount;
  final DateTime date;
  final String category;
  final List<CollectionAllocation> allocations;

  double get interestComponent => roundCollectionMoney(
        allocations.fold<double>(0, (sum, item) => sum + item.interest),
      );

  double get principalComponent => roundCollectionMoney(
        allocations.fold<double>(0, (sum, item) => sum + item.principal),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'amount': amount,
        'date': _dateKey(date),
        'category': category,
        'allocations': allocations.map((item) => item.toJson()).toList(),
      };

  factory CollectionPayment.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final amount = json['amount'];
    final date = json['date'];
    final category = json['category'];
    final rawAllocations = json['allocations'];
    if (id is! String ||
        id.trim().isEmpty ||
        amount is! num ||
        !amount.isFinite ||
        amount <= 0 ||
        date is! String ||
        category is! String ||
        !collectionPaymentCategories.contains(category) ||
        rawAllocations is! List ||
        rawAllocations.isEmpty) {
      throw const FormatException('Invalid collection payment.');
    }
    final allocations = rawAllocations.map((item) {
      if (item is! Map) {
        throw const FormatException('Invalid collection allocation.');
      }
      return CollectionAllocation.fromJson(Map<String, Object?>.from(item));
    }).toList();
    final allocated = allocations.fold<double>(
      0,
      (sum, item) => sum + item.interest + item.principal,
    );
    if ((allocated - amount.toDouble()).abs() > 0.02 ||
        (category == 'interest' &&
            allocations.any((item) => item.periodNumber == null)) ||
        (category == 'principal' &&
            allocations.any((item) => item.periodNumber != null)) ||
        (category == 'emi' &&
            allocations.any((item) => item.periodNumber == null))) {
      throw const FormatException('Invalid collection payment allocations.');
    }
    return CollectionPayment(
      id: id,
      amount: amount.toDouble(),
      date: _parseDate(date),
      category: category,
      allocations: List.unmodifiable(allocations),
    );
  }
}

class CollectionPeriod {
  const CollectionPeriod({
    required this.number,
    required this.startDate,
    required this.dueDate,
    required this.openingPrincipal,
    required this.expectedInterest,
    required this.expectedPrincipal,
  });

  final int number;
  final DateTime startDate;
  final DateTime dueDate;
  final double openingPrincipal;
  final double expectedInterest;
  final double expectedPrincipal;

  double get expectedTotal =>
      roundCollectionMoney(expectedInterest + expectedPrincipal);
}

enum CollectionPeriodStatus {
  paid,
  partiallyPaid,
  pending,
  overdue,
}

class CollectionLoan {
  CollectionLoan({
    required this.id,
    required this.direction,
    required this.person,
    this.phone = '',
    required this.principal,
    required this.rate,
    this.ratePeriod = 'monthly',
    required this.type,
    required this.startDate,
    required this.firstDueDate,
    this.tenureInstallments = 0,
    this.note = '',
    List<CollectionPayment> payments = const [],
    this.closedAt,
  }) : payments = List.unmodifiable(payments);

  final String id;
  final String direction;
  final String person;
  final String phone;
  final double principal;
  final double rate;
  final String ratePeriod;
  final CollectionLoanType type;
  final DateTime startDate;
  final DateTime firstDueDate;
  final int tenureInstallments;
  final String note;
  final List<CollectionPayment> payments;
  final DateTime? closedAt;

  bool get isClosed => closedAt != null;

  bool get isEmi => type.isEmi;

  bool get isInterestOnly => !isEmi;

  bool get isWeekly => type.isWeekly;

  bool get isMonthly => !isWeekly;

  String get frequency => type.frequency;

  double get periodicRatePercent {
    final annual = rate;
    switch (ratePeriod) {
      case 'weekly':
        return isWeekly ? annual : annual * 52 / 12;
      case 'annual':
        return isWeekly ? annual / 52 : annual / 12;
      default:
        return isWeekly ? annual * 12 / 52 : annual;
    }
  }

  late final List<CollectionPeriod> emiSchedule = _buildEmiSchedule();

  int get periodCount => isEmi ? tenureInstallments : 0;

  double get totalCollectedInterest => roundCollectionMoney(
        payments.fold<double>(0, (sum, item) => sum + item.interestComponent),
      );

  double get totalCollectedPrincipal => roundCollectionMoney(
        payments.fold<double>(0, (sum, item) => sum + item.principalComponent),
      );

  double get totalCollected =>
      roundCollectionMoney(totalCollectedInterest + totalCollectedPrincipal);

  double get outstandingPrincipal => roundCollectionMoney(
        math.max(0, principal - totalCollectedPrincipal),
      );

  double get totalScheduledInterest => isEmi
      ? roundCollectionMoney(
          emiSchedule.fold<double>(
              0, (sum, item) => sum + item.expectedInterest),
        )
      : roundCollectionMoney(totalCollectedInterest + pendingInterest());

  double get totalScheduledRepayment => isEmi
      ? roundCollectionMoney(
          emiSchedule.fold<double>(0, (sum, item) => sum + item.expectedTotal),
        )
      : 0;

  double get outstandingBalance {
    if (isEmi) {
      return roundCollectionMoney(
        emiSchedule.fold<double>(
          0,
          (sum, item) => sum + remainingForPeriod(item.number),
        ),
      );
    }
    return roundCollectionMoney(
      outstandingPrincipal + pendingInterest(),
    );
  }

  double get overdueInterest {
    final today = _midnight(DateTime.now());
    if (isEmi) {
      return roundCollectionMoney(
        emiSchedule.fold<double>(0, (sum, item) {
          if (!item.dueDate.isBefore(today)) return sum;
          return sum + remainingInterestForPeriod(item.number);
        }),
      );
    }
    return roundCollectionMoney(
      scheduleThrough(today).fold<double>(0, (sum, item) {
        if (!item.dueDate.isBefore(today)) return sum;
        return sum + remainingInterestForPeriod(item.number);
      }),
    );
  }

  double paidForPeriod(int number) => roundCollectionMoney(
        payments.fold<double>(0, (sum, payment) {
          return sum +
              payment.allocations
                  .where((item) => item.periodNumber == number)
                  .fold<double>(0, (inner, item) => inner + item.total);
        }),
      );

  double interestPaidForPeriod(int number) => roundCollectionMoney(
        payments.fold<double>(0, (sum, payment) {
          return sum +
              payment.allocations
                  .where((item) => item.periodNumber == number)
                  .fold<double>(0, (inner, item) => inner + item.interest);
        }),
      );

  double principalPaidForPeriod(int number) => roundCollectionMoney(
        payments.fold<double>(0, (sum, payment) {
          return sum +
              payment.allocations
                  .where((item) => item.periodNumber == number)
                  .fold<double>(0, (inner, item) => inner + item.principal);
        }),
      );

  double remainingForPeriod(int number) {
    final item = periodFor(number);
    if (isEmi) {
      return roundCollectionMoney(
        math.max(0, item.expectedTotal - paidForPeriod(number)),
      );
    }
    return remainingInterestForPeriod(number);
  }

  double remainingInterestForPeriod(int number) {
    final item = periodFor(number);
    return roundCollectionMoney(
      math.max(0, item.expectedInterest - interestPaidForPeriod(number)),
    );
  }

  double remainingPrincipalForPeriod(int number) {
    if (!isEmi) return 0;
    final item = periodFor(number);
    return roundCollectionMoney(
      math.max(0, item.expectedPrincipal - principalPaidForPeriod(number)),
    );
  }

  CollectionPeriod periodFor(int number) {
    if (number < 1) {
      throw ArgumentError.value(number, 'number', 'Period must be positive.');
    }
    if (isEmi) {
      if (number > emiSchedule.length) {
        throw RangeError.range(number, 1, emiSchedule.length, 'number');
      }
      return emiSchedule[number - 1];
    }
    return _interestPeriod(number);
  }

  CollectionPeriod? get nextUnpaidPeriod {
    if (isEmi) {
      for (final item in emiSchedule) {
        if (remainingForPeriod(item.number) > collectionTolerance) return item;
      }
      return null;
    }
    if (rate <= 0) {
      for (var number = 1; number <= 5200; number++) {
        final item = _interestPeriod(number);
        if (item.startDate.isAfter(_midnight(DateTime.now()))) break;
        if (remainingInterestForPeriod(number) > collectionTolerance) {
          return item;
        }
      }
      return null;
    }
    for (var number = 1; number <= 5200; number++) {
      if (remainingInterestForPeriod(number) > collectionTolerance) {
        return _interestPeriod(number);
      }
    }
    return null;
  }

  CollectionPeriod? oldestUnpaidPeriod(
      {DateTime? today, bool dueOnly = false}) {
    final day = _midnight(today ?? DateTime.now());
    if (isEmi) {
      for (final item in emiSchedule) {
        if (remainingForPeriod(item.number) <= collectionTolerance) continue;
        if (dueOnly && item.dueDate.isAfter(day)) continue;
        return item;
      }
      return null;
    }
    for (var number = 1; number <= 5200; number++) {
      final item = _interestPeriod(number);
      if (item.startDate.isAfter(day)) break;
      if (remainingInterestForPeriod(number) <= collectionTolerance) continue;
      if (dueOnly && item.dueDate.isAfter(day)) continue;
      return item;
    }
    return null;
  }

  DateTime? get nextCollectionDate => nextUnpaidPeriod?.dueDate;

  double get nextCollectionAmount {
    final item = nextUnpaidPeriod;
    return item == null ? 0 : remainingForPeriod(item.number);
  }

  CollectionPeriodStatus statusForPeriod(int number, {DateTime? today}) {
    final item = periodFor(number);
    final day = _midnight(today ?? DateTime.now());
    final remaining = remainingForPeriod(number);
    if (remaining <= collectionTolerance) {
      return CollectionPeriodStatus.paid;
    }
    if (item.dueDate.isBefore(day)) {
      return CollectionPeriodStatus.overdue;
    }
    if (paidForPeriod(number) > collectionTolerance) {
      return CollectionPeriodStatus.partiallyPaid;
    }
    return CollectionPeriodStatus.pending;
  }

  bool isPartialFor(int number) {
    final paid = paidForPeriod(number);
    return paid > collectionTolerance &&
        remainingForPeriod(number) > collectionTolerance;
  }

  bool isAdvancePaymentFor(int number, {DateTime? today}) {
    final item = periodFor(number);
    final day = _midnight(today ?? DateTime.now());
    return paidForPeriod(number) > collectionTolerance &&
        item.dueDate.isAfter(day);
  }

  double overdueAmount({DateTime? today}) {
    final day = _midnight(today ?? DateTime.now());
    if (isEmi) {
      return roundCollectionMoney(
        emiSchedule.fold<double>(0, (sum, item) {
          if (!item.dueDate.isBefore(day)) return sum;
          return sum + remainingForPeriod(item.number);
        }),
      );
    }
    return roundCollectionMoney(
      scheduleThrough(day).fold<double>(0, (sum, item) {
        if (!item.dueDate.isBefore(day)) return sum;
        return sum + remainingInterestForPeriod(item.number);
      }),
    );
  }

  int overdueCount({DateTime? today}) {
    final day = _midnight(today ?? DateTime.now());
    if (isEmi) {
      return emiSchedule
          .where((item) =>
              item.dueDate.isBefore(day) &&
              remainingForPeriod(item.number) > collectionTolerance)
          .length;
    }
    return scheduleThrough(day)
        .where((item) =>
            item.dueDate.isBefore(day) &&
            remainingInterestForPeriod(item.number) > collectionTolerance)
        .length;
  }

  double pendingInterest({DateTime? today}) {
    final day = _midnight(today ?? DateTime.now());
    if (isEmi) {
      return roundCollectionMoney(
        emiSchedule.fold<double>(0, (sum, item) {
          if (item.dueDate.isAfter(day)) return sum;
          return sum + remainingInterestForPeriod(item.number);
        }),
      );
    }
    return roundCollectionMoney(
      scheduleThrough(day).fold<double>(0, (sum, item) {
        if (!item.dueDate.isAfter(day)) {
          return sum + remainingInterestForPeriod(item.number);
        }
        return sum + _accruedRemaining(item, day);
      }),
    );
  }

  double accruedInterest({DateTime? today}) {
    final day = _midnight(today ?? DateTime.now());
    if (isEmi) {
      return roundCollectionMoney(
        emiSchedule.fold<double>(0, (sum, item) {
          if (!item.dueDate.isAfter(day) || item.startDate.isAfter(day)) {
            return sum;
          }
          return sum + _accruedRemaining(item, day);
        }),
      );
    }
    return roundCollectionMoney(
      scheduleThrough(day).fold<double>(0, (sum, item) {
        if (!item.dueDate.isAfter(day) || item.startDate.isAfter(day)) {
          return sum;
        }
        return sum + _accruedRemaining(item, day);
      }),
    );
  }

  double settlementOutstanding({DateTime? today}) {
    final day = _midnight(today ?? DateTime.now());
    if (isEmi) {
      return roundCollectionMoney(
        emiSchedule.fold<double>(
          0,
          (sum, item) => sum + remainingForPeriod(item.number),
        ),
      );
    }
    return roundCollectionMoney(
        outstandingPrincipal + pendingInterest(today: day));
  }

  double totalOutstanding({DateTime? today}) {
    final day = _midnight(today ?? DateTime.now());
    if (isEmi) return settlementOutstanding(today: day);
    return roundCollectionMoney(
      outstandingPrincipal + overdueAmount(today: day),
    );
  }

  double settlementAmount({DateTime? today}) =>
      settlementOutstanding(today: today);

  bool canClose({DateTime? today}) =>
      !isClosed && settlementOutstanding(today: today) <= collectionTolerance;

  bool get isSettled => settlementOutstanding() <= collectionTolerance;

  bool hasPartialPayments({DateTime? today}) =>
      payments.isNotEmpty &&
      totalOutstanding(today: today) > collectionTolerance;

  List<CollectionPeriod> scheduleThrough(DateTime date, {int extra = 0}) {
    if (isEmi) return emiSchedule;
    final day = _midnight(date);
    final result = <CollectionPeriod>[];
    for (var number = 1; number <= 5200; number++) {
      final item = _interestPeriod(number);
      if (item.startDate.isAfter(day)) break;
      result.add(item);
    }
    if (result.isEmpty) result.add(_interestPeriod(1));
    var last = result.last.number;
    for (var index = 0; index < extra; index++) {
      last += 1;
      result.add(_interestPeriod(last));
    }
    return result;
  }

  List<CollectionPeriod> notificationPeriods({
    DateTime? today,
    int limit = 12,
  }) {
    final day = _midnight(today ?? DateTime.now());
    if (isEmi) {
      return emiSchedule
          .where(
              (item) => remainingForPeriod(item.number) > collectionTolerance)
          .take(limit)
          .toList();
    }
    final result = <CollectionPeriod>[];
    var number = 1;
    if (rate > 0) {
      final dueOnly = oldestUnpaidPeriod(today: day, dueOnly: true);
      if (dueOnly != null) {
        number = dueOnly.number;
      } else {
        for (var candidate = 1; candidate <= 5200; candidate++) {
          final item = _interestPeriod(candidate);
          if (!item.dueDate.isBefore(day)) {
            number = candidate;
            break;
          }
        }
      }
    }
    for (var index = 0; index < limit; index++) {
      final item = _interestPeriod(number + index);
      if (rate <= 0 ||
          remainingInterestForPeriod(item.number) <= collectionTolerance) {
        continue;
      }
      result.add(item);
    }
    return result;
  }

  CollectionLoan copyWith({
    String? direction,
    String? person,
    String? phone,
    double? principal,
    double? rate,
    String? ratePeriod,
    CollectionLoanType? type,
    DateTime? startDate,
    DateTime? firstDueDate,
    int? tenureInstallments,
    String? note,
    List<CollectionPayment>? payments,
    DateTime? closedAt,
  }) =>
      CollectionLoan(
        id: id,
        direction: direction ?? this.direction,
        person: person ?? this.person,
        phone: phone ?? this.phone,
        principal: principal ?? this.principal,
        rate: rate ?? this.rate,
        ratePeriod: ratePeriod ?? this.ratePeriod,
        type: type ?? this.type,
        startDate: startDate ?? this.startDate,
        firstDueDate: firstDueDate ?? this.firstDueDate,
        tenureInstallments: tenureInstallments ?? this.tenureInstallments,
        note: note ?? this.note,
        payments: payments ?? this.payments,
        closedAt: closedAt ?? this.closedAt,
      );

  CollectionLoan withPayment(CollectionPayment payment) =>
      copyWith(payments: [...payments, payment]);

  CollectionLoan withoutPayment(String paymentId) => copyWith(
        payments: payments.where((payment) => payment.id != paymentId).toList(),
      );

  CollectionLoan close(DateTime date) => copyWith(closedAt: date);

  CollectionLoan recordPayment({
    required String id,
    required double amount,
    required DateTime date,
    required String category,
    int? periodNumber,
  }) {
    if (isClosed) {
      throw StateError('A closed collection loan cannot receive payments.');
    }
    final day = _midnight(date);
    if (day.isBefore(startDate)) {
      throw ArgumentError('Payment date cannot be before the loan start date.');
    }
    final requested = roundCollectionMoney(amount);
    if (requested <= 0) {
      throw ArgumentError('Payment amount must be greater than zero.');
    }
    final allocations =
        _buildAllocations(requested, day, category, periodNumber);
    final total = roundCollectionMoney(
      allocations.fold<double>(
        0,
        (sum, item) => sum + item.interest + item.principal,
      ),
    );
    if ((total - requested).abs() > 0.02) {
      throw ArgumentError('Payment exceeds the outstanding balance.');
    }
    final payment = CollectionPayment(
      id: id,
      amount: total,
      date: day,
      category: category,
      allocations: List.unmodifiable(allocations),
    );
    return withPayment(payment);
  }

  CollectionLoan settle({
    required String id,
    DateTime? date,
  }) {
    final day = _midnight(date ?? DateTime.now());
    final amount = settlementAmount(today: day);
    if (amount <= collectionTolerance) {
      throw StateError('This collection loan is already settled.');
    }
    return recordPayment(
      id: id,
      amount: amount,
      date: day,
      category: 'settlement',
    );
  }

  Map<String, Object?> toJson() => {
        'loanType': 'collection',
        'id': id,
        'direction': direction,
        'person': person,
        'phone': phone,
        'principal': principal,
        'rate': rate,
        'ratePeriod': ratePeriod,
        'collectionType': type.key,
        'startDate': _dateKey(startDate),
        'firstDueDate': _dateKey(firstDueDate),
        'tenureInstallments': tenureInstallments,
        'note': note,
        'closedAt': closedAt == null ? null : _dateKey(closedAt!),
        'payments': payments.map((payment) => payment.toJson()).toList(),
      };

  factory CollectionLoan.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final direction = json['direction'];
    final person = json['person'];
    final phone = json['phone'];
    final principal = json['principal'];
    final rate = json['rate'];
    final ratePeriod = json['ratePeriod'] ?? 'monthly';
    final collectionType = json['collectionType'];
    final startDate = json['startDate'];
    final firstDueDate = json['firstDueDate'];
    final tenureInstallments = json['tenureInstallments'] ?? 0;
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
        ratePeriod is! String ||
        !collectionRatePeriods.contains(ratePeriod) ||
        collectionType is! String ||
        !collectionTypeKeys.contains(collectionType) ||
        startDate is! String ||
        firstDueDate is! String ||
        tenureInstallments is! int ||
        tenureInstallments < 0 ||
        tenureInstallments > 5200 ||
        note is! String ||
        (rawClosedAt != null && rawClosedAt is! String) ||
        rawPayments is! List) {
      throw const FormatException('Invalid collection loan record.');
    }
    final parsedStartDate = _parseDate(startDate);
    final parsedFirstDueDate = _parseDate(firstDueDate);
    final parsedClosedAt =
        rawClosedAt == null ? null : _parseDate(rawClosedAt as String);
    final type = collectionTypeFromKey(collectionType);
    if (parsedFirstDueDate.isBefore(parsedStartDate) ||
        (type.isEmi && tenureInstallments < 1) ||
        (parsedClosedAt != null && parsedClosedAt.isBefore(parsedStartDate))) {
      throw const FormatException('Invalid collection loan dates.');
    }
    final payments = rawPayments.map((item) {
      if (item is! Map) {
        throw const FormatException('Invalid collection payment record.');
      }
      return CollectionPayment.fromJson(Map<String, Object?>.from(item));
    }).toList();
    if (payments.map((payment) => payment.id).toSet().length !=
        payments.length) {
      throw const FormatException('Duplicate collection payment IDs.');
    }
    final loan = CollectionLoan(
      id: id,
      direction: direction as String,
      person: person.trim(),
      phone: phone.trim(),
      principal: principal.toDouble(),
      rate: rate.toDouble(),
      ratePeriod: ratePeriod,
      type: type,
      startDate: parsedStartDate,
      firstDueDate: parsedFirstDueDate,
      tenureInstallments: tenureInstallments,
      note: note.trim(),
      payments: payments,
      closedAt: parsedClosedAt,
    );
    var principalCollected = 0.0;
    for (final payment in payments) {
      if (payment.date.isBefore(parsedStartDate) ||
          (parsedClosedAt != null && payment.date.isAfter(parsedClosedAt))) {
        throw const FormatException('Invalid collection payment date.');
      }
      if (!type.isEmi && payment.category == 'emi') {
        throw const FormatException('Invalid collection payment category.');
      }
      if (type.isEmi &&
          (payment.category == 'interest' || payment.category == 'principal')) {
        throw const FormatException('Invalid collection payment category.');
      }
      for (final allocation in payment.allocations) {
        final periodNumber = allocation.periodNumber;
        if (type.isEmi) {
          if (periodNumber == null ||
              periodNumber < 1 ||
              periodNumber > tenureInstallments) {
            throw const FormatException('Invalid collection period number.');
          }
        } else if (periodNumber != null && periodNumber < 1) {
          throw const FormatException('Invalid collection period number.');
        }
        principalCollected += allocation.principal;
      }
    }
    if (principalCollected > principal.toDouble() + collectionTolerance) {
      throw const FormatException('Principal collection exceeds the loan.');
    }
    if (type.isEmi) {
      for (var number = 1; number <= loan.emiSchedule.length; number++) {
        final item = loan.emiSchedule[number - 1];
        if (loan.paidForPeriod(number) > item.expectedTotal + 0.02 ||
            loan.interestPaidForPeriod(number) > item.expectedInterest + 0.02 ||
            loan.principalPaidForPeriod(number) >
                item.expectedPrincipal + 0.02) {
          throw const FormatException('EMI collection exceeds the instalment.');
        }
      }
    }
    if (loan.isClosed &&
        loan.settlementOutstanding(today: loan.closedAt) >
            collectionTolerance) {
      throw const FormatException('A closed collection loan must be settled.');
    }
    return loan;
  }

  List<CollectionPeriod> _buildEmiSchedule() {
    if (!isEmi) return const [];
    final count = tenureInstallments;
    if (count < 1) return const [];
    final periodRate = periodicRatePercent / 100;
    final items = <CollectionPeriod>[];
    var balance = principal;
    if (rate > 0) {
      final factor = math.pow(1 + periodRate, count).toDouble();
      final rawEmi = periodRate <= 0
          ? principal / count
          : principal * periodRate * factor / (factor - 1);
      final emi = roundCollectionMoney(rawEmi);
      for (var number = 1; number <= count; number++) {
        final opening = roundCollectionMoney(balance);
        final interest = roundCollectionMoney(balance * periodRate);
        final isLast = number == count;
        var principalPart =
            isLast ? opening : roundCollectionMoney(emi - interest);
        if (principalPart > opening) principalPart = opening;
        if (principalPart < 0) principalPart = 0;
        final closing =
            roundCollectionMoney(math.max(0, opening - principalPart));
        items.add(
          CollectionPeriod(
            number: number,
            startDate: _periodStart(number),
            dueDate: _periodDueDate(number),
            openingPrincipal: opening,
            expectedInterest: interest,
            expectedPrincipal: principalPart,
          ),
        );
        balance = closing;
      }
      return items;
    }

    final totalInterest = roundCollectionMoney(
      principal * periodicRatePercent / 100 * count,
    );
    final flatEmi = roundCollectionMoney((principal + totalInterest) / count);
    final periodInterest =
        roundCollectionMoney(principal * periodicRatePercent / 100);
    for (var number = 1; number <= count; number++) {
      final opening = roundCollectionMoney(balance);
      final interest = periodInterest;
      final isLast = number == count;
      var principalPart =
          isLast ? opening : roundCollectionMoney(flatEmi - interest);
      if (principalPart > opening) principalPart = opening;
      if (principalPart < 0) principalPart = 0;
      final closing =
          roundCollectionMoney(math.max(0, opening - principalPart));
      items.add(
        CollectionPeriod(
          number: number,
          startDate: _periodStart(number),
          dueDate: _periodDueDate(number),
          openingPrincipal: opening,
          expectedInterest: interest,
          expectedPrincipal: principalPart,
        ),
      );
      balance = closing;
    }
    return items;
  }

  CollectionPeriod _interestPeriod(int number) {
    final dueDate = _periodDueDate(number);
    final startDate = _periodStart(number);
    final repaid = roundCollectionMoney(_principalPaidOnOrBefore(startDate));
    final opening = roundCollectionMoney(math.max(0, principal - repaid));
    final interest = roundCollectionMoney(opening * periodicRatePercent / 100);
    return CollectionPeriod(
      number: number,
      startDate: startDate,
      dueDate: dueDate,
      openingPrincipal: opening,
      expectedInterest: interest,
      expectedPrincipal: 0,
    );
  }

  DateTime _periodDueDate(int number) {
    if (isWeekly) {
      return firstDueDate.add(Duration(days: 7 * (number - 1)));
    }
    return _addCalendarMonths(firstDueDate, number - 1);
  }

  DateTime _periodStart(int number) {
    if (number <= 1) return startDate;
    return _periodDueDate(number - 1).add(const Duration(days: 1));
  }

  double _principalPaidOnOrBefore(DateTime date) => payments.fold<double>(
        0,
        (sum, payment) {
          if (payment.date.isAfter(date)) return sum;
          return sum +
              payment.allocations.fold<double>(
                0,
                (inner, item) => inner + item.principal,
              );
        },
      );

  double _accruedRemaining(CollectionPeriod item, DateTime day) {
    if (day.isBefore(item.startDate) || item.expectedInterest <= 0) return 0;
    final totalDays = item.dueDate.difference(item.startDate).inDays + 1;
    final elapsedDays = day.difference(item.startDate).inDays + 1;
    final ratio = math.min(1.0, math.max(0.0, elapsedDays / totalDays));
    final accrued = item.expectedInterest * ratio;
    return roundCollectionMoney(
      math.max(0, accrued - interestPaidForPeriod(item.number)),
    );
  }

  double _settlementInterestRemaining(CollectionPeriod item, DateTime day) {
    if (item.startDate.isAfter(day)) return 0;
    if (!item.dueDate.isAfter(day)) {
      return remainingInterestForPeriod(item.number);
    }
    return _accruedRemaining(item, day);
  }

  List<CollectionAllocation> _buildAllocations(
    double amount,
    DateTime date,
    String category,
    int? periodNumber,
  ) {
    switch (category) {
      case 'interest':
        if (isEmi) {
          throw ArgumentError('Use EMI payments for EMI collection loans.');
        }
        final number =
            periodNumber ?? _defaultInterestPeriod(date, dueOnly: false);
        final remaining = remainingInterestForPeriod(number);
        if (amount > remaining + collectionTolerance) {
          throw ArgumentError('Interest payment exceeds the period balance.');
        }
        return [
          CollectionAllocation(
            periodNumber: number,
            interest: math.min(amount, remaining),
            principal: 0,
          ),
        ];
      case 'principal':
        if (isEmi) {
          throw ArgumentError('Principal is repaid with EMI instalments.');
        }
        if (amount > outstandingPrincipal + collectionTolerance) {
          throw ArgumentError(
              'Principal payment exceeds the outstanding loan.');
        }
        return [
          CollectionAllocation(
            periodNumber: null,
            interest: 0,
            principal: amount,
          ),
        ];
      case 'emi':
        if (!isEmi) {
          throw ArgumentError(
              'EMI payments are only for EMI collection loans.');
        }
        final start = periodNumber ?? _firstUnpaidEmiPeriod();
        return _allocateEmi(amount, start);
      case 'settlement':
        if (isEmi) return _allocateEmi(amount, 1);
        return _allocateInterestSettlement(amount, date);
      default:
        throw ArgumentError.value(category, 'category', 'Invalid category.');
    }
  }

  int _defaultInterestPeriod(DateTime date, {required bool dueOnly}) {
    final day = _midnight(date);
    final oldest = oldestUnpaidPeriod(today: day, dueOnly: dueOnly);
    if (oldest != null) return oldest.number;
    for (var number = 1; number <= 5200; number++) {
      final item = _interestPeriod(number);
      if (!item.dueDate.isBefore(day)) return number;
    }
    return 1;
  }

  int _firstUnpaidEmiPeriod() {
    for (final item in emiSchedule) {
      if (remainingForPeriod(item.number) > collectionTolerance) {
        return item.number;
      }
    }
    return tenureInstallments;
  }

  List<CollectionAllocation> _allocateEmi(double amount, int start) {
    var left = roundCollectionMoney(amount);
    final allocations = <CollectionAllocation>[];
    for (var number = start; number <= emiSchedule.length; number++) {
      if (left <= collectionTolerance) break;
      final interest = remainingInterestForPeriod(number);
      final principal = remainingPrincipalForPeriod(number);
      if (interest <= collectionTolerance && principal <= collectionTolerance) {
        continue;
      }
      final interestPart = roundCollectionMoney(math.min(left, interest));
      left = roundCollectionMoney(left - interestPart);
      final principalPart = roundCollectionMoney(math.min(left, principal));
      left = roundCollectionMoney(left - principalPart);
      if (interestPart > collectionTolerance ||
          principalPart > collectionTolerance) {
        allocations.add(
          CollectionAllocation(
            periodNumber: number,
            interest: interestPart,
            principal: principalPart,
          ),
        );
      }
    }
    if (left > collectionTolerance) {
      throw ArgumentError('EMI payment exceeds the outstanding balance.');
    }
    return allocations;
  }

  List<CollectionAllocation> _allocateInterestSettlement(
    double amount,
    DateTime date,
  ) {
    var left = roundCollectionMoney(amount);
    final allocations = <CollectionAllocation>[];
    for (var number = 1; number <= 5200; number++) {
      if (left <= collectionTolerance) break;
      final item = _interestPeriod(number);
      if (item.startDate.isAfter(date)) break;
      final remaining = _settlementInterestRemaining(item, date);
      if (remaining <= collectionTolerance) continue;
      final interestPart = roundCollectionMoney(math.min(left, remaining));
      left = roundCollectionMoney(left - interestPart);
      allocations.add(
        CollectionAllocation(
          periodNumber: number,
          interest: interestPart,
          principal: 0,
        ),
      );
    }
    if (left > collectionTolerance) {
      final principalPart =
          roundCollectionMoney(math.min(left, outstandingPrincipal));
      left = roundCollectionMoney(left - principalPart);
      if (principalPart > collectionTolerance) {
        allocations.add(
          CollectionAllocation(
            periodNumber: null,
            interest: 0,
            principal: principalPart,
          ),
        );
      }
    }
    if (left > collectionTolerance) {
      throw ArgumentError('Settlement exceeds the outstanding balance.');
    }
    return allocations;
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
