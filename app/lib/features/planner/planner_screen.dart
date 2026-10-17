import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/widgets/nest_ui.dart';
import '../../core/motion/motion.dart';
import '../../core/format.dart';
import '../../core/theme/palettes.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

/// Date & Life Planner: date nights plus bigger shared plans linked to goals.
class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  int _tab = 0;
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();

  Future<void> _add() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => _PlanEditor(initialDate: _tab == 1 ? _selected : null),
    );
    if (added == true) ref.invalidate(plansProvider);
  }

  Future<void> _delete(Plan plan) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove "${plan.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(repositoryProvider).deletePlan(plan.id);
      ref.invalidate(plansProvider);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(plansProvider);
    return Scaffold(
      body: NestBackground(
        child: SafeArea(
          child: Column(
            children: [
              PageHeader(
                'Date & Life Planner',
                trailing: IconButton(tooltip: 'New plan', icon: const Icon(Icons.add_rounded), onPressed: _add),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: PillTabs(labels: const ['Upcoming', 'Calendar'], index: _tab, onChanged: (i) => setState(() => _tab = i)),
              ),
              Expanded(
                child: switch (plans) {
                  AsyncData(:final value) => RefreshIndicator(
                    onRefresh: () => ref.refresh(plansProvider.future),
                    child: _tab == 0 ? _upcoming(value) : _calendar(value),
                  ),
                  AsyncError(:final error) => ErrorRetry(error: error, onRetry: () => ref.invalidate(plansProvider)),
                  _ => const SkeletonList(cards: 2),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _upcoming(List<Plan> plans) {
    final now = DateTime.now().subtract(const Duration(hours: 6));
    final dates = plans.where((p) => p.isDate && (p.scheduledAt?.isAfter(now) ?? true)).toList();
    final life = plans.where((p) => !p.isDate).toList();
    final p = context.pn;
    if (dates.isEmpty && life.isEmpty) {
      return EmptyState(
        title: 'Plan your next date',
        message: 'Dinner, a weekend away or a big life plan. Put it on the calendar for both of you.',
        actionLabel: 'New plan',
        onAction: _add,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        if (dates.isNotEmpty) FadeSlideIn(child: _FeaturedDate(dates.first, onLongPress: () => _delete(dates.first))),
        if (dates.isEmpty)
          PairnestCard(
            onTap: _add,
            child: Row(
              children: [
                Icon(Icons.favorite_border_rounded, color: p.primaryDeep),
                const SizedBox(width: 12),
                const Expanded(child: Text('Plan your next date night')),
                Icon(Icons.add_rounded, color: p.muted),
              ],
            ),
          ),
        if (life.isNotEmpty) ...[
          const SectionHeader('Shared Plans'),
          for (final (i, plan) in life.indexed) ...[
            FadeSlideIn(
              index: i + 1,
              child: _PlanTile(plan, onLongPress: () => _delete(plan)),
            ),
            const SizedBox(height: 10),
          ],
        ],
        if (dates.length > 1) ...[
          const SectionHeader('More Dates'),
          for (final (i, plan) in dates.skip(1).indexed) ...[
            FadeSlideIn(
              index: life.length + i + 1,
              child: _PlanTile(plan, onLongPress: () => _delete(plan)),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }

  Widget _calendar(List<Plan> plans) {
    final p = context.pn;
    List<Plan> on(DateTime day) => plans.where((pl) => pl.scheduledAt != null && isSameDay(pl.scheduledAt, day)).toList();
    final selectedPlans = on(_selected);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        PairnestCard(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
          child: TableCalendar<Plan>(
            firstDay: DateTime(2020),
            lastDay: DateTime(2100),
            focusedDay: _focused,
            selectedDayPredicate: (d) => isSameDay(d, _selected),
            eventLoader: on,
            availableCalendarFormats: const {CalendarFormat.month: 'Month'},
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              leftChevronIcon: Icon(Icons.chevron_left_rounded, color: p.text),
              rightChevronIcon: Icon(Icons.chevron_right_rounded, color: p.text),
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              defaultTextStyle: TextStyle(color: p.text),
              weekendTextStyle: TextStyle(color: p.text),
              todayDecoration: BoxDecoration(color: p.soft, shape: BoxShape.circle),
              todayTextStyle: TextStyle(color: p.primaryDeep, fontWeight: FontWeight.w700),
              selectedDecoration: BoxDecoration(color: p.primaryDeep, shape: BoxShape.circle),
              selectedTextStyle: TextStyle(color: p.onPrimary, fontWeight: FontWeight.w700),
              markerDecoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(color: p.muted, fontSize: 12),
              weekendStyle: TextStyle(color: p.muted, fontSize: 12),
            ),
            onDaySelected: (selected, focused) => setState(() {
              _selected = selected;
              _focused = focused;
            }),
            onPageChanged: (focused) => _focused = focused,
          ),
        ),
        SectionHeader(longDate(_selected), action: 'Add', onAction: _add),
        if (selectedPlans.isEmpty) Text('Nothing planned. A perfect day to plan something!', style: TextStyle(color: p.muted)),
        for (final (i, plan) in selectedPlans.indexed) ...[
          FadeSlideIn(
            key: ValueKey(plan.id),
            index: i,
            child: _PlanTile(plan, onLongPress: () => _delete(plan)),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _FeaturedDate extends StatelessWidget {
  const _FeaturedDate(this.plan, {required this.onLongPress});

  final Plan plan;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final when = plan.scheduledAt;
    return GestureDetector(
      onLongPress: onLongPress,
      child: HeroCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SceneBanner(kind: 'date', height: 96, radius: 16),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 56,
                  height: 64,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
                  alignment: Alignment.center,
                  child: when == null
                      ? const Icon(Icons.favorite_rounded, color: Colors.white)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              shortDate(when).split(' ').first.toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${when.day}',
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('NEXT UP', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11, letterSpacing: 1.2)),
                      Text(
                        plan.title,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      if (when != null)
                        Text(
                          '${longDate(when)} · ${timeLabel(when)}',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                        ),
                      if (plan.notes.isNotEmpty)
                        Text(plan.notes, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.favorite_rounded, color: Color(0xFFFFC2B4)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile(this.plan, {required this.onLongPress});

  final Plan plan;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    final goal = plan.goal;
    return GestureDetector(
      onLongPress: onLongPress,
      child: PairnestCard(
        child: Row(
          children: [
            // Painted thumbnail, like the photos in the dashboard design.
            SizedBox(width: 58, child: SceneBanner(kind: plan.isDate ? 'date' : (goal?.icon ?? 'star'), height: 50, radius: 14)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (goal != null) ...[
                    const SizedBox(height: 2),
                    Text('${peso(goal.saved)} / ${peso(goal.target)}', style: TextStyle(color: p.muted, fontSize: 12)),
                    const SizedBox(height: 6),
                    SoftProgress(goal.ratio, height: 6),
                  ] else if (plan.scheduledAt != null)
                    Text(
                      '${longDate(plan.scheduledAt!)} · ${timeLabel(plan.scheduledAt!)}',
                      style: TextStyle(color: p.muted, fontSize: 12),
                    ),
                ],
              ),
            ),
            if (goal != null) ...[
              const SizedBox(width: 10),
              Text(
                '${(goal.ratio * 100).round()}%',
                style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlanEditor extends ConsumerStatefulWidget {
  const _PlanEditor({this.initialDate});

  final DateTime? initialDate;

  @override
  ConsumerState<_PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends ConsumerState<_PlanEditor> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  String _kind = 'date';
  late DateTime? _when = widget.initialDate == null
      ? null
      : DateTime(widget.initialDate!.year, widget.initialDate!.month, widget.initialDate!.day, 19);
  int? _goalId;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickWhen() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _when ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 30),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_when ?? DateTime(0, 1, 1, 19)));
    setState(() => _when = DateTime(date.year, date.month, date.day, time?.hour ?? 19, time?.minute ?? 0));
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      showSnack(context, 'Give your plan a name.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(repositoryProvider)
          .addPlan(
            kind: _kind,
            title: _title.text.trim(),
            notes: _notes.text.trim(),
            scheduledAt: _when,
            goalId: _kind == 'life' ? _goalId : null,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, friendlyError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(activeGoalsProvider).value ?? const <Goal>[];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New plan', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            PillTabs(
              labels: const ['Date', 'Life plan'],
              index: _kind == 'date' ? 0 : 1,
              onChanged: (i) => setState(() => _kind = i == 0 ? 'date' : 'life'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Title',
                hintText: _kind == 'date' ? 'e.g. Picnic at the park' : 'e.g. Move to a bigger place',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _pickWhen,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'When', suffixIcon: Icon(Icons.event_rounded, size: 18)),
                child: Text(_when == null ? 'Someday' : '${longDate(_when!)} · ${timeLabel(_when!)}'),
              ),
            ),
            if (_kind == 'life' && goals.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: _goalId,
                decoration: const InputDecoration(labelText: 'Link to a savings goal'),
                borderRadius: BorderRadius.circular(14),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('None')),
                  for (final g in goals) DropdownMenuItem<int?>(value: g.id, child: Text(g.name)),
                ],
                onChanged: (v) => setState(() => _goalId = v),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(onPressed: _busy ? null : _save, child: const Text('Save plan')),
          ],
        ),
      ),
    );
  }
}
