import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../theme/palettes.dart';

/// Each partner keeps the color of "their" mascot bird.
Color memberColor(BuildContext context, Couple? couple, int userId) {
  final p = context.pn;
  return (couple?.indexOf(userId) ?? 0) == 0 ? p.birdA : p.birdB;
}
