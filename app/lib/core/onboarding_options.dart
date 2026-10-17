/// The choices onboarding offers. Keys match the API
/// (backend `App\Services\StarterGoals`), so picked goals become the same
/// starter savings goals in demo mode and against the server.
class GoalOption {
  const GoalOption(this.key, this.label, this.goalName, this.icon, this.target);

  final String key;

  /// What the chip says.
  final String label;

  /// The starter goal it creates.
  final String goalName;
  final String icon;
  final double target;
}

const financialGoalOptions = [
  GoalOption('emergency', 'Emergency fund', 'Emergency Fund', 'shield', 50000),
  GoalOption('home', 'Our own home', 'Our Home', 'home', 500000),
  GoalOption('travel', 'Travel', 'Travel Fund', 'travel', 60000),
  GoalOption('wedding', 'Wedding', 'Our Wedding', 'ring', 300000),
  GoalOption('debt_free', 'Debt-free', 'Debt-Free', 'star', 100000),
  GoalOption('car', 'A car', 'Car', 'car', 300000),
  GoalOption('retirement', 'Retirement', 'Retirement', 'retire', 1000000),
  GoalOption('business', 'Our business', 'Our Business', 'business', 200000),
];

const familyGoalOptions = [
  GoalOption('getting_married', 'Getting married', 'Our Wedding', 'ring', 300000),
  GoalOption('kids', 'Having kids', 'Baby Fund', 'baby', 150000),
  GoalOption('education', "Kids' education", "Kids' Education", 'school', 500000),
  GoalOption('parents', 'Caring for parents', "Parents' Care", 'home', 100000),
  GoalOption('pet', 'A pet', 'Pet Fund', 'pet', 30000),
];

GoalOption? goalOption(String key) {
  for (final o in [...financialGoalOptions, ...familyGoalOptions]) {
    if (o.key == key) return o;
  }
  return null;
}

const relationshipStages = {'dating': 'Dating', 'engaged': 'Engaged', 'married': 'Married', 'living_together': 'Living together'};

/// key → (title, description)
const moneyStyles = {
  'shared': ('We share everything', 'One pot for all our money.'),
  'partly': ('Partly shared', 'Some together, some our own.'),
  'separate': ('Separate, shared bills', 'Our own money; we split the bills.'),
};
