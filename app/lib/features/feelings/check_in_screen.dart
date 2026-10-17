import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/nest_ui.dart';
import '../../core/mascot/mascot.dart';
import '../../core/theme/palettes.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/mood_face.dart';
import '../../data/providers.dart';

/// "Pairnest Feels" — a quick, optionally private, mood check-in.
class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({super.key, this.initialMood});

  /// Preselected from Home's quick mood picker.
  final String? initialMood;

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen> {
  final _note = TextEditingController();
  late String _mood = moodStyles.any((m) => m.key == widget.initialMood) ? widget.initialMood! : 'happy';
  bool _private = false;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).addMood(mood: _mood, note: _note.text.trim(), isPrivate: _private);
      ref.invalidate(moodsProvider);
      if (mounted) {
        showSnack(context, _private ? 'Saved privately. Thanks for checking in.' : 'Shared with your partner.');
        Navigator.of(context).pop();
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
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: NestBackground(
        child: SafeArea(
          child: Column(
            children: [
              PageHeader(
                'Pairnest Feels',
                trailing: const Padding(padding: EdgeInsets.only(right: 12), child: MascotBird(size: 34)),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    Text('How are you feeling today?', style: text.headlineSmall),
                    const SizedBox(height: 8),
                    Text("It's okay to feel what you feel. Your feelings matter, too.", style: TextStyle(color: p.muted, height: 1.4)),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        for (final m in moodStyles)
                          Expanded(
                            child: Semantics(
                              selected: m.key == _mood,
                              button: true,
                              label: m.label,
                              child: GestureDetector(
                                onTap: () => setState(() => _mood = m.key),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: m.key == _mood ? m.color.withValues(alpha: 0.2) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: m.key == _mood ? m.color : Colors.transparent, width: 2),
                                  ),
                                  child: Column(
                                    children: [
                                      AnimatedScale(
                                        scale: m.key == _mood ? 1.12 : 1,
                                        duration: const Duration(milliseconds: 180),
                                        child: MoodFace(m.key, size: 40),
                                      ),
                                      const SizedBox(height: 6),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(m.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _note,
                      maxLines: 4,
                      maxLength: 500,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Add a note (optional)',
                        hintText: "e.g. I'm feeling a bit overwhelmed with our expenses this week...",
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    PairnestCard(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: Icon(_private ? Icons.lock_rounded : Icons.lock_open_rounded, color: p.primaryDeep),
                        title: const Text('Keep this private', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          _private ? 'Only you can see this.' : 'Your partner will see this check-in.',
                          style: TextStyle(color: p.muted, fontSize: 12),
                        ),
                        value: _private,
                        onChanged: (v) => setState(() => _private = v),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: FilledButton(onPressed: _busy ? null : _save, child: const Text('Save')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
