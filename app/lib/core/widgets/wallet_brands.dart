import 'package:flutter/material.dart';

/// A local bank or e-wallet's card colours. Only colours and the name are
/// used, never logos. Each base keeps white text readable (4.5:1 or more).
class WalletBrand {
  const WalletBrand(this.key, this.name, this.group, this.kind, this.light, this.base, this.dark, {this.accent, this.short});

  final String key;
  final String name;

  /// E-wallets, Digital banks, Banks or Other, for the editor's grid.
  final String group;

  /// The kind a new wallet of this brand starts as.
  final String kind;
  final Color light;
  final Color base;
  final Color dark;

  /// A thin stripe in the brand's second colour (BDO's yellow, PNB's red).
  final Color? accent;

  /// Up to 3 letters for the round badge; the name's initials otherwise.
  final String? short;

  List<Color> get colors => [light, base, dark];

  String get badge {
    if (short != null) return short!;
    final words = name.split(RegExp(r'[\s.]+')).where((w) => w.isNotEmpty).toList();
    return words.length > 1 ? words.take(2).map((w) => w[0]).join().toUpperCase() : name.substring(0, name.length.clamp(0, 2));
  }
}

const walletGroups = ['E-wallets', 'Digital banks', 'Banks', 'Other'];

const walletBrands = <WalletBrand>[
  WalletBrand('gcash', 'GCash', 'E-wallets', 'ewallet', Color(0xFF2A8BFF), Color(0xFF0061D5), Color(0xFF003F94), short: 'G'),
  WalletBrand('maya', 'Maya', 'E-wallets', 'ewallet', Color(0xFF00B464), Color(0xFF0E6B47), Color(0xFF0B1F17), short: 'M'),
  WalletBrand('grabpay', 'GrabPay', 'E-wallets', 'ewallet', Color(0xFF00B14F), Color(0xFF00803A), Color(0xFF004D23)),
  WalletBrand('shopeepay', 'ShopeePay', 'E-wallets', 'ewallet', Color(0xFFF26B4A), Color(0xFFD33B1D), Color(0xFF8F2410), short: 'SP'),
  WalletBrand('coins', 'Coins.ph', 'E-wallets', 'ewallet', Color(0xFF3D6DF5), Color(0xFF1446C8), Color(0xFF0B2A80), short: 'C'),
  WalletBrand('maribank', 'MariBank', 'Digital banks', 'debit', Color(0xFFF26A2E), Color(0xFFC23F0C), Color(0xFF7C2606), short: 'MB'),
  WalletBrand('gotyme', 'GoTyme', 'Digital banks', 'debit', Color(0xFF00BFC8), Color(0xFF0A3D62), Color(0xFF061F38), short: 'GT'),
  WalletBrand('tonik', 'Tonik', 'Digital banks', 'debit', Color(0xFF8B5CF6), Color(0xFF5B21B6), Color(0xFF34106E), short: 'T'),
  WalletBrand('uno', 'UNO', 'Digital banks', 'debit', Color(0xFF5A54C4), Color(0xFF2E2A72), Color(0xFF17143F), short: 'U'),
  WalletBrand('cimb', 'CIMB', 'Digital banks', 'debit', Color(0xFFE5343B), Color(0xFFB3141A), Color(0xFF6E0A0E), short: 'C'),
  WalletBrand('seabank', 'SeaBank', 'Digital banks', 'debit', Color(0xFFFF7A1A), Color(0xFFC2410C), Color(0xFF7A2706), short: 'S'),
  WalletBrand('bpi', 'BPI', 'Banks', 'debit', Color(0xFFD7262D), Color(0xFFA3141A), Color(0xFF5E0A0E)),
  WalletBrand('bdo', 'BDO', 'Banks', 'debit', Color(0xFF1D4FC4), Color(0xFF0033A0), Color(0xFF001E5E), accent: Color(0xFFFDB913)),
  WalletBrand('metrobank', 'Metrobank', 'Banks', 'debit', Color(0xFF1C5AA6), Color(0xFF003B71), Color(0xFF00213F), short: 'MB'),
  WalletBrand('unionbank', 'UnionBank', 'Banks', 'debit', Color(0xFFFF8000), Color(0xFFB04E00), Color(0xFF6B2F00), short: 'UB'),
  WalletBrand('securitybank', 'Security Bank', 'Banks', 'debit', Color(0xFF2E8BD6), Color(0xFF005A9C), Color(0xFF00355C)),
  WalletBrand(
    'landbank',
    'Landbank',
    'Banks',
    'debit',
    Color(0xFF16A34A),
    Color(0xFF00753A),
    Color(0xFF00421F),
    accent: Color(0xFFF5C518),
    short: 'LB',
  ),
  WalletBrand('pnb', 'PNB', 'Banks', 'debit', Color(0xFF1F5FAE), Color(0xFF003D7C), Color(0xFF002147), accent: Color(0xFFD7262D)),
  WalletBrand('rcbc', 'RCBC', 'Banks', 'debit', Color(0xFF2B7BD0), Color(0xFF00539B), Color(0xFF00305C), short: 'RC'),
  WalletBrand('chinabank', 'Chinabank', 'Banks', 'debit', Color(0xFFE11D48), Color(0xFFB30E28), Color(0xFF6B0817), short: 'CB'),
  WalletBrand('eastwest', 'EastWest', 'Banks', 'debit', Color(0xFF8B4FC0), Color(0xFF5B2C83), Color(0xFF34184D), short: 'EW'),
  WalletBrand('psbank', 'PSBank', 'Banks', 'debit', Color(0xFF3B73D6), Color(0xFF0D47A1), Color(0xFF062A61), short: 'PS'),
  WalletBrand('aub', 'AUB', 'Banks', 'debit', Color(0xFF3F64B8), Color(0xFF1B3F8B), Color(0xFF0E2352)),
  WalletBrand('cash', 'Cash', 'Other', 'cash', Color(0xFFB08A5B), Color(0xFF7A5C3A), Color(0xFF4A3622), short: '₱'),
  WalletBrand('other', 'Other', 'Other', 'debit', Color(0xFF64748B), Color(0xFF475569), Color(0xFF283240), short: '•'),
];

final _byKey = {for (final b in walletBrands) b.key: b};

WalletBrand brandOf(String key) => _byKey[key] ?? _byKey['other']!;

const walletKinds = {'debit': 'Debit', 'credit': 'Credit', 'ewallet': 'E-wallet', 'bank': 'Savings', 'cash': 'Cash'};

/// WCAG contrast ratio between two colours.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}
