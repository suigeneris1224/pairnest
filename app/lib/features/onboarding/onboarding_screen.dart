import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/mascot/brand_logo.dart';
import '../../core/mascot/mascot.dart';
import '../../core/motion/motion.dart';
import '../../core/onboarding_options.dart';
import '../../core/theme/palettes.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/nest_ui.dart';
import '../../data/mock_repository.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../goals/goals_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: NestBackground(child: Center(child: BrandLogo(width: 240, animateIn: true))),
    );
  }
}

/// Welcome, then four short questions instead of a sign-up form: no email,
/// no password. Only a name is required; the answers become starter goals
/// and the first budget.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _steps = 4;

  final _controller = PageController();
  final _name = TextEditingController();
  final _partner = TextEditingController();
  final _budget = TextEditingController();
  int _page = 0;
  String? _stage;
  final _financial = <String>{};
  final _family = <String>{};
  String? _style;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _name.dispose();
    _partner.dispose();
    _budget.dispose();
    super.dispose();
  }

  void _go(int page) {
    FocusScope.of(context).unfocus();
    _controller.animateToPage(page, duration: Motion.reduced(context) ? Duration.zero : Motion.slow, curve: Motion.emphasized);
  }

  bool get _canContinue => _page != 1 || _name.text.trim().isNotEmpty;

  /// Whether the current question has an answer ("Skip" otherwise).
  bool get _answered => switch (_page) {
    2 => _financial.isNotEmpty,
    3 => _family.isNotEmpty,
    4 => _style != null || _budget.text.trim().isNotEmpty,
    _ => true,
  };

  Future<void> _finish() async {
    setState(() => _busy = true);
    ref.read(onboardedProvider.notifier).set();
    try {
      await ref
          .read(sessionProvider.notifier)
          .start(
            _name.text,
            OnboardingProfile(
              partnerName: _partner.text.trim().isEmpty ? null : _partner.text.trim(),
              stage: _stage,
              financialGoals: [
                for (final o in financialGoalOptions)
                  if (_financial.contains(o.key)) o.key,
              ],
              familyGoals: [
                for (final o in familyGoalOptions)
                  if (_family.contains(o.key)) o.key,
              ],
              moneyStyle: _style,
              monthlyBudget: double.tryParse(_budget.text.replaceAll(',', '')),
            ),
          );
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _next() => _page == _steps ? _finish() : _go(_page + 1);

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    return Scaffold(
      body: NestBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _controller,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    const _Welcome(),
                    _Question(
                      step: 1,
                      title: 'First, about you two',
                      subtitle: 'Just first names or nicknames. No email, no password.',
                      children: [
                        TextField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          maxLength: 40,
                          decoration: const InputDecoration(labelText: 'What should we call you?', counterText: ''),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _partner,
                          textCapitalization: TextCapitalization.words,
                          maxLength: 40,
                          decoration: const InputDecoration(labelText: "Your partner's name (optional)", counterText: ''),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Where are you two?',
                          style: TextStyle(fontWeight: FontWeight.w600, color: p.heading),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final e in relationshipStages.entries)
                              ChoiceChip(
                                label: Text(e.value),
                                selected: _stage == e.key,
                                onSelected: (on) => setState(() => _stage = on ? e.key : null),
                              ),
                          ],
                        ),
                      ],
                    ),
                    _Question(
                      step: 2,
                      title: 'What are you saving for?',
                      subtitle: "Pick any. We'll start a savings goal for each one, and you can change targets later.",
                      children: [_GoalGrid(financialGoalOptions, selected: _financial, onToggle: _toggle(_financial))],
                    ),
                    _Question(
                      step: 3,
                      title: 'Any family plans ahead?',
                      subtitle: 'Totally optional, and it stays between you two.',
                      children: [
                        _GoalGrid(familyGoalOptions, selected: _family, onToggle: _toggle(_family)),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ChoiceChip(
                            label: const Text('Not right now'),
                            selected: false,
                            onSelected: (_) {
                              setState(_family.clear);
                              _go(4);
                            },
                          ),
                        ),
                      ],
                    ),
                    _Question(
                      step: 4,
                      title: 'How do you handle money?',
                      subtitle: 'There\'s no right answer. It just helps us set things up.',
                      children: [
                        for (final e in moneyStyles.entries) ...[
                          _StyleCard(
                            title: e.value.$1,
                            subtitle: e.value.$2,
                            selected: _style == e.key,
                            onTap: () => setState(() => _style = _style == e.key ? null : e.key),
                          ),
                          const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 6),
                        TextField(
                          controller: _budget,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Monthly shared budget (optional)',
                            prefixText: '₱ ',
                            helperText: "We'll set up your first budget. Change it anytime.",
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Icon(Icons.lock_outline_rounded, size: 18, color: p.muted),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No email, no password, no bank details. Just you two.',
                                style: TextStyle(color: p.muted, fontSize: 12.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(padding: const EdgeInsets.fromLTRB(24, 8, 24, 20), child: _page == 0 ? _welcomeActions() : _stepBar()),
            ],
          ),
        ),
      ),
    );
  }

  ValueChanged<String> _toggle(Set<String> set) =>
      (key) => setState(() => set.contains(key) ? set.remove(key) : set.add(key));

  Widget _welcomeActions() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FilledButton(onPressed: () => _go(1), child: const Text('Get Started')),
      const SizedBox(height: 4),
      TextButton(onPressed: () => context.go('/restore'), child: const Text('I already have a nest')),
      if (apiUrl.isEmpty)
        TextButton(
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  ref.read(onboardedProvider.notifier).set();
                  try {
                    await ref.read(sessionProvider.notifier).recover(MockRepository.demoKey);
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          child: const Text('Explore the demo nest'),
        ),
    ],
  );

  Widget _stepBar() {
    final p = context.pn;
    final last = _page == _steps;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 1; i <= _steps; i++)
              AnimatedContainer(
                duration: Motion.medium,
                curve: Motion.curve,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 18 : 7,
                height: 7,
                decoration: BoxDecoration(color: i <= _page ? p.primaryDeep : p.border, borderRadius: BorderRadius.circular(8)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            TextButton(onPressed: _busy ? null : () => _go(_page - 1), child: const Text('Back')),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _busy || !_canContinue ? null : _next,
                child: Text(
                  last
                      ? 'Create my nest'
                      : _answered
                      ? 'Next'
                      : 'Skip',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const FadeSlideIn(child: MascotPair(width: 240, animate: true)),
              const SizedBox(height: 24),
              FadeSlideIn(
                index: 2,
                child: Text(
                  'Better\nMoney, Happier\nTogether.',
                  textAlign: TextAlign.center,
                  style: text.headlineMedium?.copyWith(color: p.primaryDeep, height: 1.15),
                ),
              ),
              const SizedBox(height: 14),
              FadeSlideIn(
                index: 4,
                child: Text(
                  'Plan, save, and grow —\nnot just your finances,\nbut your relationship too.',
                  textAlign: TextAlign.center,
                  style: text.bodyLarge?.copyWith(color: p.muted, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One onboarding question: step, title, helper text and its controls.
class _Question extends StatelessWidget {
  const _Question({required this.step, required this.title, required this.subtitle, required this.children});

  final int step;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      children: [
        Text(
          'STEP $step OF 4',
          style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8),
        ),
        const SizedBox(height: 6),
        FadeSlideIn(
          child: Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: p.heading)),
        ),
        const SizedBox(height: 6),
        Text(subtitle, style: TextStyle(color: p.muted, height: 1.4)),
        const SizedBox(height: 20),
        ...children,
      ],
    );
  }
}

class _GoalGrid extends StatelessWidget {
  const _GoalGrid(this.options, {required this.selected, required this.onToggle});

  final List<GoalOption> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final width = (c.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final o in options)
              SizedBox(
                width: width,
                child: _GoalTile(o, selected: selected.contains(o.key), onTap: () => onToggle(o.key)),
              ),
          ],
        );
      },
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile(this.option, {required this.selected, required this.onTap});

  final GoalOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    return Material(
      color: selected ? Pastel.sage.background(p) : p.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: Motion.fast,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? p.primary : p.border, width: selected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              GoalArt(option.icon, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Text(option.label, maxLines: 2, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
              ),
              if (selected) Icon(Icons.check_circle_rounded, size: 18, color: p.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _StyleCard extends StatelessWidget {
  const _StyleCard({required this.title, required this.subtitle, required this.selected, required this.onTap});

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    return Material(
      color: selected ? Pastel.sage.background(p) : p.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? p.primary : p.border, width: selected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: p.muted, fontSize: 12.5)),
                  ],
                ),
              ),
              Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: selected ? p.primary : p.muted),
            ],
          ),
        ),
      ),
    );
  }
}
