import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/data/watcher/address_book.dart';
import 'package:xrpl_mobile_wallet/data/watcher/tx_notification_parser.dart';

void main() {
  group('WatcherAddressBook', () {
    test('round-trips JSON with public fields only', () {
      const book = WatcherAddressBook(
        network: 'testnet',
        wss: 'wss://s.altnet.rippletest.net:51233',
        enabled: true,
        accounts: [
          WatcherAccountEntry(address: 'rN7n7otQDd6FczFgLdSqtcsAUxDkw6fzRH', label: 'Cold'),
        ],
      );
      final decoded = WatcherAddressBook.fromJson(book.toJson());
      expect(decoded.network, 'testnet');
      expect(decoded.wss, book.wss);
      expect(decoded.enabled, isTrue);
      expect(decoded.accounts, hasLength(1));
      expect(decoded.accounts.first.address, startsWith('rN7n'));
      expect(decoded.accounts.first.label, 'Cold');
      // Guard: JSON must never grow secret-like keys.
      expect(book.toJson().keys, containsAll(['network', 'wss', 'enabled', 'accounts']));
      expect(book.toJson().containsKey('secret'), isFalse);
      expect(book.toJson().containsKey('seed'), isFalse);
      expect(book.toJson().containsKey('mnemonic'), isFalse);
    });

    test('shouldRun requires enabled + accounts', () {
      expect(WatcherAddressBook.empty.shouldRun, isFalse);
      expect(
        const WatcherAddressBook(
          network: 'mainnet',
          wss: 'wss://xrplcluster.com',
          enabled: true,
          accounts: [
            WatcherAccountEntry(address: 'rAAA', label: 'A'),
          ],
        ).shouldRun,
        isTrue,
      );
      expect(
        const WatcherAddressBook(
          network: 'mainnet',
          wss: 'wss://xrplcluster.com',
          enabled: false,
          accounts: [
            WatcherAccountEntry(address: 'rAAA', label: 'A'),
          ],
        ).shouldRun,
        isFalse,
      );
    });

    test('defaults enabled true when missing from JSON', () {
      final book = WatcherAddressBook.fromJson({
        'network': 'mainnet',
        'wss': 'wss://xrplcluster.com',
        'accounts': [],
      });
      expect(book.enabled, isTrue);
    });
  });

  group('TxNotificationParser', () {
    test('parses transaction stream message with drops amount', () {
      final event = TxNotificationParser.parseMessage({
        'type': 'transaction',
        'validated': true,
        'transaction': {
          'Account': 'rSender',
          'Destination': 'rDest',
          'TransactionType': 'Payment',
          'Amount': '1500000',
          'hash': 'ABC123',
        },
      });
      expect(event, isNotNull);
      expect(event!.hash, 'ABC123');
      expect(event.transactionType, 'Payment');
      expect(event.account, 'rSender');
      expect(event.destination, 'rDest');
      expect(event.amountSummary, '1.5 XRP');
    });

    test('parses tx_json shape and issued currency amount', () {
      final event = TxNotificationParser.parseMessage({
        'tx_json': {
          'Account': 'rIssuer',
          'Destination': 'rUser',
          'TransactionType': 'Payment',
          'Amount': {
            'currency': 'USD',
            'value': '12.5',
            'issuer': 'rIssuer',
          },
          'hash': 'DEF456',
        },
        'validated': true,
      });
      expect(event, isNotNull);
      expect(event!.amountSummary, '12.5 USD');
      expect(event.hash, 'DEF456');
    });

    test('returns null for non-tx messages', () {
      expect(
        TxNotificationParser.parseMessage({
          'type': 'ledgerClosed',
          'ledger_index': 1,
        }),
        isNull,
      );
      expect(
        TxNotificationParser.parseMessage({
          'id': 1,
          'status': 'success',
          'type': 'response',
          'result': {},
        }),
        isNull,
      );
    });

    test('notification copy uses label and direction', () {
      const book = WatcherAddressBook(
        network: 'mainnet',
        wss: 'wss://xrplcluster.com',
        enabled: true,
        accounts: [
          WatcherAccountEntry(address: 'rDest', label: 'Cold'),
        ],
      );
      const event = WatcherTxEvent(
        hash: 'H1',
        transactionType: 'Payment',
        account: 'rSender',
        destination: 'rDest',
        amountSummary: '1 XRP',
      );
      final copy = TxNotificationParser.notificationCopy(
        event: event,
        book: book,
      );
      expect(copy.title, 'Cold');
      expect(copy.body, contains('Received'));
      expect(copy.body, contains('Payment'));
      expect(copy.body, contains('1 XRP'));
    });
  });
}
