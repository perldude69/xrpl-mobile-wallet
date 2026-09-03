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
  BoolColumn get useLedger =>
      boolean().withDefault(const Constant(false))();
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

class AppSettingsRows extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
