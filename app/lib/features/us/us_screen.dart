import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/nest_ui.dart';
import '../../core/mascot/mascot.dart';
import '../../core/theme/palettes.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/member_colors.dart';
import '../../data/providers.dart';

/// The couple's shared space: partner info, invite code and shortcuts.
class UsScreen extends ConsumerWidget {
  const UsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final couple = me.couple!;
    final p = context.pn;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: NestBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Center(
                child: Column(
                  children: [
                    MascotPair(width: 230, animate: true, branch: true, controller: ref.watch(mascotControllerProvider)),
                    const SizedBox(height: 8),
                    Text(me.coupleNames, style: text.headlineSmall),
                    const SizedBox(height: 4),
                    Text('Same team. Different strengths. One journey.', style: TextStyle(color: p.muted, fontSize: 13)),
                    const SizedBox(height: 12),
                    CoupleAvatars(
                      names: [for (final m in couple.members) m.name],
                      colors: [for (final m in couple.members) memberColor(context, couple, m.id)],
                      size: 40,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (me.partner == null) ...[
                PairnestCard(
                  color: p.soft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Invite your partner', style: text.titleMedium),
                      const SizedBox(height: 4),
                      Text('Share this code so they can join your nest.', style: TextStyle(color: p.muted)),
                      const SizedBox(height: 12),
                      InviteCode(code: couple.inviteCode),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              PairnestCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    _MenuTile(
                      Icons.event_rounded,
                      'Date & Life Planner',
                      'More time together',
                      Pastel.peach,
                      () => context.push('/us/planner'),
                    ),
                    _MenuTile(
                      Icons.chat_bubble_outline_rounded,
                      'Money Talks',
                      'Better conversations',
                      Pastel.lavender,
                      () => context.push('/us/talks'),
                    ),
                    _MenuTile(
                      Icons.pie_chart_outline_rounded,
                      'Budgets',
                      'Plan your month together',
                      Pastel.sage,
                      () => context.go('/home/budgets'),
                    ),
                    _MenuTile(Icons.palette_outlined, 'Personalize', 'Theme & settings', Pastel.sky, () => context.push('/us/personalize')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile(this.icon, this.title, this.subtitle, this.tone, this.onTap);

  final IconData icon;
  final Pastel tone;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    return ListTile(
      onTap: onTap,
      leading: PastelIcon(icon, tone: tone, size: 42),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: p.muted, fontSize: 12)),
      trailing: Icon(Icons.chevron_right_rounded, color: p.muted),
    );
  }
}

class InviteCode extends StatelessWidget {
  const InviteCode({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.border),
            ),
            alignment: Alignment.center,
            child: SelectableText(code, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 6)),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filledTonal(
          tooltip: 'Copy code',
          icon: const Icon(Icons.copy_rounded),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: code));
            if (context.mounted) showSnack(context, 'Invite code copied');
          },
        ),
      ],
    );
  }
}
