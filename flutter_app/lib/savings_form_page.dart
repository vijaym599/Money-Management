import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models.dart';

class SavingsFormPage extends StatefulWidget {
  const SavingsFormPage({
    required this.isTamil,
    this.entry,
    super.key,
  });

  final bool isTamil;
  final SavingsEntry? entry;

  @override
  State<SavingsFormPage> createState() => _SavingsFormPageState();
}

class _SavingsFormPageState extends State<SavingsFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _target;
  late final TextEditingController _note;
  late String _type;

  bool get _editing => widget.entry != null;
  String _tr(String tamil, String english) => widget.isTamil ? tamil : english;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _name = TextEditingController(text: entry?.name ?? '');
    _amount = TextEditingController(
      text: entry == null ? '' : _plainNumber(entry.amount),
    );
    _target = TextEditingController(
      text:
          entry?.targetAmount == null ? '' : _plainNumber(entry!.targetAmount!),
    );
    _note = TextEditingController(text: entry?.note ?? '');
    _type = entry?.type ?? 'bank';
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _target.dispose();
    _note.dispose();
    super.dispose();
  }

  String _plainNumber(double value) =>
      value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

  String _typeLabel(String type) => switch (type) {
        'bank' => _tr('வங்கி கணக்கு', 'Bank account'),
        'cash' => _tr('கையிருப்பு பணம்', 'Cash'),
        'fixed_deposit' => _tr('நிலையான வைப்பு', 'Fixed deposit'),
        'recurring_deposit' => _tr('தொடர் வைப்பு', 'Recurring deposit'),
        'digital_wallet' => _tr('டிஜிட்டல் வாலெட்', 'Digital wallet'),
        _ => _tr('மற்றவை', 'Other'),
      };

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final targetText = _target.text.trim();
    Navigator.pop(
      context,
      SavingsEntry(
        id: widget.entry?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        name: _name.text.trim(),
        type: _type,
        amount: double.parse(_amount.text.trim()),
        targetAmount: targetText.isEmpty ? null : double.parse(targetText),
        updatedAt: DateTime.now(),
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final numberInput = <TextInputFormatter>[
      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing
            ? _tr('சேமிப்பைத் திருத்து', 'Edit savings')
            : _tr('சேமிப்பைச் சேர்', 'Add savings')),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: .55),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_outlined,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_tr(
                            'கணக்கு எண், PIN, கடவுச்சொல் போன்ற ரகசிய தகவல்களை இங்கே பதிவு செய்ய வேண்டாம்.',
                            'Do not enter account numbers, PINs, passwords, or other secrets here.',
                          )),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 50,
                    decoration: InputDecoration(
                      labelText:
                          _tr('சேமிப்பு இருக்கும் இடம்', 'Where is it saved?'),
                      hintText: _tr('உதா: அவசர நிதி வங்கி',
                          'Example: Emergency fund bank'),
                      prefixIcon: const Icon(Icons.location_on_outlined),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? _tr('இடம் அல்லது பெயரை உள்ளிடவும்',
                            'Enter a location or name')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration: InputDecoration(
                      labelText: _tr('சேமிப்பு வகை', 'Savings type'),
                      prefixIcon: const Icon(Icons.category_outlined),
                    ),
                    items: [
                      for (final type in savingsEntryTypes)
                        DropdownMenuItem(
                          value: type,
                          child: Text(_typeLabel(type)),
                        ),
                    ],
                    onChanged: (value) => setState(() => _type = value!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: numberInput,
                    decoration: InputDecoration(
                      labelText: _tr('தற்போதைய தொகை (₹)', 'Current amount (₹)'),
                      prefixIcon: const Icon(Icons.currency_rupee_rounded),
                    ),
                    validator: (value) {
                      final amount = double.tryParse(value?.trim() ?? '');
                      return amount == null || !amount.isFinite || amount < 0
                          ? _tr('சரியான தொகையை உள்ளிடவும்',
                              'Enter a valid amount')
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _target,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: numberInput,
                    decoration: InputDecoration(
                      labelText: _tr('இலக்கு தொகை (விருப்பம்)',
                          'Target amount (optional)'),
                      prefixIcon: const Icon(Icons.flag_outlined),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return null;
                      final target = double.tryParse(text);
                      return target == null || !target.isFinite || target <= 0
                          ? _tr('சரியான இலக்கு தொகையை உள்ளிடவும்',
                              'Enter a valid target amount')
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _note,
                    maxLength: 120,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: _tr('குறிப்பு (விருப்பம்)', 'Note (optional)'),
                      prefixIcon: const Icon(Icons.notes_rounded),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_editing
                        ? _tr('மாற்றங்களைச் சேமி', 'Save changes')
                        : _tr('சேமிப்பைச் சேர்', 'Add savings')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
