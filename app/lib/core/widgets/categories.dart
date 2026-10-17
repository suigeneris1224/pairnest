import 'package:flutter/material.dart';

import '../motion/motion.dart';
import '../theme/palettes.dart';

class CategoryStyle {
  const CategoryStyle(this.key, this.label, this.icon, this.color, [this.short]);

  final String key;
  final String label;

  /// Compact label for tight legends; falls back to [label].
  final String? short;
  final IconData icon;
  final Color color;
}

const expenseCategories = [
  CategoryStyle('food', 'Food & Dining', Icons.restaurant_rounded, Color(0xFF6F9B7A), 'Food'),
  CategoryStyle('transport', 'Transport', Icons.directions_car_rounded, Color(0xFFF0A27E)),
  CategoryStyle('bills', 'Bills & Utilities', Icons.home_rounded, Color(0xFF8DB6D9), 'Bills'),
  CategoryStyle('shopping', 'Shopping', Icons.shopping_bag_rounded, Color(0xFFA99BCB)),
  CategoryStyle('entertainment', 'Entertainment', Icons.favorite_rounded, Color(0xFFE8A0A8), 'Fun'),
  CategoryStyle('health', 'Health', Icons.medical_services_rounded, Color(0xFF7FBFB5)),
  CategoryStyle('others', 'Others', Icons.more_horiz_rounded, Color(0xFFB9B3C9)),
];

const incomeCategory = CategoryStyle('income', 'Income', Icons.savings_rounded, Color(0xFF4E9F7A));

/// Transfers into goals; set by the app, never picked.
const savingsCategory = CategoryStyle('savings', 'Savings', Icons.track_changes_rounded, Color(0xFF8E7CC3));

CategoryStyle categoryStyle(String key) => switch (key) {
  'income' => incomeCategory,
  'savings' => savingsCategory,
  _ => expenseCategories.firstWhere((c) => c.key == key, orElse: () => expenseCategories.last),
};

class CategoryIcon extends StatelessWidget {
  const CategoryIcon(this.category, {super.key, this.size = 44});

  final String category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = categoryStyle(category);
    return Container(
      width: size,
      height: size,
      // Soft circle with a deepened icon, as in the dashboard legend.
      decoration: BoxDecoration(color: style.color.withValues(alpha: 0.2), shape: BoxShape.circle),
      child: Icon(style.icon, color: Color.lerp(style.color, Colors.black, 0.25), size: size * 0.48),
    );
  }
}

const goalIcons = <String, IconData>{
  'travel': Icons.flight_takeoff_rounded,
  'shield': Icons.shield_rounded,
  'home': Icons.home_rounded,
  'car': Icons.directions_car_filled_rounded,
  'school': Icons.school_rounded,
  'ring': Icons.diamond_rounded,
  'baby': Icons.child_friendly_rounded,
  'star': Icons.star_rounded,
  'pet': Icons.pets_rounded,
  'business': Icons.storefront_rounded,
  'retire': Icons.beach_access_rounded,
};

const goalTints = <String, List<Color>>{
  'travel': [Color(0xFF8CC7D9), Color(0xFF4F9BB5)],
  'shield': [Color(0xFFA9CFA4), Color(0xFF5E9B6E)],
  'home': [Color(0xFFF6C9A8), Color(0xFFE3845F)],
  'car': [Color(0xFFB9C3E8), Color(0xFF6C83C9)],
  'school': [Color(0xFFF2D58C), Color(0xFFD9A43B)],
  'ring': [Color(0xFFE0C8F0), Color(0xFF9077BF)],
  'baby': [Color(0xFFF7C6CF), Color(0xFFE0717C)],
  'star': [Color(0xFFF2D58C), Color(0xFFE5A54B)],
  'pet': [Color(0xFFC9DFA8), Color(0xFF7FA35A)],
  'business': [Color(0xFFB7D3E8), Color(0xFF5B87B0)],
  'retire': [Color(0xFFF6C99E), Color(0xFFE08A52)],
};

/// A round, selectable category button for pickers.
class CategoryChoice extends StatelessWidget {
  const CategoryChoice({super.key, required this.style, required this.selected, required this.onTap});

  final CategoryStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    return Semantics(
      selected: selected,
      button: true,
      child: PressScale(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: selected ? p.soft : p.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? p.primaryDeep : p.border, width: selected ? 2 : 1),
                ),
                child: Icon(style.icon, color: selected ? p.primaryDeep : style.color),
              ),
              const SizedBox(height: 6),
              Text(
                style.label,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, height: 1.2, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
