import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/widgets/nest_ui.dart';
import '../../core/theme/palettes.dart';
import '../../core/widgets/common.dart';
import '../../data/providers.dart';
import '../onboarding/recovery_key_screen.dart';
import '../theme_select/theme_select_screen.dart';
import 'us_screen.dart';

class PersonalizeScreen extends ConsumerStatefulWidget {
  const PersonalizeScreen({super.key});

  @override
  ConsumerState<PersonalizeScreen> createState() => _PersonalizeScreenState();
}

class _PersonalizeScreenState extends ConsumerState<PersonalizeScreen> {
  int _tab = 0;
  late String _pending = ref.read(themeProvider).id;
  bool _busy = false;

  Future<void> _saveTheme() async {
    setState(() => _busy = true);
    try {
      await ref.read(themeProvider.notifier).select(_pending, share: true);
      if (mounted) showSnack(context, 'Theme saved for both of you');
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    return Scaffold(
      body: NestBackground(
        child: SafeArea(
          child: Column(
            children: [
              const PageHeader('Personalize'),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: PillTabs(labels: const ['Theme', 'Settings'], index: _tab, onChanged: (i) => setState(() => _tab = i)),
              ),
              Expanded(
                child: _tab == 0
                    ? ListView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        children: [
                          Text('Choose your theme', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text('This theme will be shared across your couple space.', style: TextStyle(color: p.muted, fontSize: 12)),
                          const SizedBox(height: 14),
                          for (final palette in allPalettes) ...[
                            _PaletteRow(
                              palette: palette,
                              selected: palette.id == _pending,
                              onTap: () {
                                setState(() => _pending = palette.id);
                                ref.read(themeProvider.notifier).select(palette.id);
                              },
                            ),
                            const SizedBox(height: 10),
                          ],
                          const SizedBox(height: 8),
                          FilledButton(onPressed: _busy ? null : _saveTheme, child: const Text('Save Theme')),
                        ],
                      )
                    : const _Settings(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaletteRow extends StatelessWidget {
  const _PaletteRow({required this.palette, required this.selected, required this.onTap});

  final PairnestPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    return Semantics(
      selected: selected,
      child: PairnestCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        color: selected ? p.soft.withValues(alpha: 0.6) : null,
        child: Row(
          children: [
            PaletteSwatch(palette: palette, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(palette.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(palette.tagline, style: TextStyle(color: p.muted, fontSize: 12)),
                ],
              ),
            ),
            Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined, color: selected ? p.primaryDeep : p.border),
          ],
        ),
      ),
    );
  }
}

class _Settings extends ConsumerWidget {
  const _Settings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final p = context.pn;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        PairnestCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: Text(me.user.name),
                subtitle: const Text('Anonymous: no email, no password'),
              ),
              ListTile(
                leading: const Icon(Icons.favorite_outline_rounded),
                title: Text(me.partner?.name ?? 'No partner yet'),
                subtitle: Text(me.partner == null ? 'Share your invite code below' : 'Your partner'),
              ),
              ListTile(
                leading: const Icon(Icons.cloud_outlined),
                title: const Text('Data source'),
                subtitle: Text(apiUrl.isEmpty ? 'Demo data on this device' : apiUrl),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Invite code',
          style: TextStyle(color: p.muted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        InviteCode(code: me.couple!.inviteCode),
        const SizedBox(height: 20),
        Text(
          'Phones & recovery',
          style: TextStyle(color: p.muted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        PairnestCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.phonelink_setup_rounded),
                title: const Text('Re-link a phone'),
                subtitle: Text(
                  me.partner == null
                      ? 'Once your partner joins, you can sign them back in here'
                      : 'Sign ${me.partner!.name} back in on a new phone',
                ),
                enabled: me.partner != null,
                onTap: () => _relink(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.key_rounded),
                title: const Text('New recovery key'),
                subtitle: const Text('Lost yours? Make a new one; the old one stops working'),
                onTap: () => _newKey(context, ref),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          icon: const Icon(Icons.phonelink_erase_rounded),
          label: const Text('Remove this phone'),
          onPressed: () => _removePhone(context, ref),
        ),
      ],
    );
  }

  Future<void> _relink(BuildContext context, WidgetRef ref) async {
    try {
      final r = await ref.read(repositoryProvider).relinkCode();
      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        builder: (sheet) => _CodeSheet(
          title: 'Re-link ${r.forName}',
          message:
              'On ${r.forName}\'s new phone, open Pairnest and tap "I already have a nest", then enter this code. '
              'It works once, until ${timeLabel(r.expiresAt)}.',
          code: r.code,
        ),
      );
    } catch (e) {
      if (context.mounted) showSnack(context, friendlyError(e));
    }
  }

  Future<void> _newKey(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Make a new recovery key?'),
        content: const Text('Your old recovery key will stop working.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Make new key')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final key = await ref.read(repositoryProvider).newRecoveryKey();
      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        builder: (sheet) => _CodeSheet(
          title: 'Your new recovery key',
          message: "Save it somewhere safe. It's the only way back in if you lose this phone and your partner can't re-link you.",
          code: key,
        ),
      );
    } catch (e) {
      if (context.mounted) showSnack(context, friendlyError(e));
    }
  }

  Future<void> _removePhone(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Remove this phone?'),
        content: const Text("Your nest stays safe, but to get back in you'll need your recovery key or a code from your partner's phone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true) await ref.read(sessionProvider.notifier).logout();
  }
}

/// A one-time code or key with a Copy button.
class _CodeSheet extends StatelessWidget {
  const _CodeSheet({required this.title, required this.message, required this.code});

  final String title;
  final String message;
  final String code;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, style: TextStyle(color: p.muted, height: 1.4)),
            const SizedBox(height: 16),
            RecoveryKeyCard(recoveryKey: code),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
          ],
        ),
      ),
    );
  }
}
