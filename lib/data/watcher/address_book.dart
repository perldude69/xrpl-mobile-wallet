import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:xrpl_mobile_wallet/config/network_id.dart';
import 'package:xrpl_mobile_wallet/config/storage_keys.dart';

/// A single public account entry for the background watcher.
///
/// **Never** includes secrets or key material — address + label only.
class WatcherAccountEntry {
  const WatcherAccountEntry({
    required this.address,
    required this.label,
  });

  final String address;
  final String label;

  Map<String, dynamic> toJson() => {
        'address': address,
        'label': label,
      };

  factory WatcherAccountEntry.fromJson(Map<String, dynamic> json) {
    return WatcherAccountEntry(
      address: json['address']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
    );
  }
}

/// Public-only address book written by the UI and read by the FGS isolate.
class WatcherAddressBook {
  const WatcherAddressBook({
    required this.network,
    required this.wss,
    required this.enabled,
    required this.accounts,
  });

  final String network;
  final String wss;
  final bool enabled;
  final List<WatcherAccountEntry> accounts;

  static const empty = WatcherAddressBook(
    network: 'mainnet',
    wss: 'wss://xrplcluster.com',
    enabled: true,
    accounts: [],
  );

  bool get shouldRun => enabled && accounts.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'network': network,
        'wss': wss,
        'enabled': enabled,
        'accounts': accounts.map((a) => a.toJson()).toList(),
      };

  factory WatcherAddressBook.fromJson(Map<String, dynamic> json) {
    final rawAccounts = json['accounts'];
    final accounts = <WatcherAccountEntry>[];
    if (rawAccounts is List) {
      for (final item in rawAccounts) {
        if (item is Map<String, dynamic>) {
          final entry = WatcherAccountEntry.fromJson(item);
          if (entry.address.isNotEmpty) accounts.add(entry);
        } else if (item is Map) {
          final entry = WatcherAccountEntry.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (entry.address.isNotEmpty) accounts.add(entry);
        }
      }
    }
    return WatcherAddressBook(
      network: json['network']?.toString() ?? 'mainnet',
      wss: json['wss']?.toString() ?? NetworkId.mainnet.defaultWss,
      enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
      accounts: accounts,
    );
  }

  WatcherAddressBook copyWith({
    String? network,
    String? wss,
    bool? enabled,
    List<WatcherAccountEntry>? accounts,
  }) {
    return WatcherAddressBook(
      network: network ?? this.network,
      wss: wss ?? this.wss,
      enabled: enabled ?? this.enabled,
      accounts: accounts ?? this.accounts,
    );
  }

  /// Resolve a display label for [address], or a shortened classic address.
  String labelFor(String address) {
    for (final a in accounts) {
      if (a.address == address) {
        return a.label.isNotEmpty ? a.label : _shortAddress(address);
      }
    }
    return _shortAddress(address);
  }

  static String _shortAddress(String address) {
    if (address.length <= 12) return address;
    return '${address.substring(0, 6)}…${address.substring(address.length - 4)}';
  }
}

/// Read/write helpers for [StorageKeys.watcherAddressBookFile].
class WatcherAddressBookStore {
  WatcherAddressBookStore();

  Future<String> filePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, StorageKeys.watcherAddressBookFile);
  }

  Future<WatcherAddressBook> load() async {
    try {
      final path = await filePath();
      final file = File(path);
      if (!await file.exists()) return WatcherAddressBook.empty;
      final text = await file.readAsString();
      if (text.trim().isEmpty) return WatcherAddressBook.empty;
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        return WatcherAddressBook.fromJson(decoded);
      }
      if (decoded is Map) {
        return WatcherAddressBook.fromJson(Map<String, dynamic>.from(decoded));
      }
      return WatcherAddressBook.empty;
    } catch (_) {
      return WatcherAddressBook.empty;
    }
  }

  Future<void> save(WatcherAddressBook book) async {
    final path = await filePath();
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(book.toJson()),
      flush: true,
    );
  }

  /// Remove the public address book file (used by full wipe).
  Future<void> clear() async {
    try {
      final path = await filePath();
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
