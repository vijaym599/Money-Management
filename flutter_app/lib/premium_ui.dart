import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'loan_reminder.dart';
import 'models.dart';

const _brandBlue = Color(0xFF1769FF);
const _brandNavy = Color(0xFF081B3A);
const _softBlue = Color(0xFFEAF1FF);
const _success = Color(0xFF16A085);
const _warning = Color(0xFFF59E0B);

class PremiumSplash extends StatelessWidget {
  const PremiumSplash({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_brandNavy, Color(0xFF123B8F), _brandBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: .86, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutBack,
              builder: (context, value, child) => Transform.scale(
                scale: value,
                child: child,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 28,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: _brandBlue,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'கடன் கணக்கு',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.4,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Your money. Clearly managed.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .72),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 36),
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class PremiumAppShell extends StatelessWidget {
  const PremiumAppShell({
    required this.loans,
    required this.isTamil,
    required this.darkMode,
    required this.profileName,
    required this.profilePhone,
    required this.loadError,
    required this.selectedPage,
    required this.onPageChanged,
    required this.onAddLoan,
    required this.onEditLoan,
    required this.onPayment,
    required this.onEditPhone,
    required this.onSharePdf,
    required this.onDelete,
    required this.onDetails,
    required this.onLanguageChanged,
    required this.onThemeChanged,
    required this.onProfileSaved,
    required this.appLockEnabled,
    required this.biometricEnabled,
    required this.biometricAvailable,
    required this.notificationsEnabled,
    required this.onConfigureSecurity,
    required this.onNotificationsChanged,
    required this.onBackup,
    super.key,
  });

  final List<Loan> loans;
  final bool isTamil;
  final bool darkMode;
  final String profileName;
  final String profilePhone;
  final String? loadError;
  final int selectedPage;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onAddLoan;
  final ValueChanged<Loan> onEditLoan;
  final ValueChanged<Loan> onPayment;
  final ValueChanged<Loan> onEditPhone;
  final ValueChanged<Loan> onSharePdf;
  final ValueChanged<Loan> onDelete;
  final void Function(BuildContext context, Loan loan) onDetails;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<bool> onThemeChanged;
  final Future<void> Function(String name, String phone) onProfileSaved;
  final bool appLockEnabled;
  final bool biometricEnabled;
  final bool biometricAvailable;
  final bool notificationsEnabled;
  final VoidCallback onConfigureSecurity;
  final ValueChanged<bool> onNotificationsChanged;
  final VoidCallback onBackup;

  String _tr(String ta, String en) => isTamil ? ta : en;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _DashboardPage(
        loans: loans,
        isTamil: isTamil,
        profileName: profileName,
        loadError: loadError,
        onAddLoan: onAddLoan,
        onEditLoan: onEditLoan,
        onPayment: onPayment,
        onEditPhone: onEditPhone,
        onSharePdf: onSharePdf,
        onDetails: onDetails,
        onOpenLoans: () => onPageChanged(1),
        onOpenPeople: () => onPageChanged(2),
        onBackup: onBackup,
      ),
      _LoansPage(
        loans: loans,
        isTamil: isTamil,
        onAddLoan: onAddLoan,
        onEditLoan: onEditLoan,
        onPayment: onPayment,
        onEditPhone: onEditPhone,
        onSharePdf: onSharePdf,
        onDelete: onDelete,
        onDetails: onDetails,
      ),
      _PeoplePage(
        loans: loans,
        isTamil: isTamil,
        onEditLoan: onEditLoan,
        onPayment: onPayment,
        onEditPhone: onEditPhone,
        onSharePdf: onSharePdf,
        onDetails: onDetails,
      ),
      _ReportsPage(loans: loans, isTamil: isTamil),
      _ProfilePage(
        loans: loans,
        isTamil: isTamil,
        darkMode: darkMode,
        profileName: profileName,
        profilePhone: profilePhone,
        onLanguageChanged: onLanguageChanged,
        onThemeChanged: onThemeChanged,
        onProfileSaved: onProfileSaved,
        appLockEnabled: appLockEnabled,
        biometricEnabled: biometricEnabled,
        biometricAvailable: biometricAvailable,
        notificationsEnabled: notificationsEnabled,
        onConfigureSecurity: onConfigureSecurity,
        onNotificationsChanged: onNotificationsChanged,
        onBackup: onBackup,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 900;
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                if (useRail)
                  _PremiumRail(
                    selectedIndex: selectedPage,
                    isTamil: isTamil,
                    onChanged: onPageChanged,
                  ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(.025, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(selectedPage),
                      child: pages[selectedPage.clamp(0, pages.length - 1)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: selectedPage == 0 || selectedPage == 1
              ? FloatingActionButton.extended(
                  onPressed: onAddLoan,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(_tr('புதிய கடன்', 'New loan')),
                )
              : null,
          bottomNavigationBar: useRail
              ? null
              : _PremiumNavigationBar(
                  selectedIndex: selectedPage,
                  isTamil: isTamil,
                  onChanged: onPageChanged,
                ),
        );
      },
    );
  }
}

class _DashboardPage extends StatelessWidget {
  const _DashboardPage({
    required this.loans,
    required this.isTamil,
    required this.profileName,
    required this.loadError,
    required this.onAddLoan,
    required this.onEditLoan,
    required this.onPayment,
    required this.onEditPhone,
    required this.onSharePdf,
    required this.onDetails,
    required this.onOpenLoans,
    required this.onOpenPeople,
    required this.onBackup,
  });

  final List<Loan> loans;
  final bool isTamil;
  final String profileName;
  final String? loadError;
  final VoidCallback onAddLoan;
  final ValueChanged<Loan> onEditLoan;
  final ValueChanged<Loan> onPayment;
  final ValueChanged<Loan> onEditPhone;
  final ValueChanged<Loan> onSharePdf;
  final void Function(BuildContext, Loan) onDetails;
  final VoidCallback onOpenLoans;
  final VoidCallback onOpenPeople;
  final VoidCallback onBackup;

  String _tr(String ta, String en) => isTamil ? ta : en;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final lent = loans
        .where((loan) => loan.direction == 'given')
        .fold<double>(0, (sum, loan) => sum + loan.outstanding);
    final borrowed = loans
        .where((loan) => loan.direction == 'taken')
        .fold<double>(0, (sum, loan) => sum + loan.outstanding);
    final overdue = loans.fold<double>(
      0,
      (sum, loan) => sum + loan.overdueInterest(today: now),
    );
    final dueCount =
        loans.where((loan) => loan.overdueInterest(today: now) > .009).length;
    final recentLoans = loans.take(3).toList();
    final entries = _paymentEntries(loans).take(4).toList();

    return _PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopHeader(
            title: profileName.isEmpty
                ? _tr('வணக்கம் 👋', 'Welcome back 👋')
                : _tr('வணக்கம், $profileName', 'Welcome, $profileName'),
            subtitle:
                DateFormat('EEEE, d MMMM', isTamil ? 'ta' : 'en').format(now),
            trailing: _NotificationButton(
              loans: loans,
              isTamil: isTamil,
              count: dueCount,
            ),
          ),
          if (loadError != null) ...[
            const SizedBox(height: 14),
            _InlineNotice(text: loadError!),
          ],
          const SizedBox(height: 20),
          _BalanceHero(
            lent: lent,
            borrowed: borrowed,
            overdue: overdue,
            isTamil: isTamil,
          ),
          const SizedBox(height: 26),
          _ResponsiveSummaryGrid(
            children: [
              _MetricCard(
                label: _tr('கொடுத்த நிலுவை', 'Total lent'),
                value: _money(lent),
                icon: Icons.call_made_rounded,
                color: _brandBlue,
              ),
              _MetricCard(
                label: _tr('வாங்கிய நிலுவை', 'Total borrowed'),
                value: _money(borrowed),
                icon: Icons.call_received_rounded,
                color: _warning,
              ),
              _MetricCard(
                label: _tr('வட்டி நிலுவை', 'Interest overdue'),
                value: _money(overdue),
                icon: Icons.schedule_rounded,
                color: overdue > 0 ? const Color(0xFFEF5350) : _success,
              ),
            ],
          ),
          const SizedBox(height: 28),
          _SectionHeading(
            title: _tr('சமீபத்திய கடன்கள்', 'Recent loans'),
            action: loans.isEmpty ? null : _tr('அனைத்தும்', 'View all'),
            onAction: loans.isEmpty ? null : onOpenLoans,
          ),
          const SizedBox(height: 12),
          if (loans.isEmpty)
            _PremiumEmptyState(
              title: _tr('இன்னும் கடன் இல்லை', 'No loans yet'),
              subtitle: _tr(
                'முதல் கடனைச் சேர்த்து உங்கள் பணத்தை தெளிவாகக் கண்காணிக்கத் தொடங்குங்கள்.',
                'Add your first loan and start tracking your money clearly.',
              ),
              actionLabel: _tr('கடன் சேர்க்க', 'Add a loan'),
              onAction: onAddLoan,
            )
          else
            for (final loan in recentLoans)
              _PremiumLoanCard(
                loan: loan,
                isTamil: isTamil,
                onEdit: () => onEditLoan(loan),
                onPayment: () => onPayment(loan),
                onEditPhone: () => onEditPhone(loan),
                onSharePdf: () => onSharePdf(loan),
                onDetails: () => onDetails(context, loan),
              ),
          if (entries.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionHeading(
              title: _tr('சமீபத்திய பரிவர்த்தனைகள்', 'Recent transactions'),
              action: _tr('வரலாறு', 'History'),
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _TransactionsPage(
                    loans: loans,
                    isTamil: isTamil,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _SurfaceCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  for (var i = 0; i < entries.length; i++) ...[
                    _TransactionTile(
                      entry: entries[i],
                      isTamil: isTamil,
                    ),
                    if (i < entries.length - 1)
                      const Divider(height: 1, indent: 64),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 26),
          _SectionHeading(
            title: _tr('விரைவு செயல்கள்', 'Quick actions'),
          ),
          const SizedBox(height: 12),
          _QuickActions(
            isTamil: isTamil,
            hasLoans: loans.isNotEmpty,
            onAdd: onAddLoan,
            onPayment: () => _pickLoanForPayment(
              context,
              loans,
              isTamil,
              onPayment,
            ),
            onCalculator: () => _showCalculator(context, isTamil),
            onBackup: onBackup,
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _LoansPage extends StatefulWidget {
  const _LoansPage({
    required this.loans,
    required this.isTamil,
    required this.onAddLoan,
    required this.onEditLoan,
    required this.onPayment,
    required this.onEditPhone,
    required this.onSharePdf,
    required this.onDelete,
    required this.onDetails,
  });

  final List<Loan> loans;
  final bool isTamil;
  final VoidCallback onAddLoan;
  final ValueChanged<Loan> onEditLoan;
  final ValueChanged<Loan> onPayment;
  final ValueChanged<Loan> onEditPhone;
  final ValueChanged<Loan> onSharePdf;
  final ValueChanged<Loan> onDelete;
  final void Function(BuildContext, Loan) onDetails;

  @override
  State<_LoansPage> createState() => _LoansPageState();
}

class _LoansPageState extends State<_LoansPage> {
  String _query = '';
  String _filter = 'all';

  String _tr(String ta, String en) => widget.isTamil ? ta : en;

  @override
  Widget build(BuildContext context) {
    final shown = widget.loans.where((loan) {
      final directionMatches = switch (_filter) {
        'given' => loan.direction == 'given' && loan.rate > 0,
        'taken' => loan.direction == 'taken',
        'interest_free' => loan.direction == 'given' && loan.rate == 0,
        _ => true,
      };
      final queryMatches =
          loan.person.toLowerCase().contains(_query.toLowerCase());
      return directionMatches && queryMatches;
    }).toList();

    return _PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopHeader(
            title: _tr('கடன்கள்', 'Loans'),
            subtitle: _tr(
              '${widget.loans.length} செயலில் உள்ள கணக்குகள்',
              '${widget.loans.length} active accounts',
            ),
            trailing: IconButton.filledTonal(
              tooltip: _tr('புதிய கடன்', 'New loan'),
              onPressed: widget.onAddLoan,
              icon: const Icon(Icons.add_rounded),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            onChanged: (value) => setState(() => _query = value.trim()),
            decoration: InputDecoration(
              hintText: _tr('பெயரைத் தேடுங்கள்', 'Search by person'),
              prefixIcon: const Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'all',
                  label: Text(_tr('அனைத்தும்', 'All')),
                  icon: const Icon(Icons.grid_view_rounded),
                ),
                ButtonSegment(
                  value: 'given',
                  label: Text(_tr('கொடுத்தது', 'Lent')),
                  icon: const Icon(Icons.call_made_rounded),
                ),
                ButtonSegment(
                  value: 'taken',
                  label: Text(_tr('வாங்கியது', 'Borrowed')),
                  icon: const Icon(Icons.call_received_rounded),
                ),
                ButtonSegment(
                  value: 'interest_free',
                  label: Text(_tr('வட்டி இல்லாமல்', 'Interest-free')),
                  icon: const Icon(Icons.favorite_outline_rounded),
                ),
              ],
              selected: {_filter},
              onSelectionChanged: (value) =>
                  setState(() => _filter = value.first),
            ),
          ),
          const SizedBox(height: 20),
          if (_filter == 'interest_free' && shown.isNotEmpty) ...[
            _InterestFreeSummary(loans: shown, isTamil: widget.isTamil),
            const SizedBox(height: 16),
          ],
          if (shown.isEmpty)
            _PremiumEmptyState(
              title: widget.loans.isEmpty
                  ? _tr('இன்னும் கடன் இல்லை', 'No loans yet')
                  : _tr('பொருத்தமான கடன் இல்லை', 'No matching loans'),
              subtitle: widget.loans.isEmpty
                  ? _tr('புதிய கடனைச் சேர்க்கவும்.', 'Add a new loan to begin.')
                  : _tr('தேடல் அல்லது வடிகட்டியை மாற்றவும்.',
                      'Try changing the search or filter.'),
              actionLabel:
                  widget.loans.isEmpty ? _tr('புதிய கடன்', 'New loan') : null,
              onAction: widget.loans.isEmpty ? widget.onAddLoan : null,
            )
          else
            for (final loan in shown)
              _PremiumLoanCard(
                loan: loan,
                isTamil: widget.isTamil,
                showDelete: true,
                onEdit: () => widget.onEditLoan(loan),
                onPayment: () => widget.onPayment(loan),
                onEditPhone: () => widget.onEditPhone(loan),
                onSharePdf: () => widget.onSharePdf(loan),
                onDetails: () => widget.onDetails(context, loan),
                onDelete: () => widget.onDelete(loan),
              ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _PeoplePage extends StatelessWidget {
  const _PeoplePage({
    required this.loans,
    required this.isTamil,
    required this.onEditLoan,
    required this.onPayment,
    required this.onEditPhone,
    required this.onSharePdf,
    required this.onDetails,
  });

  final List<Loan> loans;
  final bool isTamil;
  final ValueChanged<Loan> onEditLoan;
  final ValueChanged<Loan> onPayment;
  final ValueChanged<Loan> onEditPhone;
  final ValueChanged<Loan> onSharePdf;
  final void Function(BuildContext, Loan) onDetails;

  String _tr(String ta, String en) => isTamil ? ta : en;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<Loan>>{};
    for (final loan in loans) {
      grouped.putIfAbsent(loan.person, () => []).add(loan);
    }
    final people = grouped.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return _PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopHeader(
            title: _tr('நபர்கள்', 'People'),
            subtitle: _tr(
              '${people.length} தொடர்புகள்',
              '${people.length} financial contacts',
            ),
          ),
          const SizedBox(height: 22),
          if (people.isEmpty)
            _PremiumEmptyState(
              title: _tr('நபர்கள் இல்லை', 'No people yet'),
              subtitle: _tr(
                'கடன் சேர்க்கும்போது நபர்கள் தானாக இங்கே தோன்றுவார்கள்.',
                'People appear here automatically when you add loans.',
              ),
            )
          else
            _SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < people.length; i++) ...[
                    _PersonTile(
                      name: people[i].key,
                      loans: people[i].value,
                      isTamil: isTamil,
                      onTap: () {
                        final personLoans = people[i].value;
                        if (personLoans.length == 1) {
                          // Most people have one account. Open it directly so
                          // People -> loan details is a two-screen flow.
                          onDetails(context, personLoans.single);
                          return;
                        }
                        _showPersonDetails(
                          context,
                          people[i].key,
                          personLoans,
                          isTamil,
                          onEditLoan,
                          onPayment,
                          onEditPhone,
                          onSharePdf,
                          onDetails,
                        );
                      },
                    ),
                    if (i < people.length - 1)
                      const Divider(height: 1, indent: 72),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _ReportsPage extends StatelessWidget {
  const _ReportsPage({required this.loans, required this.isTamil});

  final List<Loan> loans;
  final bool isTamil;

  String _tr(String ta, String en) => isTamil ? ta : en;

  @override
  Widget build(BuildContext context) {
    final lent = loans
        .where((loan) => loan.direction == 'given')
        .fold<double>(0, (sum, loan) => sum + loan.outstanding);
    final borrowed = loans
        .where((loan) => loan.direction == 'taken')
        .fold<double>(0, (sum, loan) => sum + loan.outstanding);
    final earned = loans
        .where((loan) => loan.direction == 'given')
        .expand((loan) => loan.payments)
        .where((payment) => payment.type == 'interest')
        .fold<double>(0, (sum, payment) => sum + payment.amount);
    final paid = loans
        .where((loan) => loan.direction == 'taken')
        .expand((loan) => loan.payments)
        .where((payment) => payment.type == 'interest')
        .fold<double>(0, (sum, payment) => sum + payment.amount);
    final monthly = _monthlyInterest(loans);

    return _PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopHeader(
            title: _tr('அறிக்கைகள்', 'Reports'),
            subtitle: _tr('உங்கள் நிதி நிலையின் சுருக்கம்',
                'A clear view of your financial position'),
          ),
          const SizedBox(height: 22),
          if (loans.isEmpty)
            _PremiumEmptyState(
              title: _tr('அறிக்கை தரவு இல்லை', 'No report data yet'),
              subtitle: _tr(
                'உண்மையான கடன் மற்றும் செலுத்தல் பதிவுகள் சேர்ந்ததும் அறிக்கைகள் தோன்றும்.',
                'Reports appear when real loans and payments are recorded.',
              ),
            )
          else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 680;
                final allocation = _AllocationCard(
                  lent: lent,
                  borrowed: borrowed,
                  isTamil: isTamil,
                );
                final interest = _InterestOverviewCard(
                  earned: earned,
                  paid: paid,
                  isTamil: isTamil,
                );
                return wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: allocation),
                          const SizedBox(width: 16),
                          Expanded(child: interest),
                        ],
                      )
                    : Column(
                        children: [
                          allocation,
                          const SizedBox(height: 16),
                          interest,
                        ],
                      );
              },
            ),
            const SizedBox(height: 18),
            _MonthlyChartCard(months: monthly, isTamil: isTamil),
            const SizedBox(height: 18),
            _AdvancedAnalyticsCard(loans: loans, isTamil: isTamil),
          ],
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _AdvancedAnalyticsCard extends StatelessWidget {
  const _AdvancedAnalyticsCard({
    required this.loans,
    required this.isTamil,
  });

  final List<Loan> loans;
  final bool isTamil;

  String _tr(String ta, String en) => isTamil ? ta : en;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final given = loans.where((loan) => loan.direction == 'given').toList();
    final interestCollected = given
        .expand((loan) => loan.payments)
        .where((payment) => payment.type == 'interest')
        .fold<double>(0, (sum, payment) => sum + payment.amount);
    final interestOverdue = given.fold<double>(
      0,
      (sum, loan) => sum + loan.overdueInterest(today: now),
    );
    final collectionBase = interestCollected + interestOverdue;
    final collectionRate = collectionBase <= .009
        ? 100.0
        : interestCollected / collectionBase * 100;
    final originalPrincipal =
        given.fold<double>(0, (sum, loan) => sum + loan.principal);
    final principalOutstanding =
        given.fold<double>(0, (sum, loan) => sum + loan.outstanding);
    final principalRecovery = originalPrincipal <= .009
        ? 0.0
        : (originalPrincipal - principalOutstanding) / originalPrincipal * 100;
    final overdueAccounts =
        given.where((loan) => loan.overdueInterest(today: now) > .009).length;

    var age30 = 0.0;
    var age60 = 0.0;
    var age90 = 0.0;
    for (final loan in given) {
      for (final month in loan.monthsThrough(now)) {
        final status = loan.statusFor(month, today: now);
        if (!status.isDue) continue;
        if (status.overdueDays <= 30) {
          age30 += status.remaining;
        } else if (status.overdueDays <= 60) {
          age60 += status.remaining;
        } else {
          age90 += status.remaining;
        }
      }
    }

    final personBalances = <String, double>{};
    for (final loan in given) {
      personBalances.update(
        loan.person,
        (value) => value + loan.outstanding,
        ifAbsent: () => loan.outstanding,
      );
    }
    final topPeople = personBalances.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SettingsIcon(icon: Icons.insights_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tr('மேம்பட்ட நிதி பகுப்பாய்வு', 'Advanced analytics'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text(
                      _tr('பதிவு செய்யப்பட்ட உண்மையான தரவின் அடிப்படையில்',
                          'Based on your recorded financial data'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _AnalyticsMetric(
                label: _tr('வட்டி வசூல் விகிதம்', 'Interest collection'),
                value: '${collectionRate.clamp(0, 100).toStringAsFixed(1)}%',
                color: _brandBlue,
              ),
              _AnalyticsMetric(
                label: _tr('முதல்தொகை மீட்பு', 'Principal recovery'),
                value: '${principalRecovery.clamp(0, 100).toStringAsFixed(1)}%',
                color: _success,
              ),
              _AnalyticsMetric(
                label: _tr('நிலுவை கணக்குகள்', 'Overdue accounts'),
                value: '$overdueAccounts',
                color: const Color(0xFFEF5350),
              ),
              _AnalyticsMetric(
                label: _tr('மொத்த exposure', 'Total exposure'),
                value: _money(principalOutstanding + interestOverdue),
                color: _warning,
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            _tr('வட்டி நிலுவை காலப் பகுப்பு', 'Interest overdue aging'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _AgingRow(label: '1–30 ${_tr('நாட்கள்', 'days')}', value: age30),
          _AgingRow(label: '31–60 ${_tr('நாட்கள்', 'days')}', value: age60),
          _AgingRow(label: '60+ ${_tr('நாட்கள்', 'days')}', value: age90),
          if (topPeople.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              _tr('அதிக நிலுவை உள்ள நபர்கள்', 'Top outstanding people'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < math.min(5, topPeople.length); index++)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 17,
                  backgroundColor: _softBlue,
                  child: Text('${index + 1}',
                      style: const TextStyle(
                          color: _brandBlue, fontWeight: FontWeight.w800)),
                ),
                title: Text(topPeople[index].key),
                trailing: Text(
                  _money(topPeople[index].value),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _AnalyticsMetric extends StatelessWidget {
  const _AnalyticsMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 145,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 5),
            FittedBox(
              child: Text(value,
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  )),
            ),
          ],
        ),
      );
}

class _AgingRow extends StatelessWidget {
  const _AgingRow({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(_money(value),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _ProfilePage extends StatefulWidget {
  const _ProfilePage({
    required this.loans,
    required this.isTamil,
    required this.darkMode,
    required this.profileName,
    required this.profilePhone,
    required this.onLanguageChanged,
    required this.onThemeChanged,
    required this.onProfileSaved,
    required this.appLockEnabled,
    required this.biometricEnabled,
    required this.biometricAvailable,
    required this.notificationsEnabled,
    required this.onConfigureSecurity,
    required this.onNotificationsChanged,
    required this.onBackup,
  });

  final List<Loan> loans;
  final bool isTamil;
  final bool darkMode;
  final String profileName;
  final String profilePhone;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<bool> onThemeChanged;
  final Future<void> Function(String name, String phone) onProfileSaved;
  final bool appLockEnabled;
  final bool biometricEnabled;
  final bool biometricAvailable;
  final bool notificationsEnabled;
  final VoidCallback onConfigureSecurity;
  final ValueChanged<bool> onNotificationsChanged;
  final VoidCallback onBackup;

  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage> {
  late final TextEditingController _name;
  late final TextEditingController _phone;

  String _tr(String ta, String en) => widget.isTamil ? ta : en;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profileName);
    _phone = TextEditingController(text: widget.profilePhone);
  }

  @override
  void didUpdateWidget(covariant _ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileName != widget.profileName) {
      _name.text = widget.profileName;
    }
    if (oldWidget.profilePhone != widget.profilePhone) {
      _phone.text = widget.profilePhone;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _PageScroll(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TopHeader(
              title: _tr('சுயவிவரம்', 'Profile'),
              subtitle:
                  _tr('கணக்கு மற்றும் விருப்பங்கள்', 'Account and preferences'),
            ),
            const SizedBox(height: 22),
            _ProfileHero(
              name: widget.profileName,
              phone: widget.profilePhone,
              loanCount: widget.loans.length,
              isTamil: widget.isTamil,
            ),
            const SizedBox(height: 18),
            _SettingsSection(
              title: _tr('தனிப்பட்ட விவரங்கள்', 'Personal details'),
              child: Column(
                children: [
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: _tr('உங்கள் பெயர்', 'Your name'),
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: _tr('தொலைபேசி எண்', 'Phone number'),
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () =>
                          widget.onProfileSaved(_name.text, _phone.text),
                      icon: const Icon(Icons.check_rounded),
                      label: Text(_tr('சுயவிவரத்தைச் சேமி', 'Save profile')),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SettingsSection(
              title: _tr('விருப்பங்கள்', 'Preferences'),
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    secondary:
                        const _SettingsIcon(icon: Icons.dark_mode_outlined),
                    title: Text(_tr('இருண்ட தோற்றம்', 'Dark theme')),
                    subtitle: Text(_tr('இரவு நேரத்தில் கண்களுக்கு எளிது',
                        'Comfortable viewing at night')),
                    value: widget.darkMode,
                    onChanged: widget.onThemeChanged,
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const _SettingsIcon(icon: Icons.language_rounded),
                    title: Text(_tr('மொழி', 'Language')),
                    subtitle: Text(widget.isTamil ? 'தமிழ்' : 'English'),
                    trailing: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: widget.isTamil ? 'ta' : 'en',
                        items: const [
                          DropdownMenuItem(value: 'ta', child: Text('தமிழ்')),
                          DropdownMenuItem(value: 'en', child: Text('English')),
                        ],
                        onChanged: (value) {
                          if (value != null) widget.onLanguageChanged(value);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SettingsSection(
              title: _tr('தரவு மற்றும் பாதுகாப்பு', 'Data and security'),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading:
                        const _SettingsIcon(icon: Icons.lock_outline_rounded),
                    title: Text(_tr('PIN & Biometric app lock',
                        'PIN & biometric app lock')),
                    subtitle: Text(widget.appLockEnabled
                        ? (widget.biometricEnabled
                            ? _tr(
                                'PIN மற்றும் biometric பாதுகாப்பு இயக்கப்பட்டுள்ளது',
                                'PIN and biometric protection are enabled')
                            : _tr('PIN பாதுகாப்பு இயக்கப்பட்டுள்ளது',
                                'PIN protection is enabled'))
                        : widget.biometricAvailable
                            ? _tr('App lock அமைக்கப்படவில்லை • Biometric தயார்',
                                'App lock is not configured • Biometrics ready')
                            : _tr(
                                'App lock அமைக்கப்படவில்லை • PIN பயன்படுத்தலாம்',
                                'App lock is not configured • PIN is available')),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: widget.onConfigureSecurity,
                  ),
                  const Divider(),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    secondary: const _SettingsIcon(
                      icon: Icons.notifications_active_outlined,
                    ),
                    title: Text(_tr('தவணை reminders', 'Payment reminders')),
                    subtitle: Text(_tr(
                      'Due date-க்கு ஒரு நாள் முன்பும் அன்றும் அறிவிப்பு',
                      'Notify one day before and on the due date',
                    )),
                    value: widget.notificationsEnabled,
                    onChanged: widget.onNotificationsChanged,
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const _SettingsIcon(icon: Icons.backup_outlined),
                    title: Text(
                        _tr('காப்புப் பிரதி / மீட்டமை', 'Backup / restore')),
                    subtitle: Text(_tr('JSON காப்புப் பிரதியை நிர்வகிக்கவும்',
                        'Manage your JSON backup')),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: widget.onBackup,
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const _SettingsIcon(
                      icon: Icons.phonelink_lock_outlined,
                    ),
                    title: Text(_tr('Encrypted on-device storage',
                        'Encrypted on-device storage')),
                    subtitle: Text(_tr(
                      'கடன் தரவு Android Keystore மூலம் encrypt செய்யப்படுகிறது.',
                      'Loan data is encrypted using Android Keystore.',
                    )),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      );
}

class _PremiumNavigationBar extends StatelessWidget {
  const _PremiumNavigationBar({
    required this.selectedIndex,
    required this.isTamil,
    required this.onChanged,
  });

  final int selectedIndex;
  final bool isTamil;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onChanged,
        destinations: [
          _destination(Icons.home_outlined, Icons.home_rounded,
              isTamil ? 'முகப்பு' : 'Home'),
          _destination(
              Icons.account_balance_wallet_outlined,
              Icons.account_balance_wallet_rounded,
              isTamil ? 'கடன்கள்' : 'Loans'),
          _destination(Icons.people_outline_rounded, Icons.people_rounded,
              isTamil ? 'நபர்கள்' : 'People'),
          _destination(Icons.bar_chart_outlined, Icons.bar_chart_rounded,
              isTamil ? 'அறிக்கை' : 'Reports'),
          _destination(Icons.person_outline_rounded, Icons.person_rounded,
              isTamil ? 'சுயவிவரம்' : 'Profile'),
        ],
      );

  NavigationDestination _destination(
    IconData icon,
    IconData selected,
    String label,
  ) =>
      NavigationDestination(
        icon: Icon(icon),
        selectedIcon: Icon(selected),
        label: label,
      );
}

class _PremiumRail extends StatelessWidget {
  const _PremiumRail({
    required this.selectedIndex,
    required this.isTamil,
    required this.onChanged,
  });

  final int selectedIndex;
  final bool isTamil;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            right: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: NavigationRail(
          selectedIndex: selectedIndex,
          onDestinationSelected: onChanged,
          labelType: NavigationRailLabelType.all,
          leading: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _brandBlue,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
              ),
            ),
          ),
          destinations: [
            _rail(Icons.home_rounded, isTamil ? 'முகப்பு' : 'Home'),
            _rail(Icons.account_balance_wallet_rounded,
                isTamil ? 'கடன்கள்' : 'Loans'),
            _rail(Icons.people_rounded, isTamil ? 'நபர்கள்' : 'People'),
            _rail(Icons.bar_chart_rounded, isTamil ? 'அறிக்கை' : 'Reports'),
            _rail(Icons.person_rounded, isTamil ? 'சுயவிவரம்' : 'Profile'),
          ],
        ),
      );

  NavigationRailDestination _rail(IconData icon, String label) =>
      NavigationRailDestination(icon: Icon(icon), label: Text(label));
}

class _PageScroll extends StatelessWidget {
  const _PageScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            children: [child],
          ),
        ),
      );
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              gradient:
                  const LinearGradient(colors: [_brandBlue, Color(0xFF0A3EAA)]),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.35,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      );
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({
    required this.loans,
    required this.isTamil,
    required this.count,
  });

  final List<Loan> loans;
  final bool isTamil;
  final int count;

  @override
  Widget build(BuildContext context) => Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: IconButton.filledTonal(
          tooltip: isTamil ? 'அறிவிப்புகள்' : 'Notifications',
          onPressed: () => _showNotifications(context, loans, isTamil),
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      );
}

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({
    required this.lent,
    required this.borrowed,
    required this.overdue,
    required this.isTamil,
  });

  final double lent;
  final double borrowed;
  final double overdue;
  final bool isTamil;

  String _tr(String ta, String en) => isTamil ? ta : en;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_brandBlue, Color(0xFF0C3E9D), _brandNavy],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              color: Color(0x401769FF),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -35,
              top: -55,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .07),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _tr('நிகர நிலுவை', 'Net position'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .75),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.shield_outlined,
                      color: Colors.white.withValues(alpha: .75),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _money(lent - borrowed),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.8,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 24,
                  runSpacing: 14,
                  children: [
                    _HeroStat(
                      label: _tr('பெற வேண்டியது', 'To receive'),
                      value: _money(lent),
                    ),
                    _HeroStat(
                      label: _tr('செலுத்த வேண்டியது', 'To pay'),
                      value: _money(borrowed + overdue),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .66),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.isTamil,
    required this.hasLoans,
    required this.onAdd,
    required this.onPayment,
    required this.onCalculator,
    required this.onBackup,
  });

  final bool isTamil;
  final bool hasLoans;
  final VoidCallback onAdd;
  final VoidCallback onPayment;
  final VoidCallback onCalculator;
  final VoidCallback onBackup;

  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.add_rounded, isTamil ? 'கடன் சேர்' : 'Add loan', onAdd),
      (
        Icons.payments_outlined,
        isTamil ? 'செலுத்தல்' : 'Payment',
        hasLoans ? onPayment : onAdd,
      ),
      (
        Icons.calculate_outlined,
        isTamil ? 'கணக்கீடு' : 'Calculator',
        onCalculator,
      ),
      (Icons.cloud_download_outlined, isTamil ? 'காப்பு' : 'Backup', onBackup),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth >= 620
            ? (constraints.maxWidth - 36) / 4
            : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final action in actions)
              SizedBox(
                width: itemWidth,
                child: _QuickAction(
                  icon: action.$1,
                  label: action.$2,
                  onTap: action.$3,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _softBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: _brandBlue),
                ),
                const SizedBox(height: 9),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ResponsiveSummaryGrid extends StatelessWidget {
  const _ResponsiveSummaryGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 760 ? 3 : 1;
          final width = columns == 1
              ? constraints.maxWidth
              : (constraints.maxWidth - 24) / 3;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final child in children)
                SizedBox(width: width, child: child),
            ],
          );
        },
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => _SurfaceCard(
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _InterestFreeSummary extends StatelessWidget {
  const _InterestFreeSummary({required this.loans, required this.isTamil});

  final List<Loan> loans;
  final bool isTamil;

  @override
  Widget build(BuildContext context) {
    final original = loans.fold<double>(0, (sum, loan) => sum + loan.principal);
    final outstanding =
        loans.fold<double>(0, (sum, loan) => sum + loan.outstanding);
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F9D84), Color(0xFF087A69)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2616A085),
            blurRadius: 20,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite_rounded, color: Colors.white),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  isTamil ? 'வட்டி இல்லா கடன்கள்' : 'Interest-free loans',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${loans.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  label: isTamil ? 'மொத்தம் கொடுத்தது' : 'Total lent',
                  value: _money(original),
                ),
              ),
              Expanded(
                child: _HeroStat(
                  label: isTamil ? 'திரும்ப வரவேண்டியது' : 'Outstanding',
                  value: _money(outstanding),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PremiumLoanCard extends StatelessWidget {
  const _PremiumLoanCard({
    required this.loan,
    required this.isTamil,
    required this.onEdit,
    required this.onPayment,
    required this.onEditPhone,
    required this.onSharePdf,
    required this.onDetails,
    this.showDelete = false,
    this.onDelete,
  });

  final Loan loan;
  final bool isTamil;
  final VoidCallback onEdit;
  final VoidCallback onPayment;
  final VoidCallback onEditPhone;
  final VoidCallback onSharePdf;
  final VoidCallback onDetails;
  final bool showDelete;
  final VoidCallback? onDelete;

  String _tr(String ta, String en) => isTamil ? ta : en;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final status = loan.statusFor(DateFormat('yyyy-MM').format(now));
    final overdue = loan.overdueInterest(today: now);
    final isGiven = loan.direction == 'given';
    final interestFree = loan.rate <= 0;
    final accent = interestFree ? _success : (isGiven ? _brandBlue : _warning);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundColor: accent.withValues(alpha: .11),
                  child: Text(
                    _initial(loan.person),
                    style:
                        TextStyle(color: accent, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: onDetails,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            loan.person,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        interestFree
                            ? _tr('வட்டி இல்லா கடன்', 'Interest-free loan')
                            : '${_tr(isGiven ? 'கொடுத்தது' : 'வாங்கியது', isGiven ? 'Lent' : 'Borrowed')}  •  ${loan.rate}% ${_tr('மாதம்', 'monthly')}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (loan.phone.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          loan.phone,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
                _StatusPill(
                  text: loan.isCompleted(today: now)
                      ? _tr('முடிந்தது', 'Settled')
                      : overdue > .009
                          ? _tr('நிலுவை', 'Overdue')
                          : !interestFree && status.remaining <= .009
                              ? _tr('செலுத்தியது', 'Settled')
                              : _tr('செயலில்', 'Active'),
                  color: loan.isCompleted(today: now)
                      ? _success
                      : overdue > .009
                          ? const Color(0xFFEF5350)
                          : !interestFree && status.remaining <= .009
                              ? _success
                              : accent,
                ),
                PopupMenuButton<String>(
                  tooltip: _tr('மேலும்', 'More'),
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'contact') onEditPhone();
                    if (value == 'pdf') onSharePdf();
                    if (value == 'delete') onDelete?.call();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Icons.edit_calendar_outlined),
                          const SizedBox(width: 9),
                          Text(_tr('கடன் அமைப்புகளைத் திருத்து',
                              'Edit loan settings')),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'contact',
                      child: Row(
                        children: [
                          const Icon(Icons.phone_outlined),
                          const SizedBox(width: 9),
                          Text(_tr('தொடர்பு எண்', 'Contact number')),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'pdf',
                      child: Row(
                        children: [
                          const Icon(Icons.picture_as_pdf_outlined),
                          const SizedBox(width: 9),
                          Text(_tr('PDF அறிக்கை பகிர்', 'Share PDF statement')),
                        ],
                      ),
                    ),
                    if (showDelete)
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline_rounded),
                            const SizedBox(width: 9),
                            Text(_tr('நீக்கு', 'Delete')),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 17),
            Row(
              children: [
                Expanded(
                  child: _LoanAmount(
                    label: interestFree
                        ? _tr('முதல்தொகை நிலுவை', 'Principal outstanding')
                        : _tr('முதல்தொகை நிலுவை', 'Outstanding'),
                    value: _money(loan.outstanding),
                  ),
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: Theme.of(context).dividerColor,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _LoanAmount(
                    label: interestFree
                        ? _tr('கடன் தேதி', 'Loan date')
                        : _tr('மாத வட்டி', 'Monthly interest'),
                    value: interestFree
                        ? DateFormat('d MMM yyyy').format(loan.startDate)
                        : _money(loan.monthlyInterest),
                  ),
                ),
              ],
            ),
            if (overdue > .009) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF5350).withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _tr(
                    '${loan.overdueMonthCount(today: now)} மாதங்கள் • ${_money(overdue)} வட்டி நிலுவை',
                    '${loan.overdueMonthCount(today: now)} months • ${_money(overdue)} interest overdue',
                  ),
                  style: const TextStyle(
                    color: Color(0xFFDC3C3C),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPayment,
                    icon: const Icon(Icons.add_card_rounded, size: 18),
                    label: Text(_tr('செலுத்தல் பதிவு', 'Record payment')),
                  ),
                ),
                const SizedBox(width: 10),
                if (isGiven) ...[
                  IconButton.filledTonal(
                    tooltip: _tr('பகிர்வு', 'Share'),
                    onPressed: () => showLoanShareSheet(
                      context,
                      loan: loan,
                      appIsTamil: isTamil,
                    ),
                    icon: const Icon(Icons.share_rounded),
                  ),
                  const SizedBox(width: 10),
                ],
                IconButton.filledTonal(
                  tooltip: _tr('விவரங்கள்', 'Details'),
                  onPressed: onDetails,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LoanAmount extends StatelessWidget {
  const _LoanAmount({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 10,
          ),
        ),
      );
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({
    required this.name,
    required this.loans,
    required this.isTamil,
    required this.onTap,
  });

  final String name;
  final List<Loan> loans;
  final bool isTamil;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lent = loans
        .where((loan) => loan.direction == 'given')
        .fold<double>(0, (sum, loan) => sum + loan.outstanding);
    final borrowed = loans
        .where((loan) => loan.direction == 'taken')
        .fold<double>(0, (sum, loan) => sum + loan.outstanding);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      leading: CircleAvatar(
        backgroundColor: _softBlue,
        child: Text(
          _initial(name),
          style:
              const TextStyle(color: _brandBlue, fontWeight: FontWeight.w800),
        ),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        isTamil
            ? '${loans.length} கடன்கள் • ${loans.expand((loan) => loan.payments).length} செலுத்தல்கள்'
            : '${loans.length} loans • ${loans.expand((loan) => loan.payments).length} payments',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (lent > 0)
            Text(
              '+${_money(lent)}',
              style:
                  const TextStyle(color: _success, fontWeight: FontWeight.w700),
            ),
          if (borrowed > 0)
            Text(
              '-${_money(borrowed)}',
              style: const TextStyle(
                  color: Color(0xFFEF5350), fontWeight: FontWeight.w700),
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _AllocationCard extends StatelessWidget {
  const _AllocationCard({
    required this.lent,
    required this.borrowed,
    required this.isTamil,
  });

  final double lent;
  final double borrowed;
  final bool isTamil;

  @override
  Widget build(BuildContext context) => _SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isTamil ? 'கடன் பகிர்வு' : 'Loan allocation',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                SizedBox(
                  width: 116,
                  height: 116,
                  child: CustomPaint(
                    painter: _DonutPainter(lent: lent, borrowed: borrowed),
                    child: Center(
                      child: Text(
                        '${lent + borrowed == 0 ? 0 : (lent / (lent + borrowed) * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    children: [
                      _LegendRow(
                        color: _brandBlue,
                        label: isTamil ? 'கொடுத்தது' : 'Lent',
                        value: _money(lent),
                      ),
                      const SizedBox(height: 14),
                      _LegendRow(
                        color: _warning,
                        label: isTamil ? 'வாங்கியது' : 'Borrowed',
                        value: _money(borrowed),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

class _InterestOverviewCard extends StatelessWidget {
  const _InterestOverviewCard({
    required this.earned,
    required this.paid,
    required this.isTamil,
  });

  final double earned;
  final double paid;
  final bool isTamil;

  @override
  Widget build(BuildContext context) => _SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isTamil ? 'வட்டி சுருக்கம்' : 'Interest overview',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 18),
            _ReportValue(
              label: isTamil ? 'பெற்ற வட்டி' : 'Interest earned',
              value: _money(earned),
              color: _success,
              icon: Icons.trending_up_rounded,
            ),
            const SizedBox(height: 14),
            _ReportValue(
              label: isTamil ? 'செலுத்திய வட்டி' : 'Interest paid',
              value: _money(paid),
              color: const Color(0xFFEF5350),
              icon: Icons.trending_down_rounded,
            ),
            const Divider(height: 26),
            _ReportValue(
              label: isTamil ? 'நிகர வட்டி' : 'Net interest',
              value: _money(earned - paid),
              color: _brandBlue,
              icon: Icons.balance_rounded,
            ),
          ],
        ),
      );
}

class _MonthlyChartCard extends StatelessWidget {
  const _MonthlyChartCard({required this.months, required this.isTamil});

  final List<_MonthReport> months;
  final bool isTamil;

  @override
  Widget build(BuildContext context) {
    final maxValue = months.fold<double>(
      0,
      (max, month) => math.max(max, math.max(month.earned, month.paid)),
    );
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isTamil ? '6 மாத வட்டி செயல்பாடு' : '6-month interest activity',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            isTamil
                ? 'உண்மையான செலுத்தல் பதிவுகளின் அடிப்படையில்'
                : 'Based on recorded payments',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 190,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final month in months)
                  Expanded(
                    child: _MonthBars(
                      report: month,
                      maxValue: maxValue,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ChartLegend(
                color: _brandBlue,
                label: isTamil ? 'பெற்றது' : 'Earned',
              ),
              const SizedBox(width: 18),
              _ChartLegend(
                color: _warning,
                label: isTamil ? 'செலுத்தியது' : 'Paid',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthBars extends StatelessWidget {
  const _MonthBars({required this.report, required this.maxValue});

  final _MonthReport report;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    double height(double value) =>
        maxValue <= 0 ? 4 : math.max(4, value / maxValue * 135);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 12,
                height: height(report.earned),
                decoration: const BoxDecoration(
                  color: _brandBlue,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
                ),
              ),
              const SizedBox(width: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 12,
                height: height(report.paid),
                decoration: const BoxDecoration(
                  color: _warning,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        Text(report.label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.lent, required this.borrowed});

  final double lent;
  final double borrowed;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width * .13;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE8EDF6);
    canvas.drawArc(rect.deflate(stroke / 2), 0, math.pi * 2, false, base);
    final total = lent + borrowed;
    if (total <= 0) return;
    final start = -math.pi / 2;
    final lentSweep = math.pi * 2 * lent / total;
    final lentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = _brandBlue;
    final borrowedPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = _warning;
    canvas.drawArc(
        rect.deflate(stroke / 2), start, lentSweep, false, lentPaint);
    canvas.drawArc(
      rect.deflate(stroke / 2),
      start + lentSweep,
      math.pi * 2 - lentSweep,
      false,
      borrowedPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.lent != lent || oldDelegate.borrowed != borrowed;
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(17),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: dark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0A0B1F44),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: .7),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    this.action,
    this.onAction,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      );
}

class _PremiumEmptyState extends StatelessWidget {
  const _PremiumEmptyState({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => _SurfaceCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _softBlue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: _brandBlue,
                  size: 30,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 17),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      );
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.name,
    required this.phone,
    required this.loanCount,
    required this.isTamil,
  });

  final String name;
  final String phone;
  final int loanCount;
  final bool isTamil;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient:
              const LinearGradient(colors: [_brandNavy, Color(0xFF1348B8)]),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: Colors.white,
              child: Text(
                _initial(name.isEmpty ? (isTamil ? 'ப' : 'U') : name),
                style: const TextStyle(
                  color: _brandBlue,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty
                        ? (isTamil ? 'உங்கள் சுயவிவரம்' : 'Your profile')
                        : name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    phone.isEmpty
                        ? (isTamil
                            ? 'விவரங்களைச் சேர்க்கவும்'
                            : 'Add your details')
                        : phone,
                    style: TextStyle(color: Colors.white.withValues(alpha: .7)),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    isTamil
                        ? '$loanCount கடன் கணக்குகள்'
                        : '$loanCount loan accounts',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .9),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => _SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 15),
            child,
          ],
        ),
      );
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: _softBlue,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: _brandBlue, size: 21),
      );
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      );
}

class _ReportValue extends StatelessWidget {
  const _ReportValue({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      );
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      );
}

class _SectionSheetHeader extends StatelessWidget {
  const _SectionSheetHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      );
}

class _TransactionsPage extends StatefulWidget {
  const _TransactionsPage({required this.loans, required this.isTamil});

  final List<Loan> loans;
  final bool isTamil;

  @override
  State<_TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<_TransactionsPage> {
  String _query = '';
  String _filter = 'all';

  String _tr(String ta, String en) => widget.isTamil ? ta : en;

  @override
  Widget build(BuildContext context) {
    final entries = _paymentEntries(widget.loans).where((entry) {
      final typeMatches = _filter == 'all' || entry.payment.type == _filter;
      return typeMatches &&
          entry.loan.person.toLowerCase().contains(_query.toLowerCase());
    }).toList();
    return Scaffold(
      appBar: AppBar(title: Text(_tr('பரிவர்த்தனைகள்', 'Transactions'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextField(
                onChanged: (value) => setState(() => _query = value.trim()),
                decoration: InputDecoration(
                  hintText: _tr('பெயரைத் தேடுங்கள்', 'Search by person'),
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                        value: 'all', label: Text(_tr('அனைத்தும்', 'All'))),
                    ButtonSegment(
                        value: 'interest',
                        label: Text(_tr('வட்டி', 'Interest'))),
                    ButtonSegment(
                        value: 'principal',
                        label: Text(_tr('முதல்தொகை', 'Principal'))),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (value) =>
                      setState(() => _filter = value.first),
                ),
              ),
              const SizedBox(height: 18),
              if (entries.isEmpty)
                _PremiumEmptyState(
                  title: _tr('பரிவர்த்தனைகள் இல்லை', 'No transactions'),
                  subtitle: _tr(
                      'செலுத்தல்கள் பதிவு செய்யப்பட்டதும் இங்கே தோன்றும்.',
                      'Recorded payments will appear here.'),
                )
              else
                _SurfaceCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      for (var i = 0; i < entries.length; i++) ...[
                        _TransactionTile(
                            entry: entries[i], isTamil: widget.isTamil),
                        if (i < entries.length - 1)
                          const Divider(height: 1, indent: 64),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.entry, required this.isTamil});

  final _PaymentEntry entry;
  final bool isTamil;

  @override
  Widget build(BuildContext context) {
    final isInterest = entry.payment.type == 'interest';
    return ListTile(
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: (isInterest ? _brandBlue : _success).withValues(alpha: .1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          isInterest ? Icons.percent_rounded : Icons.payments_outlined,
          color: isInterest ? _brandBlue : _success,
          size: 20,
        ),
      ),
      title: Text(entry.loan.person,
          style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        '${isTamil ? (isInterest ? 'வட்டி' : 'முதல்தொகை') : (isInterest ? 'Interest' : 'Principal')} • ${DateFormat('d MMM yyyy').format(entry.payment.date)}',
      ),
      trailing: Text(
        _money(entry.payment.amount),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _InterestCalculatorSheet extends StatefulWidget {
  const _InterestCalculatorSheet({required this.isTamil});

  final bool isTamil;

  @override
  State<_InterestCalculatorSheet> createState() =>
      _InterestCalculatorSheetState();
}

class _InterestCalculatorSheetState extends State<_InterestCalculatorSheet> {
  final _principal = TextEditingController();
  final _rate = TextEditingController();
  final _duration = TextEditingController();
  String _method = 'simple';
  String _period = 'monthly';
  String _inputMode = 'duration';
  DateTime _fromDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  double? _interest;
  double? _total;
  String? _calculationPeriod;

  String _tr(String ta, String en) => widget.isTamil ? ta : en;

  @override
  void dispose() {
    _principal.dispose();
    _rate.dispose();
    _duration.dispose();
    super.dispose();
  }

  void _calculate() {
    final principal = double.tryParse(_principal.text);
    final rate = double.tryParse(_rate.text);
    final duration = _inputMode == 'dates'
        ? _datePeriodUnits().$1
        : double.tryParse(_duration.text);
    if (principal == null ||
        rate == null ||
        duration == null ||
        principal <= 0 ||
        rate < 0 ||
        duration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                _tr('சரியான மதிப்புகளை உள்ளிடவும்.', 'Enter valid values.'))),
      );
      return;
    }
    final periods = duration;
    final periodicRate = rate / 100;
    final total = _method == 'simple'
        ? principal * (1 + periodicRate * periods)
        : principal * math.pow(1 + periodicRate, periods).toDouble();
    setState(() {
      _total = total;
      _interest = total - principal;
      _calculationPeriod = _inputMode == 'dates' ? _datePeriodUnits().$2 : null;
    });
  }

  (double, String) _datePeriodUnits() {
    if (_endDate.isBefore(_fromDate)) return (0, '');
    var cursor = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    final end = DateTime(_endDate.year, _endDate.month, _endDate.day);
    var completePeriods = 0;

    DateTime completionDate(DateTime start) {
      final target = _period == 'monthly'
          ? DateTime(start.year, start.month + 1, 1)
          : DateTime(start.year + 1, start.month, 1);
      final lastDay = DateTime(target.year, target.month + 1, 0).day;
      final anniversary = DateTime(
        target.year,
        target.month,
        math.min(start.day, lastDay),
      );
      return anniversary.subtract(const Duration(days: 1));
    }

    var completion = completionDate(cursor);
    while (!completion.isAfter(end)) {
      completePeriods++;
      cursor = completion.add(const Duration(days: 1));
      completion = completionDate(cursor);
    }
    final remainingDays =
        end.isBefore(cursor) ? 0 : end.difference(cursor).inDays + 1;
    final partialPeriodDays = completion.difference(cursor).inDays + 1;
    final units = completePeriods + remainingDays / partialPeriodDays;
    final unitLabel =
        _period == 'monthly' ? _tr('மாதம்', 'month') : _tr('ஆண்டு', 'year');
    final label = remainingDays == 0
        ? '$completePeriods $unitLabel'
        : '$completePeriods $unitLabel + $remainingDays ${_tr('நாட்கள்', 'days')}';
    return (units, label);
  }

  Future<void> _pickCalculatorDate({required bool from}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: from ? _fromDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null) return;
    setState(() {
      if (from) {
        _fromDate = selected;
        if (_endDate.isBefore(selected)) _endDate = selected;
      } else {
        _endDate = selected;
      }
      _interest = null;
      _total = null;
      _calculationPeriod = null;
    });
  }

  Widget _periodDropdown() => DropdownButtonFormField<String>(
        initialValue: _period,
        decoration: InputDecoration(labelText: _tr('காலம்', 'Period')),
        items: [
          DropdownMenuItem(
            value: 'monthly',
            child: Text(_tr('மாதங்கள்', 'Months')),
          ),
          DropdownMenuItem(
            value: 'yearly',
            child: Text(_tr('ஆண்டுகள்', 'Years')),
          ),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _period = value;
              _interest = null;
              _total = null;
              _calculationPeriod = null;
            });
          }
        },
      );

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionSheetHeader(
                title: _tr('வட்டி கணக்கீடு', 'Interest calculator'),
                subtitle: _tr('இந்த கணக்கீடு சேமிக்கப்படாது.',
                    'Calculations are not saved.'),
              ),
              const SizedBox(height: 18),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                      value: 'simple', label: Text(_tr('தனி வட்டி', 'Simple'))),
                  ButtonSegment(
                      value: 'compound',
                      label: Text(_tr('கூட்டு வட்டி', 'Compound'))),
                ],
                selected: {_method},
                onSelectionChanged: (value) =>
                    setState(() => _method = value.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _principal,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: _tr('முதல்தொகை', 'Principal'),
                  prefixText: '₹ ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _rate,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: _period == 'monthly'
                      ? _tr('மாத வட்டி விகிதம்', 'Monthly interest rate')
                      : _tr('ஆண்டு வட்டி விகிதம்', 'Yearly interest rate'),
                  suffixText: '%',
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: 'duration',
                    icon: const Icon(Icons.timelapse_rounded),
                    label: Text(_tr('கால அளவு', 'Duration')),
                  ),
                  ButtonSegment(
                    value: 'dates',
                    icon: const Icon(Icons.date_range_outlined),
                    label: Text(_tr('தேதிகள்', 'Dates')),
                  ),
                ],
                selected: {_inputMode},
                onSelectionChanged: (value) => setState(() {
                  _inputMode = value.first;
                  _interest = null;
                  _total = null;
                  _calculationPeriod = null;
                }),
              ),
              const SizedBox(height: 12),
              if (_inputMode == 'duration')
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _duration,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: _tr('கால அளவு', 'Duration'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: _periodDropdown()),
                  ],
                )
              else ...[
                _periodDropdown(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        label: _tr('தொடக்க தேதி', 'From date'),
                        date: _fromDate,
                        onTap: () => _pickCalculatorDate(from: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DateField(
                        label: _tr('முடிவு தேதி', 'End date'),
                        date: _endDate,
                        onTap: () => _pickCalculatorDate(from: false),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _calculate,
                  icon: const Icon(Icons.calculate_outlined),
                  label: Text(_tr('கணக்கிடு', 'Calculate')),
                ),
              ),
              if (_interest != null && _total != null) ...[
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_brandBlue, Color(0xFF0A3EAA)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_tr('மொத்த வட்டி', 'Total interest'),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: .72))),
                      const SizedBox(height: 4),
                      Text(_money(_interest!),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 25,
                              fontWeight: FontWeight.w800)),
                      if (_calculationPeriod != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _calculationPeriod!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .78),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                          '${_tr('மொத்த தொகை', 'Total amount')}: ${_money(_total!)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.calendar_month_outlined),
          ),
          child: Text(
            MaterialLocalizations.of(context).formatMediumDate(date),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
}

class _PaymentEntry {
  const _PaymentEntry({required this.loan, required this.payment});

  final Loan loan;
  final LoanPayment payment;
}

class _MonthReport {
  const _MonthReport(
      {required this.label, required this.earned, required this.paid});

  final String label;
  final double earned;
  final double paid;
}

List<_PaymentEntry> _paymentEntries(List<Loan> loans) {
  final entries = <_PaymentEntry>[
    for (final loan in loans)
      for (final payment in loan.payments)
        _PaymentEntry(loan: loan, payment: payment),
  ];
  entries.sort((a, b) => b.payment.date.compareTo(a.payment.date));
  return entries;
}

List<_MonthReport> _monthlyInterest(List<Loan> loans) {
  final now = DateTime.now();
  return List.generate(6, (index) {
    final date = DateTime(now.year, now.month - 5 + index);
    double earned = 0;
    double paid = 0;
    for (final loan in loans) {
      for (final payment in loan.payments.where((item) =>
          item.type == 'interest' &&
          item.date.year == date.year &&
          item.date.month == date.month)) {
        if (loan.direction == 'given') {
          earned += payment.amount;
        } else {
          paid += payment.amount;
        }
      }
    }
    return _MonthReport(
      label: DateFormat('MMM').format(date),
      earned: earned,
      paid: paid,
    );
  });
}

Future<void> _pickLoanForPayment(
  BuildContext context,
  List<Loan> loans,
  bool isTamil,
  ValueChanged<Loan> onPayment,
) async {
  final loan = await showModalBottomSheet<Loan>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isTamil ? 'கடனைத் தேர்ந்தெடுக்கவும்' : 'Choose a loan',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final item in loans)
                    ListTile(
                      leading: CircleAvatar(child: Text(_initial(item.person))),
                      title: Text(item.person),
                      subtitle: Text(_money(item.outstanding)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.pop(sheetContext, item),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (loan != null) onPayment(loan);
}

Future<void> _showCalculator(BuildContext context, bool isTamil) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _InterestCalculatorSheet(isTamil: isTamil),
    );

Future<void> _showNotifications(
  BuildContext context,
  List<Loan> loans,
  bool isTamil,
) async {
  final now = DateTime.now();
  final overdue =
      loans.where((loan) => loan.overdueInterest(today: now) > .009).toList();
  final upcoming = loans.where((loan) {
    final month = DateFormat('yyyy-MM').format(now);
    final status = loan.statusFor(month, today: now);
    final days = status.dueDate
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    return status.remaining > .009 && days > 0 && days <= 7;
  }).toList();
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionSheetHeader(
              title: isTamil ? 'அறிவிப்புகள்' : 'Notifications',
              subtitle: isTamil
                  ? 'நிலுவை மற்றும் வரவிருக்கும் தேதிகள்'
                  : 'Overdue and upcoming dues',
            ),
            const SizedBox(height: 10),
            if (overdue.isEmpty && upcoming.isEmpty)
              _PremiumEmptyState(
                title:
                    isTamil ? 'புதிய அறிவிப்பு இல்லை' : 'You are all caught up',
                subtitle: isTamil
                    ? 'தற்போது நிலுவை அல்லது அடுத்த 7 நாள் நினைவூட்டல் இல்லை.'
                    : 'No overdue or next-7-day reminders.',
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final loan in overdue)
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFFFE8E8),
                          child: Icon(Icons.warning_amber_rounded,
                              color: Color(0xFFDC3C3C)),
                        ),
                        title: Text(loan.person),
                        subtitle: Text(isTamil
                            ? '${loan.overdueMonthCount(today: now)} மாதங்கள் நிலுவை'
                            : '${loan.overdueMonthCount(today: now)} months overdue'),
                        trailing: Text(_money(loan.overdueInterest(today: now)),
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    for (final loan in upcoming)
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: _softBlue,
                          child: Icon(Icons.event_outlined, color: _brandBlue),
                        ),
                        title: Text(loan.person),
                        subtitle: Text(isTamil
                            ? 'விரைவில் செலுத்த வேண்டியது'
                            : 'Due soon'),
                        trailing: Text(_money(loan.monthlyInterest),
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _showPersonDetails(
  BuildContext context,
  String name,
  List<Loan> loans,
  bool isTamil,
  ValueChanged<Loan> onEditLoan,
  ValueChanged<Loan> onPayment,
  ValueChanged<Loan> onEditPhone,
  ValueChanged<Loan> onSharePdf,
  void Function(BuildContext, Loan) onDetails,
) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (pageContext) => Scaffold(
          appBar: AppBar(title: Text(name)),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    Text(
                      isTamil
                          ? '${loans.length} கடன் கணக்குகள்'
                          : '${loans.length} loan accounts',
                      style: Theme.of(pageContext).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    for (final loan in loans)
                      _PremiumLoanCard(
                        loan: loan,
                        isTamil: isTamil,
                        onEdit: () {
                          Navigator.pop(pageContext);
                          onEditLoan(loan);
                        },
                        onPayment: () {
                          Navigator.pop(pageContext);
                          onPayment(loan);
                        },
                        onEditPhone: () {
                          Navigator.pop(pageContext);
                          onEditPhone(loan);
                        },
                        onSharePdf: () {
                          Navigator.pop(pageContext);
                          onSharePdf(loan);
                        },
                        onDetails: () => onDetails(pageContext, loan),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

Future<void> showLoanShareSheet(
  BuildContext context, {
  required Loan loan,
  required bool appIsTamil,
  LoanShareType initialType = LoanShareType.reminder,
  LoanPayment? payment,
}) async {
  var selectedType = initialType;
  var selectedLanguage =
      appIsTamil ? LoanShareLanguage.tamil : LoanShareLanguage.english;
  final paymentsByDate = [...loan.payments]..sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });
  final recordedPayment =
      payment != null && loan.payments.any((item) => item.id == payment.id)
          ? payment
          : (paymentsByDate.isEmpty ? null : paymentsByDate.last);
  if (selectedType == LoanShareType.paymentReceipt && recordedPayment == null) {
    selectedType = LoanShareType.reminder;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) {
        final message = LoanShareMessageBuilder.build(
          loan: loan,
          type: selectedType,
          language: selectedLanguage,
          payment: selectedType == LoanShareType.paymentReceipt
              ? recordedPayment
              : null,
        );
        String tr(String ta, String en) => appIsTamil ? ta : en;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20 +
                math.max(
                  MediaQuery.viewInsetsOf(context).bottom,
                  MediaQuery.viewPaddingOf(context).bottom,
                ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('கணக்கு பகிர்வு', 'Share loan account'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ShareTypeChip(
                    label: tr('நினைவூட்டல்', 'Reminder'),
                    icon: Icons.notifications_none_rounded,
                    selected: selectedType == LoanShareType.reminder,
                    onSelected: () => setSheetState(
                      () => selectedType = LoanShareType.reminder,
                    ),
                  ),
                  _ShareTypeChip(
                    label: tr('கடன் அறிக்கை', 'Statement'),
                    icon: Icons.receipt_long_outlined,
                    selected: selectedType == LoanShareType.statement,
                    onSelected: () => setSheetState(
                      () => selectedType = LoanShareType.statement,
                    ),
                  ),
                  _ShareTypeChip(
                    label: tr('பணம் பெற்ற ரசீது', 'Payment receipt'),
                    icon: Icons.task_alt_rounded,
                    selected: selectedType == LoanShareType.paymentReceipt,
                    enabled: recordedPayment != null,
                    onSelected: () => setSheetState(
                      () => selectedType = LoanShareType.paymentReceipt,
                    ),
                  ),
                ],
              ),
              if (recordedPayment == null) ...[
                const SizedBox(height: 7),
                Text(
                  tr(
                    'பதிவு செய்யப்பட்ட செலுத்தல் இருந்தால் மட்டுமே ரசீது கிடைக்கும்.',
                    'A receipt is available only after a payment is recorded.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 14),
              SegmentedButton<LoanShareLanguage>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: LoanShareLanguage.english,
                    label: Text('English'),
                  ),
                  ButtonSegment(
                    value: LoanShareLanguage.tamil,
                    label: Text('தமிழ்'),
                  ),
                  ButtonSegment(
                    value: LoanShareLanguage.both,
                    label: Text('Both'),
                  ),
                ],
                selected: {selectedLanguage},
                onSelectionChanged: (selection) => setSheetState(
                  () => selectedLanguage = selection.first,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                tr('முன்னோட்டம்', 'Preview'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 7),
              Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .36,
                ),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    message,
                    style: const TextStyle(height: 1.45, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: message));
                        if (sheetContext.mounted) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            SnackBar(
                              content: Text(tr(
                                'செய்தி நகலெடுக்கப்பட்டது.',
                                'Message copied.',
                              )),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: Text(tr('நகலெடு', 'Copy')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _shareToWhatsApp(
                        sheetContext,
                        loan: loan,
                        message: message,
                        isTamil: appIsTamil,
                      ),
                      icon: const Icon(Icons.chat_rounded),
                      label: const Text('WhatsApp'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _ShareTypeChip extends StatelessWidget {
  const _ShareTypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        selected: selected,
        onSelected: enabled ? (_) => onSelected() : null,
      );
}

Future<void> _shareToWhatsApp(
  BuildContext context, {
  required Loan loan,
  required String message,
  required bool isTamil,
}) async {
  var phone = loan.phone.replaceAll(RegExp(r'\D'), '');
  if (phone.length == 10) phone = '91$phone';
  final path = phone.isEmpty ? '/' : '/$phone';
  final uri = Uri.https('wa.me', path, {'text': message});
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) throw StateError('WhatsApp did not open.');
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isTamil
              ? 'WhatsApp-ஐ திறக்க முடியவில்லை.'
              : 'Could not open WhatsApp.'),
        ),
      );
    }
  }
}

String _money(double value) => NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: value % 1 == 0 ? 0 : 2,
    ).format(value);

String _initial(String value) {
  final text = value.trim();
  return text.isEmpty ? '?' : text.characters.first;
}
