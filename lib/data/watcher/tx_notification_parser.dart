import 'package:xrpl_mobile_wallet/domain/amount/xrp_amount.dart';
import 'package:xrpl_mobile_wallet/data/watcher/address_book.dart';
import 'package:xrpl_mobile_wallet/domain/tokens/currency_display.dart';

/// Parsed XRPL stream transaction suitable for a local notification.
class WatcherTxEvent {
  const WatcherTxEvent({
    required this.hash,
    required this.transactionType,
    required this.account,
    this.destination,
    this.amountSummary,
    this.validated = true,
  });

  final String hash;
  final String transactionType;
  final String account;
  final String? destination;
  final String? amountSummary;
  final bool validated;
}

/// Pure helpers for XRPL WebSocket transaction messages.
///
/// Kept free of Flutter plugins so unit tests can run without platform channels.
class TxNotificationParser {
  TxNotificationParser._();

  /// Extract a [WatcherTxEvent] from a flexible stream payload.
  ///
  /// Accepts both `transaction` and `tx_json` shapes, and ignores non-tx
  /// messages (subscribe responses, ledger closed, etc.).
  static WatcherTxEvent? parseMessage(Map<String, dynamic> message) {
    final type = message['type']?.toString();
    // Stream txs are usually type=transaction; some nodes omit type.
    final txNode = _asMap(message['transaction']) ??
        _asMap(message['tx_json']) ??
        _asMap(message['tx']);
    if (txNode == null) return null;
    if (type != null &&
        type != 'transaction' &&
        type != 'response' &&
        message['transaction'] == null &&
        message['tx_json'] == null) {
      return null;
    }

    final hash = txNode['hash']?.toString() ??
        message['hash']?.toString() ??
        _asMap(message['meta'])?['TransactionHash']?.toString();
    if (hash == null || hash.isEmpty) return null;

    final txType = txNode['TransactionType']?.toString() ?? 'Unknown';
    final account = txNode['Account']?.toString() ?? '';
    final destination = txNode['Destination']?.toString();
    final amountSummary = formatAmountField(txNode['Amount']);
    final validated = message['validated'] is bool
        ? message['validated'] as bool
        : true;

    return WatcherTxEvent(
      hash: hash,
      transactionType: txType,
      account: account,
      destination: destination,
      amountSummary: amountSummary,
      validated: validated,
    );
  }

  /// Format XRPL Amount (drops string or issued currency map) for display.
  static String? formatAmountField(Object? amount) {
    if (amount == null) return null;
    if (amount is String) {
      try {
        return '${XrpAmount.dropsToXrp(amount)} XRP';
      } catch (_) {
        return amount;
      }
    }
    if (amount is Map) {
      final value = amount['value']?.toString();
      final currency = amount['currency']?.toString() ?? '';
      final issuer = amount['issuer']?.toString();
      if (value == null) return null;
      if (currency.isEmpty) return value;
      final symbol = CurrencyDisplay.symbol(currency, issuer: issuer);
      return '$value $symbol';
    }
    return amount.toString();
  }

  /// Pick the watched account this tx most likely concerns.
  static WatcherAccountEntry? matchWatchedAccount(
    WatcherTxEvent event,
    List<WatcherAccountEntry> accounts,
  ) {
    final watched = {
      for (final a in accounts) a.address: a,
    };
    if (event.destination != null && watched.containsKey(event.destination)) {
      return watched[event.destination!];
    }
    if (watched.containsKey(event.account)) {
      return watched[event.account];
    }
    return null;
  }

  /// Build notification title/body for a validated tx involving a watched account.
  static ({String title, String body}) notificationCopy({
    required WatcherTxEvent event,
    required WatcherAddressBook book,
  }) {
    final matched = matchWatchedAccount(event, book.accounts);
    final title = matched != null
        ? (matched.label.isNotEmpty
            ? matched.label
            : WatcherAddressBook.empty.labelFor(matched.address))
        : book.labelFor(
            event.destination ?? event.account,
          );

    final parts = <String>[event.transactionType];
    if (event.amountSummary != null && event.amountSummary!.isNotEmpty) {
      parts.add(event.amountSummary!);
    }
    final direction = _directionHint(event, book);
    final body = direction == null
        ? parts.join(' · ')
        : '$direction · ${parts.join(' · ')}';

    return (title: title, body: body);
  }

  static String? _directionHint(
    WatcherTxEvent event,
    WatcherAddressBook book,
  ) {
    final watched = book.accounts.map((a) => a.address).toSet();
    final isDest =
        event.destination != null && watched.contains(event.destination);
    final isSrc = watched.contains(event.account);
    if (isDest && !isSrc) return 'Received';
    if (isSrc && !isDest) return 'Sent';
    return null;
  }

  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }
}
