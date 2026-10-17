import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/mascot/mascot.dart';
import '../../core/theme/palettes.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/nest_ui.dart';
import '../../data/providers.dart';

/// Shown once, right after onboarding: the key that gets you back in on a
/// new phone if your partner can't re-link you.
class RecoveryKeyScreen extends ConsumerStatefulWidget {
  const RecoveryKeyScreen({super.key});

  @override
  ConsumerState<RecoveryKeyScreen> createState() => _RecoveryKeyScreenState();
}

class _RecoveryKeyScreenState extends ConsumerState<RecoveryKeyScreen> {
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    final text = Theme.of(context).textTheme;
    final key = ref.watch(pendingRecoveryKeyProvider) ?? '';

    return Scaffold(
      body: NestBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
            children: [
              const Center(child: MascotPair(width: 150, heart: true, leaves: false)),
              const SizedBox(height: 16),
              Text(
                'Save your recovery key',
                textAlign: TextAlign.center,
                style: text.headlineSmall?.copyWith(color: p.heading),
              ),
              const SizedBox(height: 8),
              Text(
                "Pairnest doesn't know your email, so this key is how you get back in if you lose this phone "
                "and your partner can't re-link you. Screenshot it or write it down.",
                textAlign: TextAlign.center,
                style: TextStyle(color: p.muted, height: 1.45),
              ),
              const SizedBox(height: 22),
              RecoveryKeyCard(recoveryKey: key),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _saved,
                onChanged: (v) => setState(() => _saved = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: const Text("I've saved my recovery key"),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _saved ? () => ref.read(pendingRecoveryKeyProvider.notifier).saved() : null,
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A recovery key in large monospace with a Copy button.
class RecoveryKeyCard extends StatelessWidget {
  const RecoveryKeyCard({super.key, required this.recoveryKey});

  final String recoveryKey;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    return PairnestCard(
      child: Column(
        children: [
          SelectableText(
            recoveryKey,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'monospace', fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: p.heading),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: recoveryKey));
              showSnack(context, 'Recovery key copied');
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy'),
          ),
        ],
      ),
    );
  }
}
