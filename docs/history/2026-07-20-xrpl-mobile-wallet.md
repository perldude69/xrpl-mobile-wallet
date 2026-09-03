# XRPL Mobile Wallet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a personal Android-first Flutter XRPL wallet that imports signing keys or watch-only addresses, shows XRP/IOU balances and history, sends payments, and notifies on account activity via a foreground service.

**Architecture:** Local-first Flutter app using `xrpl_dart` for ledger I/O and signing. Secrets stay in `flutter_secure_storage` (UI process only). Non-secret metadata in SQLite. An Android foreground service holds public addresses only and WebSocket-subscribes for local notifications.

**Tech Stack:** Flutter 3.x / Dart 3.x, `xrpl_dart`, `blockchain_utils`, `flutter_secure_storage`, `local_auth`, `drift` + `sqlite3_flutter_libs`, `flutter_riverpod`, `flutter_local_notifications`, `qr_flutter`, Material 3.

**Spec:** `docs/design/2026-07-20-xrpl-mobile-wallet-design.md`

**Project root:** `/home/jim/xrpl-mobile-wallet`

---

## File Structure (target)

```
xrpl-mobile-wallet/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── core/
│   │   ├── constants.dart          # network URLs, timeouts
│   │   ├── theme.dart
│   │   └── errors.dart
│   ├── domain/
│   │   ├── models/
│   │   │   ├── wallet_account.dart
│   │   │   ├── balance.dart
│   │   │   ├── cached_tx.dart
│   │   │   └── network_id.dart
│   │   └── validation/
│   │       ├── address_validator.dart
│   │       └── secret_validator.dart
│   ├── data/
│   │   ├── secure/
│   │   │   ├── key_vault.dart
│   │   │   └── pin_service.dart
│   │   ├── db/
│   │   │   ├── app_database.dart
│   │   │   ├── tables.dart
│   │   │   └── wallet_dao.dart
│   │   ├── ledger/
│   │   │   ├── ledger_client.dart
│   │   │   └── amount_format.dart
│   │   ├── tx/
│   │   │   └── payment_service.dart
│   │   └── watcher/
│   │       └── watcher_bridge.dart
│   ├── state/
│   │   ├── providers.dart
│   │   ├── lock_controller.dart
│   │   └── wallet_list_controller.dart
│   └── ui/
│       ├── shell/main_shell.dart
│       ├── lock/setup_pin_screen.dart
│       ├── lock/unlock_screen.dart
│       ├── wallets/wallet_list_screen.dart
│       ├── wallets/wallet_detail_screen.dart
│       ├── wallets/import_screen.dart
│       ├── wallets/receive_screen.dart
│       ├── send/send_screen.dart
│       ├── activity/activity_screen.dart
│       └── settings/settings_screen.dart
├── android/
│   └── app/src/main/kotlin/.../watcher/  # FGS (Task 7)
├── test/
│   ├── domain/validation_test.dart
│   ├── data/amount_format_test.dart
│   └── data/pin_service_test.dart
└── docs/superpowers/...
```

---

### Task 1: Flutter project scaffold

**Files:**
- Create: entire Flutter project under `/home/jim/xrpl-mobile-wallet` (merge with existing `docs/`)
- Create: `lib/main.dart`, `lib/app.dart`, `lib/core/theme.dart`, `lib/core/constants.dart`
- Create: `lib/ui/shell/main_shell.dart`
- Modify: `pubspec.yaml`

- [ ] **Step 1: Create Flutter project without overwriting docs**

```bash
cd /home/jim
# If only docs exist, create in temp and merge
flutter create --org com.jim.xrpl --project-name xrpl_mobile_wallet /tmp/xrpl_mobile_wallet_scaffold
rsync -a --ignore-existing /tmp/xrpl_mobile_wallet_scaffold/ /home/jim/xrpl-mobile-wallet/
# Ensure docs/ from design remain
ls /home/jim/xrpl-mobile-wallet/docs/superpowers/specs/
cd /home/jim/xrpl-mobile-wallet
git init
git add docs
git commit -m "docs: add XRPL mobile wallet design and plan"
```

Expected: `lib/main.dart` exists; docs still present.

- [ ] **Step 2: Add dependencies to `pubspec.yaml`**

Under `dependencies:` add (use latest compatible versions from pub.dev at implement time):

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  xrpl_dart: ^7.5.0
  blockchain_utils: ^5.0.0   # align with xrpl_dart's constraint
  flutter_secure_storage: ^9.2.4
  local_auth: ^2.3.0
  drift: ^2.22.0
  sqlite3_flutter_libs: ^0.5.28
  path_provider: ^2.1.5
  path: ^1.9.0
  flutter_riverpod: ^2.6.1
  flutter_local_notifications: ^18.0.1
  qr_flutter: ^4.1.0
  uuid: ^4.5.1
  crypto: ^3.0.6
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  drift_dev: ^2.22.0
  build_runner: ^2.4.14
```

Run:

```bash
cd /home/jim/xrpl-mobile-wallet && flutter pub get
```

Expected: exit 0. If `blockchain_utils` version conflicts with `xrpl_dart`, use the version required by `xrpl_dart` (check `pubspec.lock` / resolver errors).

- [ ] **Step 3: Write `lib/core/constants.dart`**

```dart
enum NetworkId { mainnet, testnet }

extension NetworkIdX on NetworkId {
  String get label => switch (this) {
        NetworkId.mainnet => 'Mainnet',
        NetworkId.testnet => 'Testnet',
      };

  /// Public cluster WebSocket endpoints (override later in settings if needed).
  String get defaultWss => switch (this) {
        NetworkId.mainnet => 'wss://xrplcluster.com',
        NetworkId.testnet => 'wss://s.altnet.rippletest.net:51233',
      };
}

class AppConstants {
  static const pinMinLength = 6;
  static const autoLockSeconds = 90;
  static const secureStoragePinKey = 'app_pin_hash';
  static const secureStoragePinSaltKey = 'app_pin_salt';
  static const prefsActiveNetworkKey = 'active_network';
  static const prefsWatcherEnabledKey = 'watcher_enabled';
}
```

- [ ] **Step 4: Write `lib/core/theme.dart` and shell UI**

```dart
// lib/core/theme.dart
import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const seed = Color(0xFF00A3BF); // XRPL-adjacent teal
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ),
    appBarTheme: const AppBarTheme(centerTitle: false),
  );
}
```

```dart
// lib/ui/shell/main_shell.dart
import 'package:flutter/material.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _titles = ['Wallets', 'Activity', 'Settings'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: IndexedStack(
        index: _index,
        children: const [
          Center(child: Text('Wallets — coming soon')),
          Center(child: Text('Activity — coming soon')),
          Center(child: Text('Settings — coming soon')),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Wallets'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Activity'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
```

```dart
// lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'ui/shell/main_shell.dart';

class XrplWalletApp extends StatelessWidget {
  const XrplWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'XRPL Wallet',
        theme: buildAppTheme(),
        home: const MainShell(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
```

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const XrplWalletApp());
}
```

- [ ] **Step 5: Verify analyze and tests**

```bash
cd /home/jim/xrpl-mobile-wallet
flutter analyze
flutter test
```

Expected: no errors (fix or update default `widget_test.dart` to pump `XrplWalletApp`).

Update `test/widget_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/app.dart';

void main() {
  testWidgets('shell shows Wallets tab', (tester) async {
    await tester.pumpWidget(const XrplWalletApp());
    expect(find.text('Wallets'), findsWidgets);
  });
}
```

- [ ] **Step 6: Commit**

```bash
cd /home/jim/xrpl-mobile-wallet
git add -A
git commit -m "feat: scaffold Flutter XRPL wallet shell and dependencies"
```

---

### Task 2: Domain models and validation (TDD)

**Files:**
- Create: `lib/domain/models/network_id.dart` (or keep in constants — prefer single `network_id.dart` exporting enum if split)
- Create: `lib/domain/models/wallet_account.dart`
- Create: `lib/domain/validation/address_validator.dart`
- Create: `lib/domain/validation/secret_validator.dart`
- Create: `test/domain/validation_test.dart`

- [ ] **Step 1: Write failing validation tests**

```dart
// test/domain/validation_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/domain/validation/address_validator.dart';
import 'package:xrpl_mobile_wallet/domain/validation/secret_validator.dart';

void main() {
  group('AddressValidator', () {
    test('accepts a known-valid classic address format', () {
      // Well-formed classic address (checksum validated by implementation)
      const addr = 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh';
      expect(AddressValidator.isValidClassic(addr), isTrue);
    });

    test('rejects empty and garbage', () {
      expect(AddressValidator.isValidClassic(''), isFalse);
      expect(AddressValidator.isValidClassic('not-an-address'), isFalse);
      expect(AddressValidator.isValidClassic('s████'), isFalse);
    });
  });

  group('SecretValidator', () {
    test('detects family seed prefix', () {
      expect(SecretValidator.looksLikeFamilySeed('snoPBrXtMeMyMHUVTgbuqAfg1SUTb'), isTrue);
      expect(SecretValidator.looksLikeFamilySeed('hello world'), isFalse);
    });

    test('detects mnemonic by word count', () {
      final words12 = List.filled(12, 'abandon').join(' ');
      final words24 = List.filled(24, 'abandon').join(' ');
      expect(SecretValidator.looksLikeMnemonic(words12), isTrue);
      expect(SecretValidator.looksLikeMnemonic(words24), isTrue);
      expect(SecretValidator.looksLikeMnemonic('only three words'), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run tests — expect FAIL**

```bash
cd /home/jim/xrpl-mobile-wallet && flutter test test/domain/validation_test.dart
```

Expected: compilation failure (missing libraries).

- [ ] **Step 3: Implement models and validators**

```dart
// lib/domain/models/wallet_account.dart
import 'package:xrpl_mobile_wallet/core/constants.dart';

enum WalletKind { signing, watchOnly }

enum ImportMethod { mnemonic, familySeed, addressOnly }

class WalletAccount {
  final String id;
  final String label;
  final String address;
  final WalletKind kind;
  final NetworkId preferredNetwork;
  final ImportMethod importMethod;
  final DateTime createdAt;
  final int sortOrder;

  const WalletAccount({
    required this.id,
    required this.label,
    required this.address,
    required this.kind,
    required this.preferredNetwork,
    required this.importMethod,
    required this.createdAt,
    this.sortOrder = 0,
  });

  bool get canSign => kind == WalletKind.signing;
}
```

```dart
// lib/domain/validation/address_validator.dart
import 'package:xrpl_dart/xrpl_dart.dart';

class AddressValidator {
  static bool isValidClassic(String input) {
    final s = input.trim();
    if (s.isEmpty || !s.startsWith('r')) return false;
    try {
      // xrpl_dart address decode / checksum — adjust API to package version:
      // Prefer: XRPAddress(s) or similar constructor that throws on bad checksum.
      final _ = XRPAddress(s);
      return true;
    } catch (_) {
      return false;
    }
  }
}
```

**Note:** Confirm `XRPAddress` constructor name against `xrpl_dart` 7.x API (`publicKey.toAddress()` patterns). If the package exposes `XRPAddressUtils` or `AddressUtils.decode`, use that. Tests must still pass with real checksum logic.

```dart
// lib/domain/validation/secret_validator.dart
class SecretValidator {
  static bool looksLikeFamilySeed(String input) {
    final s = input.trim();
    return s.startsWith('s') && !s.contains(' ') && s.length >= 20;
  }

  static bool looksLikeMnemonic(String input) {
    final parts = input.trim().split(RegExp(r'\s+'));
    return parts.length == 12 || parts.length == 24;
  }
}
```

If `XRPAddress` API differs, fix implementation until tests pass — do not weaken tests to `startsWith('r')` only.

- [ ] **Step 4: Run tests — expect PASS**

```bash
flutter test test/domain/validation_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/domain test/domain
git commit -m "feat: add wallet domain models and import validation"
```

---

### Task 3: PIN service and KeyVault (TDD)

**Files:**
- Create: `lib/data/secure/pin_service.dart`
- Create: `lib/data/secure/key_vault.dart`
- Create: `test/data/pin_service_test.dart`

- [ ] **Step 1: Write PIN hash tests (pure functions)**

```dart
// test/data/pin_service_test.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/data/secure/pin_service.dart';

void main() {
  test('same pin+salt produces same hash', () {
    const salt = 'abc123';
    final a = PinService.hashPin('123456', salt);
    final b = PinService.hashPin('123456', salt);
    expect(a, equals(b));
  });

  test('different pins differ', () {
    const salt = 'abc123';
    expect(PinService.hashPin('123456', salt), isNot(equals(PinService.hashPin('654321', salt))));
  });

  test('min length enforced', () {
    expect(PinService.isPinFormatValid('12345'), isFalse);
    expect(PinService.isPinFormatValid('123456'), isTrue);
  });
}
```

- [ ] **Step 2: Implement PinService and KeyVault**

```dart
// lib/data/secure/pin_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:xrpl_mobile_wallet/core/constants.dart';

class PinService {
  PinService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static bool isPinFormatValid(String pin) =>
      pin.length >= AppConstants.pinMinLength && RegExp(r'^\d+$').hasMatch(pin);

  static String hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  static String generateSalt() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return base64UrlEncode(bytes);
  }

  Future<bool> hasPin() async {
    final h = await _storage.read(key: AppConstants.secureStoragePinKey);
    return h != null && h.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    if (!isPinFormatValid(pin)) {
      throw ArgumentError('PIN must be at least ${AppConstants.pinMinLength} digits');
    }
    final salt = generateSalt();
    final hash = hashPin(pin, salt);
    await _storage.write(key: AppConstants.secureStoragePinSaltKey, value: salt);
    await _storage.write(key: AppConstants.secureStoragePinKey, value: hash);
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: AppConstants.secureStoragePinSaltKey);
    final expected = await _storage.read(key: AppConstants.secureStoragePinKey);
    if (salt == null || expected == null) return false;
    return hashPin(pin, salt) == expected;
  }

  Future<void> clearPin() async {
    await _storage.delete(key: AppConstants.secureStoragePinKey);
    await _storage.delete(key: AppConstants.secureStoragePinSaltKey);
  }
}
```

```dart
// lib/data/secure/key_vault.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KeyVault {
  KeyVault({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _key(String walletId) => 'wallet_secret_$walletId';

  Future<void> saveSecret(String walletId, String secret) async {
    await _storage.write(key: _key(walletId), value: secret);
  }

  Future<String?> readSecret(String walletId) async {
    return _storage.read(key: _key(walletId));
  }

  Future<void> deleteSecret(String walletId) async {
    await _storage.delete(key: _key(walletId));
  }

  Future<void> deleteAllSecrets() async {
    // Prefer enumerating known wallet IDs from DB caller; this clears only our prefix if supported.
    await _storage.deleteAll();
  }
}
```

**Security note:** `deleteAllSecrets` via `deleteAll()` also clears PIN — `wipe` flow must re-order: delete wallets, secrets, PIN, then SQLite. Document in wipe implementation (Task 4/8).

- [ ] **Step 3: Run unit tests**

```bash
flutter test test/data/pin_service_test.dart
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/data/secure test/data
git commit -m "feat: add PIN hashing and secure KeyVault"
```

---

### Task 4: SQLite schema (Drift) and wallet repository

**Files:**
- Create: `lib/data/db/tables.dart`
- Create: `lib/data/db/app_database.dart`
- Create: `lib/data/db/wallet_dao.dart` (or methods on database)
- Create: `lib/state/providers.dart`

- [ ] **Step 1: Define Drift tables**

```dart
// lib/data/db/tables.dart
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

  @override
  Set<Column> get primaryKey => {id};
}

class Balances extends Table {
  TextColumn get walletId => text()();
  TextColumn get currency => text()();
  TextColumn get issuer => text().nullable()();
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
```

- [ ] **Step 2: AppDatabase + code generation**

```dart
// lib/data/db/app_database.dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Wallets, Balances, CachedTxs, AppSettingsRows])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  Future<List<Wallet>> getAllWallets() => select(wallets).get();

  Future<void> upsertWallet(WalletsCompanion row) =>
      into(wallets).insertOnConflictUpdate(row);

  Future<void> deleteWalletById(String id) =>
      (delete(wallets)..where((t) => t.id.equals(id))).go();

  Future<void> wipeAll() async {
    await delete(cachedTxs).go();
    await delete(balances).go();
    await delete(wallets).go();
    await delete(appSettingsRows).go();
  }
}

LazyDatabase _open() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'xrpl_wallet.sqlite'));
    return NativeDatabase(file);
  });
}
```

Run:

```bash
cd /home/jim/xrpl-mobile-wallet
dart run build_runner build --delete-conflicting-outputs
```

Expected: `lib/data/db/app_database.g.dart` generated.

- [ ] **Step 3: Riverpod providers**

```dart
// lib/state/providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xrpl_mobile_wallet/data/db/app_database.dart';
import 'package:xrpl_mobile_wallet/data/secure/key_vault.dart';
import 'package:xrpl_mobile_wallet/data/secure/pin_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final pinServiceProvider = Provider((ref) => PinService());
final keyVaultProvider = Provider((ref) => KeyVault());
```

- [ ] **Step 4: Commit**

```bash
git add lib/data/db lib/state
git commit -m "feat: add Drift SQLite schema and providers"
```

---

### Task 5: Lock screens and app gate

**Files:**
- Create: `lib/state/lock_controller.dart`
- Create: `lib/ui/lock/setup_pin_screen.dart`
- Create: `lib/ui/lock/unlock_screen.dart`
- Modify: `lib/app.dart`

- [ ] **Step 1: LockController**

```dart
// lib/state/lock_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:xrpl_mobile_wallet/data/secure/pin_service.dart';
import 'package:xrpl_mobile_wallet/state/providers.dart';

enum LockPhase { loading, needsSetup, locked, unlocked }

class LockController extends StateNotifier<LockPhase> {
  LockController(this._pin) : super(LockPhase.loading) {
    _init();
  }

  final PinService _pin;
  final _auth = LocalAuthentication();

  Future<void> _init() async {
    state = await _pin.hasPin() ? LockPhase.locked : LockPhase.needsSetup;
  }

  Future<void> setupPin(String pin) async {
    await _pin.setPin(pin);
    state = LockPhase.unlocked;
  }

  Future<bool> unlockWithPin(String pin) async {
    final ok = await _pin.verifyPin(pin);
    if (ok) state = LockPhase.unlocked;
    return ok;
  }

  Future<bool> unlockWithBiometrics() async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock XRPL Wallet',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (ok) state = LockPhase.unlocked;
      return ok;
    } catch (_) {
      return false;
    }
  }

  void lock() {
    if (state == LockPhase.unlocked) state = LockPhase.locked;
  }
}

final lockControllerProvider =
    StateNotifierProvider<LockController, LockPhase>((ref) {
  return LockController(ref.watch(pinServiceProvider));
});
```

- [ ] **Step 2: Setup + Unlock UI (minimal Material forms)**

`SetupPinScreen`: two fields (PIN + confirm), validate length/match, call `setupPin`.

`UnlockScreen`: PIN field + Unlock button + optional “Use biometrics” if `local_auth` reports support.

- [ ] **Step 3: Gate in `app.dart`**

```dart
// home: Consumer that switches on lockControllerProvider:
// loading -> splash CircularProgressIndicator
// needsSetup -> SetupPinScreen
// locked -> UnlockScreen
// unlocked -> MainShell
// Also: WidgetsBindingObserver on app resume after AppConstants.autoLockSeconds -> lock()
```

Implement observer in a small `LockLifecycle` widget wrapping `MainShell`.

- [ ] **Step 4: Manual check on device/emulator**

```bash
flutter run
```

Expected: first launch asks for PIN; kill/reopen asks to unlock.

- [ ] **Step 5: Commit**

```bash
git commit -am "feat: add PIN setup, unlock, and auto-lock gate"
```

---

### Task 6: Ledger client (read path)

**Files:**
- Create: `lib/data/ledger/ledger_client.dart`
- Create: `lib/data/ledger/amount_format.dart`
- Create: `test/data/amount_format_test.dart`
- Create: `lib/state/network_controller.dart`

- [ ] **Step 1: Amount formatting tests**

```dart
// test/data/amount_format_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/data/ledger/amount_format.dart';

void main() {
  test('drops to XRP', () {
    expect(AmountFormat.dropsToXrp('1000000'), '1');
    expect(AmountFormat.dropsToXrp('1'), '0.000001');
  });

  test('xrp to drops', () {
    expect(AmountFormat.xrpToDrops('1'), '1000000');
  });
}
```

Implement with `BigInt` math (1 XRP = 1_000_000 drops).

- [ ] **Step 2: LedgerClient**

```dart
// lib/data/ledger/ledger_client.dart
// Responsibilities:
// - connect(NetworkId) using NetworkId.defaultWss
// - disconnect()
// - Future<AccountBalances> fetchBalances(String address)
//     RPC account_info -> XRP balance
//     RPC account_lines -> IOUs
// - Future<List<CachedTxDraft>> fetchAccountTx(String address, {int limit = 20})
// - Use xrpl_dart XRPProvider + RPCWebSocketService (see package examples)
//
// Map unfunded account (actNotFound) to zero XRP and empty lines without throwing.
```

Wire `networkControllerProvider` holding `NetworkId` + connection state (`disconnected|connecting|connected|error`).

- [ ] **Step 3: Integration smoke (manual / optional test)**

```bash
# Optional: flutter test with a test that connects to testnet if ENABLE_XRPL_IT=1
```

At minimum, manual: connect testnet, `account_info` for a funded faucet address.

- [ ] **Step 4: Commit**

```bash
git commit -am "feat: add XRPL ledger read client and amount formatting"
```

---

### Task 7: Import wallet flows + list/detail/receive

**Files:**
- Create: `lib/data/wallet/wallet_importer.dart`
- Create: `lib/ui/wallets/import_screen.dart`
- Create: `lib/ui/wallets/wallet_list_screen.dart`
- Create: `lib/ui/wallets/wallet_detail_screen.dart`
- Create: `lib/ui/wallets/receive_screen.dart`
- Create: `lib/state/wallet_list_controller.dart`
- Modify: `main_shell.dart` to use real list

- [ ] **Step 1: WalletImporter**

```dart
// lib/data/wallet/wallet_importer.dart
// importMnemonic(phrase) -> derive via xrpl_dart / blockchain_utils BIP39
// importFamilySeed(seed) -> XRP private key / wallet from seed
// importWatchOnly(address) -> address only
// Returns WalletAccount + secret? (null for watch)
// Throws on invalid checksum / invalid mnemonic
```

Match derivation to XRPL defaults (ed25519 vs secp256k1 — follow `xrpl_dart` wallet-from-mnemonic examples so addresses match `xrpl.js` `Wallet.fromMnemonic` for the same phrase).

- [ ] **Step 2: Persist on confirm**

```dart
// On successful import:
// 1. uuid id
// 2. if signing: keyVault.saveSecret(id, secret)
// 3. db.upsertWallet(...)
// 4. clear TextEditingControllers
// 5. refresh balances via ledgerClient
// 6. notify watcher bridge (no-op until Task 10)
```

- [ ] **Step 3: UI**

- Import: segmented control Mnemonic | Family seed | Watch address; FLAG_SECURE via platform channel or `flutter_windowmanager` / Android `FLAG_SECURE` plugin — if no plugin, document TODO and set in Android Activity for that route using a small MethodChannel in Task 8 hardening.
- List: tiles with label, shortened address, XRP balance, badge Watch/Signing
- Detail: balances list, Send (if signing), Receive, delete
- Receive: `QrImageView(data: address)`, copy button

- [ ] **Step 4: Manual test on testnet**

Import watch-only known address; see balance or unfunded zero.

- [ ] **Step 5: Commit**

```bash
git commit -am "feat: import signing and watch-only wallets with list and receive"
```

---

### Task 8: Send payment

**Files:**
- Create: `lib/data/tx/payment_service.dart`
- Create: `lib/ui/send/send_screen.dart`

- [ ] **Step 1: PaymentService**

```dart
// buildAndSubmit({
//   required String walletId,
//   required String destination,
//   int? destinationTag,
//   required /* XRP or IOU amount */,
// })
// Steps:
// 1. load secret from KeyVault (caller ensures unlocked)
// 2. reconstruct signing key
// 3. Payment tx via xrpl_dart
// 4. autoFill fee/sequence/lastLedgerSequence
// 5. sign + submit
// 6. clear secret variable
// 7. return hash + engine result
```

- [ ] **Step 2: Send UI wizard**

Pages/sections: asset picker → destination → amount → review (network banner if mismatch) → result.

Require unlock if `LockPhase.locked` before sign.

- [ ] **Step 3: Manual testnet send**

Fund account via faucet if needed; send 1 drop or small XRP between test accounts.

- [ ] **Step 4: Commit**

```bash
git commit -am "feat: send XRP and IOU payments with review confirm"
```

---

### Task 9: Activity feed

**Files:**
- Create: `lib/ui/activity/activity_screen.dart`
- Create: `lib/ui/activity/tx_detail_screen.dart`
- Modify: wallet detail to show recent txs

- [ ] **Step 1: Load cached txs from DB; pull-to-refresh calls `fetchAccountTx` for each wallet and upserts**

- [ ] **Step 2: ListTile per tx: direction icon, amountSummary, date, wallet label**

- [ ] **Step 3: Commit**

```bash
git commit -am "feat: activity feed and transaction detail"
```

---

### Task 10: Android watcher foreground service

**Files:**
- Create: `android/.../watcher/XrplWatcherService.kt`
- Create: `lib/data/watcher/watcher_bridge.dart`
- Modify: `AndroidManifest.xml` (permissions, service)
- Modify: Settings screen toggle

- [ ] **Step 1: Manifest permissions**

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC"/>
```

Register service with `foregroundServiceType="dataSync"`.

- [ ] **Step 2: Address book file**

UI writes JSON to app files dir:

```json
{
  "network": "mainnet",
  "wss": "wss://xrplcluster.com",
  "accounts": [
    {"address": "r...", "label": "Cold"}
  ]
}
```

Service reads only this file — **no secrets**.

- [ ] **Step 3: Service loop**

Kotlin (or Flutter isolate + `flutter_background_service` if preferred — pick **one**):

**Preferred for v1 speed:** `flutter_background_service` + Dart WSS using same subscribe logic, still never loading KeyVault in the background callback.

Subscribe:

```json
{ "command": "subscribe", "accounts": ["r..."] }
```

On transaction message → parse → local notification → dedupe hashes in memory + small prefs file.

Sticky notification: `XRPL Watcher: N accounts · Mainnet · connected`.

- [ ] **Step 4: Bridge API**

```dart
class WatcherBridge {
  Future<void> syncAddressBook(List<WalletAccount> accounts, NetworkId network);
  Future<void> setEnabled(bool enabled);
  Future<bool> isRunning();
}
```

Call `syncAddressBook` after import/delete/network change.

- [ ] **Step 5: Manual test**

Enable watcher; from another wallet send testnet XRP to watched address; confirm notification with app backgrounded.

- [ ] **Step 6: Commit**

```bash
git commit -am "feat: Android foreground watcher with local notifications"
```

---

### Task 11: Settings, wipe, hardening, release APK

**Files:**
- Create: `lib/ui/settings/settings_screen.dart`
- Modify: Android release signing (debug keystore OK for personal sideload initially)
- Create: `README.md`

- [ ] **Step 1: Settings UI**

- Network switch Mainnet/Testnet  
- Watcher enable + link to battery optimization tips  
- Biometrics toggle (store flag in settings table)  
- Wipe all: confirm dialog → KeyVault.deleteAll + PinService.clear + db.wipeAll → navigate to setup PIN  

- [ ] **Step 2: README**

```markdown
# XRPL Mobile Wallet

Personal Android wallet manager for the XRP Ledger.

## Build
flutter pub get
flutter run
flutter build apk --release

## Security
- PIN required; secrets in Android Keystore
- Watcher process never holds keys
- Import only (no generate) in v1

## Watcher
Disable battery optimization for reliable background alerts.
```

- [ ] **Step 3: Release APK**

```bash
flutter build apk --release
ls -la build/app/outputs/flutter-apk/app-release.apk
```

- [ ] **Step 4: Final analyze + test**

```bash
flutter analyze
flutter test
```

- [ ] **Step 5: Commit**

```bash
git commit -am "feat: settings, wipe, README, and release APK build"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Import mnemonic / family seed | 7 |
| Watch-only address | 7 |
| XRP + IOU balances | 6–7 |
| Send XRP + IOU | 8 |
| Mainnet + Testnet | 1, 6, 11 |
| PIN + biometrics + auto-lock | 3, 5 |
| Secrets not in watcher | 3, 10 |
| Activity / history | 9 |
| FGS notifications | 10 |
| Sideload APK | 11 |
| No generate wallet | 7 (import-only UI) |

## Self-review notes

- `xrpl_dart` symbol names (`XRPAddress`, wallet-from-mnemonic) must be verified against installed package docs during Task 2/7; adjust call sites without changing behavior contracts in tests.
- Prefer `flutter_background_service` for Task 10 if pure Kotlin WSS would delay first APK.
- Wipe must not leave PIN without DB or secrets without PIN — order: stop watcher → wipe DB → deleteAll secure storage → needsSetup.

---

## Execution handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-20-xrpl-mobile-wallet.md`.

**Two execution options:**

1. **Subagent-Driven (recommended)** — fresh subagent per task, review between tasks  
2. **Inline Execution** — this session implements tasks with checkpoints  

Which approach?
