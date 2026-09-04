/// App-wide non-secret knobs (PIN policy, auto-lock, notification channels).
class AppConfig {
  static const pinMinLength = 6;
  static const autoLockSeconds = 90;

  /// PBKDF2-SHA256 iterations for the PIN verifier (same family as export).
  static const pinPbkdf2Iterations = 120000;

  /// Refuse to sign if autoFill fee exceeds this (drops). 0.1 XRP.
  static const maxFeeDrops = 100000;

  /// Default XRPL account-create reserve (drops). Used when destination is unfunded.
  static const accountCreateReserveDrops = 1000000;

  /// Sticky FGS status channel (low importance).
  static const watcherStatusChannelId = 'watcher_status';
  static const watcherStatusChannelName = 'XRPL Watcher status';
  static const watcherStatusNotificationId = 888;

  /// Transaction alert channel (high importance).
  static const walletActivityChannelId = 'wallet_activity';
  static const walletActivityChannelName = 'Wallet activity';

  /// XRPL-Labs TrustSet price oracle (XRP/USD aggregate in LimitAmount).
  static const xrpUsdOracleAddress = 'rXUMMaPpZqPutoRszR29jtC8amWq3APkx';

  /// Developer coffee tip: Settings mug sends XRP here (mainnet classic address).
  static const coffeeAddress = 'rJTyAxvqh9UcigEfK2CTAd3ipUEvchDNzr';
}
