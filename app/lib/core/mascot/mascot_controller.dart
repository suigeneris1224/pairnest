import 'package:flutter/foundation.dart';

/// A lasting state for the birds, blended in and out.
enum MascotMood {
  idle,

  /// Empty states: one bird tilts its head, the other gestures at the action.
  curious,

  /// Budget warnings: a calm, considering look, never sad or alarmed.
  thoughtful,
}

/// A short, one-off reaction to something the couple just did.
enum MascotReaction {
  /// An expense was added: a glance down at the list.
  glance,

  /// Money was saved: a small encouraging hop.
  cheer,

  /// A goal was reached: bounces, wing flaps and hearts.
  celebrate,
}

/// Triggers reactions on any [MascotPair] it's attached to.
class MascotController extends ChangeNotifier {
  MascotReaction? _last;
  int _count = 0;

  /// The most recent reaction; [count] tells listeners a new one arrived.
  MascotReaction? get last => _last;
  int get count => _count;

  void react(MascotReaction reaction) {
    _last = reaction;
    _count++;
    notifyListeners();
  }
}
