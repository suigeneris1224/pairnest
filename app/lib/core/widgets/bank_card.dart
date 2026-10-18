import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/providers.dart';
import '../format.dart';
import 'nest_ui.dart';
import 'wallet_brands.dart';

/// "₱4,200", "₱3,200 owed" on a credit card, or "Balance private".
String walletBalanceText(Wallet w, {bool hide = false}) {
  final b = w.balance;
  if (b == null) return 'Balance private';
  if (hide) return w.isCredit ? '₱•••• owed' : '₱••••';
  if (w.isCredit) {
    if (b < 0) return '${peso(-b)} owed';
    return b == 0 ? 'Nothing owed' : '${peso(b)} credit';
  }
  return b < 0 ? '-${peso(-b)}' : peso(b);
}

/// What a wallet's card says about whose it is: "ALEX & SAM" or "ALEX".
String walletHolder(Wallet w, Me me) => (w.isShared ? me.coupleNames : (w.ownerName.isEmpty ? me.user.name : w.ownerName)).toUpperCase();

Widget _emblem(Wallet w) {
  final icon = switch (w.kind) {
    'ewallet' => Icons.phone_iphone_rounded,
    'cash' => Icons.payments_rounded,
    _ => null,
  };
  if (icon == null) return const SizedBox.shrink();
  return Container(
    width: 36,
    height: 27,
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(6)),
    child: Icon(icon, size: 18, color: Colors.white),
  );
}

/// A wallet as a local bank or e-wallet card, in the brand's colours.
class BankCard extends ConsumerWidget {
  const BankCard(this.wallet, {super.key, this.onTap, this.hide});

  final Wallet wallet;
  final VoidCallback? onTap;

  /// Overrides the hide-amounts setting, e.g. for the editor preview.
  final bool? hide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = brandOf(wallet.provider);
    final me = ref.watch(meProvider);
    final bool hidden = hide ?? ref.watch(hideAmountsProvider);
    const soft = TextStyle(color: Color(0xDDFFFFFF), fontSize: 12.5);
    final big = Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontSize: 30, height: 1.1);
    final mine = wallet.ownerId == me.user.id;

    return Semantics(
      label: '${wallet.name}, ${walletKinds[wallet.kind] ?? ''}, ${walletBalanceText(wallet, hide: hidden)}',
      container: true,
      child: WalletCard(
        title: wallet.name,
        holder: walletHolder(wallet, me),
        number: wallet.last4 ?? '',
        colors: brand.colors,
        accent: brand.accent,
        emblem: wallet.kind == 'debit' || wallet.kind == 'credit' || wallet.kind == 'bank' ? null : _emblem(wallet),
        onTap: onTap,
        trailing: wallet.isShared
            ? const _Tag('Ours', icon: Icons.favorite_rounded)
            : (mine ? null : _Tag(wallet.ownerName.isEmpty ? 'Partner' : wallet.ownerName)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              brand.key == 'other' || brand.name == wallet.name
                  ? (walletKinds[wallet.kind] ?? '')
                  : '${brand.name} · ${walletKinds[wallet.kind] ?? ''}',
              style: soft,
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                walletBalanceText(wallet, hide: hidden),
                style: wallet.balance == null ? big?.copyWith(fontSize: 20, color: const Color(0xDDFFFFFF)) : big,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, {this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 12, color: Colors.white), const SizedBox(width: 4)],
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

/// A small brand-coloured card for Home's wallet row.
class MiniWalletCard extends ConsumerWidget {
  const MiniWalletCard(this.wallet, {super.key, this.onTap});

  final Wallet wallet;
  final VoidCallback? onTap;

  static const size = Size(132, 80);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = brandOf(wallet.provider);
    final hide = ref.watch(hideAmountsProvider);
    final radius = BorderRadius.circular(14);
    return Semantics(
      button: true,
      label: '${wallet.name}, ${walletBalanceText(wallet, hide: hide)}',
      excludeSemantics: true,
      child: Material(
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          width: size.width,
          height: size.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: brand.colors, stops: const [0, 0.45, 1]),
          ),
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                if (brand.accent != null) Positioned(top: 0, left: 0, right: 0, height: 3, child: ColoredBox(color: brand.accent!)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              wallet.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5),
                            ),
                          ),
                          if (wallet.isShared) const Icon(Icons.favorite_rounded, size: 12, color: Colors.white),
                        ],
                      ),
                      const Spacer(),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          walletBalanceText(wallet, hide: hide),
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: wallet.balance == null ? 11.5 : 15),
                        ),
                      ),
                      if (wallet.last4 != null)
                        Text('•••• ${wallet.last4}', style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 10, letterSpacing: 1.2)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A round brand badge, for pickers.
class BrandBadge extends StatelessWidget {
  const BrandBadge(this.brand, {super.key, this.size = 40, this.selected = false});

  final WalletBrand brand;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [brand.light, brand.dark]),
      border: selected ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2.5) : null,
    ),
    child: Text(
      brand.badge,
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * (brand.badge.length > 2 ? 0.28 : 0.36)),
    ),
  );
}
