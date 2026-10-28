import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/format.dart';
import '../../core/widgets/nest_ui.dart';
import '../../core/theme/palettes.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/member_avatar.dart';
import '../../data/models.dart';
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
              const _MyPhotoTile(),
              ListTile(
                leading: me.partner == null
                    ? const Icon(Icons.favorite_outline_rounded)
                    : MemberAvatar(userId: me.partner!.id, name: me.partner!.name, size: 40),
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
                leading: const Icon(Icons.devices_rounded),
                title: const Text('Phones'),
                subtitle: const Text('See where your account is signed in, and sign a phone out'),
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  useRootNavigator: true,
                  isScrollControlled: true,
                  builder: (_) => const _PhonesSheet(),
                ),
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
              'It works once, until ${timeLabel(r.expiresAt)}. ${r.forName}\'s other phones stay signed in, '
              'and you\'ll both see the new phone in your updates.',
          code: r.code,
        ),
      );
    } catch (e) {
      if (context.mounted) showSnack(context, friendlyError(e));
    }
  }

  Future<void> _newKey(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'Make a new recovery key?',
      message: 'Your old recovery key will stop working.',
      keepLabel: 'Cancel',
      confirmLabel: 'Make new key',
    );
    if (!ok || !context.mounted) return;
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
    final ok = await confirmDialog(
      context,
      title: 'Remove this phone?',
      message: "Your nest stays safe, but to get back in you'll need your recovery key or a code from your partner's phone.",
      keepLabel: 'Cancel',
      confirmLabel: 'Remove',
    );
    if (ok) await ref.read(sessionProvider.notifier).logout();
  }
}

/// The phones signed in to your account, each with Sign out.
class _PhonesSheet extends ConsumerWidget {
  const _PhonesSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pn;
    final devices = ref.watch(devicesProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Phones', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              "Don't recognise one? Sign it out. Phones added with your partner's code are marked.",
              style: TextStyle(color: p.muted, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 12),
            switch (devices) {
              AsyncData(:final value) => Column(
                children: [
                  for (final d in value)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(d.current ? Icons.smartphone_rounded : Icons.phone_android_outlined),
                      title: Text(d.current ? 'This phone' : (d.relinked ? 'Added with a re-link code' : 'Another phone')),
                      subtitle: Text(
                        [
                          if (d.createdAt != null) 'Signed in ${shortDate(d.createdAt!)}',
                          if (d.lastUsedAt != null && !d.current) 'last used ${shortDate(d.lastUsedAt!)}',
                        ].join(' · '),
                      ),
                      trailing: d.current ? null : TextButton(onPressed: () => _signOut(context, ref, d), child: const Text('Sign out')),
                    ),
                ],
              ),
              AsyncError(:final error) => Text(friendlyError(error), style: TextStyle(color: p.muted)),
              _ => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            },
          ],
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref, Device d) async {
    try {
      await ref.read(repositoryProvider).removeDevice(d.id);
      ref.invalidate(devicesProvider);
      if (context.mounted) showSnack(context, 'That phone was signed out.');
    } catch (e) {
      if (context.mounted) showSnack(context, friendlyError(e));
    }
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
    // Scrolls rather than overflowing on short screens or with large text.
    return SafeArea(
      child: SingleChildScrollView(
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

/// Your name and photo; tap to choose, take or remove a photo.
class _MyPhotoTile extends ConsumerStatefulWidget {
  const _MyPhotoTile();

  @override
  ConsumerState<_MyPhotoTile> createState() => _MyPhotoTileState();
}

class _MyPhotoTileState extends ConsumerState<_MyPhotoTile> {
  bool _busy = false;

  Future<void> _change() async {
    final me = ref.read(meProvider);
    final hasPhoto = me.user.avatarVersion != null;
    final choice = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose photo'),
              onTap: () => Navigator.pop(sheet, 'gallery'),
            ),
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take photo'),
                onTap: () => Navigator.pop(sheet, 'camera'),
              ),
            if (hasPhoto)
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: Theme.of(sheet).colorScheme.error),
                title: const Text('Remove photo'),
                onTap: () => Navigator.pop(sheet, 'remove'),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Only you and ${me.partner?.name ?? 'your partner'} can see your photo. Location data is removed.',
                style: TextStyle(color: sheet.pn.muted, fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    final repo = ref.read(repositoryProvider);
    final session = ref.read(sessionProvider.notifier);
    try {
      if (choice == 'remove') {
        setState(() => _busy = true);
        session.updateMe(await repo.removeAvatar());
        if (mounted) showSnack(context, 'Photo removed');
      } else {
        final bytes = await ref.read(photoPickerProvider)(choice == 'camera' ? ImageSource.camera : ImageSource.gallery);
        if (bytes == null || !mounted) return;
        setState(() => _busy = true);
        session.updateMe(await repo.uploadAvatar(bytes, 'photo.jpg'));
        if (mounted) showSnack(context, 'Photo updated');
      }
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    final me = ref.watch(meProvider);
    return ListTile(
      onTap: _busy ? null : _change,
      leading: Tooltip(
        message: 'Change your photo',
        child: SizedBox.square(
          dimension: 52,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              MemberAvatar(userId: me.user.id, name: me.user.name, size: 52),
              if (_busy)
                const Positioned.fill(
                  child: Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2.5)),
                ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: p.primaryDeep,
                    shape: BoxShape.circle,
                    border: Border.all(color: p.surface, width: 2),
                  ),
                  child: Icon(Icons.photo_camera_rounded, size: 12, color: p.onPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
      title: Text(me.user.name),
      subtitle: Text(me.user.avatarVersion == null ? 'Add a photo · Anonymous: no email, no password' : 'Anonymous: no email, no password'),
    );
  }
}
