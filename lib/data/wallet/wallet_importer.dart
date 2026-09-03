import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:uuid/uuid.dart';
import 'package:xrpl_dart/xrpl_dart.dart';
import 'package:xrpl_mobile_wallet/domain/wallet/wallet_account.dart';
import 'package:xrpl_mobile_wallet/domain/validation/address_validator.dart';
import 'package:xrpl_mobile_wallet/domain/validation/secret_validator.dart';

/// Result of a successful import (not yet persisted).
class ImportResult {
  const ImportResult({
    required this.account,
    this.secret,
  });

  final WalletAccount account;

  /// Raw secret material for KeyVault. Null for watch-only wallets.
  final String? secret;
}

/// Derived signing material (no new account id) for import or attach-keys.
class DerivedSecret {
  const DerivedSecret({
    required this.address,
    required this.secret,
    required this.importMethod,
  });

  final String address;
  final String secret;
  final ImportMethod importMethod;
}

/// Derives classic addresses from mnemonic / family seed / watch-only address.
class WalletImporter {
  WalletImporter({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  /// BIP39 mnemonic → classic address + normalized secret (secp256k1 BIP44).
  ///
  /// Path `m/44'/144'/0'/0/0`, matching `xrpl.js` `Wallet.fromMnemonic`.
  DerivedSecret deriveMnemonic(String phrase) {
    final trimmed = phrase.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    if (!SecretValidator.looksLikeMnemonic(trimmed)) {
      throw ArgumentError('Enter 12 or 24 recovery words');
    }

    final List<int> seedBytes;
    try {
      seedBytes = Bip39SeedGenerator(Mnemonic.fromString(trimmed)).generate();
    } catch (e) {
      throw ArgumentError('Invalid recovery phrase');
    }

    final bip32 = Bip44.fromSeed(seedBytes, Bip44Coins.ripple)
        .purpose
        .coin
        .account(0)
        .change(Bip44Changes.chainExt)
        .addressIndex(0);

    final raw = bip32.privateKey.raw;
    final XRPPrivateKey pk;
    try {
      pk = XRPPrivateKey.fromBytes(raw, algorithm: XRPKeyAlgorithm.secp256k1);
    } catch (e) {
      throw ArgumentError('Could not derive key from mnemonic: $e');
    }

    return DerivedSecret(
      address: pk.getPublic().toClassicAddress().address,
      secret: trimmed,
      importMethod: ImportMethod.mnemonic,
    );
  }

  /// Family seed (`s...`) → classic address + secret.
  DerivedSecret deriveFamilySeed(String seed) {
    final trimmed = seed.trim();
    if (!SecretValidator.looksLikeFamilySeed(trimmed)) {
      throw ArgumentError(
        'Family seed must start with "s" and contain no spaces',
      );
    }

    final XRPPrivateKey pk;
    try {
      pk = XRPPrivateKey.fromSeed(trimmed);
    } catch (e) {
      throw ArgumentError('Invalid family seed');
    }

    return DerivedSecret(
      address: pk.getPublic().toClassicAddress().address,
      secret: trimmed,
      importMethod: ImportMethod.familySeed,
    );
  }

  /// Derive mnemonic and require [expectedAddress] match (attach-keys gate).
  DerivedSecret deriveMnemonicForAddress(
    String phrase, {
    required String expectedAddress,
  }) {
    final derived = deriveMnemonic(phrase);
    _requireAddressMatch(derived.address, expectedAddress);
    return derived;
  }

  /// Derive family seed and require [expectedAddress] match (attach-keys gate).
  DerivedSecret deriveFamilySeedForAddress(
    String seed, {
    required String expectedAddress,
  }) {
    final derived = deriveFamilySeed(seed);
    _requireAddressMatch(derived.address, expectedAddress);
    return derived;
  }

  void _requireAddressMatch(String derived, String expected) {
    if (derived != expected) {
      throw ArgumentError(
        'This secret does not match this wallet\'s address.',
      );
    }
  }

  /// BIP39 mnemonic → BIP44 path `m/44'/144'/0'/0/0` → XRPL classic address.
  ///
  /// Uses [XRPKeyAlgorithm.secp256k1], matching `xrpl.js` `Wallet.fromMnemonic`
  /// (BIP32 HD). Family seeds / `Wallet.generate()` often use ed25519; that is
  /// a different import path ([importFamilySeed]).
  ImportResult importMnemonic(
    String phrase, {
    required String label,
    required NetworkId network,
  }) {
    final derived = deriveMnemonic(phrase);
    return ImportResult(
      account: WalletAccount(
        id: _uuid.v4(),
        label: _requireLabel(label),
        address: derived.address,
        kind: WalletKind.signing,
        preferredNetwork: network,
        importMethod: ImportMethod.mnemonic,
        createdAt: DateTime.now().toUtc(),
      ),
      secret: derived.secret,
    );
  }

  /// Family seed (`s...`) → classic address via [XRPPrivateKey.fromSeed].
  ImportResult importFamilySeed(
    String seed, {
    required String label,
    required NetworkId network,
  }) {
    final derived = deriveFamilySeed(seed);
    return ImportResult(
      account: WalletAccount(
        id: _uuid.v4(),
        label: _requireLabel(label),
        address: derived.address,
        kind: WalletKind.signing,
        preferredNetwork: network,
        importMethod: ImportMethod.familySeed,
        createdAt: DateTime.now().toUtc(),
      ),
      secret: derived.secret,
    );
  }

  /// Watch-only classic address (no secret stored).
  ImportResult importWatchOnly(
    String address, {
    required String label,
    required NetworkId network,
  }) {
    final trimmed = address.trim();
    if (!AddressValidator.isValidClassic(trimmed)) {
      throw ArgumentError('Invalid XRPL classic address');
    }

    return ImportResult(
      account: WalletAccount(
        id: _uuid.v4(),
        label: _requireLabel(label),
        address: trimmed,
        kind: WalletKind.watchOnly,
        preferredNetwork: network,
        importMethod: ImportMethod.addressOnly,
        createdAt: DateTime.now().toUtc(),
      ),
      secret: null,
    );
  }

  String _requireLabel(String label) {
    final t = label.trim();
    if (t.isEmpty) {
      throw ArgumentError('Label is required');
    }
    return t;
  }
}
