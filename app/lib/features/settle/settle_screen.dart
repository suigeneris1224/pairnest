import '../../core/pref_keys.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/mascot/mascot.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/palettes.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/member_avatar.dart';
import '../../core/widgets/member_colors.dart';
import '../../core/widgets/nest_ui.dart';
import '../../core/widgets/wallet_picker.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

/// "Sam owes you ₱415" or "You owe Sam ₱415", from the signed-in user's side.
String owesLabel(Owes owes, int meId, {bool hideAmount = false}) {
  final amount = hideAmount ? '₱••••' : peso(owes.amount);
  return owes.from.id == meId ? 'You owe ${owes.to.name} $amount' : '${owes.from.name} owes you $amount';
}

String _plain(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

/// Asks how much was paid back (the full balance by default), records it and
/// offers Undo.
Future<void> settleUp(BuildContext context, WidgetRef ref, Owes owes) async {
  // The sheet preselects your wallet, so have them loaded (fine without).
  await ref.read(walletsProvider.future).catchError((Object _) => const <Wallet>[]);
  if (!context.mounted) return;
  final picked = await showModalBottomSheet<({double amount, int? fromWallet, int? toWallet})>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => _SettleSheet(owes),
  );
  if (picked == null || !context.mounted) return;
  final amount = picked.amount;
  final meId = ref.read(meProvider).user.id;
  final mine = owes.from.id == meId ? picked.fromWallet : picked.toWallet;
  if (mine != null) ref.read(prefsProvider).setInt(_lastSettleWalletKey, mine);
  final repo = ref.read(repositoryProvider);
  final messenger = ScaffoldMessenger.of(context);
  final container = ProviderScope.containerOf(context, listen: false);
  try {
    final settlement = await repo.settleUp(
      amount: amount,
      fromUserId: owes.from.id,
      fromWalletId: picked.fromWallet,
      toWalletId: picked.toWallet,
    );
    invalidateMoney(ref);
    ref.read(mascotControllerProvider).react(MascotReaction.cheer);
    HapticFeedback.lightImpact();
    showSnackOn(
      messenger,
      'Settled up · ${peso(amount)}',
      actionLabel: 'Undo',
      onAction: () => repo
          .deleteSettlement(settlement.id)
          .then((_) => invalidateMoneyIn(container), onError: (Object e) => showSnackOn(messenger, friendlyError(e))),
    );
  } catch (e) {
    showSnackOn(messenger, friendlyError(e));
  }
}

const _lastSettleWalletKey = PrefKeys.lastSettleWallet;

class SettleScreen extends ConsumerWidget {
  const SettleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(balanceProvider);
    return Scaffold(
      body: NestBackground(
        child: SafeArea(
          child: Column(
            children: [
              const PageHeader('Settle Up'),
              Expanded(
                child: switch (balance) {
                  AsyncData(:final value) when !value.hasPartner => EmptyState(
                    title: 'Invite your partner to start splitting',
                    message: 'Once your partner joins, Pairnest keeps track of who paid for what, and who owes whom.',
                    actionLabel: 'Show invite code',
                    onAction: () => context.go('/us'),
                  ),
                  AsyncData(:final value) => RefreshIndicator(
                    onRefresh: () => ref.refresh(balanceProvider.future),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      children: [
                        FadeSlideIn(child: _BalanceHero(value)),
                        const SizedBox(height: 14),
                        FadeSlideIn(index: 1, child: _WhoPaidCard(value)),
                        const SizedBox(height: 14),
                        FadeSlideIn(index: 2, child: _HistoryCard(value.settlements)),
                      ],
                    ),
                  ),
                  AsyncError(:final error) => ErrorRetry(error: error, onRetry: () => ref.invalidate(balanceProvider)),
                  _ => const SkeletonList(cards: 2),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceHero extends ConsumerWidget {
  const _BalanceHero(this.balance);

  final SplitBalance balance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meId = ref.watch(meProvider).user.id;
    final hide = ref.watch(hideAmountsProvider);
    final owes = balance.owes;
    const soft = TextStyle(color: Color(0xDDFFFFFF), fontSize: 13, height: 1.35);
    final big = Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontSize: 36, height: 1.1);

    if (owes == null) {
      return HeroCard(
        child: Row(
          children: [
            const MascotPair(width: 110, leaves: false),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("You're all even", style: big?.copyWith(fontSize: 24)),
                  const SizedBox(height: 6),
                  const Text('Nothing to settle. Nice teamwork!', style: soft),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final iOwe = owes.from.id == meId;
    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            iOwe ? 'You owe ${owes.to.name}' : '${owes.from.name} owes you',
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(hide ? '₱••••' : peso(owes.amount), style: big),
          const SizedBox(height: 6),
          const Text('Split expenses shared 50/50, minus settle-ups.', style: soft),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: context.pn.isDark ? const Color(0xFF2E3D63) : context.pn.primaryDeep,
            ),
            onPressed: () => settleUp(context, ref, owes),
            icon: const Icon(Icons.handshake_outlined, size: 20),
            label: const Text('Settle up'),
          ),
        ],
      ),
    );
  }
}

class _WhoPaidCard extends ConsumerWidget {
  const _WhoPaidCard(this.balance);

  final SplitBalance balance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pn;
    final me = ref.watch(meProvider);
    final hide = ref.watch(hideAmountsProvider);
    final most = balance.members.fold<double>(0, (m, x) => x.paidThisMonth > m ? x.paidThisMonth : m);

    return SectionCard(
      title: 'Who paid this month',
      icon: Icons.people_alt_outlined,
      action: 'Activity',
      onAction: () => context.go('/activity'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final m in balance.members) ...[
            Row(
              children: [
                MemberAvatar(userId: m.id, name: m.name, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(m.id == me.user.id ? '${m.name} (you)' : m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Text(hide ? '₱••••' : peso(m.paidThisMonth), style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            SoftProgress(most == 0 ? 0 : m.paidThisMonth / most, color: memberColor(context, me.couple, m.id)),
            const SizedBox(height: 14),
          ],
          if (balance.members.any((m) => m.toppedUpThisMonth > 0) || balance.sharedSpentThisMonth > 0) ...[
            Text(
              'Put into shared wallets',
              style: TextStyle(color: p.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            for (final m in balance.members)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 16, color: memberColor(context, me.couple, m.id)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(m.id == me.user.id ? 'You' : m.name)),
                    Text(hide ? '₱••••' : peso(m.toppedUpThisMonth), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            if (balance.sharedSpentThisMonth > 0)
              Text(
                '${hide ? '₱••••' : peso(balance.sharedSpentThisMonth)} spent from shared wallets this month',
                style: TextStyle(color: p.muted, fontSize: 12.5),
              ),
            const SizedBox(height: 12),
          ],
          Text(
            "Split expenses are shared 50/50. Personal ones and spending from shared wallets don't count toward the balance.",
            style: TextStyle(color: p.muted, fontSize: 12.5, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard(this.settlements);

  final List<Settlement> settlements;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pn;
    final meId = ref.watch(meProvider).user.id;
    final hide = ref.watch(hideAmountsProvider);
    String who(int id, String name) => id == meId ? 'You' : name;
    String whom(int id, String name) => id == meId ? 'you' : name;

    return SectionCard(
      title: 'Settle-up history',
      icon: Icons.history_rounded,
      child: settlements.isEmpty
          ? Text('No settle-ups yet. When one of you pays the other back, record it here.', style: TextStyle(color: p.muted, height: 1.4))
          : Column(
              children: [
                for (final (i, s) in settlements.indexed) ...[
                  if (i > 0) Divider(height: 14, color: p.border),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _setMyWallet(context, ref, s),
                    child: Row(
                      children: [
                        const PastelIcon(Icons.handshake_outlined, tone: Pastel.peach, size: 38),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${who(s.fromId, s.fromName)} paid ${whom(s.toId, s.toName)}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                [
                                  // Each side tracks its own wallet, so often only one is known.
                                  if (s.fromWalletName != null && s.toWalletName != null)
                                    '${s.fromWalletName} → ${s.toWalletName}'
                                  else if (s.fromWalletName != null)
                                    'From ${s.fromWalletName}'
                                  else if (s.toWalletName != null)
                                    'Into ${s.toWalletName}',
                                  shortDate(s.settledOn),
                                ].join(' · '),
                                style: TextStyle(color: p.muted, fontSize: 12),
                              ),
                              if ((s.fromId == meId ? s.fromWalletId : s.toWalletId) == null)
                                Text(
                                  'Set your wallet',
                                  style: TextStyle(color: p.primaryDeep, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                            ],
                          ),
                        ),
                        Text(hide ? '₱••••' : peso(s.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

/// Lets you say which of your own wallets your side of [s] went through,
/// e.g. where money your partner recorded paying you landed.
Future<void> _setMyWallet(BuildContext context, WidgetRef ref, Settlement s) async {
  final paid = s.fromId == ref.read(meProvider).user.id;
  final picked = await showModalBottomSheet<({int? walletId})>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => _MyWalletSheet(paid: paid, initial: paid ? s.fromWalletId : s.toWalletId),
  );
  if (picked == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(repositoryProvider).setSettlementWallet(s.id, picked.walletId);
    invalidateMoney(ref);
    showSnackOn(messenger, picked.walletId == null ? 'Wallet cleared.' : 'Wallet saved.');
  } catch (e) {
    showSnackOn(messenger, friendlyError(e));
  }
}

class _MyWalletSheet extends StatefulWidget {
  const _MyWalletSheet({required this.paid, required this.initial});

  final bool paid;
  final int? initial;

  @override
  State<_MyWalletSheet> createState() => _MyWalletSheetState();
}

class _MyWalletSheetState extends State<_MyWalletSheet> {
  late int? _wallet = widget.initial;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetTitle(widget.paid ? 'Where it came from' : 'Where it landed'),
          Text("Your side only. Your partner's wallets are theirs to track.", style: TextStyle(color: context.pn.muted, fontSize: 12.5)),
          WalletDropdown(
            label: widget.paid ? 'Paid from your wallet' : 'Received in your wallet',
            personalOnly: true,
            noneLabel: 'Not tracked',
            value: _wallet,
            onChanged: (id) => setState(() => _wallet = id),
          ),
          const SizedBox(height: 18),
          FilledButton(onPressed: () => Navigator.pop(context, (walletId: _wallet)), child: const Text('Save')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ],
      ),
    ),
  );
}

class _SettleSheet extends ConsumerStatefulWidget {
  const _SettleSheet(this.owes);

  final Owes owes;

  @override
  ConsumerState<_SettleSheet> createState() => _SettleSheetState();
}

class _SettleSheetState extends ConsumerState<_SettleSheet> {
  late final _amount = TextEditingController(text: _plain(widget.owes.amount));
  String? _error;
  late int? _fromWallet = _myDefault(widget.owes.from.id);
  late int? _toWallet = _myDefault(widget.owes.to.id);

  /// Your side starts on the wallet you settled from last time, else your
  /// Cash; your partner's side is never set from here.
  int? _myDefault(int userId) {
    final me = ref.read(meProvider).user.id;
    if (userId != me) return null;
    final mine = [
      for (final w in knownWallets(ref))
        if (w.ownerId == me) w,
    ];
    final last = ref.read(prefsProvider).getInt(_lastSettleWalletKey);
    return mine.where((w) => w.id == last).firstOrNull?.id ?? mine.where((w) => w.builtin).firstOrNull?.id;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double? get _value => double.tryParse(_amount.text.replaceAll(',', ''));

  void _submit() {
    final v = _value;
    if (v == null || v <= 0) {
      setState(() => _error = 'Enter an amount greater than zero.');
    } else if (v > widget.owes.amount + 0.001) {
      setState(() => _error = "That's more than the ${peso(widget.owes.amount)} owed.");
    } else {
      Navigator.pop(context, (amount: v, fromWallet: _fromWallet, toWallet: _toWallet));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    final me = ref.watch(meProvider);
    final owes = widget.owes;
    String name(Member m) => m.id == me.user.id ? 'You' : m.name;
    final v = _value;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetTitle('Settle up'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Person(owes.from, name(owes.from), memberColor(context, me.couple, owes.from.id)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Icon(Icons.arrow_forward_rounded, color: p.muted),
                  ),
                  _Person(owes.to, name(owes.to), memberColor(context, me.couple, owes.to.id)),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _amount,
                autofocus: false,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: InputDecoration(labelText: 'Amount paid back', prefixText: '₱ ', errorText: _error),
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 8),
              Text('Paying part of it is fine. The rest stays on the balance.', style: TextStyle(color: p.muted, fontSize: 12.5)),
              // Only your side: your partner's wallets are theirs to track.
              if (owes.from.id == me.user.id)
                WalletDropdown(
                  label: 'Paid from your wallet',
                  userId: owes.from.id,
                  personalOnly: true,
                  noneLabel: 'Not tracked',
                  value: _fromWallet,
                  onChanged: (id) => setState(() => _fromWallet = id),
                )
              else
                WalletDropdown(
                  label: 'Received in your wallet',
                  userId: owes.to.id,
                  personalOnly: true,
                  noneLabel: 'Not tracked',
                  value: _toWallet,
                  onChanged: (id) => setState(() => _toWallet = id),
                ),
              const SizedBox(height: 18),
              FilledButton(onPressed: _submit, child: Text(v == null || v <= 0 ? 'Record payment' : 'Record ${peso(v)}')),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ],
          ),
        ),
      ),
    );
  }
}

class _Person extends StatelessWidget {
  const _Person(this.member, this.label, this.color);

  final Member member;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      MemberAvatar(userId: member.id, name: member.name, size: 48),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    ],
  );
}
