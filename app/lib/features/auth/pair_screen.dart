import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/nest_ui.dart';
import '../../core/mascot/mascot.dart';
import '../../core/theme/palettes.dart';
import '../../core/widgets/common.dart';
import '../../data/providers.dart';

/// Create a new nest or join your partner's with their invite code.
class PairScreen extends ConsumerStatefulWidget {
  const PairScreen({super.key});

  @override
  ConsumerState<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends ConsumerState<PairScreen> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startOver(SessionNotifier session) async {
    final ok = await confirmDialog(
      context,
      title: 'Start over?',
      message: "Your answers so far will be forgotten on this phone, and you'll go back to the start.",
      keepLabel: 'Cancel',
      confirmLabel: 'Start over',
    );
    if (ok) await _run(session.logout);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    final text = Theme.of(context).textTheme;
    final session = ref.read(sessionProvider.notifier);
    final me = ref.watch(sessionProvider).value;
    final name = me?.user.name ?? '';
    final partner = me?.partnerName;

    return Scaffold(
      body: NestBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                const Center(child: MascotPair(width: 180, bubbles: true, heart: false, animate: true)),
                const SizedBox(height: 16),
                Text('Hi $name! Let\'s build your nest', textAlign: TextAlign.center, style: text.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  partner == null
                      ? 'Pairnest works best with two. Start a new nest and share the code, or join your partner\'s.'
                      : 'Pairnest works best with two. Start a new nest and invite $partner, or join theirs.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.muted, height: 1.5),
                ),
                const SizedBox(height: 28),
                PairnestCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Start a new nest', style: text.titleMedium),
                      const SizedBox(height: 4),
                      Text('You\'ll get an invite code for ${partner ?? 'your partner'}.', style: TextStyle(color: p.muted)),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: _busy ? null : () => _run(session.createNest), child: const Text('Create our nest')),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                PairnestCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(partner == null ? 'Join your partner' : 'Join $partner', style: text.titleMedium),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _code,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 6,
                        decoration: const InputDecoration(labelText: 'Invite code', counterText: '', hintText: 'e.g. NEST01'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _busy ? null : () => _run(() => session.joinNest(_code.text)),
                        child: const Text('Join nest'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(onPressed: _busy ? null : () => _startOver(session), child: const Text('Start over')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
