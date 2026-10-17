import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/motion/motion.dart';
import 'core/theme/app_theme.dart';
import 'data/providers.dart';
import 'router.dart';

class PairnestApp extends ConsumerWidget {
  const PairnestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(themeProvider);
    return MaterialApp.router(
      title: 'Pairnest',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(palette, googleFonts: ref.watch(useGoogleFontsProvider)),
      themeAnimationDuration: Motion.slow,
      themeAnimationCurve: Motion.curve,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => _PhoneFrame(child: child!),
    );
  }
}

/// On wide (web/desktop) screens, keep the mobile layout in a centered column.
class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 600) return child;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return ColoredBox(
      color: Color.lerp(bg, Colors.black, 0.04)!,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          margin: const EdgeInsets.symmetric(vertical: 24),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(36),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 40, offset: const Offset(0, 16))],
          ),
          child: child,
        ),
      ),
    );
  }
}
