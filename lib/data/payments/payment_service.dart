import 'dart:async';
import 'dart:convert';

import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:drift/drift.dart';
import 'package:xrpl_dart/xrpl_dart.dart';
import 'package:xrpl_mobile_wallet/config/app_config.dart';
import 'package:xrpl_mobile_wallet/config/network_id.dart';
import 'package:xrpl_mobile_wallet/domain/amount/xrp_amount.dart';
import 'package:xrpl_mobile_wallet/domain/tokens/rlusd.dart';
import 'package:xrpl_mobile_wallet/domain/validation/secret_validator.dart';
import 'package:xrpl_mobile_wallet/data/database/app_database.dart';

/// Destination account flags that affect whether a payment is safe to send.
class DestinationAccountPolicy {
  const DestinationAccountPolicy({
    required this.exists,
    required this.requireDestinationTag,
    required this.disallowIncomingXrp,
  });

  /// False when the classic address has never been funded (`actNotFound`).
  final bool exists;
  final bool requireDestinationTag;
  final bool disallowIncomingXrp;

  static const unfunded = DestinationAccountPolicy(
    exists: false,
    requireDestinationTag: false,
    disallowIncomingXrp: false,
  );

  static const int lsfRequireDestTag = 0x00020000;
  static const int lsfDisallowXrp = 0x00080000;

  factory DestinationAccountPolicy.fromFlags(int flags) {
    return DestinationAccountPolicy(
      exists: true,
      requireDestinationTag: (flags & lsfRequireDestTag) != 0,
      disallowIncomingXrp: (flags & lsfDisallowXrp) != 0,
    );
  }

  /// Error to show before signing, or null if the payment may proceed.
  String? sendError({required bool isXrp, required int? destinationTag}) {
    if (exists && requireDestinationTag && destinationTag == null) {
      return 'This destination requires a destination tag';
    }
    if (exists && isXrp && disallowIncomingXrp) {
      return 'This destination does not accept XRP';
    }
    return null;
  }
}

/// Result of submitting a Payment transaction.
class PaymentSubmitResult {
  const PaymentSubmitResult({
    required this.hash,
    required this.engineResult,
    required this.engineResultMessage,
    required this.isSuccess,
    this.feeDrops,
    this.lastLedgerSequence,
  });

  final String hash;
  final String engineResult;
  final String engineResultMessage;
  final bool isSuccess;

  /// Fee in drops after autoFill, if known.
  final String? feeDrops;

  /// `LastLedgerSequence` autoFill put on the transaction, if known.
  ///
  /// Recorded at submit time because it is the only thing that can later prove
  /// a missing transaction is definitively dead rather than merely slow: past
  /// this ledger with nothing validated, it can never be applied.
  final int? lastLedgerSequence;
}

class PaymentOperationException implements Exception {
  const PaymentOperationException(this.stage);

  final String stage;

  /// The transaction was signed, but the submit outcome is unknown.
  bool get submissionUncertain =>
      stage == 'submit timeout' || stage == 'submit transport';
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
      throw const FormatException(
        'Destination tag out of range (0–4294967295)',
      );
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

  /// Returns an error if [feeDrops] is missing, invalid, or above [maxDrops].
  static String? validateFeeDrops(String? feeDrops, {BigInt? maxDrops}) {
    final max = maxDrops ?? BigInt.from(AppConfig.maxFeeDrops);
    if (feeDrops == null || feeDrops.trim().isEmpty) {
      return 'Network fee is missing; refusing to sign';
    }
    final BigInt fee;
    try {
      fee = BigInt.parse(feeDrops.trim());
    } catch (_) {
      return 'Network fee is invalid; refusing to sign';
    }
    if (fee <= BigInt.zero) {
      return 'Network fee is invalid; refusing to sign';
    }
    if (fee > max) {
      return 'Network fee is ${XrpAmount.dropsToXrp(fee.toString())} XRP '
          '(max ${XrpAmount.dropsToXrp(max.toString())} XRP). Refusing to sign.';
    }
    return null;
  }

  /// Sign-time fee must match the value shown on Review (and still pass the cap).
  static String? reviewedFeeMatches({
    required String? reviewedDrops,
    required String? actualDrops,
  }) {
    final cap = validateFeeDrops(actualDrops);
    if (cap != null) return cap;
    if (reviewedDrops == null || reviewedDrops.trim().isEmpty) {
      return 'Review fee is missing; go back to Review';
    }
    final reviewed = BigInt.parse(reviewedDrops.trim());
    final actual = BigInt.parse(actualDrops!.trim());
    if (actual != reviewed) {
      return 'Network fee changed to ${XrpAmount.dropsToXrp(actual.toString())} XRP '
          '(reviewed ${XrpAmount.dropsToXrp(reviewed.toString())} XRP). '
          'Go back to Review to confirm the new fee.';
    }
    return null;
  }

  /// Amount + fee must fit in [availableXrp]. Unfunded destinations need
  /// at least [accountReserveDrops] (account-create reserve).
  static String? validateXrpSpendable({
    required String amountXrp,
    required String availableXrp,
    required String feeDrops,
    required bool destUnfunded,
    BigInt? accountReserveDrops,
  }) {
    final amountErr = validateXrpAmount(amountXrp);
    if (amountErr != null) return amountErr;
    final feeErr = validateFeeDrops(feeDrops);
    if (feeErr != null) return feeErr;
    final send = BigInt.parse(XrpAmount.xrpToDrops(amountXrp.trim()));
    final BigInt bal;
    try {
      bal = BigInt.parse(XrpAmount.xrpToDrops(availableXrp.trim()));
    } catch (_) {
      return 'Available balance is invalid';
    }
    final fee = BigInt.parse(feeDrops.trim());
    if (send + fee > bal) {
      return 'Amount plus network fee exceeds available balance';
    }
    if (destUnfunded) {
      final reserve =
          accountReserveDrops ??
          BigInt.from(AppConfig.accountCreateReserveDrops);
      if (send < reserve) {
        return 'Unfunded destination needs at least '
            '${XrpAmount.dropsToXrp(reserve.toString())} XRP';
      }
    }
    return null;
  }
}

/// Builds, signs, and submits XRPL Payment transactions.
///
/// Secrets are accepted as method arguments (from KeyVault at the call site),
/// kept in local variables only, and never logged.
class PaymentService {
  PaymentService({this.database});

  final AppDatabase? database;

  /// Signs and submits a non-Payment transaction using the same guarded path
  /// as payments. The transaction builder must contain only public inputs.
  ///
  /// [expectedFeeDrops] is the fee the user was actually shown at review. When
  /// given, autoFill must land on that same figure or signing is refused —
  /// otherwise a fee spike between review and signature is paid silently.
  Future<PaymentSubmitResult> signAndSubmitTransaction({
    String? walletId,
    String network = 'unknown',
    required String secret,
    required String fromAddress,
    required XRPProvider rpc,
    required SubmittableTransaction Function(String publicKeyHex) build,
    String? expectedFeeDrops,
  }) {
    return _signAndSubmit(
      walletId: walletId,
      network: network,
      secret: secret,
      fromAddress: fromAddress,
      rpc: rpc,
      build: build,
      expectedFeeDrops: expectedFeeDrops,
    );
  }

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
        seedBytes = Bip39SeedGenerator(Mnemonic.fromString(trimmed)).generate();
      } catch (e) {
        throw ArgumentError('Invalid mnemonic: $e');
      }

      final bip32 = Bip44.fromSeed(
        seedBytes,
        Bip44Coins.ripple,
      ).purpose.coin.account(0).change(Bip44Changes.chainExt).addressIndex(0);
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
    required String network,
    required String secret,
    required String fromAddress,
    required String destination,
    int? destinationTag,
    required String amountXrp,
    required XRPProvider rpc,
    String? expectedFeeDrops,
  }) async {
    final amountError = PaymentValidators.validateXrpAmount(amountXrp);
    if (amountError != null) {
      throw ArgumentError(amountError);
    }

    final drops = XRPHelper.xrpToDrop(amountXrp.trim());
    final amount = XRPAmount(drops);

    return _signAndSubmit(
      walletId: walletId,
      network: network,
      secret: secret,
      fromAddress: fromAddress,
      rpc: rpc,
      expectedFeeDrops: expectedFeeDrops,
      build: (pubHex) => Payment(
        amount: amount,
        destination: destination.trim(),
        destinationTag: destinationTag,
        account: fromAddress,
        signer: XRPLSignature.signer(pubHex),
      ),
    );
  }

  Future<PaymentSubmitResult> createXrpEscrow({
    required String walletId,
    required String network,
    required String secret,
    required String fromAddress,
    required String destination,
    required String amountXrp,
    required DateTime finishAfter,
    required DateTime cancelAfter,
    required XRPProvider rpc,
    String? expectedFeeDrops,
    int? destinationTag,
  }) async {
    final error = validateEscrowTimes(finishAfter, cancelAfter);
    if (error != null) throw ArgumentError(error);
    final amountError = PaymentValidators.validateXrpAmount(amountXrp);
    if (amountError != null) throw ArgumentError(amountError);
    return _signAndSubmit(
      walletId: walletId,
      network: network,
      secret: secret,
      fromAddress: fromAddress,
      rpc: rpc,
      expectedFeeDrops: expectedFeeDrops,
      build: (pubHex) => EscrowCreate(
        account: fromAddress,
        amount: XRPAmount(XRPHelper.xrpToDrop(amountXrp.trim())),
        destination: destination.trim(),
        destinationTag: destinationTag,
        finishAfterTime: finishAfter.toUtc(),
        cancelAfterTime: cancelAfter.toUtc(),
        signer: XRPLSignature.signer(pubHex),
      ),
    );
  }

  Future<PaymentSubmitResult> createXrpEscrowWithLedger({
    required String walletId,
    required String network,
    required String fromAddress,
    required String destination,
    required String amountXrp,
    required DateTime finishAfter,
    required DateTime cancelAfter,
    required XRPProvider rpc,
    required String publicKeyHex,
    required Future<String> Function(List<int> txBlob) signTransactionBlob,
    String? expectedFeeDrops,
    int? destinationTag,
  }) async {
    final error = validateEscrowTimes(finishAfter, cancelAfter);
    if (error != null) throw ArgumentError(error);
    final amountError = PaymentValidators.validateXrpAmount(amountXrp);
    if (amountError != null) throw ArgumentError(amountError);
    return signAndSubmitWithLedgerKeys(
      walletId: walletId,
      network: network,
      fromAddress: fromAddress,
      rpc: rpc,
      publicKeyHex: publicKeyHex,
      signTransactionBlob: signTransactionBlob,
      expectedFeeDrops: expectedFeeDrops,
      build: (pubHex) => EscrowCreate(
        account: fromAddress,
        amount: XRPAmount(XRPHelper.xrpToDrop(amountXrp.trim())),
        destination: destination.trim(),
        destinationTag: destinationTag,
        finishAfterTime: finishAfter.toUtc(),
        cancelAfterTime: cancelAfter.toUtc(),
        signer: XRPLSignature.signer(pubHex),
      ),
    );
  }

  static String? validateEscrowTimes(
    DateTime finishAfter,
    DateTime cancelAfter,
  ) {
    if (!finishAfter.isUtc || !cancelAfter.isUtc) {
      return 'Escrow times must include a UTC offset';
    }
    if (!finishAfter.isAfter(DateTime.now().toUtc())) {
      return 'FinishAfter must be in the future';
    }
    if (!cancelAfter.isAfter(finishAfter)) {
      return 'CancelAfter must be after FinishAfter';
    }
    return null;
  }

  /// Amount + fee + extra owner-reserve increment must fit in spendable XRP.
  static String? validateEscrowCreateSpendable({
    required String amountXrp,
    required BigInt balanceDrops,
    required BigInt currentReserveDrops,
    required BigInt reserveIncrementDrops,
    required String feeDrops,
    required bool destUnfunded,
    BigInt? accountReserveDrops,
  }) {
    final amountErr = PaymentValidators.validateXrpAmount(amountXrp);
    if (amountErr != null) return amountErr;
    final feeErr = PaymentValidators.validateFeeDrops(feeDrops);
    if (feeErr != null) return feeErr;
    final amount = BigInt.parse(XrpAmount.xrpToDrops(amountXrp.trim()));
    final fee = BigInt.parse(feeDrops.trim());
    final spendable = balanceDrops - currentReserveDrops;
    if (spendable < BigInt.zero) {
      return 'Account is below its XRP reserve';
    }
    if (amount + fee + reserveIncrementDrops > spendable) {
      return 'Amount plus network fee and extra owner reserve exceeds spendable XRP';
    }
    if (destUnfunded) {
      final reserve =
          accountReserveDrops ??
          BigInt.from(AppConfig.accountCreateReserveDrops);
      if (amount < reserve) {
        return 'Unfunded destination needs at least '
            '${XrpAmount.dropsToXrp(reserve.toString())} XRP';
      }
    }
    return null;
  }

  Future<PaymentSubmitResult> sendIou({
    required String walletId,
    required String network,
    required String secret,
    required String fromAddress,
    required String destination,
    int? destinationTag,
    required String currency,
    required String issuer,
    required String value,
    required XRPProvider rpc,
    String? expectedFeeDrops,
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
      walletId: walletId,
      network: network,
      secret: secret,
      fromAddress: fromAddress,
      rpc: rpc,
      expectedFeeDrops: expectedFeeDrops,
      build: (pubHex) => Payment(
        amount: amount,
        destination: destination.trim(),
        destinationTag: destinationTag,
        account: fromAddress,
        signer: XRPLSignature.signer(pubHex),
      ),
    );
  }

  /// Unsigned RLUSD TrustSet (NoRipple, official issuer for [network]).
  TrustSet buildRlusdTrustSet({
    required String fromAddress,
    required NetworkId network,
    required String publicKeyHex,
  }) {
    return TrustSet(
      account: fromAddress,
      limitAmount: IssuedCurrencyAmount(
        currency: Rlusd.currencyHex,
        issuer: Rlusd.issuerFor(network),
        value: Rlusd.limit,
      ),
      flags: [TrustSetFlag.tfSetNoRipple.id],
      signer: XRPLSignature.signer(publicKeyHex),
    );
  }

  Future<PaymentSubmitResult> setRlusdTrustLine({
    required String secret,
    required String fromAddress,
    required NetworkId network,
    required XRPProvider rpc,
  }) {
    return _signAndSubmit(
      secret: secret,
      fromAddress: fromAddress,
      rpc: rpc,
      build: (pubHex) => buildRlusdTrustSet(
        fromAddress: fromAddress,
        network: network,
        publicKeyHex: pubHex,
      ),
    );
  }

  Future<PaymentSubmitResult> setRlusdTrustLineWithLedger({
    required String fromAddress,
    required NetworkId network,
    required XRPProvider rpc,
    required String publicKeyHex,
    required Future<String> Function(List<int> txBlob) signTransactionBlob,
  }) {
    return signAndSubmitWithLedgerKeys(
      fromAddress: fromAddress,
      rpc: rpc,
      publicKeyHex: publicKeyHex,
      signTransactionBlob: signTransactionBlob,
      build: (pubHex) => buildRlusdTrustSet(
        fromAddress: fromAddress,
        network: network,
        publicKeyHex: pubHex,
      ),
    );
  }

  Future<PaymentSubmitResult> sendXrpWithLedger({
    String? walletId,
    String network = 'unknown',
    required String fromAddress,
    required String destination,
    int? destinationTag,
    required String amountXrp,
    required XRPProvider rpc,
    required String publicKeyHex,
    required Future<String> Function(List<int> txBlob) signTransactionBlob,
    String? expectedFeeDrops,
  }) async {
    final amountError = PaymentValidators.validateXrpAmount(amountXrp);
    if (amountError != null) throw ArgumentError(amountError);
    final drops = XRPHelper.xrpToDrop(amountXrp.trim());
    return signAndSubmitWithLedgerKeys(
      walletId: walletId,
      network: network,
      fromAddress: fromAddress,
      rpc: rpc,
      publicKeyHex: publicKeyHex,
      signTransactionBlob: signTransactionBlob,
      expectedFeeDrops: expectedFeeDrops,
      build: (pubHex) => Payment(
        amount: XRPAmount(drops),
        destination: destination.trim(),
        destinationTag: destinationTag,
        account: fromAddress,
        signer: XRPLSignature.signer(pubHex),
      ),
    );
  }

  Future<PaymentSubmitResult> sendIouWithLedger({
    String? walletId,
    String network = 'unknown',
    required String fromAddress,
    required String destination,
    int? destinationTag,
    required String currency,
    required String issuer,
    required String value,
    required XRPProvider rpc,
    required String publicKeyHex,
    required Future<String> Function(List<int> txBlob) signTransactionBlob,
    String? expectedFeeDrops,
  }) async {
    final amountError = PaymentValidators.validateIouAmount(value);
    if (amountError != null) throw ArgumentError(amountError);
    return signAndSubmitWithLedgerKeys(
      walletId: walletId,
      network: network,
      fromAddress: fromAddress,
      rpc: rpc,
      publicKeyHex: publicKeyHex,
      signTransactionBlob: signTransactionBlob,
      expectedFeeDrops: expectedFeeDrops,
      build: (pubHex) => Payment(
        amount: IssuedCurrencyAmount(
          value: value.trim(),
          currency: currency.trim(),
          issuer: issuer.trim(),
        ),
        destination: destination.trim(),
        destinationTag: destinationTag,
        account: fromAddress,
        signer: XRPLSignature.signer(pubHex),
      ),
    );
  }

  /// Sign a prepared transaction with Ledger public key + device signature
  /// (no private key on phone).
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
    String? walletId,
    String network = 'unknown',
    required String fromAddress,
    required XRPProvider rpc,
    required String publicKeyHex,
    required Future<String> Function(List<int> txBlob) signTransactionBlob,
    required SubmittableTransaction Function(String pubHex) build,
    String? expectedFeeDrops,
  }) async {
    final pub = XRPPublicKey.fromHex(publicKeyHex);
    final derived = pub.toClassicAddress().address;
    if (derived != fromAddress) {
      throw StateError(
        'Ledger address $derived does not match this wallet ($fromAddress). '
        'Check the account index or uncheck Ledger Device.',
      );
    }

    final transaction = build(publicKeyHex);

    await XRPHelper.autoFill(rpc, transaction);
    final feeDrops = transaction.fee?.toString();
    final feeError = expectedFeeDrops == null
        ? PaymentValidators.validateFeeDrops(feeDrops)
        : PaymentValidators.reviewedFeeMatches(
            reviewedDrops: expectedFeeDrops,
            actualDrops: feeDrops,
          );
    if (feeError != null) throw ArgumentError(feeError);

    // Ledger XRP app expects the serialized transaction STObject, not the
    // STX\0-prefixed software signing digest.
    final txBlob = transaction.toTransactionBlobBytes();
    final sigHex = await signTransactionBlob(txBlob);
    transaction.setSignature(XRPLSignature.sign(publicKeyHex, sigHex));

    final trBlob = transaction.toTransactionBlob();
    final txHash = transaction.getHash();
    final pendingId = walletId == null ? null : '$walletId:$txHash';
    if (pendingId != null && database != null) {
      await database!.insertPendingPayment(
        PendingPaymentsCompanion.insert(
          id: pendingId,
          walletId: walletId!,
          network: network,
          txHash: txHash,
          signedBlob: base64Encode(utf8.encode(trBlob)),
          lastLedgerSequence: Value(transaction.lastLedgerSequence),
          status: 'submitted',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    }
    final PaymentSubmitResult result;
    try {
      final response = await rpc.request(XRPRequestSubmit(txBlob: trBlob));
      result = PaymentSubmitResult(
        hash: response.txJson.hash ?? txHash,
        engineResult: response.engineResult,
        engineResultMessage: response.engineResultMessage,
        isSuccess: response.isSuccess,
        feeDrops: feeDrops,
        lastLedgerSequence: transaction.lastLedgerSequence,
      );
    } on TimeoutException {
      throw const PaymentOperationException('submit timeout');
    } catch (_) {
      throw const PaymentOperationException('submit transport');
    }

    if (pendingId != null && database != null) {
      await database!.updatePendingPayment(
        pendingId,
        status: result.isSuccess ? 'submitted' : 'failed',
        lastError: result.isSuccess ? null : result.engineResult,
      );
    }

    return result;
  }

  Future<PaymentSubmitResult> _signAndSubmit({
    String? walletId,
    String network = 'unknown',
    required String secret,
    required String fromAddress,
    required XRPProvider rpc,
    required SubmittableTransaction Function(String pubHex) build,
    String? expectedFeeDrops,
  }) async {
    // Local-only key material; not stored or logged.
    final XRPPrivateKey privateKey;
    try {
      privateKey = privateKeyFromSecret(secret, expectedAddress: fromAddress);
    } catch (_) {
      throw const PaymentOperationException('key reconstruction');
    }
    final publicKey = privateKey.getPublic();
    final signerAddress = publicKey.toClassicAddress();
    final pubHex = publicKey.toHex();
    final transaction = build(pubHex);

    try {
      await XRPHelper.autoFill(rpc, transaction);
    } catch (_) {
      throw const PaymentOperationException('autofill');
    }
    final feeDrops = transaction.fee?.toString();
    final feeError = expectedFeeDrops == null
        ? PaymentValidators.validateFeeDrops(feeDrops)
        : PaymentValidators.reviewedFeeMatches(
            reviewedDrops: expectedFeeDrops,
            actualDrops: feeDrops,
          );
    if (feeError != null) throw ArgumentError(feeError);

    try {
      final blob = transaction.toSigningBlobBytes(signerAddress);
      final sig = privateKey.sign(blob);
      transaction.setSignature(sig);
    } catch (_) {
      throw const PaymentOperationException('signing');
    }

    final PaymentSubmitResult result;
    String? pendingId;
    try {
      final trBlob = transaction.toTransactionBlob();
      final txHash = transaction.getHash();
      pendingId = walletId == null ? null : '$walletId:$txHash';
      if (pendingId != null && database != null) {
        await database!.insertPendingPayment(
          PendingPaymentsCompanion.insert(
            id: pendingId,
            walletId: walletId!,
            network: network,
            txHash: txHash,
            signedBlob: base64Encode(utf8.encode(trBlob)),
            lastLedgerSequence: Value(transaction.lastLedgerSequence),
            status: 'submitted',
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
      }
      final response = await rpc.request(XRPRequestSubmit(txBlob: trBlob));
      result = PaymentSubmitResult(
        hash: response.txJson.hash ?? txHash,
        engineResult: response.engineResult,
        engineResultMessage: response.engineResultMessage,
        isSuccess: response.isSuccess,
        feeDrops: feeDrops,
        lastLedgerSequence: transaction.lastLedgerSequence,
      );
      if (pendingId != null && database != null) {
        await database!.updatePendingPayment(
          pendingId,
          status: result.isSuccess ? 'submitted' : 'failed',
          lastError: result.isSuccess ? null : result.engineResult,
        );
      }
    } on BaseXRPLPluginException {
      rethrow;
    } on RPCError {
      rethrow;
    } on TimeoutException {
      throw const PaymentOperationException('submit timeout');
    } on FormatException {
      throw const PaymentOperationException('submit response parsing');
    } catch (_) {
      throw const PaymentOperationException('submit transport');
    }

    return result;
  }
}
