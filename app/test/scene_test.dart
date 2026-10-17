import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pairnest/core/theme/app_theme.dart';
import 'package:pairnest/core/theme/palettes.dart';
import 'package:pairnest/core/widgets/categories.dart';
import 'package:pairnest/core/widgets/nest_ui.dart';

void main() {
  testWidgets('every goal scene paints at card and row sizes, light and dark', (tester) async {
    final kinds = [...goalIcons.keys, 'date', 'unknown'];
    for (final theme in ['sage', 'midnight']) {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(paletteById(theme), googleFonts: false),
          home: Scaffold(
            body: ListView(
              children: [
                for (final kind in kinds) ...[
                  SizedBox(width: 320, child: SceneBanner(kind: kind, height: 84)),
                  SizedBox(width: 56, child: SceneBanner(kind: kind, height: 46, radius: 12)),
                ],
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: theme);
    }
    // The new kinds have icons and tints for the goal picker.
    for (final k in ['pet', 'business', 'retire']) {
      expect(goalIcons[k], isNotNull);
      expect(goalTints[k], isNotNull);
    }
  });
}
