// Design-preview entry point: boots straight into the signed-in demo nest so
// every screen can be opened by URL (e.g. /#/goals, /?theme=midnight#/us,
// /?onboarding=1 for the welcome flow, /?empty=1 for a brand-new nest, /?due=1 or /?due=2 for bill
// reminders, /?tight=1 for a nearly spent budget, /?scenes=1 for every goal
// illustration). Not used by the real app.
//
//   flutter build web -t tool/preview_main.dart -o build/preview
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pairnest/app.dart';
import 'package:pairnest/core/theme/app_theme.dart';
import 'package:pairnest/core/theme/palettes.dart';
import 'package:pairnest/core/widgets/categories.dart';
import 'package:pairnest/core/widgets/nest_ui.dart';
import 'package:pairnest/data/mock_repository.dart';
import 'package:pairnest/data/models.dart';
import 'package:pairnest/data/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final theme = Uri.base.queryParameters['theme'] ?? 'sage';
  if (Uri.base.queryParameters['scenes'] != null) return runApp(_SceneGallery(theme));
  // ignore: invalid_use_of_visible_for_testing_member
  final fresh = Uri.base.queryParameters['fresh'] != null; // ?fresh=1 starts at onboarding
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({'onboarded': !fresh, 'theme_chosen': true, 'theme': theme});
  final prefs = await SharedPreferences.getInstance();
  final repo = MockRepository(seed: Uri.base.queryParameters['empty'] == null);
  // ?onboarding=1 previews the welcome questions; otherwise open the demo nest.
  if (!fresh && Uri.base.queryParameters['onboarding'] == null) {
    await repo.recover(MockRepository.demoKey);
    await repo.updateTheme(theme);
  }
  // ?tight=1: spending past 90% of the budget, for the thoughtful birds.
  if (Uri.base.queryParameters['tight'] != null) {
    await repo.addTransaction(
      TxnDraft(
        type: 'expense',
        amount: 11500,
        category: 'shopping',
        title: 'New sofa',
        paymentMethod: 'card',
        isSplit: true,
        occurredOn: DateTime.now(),
      ),
    );
  }
  final due = int.tryParse(Uri.base.queryParameters['due'] ?? '') ?? 0;
  final today = DateTime.now();
  if (due >= 1) {
    await repo.addBill(
      BillDraft(title: 'Internet', amount: 1699, category: 'bills', frequency: 'monthly', nextDueOn: today.add(const Duration(days: 1))),
    );
  }
  if (due >= 2) {
    await repo.addBill(
      BillDraft(title: 'Water', amount: 480, category: 'bills', frequency: 'monthly', nextDueOn: today.subtract(const Duration(days: 2))),
    );
  }

  runApp(
    ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs), repositoryProvider.overrideWithValue(repo)],
      child: const PairnestApp(),
    ),
  );
}

/// Every goal illustration at card and row size, for design review.
class _SceneGallery extends StatelessWidget {
  const _SceneGallery(this.theme);

  final String theme;

  @override
  Widget build(BuildContext context) {
    final kinds = [...goalIcons.keys, 'date'];
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(paletteById(theme), googleFonts: false),
      home: Scaffold(
        body: GridView.count(
          crossAxisCount: 3,
          padding: const EdgeInsets.all(12),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.25,
          children: [
            for (final k in kinds)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SceneBanner(kind: k, height: 84),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      SizedBox(width: 56, child: SceneBanner(kind: k, height: 46, radius: 12)),
                      const SizedBox(width: 8),
                      Text(k),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
