import '../../core/pref_keys.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/mascot/mascot.dart';
import '../../core/theme/palettes.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/nest_ui.dart';
import '../../core/widgets/wallet_picker.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import 'goals_screen.dart';

/// Moves money into a goal ([goal] preselected, else the first), logs it in
/// Activity and offers Undo.
Future<void> openTransfer(BuildContext context, WidgetRef ref, {Goal? goal}) async {
  final picked = await showModalBottomSheet<(Goal, double, int?)>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => _TransferSheet(initial: goal),
  );
  if (picked == null || !context.mounted) return;
  final (target, amount, walletId) = picked;
  final repo = ref.read(repositoryProvider);
  final messenger = ScaffoldMessenger.of(context);
  final container = ProviderScope.containerOf(context, listen: false);
  try {
    if (walletId != null) ref.read(prefsProvider).setInt(_lastTransferWalletKey, walletId);
    final result = await repo.contribute(target.id, amount, walletId: walletId);
    invalidateMoney(ref);
    HapticFeedback.lightImpact();
    final reached = target.saved < target.target && result.goal.saved >= result.goal.target;
    ref.read(mascotControllerProvider).react(reached ? MascotReaction.celebrate : MascotReaction.cheer);
    if (reached && context.mounted) showGoalCelebration(context, result.goal);
    final transferId = result.transferId;
    showSnackOn(
      messenger,
      '${peso(amount)} moved to ${target.name}',
      actionLabel: transferId == null ? null : 'Undo',
      onAction: transferId == null
          ? null
          : () => repo
                .deleteTransaction(transferId)
                .then((_) => invalidateMoneyIn(container), onError: (Object e) => showSnackOn(messenger, friendlyError(e))),
    );
  } catch (e) {
    showSnackOn(messenger, friendlyError(e));
  }
}

const _lastTransferWalletKey = PrefKeys.lastTransferWallet;

/// A short celebration when a transfer completes a goal: the birds bounce,
/// flap and send up hearts.
Future<void> showGoalCelebration(BuildContext context, Goal goal) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  builder: (sheet) {
    final p = sheet.pn;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: MascotPair(width: 170, leaves: false, animate: true, playOnMount: MascotReaction.celebrate)),
            const SizedBox(height: 8),
            Text(
              'You reached ${goal.name}!',
              textAlign: TextAlign.center,
              style: Theme.of(sheet).textTheme.headlineSmall?.copyWith(color: p.heading),
            ),
            const SizedBox(height: 6),
            Text(
              '${peso(goal.saved)} saved together. That took teamwork.',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.muted, height: 1.4),
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: () => Navigator.pop(sheet), child: const Text('Yay!')),
          ],
        ),
      ),
    );
  },
);

class _TransferSheet extends ConsumerStatefulWidget {
  const _TransferSheet({this.initial});

  final Goal? initial;

  @override
  ConsumerState<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends ConsumerState<_TransferSheet> {
  final _amount = TextEditingController();
  late int? _goalId = widget.initial?.id;
  late int? _walletId = ref.read(prefsProvider).getInt(_lastTransferWalletKey);

  @override
  void initState() {
    super.initState();
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double? get _value => double.tryParse(_amount.text.replaceAll(',', ''));

  /// The remembered wallet only if it's still one you can use.
  int? _usableWallet() {
    final me = ref.read(meProvider).user.id;
    final wallets = ref.read(walletsProvider).value ?? const <Wallet>[];
    return wallets.any((w) => w.id == _walletId && w.usableBy(me)) ? _walletId : null;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    final goals = ref.watch(activeGoalsProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: switch (goals) {
            AsyncData(:final value) when value.isEmpty => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SheetTitle('Transfer to a goal'),
                const SizedBox(height: 10),
                Text('Create a savings goal first, then move money into it from here.', style: TextStyle(color: p.muted, height: 1.4)),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    GoRouter.of(context).go('/goals?new=1');
                  },
                  child: const Text('Create a goal'),
                ),
              ],
            ),
            AsyncData(:final value) => _form(value),
            AsyncError(:final error) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(friendlyError(error), textAlign: TextAlign.center),
            ),
            _ => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          },
        ),
      ),
    );
  }

  Widget _form(List<Goal> goals) {
    final p = context.pn;
    final goal = goals.where((g) => g.id == _goalId).firstOrNull ?? goals.first;
    final v = _value;
    final valid = v != null && v > 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetTitle('Transfer to a goal'),
        const SizedBox(height: 4),
        Text('Savings stay out of your spending budget.', style: TextStyle(color: p.muted, fontSize: 12.5)),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: ListView(
            shrinkWrap: true,
            children: [for (final g in goals) _GoalOption(g, selected: g.id == goal.id, onTap: () => setState(() => _goalId = g.id))],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final quick in [500, 1000, 2500, 5000])
              ChoiceChip(label: Text(peso(quick.toDouble())), selected: v == quick, onSelected: (_) => _amount.text = '$quick'),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          decoration: const InputDecoration(labelText: 'Amount', prefixText: '₱ '),
        ),
        WalletDropdown(label: 'From', value: _walletId, onChanged: (id) => setState(() => _walletId = id)),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: valid ? () => Navigator.pop(context, (goal, v, _usableWallet())) : null,
          child: Text(
            valid ? 'Transfer ${peso(v)} to ${goal.name}' : 'Transfer to ${goal.name}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _GoalOption extends StatelessWidget {
  const _GoalOption(this.goal, {required this.selected, required this.onTap});

  final Goal goal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? Pastel.sage.background(p) : p.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? p.primary : p.border, width: selected ? 1.5 : 1),
            ),
            child: Row(
              children: [
                GoalArt(goal.icon, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text('${peso(goal.saved)} of ${peso(goal.target)}', style: TextStyle(color: p.muted, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: selected ? p.primary : p.muted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
