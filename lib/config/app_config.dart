/// App-wide non-secret knobs (PIN policy, auto-lock, notification channels).
class AppConfig {
  static const pinMinLength = 6;
  static const autoLockSeconds = 90;

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
