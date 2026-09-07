import 'package:flutter/material.dart';
import 'package:xrpl_mobile_wallet/config/network_id.dart';
import 'package:xrpl_mobile_wallet/domain/wallet/wallet_color.dart';

export 'package:xrpl_mobile_wallet/config/network_id.dart';

enum WalletKind { signing, watchOnly }

enum ImportMethod { mnemonic, familySeed, addressOnly, ledger }

class WalletAccount {
  final String id;
  final String label;
  final String address;
  final WalletKind kind;
  final NetworkId preferredNetwork;
  final ImportMethod importMethod;
  final DateTime createdAt;
  final int sortOrder;

  /// Optional ARGB accent; null means derive from [address].
  final int? accentColorArgb;

  /// When true, Send is enabled via a connected Ledger (no seed on phone).
  final bool useLedger;

  /// BIP44 account index for m/44'/144'/index'/0/0 on the Ledger.
  final int ledgerAccountIndex;

  const WalletAccount({
    required this.id,
    required this.label,
    required this.address,
    required this.kind,
    required this.preferredNetwork,
    required this.importMethod,
    required this.createdAt,
    this.sortOrder = 0,
    this.accentColorArgb,
    this.useLedger = false,
    this.ledgerAccountIndex = 0,
  });

  /// Local keys or Ledger checkbox enables Send.
  bool get canSign => kind == WalletKind.signing || useLedger;

  bool get hasLocalKeys => kind == WalletKind.signing;

  /// Resolved display color (manual or address-derived).
  Color get displayColor =>
      WalletColor.resolve(address, accentArgb: accentColorArgb);

  WalletAccount copyWith({
    String? id,
    String? label,
    String? address,
    WalletKind? kind,
    NetworkId? preferredNetwork,
    ImportMethod? importMethod,
    DateTime? createdAt,
    int? sortOrder,
    int? accentColorArgb,
    bool clearAccentColor = false,
    bool? useLedger,
    int? ledgerAccountIndex,
  }) {
    return WalletAccount(
      id: id ?? this.id,
      label: label ?? this.label,
      address: address ?? this.address,
      kind: kind ?? this.kind,
      preferredNetwork: preferredNetwork ?? this.preferredNetwork,
      importMethod: importMethod ?? this.importMethod,
      createdAt: createdAt ?? this.createdAt,
      sortOrder: sortOrder ?? this.sortOrder,
      accentColorArgb: clearAccentColor
          ? null
          : (accentColorArgb ?? this.accentColorArgb),
      useLedger: useLedger ?? this.useLedger,
      ledgerAccountIndex: ledgerAccountIndex ?? this.ledgerAccountIndex,
    );
  }
}
