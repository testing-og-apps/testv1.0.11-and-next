import 'package:flutter/material.dart';
import '../utils.dart';

// ───────────────────────── Option grid (Relationship / Category) ─────────────────────────

class PickerOption {
  final String label;
  final IconData icon;
  const PickerOption(this.label, this.icon);
}

/// Compact field that looks like a text field but opens a picker when tapped.
class PickerField extends StatelessWidget {
  const PickerField({super.key, required this.label, required this.value, required this.onTap});
  final String label, value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: InputDecorator(
        isEmpty: value.isEmpty,
        decoration: deco(context, label).copyWith(suffixIcon: const Icon(Icons.expand_more_rounded)),
        child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

/// Bottom sheet with a 3-column grid. Returns the chosen text, '' to clear, or null if dismissed.
Future<String?> showOptionPicker(BuildContext context,
    {required String title, required List<PickerOption> options, required String current}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => _OptionSheet(title: title, options: options, current: current),
  );
}

class _OptionSheet extends StatefulWidget {
  const _OptionSheet({required this.title, required this.options, required this.current});
  final String title, current;
  final List<PickerOption> options;
  @override
  State<_OptionSheet> createState() => _OptionSheetState();
}

class _OptionSheetState extends State<_OptionSheet> {
  late final TextEditingController _custom = TextEditingController(text: _isCustomValue ? widget.current : '');
  late bool _showCustom = _isCustomValue;

  bool get _isCustomValue =>
      widget.current.isNotEmpty && !widget.options.any((o) => o.label.toLowerCase() == widget.current.toLowerCase());

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _submitCustom() {
    final v = _custom.text.trim();
    if (v.isNotEmpty) Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600))),
            if (widget.current.isNotEmpty) TextButton(onPressed: () => Navigator.pop(context, ''), child: const Text('Clear')),
          ]),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, box) {
            final w = (box.maxWidth - 16) / 3;
            Widget tile(IconData icon, String label, bool selected, VoidCallback onTap) => SizedBox(
                  width: w,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: onTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                      decoration: BoxDecoration(
                        color: selected ? cs.primaryContainer : cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: selected ? cs.primary : cs.outlineVariant.withValues(alpha: .5), width: selected ? 1.5 : 1),
                      ),
                      child: Column(children: [
                        Icon(icon, size: 24, color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant),
                        const SizedBox(height: 6),
                        Text(label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
                      ]),
                    ),
                  ),
                );
            return Wrap(spacing: 8, runSpacing: 8, children: [
              for (final o in widget.options)
                tile(o.icon, o.label, o.label.toLowerCase() == widget.current.toLowerCase(), () => Navigator.pop(context, o.label)),
              tile(Icons.edit_outlined, 'Custom', _showCustom, () => setState(() => _showCustom = true)),
            ]);
          }),
          if (_showCustom) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _custom,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitCustom(),
              decoration: deco(context, 'Custom ${widget.title.toLowerCase()}', icon: Icons.edit_outlined).copyWith(
                suffixIcon: IconButton(icon: const Icon(Icons.check_rounded), onPressed: _submitCustom),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ───────────────────────── Country codes (phone / WhatsApp) ─────────────────────────

class Country {
  final String iso, name, dial;
  const Country(this.iso, this.name, this.dial);
  String get flag => String.fromCharCodes(iso.codeUnits.map((c) => 0x1F1E6 + c - 0x41));
}

const countries = <Country>[
  Country('BD', 'Bangladesh', '880'), Country('IN', 'India', '91'), Country('PK', 'Pakistan', '92'),
  Country('NP', 'Nepal', '977'), Country('LK', 'Sri Lanka', '94'), Country('BT', 'Bhutan', '975'),
  Country('MV', 'Maldives', '960'), Country('AF', 'Afghanistan', '93'),
  Country('US', 'United States', '1'), Country('CA', 'Canada', '1'), Country('GB', 'United Kingdom', '44'),
  Country('AU', 'Australia', '61'), Country('NZ', 'New Zealand', '64'), Country('IE', 'Ireland', '353'),
  Country('DE', 'Germany', '49'), Country('FR', 'France', '33'), Country('IT', 'Italy', '39'),
  Country('ES', 'Spain', '34'), Country('PT', 'Portugal', '351'), Country('NL', 'Netherlands', '31'),
  Country('BE', 'Belgium', '32'), Country('CH', 'Switzerland', '41'), Country('AT', 'Austria', '43'),
  Country('SE', 'Sweden', '46'), Country('NO', 'Norway', '47'), Country('DK', 'Denmark', '45'),
  Country('FI', 'Finland', '358'), Country('PL', 'Poland', '48'), Country('RU', 'Russia', '7'),
  Country('UA', 'Ukraine', '380'), Country('TR', 'Türkiye', '90'), Country('GR', 'Greece', '30'),
  Country('SA', 'Saudi Arabia', '966'), Country('AE', 'United Arab Emirates', '971'), Country('QA', 'Qatar', '974'),
  Country('KW', 'Kuwait', '965'), Country('BH', 'Bahrain', '973'), Country('OM', 'Oman', '968'),
  Country('JO', 'Jordan', '962'), Country('LB', 'Lebanon', '961'), Country('IQ', 'Iraq', '964'),
  Country('IR', 'Iran', '98'), Country('IL', 'Israel', '972'), Country('EG', 'Egypt', '20'),
  Country('ZA', 'South Africa', '27'), Country('NG', 'Nigeria', '234'), Country('KE', 'Kenya', '254'),
  Country('GH', 'Ghana', '233'), Country('ET', 'Ethiopia', '251'), Country('MA', 'Morocco', '212'),
  Country('DZ', 'Algeria', '213'), Country('TN', 'Tunisia', '216'),
  Country('CN', 'China', '86'), Country('JP', 'Japan', '81'), Country('KR', 'South Korea', '82'),
  Country('HK', 'Hong Kong', '852'), Country('SG', 'Singapore', '65'), Country('MY', 'Malaysia', '60'),
  Country('TH', 'Thailand', '66'), Country('VN', 'Vietnam', '84'), Country('ID', 'Indonesia', '62'),
  Country('PH', 'Philippines', '63'), Country('MM', 'Myanmar', '95'), Country('KH', 'Cambodia', '855'),
  Country('BR', 'Brazil', '55'), Country('MX', 'Mexico', '52'), Country('AR', 'Argentina', '54'),
  Country('CL', 'Chile', '56'), Country('CO', 'Colombia', '57'), Country('PE', 'Peru', '51'),
];

Country countryByIso(String iso) => countries.firstWhere((c) => c.iso == iso, orElse: () => countries.first);

/// Splits a stored number ("+8801630573079" or a plain local one) into country + national part.
({Country country, String national}) splitPhone(String stored, Country fallback) {
  var v = stored.trim();
  if (v.startsWith('00')) v = '+${v.substring(2)}';
  if (!v.startsWith('+')) return (country: fallback, national: v);
  final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
  for (final len in [3, 2, 1]) {
    if (digits.length <= len) continue;
    final code = digits.substring(0, len);
    for (final c in countries) {
      if (c.dial == code) return (country: c, national: digits.substring(len));
    }
  }
  return (country: fallback, national: digits);
}

/// Builds the number we store: "+<country code><number without leading zeros>".
String composePhone(Country c, String typed) {
  final t = typed.trim();
  if (t.isEmpty) return '';
  if (t.startsWith('+')) return '+${t.replaceAll(RegExp(r'[^0-9]'), '')}';
  final d = t.replaceAll(RegExp(r'[^0-9]'), '').replaceFirst(RegExp(r'^0+'), '');
  return d.isEmpty ? '' : '+${c.dial}$d';
}

/// Button showing the flag and dial code; opens the country list.
class CountryButton extends StatelessWidget {
  const CountryButton({super.key, required this.country, required this.onTap});
  final Country country;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(14)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(country.flag, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 6),
          Text('+${country.dial}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          const Icon(Icons.expand_more_rounded, size: 20),
        ]),
      ),
    );
  }
}

Future<Country?> showCountryPicker(BuildContext context, Country selected) {
  return showModalBottomSheet<Country>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => _CountrySheet(selected: selected),
  );
}

class _CountrySheet extends StatefulWidget {
  const _CountrySheet({required this.selected});
  final Country selected;
  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final q = _q.toLowerCase().replaceFirst('+', '');
    final list = countries.where((c) => q.isEmpty || c.name.toLowerCase().contains(q) || c.dial.startsWith(q) || c.iso.toLowerCase() == q).toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .75,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom),
          child: Column(children: [
            TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: deco(context, 'Search country or code', icon: Icons.search_rounded),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final c = list[i];
                  final sel = c.iso == widget.selected.iso;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Text(c.flag, style: const TextStyle(fontSize: 26)),
                    title: Text(c.name, style: TextStyle(fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('+${c.dial}', style: TextStyle(color: cs.onSurfaceVariant)),
                      if (sel) ...[const SizedBox(width: 8), Icon(Icons.check_circle_rounded, color: cs.primary)],
                    ]),
                    onTap: () => Navigator.pop(context, c),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
