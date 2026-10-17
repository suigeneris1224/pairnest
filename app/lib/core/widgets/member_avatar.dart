import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/providers.dart';
import '../mascot/mascot.dart';
import '../theme/palettes.dart';
import 'common.dart';
import 'member_colors.dart';

/// A partner's profile photo, or their coloured initial until they add one.
class MemberAvatar extends ConsumerWidget {
  const MemberAvatar({super.key, required this.userId, required this.name, this.size = 36});

  final int userId;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final member = userId == me.user.id ? me.user : me.couple?.members.where((m) => m.id == userId).firstOrNull;
    final fallback = PartnerAvatar(name: name, color: memberColor(context, me.couple, userId), size: size);
    final version = member?.avatarVersion;
    if (version == null) return fallback;

    final bytes = ref.watch(avatarProvider((userId, version))).value;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: bytes == null
          ? fallback
          : Container(
              key: ValueKey(version),
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: context.pn.surface, width: 2),
                image: DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover),
              ),
            ),
    );
  }
}

/// Home's round badge: the couple's photos split down the middle once either
/// partner has one, otherwise the birds.
class CoupleBadge extends ConsumerWidget {
  const CoupleBadge({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final members = [...?me.couple?.members]..sort((a, b) => a.id.compareTo(b.id));
    if (!members.any((m) => m.avatarVersion != null)) return MascotBadge(size: size);
    final p = context.pn;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: p.surface, width: 3),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (final m in members)
            Expanded(
              child: _Half(member: m, size: size),
            ),
        ],
      ),
    );
  }
}

class _Half extends ConsumerWidget {
  const _Half({required this.member, required this.size});

  final Member member;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = member.avatarVersion;
    final bytes = version == null ? null : ref.watch(avatarProvider((member.id, version))).value;
    if (bytes != null) return Image.memory(bytes, fit: BoxFit.cover, height: size, gaplessPlayback: true);
    final me = ref.watch(meProvider);
    return ColoredBox(
      color: memberColor(context, me.couple, member.id),
      child: Center(
        child: Text(
          member.name.isEmpty ? '?' : member.name.characters.first.toUpperCase(),
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.32),
        ),
      ),
    );
  }
}
