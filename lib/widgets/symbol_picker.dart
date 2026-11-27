import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../theme.dart';

/// A symbol the parent chose, with a label ready for the card.
class SymbolChoice {
  const SymbolChoice({required this.assetPath, required this.label});
  final String assetPath;
  final String label;
}

/// Turns a symbol file name into a label a parent would write.
///
/// The bundled set names a verb as `bathe_,_to` and a possessive as
/// `shoe_-_mans`. The words after that separator qualify the entry in a
/// catalogue; the lead word is the one that belongs on the card.
String prettifySymbolName(String assetPath) {
  final List<String> kept = [];
  for (final String part in p.basenameWithoutExtension(assetPath).split('_')) {
    if (part == ',' || part == '-') break;
    if (part.isEmpty) continue;
    kept.add(part);
  }
  final String name = kept.join(' ').trim();
  if (name.isEmpty) return 'Symbol';
  return name[0].toUpperCase() + name.substring(1);
}

const double _gap = 12;

/// Opens the symbol library. Returns null when the parent backs out.
Future<SymbolChoice?> showSymbolPicker(BuildContext context) =>
    showModalBottomSheet<SymbolChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _SymbolPicker(),
    );

class _SymbolPicker extends StatefulWidget {
  const _SymbolPicker();

  @override
  State<_SymbolPicker> createState() => _SymbolPickerState();
}

class _SymbolPickerState extends State<_SymbolPicker> {
  final TextEditingController _search = TextEditingController();
  late final Future<List<SymbolChoice>> _symbols = _loadSymbols();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static Future<List<SymbolChoice>> _loadSymbols() async {
    final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(
      rootBundle,
    );
    final List<SymbolChoice> symbols =
        manifest
            .listAssets()
            .where((k) => k.startsWith('assets/symbols/') && k.endsWith('.svg'))
            .map(
              (k) => SymbolChoice(assetPath: k, label: prettifySymbolName(k)),
            )
            .toList()
          ..sort((a, b) => a.label.compareTo(b.label));
    return symbols;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.9,
      child: Padding(
        // Keep the search field above the on-screen keyboard.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: FutureBuilder<List<SymbolChoice>>(
          future: _symbols,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return _content(snapshot.requireData);
          },
        ),
      ),
    );
  }

  Widget _content(List<SymbolChoice> symbols) {
    final String query = _search.text.trim().toLowerCase();
    final List<SymbolChoice> shown = query.isEmpty
        ? symbols
        : symbols.where((s) => s.label.toLowerCase().contains(query)).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(_gap, _gap, _gap, 8),
          child: Text(
            'Choose a symbol',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _gap),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              // The bundled set is large, so browsing all of it is slow.
              hintText: 'Search ${symbols.length} symbols',
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear the search',
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                    ),
            ),
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(_gap),
                    child: Text(
                      symbols.isEmpty
                          ? 'No symbols are bundled with this app.'
                          : 'No symbol matches "${_search.text.trim()}".',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(_gap),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: AppTokens.symbolExtent,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: shown.length,
                  itemBuilder: (context, index) =>
                      _SymbolTile(choice: shown[index]),
                ),
        ),
      ],
    );
  }
}

class _SymbolTile extends StatelessWidget {
  const _SymbolTile({required this.choice});

  final SymbolChoice choice;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: choice.label,
    excludeSemantics: true,
    child: InkWell(
      onTap: () => Navigator.pop(context, choice),
      borderRadius: BorderRadius.circular(AppTokens.cardRadius),
      child: Column(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTokens.symbolPlate,
                borderRadius: BorderRadius.circular(AppTokens.cardRadius),
              ),
              child: SvgPicture.asset(choice.assetPath, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            choice.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}
