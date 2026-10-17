import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../motion/motion.dart';
import '../theme/palettes.dart';

/// Rounded cream card with a soft shadow, the main surface in Pairnest.
class PairnestCard extends StatelessWidget {
  const PairnestCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    final radius = BorderRadius.circular(24);
    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? 0.25 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: color ?? p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: p.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    return onTap == null ? card : PressScale(child: card);
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 0, 8),
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          if (action != null)
            TextButton(
              onPressed: onAction,
              child: Text(action!, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

/// Rounded progress bar used for budgets and goals.
class SoftProgress extends StatelessWidget {
  const SoftProgress(this.value, {super.key, this.color, this.height = 8});

  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    final v = value.clamp(0.0, 1.0);
    final barColor = value > 1 ? const Color(0xFFD9534F) : (color ?? p.primary);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: p.soft)),
            // Fills from empty on first show, then glides between values.
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: v),
              duration: Motion.reduced(context) ? Duration.zero : Motion.slow * 1.5,
              curve: Motion.curve,
              builder: (context, w, _) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: w,
                child: Container(
                  decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(height)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Segmented pill tabs (Recent / Both / Trends, Expense / Income, ...).
class PillTabs extends StatelessWidget {
  const PillTabs({super.key, required this.labels, required this.index, required this.onChanged});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.soft.withValues(alpha: p.isDark ? 1 : 0.6),
        borderRadius: BorderRadius.circular(40),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: i == index ? p.primaryDeep : Colors.transparent,
                    borderRadius: BorderRadius.circular(40),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: i == index ? p.onPrimary : p.muted),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PartnerAvatar extends StatelessWidget {
  const PartnerAvatar({super.key, required this.name, required this.color, this.size = 36});

  final String name;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: context.pn.surface, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.42),
      ),
    );
  }
}

/// Two overlapping avatars, used for "both of us" markers.
class CoupleAvatars extends StatelessWidget {
  const CoupleAvatars({super.key, required this.names, required this.colors, this.size = 28});

  final List<String> names;
  final List<Color> colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + (names.length - 1) * size * 0.6,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < names.length; i++)
            Positioned(
              left: i * size * 0.6,
              child: PartnerAvatar(name: names[i], color: colors[i % colors.length], size: size),
            ),
        ],
      ),
    );
  }
}

/// Title with a back arrow, like the mockup's sub-screens.
class PageHeader extends StatelessWidget {
  const PageHeader(this.title, {super.key, this.trailing, this.showBack = true, this.onBack});

  final String title;
  final Widget? trailing;
  final bool showBack;

  /// Overrides the default pop (or go home).
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_rounded),
              // Opened via a deep link there's nothing to pop, so head home.
              onPressed: onBack ?? () => canPop ? Navigator.of(context).pop() : context.go('/home'),
            )
          else
            const SizedBox(width: 12),
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
          ?trailing,
        ],
      ),
    );
  }
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: context.pn.muted),
            const SizedBox(height: 12),
            Text(friendlyError(error), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

String friendlyError(Object error) {
  final text = error.toString();
  return text.startsWith('Exception: ') ? text.substring(11) : text;
}

void showSnack(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) =>
    showSnackOn(ScaffoldMessenger.of(context), message, actionLabel: actionLabel, onAction: onAction);

/// Like [showSnack], for callers that captured the messenger before their
/// route popped (e.g. "Saved · Undo" after closing a sheet).
void showSnackOn(ScaffoldMessengerState messenger, String message, {String? actionLabel, VoidCallback? onAction}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: actionLabel != null && onAction != null ? SnackBarAction(label: actionLabel, onPressed: onAction) : null,
        // Snack bars with an action persist by default; Undo should time out.
        persist: false,
        duration: const Duration(seconds: 5),
      ),
    );
}
