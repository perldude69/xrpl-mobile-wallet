import 'package:drift/drift.dart';

class Wallets extends Table {
  TextColumn get id => text()();
  TextColumn get label => text()();
  TextColumn get address => text()();
  TextColumn get kind => text()(); // signing | watchOnly
  TextColumn get preferredNetwork => text()(); // mainnet | testnet
  TextColumn get importMethod => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Optional ARGB accent; null = derive from address.
  IntColumn get accentColor => integer().nullable()();

  /// When true, Send uses a connected Ledger (no seed on phone).
  BoolColumn get useLedger => boolean().withDefault(const Constant(false))();

  /// BIP44 account index for Ledger path m/44'/144'/index'/0/0.
  IntColumn get ledgerAccountIndex =>
      integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Balance rows keyed by (walletId, currency, issuer).
///
/// [issuer] is non-null with empty-string default so it can participate in the
/// composite primary key (Drift does not allow nullable PK columns). Use '' for
/// native XRP / no issuer.
class Balances extends Table {
  TextColumn get walletId => text()();
  TextColumn get currency => text()();
  TextColumn get issuer => text().withDefault(const Constant(''))();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {walletId, currency, issuer};
}

class CachedTxs extends Table {
  TextColumn get hash => text()();
  TextColumn get walletId => text()();
  IntColumn get ledgerIndex => integer().nullable()();
  TextColumn get txType => text()();
  TextColumn get direction => text()(); // in | out | self | other
  TextColumn get amountSummary => text()();
  TextColumn get counterpart => text().nullable()();
  DateTimeColumn get date => dateTime()();

  @override
  Set<Column> get primaryKey => {hash, walletId};
}

/// One order the user placed (market or resting limit).
///
/// Public trade metadata only — never secrets. [status] stores a
/// `TradeStatus` **name**; [lastError] stores a fixed category slug, never raw
/// exception text (XRW-28).
class TradeExecutions extends Table {
  TextColumn get id => text()();
  TextColumn get walletId => text()();
  TextColumn get network => text()();

  /// `buy` or `sell`, read as "…the base asset".
  TextColumn get side => text()();

  /// Asset given up. Issuer is null for XRP.
  TextColumn get baseCurrency => text()();
  TextColumn get baseIssuer => text().nullable()();

  /// Asset wanted. Issuer is null for XRP.
  TextColumn get quoteCurrency => text()();
  TextColumn get quoteIssuer => text().nullable()();

  TextColumn get targetAmount => text()();

  /// Sum of `TradeFills.filledBase`, maintained by the reconciler from
  /// validated ledger metadata — never by client-side subtraction.
  TextColumn get filledAmount => text().withDefault(const Constant('0'))();

  /// `market` (IOC/FOK) or `limit` (resting).
  TextColumn get orderType => text()();

  TextColumn get status => text()();
  TextColumn get lastError => text().nullable()();

  /// Hash of the submitted OfferCreate, once known.
  TextColumn get txHash => text().nullable()();

  /// Sequence of the resting offer this order created, for OfferCancel and
  /// for matching `account_offers`.
  IntColumn get offerSequence => integer().nullable()();

  /// `LastLedgerSequence` of the submitted transaction. Past this ledger with
  /// no validated result ⇒ definitively failed, safe to retry.
  IntColumn get lastLedgerSequence => integer().nullable()();

  /// Ledger index the reconciler last checked against.
  IntColumn get lastLedgerIndex => integer().nullable()();

  /// Optional XRPL `Expiration` on a resting offer.
  DateTimeColumn get expiration => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One validated fill against a [TradeExecutions] row.
///
/// A resting offer is partially filled by many *later* taker transactions in
/// different ledgers, so one execution has N fills. Rows are written only from
/// validated transaction metadata.
class TradeFills extends Table {
  TextColumn get executionId => text()();
  TextColumn get txHash => text()();
  IntColumn get ledgerIndex => integer()();

  /// Amounts actually exchanged in this fill, as ledger-reported strings.
  TextColumn get filledBase => text()();
  TextColumn get filledQuote => text()();

  /// Executed rate for this fill (quote per base), as a decimal string.
  TextColumn get rate => text()();

  TextColumn get feeDrops => text().nullable()();
  DateTimeColumn get date => dateTime()();

  @override
  Set<Column> get primaryKey => {executionId, txHash};
}

/// A payment whose submission outcome is not yet final.
///
/// The signed blob is required to identify and recover a transaction after a
/// transport failure. It contains no private key material.
class PendingPayments extends Table {
  TextColumn get id => text()();
  TextColumn get walletId => text()();
  TextColumn get network => text()();
  TextColumn get txHash => text()();
  TextColumn get signedBlob => text()();
  IntColumn get lastLedgerSequence => integer().nullable()();
  TextColumn get status => text()(); // submitted | validated | failed | expired
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class AppSettingsRows extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
