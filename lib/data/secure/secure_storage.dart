import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Shared Keystore-backed store for PIN verifiers and wallet secrets.
///
/// [AndroidOptions.resetOnError] is false so a decryption glitch or a
/// cross-device backup restore cannot silently delete seeds. Callers must
/// surface the error to the user.
const kAppSecureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(resetOnError: false),
);
