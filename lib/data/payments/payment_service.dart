import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:xrpl_dart/xrpl_dart.dart';
import 'package:xrpl_mobile_wallet/domain/amount/xrp_amount.dart';
import 'package:xrpl_mobile_wallet/domain/validation/secret_validator.dart';

/// Result of submitting a Payment transaction.
class PaymentSubmitResult {
  const PaymentSubmitResult({
    required this.hash,
    required this.engineResult,
    required this.engineResultMessage,
    required this.isSuccess,
    this.feeDrops,
  });

  final String hash;
  final String engineResult;
  final String engineResultMessage;
  final bool isSuccess;

  /// Fee in drops after autoFill, if known.
  final String? feeDrops;
}

/// Pure validation helpers for send-form inputs (unit-testable).
class PaymentValidators {
  PaymentValidators._();

  /// Returns an error message, or null if [amount] is a valid positive XRP amount.
  static String? validateXrpAmount(String amount) {
    final trimmed = amount.trim();
    if (trimmed.isEmpty) return 'Enter an amount';
    try {
      final drops = XrpAmount.xrpToDrops(trimmed);
      final value = BigInt.parse(drops);
      if (value <= BigInt.zero) return 'Amount must be greater than zero';
      return null;
    } on FormatException catch (e) {
      return e.message;
    } catch (_) {
      return 'Invalid XRP amount';
    }
  }

  /// Returns an error message, or null if [amount] is a valid positive IOU value.
  static String? validateIouAmount(String amount) {
    final trimmed = amount.trim();
    if (trimmed.isEmpty) return 'Enter an amount';
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(trimmed)) {
      return 'Invalid amount format';
    }
    // Reject all-zero values like "0", "0.0", "0.000".
    final normalized = trimmed.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final nonzero = normalized.replaceAll(RegExp(r'[0.]'), '');
    if (nonzero.isEmpty) return 'Amount must be greater than zero';
    return null;
  }

  /// Parses an optional destination tag. Empty → null. Invalid → throws [FormatException].
  static int? parseDestinationTag(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    if (!RegExp(r'^\d+$').hasMatch(trimmed)) {
      throw const FormatException('Destination tag must be a whole number');
    }
    final value = int.parse(trimmed);
    // XRPL destination tags are unsigned 32-bit.
    if (value < 0 || value > 0xFFFFFFFF) {
      throw const FormatException('Destination tag out of range (0–4294967295)');
    }
    return value;
  }

  /// Compares two positive decimal amount strings (no scientific notation).
  /// Returns negative if [a] < [b], zero if equal, positive if [a] > [b].
  static int compareDecimal(String a, String b) {
    final ra = BigRational.parseDecimal(a.trim());
    final rb = BigRational.parseDecimal(b.trim());
    return ra.compareTo(rb);
  }
}

/// Builds, signs, and submits XRPL Payment transactions.
///
/// Secrets are accepted as method arguments (from KeyVault at the call site),
/// kept in local variables only, and never logged.
class PaymentService {
  /// Reconstruct an [XRPPrivateKey] from a stored secret using the same rules
  /// as [WalletImporter] (mnemonic BIP44 path or family seed).
  ///
  /// Mnemonics use [XRPKeyAlgorithm.secp256k1] first (match `xrpl.js`
  /// `Wallet.fromMnemonic` and [WalletImporter.importMnemonic]). When
  /// [expectedAddress] is set and secp does not match, tries ed25519 so
  /// wallets mis-imported under the old ed25519-first path can still sign.
  static XRPPrivateKey privateKeyFromSecret(
    String secret, {
    String? expectedAddress,
  }) {
    final trimmed = secret.trim().replaceAll(RegExp(r'\s+'), ' ');

    if (SecretValidator.looksLikeFamilySeed(trimmed)) {
      final pk = XRPPrivateKey.fromSeed(trimmed);
      _assertAddress(pk, expectedAddress);
      return pk;
    }

    if (SecretValidator.looksLikeMnemonic(trimmed)) {
      final List<int> seedBytes;
      try {
        seedBytes =
            Bip39SeedGenerator(Mnemonic.fromString(trimmed)).generate();
      } catch (e) {
        throw ArgumentError('Invalid mnemonic: $e');
      }

      final bip32 = Bip44.fromSeed(seedBytes, Bip44Coins.ripple)
          .purpose
          .coin
          .account(0)
          .change(Bip44Changes.chainExt)
          .addressIndex(0);
      final raw = bip32.privateKey.raw;

      // Prefer secp256k1 (current import + xrpl.js). Fall back to ed25519 only
      // when an expected classic address is provided and matches that curve
      // (legacy mis-imports before the secp-only mnemonic fix).
      final algorithms = <XRPKeyAlgorithm>[
        XRPKeyAlgorithm.secp256k1,
        if (expectedAddress != null) XRPKeyAlgorithm.ed25519,
      ];

      XRPPrivateKey? matched;
      Object? lastError;
      for (final algo in algorithms) {
        try {
          final pk = XRPPrivateKey.fromBytes(raw, algorithm: algo);
          final addr = pk.getPublic().toClassicAddress().address;
          if (expectedAddress == null || addr == expectedAddress) {
            matched = pk;
            break;
          }
        } catch (e) {
          lastError = e;
        }
      }

      if (matched == null) {
        throw ArgumentError(
          expectedAddress != null
              ? 'Derived key does not match wallet address'
              : 'Could not derive key from mnemonic: $lastError',
        );
      }
      return matched;
    }

    throw ArgumentError(
      'Unrecognized secret format (expected mnemonic or family seed)',
    );
  }

  static void _assertAddress(XRPPrivateKey pk, String? expectedAddress) {
    if (expectedAddress == null) return;
    final addr = pk.getPublic().toClassicAddress().address;
    if (addr != expectedAddress) {
      throw ArgumentError('Derived key does not match wallet address');
    }
  }

  Future<PaymentSubmitResult> sendXrp({
    required String walletId,
    required String secret,
    required String fromAddress,
    required String destination,
    int? destinationTag,
    required String amountXrp,
    required XRPProvider rpc,
  }) async {
    final amountError = PaymentValidators.validateXrpAmount(amountXrp);
    if (amountError != null) {
      throw ArgumentError(amountError);
    }

    final drops = XRPHelper.xrpToDrop(amountXrp.trim());
    final amount = XRPAmount(drops);

    return _signAndSubmit(
      secret: secret,
      fromAddress: fromAddress,
      destination: destination,
      destinationTag: destinationTag,
      amount: amount,
      rpc: rpc,
    );
  }

  Future<PaymentSubmitResult> sendIou({
    required String walletId,
    required String secret,
    required String fromAddress,
    required String destination,
    int? destinationTag,
    required String currency,
    required String issuer,
    required String value,
    required XRPProvider rpc,
  }) async {
    final amountError = PaymentValidators.validateIouAmount(value);
    if (amountError != null) {
      throw ArgumentError(amountError);
    }
    if (currency.trim().isEmpty) {
      throw ArgumentError('Currency is required');
    }
    if (issuer.trim().isEmpty) {
      throw ArgumentError('Issuer is required');
    }

    final amount = IssuedCurrencyAmount(
      value: value.trim(),
      currency: currency.trim(),
      issuer: issuer.trim(),
    );

    return _signAndSubmit(
      secret: secret,
      fromAddress: fromAddress,
      destination: destination,
      destinationTag: destinationTag,
      amount: amount,
      rpc: rpc,
    );
  }

  Future<PaymentSubmitResult> sendXrpWithLedger({
    required String fromAddress,
    required String destination,
    int? destinationTag,
    required String amountXrp,
    required XRPProvider rpc,
    required String publicKeyHex,
    required Future<String> Function(List<int> txBlob) signTransactionBlob,
  }) async {
    final amountError = PaymentValidators.validateXrpAmount(amountXrp);
    if (amountError != null) throw ArgumentError(amountError);
    final drops = XRPHelper.xrpToDrop(amountXrp.trim());
    return signAndSubmitWithLedgerKeys(
      fromAddress: fromAddress,
      destination: destination,
      destinationTag: destinationTag,
      amount: XRPAmount(drops),
      rpc: rpc,
      publicKeyHex: publicKeyHex,
      signTransactionBlob: signTransactionBlob,
    );
  }

  Future<PaymentSubmitResult> sendIouWithLedger({
    required String fromAddress,
    required String destination,
    int? destinationTag,
    required String currency,
    required String issuer,
    required String value,
    required XRPProvider rpc,
    required String publicKeyHex,
    required Future<String> Function(List<int> txBlob) signTransactionBlob,
  }) async {
    final amountError = PaymentValidators.validateIouAmount(value);
    if (amountError != null) throw ArgumentError(amountError);
    return signAndSubmitWithLedgerKeys(
      fromAddress: fromAddress,
      destination: destination,
      destinationTag: destinationTag,
      amount: IssuedCurrencyAmount(
        value: value.trim(),
        currency: currency.trim(),
        issuer: issuer.trim(),
      ),
      rpc: rpc,
      publicKeyHex: publicKeyHex,
      signTransactionBlob: signTransactionBlob,
    );
  }

  /// Sign Payment with Ledger public key + device signature (no private key on phone).
  ///
  /// Matches codebaseOne / `@ledgerhq/hw-app-xrp`:
  /// 1. autofill
  /// 2. set SigningPubKey
  /// 3. encode full STObject (no TxnSignature) → device signs that blob
  /// 4. attach TxnSignature and submit
  ///
  /// Do **not** send [BaseTransaction.toSigningBlobBytes] (STX\\0 prefix) to the
  /// device — that is for software hash-and-sign only and causes SW 0x680b.
  Future<PaymentSubmitResult> signAndSubmitWithLedgerKeys({
    required String fromAddress,
    required String destination,
    int? destinationTag,
    required BaseAmount amount,
    required XRPProvider rpc,
    required String publicKeyHex,
    required Future<String> Function(List<int> txBlob) signTransactionBlob,
  }) async {
    final pub = XRPPublicKey.fromHex(publicKeyHex);
    final derived = pub.toClassicAddress().address;
    if (derived != fromAddress) {
      throw StateError(
        'Ledger address $derived does not match this wallet ($fromAddress). '
        'Check the account index or uncheck Ledger Device.',
      );
    }

    final transaction = Payment(
      amount: amount,
      destination: destination.trim(),
      destinationTag: destinationTag,
      account: fromAddress,
      // SigningPubKey only (no TxnSignature yet) — same as xrpl.js encode(prepared).
      signer: XRPLSignature.signer(publicKeyHex),
    );

    await XRPHelper.autoFill(rpc, transaction);
    final feeDrops = transaction.fee?.toString();

    // Ledger XRP app expects the serialized transaction STObject, not the
    // STX\0-prefixed software signing digest.
    final txBlob = transaction.toTransactionBlobBytes();
    final sigHex = await signTransactionBlob(txBlob);
    transaction.setSignature(
      XRPLSignature.sign(publicKeyHex, sigHex),
    );

    final trBlob = transaction.toTransactionBlob();
    final result = await rpc.request(XRPRequestSubmit(txBlob: trBlob));

    return PaymentSubmitResult(
      hash: result.txJson.hash ?? transaction.getHash(),
      engineResult: result.engineResult,
      engineResultMessage: result.engineResultMessage,
      isSuccess: result.isSuccess,
      feeDrops: feeDrops,
    );
  }

  Future<PaymentSubmitResult> _signAndSubmit({
    required String secret,
    required String fromAddress,
    required String destination,
    int? destinationTag,
    required BaseAmount amount,
    required XRPProvider rpc,
  }) async {
    // Local-only key material; not stored or logged.
    final privateKey = privateKeyFromSecret(
      secret,
      expectedAddress: fromAddress,
    );
    final publicKey = privateKey.getPublic();
    final signerAddress = publicKey.toClassicAddress();
    final pubHex = publicKey.toHex();

    final transaction = Payment(
      amount: amount,
      destination: destination.trim(),
      destinationTag: destinationTag,
      account: fromAddress,
      signer: XRPLSignature.signer(pubHex),
    );

    await XRPHelper.autoFill(rpc, transaction);
    final feeDrops = transaction.fee?.toString();

    final blob = transaction.toSigningBlobBytes(signerAddress);
    final sig = privateKey.sign(blob);
    transaction.setSignature(sig);

    final trBlob = transaction.toTransactionBlob();
    final result = await rpc.request(XRPRequestSubmit(txBlob: trBlob));

    return PaymentSubmitResult(
      hash: result.txJson.hash ?? transaction.getHash(),
      engineResult: result.engineResult,
      engineResultMessage: result.engineResultMessage,
      isSuccess: result.isSuccess,
      feeDrops: feeDrops,
    );
  }
}
