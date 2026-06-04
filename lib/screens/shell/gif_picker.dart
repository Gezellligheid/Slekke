import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/tenor_service.dart';

class GifPicker extends StatefulWidget {
  final ValueChanged<String> onSelected;

  const GifPicker({super.key, required this.onSelected});

  @override
  State<GifPicker> createState() => _GifPickerState();
}

class _GifPickerState extends State<GifPicker> {
  final _searchCtrl = TextEditingController();
  final _giphy = GifService();
  List<GifResult>? _results;
  bool _loading = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadTrending();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadTrending() async {
    setState(() => _loading = true);
    final results = await _giphy.trending();
    if (mounted) setState(() { _results = results; _loading = false; });
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) { _loadTrending(); return; }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    final results = await _giphy.search(q);
    if (mounted) setState(() { _results = results; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
      width: 320,
      height: 420,
      decoration: BoxDecoration(
        color: SlekkeColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SlekkeColors.elevated),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(140),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              style: const TextStyle(color: SlekkeColors.textPrimary, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Search GIFs…',
                prefixIcon: Icon(Icons.search, size: 18, color: SlekkeColors.textMuted),
                prefixIconConstraints: BoxConstraints(minWidth: 36, minHeight: 36),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ),
          // Label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _searchCtrl.text.isEmpty ? 'TRENDING' : 'RESULTS',
                style: const TextStyle(
                  color: SlekkeColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Grid
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: SlekkeColors.primary, strokeWidth: 2))
                : (_results == null || _results!.isEmpty)
                    ? const Center(
                        child: Text('No results',
                            style: TextStyle(
                                color: SlekkeColors.textMuted, fontSize: 13)))
                    : GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                          childAspectRatio: 1.2,
                        ),
                        itemCount: _results!.length,
                        itemBuilder: (_, i) => _GifTile(
                          result: _results![i],
                          onTap: () => widget.onSelected(_results![i].gifUrl),
                        ),
                      ),
          ),
          // Footer
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.gif_box_outlined, size: 14, color: SlekkeColors.textMuted),
                SizedBox(width: 4),
                Text('Powered by GIPHY',
                    style: TextStyle(color: SlekkeColors.textMuted, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    )); // Container + Material
  }
}

class _GifTile extends StatefulWidget {
  final GifResult result;
  final VoidCallback onTap;

  const _GifTile({required this.result, required this.onTap});

  @override
  State<_GifTile> createState() => _GifTileState();
}

class _GifTileState extends State<_GifTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                widget.result.previewUrl,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(color: SlekkeColors.elevated),
                errorBuilder: (ctx, err, _) =>
                    Container(color: SlekkeColors.elevated),
              ),
              if (_hovered)
                Container(
                  color: Colors.white.withAlpha(30),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
