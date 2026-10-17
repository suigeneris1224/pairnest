import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/nest_ui.dart';
import '../../core/motion/motion.dart';
import '../../core/format.dart';
import '../../core/mascot/mascot.dart';
import '../../core/theme/palettes.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/member_avatar.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

/// Guided weekly conversation prompts for the couple.
class MoneyTalksScreen extends ConsumerWidget {
  const MoneyTalksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final talk = ref.watch(talkProvider);
    final history = ref.watch(talkHistoryProvider);
    final p = context.pn;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: NestBackground(
        child: SafeArea(
          child: Column(
            children: [
              const PageHeader('Money Talks'),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () {
                    ref.invalidate(talkHistoryProvider);
                    return ref.refresh(talkProvider.future);
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    children: [
                      const Center(child: MascotPair(width: 190, bubbles: true, heart: false, animate: true)),
                      const SizedBox(height: 8),
                      Text('Weekly Conversation', style: text.titleLarge),
                      const SizedBox(height: 6),
                      Text(
                        "A little chat goes a long way. Here's a prompt for you and your partner.",
                        style: TextStyle(color: p.muted, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      switch (talk) {
                        AsyncData(:final value) => _PromptCard(value),
                        AsyncError(:final error) => ErrorRetry(error: error, onRetry: () => ref.invalidate(talkProvider)),
                        _ => const SkeletonList(cards: 0, padding: EdgeInsets.zero),
                      },
                      const SectionHeader('Past Conversations'),
                      switch (history) {
                        AsyncData(:final value) when value.isEmpty => PairnestCard(
                          child: Row(
                            children: [
                              const PastelIcon(Icons.forum_outlined, tone: Pastel.lavender, size: 44),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "Your first talk is waiting. Answer this week's prompt and it will be saved here.",
                                  style: TextStyle(color: p.muted, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        AsyncData(:final value) => PairnestCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              for (final (i, t) in value.indexed) ...[
                                FadeSlideIn(index: i, child: _PastTalkTile(t)),
                                if (t != value.last) const Divider(height: 1),
                              ],
                            ],
                          ),
                        ),
                        AsyncError(:final error) => ErrorRetry(error: error, onRetry: () => ref.invalidate(talkHistoryProvider)),
                        _ => const SizedBox.shrink(),
                      },
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromptCard extends ConsumerWidget {
  const _PromptCard(this.talk);

  final TalkState talk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HeroCard(
      tint: Pastel.lavender.deep,
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Text(
            '“${talk.prompt.question}”',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(height: 1.4, color: Colors.white),
          ),
          const SizedBox(height: 18),
          if (!talk.answered)
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Pastel.lavender.deep),
              onPressed: () => _answer(context),
              child: const Text('Share Your Answer'),
            )
          else ...[
            for (final a in talk.answers)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MemberAvatar(userId: a.userId, name: a.userName, size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(14)),
                        child: Text(a.answer, style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            if (talk.answers.length < 2)
              const Text('Waiting for your partner to share theirs…', style: TextStyle(color: Color(0xDDFFFFFF), fontSize: 12)),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: () => _answer(context),
              child: const Text('Edit my answer'),
            ),
          ],
        ],
      ),
    );
  }

  void _answer(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => _AnswerSheet(talk.prompt),
    );
  }
}

class _AnswerSheet extends ConsumerStatefulWidget {
  const _AnswerSheet(this.prompt);

  final Prompt prompt;

  @override
  ConsumerState<_AnswerSheet> createState() => _AnswerSheetState();
}

class _AnswerSheetState extends ConsumerState<_AnswerSheet> {
  final _answer = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_answer.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).answerTalk(_answer.text.trim());
      ref.invalidate(talkProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, friendlyError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.prompt.question, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text("Your partner's answer is revealed once you share yours.", style: TextStyle(color: context.pn.muted, fontSize: 12)),
          const SizedBox(height: 14),
          TextField(
            controller: _answer,
            autofocus: true,
            maxLines: 4,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Write from the heart…'),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _busy ? null : _send, child: const Text('Share')),
        ],
      ),
    );
  }
}

class _PastTalkTile extends ConsumerWidget {
  const _PastTalkTile(this.talk);

  final PastTalk talk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pn;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: Text(talk.prompt.question, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(longDate(talk.lastAnsweredAt), style: TextStyle(color: p.muted, fontSize: 12)),
        children: [
          for (final a in talk.answers)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MemberAvatar(userId: a.userId, name: a.userName, size: 26),
                  const SizedBox(width: 10),
                  Expanded(child: Text(a.answer, style: const TextStyle(height: 1.4))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
