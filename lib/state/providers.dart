import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xrpl_mobile_wallet/data/database/app_database.dart';
import 'package:xrpl_mobile_wallet/data/secure/key_vault.dart';
import 'package:xrpl_mobile_wallet/data/secure/pin_service.dart';
import 'package:xrpl_mobile_wallet/data/watcher/account_watcher.dart';

export 'package:xrpl_mobile_wallet/state/network_controller.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final pinServiceProvider = Provider((ref) => PinService());
final keyVaultProvider = Provider((ref) => KeyVault());

final accountWatcherProvider = Provider<AccountWatcher>((ref) => AccountWatcher());