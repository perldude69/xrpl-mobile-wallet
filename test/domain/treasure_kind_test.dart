import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/domain/wallet/treasure_kind.dart';

void main() {
  test('fromAddress is stable and non-empty', () {
    const addr = 'rHsMGQEkVNJmpGWs8XUBoTBiAAbwxZN5v3';
    final a = TreasureKind.fromAddress(addr);
    final b = TreasureKind.fromAddress('  $addr  ');
    expect(a, b);
    expect(TreasureKind.fromAddress(''), TreasureKind.chest);
  });

  test('different addresses are not all the same kind', () {
    const samples = [
      'rHsMGQEkVNJmpGWs8XUBoTBiAAbwxZN5v3',
      'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh',
      'rJTyAxvqh9UcigEfK2CTAd3ipUEvchDNzr',
      'rXUMMaPpZqPutoRszR29jtC8amWq3APkx',
      'rrrrrrrrrrrrrrrrrrrrrhoLvTp',
    ];
    final kinds = samples.map(TreasureKind.fromAddress).toSet();
    expect(kinds.length, greaterThan(1));
  });
}
