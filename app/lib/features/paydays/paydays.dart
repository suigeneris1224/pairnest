import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/mascot/mascot.dart';
import '../../core/theme/palettes.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/member_avatar.dart';
import '../../core/widgets/nest_ui.dart';
import '../../core/widgets/wallet_picker.dart';
import '../../data/models.dart';
import '../../data/payday_schedule.dart';
import '../../data/providers.dart';

double? _parseAmount(String text) {
  final v = double.tryParse(text.replaceAll(',', ''));
  return v == null || v <= 0 ? null : v;
}

String _plainAmount(double v) => v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);

/// Asks how much came in (take-home pay varies), logs it as income and moves
/// the payday on, with Undo.
Future<void> receivePayday(BuildContext context, WidgetRef ref, Payday payday) async {
  final amount = await showModalBottomSheet<double>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => _ReceiveSheet(payday, walletName: walletNameOf(ref, payday.walletId)),
  );
  if (amount == null || !context.mounted) return;
  final repo = ref.read(repositoryProvider);
  final messenger = ScaffoldMessenger.of(context);
  final container = ProviderScope.containerOf(context, listen: false);
  try {
    final got = await repo.receivePayday(payday.id, amount: amount == payday.amount ? null : amount);
    invalidateMoney(ref);
    ref.read(mascotControllerProvider).react(MascotReaction.cheer);
    HapticFeedback.lightImpact();
    showSnackOn(
      messenger,
      '${payday.title} logged · next payday ${shortDate(got.payday.nextOn)}',
      actionLabel: 'Undo',
      onAction: () => repo
          .unreceivePayday(payday.id, transactionId: got.transactionId, previousNext: payday.nextOn)
          .then((_) => invalidateMoneyIn(container), onError: (Object e) => showSnackOn(messenger, friendlyError(e))),
    );
  } catch (e) {
    showSnackOn(messenger, friendlyError(e));
  }
}

class _ReceiveSheet extends StatefulWidget {
  const _ReceiveSheet(this.payday, {this.walletName});

  final Payday payday;

  /// Where it lands, e.g. "BPI".
  final String? walletName;

  @override
  State<_ReceiveSheet> createState() => _ReceiveSheetState();
}

class _ReceiveSheetState extends State<_ReceiveSheet> {
  late final _amount = TextEditingController(text: _plainAmount(widget.payday.amount));

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    final amount = _parseAmount(_amount.text);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  PastelIcon(Icons.payments_rounded, tone: Pastel.sky, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Did your ${widget.payday.title} come in?', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(widget.payday.scheduleLabel, style: TextStyle(color: p.muted, fontSize: 12.5)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: const InputDecoration(labelText: 'Amount received', prefixText: '₱ '),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Text(
                widget.walletName == null
                    ? "It's logged as income today. Change the amount if this one was different."
                    : "It's logged as income in ${widget.walletName} today. Change the amount if this one was different.",
                style: TextStyle(color: p.muted, fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: amount == null ? null : () => Navigator.pop(context, amount),
                child: Text(amount == null ? 'Log it' : 'Log ${peso(amount)}'),
              ),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Not yet')),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the add/edit sheet; returns once it closes.
Future<void> openPaydayEditor(BuildContext context, {Payday? existing}) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  builder: (_) => PaydayEditor(existing: existing),
);

/// One payday: whose it is, its schedule and next date, and the amount.
class PaydayRow extends ConsumerWidget {
  const PaydayRow(this.payday, {super.key, this.onTap, this.trailing});

  final Payday payday;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pn;
    final now = ref.watch(nowProvider)();
    final hide = ref.watch(hideAmountsProvider);
    final mine = payday.userId == ref.watch(meProvider).user.id;
    final soon = payday.daysUntil(now) <= 1;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            MemberAvatar(userId: payday.userId, name: payday.userName, size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mine ? payday.title : "${payday.userName}'s ${payday.title}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${payday.daysUntil(now) < 0 ? payday.whenLabel(now) : 'Next ${shortDate(payday.nextOn)}'} · ${payday.scheduleLabel}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: soon ? p.heading : p.muted, fontWeight: soon ? FontWeight.w600 : FontWeight.w400),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: Pastel.sky.background(p), borderRadius: BorderRadius.circular(20)),
              child: Text(
                hide ? '₱••••' : peso(payday.amount),
                style: TextStyle(fontSize: 12, color: Pastel.sky.foreground(p), fontWeight: FontWeight.w700),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Both partners' pay schedules, for the Budgets page.
class PaydaysSection extends ConsumerWidget {
  const PaydaysSection({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref, Payday payday) async {
    final repo = ref.read(repositoryProvider);
    try {
      await repo.deletePayday(payday.id);
    } catch (e) {
      if (context.mounted) showSnack(context, friendlyError(e));
      return;
    } finally {
      invalidateMoney(ref);
    }
    if (!context.mounted) return;
    showSnack(
      context,
      '${payday.title} removed',
      actionLabel: 'Undo',
      onAction: () async {
        await repo.addPayday(
          PaydayDraft(
            title: payday.title,
            amount: payday.amount,
            frequency: payday.frequency,
            days: payday.days,
            nextOn: payday.nextOn,
            isSplit: payday.isSplit,
            walletId: payday.walletId,
          ),
        );
        if (context.mounted) invalidateMoney(ref);
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pn;
    final paydays = ref.watch(paydaysProvider);
    final me = ref.watch(meProvider).user.id;
    return SectionCard(
      icon: Icons.payments_outlined,
      title: 'Paydays',
      action: 'Add payday',
      onAction: () => openPaydayEditor(context),
      child: switch (paydays) {
        AsyncData(:final value) when value.isEmpty => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            'Add your paydays and Pairnest will remind you to log them, and show what you can spend until then.',
            style: TextStyle(color: p.muted, fontSize: 12.5, height: 1.4),
          ),
        ),
        AsyncData(:final value) => Column(
          children: [
            for (final payday in value)
              if (payday.userId != me)
                PaydayRow(payday)
              else
                Dismissible(
                  key: ValueKey('payday-${payday.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 12),
                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.12),
                    child: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.error, semanticLabel: 'Delete'),
                  ),
                  onDismissed: (_) => _delete(context, ref, payday),
                  child: PaydayRow(
                    payday,
                    onTap: () => openPaydayEditor(context, existing: payday),
                    trailing: IconButton(
                      tooltip: 'Log ${payday.title}',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.add_task_rounded, color: p.primaryDeep),
                      onPressed: () => receivePayday(context, ref, payday),
                    ),
                  ),
                ),
          ],
        ),
        AsyncError(:final error) => ErrorRetry(error: error, onRetry: () => ref.invalidate(paydaysProvider)),
        _ => const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Skeleton(height: 44)),
      },
    );
  }
}

class PaydayEditor extends ConsumerStatefulWidget {
  const PaydayEditor({super.key, this.existing});

  final Payday? existing;

  @override
  ConsumerState<PaydayEditor> createState() => _PaydayEditorState();
}

class _PaydayEditorState extends ConsumerState<PaydayEditor> {
  static const _labels = ['Twice a month', 'Monthly', 'Every 2 weeks', 'Weekly'];

  late final Payday? _existing = widget.existing;
  late final _title = TextEditingController(text: _existing?.title ?? 'Salary');
  late final _amount = TextEditingController(text: _existing == null ? '' : _plainAmount(_existing.amount));
  late int _frequency = payFrequencies.indexOf(_existing?.frequency ?? 'semimonthly');
  late int _dayA = _existing?.days.firstOrNull ?? 15;
  late int _dayB = (_existing?.days.length ?? 0) > 1 ? _existing!.days[1] : 30;
  late DateTime _next = _existing?.nextOn ?? DateTime.now();
  late bool _split = _existing?.isSplit ?? true;
  late int? _walletId = _existing?.walletId;
  bool _busy = false;

  String get _freq => payFrequencies[_frequency];

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _next,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) setState(() => _next = picked);
  }

  Future<void> _save() async {
    final amount = _parseAmount(_amount.text);
    if (amount == null) {
      showSnack(context, 'Add how much you usually take home.');
      return;
    }
    if (_freq == 'semimonthly' && _dayA == _dayB) {
      showSnack(context, 'Pick two different days of the month.');
      return;
    }
    final draft = PaydayDraft(
      title: _title.text.trim().isEmpty ? 'Salary' : _title.text.trim(),
      amount: amount,
      frequency: _freq,
      days: switch (_freq) {
        'semimonthly' => [_dayA, _dayB],
        'monthly' => [_dayA],
        _ => const [],
      },
      nextOn: isByDay(_freq) ? null : _next,
      isSplit: _split,
      walletId: _walletId,
    );
    setState(() => _busy = true);
    try {
      final repo = ref.read(repositoryProvider);
      _existing == null ? await repo.addPayday(draft) : await repo.updatePayday(_existing.id, draft);
      invalidateMoney(ref);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, friendlyError(e));
      }
    }
  }

  Widget _day(String label, int value, ValueChanged<int> onChanged) => DropdownButtonFormField<int>(
    key: ValueKey('$label-$_frequency'),
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    borderRadius: BorderRadius.circular(14),
    menuMaxHeight: 320,
    items: [for (var d = 1; d <= 31; d++) DropdownMenuItem(value: d, child: Text(ordinal(d)))],
    onChanged: (v) => setState(() => onChanged(v ?? value)),
  );

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_existing == null ? 'New payday' : 'Edit payday', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Salary, Freelance'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              autofocus: _existing == null,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: const InputDecoration(labelText: 'Usual take-home pay', prefixText: '₱ '),
            ),
            const SizedBox(height: 14),
            Text(
              'How often',
              style: TextStyle(color: p.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, label) in _labels.indexed)
                  ChoiceChip(label: Text(label), selected: i == _frequency, onSelected: (_) => setState(() => _frequency = i)),
              ],
            ),
            const SizedBox(height: 12),
            if (_freq == 'semimonthly')
              Row(
                children: [
                  Expanded(child: _day('First payday', _dayA, (v) => _dayA = v)),
                  const SizedBox(width: 10),
                  Expanded(child: _day('Second payday', _dayB, (v) => _dayB = v)),
                ],
              )
            else if (_freq == 'monthly')
              _day('Payday', _dayA, (v) => _dayA = v)
            else
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Next payday', suffixIcon: Icon(Icons.calendar_today_rounded, size: 18)),
                  child: Text(longDate(_next)),
                ),
              ),
            if (isByDay(_freq))
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text('Short months use their last day.', style: TextStyle(color: p.muted, fontSize: 12)),
              ),
            WalletDropdown(label: 'Lands in', value: _walletId, onChanged: (id) => setState(() => _walletId = id)),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: const Text('Shared money'),
              subtitle: Text('Counts toward what you have together', style: TextStyle(color: p.muted, fontSize: 12)),
              value: _split,
              onChanged: (v) => setState(() => _split = v),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: _busy ? null : _save, child: Text(_existing == null ? 'Add payday' : 'Save changes')),
          ],
        ),
      ),
    );
  }
}
