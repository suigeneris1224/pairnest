import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/palettes.dart';
import '../../core/widgets/bank_card.dart';
import '../../core/widgets/categories.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/nest_ui.dart';
import '../../core/widgets/wallet_brands.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../activity/txn_tile.dart';
import 'move_sheet.dart';
import 'wallet_editor.dart';

/// Every wallet as a card you can swipe through, with the chosen one's
/// month, actions and recent transactions below.
class WalletsScreen extends ConsumerStatefulWidget {
  const WalletsScreen({super.key, this.initialId, this.sharedOnly = false});

  /// Opens on this wallet, e.g. when tapped on Home.
  final int? initialId;

  /// Opens on the Ours filter.
  final bool sharedOnly;

  @override
  ConsumerState<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends ConsumerState<WalletsScreen> {
  late int _filter = widget.sharedOnly ? 1 : 0;
  int _index = 0;
  PageController? _pages;
  late int? _jumpTo = widget.initialId;

  @override
  void dispose() {
    _pages?.dispose();
    super.dispose();
  }

  List<Wallet> _filtered(List<Wallet> all, int me) => switch (_filter) {
    1 => all.where((w) => w.isShared).toList(),
    2 => all.where((w) => w.ownerId == me).toList(),
    3 => all.where((w) => !w.isShared && w.ownerId != me).toList(),
    _ => all,
  };

  PageController _controller(List<Wallet> shown) {
    if (_jumpTo != null) {
      final i = shown.indexWhere((w) => w.id == _jumpTo);
      _jumpTo = null;
      if (i >= 0) {
        _index = i;
        _pages?.dispose();
        _pages = null;
      }
    }
    if (_index >= shown.length) _index = shown.isEmpty ? 0 : shown.length - 1;
    return _pages ??= PageController(viewportFraction: 0.88, initialPage: _index);
  }

  void _setFilter(int f) => setState(() {
    _filter = f;
    _index = 0;
    _pages?.dispose();
    _pages = null;
  });

  @override
  Widget build(BuildContext context) {
    final wallets = ref.watch(walletsProvider);
    return Scaffold(
      body: NestBackground(
        child: SafeArea(
          child: Column(
            children: [
              PageHeader(
                'Our Wallets',
                trailing: IconButton(
                  tooltip: 'Add wallet',
                  icon: const Icon(Icons.add_rounded),
                  onPressed: () => openWalletEditor(context),
                ),
              ),
              Expanded(
                child: switch (wallets) {
                  AsyncData(:final value) when value.isEmpty => const _Empty(),
                  AsyncData(:final value) => _body(value),
                  AsyncError(:final error) => ErrorRetry(error: error, onRetry: () => ref.invalidate(walletsProvider)),
                  _ => const SkeletonList(cards: 2),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(List<Wallet> all) {
    final me = ref.watch(meProvider);
    final partner = me.partner;
    final shown = _filtered(all, me.user.id);
    final pages = _controller(shown);
    final selected = shown.isEmpty ? null : shown[_index];

    return RefreshIndicator(
      onRefresh: () => ref.refresh(walletsProvider.future),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 10), child: _Summary(all)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: PillTabs(
              labels: ['All', 'Ours', 'Mine', if (partner != null) "${partner.name}'s"],
              index: _filter,
              onChanged: _setFilter,
            ),
          ),
          const SizedBox(height: 14),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Text(
                'No wallets here yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.pn.muted),
              ),
            )
          else ...[
            SizedBox(
              height: WalletCard.minHeight + 26,
              // Mouse and trackpad drags swipe too, for the web.
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
                child: PageView.builder(
                  controller: pages,
                  itemCount: shown.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.fromLTRB(6, 2, 6, 24),
                    child: BankCard(
                      shown[i],
                      key: ValueKey('wallet-card-${shown[i].id}'),
                      // Tapping a peeking card brings it to the front.
                      onTap: i == _index ? null : () => pages.animateToPage(i, duration: Motion.medium, curve: Curves.easeOutCubic),
                    ),
                  ),
                ),
              ),
            ),
            if (shown.length > 1) _Dots(count: shown.length, index: _index),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AnimatedSwitcher(
                duration: Motion.medium,
                child: _Details(selected!, key: ValueKey(selected.id)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Summary extends ConsumerWidget {
  const _Summary(this.wallets);

  final List<Wallet> wallets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pn;
    final hide = ref.watch(hideAmountsProvider);
    final known = wallets.where((w) => w.balance != null);
    final have = known.where((w) => !w.isCredit).fold(0.0, (a, w) => a + w.balance!);
    final owed = known.where((w) => w.isCredit && w.balance! < 0).fold(0.0, (a, w) => a - w.balance!);
    String money(double v) => hide ? '₱••••' : peso(v);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: money(have),
            style: TextStyle(fontWeight: FontWeight.w700, color: p.heading, fontSize: 15),
          ),
          TextSpan(text: ' across ${known.length} ${known.length == 1 ? 'wallet' : 'wallets'}'),
          if (owed > 0) ...[
            const TextSpan(text: ' · '),
            TextSpan(
              text: money(owed),
              style: TextStyle(fontWeight: FontWeight.w700, color: p.heading),
            ),
            const TextSpan(text: ' owed on cards'),
          ],
        ],
      ),
      style: TextStyle(color: p.muted, fontSize: 13),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: Motion.fast,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(color: i == index ? p.primaryDeep : p.border, borderRadius: BorderRadius.circular(3)),
          ),
      ],
    );
  }
}

/// The chosen wallet: this month in and out, what you can do, and what went through it.
class _Details extends ConsumerWidget {
  const _Details(this.wallet, {super.key});

  final Wallet wallet;

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'Remove ${wallet.name}?',
      message: "Transactions already logged with it keep its name. You won't see it in your wallets any more.",
      keepLabel: 'Keep',
      confirmLabel: 'Remove',
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(repositoryProvider).archiveWallet(wallet.id);
      invalidateMoney(ref);
      if (context.mounted) showSnack(context, '${wallet.name} removed');
    } catch (e) {
      if (context.mounted) showSnack(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pn;
    final me = ref.watch(meProvider);
    final hide = ref.watch(hideAmountsProvider);
    final now = ref.watch(nowProvider)();
    final txns = ref.watch(transactionsProvider((monthStart(now), ''))).value ?? const <Txn>[];
    final mine = [
      for (final t in txns)
        if (t.walletId == wallet.id || t.toWalletId == wallet.id) t,
    ];
    final into = mine.where((t) => t.isIncome || t.isRelease || (t.isMove && t.toWalletId == wallet.id)).fold(0.0, (a, t) => a + t.amount);
    final out = mine
        .where((t) => !(t.isIncome || t.isRelease || (t.isMove && t.toWalletId == wallet.id)))
        .fold(0.0, (a, t) => a + t.amount);
    final canEdit = wallet.usableBy(me.user.id);
    final private = wallet.balance == null;
    final myCash = (ref.watch(walletsProvider).value ?? const <Wallet>[])
        .where((w) => w.isCash && w.ownerId == me.user.id && w.id != wallet.id)
        .firstOrNull;
    String money(double v) => hide ? '₱••••' : peso(v);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!private)
          Row(
            children: [
              Expanded(
                child: _Figure(label: 'In this month', value: money(into), color: incomeCategory.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Figure(label: 'Out this month', value: money(out), color: p.heading),
              ),
            ],
          ),
        const SizedBox(height: 12),
        if (canEdit)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (wallet.isShared)
                ActionChip(
                  avatar: const Icon(Icons.add_card_rounded, size: 18),
                  label: const Text('Top up'),
                  onPressed: () => openMoveSheet(context, ref, to: wallet),
                )
              else if (wallet.isCredit && (wallet.balance ?? 0) < 0)
                ActionChip(
                  avatar: const Icon(Icons.credit_score_rounded, size: 18),
                  label: const Text('Pay card'),
                  onPressed: () => openMoveSheet(context, ref, to: wallet, amount: -(wallet.balance!)),
                )
              else
                ActionChip(
                  avatar: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('Move money'),
                  onPressed: () => openMoveSheet(context, ref, from: wallet),
                ),
              if (myCash != null && !wallet.isCash && !wallet.isCredit && !wallet.isShared)
                ActionChip(
                  avatar: const Icon(Icons.local_atm_rounded, size: 18),
                  label: const Text('Withdraw cash'),
                  onPressed: () => openMoveSheet(context, ref, from: wallet, to: myCash),
                ),
              ActionChip(
                avatar: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Correct balance'),
                onPressed: () => correctWalletBalance(context, ref, wallet),
              ),
              ActionChip(
                avatar: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
                onPressed: () => openWalletEditor(context, existing: wallet),
              ),
              if (!wallet.builtin)
                ActionChip(
                  avatar: const Icon(Icons.archive_outlined, size: 18),
                  label: const Text('Remove'),
                  onPressed: () => _archive(context, ref),
                ),
            ],
          )
        else
          Text(
            private
                ? "${wallet.ownerName} keeps this wallet's balance private. Only ${wallet.ownerName} can change it."
                : 'Only ${wallet.ownerName} can change this wallet.',
            style: TextStyle(color: p.muted, fontSize: 12.5, height: 1.4),
          ),
        const SizedBox(height: 14),
        SectionCard(
          icon: Icons.receipt_long_rounded,
          title: 'This month',
          action: 'See all',
          onAction: () => context.go('/activity?wallet=${wallet.id}'),
          child: mine.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Nothing logged with ${wallet.name} this month. Pick it under "Paid with" when you add an expense.',
                    style: TextStyle(color: p.muted, fontSize: 12.5, height: 1.4),
                  ),
                )
              : Column(children: [for (final t in mine.take(8)) TxnTile(t)]),
        ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: p.muted, fontSize: 12)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: color),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    return Column(
      children: [
        const Expanded(
          child: EmptyState(
            title: 'Every peso, in one place',
            message: 'Add your GCash, Maya or bank cards. Log money in and out with them, and Pairnest keeps their balances for you.',
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick add',
                style: TextStyle(color: p.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final key in ['gcash', 'maya', 'maribank', 'gotyme', 'bpi', 'bdo', 'cash'])
                    Semantics(
                      button: true,
                      label: 'Add ${brandOf(key).name}',
                      excludeSemantics: true,
                      child: InkWell(
                        onTap: () => openWalletEditor(context, provider: key),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                          decoration: BoxDecoration(
                            color: p.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: p.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              BrandBadge(brandOf(key), size: 26),
                              const SizedBox(width: 8),
                              Text(
                                brandOf(key).name,
                                style: TextStyle(fontWeight: FontWeight.w600, color: p.heading),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
