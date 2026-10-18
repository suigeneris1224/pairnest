import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/providers.dart';
import 'bank_card.dart';
import 'wallet_brands.dart';

/// Picks one of [userId]'s wallets or a shared one, or none. Shows nothing
/// until the couple has wallets.
class WalletDropdown extends ConsumerWidget {
  const WalletDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.userId,
    this.personalOnly = false,
    this.noneLabel = 'No wallet',
  });

  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;

  /// Whose wallets can be picked; you by default.
  final int? userId;

  /// Only [userId]'s own wallets, not shared ones (e.g. settling up).
  final bool personalOnly;
  final String noneLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = userId ?? ref.watch(meProvider).user.id;
    final wallets = [
      for (final w in ref.watch(walletsProvider).value ?? const <Wallet>[])
        if (personalOnly ? w.ownerId == owner : w.usableBy(owner)) w,
    ];
    if (wallets.isEmpty) return const SizedBox.shrink();
    final current = wallets.any((w) => w.id == value) ? value : null;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DropdownButtonFormField<int?>(
        key: ValueKey('$label-$current'),
        initialValue: current,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        borderRadius: BorderRadius.circular(14),
        items: [
          DropdownMenuItem<int?>(value: null, child: Text(noneLabel)),
          for (final w in wallets)
            DropdownMenuItem<int?>(
              value: w.id,
              child: Row(
                children: [
                  BrandBadge(brandOf(w.provider), size: 24),
                  const SizedBox(width: 10),
                  Expanded(child: Text(w.isShared ? '${w.name} · Ours' : w.name, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

/// The wallets already loaded: the Wallets list, or Home's copy.
List<Wallet> knownWallets(WidgetRef ref) => ref.read(walletsProvider).value ?? ref.read(dashboardProvider).value?.wallets ?? const [];

/// A wallet's name by id, for "into GCash" and "from BPI" lines.
String? walletNameOf(WidgetRef ref, int? id) => id == null ? null : knownWallets(ref).where((w) => w.id == id).firstOrNull?.name;
