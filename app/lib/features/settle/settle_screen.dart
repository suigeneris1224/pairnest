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
  final amount = await showModalBottomSheet<double>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => _SettleSheet(owes),
  );
  if (amount == null || !context.mounted) return;
  final repo = ref.read(repositoryProvider);
  final messenger = ScaffoldMessenger.of(context);
  final container = ProviderScope.containerOf(context, listen: false);
  try {
    final settlement = await repo.settleUp(amount: amount, fromUserId: owes.from.id);
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
                  Row(
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
                            Text(shortDate(s.settledOn), style: TextStyle(color: p.muted, fontSize: 12)),
                          ],
                        ),
                      ),
                      Text(hide ? '₱••••' : peso(s.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
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
      Navigator.pop(context, v);
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
