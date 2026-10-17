import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/nest_ui.dart';
import '../../core/motion/motion.dart';
import '../../core/mascot/mascot.dart';
import '../../core/theme/palettes.dart';
import '../../core/widgets/common.dart';
import '../../data/providers.dart';

/// "Make it yours" — first-run theme picker.
class ThemeSelectScreen extends ConsumerStatefulWidget {
  const ThemeSelectScreen({super.key});

  @override
  ConsumerState<ThemeSelectScreen> createState() => _ThemeSelectScreenState();
}

class _ThemeSelectScreenState extends ConsumerState<ThemeSelectScreen> {
  bool _busy = false;

  Future<void> _continue() async {
    setState(() => _busy = true);
    try {
      await ref.read(themeProvider.notifier).select(ref.read(themeProvider).id, share: true);
      ref.read(themeChosenProvider.notifier).set();
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    final text = Theme.of(context).textTheme;
    final selected = ref.watch(themeProvider);

    return Scaffold(
      body: NestBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Make it yours', style: text.headlineSmall),
                          const SizedBox(height: 8),
                          Text('Choose a color theme that matches\nyour style and vibe.', style: TextStyle(color: p.muted, height: 1.5)),
                        ],
                      ),
                    ),
                    const LeafSprigs(size: 64),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: PaletteGrid(selectedId: selected.id, onSelect: (id) => ref.read(themeProvider.notifier).select(id)),
                ),
                Text(
                  'Your partner will see the same theme.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: _busy ? null : _continue, child: const Text('Continue')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PaletteGrid extends StatelessWidget {
  const PaletteGrid({super.key, required this.selectedId, required this.onSelect});

  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.15,
      children: [
        for (final palette in allPalettes)
          PaletteCard(palette: palette, selected: palette.id == selectedId, onTap: () => onSelect(palette.id)),
      ],
    );
  }
}

class PaletteCard extends StatelessWidget {
  const PaletteCard({super.key, required this.palette, required this.selected, required this.onTap});

  final PairnestPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final current = context.pn;
    final tint = palette.isDark ? palette.surface : palette.soft;
    return Semantics(
      selected: selected,
      button: true,
      label: '${palette.name} theme',
      child: PressScale(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: palette.isDark ? 1 : 0.7),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: selected ? current.primaryDeep : Colors.transparent, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PaletteSwatch(palette: palette),
                    const Spacer(),
                    if (selected) Icon(Icons.check_circle_rounded, color: current.primaryDeep, size: 22),
                  ],
                ),
                const Spacer(),
                Text(
                  palette.name,
                  style: TextStyle(fontWeight: FontWeight.w700, color: palette.text),
                ),
                const SizedBox(height: 2),
                Text(palette.tagline, style: TextStyle(fontSize: 12, color: palette.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Two overlapping circles previewing a palette.
class PaletteSwatch extends StatelessWidget {
  const PaletteSwatch({super.key, required this.palette, this.size = 34});

  final PairnestPalette palette;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.6,
      height: size,
      child: Stack(
        children: [
          Positioned(
            right: 0,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.isDark ? palette.primary : palette.soft,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
          CircleAvatar(radius: size / 2, backgroundColor: palette.isDark ? const Color(0xFF3A4566) : palette.primary),
        ],
      ),
    );
  }
}
