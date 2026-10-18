import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pairnest/core/widgets/bank_card.dart';
import 'package:pairnest/core/widgets/wallet_brands.dart';
import 'package:pairnest/data/models.dart';

/// Must match the backend's Wallet::PROVIDERS.
const serverProviders = [
  'gcash', 'maya', 'grabpay', 'shopeepay', 'coins', //
  'maribank', 'gotyme', 'tonik', 'uno', 'cimb', 'seabank',
  'bpi', 'bdo', 'metrobank', 'unionbank', 'securitybank', 'landbank', 'pnb', 'rcbc', 'chinabank', 'eastwest', 'psbank', 'aub',
  'cash', 'other',
];

void main() {
  test('every provider the server accepts has a brand, and nothing more', () {
    expect(walletBrands.map((b) => b.key), unorderedEquals(serverProviders));
    expect(brandOf('nope').key, 'other');
  });

  test('white text stays readable on every brand card', () {
    for (final b in walletBrands) {
      expect(contrastRatio(Colors.white, b.base), greaterThanOrEqualTo(4.5), reason: '${b.name} base');
      expect(contrastRatio(Colors.white, b.dark), greaterThanOrEqualTo(4.5), reason: '${b.name} dark');
    }
  });

  test('badges are short', () {
    for (final b in walletBrands) {
      expect(b.badge.length, inInclusiveRange(1, 3), reason: b.name);
    }
    expect(brandOf('securitybank').badge, 'SB');
  });

  test('balance labels: owed on credit cards, private for a partner', () {
    Wallet w(String kind, double? balance) => Wallet(id: 1, name: 'W', kind: kind, balance: balance);
    expect(walletBalanceText(w('ewallet', 4200)), '₱4,200');
    expect(walletBalanceText(w('debit', -50)), '-₱50');
    expect(walletBalanceText(w('credit', -6300)), '₱6,300 owed');
    expect(walletBalanceText(w('credit', 0)), 'Nothing owed');
    expect(walletBalanceText(w('credit', 120)), '₱120 credit');
    expect(walletBalanceText(w('debit', null)), 'Balance private');
    expect(walletBalanceText(w('ewallet', 4200), hide: true), '₱••••');
    expect(walletBalanceText(w('credit', -6300), hide: true), '₱•••• owed');
  });
}
