import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/palettes.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/nest_ui.dart';
import '../../data/mock_repository.dart';
import '../../data/providers.dart';

/// Back into an existing nest on a new phone: a one-time code from the
/// partner's phone, or the recovery key.
class RestoreScreen extends ConsumerStatefulWidget {
  const RestoreScreen({super.key});

  @override
  ConsumerState<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends ConsumerState<RestoreScreen> {
  final _input = TextEditingController();
  int _tab = 0;
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _input.text.trim();
    if (value.isEmpty) return;
    setState(() => _busy = true);
    final session = ref.read(sessionProvider.notifier);
    try {
      await (_tab == 0 ? session.redeemRelink(value) : session.recover(value));
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    final byCode = _tab == 0;

    return Scaffold(
      body: NestBackground(
        child: SafeArea(
          child: Column(
            children: [
              PageHeader('Back to your nest', onBack: () => context.go('/onboarding')),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  children: [
                    PillTabs(
                      labels: const ['Code from partner', 'Recovery key'],
                      index: _tab,
                      onChanged: (i) => setState(() {
                        _tab = i;
                        _input.clear();
                      }),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      byCode
                          ? 'On your partner\'s phone, open Us → Personalize → "Re-link a phone" and enter the code it shows. '
                                'It works once, for 10 minutes.'
                          : 'Enter the recovery key you saved when you made your nest.',
                      style: TextStyle(color: p.muted, height: 1.45),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _input,
                      textCapitalization: TextCapitalization.characters,
                      autocorrect: false,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: byCode ? 'Code from partner' : 'Recovery key',
                        hintText: byCode ? 'e.g. QX4M7KDP' : 'XXXX-XXXX-XXXX-XXXX',
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _busy ? null : _submit, child: const Text('Continue')),
                    if (apiUrl.isEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Demo mode: use the recovery key ${MockRepository.demoKey}.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: p.muted, fontSize: 12),
                      ),
                    ],
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
