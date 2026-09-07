import 'package:xrpl_mobile_wallet/data/secure/key_names.dart';

/// Prefs and secure-storage *names*. Values are never secrets in this file.
///
/// Sensitive secure-storage names (PIN verifiers, wallet secrets) are derived
/// at runtime by [KeyNames] so the release snapshot carries no structured
/// literals (XRW-23). Non-sensitive SharedPreferences keys stay as plain
/// constants (they hold public data only).
///
/// Changing a sensitive name makes existing entries unreachable — re-import
/// or wipe instead of renaming casually.
class StorageKeys {
  static String get pinHash => KeyNames.pinHash;
  static String get pinSalt => KeyNames.pinSalt;

  /// Optional second PIN: unlock screen opens Zerpland instead of the wallet.
  static String get gamePinHash => KeyNames.gamePinHash;
  static String get gamePinSalt => KeyNames.gamePinSalt;
  static String get pinKdf => KeyNames.pinKdf;

  static const activeNetwork = 'active_network';
  static const watcherEnabled = 'watcher_enabled';

  /// Comma-separated mainnet HTTP RPC endpoint ids (see [EndpointPreferences]).
  static const mainnetHttpEndpointIds = 'mainnet_http_endpoint_ids';

  /// Comma-separated mainnet WSS endpoint ids (see [EndpointPreferences]).
  static const mainnetWssEndpointIds = 'mainnet_wss_endpoint_ids';

  /// JSON array of user-defined mainnet nodes (public URLs, including optional
  /// query tokens the user pasted — stored on-device, never committed).
  static const customEndpointsJson = 'custom_endpoints_json';

  /// Public address book shared with the background watcher (no secrets).
  static const watcherAddressBookFile = 'watcher_address_book.json';

  /// Watcher isolate → UI heartbeat (SharedPreferences; public, no secrets).
  static const watcherStatus = 'watcher_wss_status';
  static const watcherHost = 'watcher_wss_host';
  static const watcherUpdatedAt = 'watcher_wss_updated_at_ms';

  /// Last known XRP→USD rate (string double) + timestamp.
  static const xrpUsdRate = 'xrp_usd_rate';
  static const xrpUsdRateAt = 'xrp_usd_rate_at_ms';

  /// Portfolio display unit: `xrp` | `usd`.
  static const displayFiat = 'portfolio_display_fiat';
}
