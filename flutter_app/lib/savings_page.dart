part of 'premium_ui.dart';

class _SavingsPage extends StatelessWidget {
  const _SavingsPage({
    required this.savings,
    required this.isTamil,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final List<SavingsEntry> savings;
  final bool isTamil;
  final VoidCallback onAdd;
  final ValueChanged<SavingsEntry> onEdit;
  final ValueChanged<SavingsEntry> onDelete;

  String _tr(String tamil, String english) => isTamil ? tamil : english;

  @override
  Widget build(BuildContext context) {
    final total = savings.fold<double>(0, (sum, entry) => sum + entry.amount);
    final targetTotal = savings
        .where((entry) => entry.targetAmount != null)
        .fold<double>(0, (sum, entry) => sum + entry.targetAmount!);
    final targetSaved = savings
        .where((entry) => entry.targetAmount != null)
        .fold<double>(0, (sum, entry) => sum + entry.amount);
    final groups = <String, double>{};
    for (final entry in savings) {
      groups.update(
        entry.type,
        (amount) => amount + entry.amount,
        ifAbsent: () => entry.amount,
      );
    }
    final grouped = groups.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _PageScroll(
      storageId: 'savings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopHeader(
            title: _tr('சேமிப்புகள்', 'Savings'),
            subtitle: _tr(
              '${savings.length} உள்ளூர் பதிவுகள்',
              '${savings.length} local records',
            ),
            trailing: IconButton.filledTonal(
              tooltip: _tr('சேமிப்பைச் சேர்', 'Add savings'),
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F9D84), Color(0xFF087A69)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x3316A085),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tr('மொத்த சேமிப்பு', 'Total savings'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .75),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _money(context, total),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (targetTotal > 0) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _tr('இலக்கு முன்னேற்றம்', 'Goal progress'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .76),
                          ),
                        ),
                      ),
                      Text(
                        '${(targetSaved / targetTotal * 100).clamp(0, 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (targetSaved / targetTotal).clamp(0, 1),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                    backgroundColor: Colors.white.withValues(alpha: .2),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '${_money(context, targetSaved)} / ${_money(context, targetTotal)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .82),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (grouped.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionHeading(
              title: _tr('எங்கே சேமிக்கப்பட்டுள்ளது', 'Where it is saved'),
            ),
            const SizedBox(height: 12),
            _ResponsiveSummaryGrid(
              children: [
                for (final group in grouped)
                  _MetricCard(
                    label: _savingsTypeLabel(group.key, isTamil),
                    value: _money(context, group.value),
                    icon: _savingsTypeIcon(group.key),
                    color: _savingsTypeColor(group.key),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 26),
          _SectionHeading(
            title: _tr('சேமிப்பு பதிவுகள்', 'Savings records'),
          ),
          const SizedBox(height: 12),
          if (savings.isEmpty)
            _PremiumEmptyState(
              title: _tr(
                  'இன்னும் சேமிப்பு பதிவுகள் இல்லை', 'No savings records yet'),
              subtitle: _tr(
                'உங்கள் பணம் எங்கே, எவ்வளவு உள்ளது என்பதை பாதுகாப்பாக கண்காணிக்க முதல் பதிவைச் சேர்க்கவும்.',
                'Add your first record to safely track where your money is and how much you have.',
              ),
              actionLabel: _tr('சேமிப்பைச் சேர்', 'Add savings'),
              onAction: onAdd,
            )
          else
            for (final entry in savings)
              _SavingsEntryCard(
                entry: entry,
                isTamil: isTamil,
                onEdit: () => onEdit(entry),
                onDelete: () => onDelete(entry),
              ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _SavingsEntryCard extends StatelessWidget {
  const _SavingsEntryCard({
    required this.entry,
    required this.isTamil,
    required this.onEdit,
    required this.onDelete,
  });

  final SavingsEntry entry;
  final bool isTamil;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _tr(String tamil, String english) => isTamil ? tamil : english;

  @override
  Widget build(BuildContext context) {
    final daysSinceUpdate = DateTime.now().difference(entry.updatedAt).inDays;
    final needsReview = daysSinceUpdate >= 90;
    final color = _savingsTypeColor(entry.type);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_savingsTypeIcon(entry.type), color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                        _savingsTypeLabel(entry.type, isTamil),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: _tr('மேலும்', 'More'),
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.edit_outlined),
                        title: Text(_tr('திருத்து', 'Edit')),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.delete_outline_rounded),
                        title: Text(_tr('நீக்கு', 'Delete')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _money(context, entry.amount),
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
            ),
            if (entry.targetAmount != null) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: entry.progress,
                minHeight: 7,
                borderRadius: BorderRadius.circular(8),
                color: color,
                backgroundColor: color.withValues(alpha: .12),
              ),
              const SizedBox(height: 6),
              Text(
                '${_tr('இலக்கு', 'Target')}: ${_money(context, entry.targetAmount!)}  •  ${(entry.progress * 100).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (entry.note.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(entry.note, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  needsReview
                      ? Icons.warning_amber_rounded
                      : Icons.verified_outlined,
                  size: 16,
                  color: needsReview ? _warning : _success,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    needsReview
                        ? _tr(
                            '90 நாட்களுக்கு மேல் ஆகிவிட்டது — தொகையை சரிபார்க்கவும்',
                            'Over 90 days old — review this balance')
                        : '${_tr('புதுப்பித்தது', 'Updated')}: ${DateFormat('d MMM yyyy').format(entry.updatedAt)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: needsReview ? _warning : null,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _savingsTypeLabel(String type, bool isTamil) => switch (type) {
      'bank' => isTamil ? 'வங்கி கணக்கு' : 'Bank account',
      'cash' => isTamil ? 'கையிருப்பு பணம்' : 'Cash',
      'fixed_deposit' => isTamil ? 'நிலையான வைப்பு' : 'Fixed deposit',
      'recurring_deposit' => isTamil ? 'தொடர் வைப்பு' : 'Recurring deposit',
      'digital_wallet' => isTamil ? 'டிஜிட்டல் வாலெட்' : 'Digital wallet',
      _ => isTamil ? 'மற்றவை' : 'Other',
    };

IconData _savingsTypeIcon(String type) => switch (type) {
      'bank' => Icons.account_balance_outlined,
      'cash' => Icons.payments_outlined,
      'fixed_deposit' => Icons.lock_clock_outlined,
      'recurring_deposit' => Icons.autorenew_rounded,
      'digital_wallet' => Icons.account_balance_wallet_outlined,
      _ => Icons.savings_outlined,
    };

Color _savingsTypeColor(String type) => switch (type) {
      'bank' => _brandBlue,
      'cash' => _success,
      'fixed_deposit' => const Color(0xFF7E57C2),
      'recurring_deposit' => const Color(0xFF00838F),
      'digital_wallet' => _warning,
      _ => const Color(0xFF607D8B),
    };
