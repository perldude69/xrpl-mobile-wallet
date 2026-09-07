// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $WalletsTable extends Wallets with TableInfo<$WalletsTable, Wallet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WalletsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _preferredNetworkMeta = const VerificationMeta(
    'preferredNetwork',
  );
  @override
  late final GeneratedColumn<String> preferredNetwork = GeneratedColumn<String>(
    'preferred_network',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importMethodMeta = const VerificationMeta(
    'importMethod',
  );
  @override
  late final GeneratedColumn<String> importMethod = GeneratedColumn<String>(
    'import_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _accentColorMeta = const VerificationMeta(
    'accentColor',
  );
  @override
  late final GeneratedColumn<int> accentColor = GeneratedColumn<int>(
    'accent_color',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _useLedgerMeta = const VerificationMeta(
    'useLedger',
  );
  @override
  late final GeneratedColumn<bool> useLedger = GeneratedColumn<bool>(
    'use_ledger',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("use_ledger" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _ledgerAccountIndexMeta =
      const VerificationMeta('ledgerAccountIndex');
  @override
  late final GeneratedColumn<int> ledgerAccountIndex = GeneratedColumn<int>(
    'ledger_account_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    label,
    address,
    kind,
    preferredNetwork,
    importMethod,
    createdAt,
    sortOrder,
    accentColor,
    useLedger,
    ledgerAccountIndex,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wallets';
  @override
  VerificationContext validateIntegrity(
    Insertable<Wallet> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    } else if (isInserting) {
      context.missing(_addressMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('preferred_network')) {
      context.handle(
        _preferredNetworkMeta,
        preferredNetwork.isAcceptableOrUnknown(
          data['preferred_network']!,
          _preferredNetworkMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_preferredNetworkMeta);
    }
    if (data.containsKey('import_method')) {
      context.handle(
        _importMethodMeta,
        importMethod.isAcceptableOrUnknown(
          data['import_method']!,
          _importMethodMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_importMethodMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('accent_color')) {
      context.handle(
        _accentColorMeta,
        accentColor.isAcceptableOrUnknown(
          data['accent_color']!,
          _accentColorMeta,
        ),
      );
    }
    if (data.containsKey('use_ledger')) {
      context.handle(
        _useLedgerMeta,
        useLedger.isAcceptableOrUnknown(data['use_ledger']!, _useLedgerMeta),
      );
    }
    if (data.containsKey('ledger_account_index')) {
      context.handle(
        _ledgerAccountIndexMeta,
        ledgerAccountIndex.isAcceptableOrUnknown(
          data['ledger_account_index']!,
          _ledgerAccountIndexMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Wallet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Wallet(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      preferredNetwork: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preferred_network'],
      )!,
      importMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}import_method'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      accentColor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}accent_color'],
      ),
      useLedger: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}use_ledger'],
      )!,
      ledgerAccountIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ledger_account_index'],
      )!,
    );
  }

  @override
  $WalletsTable createAlias(String alias) {
    return $WalletsTable(attachedDatabase, alias);
  }
}

class Wallet extends DataClass implements Insertable<Wallet> {
  final String id;
  final String label;
  final String address;
  final String kind;
  final String preferredNetwork;
  final String importMethod;
  final DateTime createdAt;
  final int sortOrder;

  /// Optional ARGB accent; null = derive from address.
  final int? accentColor;

  /// When true, Send uses a connected Ledger (no seed on phone).
  final bool useLedger;

  /// BIP44 account index for Ledger path m/44'/144'/index'/0/0.
  final int ledgerAccountIndex;
  const Wallet({
    required this.id,
    required this.label,
    required this.address,
    required this.kind,
    required this.preferredNetwork,
    required this.importMethod,
    required this.createdAt,
    required this.sortOrder,
    this.accentColor,
    required this.useLedger,
    required this.ledgerAccountIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['label'] = Variable<String>(label);
    map['address'] = Variable<String>(address);
    map['kind'] = Variable<String>(kind);
    map['preferred_network'] = Variable<String>(preferredNetwork);
    map['import_method'] = Variable<String>(importMethod);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || accentColor != null) {
      map['accent_color'] = Variable<int>(accentColor);
    }
    map['use_ledger'] = Variable<bool>(useLedger);
    map['ledger_account_index'] = Variable<int>(ledgerAccountIndex);
    return map;
  }

  WalletsCompanion toCompanion(bool nullToAbsent) {
    return WalletsCompanion(
      id: Value(id),
      label: Value(label),
      address: Value(address),
      kind: Value(kind),
      preferredNetwork: Value(preferredNetwork),
      importMethod: Value(importMethod),
      createdAt: Value(createdAt),
      sortOrder: Value(sortOrder),
      accentColor: accentColor == null && nullToAbsent
          ? const Value.absent()
          : Value(accentColor),
      useLedger: Value(useLedger),
      ledgerAccountIndex: Value(ledgerAccountIndex),
    );
  }

  factory Wallet.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Wallet(
      id: serializer.fromJson<String>(json['id']),
      label: serializer.fromJson<String>(json['label']),
      address: serializer.fromJson<String>(json['address']),
      kind: serializer.fromJson<String>(json['kind']),
      preferredNetwork: serializer.fromJson<String>(json['preferredNetwork']),
      importMethod: serializer.fromJson<String>(json['importMethod']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      accentColor: serializer.fromJson<int?>(json['accentColor']),
      useLedger: serializer.fromJson<bool>(json['useLedger']),
      ledgerAccountIndex: serializer.fromJson<int>(json['ledgerAccountIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'label': serializer.toJson<String>(label),
      'address': serializer.toJson<String>(address),
      'kind': serializer.toJson<String>(kind),
      'preferredNetwork': serializer.toJson<String>(preferredNetwork),
      'importMethod': serializer.toJson<String>(importMethod),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'accentColor': serializer.toJson<int?>(accentColor),
      'useLedger': serializer.toJson<bool>(useLedger),
      'ledgerAccountIndex': serializer.toJson<int>(ledgerAccountIndex),
    };
  }

  Wallet copyWith({
    String? id,
    String? label,
    String? address,
    String? kind,
    String? preferredNetwork,
    String? importMethod,
    DateTime? createdAt,
    int? sortOrder,
    Value<int?> accentColor = const Value.absent(),
    bool? useLedger,
    int? ledgerAccountIndex,
  }) => Wallet(
    id: id ?? this.id,
    label: label ?? this.label,
    address: address ?? this.address,
    kind: kind ?? this.kind,
    preferredNetwork: preferredNetwork ?? this.preferredNetwork,
    importMethod: importMethod ?? this.importMethod,
    createdAt: createdAt ?? this.createdAt,
    sortOrder: sortOrder ?? this.sortOrder,
    accentColor: accentColor.present ? accentColor.value : this.accentColor,
    useLedger: useLedger ?? this.useLedger,
    ledgerAccountIndex: ledgerAccountIndex ?? this.ledgerAccountIndex,
  );
  Wallet copyWithCompanion(WalletsCompanion data) {
    return Wallet(
      id: data.id.present ? data.id.value : this.id,
      label: data.label.present ? data.label.value : this.label,
      address: data.address.present ? data.address.value : this.address,
      kind: data.kind.present ? data.kind.value : this.kind,
      preferredNetwork: data.preferredNetwork.present
          ? data.preferredNetwork.value
          : this.preferredNetwork,
      importMethod: data.importMethod.present
          ? data.importMethod.value
          : this.importMethod,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      accentColor: data.accentColor.present
          ? data.accentColor.value
          : this.accentColor,
      useLedger: data.useLedger.present ? data.useLedger.value : this.useLedger,
      ledgerAccountIndex: data.ledgerAccountIndex.present
          ? data.ledgerAccountIndex.value
          : this.ledgerAccountIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Wallet(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('address: $address, ')
          ..write('kind: $kind, ')
          ..write('preferredNetwork: $preferredNetwork, ')
          ..write('importMethod: $importMethod, ')
          ..write('createdAt: $createdAt, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('accentColor: $accentColor, ')
          ..write('useLedger: $useLedger, ')
          ..write('ledgerAccountIndex: $ledgerAccountIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    label,
    address,
    kind,
    preferredNetwork,
    importMethod,
    createdAt,
    sortOrder,
    accentColor,
    useLedger,
    ledgerAccountIndex,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Wallet &&
          other.id == this.id &&
          other.label == this.label &&
          other.address == this.address &&
          other.kind == this.kind &&
          other.preferredNetwork == this.preferredNetwork &&
          other.importMethod == this.importMethod &&
          other.createdAt == this.createdAt &&
          other.sortOrder == this.sortOrder &&
          other.accentColor == this.accentColor &&
          other.useLedger == this.useLedger &&
          other.ledgerAccountIndex == this.ledgerAccountIndex);
}

class WalletsCompanion extends UpdateCompanion<Wallet> {
  final Value<String> id;
  final Value<String> label;
  final Value<String> address;
  final Value<String> kind;
  final Value<String> preferredNetwork;
  final Value<String> importMethod;
  final Value<DateTime> createdAt;
  final Value<int> sortOrder;
  final Value<int?> accentColor;
  final Value<bool> useLedger;
  final Value<int> ledgerAccountIndex;
  final Value<int> rowid;
  const WalletsCompanion({
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    this.address = const Value.absent(),
    this.kind = const Value.absent(),
    this.preferredNetwork = const Value.absent(),
    this.importMethod = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.accentColor = const Value.absent(),
    this.useLedger = const Value.absent(),
    this.ledgerAccountIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WalletsCompanion.insert({
    required String id,
    required String label,
    required String address,
    required String kind,
    required String preferredNetwork,
    required String importMethod,
    required DateTime createdAt,
    this.sortOrder = const Value.absent(),
    this.accentColor = const Value.absent(),
    this.useLedger = const Value.absent(),
    this.ledgerAccountIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       label = Value(label),
       address = Value(address),
       kind = Value(kind),
       preferredNetwork = Value(preferredNetwork),
       importMethod = Value(importMethod),
       createdAt = Value(createdAt);
  static Insertable<Wallet> custom({
    Expression<String>? id,
    Expression<String>? label,
    Expression<String>? address,
    Expression<String>? kind,
    Expression<String>? preferredNetwork,
    Expression<String>? importMethod,
    Expression<DateTime>? createdAt,
    Expression<int>? sortOrder,
    Expression<int>? accentColor,
    Expression<bool>? useLedger,
    Expression<int>? ledgerAccountIndex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (label != null) 'label': label,
      if (address != null) 'address': address,
      if (kind != null) 'kind': kind,
      if (preferredNetwork != null) 'preferred_network': preferredNetwork,
      if (importMethod != null) 'import_method': importMethod,
      if (createdAt != null) 'created_at': createdAt,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (accentColor != null) 'accent_color': accentColor,
      if (useLedger != null) 'use_ledger': useLedger,
      if (ledgerAccountIndex != null)
        'ledger_account_index': ledgerAccountIndex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WalletsCompanion copyWith({
    Value<String>? id,
    Value<String>? label,
    Value<String>? address,
    Value<String>? kind,
    Value<String>? preferredNetwork,
    Value<String>? importMethod,
    Value<DateTime>? createdAt,
    Value<int>? sortOrder,
    Value<int?>? accentColor,
    Value<bool>? useLedger,
    Value<int>? ledgerAccountIndex,
    Value<int>? rowid,
  }) {
    return WalletsCompanion(
      id: id ?? this.id,
      label: label ?? this.label,
      address: address ?? this.address,
      kind: kind ?? this.kind,
      preferredNetwork: preferredNetwork ?? this.preferredNetwork,
      importMethod: importMethod ?? this.importMethod,
      createdAt: createdAt ?? this.createdAt,
      sortOrder: sortOrder ?? this.sortOrder,
      accentColor: accentColor ?? this.accentColor,
      useLedger: useLedger ?? this.useLedger,
      ledgerAccountIndex: ledgerAccountIndex ?? this.ledgerAccountIndex,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (preferredNetwork.present) {
      map['preferred_network'] = Variable<String>(preferredNetwork.value);
    }
    if (importMethod.present) {
      map['import_method'] = Variable<String>(importMethod.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (accentColor.present) {
      map['accent_color'] = Variable<int>(accentColor.value);
    }
    if (useLedger.present) {
      map['use_ledger'] = Variable<bool>(useLedger.value);
    }
    if (ledgerAccountIndex.present) {
      map['ledger_account_index'] = Variable<int>(ledgerAccountIndex.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WalletsCompanion(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('address: $address, ')
          ..write('kind: $kind, ')
          ..write('preferredNetwork: $preferredNetwork, ')
          ..write('importMethod: $importMethod, ')
          ..write('createdAt: $createdAt, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('accentColor: $accentColor, ')
          ..write('useLedger: $useLedger, ')
          ..write('ledgerAccountIndex: $ledgerAccountIndex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BalancesTable extends Balances with TableInfo<$BalancesTable, Balance> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BalancesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _walletIdMeta = const VerificationMeta(
    'walletId',
  );
  @override
  late final GeneratedColumn<String> walletId = GeneratedColumn<String>(
    'wallet_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _issuerMeta = const VerificationMeta('issuer');
  @override
  late final GeneratedColumn<String> issuer = GeneratedColumn<String>(
    'issuer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    walletId,
    currency,
    issuer,
    value,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'balances';
  @override
  VerificationContext validateIntegrity(
    Insertable<Balance> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('wallet_id')) {
      context.handle(
        _walletIdMeta,
        walletId.isAcceptableOrUnknown(data['wallet_id']!, _walletIdMeta),
      );
    } else if (isInserting) {
      context.missing(_walletIdMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('issuer')) {
      context.handle(
        _issuerMeta,
        issuer.isAcceptableOrUnknown(data['issuer']!, _issuerMeta),
      );
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {walletId, currency, issuer};
  @override
  Balance map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Balance(
      walletId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wallet_id'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      issuer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}issuer'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $BalancesTable createAlias(String alias) {
    return $BalancesTable(attachedDatabase, alias);
  }
}

class Balance extends DataClass implements Insertable<Balance> {
  final String walletId;
  final String currency;
  final String issuer;
  final String value;
  final DateTime updatedAt;
  const Balance({
    required this.walletId,
    required this.currency,
    required this.issuer,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['wallet_id'] = Variable<String>(walletId);
    map['currency'] = Variable<String>(currency);
    map['issuer'] = Variable<String>(issuer);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BalancesCompanion toCompanion(bool nullToAbsent) {
    return BalancesCompanion(
      walletId: Value(walletId),
      currency: Value(currency),
      issuer: Value(issuer),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory Balance.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Balance(
      walletId: serializer.fromJson<String>(json['walletId']),
      currency: serializer.fromJson<String>(json['currency']),
      issuer: serializer.fromJson<String>(json['issuer']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'walletId': serializer.toJson<String>(walletId),
      'currency': serializer.toJson<String>(currency),
      'issuer': serializer.toJson<String>(issuer),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Balance copyWith({
    String? walletId,
    String? currency,
    String? issuer,
    String? value,
    DateTime? updatedAt,
  }) => Balance(
    walletId: walletId ?? this.walletId,
    currency: currency ?? this.currency,
    issuer: issuer ?? this.issuer,
    value: value ?? this.value,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Balance copyWithCompanion(BalancesCompanion data) {
    return Balance(
      walletId: data.walletId.present ? data.walletId.value : this.walletId,
      currency: data.currency.present ? data.currency.value : this.currency,
      issuer: data.issuer.present ? data.issuer.value : this.issuer,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Balance(')
          ..write('walletId: $walletId, ')
          ..write('currency: $currency, ')
          ..write('issuer: $issuer, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(walletId, currency, issuer, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Balance &&
          other.walletId == this.walletId &&
          other.currency == this.currency &&
          other.issuer == this.issuer &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class BalancesCompanion extends UpdateCompanion<Balance> {
  final Value<String> walletId;
  final Value<String> currency;
  final Value<String> issuer;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const BalancesCompanion({
    this.walletId = const Value.absent(),
    this.currency = const Value.absent(),
    this.issuer = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BalancesCompanion.insert({
    required String walletId,
    required String currency,
    this.issuer = const Value.absent(),
    required String value,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : walletId = Value(walletId),
       currency = Value(currency),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<Balance> custom({
    Expression<String>? walletId,
    Expression<String>? currency,
    Expression<String>? issuer,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (walletId != null) 'wallet_id': walletId,
      if (currency != null) 'currency': currency,
      if (issuer != null) 'issuer': issuer,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BalancesCompanion copyWith({
    Value<String>? walletId,
    Value<String>? currency,
    Value<String>? issuer,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return BalancesCompanion(
      walletId: walletId ?? this.walletId,
      currency: currency ?? this.currency,
      issuer: issuer ?? this.issuer,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (walletId.present) {
      map['wallet_id'] = Variable<String>(walletId.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (issuer.present) {
      map['issuer'] = Variable<String>(issuer.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BalancesCompanion(')
          ..write('walletId: $walletId, ')
          ..write('currency: $currency, ')
          ..write('issuer: $issuer, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedTxsTable extends CachedTxs
    with TableInfo<$CachedTxsTable, CachedTx> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedTxsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _hashMeta = const VerificationMeta('hash');
  @override
  late final GeneratedColumn<String> hash = GeneratedColumn<String>(
    'hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _walletIdMeta = const VerificationMeta(
    'walletId',
  );
  @override
  late final GeneratedColumn<String> walletId = GeneratedColumn<String>(
    'wallet_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ledgerIndexMeta = const VerificationMeta(
    'ledgerIndex',
  );
  @override
  late final GeneratedColumn<int> ledgerIndex = GeneratedColumn<int>(
    'ledger_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _txTypeMeta = const VerificationMeta('txType');
  @override
  late final GeneratedColumn<String> txType = GeneratedColumn<String>(
    'tx_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountSummaryMeta = const VerificationMeta(
    'amountSummary',
  );
  @override
  late final GeneratedColumn<String> amountSummary = GeneratedColumn<String>(
    'amount_summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _counterpartMeta = const VerificationMeta(
    'counterpart',
  );
  @override
  late final GeneratedColumn<String> counterpart = GeneratedColumn<String>(
    'counterpart',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    hash,
    walletId,
    ledgerIndex,
    txType,
    direction,
    amountSummary,
    counterpart,
    date,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_txs';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedTx> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('hash')) {
      context.handle(
        _hashMeta,
        hash.isAcceptableOrUnknown(data['hash']!, _hashMeta),
      );
    } else if (isInserting) {
      context.missing(_hashMeta);
    }
    if (data.containsKey('wallet_id')) {
      context.handle(
        _walletIdMeta,
        walletId.isAcceptableOrUnknown(data['wallet_id']!, _walletIdMeta),
      );
    } else if (isInserting) {
      context.missing(_walletIdMeta);
    }
    if (data.containsKey('ledger_index')) {
      context.handle(
        _ledgerIndexMeta,
        ledgerIndex.isAcceptableOrUnknown(
          data['ledger_index']!,
          _ledgerIndexMeta,
        ),
      );
    }
    if (data.containsKey('tx_type')) {
      context.handle(
        _txTypeMeta,
        txType.isAcceptableOrUnknown(data['tx_type']!, _txTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_txTypeMeta);
    }
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
      );
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('amount_summary')) {
      context.handle(
        _amountSummaryMeta,
        amountSummary.isAcceptableOrUnknown(
          data['amount_summary']!,
          _amountSummaryMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountSummaryMeta);
    }
    if (data.containsKey('counterpart')) {
      context.handle(
        _counterpartMeta,
        counterpart.isAcceptableOrUnknown(
          data['counterpart']!,
          _counterpartMeta,
        ),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {hash, walletId};
  @override
  CachedTx map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedTx(
      hash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hash'],
      )!,
      walletId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wallet_id'],
      )!,
      ledgerIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ledger_index'],
      ),
      txType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tx_type'],
      )!,
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direction'],
      )!,
      amountSummary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}amount_summary'],
      )!,
      counterpart: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}counterpart'],
      ),
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
    );
  }

  @override
  $CachedTxsTable createAlias(String alias) {
    return $CachedTxsTable(attachedDatabase, alias);
  }
}

class CachedTx extends DataClass implements Insertable<CachedTx> {
  final String hash;
  final String walletId;
  final int? ledgerIndex;
  final String txType;
  final String direction;
  final String amountSummary;
  final String? counterpart;
  final DateTime date;
  const CachedTx({
    required this.hash,
    required this.walletId,
    this.ledgerIndex,
    required this.txType,
    required this.direction,
    required this.amountSummary,
    this.counterpart,
    required this.date,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['hash'] = Variable<String>(hash);
    map['wallet_id'] = Variable<String>(walletId);
    if (!nullToAbsent || ledgerIndex != null) {
      map['ledger_index'] = Variable<int>(ledgerIndex);
    }
    map['tx_type'] = Variable<String>(txType);
    map['direction'] = Variable<String>(direction);
    map['amount_summary'] = Variable<String>(amountSummary);
    if (!nullToAbsent || counterpart != null) {
      map['counterpart'] = Variable<String>(counterpart);
    }
    map['date'] = Variable<DateTime>(date);
    return map;
  }

  CachedTxsCompanion toCompanion(bool nullToAbsent) {
    return CachedTxsCompanion(
      hash: Value(hash),
      walletId: Value(walletId),
      ledgerIndex: ledgerIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(ledgerIndex),
      txType: Value(txType),
      direction: Value(direction),
      amountSummary: Value(amountSummary),
      counterpart: counterpart == null && nullToAbsent
          ? const Value.absent()
          : Value(counterpart),
      date: Value(date),
    );
  }

  factory CachedTx.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedTx(
      hash: serializer.fromJson<String>(json['hash']),
      walletId: serializer.fromJson<String>(json['walletId']),
      ledgerIndex: serializer.fromJson<int?>(json['ledgerIndex']),
      txType: serializer.fromJson<String>(json['txType']),
      direction: serializer.fromJson<String>(json['direction']),
      amountSummary: serializer.fromJson<String>(json['amountSummary']),
      counterpart: serializer.fromJson<String?>(json['counterpart']),
      date: serializer.fromJson<DateTime>(json['date']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'hash': serializer.toJson<String>(hash),
      'walletId': serializer.toJson<String>(walletId),
      'ledgerIndex': serializer.toJson<int?>(ledgerIndex),
      'txType': serializer.toJson<String>(txType),
      'direction': serializer.toJson<String>(direction),
      'amountSummary': serializer.toJson<String>(amountSummary),
      'counterpart': serializer.toJson<String?>(counterpart),
      'date': serializer.toJson<DateTime>(date),
    };
  }

  CachedTx copyWith({
    String? hash,
    String? walletId,
    Value<int?> ledgerIndex = const Value.absent(),
    String? txType,
    String? direction,
    String? amountSummary,
    Value<String?> counterpart = const Value.absent(),
    DateTime? date,
  }) => CachedTx(
    hash: hash ?? this.hash,
    walletId: walletId ?? this.walletId,
    ledgerIndex: ledgerIndex.present ? ledgerIndex.value : this.ledgerIndex,
    txType: txType ?? this.txType,
    direction: direction ?? this.direction,
    amountSummary: amountSummary ?? this.amountSummary,
    counterpart: counterpart.present ? counterpart.value : this.counterpart,
    date: date ?? this.date,
  );
  CachedTx copyWithCompanion(CachedTxsCompanion data) {
    return CachedTx(
      hash: data.hash.present ? data.hash.value : this.hash,
      walletId: data.walletId.present ? data.walletId.value : this.walletId,
      ledgerIndex: data.ledgerIndex.present
          ? data.ledgerIndex.value
          : this.ledgerIndex,
      txType: data.txType.present ? data.txType.value : this.txType,
      direction: data.direction.present ? data.direction.value : this.direction,
      amountSummary: data.amountSummary.present
          ? data.amountSummary.value
          : this.amountSummary,
      counterpart: data.counterpart.present
          ? data.counterpart.value
          : this.counterpart,
      date: data.date.present ? data.date.value : this.date,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedTx(')
          ..write('hash: $hash, ')
          ..write('walletId: $walletId, ')
          ..write('ledgerIndex: $ledgerIndex, ')
          ..write('txType: $txType, ')
          ..write('direction: $direction, ')
          ..write('amountSummary: $amountSummary, ')
          ..write('counterpart: $counterpart, ')
          ..write('date: $date')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    hash,
    walletId,
    ledgerIndex,
    txType,
    direction,
    amountSummary,
    counterpart,
    date,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedTx &&
          other.hash == this.hash &&
          other.walletId == this.walletId &&
          other.ledgerIndex == this.ledgerIndex &&
          other.txType == this.txType &&
          other.direction == this.direction &&
          other.amountSummary == this.amountSummary &&
          other.counterpart == this.counterpart &&
          other.date == this.date);
}

class CachedTxsCompanion extends UpdateCompanion<CachedTx> {
  final Value<String> hash;
  final Value<String> walletId;
  final Value<int?> ledgerIndex;
  final Value<String> txType;
  final Value<String> direction;
  final Value<String> amountSummary;
  final Value<String?> counterpart;
  final Value<DateTime> date;
  final Value<int> rowid;
  const CachedTxsCompanion({
    this.hash = const Value.absent(),
    this.walletId = const Value.absent(),
    this.ledgerIndex = const Value.absent(),
    this.txType = const Value.absent(),
    this.direction = const Value.absent(),
    this.amountSummary = const Value.absent(),
    this.counterpart = const Value.absent(),
    this.date = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedTxsCompanion.insert({
    required String hash,
    required String walletId,
    this.ledgerIndex = const Value.absent(),
    required String txType,
    required String direction,
    required String amountSummary,
    this.counterpart = const Value.absent(),
    required DateTime date,
    this.rowid = const Value.absent(),
  }) : hash = Value(hash),
       walletId = Value(walletId),
       txType = Value(txType),
       direction = Value(direction),
       amountSummary = Value(amountSummary),
       date = Value(date);
  static Insertable<CachedTx> custom({
    Expression<String>? hash,
    Expression<String>? walletId,
    Expression<int>? ledgerIndex,
    Expression<String>? txType,
    Expression<String>? direction,
    Expression<String>? amountSummary,
    Expression<String>? counterpart,
    Expression<DateTime>? date,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (hash != null) 'hash': hash,
      if (walletId != null) 'wallet_id': walletId,
      if (ledgerIndex != null) 'ledger_index': ledgerIndex,
      if (txType != null) 'tx_type': txType,
      if (direction != null) 'direction': direction,
      if (amountSummary != null) 'amount_summary': amountSummary,
      if (counterpart != null) 'counterpart': counterpart,
      if (date != null) 'date': date,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedTxsCompanion copyWith({
    Value<String>? hash,
    Value<String>? walletId,
    Value<int?>? ledgerIndex,
    Value<String>? txType,
    Value<String>? direction,
    Value<String>? amountSummary,
    Value<String?>? counterpart,
    Value<DateTime>? date,
    Value<int>? rowid,
  }) {
    return CachedTxsCompanion(
      hash: hash ?? this.hash,
      walletId: walletId ?? this.walletId,
      ledgerIndex: ledgerIndex ?? this.ledgerIndex,
      txType: txType ?? this.txType,
      direction: direction ?? this.direction,
      amountSummary: amountSummary ?? this.amountSummary,
      counterpart: counterpart ?? this.counterpart,
      date: date ?? this.date,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (hash.present) {
      map['hash'] = Variable<String>(hash.value);
    }
    if (walletId.present) {
      map['wallet_id'] = Variable<String>(walletId.value);
    }
    if (ledgerIndex.present) {
      map['ledger_index'] = Variable<int>(ledgerIndex.value);
    }
    if (txType.present) {
      map['tx_type'] = Variable<String>(txType.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (amountSummary.present) {
      map['amount_summary'] = Variable<String>(amountSummary.value);
    }
    if (counterpart.present) {
      map['counterpart'] = Variable<String>(counterpart.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedTxsCompanion(')
          ..write('hash: $hash, ')
          ..write('walletId: $walletId, ')
          ..write('ledgerIndex: $ledgerIndex, ')
          ..write('txType: $txType, ')
          ..write('direction: $direction, ')
          ..write('amountSummary: $amountSummary, ')
          ..write('counterpart: $counterpart, ')
          ..write('date: $date, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsRowsTable extends AppSettingsRows
    with TableInfo<$AppSettingsRowsTable, AppSettingsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSettingsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSettingsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSettingsRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppSettingsRowsTable createAlias(String alias) {
    return $AppSettingsRowsTable(attachedDatabase, alias);
  }
}

class AppSettingsRow extends DataClass implements Insertable<AppSettingsRow> {
  final String key;
  final String value;
  const AppSettingsRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsRowsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsRowsCompanion(key: Value(key), value: Value(value));
  }

  factory AppSettingsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSettingsRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSettingsRow copyWith({String? key, String? value}) =>
      AppSettingsRow(key: key ?? this.key, value: value ?? this.value);
  AppSettingsRow copyWithCompanion(AppSettingsRowsCompanion data) {
    return AppSettingsRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettingsRow &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsRowsCompanion extends UpdateCompanion<AppSettingsRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsRowsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsRowsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppSettingsRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsRowsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppSettingsRowsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsRowsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TradeExecutionsTable extends TradeExecutions
    with TableInfo<$TradeExecutionsTable, TradeExecution> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TradeExecutionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _walletIdMeta = const VerificationMeta(
    'walletId',
  );
  @override
  late final GeneratedColumn<String> walletId = GeneratedColumn<String>(
    'wallet_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _networkMeta = const VerificationMeta(
    'network',
  );
  @override
  late final GeneratedColumn<String> network = GeneratedColumn<String>(
    'network',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sideMeta = const VerificationMeta('side');
  @override
  late final GeneratedColumn<String> side = GeneratedColumn<String>(
    'side',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseCurrencyMeta = const VerificationMeta(
    'baseCurrency',
  );
  @override
  late final GeneratedColumn<String> baseCurrency = GeneratedColumn<String>(
    'base_currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseIssuerMeta = const VerificationMeta(
    'baseIssuer',
  );
  @override
  late final GeneratedColumn<String> baseIssuer = GeneratedColumn<String>(
    'base_issuer',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _quoteCurrencyMeta = const VerificationMeta(
    'quoteCurrency',
  );
  @override
  late final GeneratedColumn<String> quoteCurrency = GeneratedColumn<String>(
    'quote_currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quoteIssuerMeta = const VerificationMeta(
    'quoteIssuer',
  );
  @override
  late final GeneratedColumn<String> quoteIssuer = GeneratedColumn<String>(
    'quote_issuer',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetAmountMeta = const VerificationMeta(
    'targetAmount',
  );
  @override
  late final GeneratedColumn<String> targetAmount = GeneratedColumn<String>(
    'target_amount',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filledAmountMeta = const VerificationMeta(
    'filledAmount',
  );
  @override
  late final GeneratedColumn<String> filledAmount = GeneratedColumn<String>(
    'filled_amount',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('0'),
  );
  static const VerificationMeta _orderTypeMeta = const VerificationMeta(
    'orderType',
  );
  @override
  late final GeneratedColumn<String> orderType = GeneratedColumn<String>(
    'order_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _txHashMeta = const VerificationMeta('txHash');
  @override
  late final GeneratedColumn<String> txHash = GeneratedColumn<String>(
    'tx_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _offerSequenceMeta = const VerificationMeta(
    'offerSequence',
  );
  @override
  late final GeneratedColumn<int> offerSequence = GeneratedColumn<int>(
    'offer_sequence',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastLedgerSequenceMeta =
      const VerificationMeta('lastLedgerSequence');
  @override
  late final GeneratedColumn<int> lastLedgerSequence = GeneratedColumn<int>(
    'last_ledger_sequence',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastLedgerIndexMeta = const VerificationMeta(
    'lastLedgerIndex',
  );
  @override
  late final GeneratedColumn<int> lastLedgerIndex = GeneratedColumn<int>(
    'last_ledger_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _expirationMeta = const VerificationMeta(
    'expiration',
  );
  @override
  late final GeneratedColumn<DateTime> expiration = GeneratedColumn<DateTime>(
    'expiration',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    walletId,
    network,
    side,
    baseCurrency,
    baseIssuer,
    quoteCurrency,
    quoteIssuer,
    targetAmount,
    filledAmount,
    orderType,
    status,
    lastError,
    txHash,
    offerSequence,
    lastLedgerSequence,
    lastLedgerIndex,
    expiration,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trade_executions';
  @override
  VerificationContext validateIntegrity(
    Insertable<TradeExecution> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('wallet_id')) {
      context.handle(
        _walletIdMeta,
        walletId.isAcceptableOrUnknown(data['wallet_id']!, _walletIdMeta),
      );
    } else if (isInserting) {
      context.missing(_walletIdMeta);
    }
    if (data.containsKey('network')) {
      context.handle(
        _networkMeta,
        network.isAcceptableOrUnknown(data['network']!, _networkMeta),
      );
    } else if (isInserting) {
      context.missing(_networkMeta);
    }
    if (data.containsKey('side')) {
      context.handle(
        _sideMeta,
        side.isAcceptableOrUnknown(data['side']!, _sideMeta),
      );
    } else if (isInserting) {
      context.missing(_sideMeta);
    }
    if (data.containsKey('base_currency')) {
      context.handle(
        _baseCurrencyMeta,
        baseCurrency.isAcceptableOrUnknown(
          data['base_currency']!,
          _baseCurrencyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_baseCurrencyMeta);
    }
    if (data.containsKey('base_issuer')) {
      context.handle(
        _baseIssuerMeta,
        baseIssuer.isAcceptableOrUnknown(data['base_issuer']!, _baseIssuerMeta),
      );
    }
    if (data.containsKey('quote_currency')) {
      context.handle(
        _quoteCurrencyMeta,
        quoteCurrency.isAcceptableOrUnknown(
          data['quote_currency']!,
          _quoteCurrencyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_quoteCurrencyMeta);
    }
    if (data.containsKey('quote_issuer')) {
      context.handle(
        _quoteIssuerMeta,
        quoteIssuer.isAcceptableOrUnknown(
          data['quote_issuer']!,
          _quoteIssuerMeta,
        ),
      );
    }
    if (data.containsKey('target_amount')) {
      context.handle(
        _targetAmountMeta,
        targetAmount.isAcceptableOrUnknown(
          data['target_amount']!,
          _targetAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetAmountMeta);
    }
    if (data.containsKey('filled_amount')) {
      context.handle(
        _filledAmountMeta,
        filledAmount.isAcceptableOrUnknown(
          data['filled_amount']!,
          _filledAmountMeta,
        ),
      );
    }
    if (data.containsKey('order_type')) {
      context.handle(
        _orderTypeMeta,
        orderType.isAcceptableOrUnknown(data['order_type']!, _orderTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_orderTypeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('tx_hash')) {
      context.handle(
        _txHashMeta,
        txHash.isAcceptableOrUnknown(data['tx_hash']!, _txHashMeta),
      );
    }
    if (data.containsKey('offer_sequence')) {
      context.handle(
        _offerSequenceMeta,
        offerSequence.isAcceptableOrUnknown(
          data['offer_sequence']!,
          _offerSequenceMeta,
        ),
      );
    }
    if (data.containsKey('last_ledger_sequence')) {
      context.handle(
        _lastLedgerSequenceMeta,
        lastLedgerSequence.isAcceptableOrUnknown(
          data['last_ledger_sequence']!,
          _lastLedgerSequenceMeta,
        ),
      );
    }
    if (data.containsKey('last_ledger_index')) {
      context.handle(
        _lastLedgerIndexMeta,
        lastLedgerIndex.isAcceptableOrUnknown(
          data['last_ledger_index']!,
          _lastLedgerIndexMeta,
        ),
      );
    }
    if (data.containsKey('expiration')) {
      context.handle(
        _expirationMeta,
        expiration.isAcceptableOrUnknown(data['expiration']!, _expirationMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TradeExecution map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TradeExecution(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      walletId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wallet_id'],
      )!,
      network: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}network'],
      )!,
      side: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}side'],
      )!,
      baseCurrency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_currency'],
      )!,
      baseIssuer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_issuer'],
      ),
      quoteCurrency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quote_currency'],
      )!,
      quoteIssuer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quote_issuer'],
      ),
      targetAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_amount'],
      )!,
      filledAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}filled_amount'],
      )!,
      orderType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}order_type'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      txHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tx_hash'],
      ),
      offerSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}offer_sequence'],
      ),
      lastLedgerSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_ledger_sequence'],
      ),
      lastLedgerIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_ledger_index'],
      ),
      expiration: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expiration'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TradeExecutionsTable createAlias(String alias) {
    return $TradeExecutionsTable(attachedDatabase, alias);
  }
}

class TradeExecution extends DataClass implements Insertable<TradeExecution> {
  final String id;
  final String walletId;
  final String network;

  /// `buy` or `sell`, read as "…the base asset".
  final String side;

  /// Asset given up. Issuer is null for XRP.
  final String baseCurrency;
  final String? baseIssuer;

  /// Asset wanted. Issuer is null for XRP.
  final String quoteCurrency;
  final String? quoteIssuer;
  final String targetAmount;

  /// Sum of `TradeFills.filledBase`, maintained by the reconciler from
  /// validated ledger metadata — never by client-side subtraction.
  final String filledAmount;

  /// `market` (IOC/FOK) or `limit` (resting).
  final String orderType;
  final String status;
  final String? lastError;

  /// Hash of the submitted OfferCreate, once known.
  final String? txHash;

  /// Sequence of the resting offer this order created, for OfferCancel and
  /// for matching `account_offers`.
  final int? offerSequence;

  /// `LastLedgerSequence` of the submitted transaction. Past this ledger with
  /// no validated result ⇒ definitively failed, safe to retry.
  final int? lastLedgerSequence;

  /// Ledger index the reconciler last checked against.
  final int? lastLedgerIndex;

  /// Optional XRPL `Expiration` on a resting offer.
  final DateTime? expiration;
  final DateTime createdAt;
  final DateTime updatedAt;
  const TradeExecution({
    required this.id,
    required this.walletId,
    required this.network,
    required this.side,
    required this.baseCurrency,
    this.baseIssuer,
    required this.quoteCurrency,
    this.quoteIssuer,
    required this.targetAmount,
    required this.filledAmount,
    required this.orderType,
    required this.status,
    this.lastError,
    this.txHash,
    this.offerSequence,
    this.lastLedgerSequence,
    this.lastLedgerIndex,
    this.expiration,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['wallet_id'] = Variable<String>(walletId);
    map['network'] = Variable<String>(network);
    map['side'] = Variable<String>(side);
    map['base_currency'] = Variable<String>(baseCurrency);
    if (!nullToAbsent || baseIssuer != null) {
      map['base_issuer'] = Variable<String>(baseIssuer);
    }
    map['quote_currency'] = Variable<String>(quoteCurrency);
    if (!nullToAbsent || quoteIssuer != null) {
      map['quote_issuer'] = Variable<String>(quoteIssuer);
    }
    map['target_amount'] = Variable<String>(targetAmount);
    map['filled_amount'] = Variable<String>(filledAmount);
    map['order_type'] = Variable<String>(orderType);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || txHash != null) {
      map['tx_hash'] = Variable<String>(txHash);
    }
    if (!nullToAbsent || offerSequence != null) {
      map['offer_sequence'] = Variable<int>(offerSequence);
    }
    if (!nullToAbsent || lastLedgerSequence != null) {
      map['last_ledger_sequence'] = Variable<int>(lastLedgerSequence);
    }
    if (!nullToAbsent || lastLedgerIndex != null) {
      map['last_ledger_index'] = Variable<int>(lastLedgerIndex);
    }
    if (!nullToAbsent || expiration != null) {
      map['expiration'] = Variable<DateTime>(expiration);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TradeExecutionsCompanion toCompanion(bool nullToAbsent) {
    return TradeExecutionsCompanion(
      id: Value(id),
      walletId: Value(walletId),
      network: Value(network),
      side: Value(side),
      baseCurrency: Value(baseCurrency),
      baseIssuer: baseIssuer == null && nullToAbsent
          ? const Value.absent()
          : Value(baseIssuer),
      quoteCurrency: Value(quoteCurrency),
      quoteIssuer: quoteIssuer == null && nullToAbsent
          ? const Value.absent()
          : Value(quoteIssuer),
      targetAmount: Value(targetAmount),
      filledAmount: Value(filledAmount),
      orderType: Value(orderType),
      status: Value(status),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      txHash: txHash == null && nullToAbsent
          ? const Value.absent()
          : Value(txHash),
      offerSequence: offerSequence == null && nullToAbsent
          ? const Value.absent()
          : Value(offerSequence),
      lastLedgerSequence: lastLedgerSequence == null && nullToAbsent
          ? const Value.absent()
          : Value(lastLedgerSequence),
      lastLedgerIndex: lastLedgerIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(lastLedgerIndex),
      expiration: expiration == null && nullToAbsent
          ? const Value.absent()
          : Value(expiration),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TradeExecution.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TradeExecution(
      id: serializer.fromJson<String>(json['id']),
      walletId: serializer.fromJson<String>(json['walletId']),
      network: serializer.fromJson<String>(json['network']),
      side: serializer.fromJson<String>(json['side']),
      baseCurrency: serializer.fromJson<String>(json['baseCurrency']),
      baseIssuer: serializer.fromJson<String?>(json['baseIssuer']),
      quoteCurrency: serializer.fromJson<String>(json['quoteCurrency']),
      quoteIssuer: serializer.fromJson<String?>(json['quoteIssuer']),
      targetAmount: serializer.fromJson<String>(json['targetAmount']),
      filledAmount: serializer.fromJson<String>(json['filledAmount']),
      orderType: serializer.fromJson<String>(json['orderType']),
      status: serializer.fromJson<String>(json['status']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      txHash: serializer.fromJson<String?>(json['txHash']),
      offerSequence: serializer.fromJson<int?>(json['offerSequence']),
      lastLedgerSequence: serializer.fromJson<int?>(json['lastLedgerSequence']),
      lastLedgerIndex: serializer.fromJson<int?>(json['lastLedgerIndex']),
      expiration: serializer.fromJson<DateTime?>(json['expiration']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'walletId': serializer.toJson<String>(walletId),
      'network': serializer.toJson<String>(network),
      'side': serializer.toJson<String>(side),
      'baseCurrency': serializer.toJson<String>(baseCurrency),
      'baseIssuer': serializer.toJson<String?>(baseIssuer),
      'quoteCurrency': serializer.toJson<String>(quoteCurrency),
      'quoteIssuer': serializer.toJson<String?>(quoteIssuer),
      'targetAmount': serializer.toJson<String>(targetAmount),
      'filledAmount': serializer.toJson<String>(filledAmount),
      'orderType': serializer.toJson<String>(orderType),
      'status': serializer.toJson<String>(status),
      'lastError': serializer.toJson<String?>(lastError),
      'txHash': serializer.toJson<String?>(txHash),
      'offerSequence': serializer.toJson<int?>(offerSequence),
      'lastLedgerSequence': serializer.toJson<int?>(lastLedgerSequence),
      'lastLedgerIndex': serializer.toJson<int?>(lastLedgerIndex),
      'expiration': serializer.toJson<DateTime?>(expiration),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TradeExecution copyWith({
    String? id,
    String? walletId,
    String? network,
    String? side,
    String? baseCurrency,
    Value<String?> baseIssuer = const Value.absent(),
    String? quoteCurrency,
    Value<String?> quoteIssuer = const Value.absent(),
    String? targetAmount,
    String? filledAmount,
    String? orderType,
    String? status,
    Value<String?> lastError = const Value.absent(),
    Value<String?> txHash = const Value.absent(),
    Value<int?> offerSequence = const Value.absent(),
    Value<int?> lastLedgerSequence = const Value.absent(),
    Value<int?> lastLedgerIndex = const Value.absent(),
    Value<DateTime?> expiration = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TradeExecution(
    id: id ?? this.id,
    walletId: walletId ?? this.walletId,
    network: network ?? this.network,
    side: side ?? this.side,
    baseCurrency: baseCurrency ?? this.baseCurrency,
    baseIssuer: baseIssuer.present ? baseIssuer.value : this.baseIssuer,
    quoteCurrency: quoteCurrency ?? this.quoteCurrency,
    quoteIssuer: quoteIssuer.present ? quoteIssuer.value : this.quoteIssuer,
    targetAmount: targetAmount ?? this.targetAmount,
    filledAmount: filledAmount ?? this.filledAmount,
    orderType: orderType ?? this.orderType,
    status: status ?? this.status,
    lastError: lastError.present ? lastError.value : this.lastError,
    txHash: txHash.present ? txHash.value : this.txHash,
    offerSequence: offerSequence.present
        ? offerSequence.value
        : this.offerSequence,
    lastLedgerSequence: lastLedgerSequence.present
        ? lastLedgerSequence.value
        : this.lastLedgerSequence,
    lastLedgerIndex: lastLedgerIndex.present
        ? lastLedgerIndex.value
        : this.lastLedgerIndex,
    expiration: expiration.present ? expiration.value : this.expiration,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TradeExecution copyWithCompanion(TradeExecutionsCompanion data) {
    return TradeExecution(
      id: data.id.present ? data.id.value : this.id,
      walletId: data.walletId.present ? data.walletId.value : this.walletId,
      network: data.network.present ? data.network.value : this.network,
      side: data.side.present ? data.side.value : this.side,
      baseCurrency: data.baseCurrency.present
          ? data.baseCurrency.value
          : this.baseCurrency,
      baseIssuer: data.baseIssuer.present
          ? data.baseIssuer.value
          : this.baseIssuer,
      quoteCurrency: data.quoteCurrency.present
          ? data.quoteCurrency.value
          : this.quoteCurrency,
      quoteIssuer: data.quoteIssuer.present
          ? data.quoteIssuer.value
          : this.quoteIssuer,
      targetAmount: data.targetAmount.present
          ? data.targetAmount.value
          : this.targetAmount,
      filledAmount: data.filledAmount.present
          ? data.filledAmount.value
          : this.filledAmount,
      orderType: data.orderType.present ? data.orderType.value : this.orderType,
      status: data.status.present ? data.status.value : this.status,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      txHash: data.txHash.present ? data.txHash.value : this.txHash,
      offerSequence: data.offerSequence.present
          ? data.offerSequence.value
          : this.offerSequence,
      lastLedgerSequence: data.lastLedgerSequence.present
          ? data.lastLedgerSequence.value
          : this.lastLedgerSequence,
      lastLedgerIndex: data.lastLedgerIndex.present
          ? data.lastLedgerIndex.value
          : this.lastLedgerIndex,
      expiration: data.expiration.present
          ? data.expiration.value
          : this.expiration,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TradeExecution(')
          ..write('id: $id, ')
          ..write('walletId: $walletId, ')
          ..write('network: $network, ')
          ..write('side: $side, ')
          ..write('baseCurrency: $baseCurrency, ')
          ..write('baseIssuer: $baseIssuer, ')
          ..write('quoteCurrency: $quoteCurrency, ')
          ..write('quoteIssuer: $quoteIssuer, ')
          ..write('targetAmount: $targetAmount, ')
          ..write('filledAmount: $filledAmount, ')
          ..write('orderType: $orderType, ')
          ..write('status: $status, ')
          ..write('lastError: $lastError, ')
          ..write('txHash: $txHash, ')
          ..write('offerSequence: $offerSequence, ')
          ..write('lastLedgerSequence: $lastLedgerSequence, ')
          ..write('lastLedgerIndex: $lastLedgerIndex, ')
          ..write('expiration: $expiration, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    walletId,
    network,
    side,
    baseCurrency,
    baseIssuer,
    quoteCurrency,
    quoteIssuer,
    targetAmount,
    filledAmount,
    orderType,
    status,
    lastError,
    txHash,
    offerSequence,
    lastLedgerSequence,
    lastLedgerIndex,
    expiration,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TradeExecution &&
          other.id == this.id &&
          other.walletId == this.walletId &&
          other.network == this.network &&
          other.side == this.side &&
          other.baseCurrency == this.baseCurrency &&
          other.baseIssuer == this.baseIssuer &&
          other.quoteCurrency == this.quoteCurrency &&
          other.quoteIssuer == this.quoteIssuer &&
          other.targetAmount == this.targetAmount &&
          other.filledAmount == this.filledAmount &&
          other.orderType == this.orderType &&
          other.status == this.status &&
          other.lastError == this.lastError &&
          other.txHash == this.txHash &&
          other.offerSequence == this.offerSequence &&
          other.lastLedgerSequence == this.lastLedgerSequence &&
          other.lastLedgerIndex == this.lastLedgerIndex &&
          other.expiration == this.expiration &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TradeExecutionsCompanion extends UpdateCompanion<TradeExecution> {
  final Value<String> id;
  final Value<String> walletId;
  final Value<String> network;
  final Value<String> side;
  final Value<String> baseCurrency;
  final Value<String?> baseIssuer;
  final Value<String> quoteCurrency;
  final Value<String?> quoteIssuer;
  final Value<String> targetAmount;
  final Value<String> filledAmount;
  final Value<String> orderType;
  final Value<String> status;
  final Value<String?> lastError;
  final Value<String?> txHash;
  final Value<int?> offerSequence;
  final Value<int?> lastLedgerSequence;
  final Value<int?> lastLedgerIndex;
  final Value<DateTime?> expiration;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const TradeExecutionsCompanion({
    this.id = const Value.absent(),
    this.walletId = const Value.absent(),
    this.network = const Value.absent(),
    this.side = const Value.absent(),
    this.baseCurrency = const Value.absent(),
    this.baseIssuer = const Value.absent(),
    this.quoteCurrency = const Value.absent(),
    this.quoteIssuer = const Value.absent(),
    this.targetAmount = const Value.absent(),
    this.filledAmount = const Value.absent(),
    this.orderType = const Value.absent(),
    this.status = const Value.absent(),
    this.lastError = const Value.absent(),
    this.txHash = const Value.absent(),
    this.offerSequence = const Value.absent(),
    this.lastLedgerSequence = const Value.absent(),
    this.lastLedgerIndex = const Value.absent(),
    this.expiration = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TradeExecutionsCompanion.insert({
    required String id,
    required String walletId,
    required String network,
    required String side,
    required String baseCurrency,
    this.baseIssuer = const Value.absent(),
    required String quoteCurrency,
    this.quoteIssuer = const Value.absent(),
    required String targetAmount,
    this.filledAmount = const Value.absent(),
    required String orderType,
    required String status,
    this.lastError = const Value.absent(),
    this.txHash = const Value.absent(),
    this.offerSequence = const Value.absent(),
    this.lastLedgerSequence = const Value.absent(),
    this.lastLedgerIndex = const Value.absent(),
    this.expiration = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       walletId = Value(walletId),
       network = Value(network),
       side = Value(side),
       baseCurrency = Value(baseCurrency),
       quoteCurrency = Value(quoteCurrency),
       targetAmount = Value(targetAmount),
       orderType = Value(orderType),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TradeExecution> custom({
    Expression<String>? id,
    Expression<String>? walletId,
    Expression<String>? network,
    Expression<String>? side,
    Expression<String>? baseCurrency,
    Expression<String>? baseIssuer,
    Expression<String>? quoteCurrency,
    Expression<String>? quoteIssuer,
    Expression<String>? targetAmount,
    Expression<String>? filledAmount,
    Expression<String>? orderType,
    Expression<String>? status,
    Expression<String>? lastError,
    Expression<String>? txHash,
    Expression<int>? offerSequence,
    Expression<int>? lastLedgerSequence,
    Expression<int>? lastLedgerIndex,
    Expression<DateTime>? expiration,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (walletId != null) 'wallet_id': walletId,
      if (network != null) 'network': network,
      if (side != null) 'side': side,
      if (baseCurrency != null) 'base_currency': baseCurrency,
      if (baseIssuer != null) 'base_issuer': baseIssuer,
      if (quoteCurrency != null) 'quote_currency': quoteCurrency,
      if (quoteIssuer != null) 'quote_issuer': quoteIssuer,
      if (targetAmount != null) 'target_amount': targetAmount,
      if (filledAmount != null) 'filled_amount': filledAmount,
      if (orderType != null) 'order_type': orderType,
      if (status != null) 'status': status,
      if (lastError != null) 'last_error': lastError,
      if (txHash != null) 'tx_hash': txHash,
      if (offerSequence != null) 'offer_sequence': offerSequence,
      if (lastLedgerSequence != null)
        'last_ledger_sequence': lastLedgerSequence,
      if (lastLedgerIndex != null) 'last_ledger_index': lastLedgerIndex,
      if (expiration != null) 'expiration': expiration,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TradeExecutionsCompanion copyWith({
    Value<String>? id,
    Value<String>? walletId,
    Value<String>? network,
    Value<String>? side,
    Value<String>? baseCurrency,
    Value<String?>? baseIssuer,
    Value<String>? quoteCurrency,
    Value<String?>? quoteIssuer,
    Value<String>? targetAmount,
    Value<String>? filledAmount,
    Value<String>? orderType,
    Value<String>? status,
    Value<String?>? lastError,
    Value<String?>? txHash,
    Value<int?>? offerSequence,
    Value<int?>? lastLedgerSequence,
    Value<int?>? lastLedgerIndex,
    Value<DateTime?>? expiration,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return TradeExecutionsCompanion(
      id: id ?? this.id,
      walletId: walletId ?? this.walletId,
      network: network ?? this.network,
      side: side ?? this.side,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      baseIssuer: baseIssuer ?? this.baseIssuer,
      quoteCurrency: quoteCurrency ?? this.quoteCurrency,
      quoteIssuer: quoteIssuer ?? this.quoteIssuer,
      targetAmount: targetAmount ?? this.targetAmount,
      filledAmount: filledAmount ?? this.filledAmount,
      orderType: orderType ?? this.orderType,
      status: status ?? this.status,
      lastError: lastError ?? this.lastError,
      txHash: txHash ?? this.txHash,
      offerSequence: offerSequence ?? this.offerSequence,
      lastLedgerSequence: lastLedgerSequence ?? this.lastLedgerSequence,
      lastLedgerIndex: lastLedgerIndex ?? this.lastLedgerIndex,
      expiration: expiration ?? this.expiration,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (walletId.present) {
      map['wallet_id'] = Variable<String>(walletId.value);
    }
    if (network.present) {
      map['network'] = Variable<String>(network.value);
    }
    if (side.present) {
      map['side'] = Variable<String>(side.value);
    }
    if (baseCurrency.present) {
      map['base_currency'] = Variable<String>(baseCurrency.value);
    }
    if (baseIssuer.present) {
      map['base_issuer'] = Variable<String>(baseIssuer.value);
    }
    if (quoteCurrency.present) {
      map['quote_currency'] = Variable<String>(quoteCurrency.value);
    }
    if (quoteIssuer.present) {
      map['quote_issuer'] = Variable<String>(quoteIssuer.value);
    }
    if (targetAmount.present) {
      map['target_amount'] = Variable<String>(targetAmount.value);
    }
    if (filledAmount.present) {
      map['filled_amount'] = Variable<String>(filledAmount.value);
    }
    if (orderType.present) {
      map['order_type'] = Variable<String>(orderType.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (txHash.present) {
      map['tx_hash'] = Variable<String>(txHash.value);
    }
    if (offerSequence.present) {
      map['offer_sequence'] = Variable<int>(offerSequence.value);
    }
    if (lastLedgerSequence.present) {
      map['last_ledger_sequence'] = Variable<int>(lastLedgerSequence.value);
    }
    if (lastLedgerIndex.present) {
      map['last_ledger_index'] = Variable<int>(lastLedgerIndex.value);
    }
    if (expiration.present) {
      map['expiration'] = Variable<DateTime>(expiration.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TradeExecutionsCompanion(')
          ..write('id: $id, ')
          ..write('walletId: $walletId, ')
          ..write('network: $network, ')
          ..write('side: $side, ')
          ..write('baseCurrency: $baseCurrency, ')
          ..write('baseIssuer: $baseIssuer, ')
          ..write('quoteCurrency: $quoteCurrency, ')
          ..write('quoteIssuer: $quoteIssuer, ')
          ..write('targetAmount: $targetAmount, ')
          ..write('filledAmount: $filledAmount, ')
          ..write('orderType: $orderType, ')
          ..write('status: $status, ')
          ..write('lastError: $lastError, ')
          ..write('txHash: $txHash, ')
          ..write('offerSequence: $offerSequence, ')
          ..write('lastLedgerSequence: $lastLedgerSequence, ')
          ..write('lastLedgerIndex: $lastLedgerIndex, ')
          ..write('expiration: $expiration, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TradeFillsTable extends TradeFills
    with TableInfo<$TradeFillsTable, TradeFill> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TradeFillsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _executionIdMeta = const VerificationMeta(
    'executionId',
  );
  @override
  late final GeneratedColumn<String> executionId = GeneratedColumn<String>(
    'execution_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _txHashMeta = const VerificationMeta('txHash');
  @override
  late final GeneratedColumn<String> txHash = GeneratedColumn<String>(
    'tx_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ledgerIndexMeta = const VerificationMeta(
    'ledgerIndex',
  );
  @override
  late final GeneratedColumn<int> ledgerIndex = GeneratedColumn<int>(
    'ledger_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filledBaseMeta = const VerificationMeta(
    'filledBase',
  );
  @override
  late final GeneratedColumn<String> filledBase = GeneratedColumn<String>(
    'filled_base',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filledQuoteMeta = const VerificationMeta(
    'filledQuote',
  );
  @override
  late final GeneratedColumn<String> filledQuote = GeneratedColumn<String>(
    'filled_quote',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rateMeta = const VerificationMeta('rate');
  @override
  late final GeneratedColumn<String> rate = GeneratedColumn<String>(
    'rate',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _feeDropsMeta = const VerificationMeta(
    'feeDrops',
  );
  @override
  late final GeneratedColumn<String> feeDrops = GeneratedColumn<String>(
    'fee_drops',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    executionId,
    txHash,
    ledgerIndex,
    filledBase,
    filledQuote,
    rate,
    feeDrops,
    date,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trade_fills';
  @override
  VerificationContext validateIntegrity(
    Insertable<TradeFill> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('execution_id')) {
      context.handle(
        _executionIdMeta,
        executionId.isAcceptableOrUnknown(
          data['execution_id']!,
          _executionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_executionIdMeta);
    }
    if (data.containsKey('tx_hash')) {
      context.handle(
        _txHashMeta,
        txHash.isAcceptableOrUnknown(data['tx_hash']!, _txHashMeta),
      );
    } else if (isInserting) {
      context.missing(_txHashMeta);
    }
    if (data.containsKey('ledger_index')) {
      context.handle(
        _ledgerIndexMeta,
        ledgerIndex.isAcceptableOrUnknown(
          data['ledger_index']!,
          _ledgerIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ledgerIndexMeta);
    }
    if (data.containsKey('filled_base')) {
      context.handle(
        _filledBaseMeta,
        filledBase.isAcceptableOrUnknown(data['filled_base']!, _filledBaseMeta),
      );
    } else if (isInserting) {
      context.missing(_filledBaseMeta);
    }
    if (data.containsKey('filled_quote')) {
      context.handle(
        _filledQuoteMeta,
        filledQuote.isAcceptableOrUnknown(
          data['filled_quote']!,
          _filledQuoteMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_filledQuoteMeta);
    }
    if (data.containsKey('rate')) {
      context.handle(
        _rateMeta,
        rate.isAcceptableOrUnknown(data['rate']!, _rateMeta),
      );
    } else if (isInserting) {
      context.missing(_rateMeta);
    }
    if (data.containsKey('fee_drops')) {
      context.handle(
        _feeDropsMeta,
        feeDrops.isAcceptableOrUnknown(data['fee_drops']!, _feeDropsMeta),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {executionId, txHash};
  @override
  TradeFill map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TradeFill(
      executionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}execution_id'],
      )!,
      txHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tx_hash'],
      )!,
      ledgerIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ledger_index'],
      )!,
      filledBase: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}filled_base'],
      )!,
      filledQuote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}filled_quote'],
      )!,
      rate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rate'],
      )!,
      feeDrops: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fee_drops'],
      ),
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
    );
  }

  @override
  $TradeFillsTable createAlias(String alias) {
    return $TradeFillsTable(attachedDatabase, alias);
  }
}

class TradeFill extends DataClass implements Insertable<TradeFill> {
  final String executionId;
  final String txHash;
  final int ledgerIndex;

  /// Amounts actually exchanged in this fill, as ledger-reported strings.
  final String filledBase;
  final String filledQuote;

  /// Executed rate for this fill (quote per base), as a decimal string.
  final String rate;
  final String? feeDrops;
  final DateTime date;
  const TradeFill({
    required this.executionId,
    required this.txHash,
    required this.ledgerIndex,
    required this.filledBase,
    required this.filledQuote,
    required this.rate,
    this.feeDrops,
    required this.date,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['execution_id'] = Variable<String>(executionId);
    map['tx_hash'] = Variable<String>(txHash);
    map['ledger_index'] = Variable<int>(ledgerIndex);
    map['filled_base'] = Variable<String>(filledBase);
    map['filled_quote'] = Variable<String>(filledQuote);
    map['rate'] = Variable<String>(rate);
    if (!nullToAbsent || feeDrops != null) {
      map['fee_drops'] = Variable<String>(feeDrops);
    }
    map['date'] = Variable<DateTime>(date);
    return map;
  }

  TradeFillsCompanion toCompanion(bool nullToAbsent) {
    return TradeFillsCompanion(
      executionId: Value(executionId),
      txHash: Value(txHash),
      ledgerIndex: Value(ledgerIndex),
      filledBase: Value(filledBase),
      filledQuote: Value(filledQuote),
      rate: Value(rate),
      feeDrops: feeDrops == null && nullToAbsent
          ? const Value.absent()
          : Value(feeDrops),
      date: Value(date),
    );
  }

  factory TradeFill.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TradeFill(
      executionId: serializer.fromJson<String>(json['executionId']),
      txHash: serializer.fromJson<String>(json['txHash']),
      ledgerIndex: serializer.fromJson<int>(json['ledgerIndex']),
      filledBase: serializer.fromJson<String>(json['filledBase']),
      filledQuote: serializer.fromJson<String>(json['filledQuote']),
      rate: serializer.fromJson<String>(json['rate']),
      feeDrops: serializer.fromJson<String?>(json['feeDrops']),
      date: serializer.fromJson<DateTime>(json['date']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'executionId': serializer.toJson<String>(executionId),
      'txHash': serializer.toJson<String>(txHash),
      'ledgerIndex': serializer.toJson<int>(ledgerIndex),
      'filledBase': serializer.toJson<String>(filledBase),
      'filledQuote': serializer.toJson<String>(filledQuote),
      'rate': serializer.toJson<String>(rate),
      'feeDrops': serializer.toJson<String?>(feeDrops),
      'date': serializer.toJson<DateTime>(date),
    };
  }

  TradeFill copyWith({
    String? executionId,
    String? txHash,
    int? ledgerIndex,
    String? filledBase,
    String? filledQuote,
    String? rate,
    Value<String?> feeDrops = const Value.absent(),
    DateTime? date,
  }) => TradeFill(
    executionId: executionId ?? this.executionId,
    txHash: txHash ?? this.txHash,
    ledgerIndex: ledgerIndex ?? this.ledgerIndex,
    filledBase: filledBase ?? this.filledBase,
    filledQuote: filledQuote ?? this.filledQuote,
    rate: rate ?? this.rate,
    feeDrops: feeDrops.present ? feeDrops.value : this.feeDrops,
    date: date ?? this.date,
  );
  TradeFill copyWithCompanion(TradeFillsCompanion data) {
    return TradeFill(
      executionId: data.executionId.present
          ? data.executionId.value
          : this.executionId,
      txHash: data.txHash.present ? data.txHash.value : this.txHash,
      ledgerIndex: data.ledgerIndex.present
          ? data.ledgerIndex.value
          : this.ledgerIndex,
      filledBase: data.filledBase.present
          ? data.filledBase.value
          : this.filledBase,
      filledQuote: data.filledQuote.present
          ? data.filledQuote.value
          : this.filledQuote,
      rate: data.rate.present ? data.rate.value : this.rate,
      feeDrops: data.feeDrops.present ? data.feeDrops.value : this.feeDrops,
      date: data.date.present ? data.date.value : this.date,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TradeFill(')
          ..write('executionId: $executionId, ')
          ..write('txHash: $txHash, ')
          ..write('ledgerIndex: $ledgerIndex, ')
          ..write('filledBase: $filledBase, ')
          ..write('filledQuote: $filledQuote, ')
          ..write('rate: $rate, ')
          ..write('feeDrops: $feeDrops, ')
          ..write('date: $date')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    executionId,
    txHash,
    ledgerIndex,
    filledBase,
    filledQuote,
    rate,
    feeDrops,
    date,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TradeFill &&
          other.executionId == this.executionId &&
          other.txHash == this.txHash &&
          other.ledgerIndex == this.ledgerIndex &&
          other.filledBase == this.filledBase &&
          other.filledQuote == this.filledQuote &&
          other.rate == this.rate &&
          other.feeDrops == this.feeDrops &&
          other.date == this.date);
}

class TradeFillsCompanion extends UpdateCompanion<TradeFill> {
  final Value<String> executionId;
  final Value<String> txHash;
  final Value<int> ledgerIndex;
  final Value<String> filledBase;
  final Value<String> filledQuote;
  final Value<String> rate;
  final Value<String?> feeDrops;
  final Value<DateTime> date;
  final Value<int> rowid;
  const TradeFillsCompanion({
    this.executionId = const Value.absent(),
    this.txHash = const Value.absent(),
    this.ledgerIndex = const Value.absent(),
    this.filledBase = const Value.absent(),
    this.filledQuote = const Value.absent(),
    this.rate = const Value.absent(),
    this.feeDrops = const Value.absent(),
    this.date = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TradeFillsCompanion.insert({
    required String executionId,
    required String txHash,
    required int ledgerIndex,
    required String filledBase,
    required String filledQuote,
    required String rate,
    this.feeDrops = const Value.absent(),
    required DateTime date,
    this.rowid = const Value.absent(),
  }) : executionId = Value(executionId),
       txHash = Value(txHash),
       ledgerIndex = Value(ledgerIndex),
       filledBase = Value(filledBase),
       filledQuote = Value(filledQuote),
       rate = Value(rate),
       date = Value(date);
  static Insertable<TradeFill> custom({
    Expression<String>? executionId,
    Expression<String>? txHash,
    Expression<int>? ledgerIndex,
    Expression<String>? filledBase,
    Expression<String>? filledQuote,
    Expression<String>? rate,
    Expression<String>? feeDrops,
    Expression<DateTime>? date,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (executionId != null) 'execution_id': executionId,
      if (txHash != null) 'tx_hash': txHash,
      if (ledgerIndex != null) 'ledger_index': ledgerIndex,
      if (filledBase != null) 'filled_base': filledBase,
      if (filledQuote != null) 'filled_quote': filledQuote,
      if (rate != null) 'rate': rate,
      if (feeDrops != null) 'fee_drops': feeDrops,
      if (date != null) 'date': date,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TradeFillsCompanion copyWith({
    Value<String>? executionId,
    Value<String>? txHash,
    Value<int>? ledgerIndex,
    Value<String>? filledBase,
    Value<String>? filledQuote,
    Value<String>? rate,
    Value<String?>? feeDrops,
    Value<DateTime>? date,
    Value<int>? rowid,
  }) {
    return TradeFillsCompanion(
      executionId: executionId ?? this.executionId,
      txHash: txHash ?? this.txHash,
      ledgerIndex: ledgerIndex ?? this.ledgerIndex,
      filledBase: filledBase ?? this.filledBase,
      filledQuote: filledQuote ?? this.filledQuote,
      rate: rate ?? this.rate,
      feeDrops: feeDrops ?? this.feeDrops,
      date: date ?? this.date,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (executionId.present) {
      map['execution_id'] = Variable<String>(executionId.value);
    }
    if (txHash.present) {
      map['tx_hash'] = Variable<String>(txHash.value);
    }
    if (ledgerIndex.present) {
      map['ledger_index'] = Variable<int>(ledgerIndex.value);
    }
    if (filledBase.present) {
      map['filled_base'] = Variable<String>(filledBase.value);
    }
    if (filledQuote.present) {
      map['filled_quote'] = Variable<String>(filledQuote.value);
    }
    if (rate.present) {
      map['rate'] = Variable<String>(rate.value);
    }
    if (feeDrops.present) {
      map['fee_drops'] = Variable<String>(feeDrops.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TradeFillsCompanion(')
          ..write('executionId: $executionId, ')
          ..write('txHash: $txHash, ')
          ..write('ledgerIndex: $ledgerIndex, ')
          ..write('filledBase: $filledBase, ')
          ..write('filledQuote: $filledQuote, ')
          ..write('rate: $rate, ')
          ..write('feeDrops: $feeDrops, ')
          ..write('date: $date, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingPaymentsTable extends PendingPayments
    with TableInfo<$PendingPaymentsTable, PendingPayment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingPaymentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _walletIdMeta = const VerificationMeta(
    'walletId',
  );
  @override
  late final GeneratedColumn<String> walletId = GeneratedColumn<String>(
    'wallet_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _networkMeta = const VerificationMeta(
    'network',
  );
  @override
  late final GeneratedColumn<String> network = GeneratedColumn<String>(
    'network',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _txHashMeta = const VerificationMeta('txHash');
  @override
  late final GeneratedColumn<String> txHash = GeneratedColumn<String>(
    'tx_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _signedBlobMeta = const VerificationMeta(
    'signedBlob',
  );
  @override
  late final GeneratedColumn<String> signedBlob = GeneratedColumn<String>(
    'signed_blob',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastLedgerSequenceMeta =
      const VerificationMeta('lastLedgerSequence');
  @override
  late final GeneratedColumn<int> lastLedgerSequence = GeneratedColumn<int>(
    'last_ledger_sequence',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    walletId,
    network,
    txHash,
    signedBlob,
    lastLedgerSequence,
    status,
    lastError,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_payments';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingPayment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('wallet_id')) {
      context.handle(
        _walletIdMeta,
        walletId.isAcceptableOrUnknown(data['wallet_id']!, _walletIdMeta),
      );
    } else if (isInserting) {
      context.missing(_walletIdMeta);
    }
    if (data.containsKey('network')) {
      context.handle(
        _networkMeta,
        network.isAcceptableOrUnknown(data['network']!, _networkMeta),
      );
    } else if (isInserting) {
      context.missing(_networkMeta);
    }
    if (data.containsKey('tx_hash')) {
      context.handle(
        _txHashMeta,
        txHash.isAcceptableOrUnknown(data['tx_hash']!, _txHashMeta),
      );
    } else if (isInserting) {
      context.missing(_txHashMeta);
    }
    if (data.containsKey('signed_blob')) {
      context.handle(
        _signedBlobMeta,
        signedBlob.isAcceptableOrUnknown(data['signed_blob']!, _signedBlobMeta),
      );
    } else if (isInserting) {
      context.missing(_signedBlobMeta);
    }
    if (data.containsKey('last_ledger_sequence')) {
      context.handle(
        _lastLedgerSequenceMeta,
        lastLedgerSequence.isAcceptableOrUnknown(
          data['last_ledger_sequence']!,
          _lastLedgerSequenceMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingPayment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingPayment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      walletId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wallet_id'],
      )!,
      network: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}network'],
      )!,
      txHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tx_hash'],
      )!,
      signedBlob: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}signed_blob'],
      )!,
      lastLedgerSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_ledger_sequence'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PendingPaymentsTable createAlias(String alias) {
    return $PendingPaymentsTable(attachedDatabase, alias);
  }
}

class PendingPayment extends DataClass implements Insertable<PendingPayment> {
  final String id;
  final String walletId;
  final String network;
  final String txHash;
  final String signedBlob;
  final int? lastLedgerSequence;
  final String status;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;
  const PendingPayment({
    required this.id,
    required this.walletId,
    required this.network,
    required this.txHash,
    required this.signedBlob,
    this.lastLedgerSequence,
    required this.status,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['wallet_id'] = Variable<String>(walletId);
    map['network'] = Variable<String>(network);
    map['tx_hash'] = Variable<String>(txHash);
    map['signed_blob'] = Variable<String>(signedBlob);
    if (!nullToAbsent || lastLedgerSequence != null) {
      map['last_ledger_sequence'] = Variable<int>(lastLedgerSequence);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PendingPaymentsCompanion toCompanion(bool nullToAbsent) {
    return PendingPaymentsCompanion(
      id: Value(id),
      walletId: Value(walletId),
      network: Value(network),
      txHash: Value(txHash),
      signedBlob: Value(signedBlob),
      lastLedgerSequence: lastLedgerSequence == null && nullToAbsent
          ? const Value.absent()
          : Value(lastLedgerSequence),
      status: Value(status),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PendingPayment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingPayment(
      id: serializer.fromJson<String>(json['id']),
      walletId: serializer.fromJson<String>(json['walletId']),
      network: serializer.fromJson<String>(json['network']),
      txHash: serializer.fromJson<String>(json['txHash']),
      signedBlob: serializer.fromJson<String>(json['signedBlob']),
      lastLedgerSequence: serializer.fromJson<int?>(json['lastLedgerSequence']),
      status: serializer.fromJson<String>(json['status']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'walletId': serializer.toJson<String>(walletId),
      'network': serializer.toJson<String>(network),
      'txHash': serializer.toJson<String>(txHash),
      'signedBlob': serializer.toJson<String>(signedBlob),
      'lastLedgerSequence': serializer.toJson<int?>(lastLedgerSequence),
      'status': serializer.toJson<String>(status),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PendingPayment copyWith({
    String? id,
    String? walletId,
    String? network,
    String? txHash,
    String? signedBlob,
    Value<int?> lastLedgerSequence = const Value.absent(),
    String? status,
    Value<String?> lastError = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => PendingPayment(
    id: id ?? this.id,
    walletId: walletId ?? this.walletId,
    network: network ?? this.network,
    txHash: txHash ?? this.txHash,
    signedBlob: signedBlob ?? this.signedBlob,
    lastLedgerSequence: lastLedgerSequence.present
        ? lastLedgerSequence.value
        : this.lastLedgerSequence,
    status: status ?? this.status,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PendingPayment copyWithCompanion(PendingPaymentsCompanion data) {
    return PendingPayment(
      id: data.id.present ? data.id.value : this.id,
      walletId: data.walletId.present ? data.walletId.value : this.walletId,
      network: data.network.present ? data.network.value : this.network,
      txHash: data.txHash.present ? data.txHash.value : this.txHash,
      signedBlob: data.signedBlob.present
          ? data.signedBlob.value
          : this.signedBlob,
      lastLedgerSequence: data.lastLedgerSequence.present
          ? data.lastLedgerSequence.value
          : this.lastLedgerSequence,
      status: data.status.present ? data.status.value : this.status,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingPayment(')
          ..write('id: $id, ')
          ..write('walletId: $walletId, ')
          ..write('network: $network, ')
          ..write('txHash: $txHash, ')
          ..write('signedBlob: $signedBlob, ')
          ..write('lastLedgerSequence: $lastLedgerSequence, ')
          ..write('status: $status, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    walletId,
    network,
    txHash,
    signedBlob,
    lastLedgerSequence,
    status,
    lastError,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingPayment &&
          other.id == this.id &&
          other.walletId == this.walletId &&
          other.network == this.network &&
          other.txHash == this.txHash &&
          other.signedBlob == this.signedBlob &&
          other.lastLedgerSequence == this.lastLedgerSequence &&
          other.status == this.status &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PendingPaymentsCompanion extends UpdateCompanion<PendingPayment> {
  final Value<String> id;
  final Value<String> walletId;
  final Value<String> network;
  final Value<String> txHash;
  final Value<String> signedBlob;
  final Value<int?> lastLedgerSequence;
  final Value<String> status;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PendingPaymentsCompanion({
    this.id = const Value.absent(),
    this.walletId = const Value.absent(),
    this.network = const Value.absent(),
    this.txHash = const Value.absent(),
    this.signedBlob = const Value.absent(),
    this.lastLedgerSequence = const Value.absent(),
    this.status = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingPaymentsCompanion.insert({
    required String id,
    required String walletId,
    required String network,
    required String txHash,
    required String signedBlob,
    this.lastLedgerSequence = const Value.absent(),
    required String status,
    this.lastError = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       walletId = Value(walletId),
       network = Value(network),
       txHash = Value(txHash),
       signedBlob = Value(signedBlob),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<PendingPayment> custom({
    Expression<String>? id,
    Expression<String>? walletId,
    Expression<String>? network,
    Expression<String>? txHash,
    Expression<String>? signedBlob,
    Expression<int>? lastLedgerSequence,
    Expression<String>? status,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (walletId != null) 'wallet_id': walletId,
      if (network != null) 'network': network,
      if (txHash != null) 'tx_hash': txHash,
      if (signedBlob != null) 'signed_blob': signedBlob,
      if (lastLedgerSequence != null)
        'last_ledger_sequence': lastLedgerSequence,
      if (status != null) 'status': status,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingPaymentsCompanion copyWith({
    Value<String>? id,
    Value<String>? walletId,
    Value<String>? network,
    Value<String>? txHash,
    Value<String>? signedBlob,
    Value<int?>? lastLedgerSequence,
    Value<String>? status,
    Value<String?>? lastError,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PendingPaymentsCompanion(
      id: id ?? this.id,
      walletId: walletId ?? this.walletId,
      network: network ?? this.network,
      txHash: txHash ?? this.txHash,
      signedBlob: signedBlob ?? this.signedBlob,
      lastLedgerSequence: lastLedgerSequence ?? this.lastLedgerSequence,
      status: status ?? this.status,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (walletId.present) {
      map['wallet_id'] = Variable<String>(walletId.value);
    }
    if (network.present) {
      map['network'] = Variable<String>(network.value);
    }
    if (txHash.present) {
      map['tx_hash'] = Variable<String>(txHash.value);
    }
    if (signedBlob.present) {
      map['signed_blob'] = Variable<String>(signedBlob.value);
    }
    if (lastLedgerSequence.present) {
      map['last_ledger_sequence'] = Variable<int>(lastLedgerSequence.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingPaymentsCompanion(')
          ..write('id: $id, ')
          ..write('walletId: $walletId, ')
          ..write('network: $network, ')
          ..write('txHash: $txHash, ')
          ..write('signedBlob: $signedBlob, ')
          ..write('lastLedgerSequence: $lastLedgerSequence, ')
          ..write('status: $status, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $WalletsTable wallets = $WalletsTable(this);
  late final $BalancesTable balances = $BalancesTable(this);
  late final $CachedTxsTable cachedTxs = $CachedTxsTable(this);
  late final $AppSettingsRowsTable appSettingsRows = $AppSettingsRowsTable(
    this,
  );
  late final $TradeExecutionsTable tradeExecutions = $TradeExecutionsTable(
    this,
  );
  late final $TradeFillsTable tradeFills = $TradeFillsTable(this);
  late final $PendingPaymentsTable pendingPayments = $PendingPaymentsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    wallets,
    balances,
    cachedTxs,
    appSettingsRows,
    tradeExecutions,
    tradeFills,
    pendingPayments,
  ];
}

typedef $$WalletsTableCreateCompanionBuilder =
    WalletsCompanion Function({
      required String id,
      required String label,
      required String address,
      required String kind,
      required String preferredNetwork,
      required String importMethod,
      required DateTime createdAt,
      Value<int> sortOrder,
      Value<int?> accentColor,
      Value<bool> useLedger,
      Value<int> ledgerAccountIndex,
      Value<int> rowid,
    });
typedef $$WalletsTableUpdateCompanionBuilder =
    WalletsCompanion Function({
      Value<String> id,
      Value<String> label,
      Value<String> address,
      Value<String> kind,
      Value<String> preferredNetwork,
      Value<String> importMethod,
      Value<DateTime> createdAt,
      Value<int> sortOrder,
      Value<int?> accentColor,
      Value<bool> useLedger,
      Value<int> ledgerAccountIndex,
      Value<int> rowid,
    });

class $$WalletsTableFilterComposer
    extends Composer<_$AppDatabase, $WalletsTable> {
  $$WalletsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preferredNetwork => $composableBuilder(
    column: $table.preferredNetwork,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importMethod => $composableBuilder(
    column: $table.importMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get accentColor => $composableBuilder(
    column: $table.accentColor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get useLedger => $composableBuilder(
    column: $table.useLedger,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ledgerAccountIndex => $composableBuilder(
    column: $table.ledgerAccountIndex,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WalletsTableOrderingComposer
    extends Composer<_$AppDatabase, $WalletsTable> {
  $$WalletsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferredNetwork => $composableBuilder(
    column: $table.preferredNetwork,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importMethod => $composableBuilder(
    column: $table.importMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get accentColor => $composableBuilder(
    column: $table.accentColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get useLedger => $composableBuilder(
    column: $table.useLedger,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ledgerAccountIndex => $composableBuilder(
    column: $table.ledgerAccountIndex,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WalletsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WalletsTable> {
  $$WalletsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get preferredNetwork => $composableBuilder(
    column: $table.preferredNetwork,
    builder: (column) => column,
  );

  GeneratedColumn<String> get importMethod => $composableBuilder(
    column: $table.importMethod,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get accentColor => $composableBuilder(
    column: $table.accentColor,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get useLedger =>
      $composableBuilder(column: $table.useLedger, builder: (column) => column);

  GeneratedColumn<int> get ledgerAccountIndex => $composableBuilder(
    column: $table.ledgerAccountIndex,
    builder: (column) => column,
  );
}

class $$WalletsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WalletsTable,
          Wallet,
          $$WalletsTableFilterComposer,
          $$WalletsTableOrderingComposer,
          $$WalletsTableAnnotationComposer,
          $$WalletsTableCreateCompanionBuilder,
          $$WalletsTableUpdateCompanionBuilder,
          (Wallet, BaseReferences<_$AppDatabase, $WalletsTable, Wallet>),
          Wallet,
          PrefetchHooks Function()
        > {
  $$WalletsTableTableManager(_$AppDatabase db, $WalletsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WalletsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WalletsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WalletsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> preferredNetwork = const Value.absent(),
                Value<String> importMethod = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int?> accentColor = const Value.absent(),
                Value<bool> useLedger = const Value.absent(),
                Value<int> ledgerAccountIndex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WalletsCompanion(
                id: id,
                label: label,
                address: address,
                kind: kind,
                preferredNetwork: preferredNetwork,
                importMethod: importMethod,
                createdAt: createdAt,
                sortOrder: sortOrder,
                accentColor: accentColor,
                useLedger: useLedger,
                ledgerAccountIndex: ledgerAccountIndex,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String label,
                required String address,
                required String kind,
                required String preferredNetwork,
                required String importMethod,
                required DateTime createdAt,
                Value<int> sortOrder = const Value.absent(),
                Value<int?> accentColor = const Value.absent(),
                Value<bool> useLedger = const Value.absent(),
                Value<int> ledgerAccountIndex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WalletsCompanion.insert(
                id: id,
                label: label,
                address: address,
                kind: kind,
                preferredNetwork: preferredNetwork,
                importMethod: importMethod,
                createdAt: createdAt,
                sortOrder: sortOrder,
                accentColor: accentColor,
                useLedger: useLedger,
                ledgerAccountIndex: ledgerAccountIndex,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WalletsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WalletsTable,
      Wallet,
      $$WalletsTableFilterComposer,
      $$WalletsTableOrderingComposer,
      $$WalletsTableAnnotationComposer,
      $$WalletsTableCreateCompanionBuilder,
      $$WalletsTableUpdateCompanionBuilder,
      (Wallet, BaseReferences<_$AppDatabase, $WalletsTable, Wallet>),
      Wallet,
      PrefetchHooks Function()
    >;
typedef $$BalancesTableCreateCompanionBuilder =
    BalancesCompanion Function({
      required String walletId,
      required String currency,
      Value<String> issuer,
      required String value,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$BalancesTableUpdateCompanionBuilder =
    BalancesCompanion Function({
      Value<String> walletId,
      Value<String> currency,
      Value<String> issuer,
      Value<String> value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$BalancesTableFilterComposer
    extends Composer<_$AppDatabase, $BalancesTable> {
  $$BalancesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get walletId => $composableBuilder(
    column: $table.walletId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get issuer => $composableBuilder(
    column: $table.issuer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BalancesTableOrderingComposer
    extends Composer<_$AppDatabase, $BalancesTable> {
  $$BalancesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get walletId => $composableBuilder(
    column: $table.walletId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get issuer => $composableBuilder(
    column: $table.issuer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BalancesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BalancesTable> {
  $$BalancesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get walletId =>
      $composableBuilder(column: $table.walletId, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get issuer =>
      $composableBuilder(column: $table.issuer, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BalancesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BalancesTable,
          Balance,
          $$BalancesTableFilterComposer,
          $$BalancesTableOrderingComposer,
          $$BalancesTableAnnotationComposer,
          $$BalancesTableCreateCompanionBuilder,
          $$BalancesTableUpdateCompanionBuilder,
          (Balance, BaseReferences<_$AppDatabase, $BalancesTable, Balance>),
          Balance,
          PrefetchHooks Function()
        > {
  $$BalancesTableTableManager(_$AppDatabase db, $BalancesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BalancesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BalancesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BalancesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> walletId = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> issuer = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BalancesCompanion(
                walletId: walletId,
                currency: currency,
                issuer: issuer,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String walletId,
                required String currency,
                Value<String> issuer = const Value.absent(),
                required String value,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => BalancesCompanion.insert(
                walletId: walletId,
                currency: currency,
                issuer: issuer,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BalancesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BalancesTable,
      Balance,
      $$BalancesTableFilterComposer,
      $$BalancesTableOrderingComposer,
      $$BalancesTableAnnotationComposer,
      $$BalancesTableCreateCompanionBuilder,
      $$BalancesTableUpdateCompanionBuilder,
      (Balance, BaseReferences<_$AppDatabase, $BalancesTable, Balance>),
      Balance,
      PrefetchHooks Function()
    >;
typedef $$CachedTxsTableCreateCompanionBuilder =
    CachedTxsCompanion Function({
      required String hash,
      required String walletId,
      Value<int?> ledgerIndex,
      required String txType,
      required String direction,
      required String amountSummary,
      Value<String?> counterpart,
      required DateTime date,
      Value<int> rowid,
    });
typedef $$CachedTxsTableUpdateCompanionBuilder =
    CachedTxsCompanion Function({
      Value<String> hash,
      Value<String> walletId,
      Value<int?> ledgerIndex,
      Value<String> txType,
      Value<String> direction,
      Value<String> amountSummary,
      Value<String?> counterpart,
      Value<DateTime> date,
      Value<int> rowid,
    });

class $$CachedTxsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedTxsTable> {
  $$CachedTxsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get walletId => $composableBuilder(
    column: $table.walletId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ledgerIndex => $composableBuilder(
    column: $table.ledgerIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get txType => $composableBuilder(
    column: $table.txType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get amountSummary => $composableBuilder(
    column: $table.amountSummary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get counterpart => $composableBuilder(
    column: $table.counterpart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedTxsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedTxsTable> {
  $$CachedTxsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get walletId => $composableBuilder(
    column: $table.walletId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ledgerIndex => $composableBuilder(
    column: $table.ledgerIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get txType => $composableBuilder(
    column: $table.txType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get amountSummary => $composableBuilder(
    column: $table.amountSummary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get counterpart => $composableBuilder(
    column: $table.counterpart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedTxsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedTxsTable> {
  $$CachedTxsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get hash =>
      $composableBuilder(column: $table.hash, builder: (column) => column);

  GeneratedColumn<String> get walletId =>
      $composableBuilder(column: $table.walletId, builder: (column) => column);

  GeneratedColumn<int> get ledgerIndex => $composableBuilder(
    column: $table.ledgerIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get txType =>
      $composableBuilder(column: $table.txType, builder: (column) => column);

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<String> get amountSummary => $composableBuilder(
    column: $table.amountSummary,
    builder: (column) => column,
  );

  GeneratedColumn<String> get counterpart => $composableBuilder(
    column: $table.counterpart,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);
}

class $$CachedTxsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedTxsTable,
          CachedTx,
          $$CachedTxsTableFilterComposer,
          $$CachedTxsTableOrderingComposer,
          $$CachedTxsTableAnnotationComposer,
          $$CachedTxsTableCreateCompanionBuilder,
          $$CachedTxsTableUpdateCompanionBuilder,
          (CachedTx, BaseReferences<_$AppDatabase, $CachedTxsTable, CachedTx>),
          CachedTx,
          PrefetchHooks Function()
        > {
  $$CachedTxsTableTableManager(_$AppDatabase db, $CachedTxsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedTxsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedTxsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedTxsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> hash = const Value.absent(),
                Value<String> walletId = const Value.absent(),
                Value<int?> ledgerIndex = const Value.absent(),
                Value<String> txType = const Value.absent(),
                Value<String> direction = const Value.absent(),
                Value<String> amountSummary = const Value.absent(),
                Value<String?> counterpart = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedTxsCompanion(
                hash: hash,
                walletId: walletId,
                ledgerIndex: ledgerIndex,
                txType: txType,
                direction: direction,
                amountSummary: amountSummary,
                counterpart: counterpart,
                date: date,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String hash,
                required String walletId,
                Value<int?> ledgerIndex = const Value.absent(),
                required String txType,
                required String direction,
                required String amountSummary,
                Value<String?> counterpart = const Value.absent(),
                required DateTime date,
                Value<int> rowid = const Value.absent(),
              }) => CachedTxsCompanion.insert(
                hash: hash,
                walletId: walletId,
                ledgerIndex: ledgerIndex,
                txType: txType,
                direction: direction,
                amountSummary: amountSummary,
                counterpart: counterpart,
                date: date,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedTxsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedTxsTable,
      CachedTx,
      $$CachedTxsTableFilterComposer,
      $$CachedTxsTableOrderingComposer,
      $$CachedTxsTableAnnotationComposer,
      $$CachedTxsTableCreateCompanionBuilder,
      $$CachedTxsTableUpdateCompanionBuilder,
      (CachedTx, BaseReferences<_$AppDatabase, $CachedTxsTable, CachedTx>),
      CachedTx,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsRowsTableCreateCompanionBuilder =
    AppSettingsRowsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppSettingsRowsTableUpdateCompanionBuilder =
    AppSettingsRowsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppSettingsRowsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsRowsTable> {
  $$AppSettingsRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsRowsTable> {
  $$AppSettingsRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsRowsTable> {
  $$AppSettingsRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsRowsTable,
          AppSettingsRow,
          $$AppSettingsRowsTableFilterComposer,
          $$AppSettingsRowsTableOrderingComposer,
          $$AppSettingsRowsTableAnnotationComposer,
          $$AppSettingsRowsTableCreateCompanionBuilder,
          $$AppSettingsRowsTableUpdateCompanionBuilder,
          (
            AppSettingsRow,
            BaseReferences<
              _$AppDatabase,
              $AppSettingsRowsTable,
              AppSettingsRow
            >,
          ),
          AppSettingsRow,
          PrefetchHooks Function()
        > {
  $$AppSettingsRowsTableTableManager(
    _$AppDatabase db,
    $AppSettingsRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsRowsCompanion(
                key: key,
                value: value,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsRowsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsRowsTable,
      AppSettingsRow,
      $$AppSettingsRowsTableFilterComposer,
      $$AppSettingsRowsTableOrderingComposer,
      $$AppSettingsRowsTableAnnotationComposer,
      $$AppSettingsRowsTableCreateCompanionBuilder,
      $$AppSettingsRowsTableUpdateCompanionBuilder,
      (
        AppSettingsRow,
        BaseReferences<_$AppDatabase, $AppSettingsRowsTable, AppSettingsRow>,
      ),
      AppSettingsRow,
      PrefetchHooks Function()
    >;
typedef $$TradeExecutionsTableCreateCompanionBuilder =
    TradeExecutionsCompanion Function({
      required String id,
      required String walletId,
      required String network,
      required String side,
      required String baseCurrency,
      Value<String?> baseIssuer,
      required String quoteCurrency,
      Value<String?> quoteIssuer,
      required String targetAmount,
      Value<String> filledAmount,
      required String orderType,
      required String status,
      Value<String?> lastError,
      Value<String?> txHash,
      Value<int?> offerSequence,
      Value<int?> lastLedgerSequence,
      Value<int?> lastLedgerIndex,
      Value<DateTime?> expiration,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$TradeExecutionsTableUpdateCompanionBuilder =
    TradeExecutionsCompanion Function({
      Value<String> id,
      Value<String> walletId,
      Value<String> network,
      Value<String> side,
      Value<String> baseCurrency,
      Value<String?> baseIssuer,
      Value<String> quoteCurrency,
      Value<String?> quoteIssuer,
      Value<String> targetAmount,
      Value<String> filledAmount,
      Value<String> orderType,
      Value<String> status,
      Value<String?> lastError,
      Value<String?> txHash,
      Value<int?> offerSequence,
      Value<int?> lastLedgerSequence,
      Value<int?> lastLedgerIndex,
      Value<DateTime?> expiration,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$TradeExecutionsTableFilterComposer
    extends Composer<_$AppDatabase, $TradeExecutionsTable> {
  $$TradeExecutionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get walletId => $composableBuilder(
    column: $table.walletId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get network => $composableBuilder(
    column: $table.network,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get side => $composableBuilder(
    column: $table.side,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseCurrency => $composableBuilder(
    column: $table.baseCurrency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseIssuer => $composableBuilder(
    column: $table.baseIssuer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quoteCurrency => $composableBuilder(
    column: $table.quoteCurrency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quoteIssuer => $composableBuilder(
    column: $table.quoteIssuer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetAmount => $composableBuilder(
    column: $table.targetAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filledAmount => $composableBuilder(
    column: $table.filledAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get orderType => $composableBuilder(
    column: $table.orderType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get txHash => $composableBuilder(
    column: $table.txHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get offerSequence => $composableBuilder(
    column: $table.offerSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastLedgerSequence => $composableBuilder(
    column: $table.lastLedgerSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastLedgerIndex => $composableBuilder(
    column: $table.lastLedgerIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiration => $composableBuilder(
    column: $table.expiration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TradeExecutionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TradeExecutionsTable> {
  $$TradeExecutionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get walletId => $composableBuilder(
    column: $table.walletId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get network => $composableBuilder(
    column: $table.network,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get side => $composableBuilder(
    column: $table.side,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseCurrency => $composableBuilder(
    column: $table.baseCurrency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseIssuer => $composableBuilder(
    column: $table.baseIssuer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quoteCurrency => $composableBuilder(
    column: $table.quoteCurrency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quoteIssuer => $composableBuilder(
    column: $table.quoteIssuer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetAmount => $composableBuilder(
    column: $table.targetAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filledAmount => $composableBuilder(
    column: $table.filledAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get orderType => $composableBuilder(
    column: $table.orderType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get txHash => $composableBuilder(
    column: $table.txHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get offerSequence => $composableBuilder(
    column: $table.offerSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastLedgerSequence => $composableBuilder(
    column: $table.lastLedgerSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastLedgerIndex => $composableBuilder(
    column: $table.lastLedgerIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiration => $composableBuilder(
    column: $table.expiration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TradeExecutionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TradeExecutionsTable> {
  $$TradeExecutionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get walletId =>
      $composableBuilder(column: $table.walletId, builder: (column) => column);

  GeneratedColumn<String> get network =>
      $composableBuilder(column: $table.network, builder: (column) => column);

  GeneratedColumn<String> get side =>
      $composableBuilder(column: $table.side, builder: (column) => column);

  GeneratedColumn<String> get baseCurrency => $composableBuilder(
    column: $table.baseCurrency,
    builder: (column) => column,
  );

  GeneratedColumn<String> get baseIssuer => $composableBuilder(
    column: $table.baseIssuer,
    builder: (column) => column,
  );

  GeneratedColumn<String> get quoteCurrency => $composableBuilder(
    column: $table.quoteCurrency,
    builder: (column) => column,
  );

  GeneratedColumn<String> get quoteIssuer => $composableBuilder(
    column: $table.quoteIssuer,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetAmount => $composableBuilder(
    column: $table.targetAmount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get filledAmount => $composableBuilder(
    column: $table.filledAmount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get orderType =>
      $composableBuilder(column: $table.orderType, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<String> get txHash =>
      $composableBuilder(column: $table.txHash, builder: (column) => column);

  GeneratedColumn<int> get offerSequence => $composableBuilder(
    column: $table.offerSequence,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastLedgerSequence => $composableBuilder(
    column: $table.lastLedgerSequence,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastLedgerIndex => $composableBuilder(
    column: $table.lastLedgerIndex,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get expiration => $composableBuilder(
    column: $table.expiration,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TradeExecutionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TradeExecutionsTable,
          TradeExecution,
          $$TradeExecutionsTableFilterComposer,
          $$TradeExecutionsTableOrderingComposer,
          $$TradeExecutionsTableAnnotationComposer,
          $$TradeExecutionsTableCreateCompanionBuilder,
          $$TradeExecutionsTableUpdateCompanionBuilder,
          (
            TradeExecution,
            BaseReferences<
              _$AppDatabase,
              $TradeExecutionsTable,
              TradeExecution
            >,
          ),
          TradeExecution,
          PrefetchHooks Function()
        > {
  $$TradeExecutionsTableTableManager(
    _$AppDatabase db,
    $TradeExecutionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TradeExecutionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TradeExecutionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TradeExecutionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> walletId = const Value.absent(),
                Value<String> network = const Value.absent(),
                Value<String> side = const Value.absent(),
                Value<String> baseCurrency = const Value.absent(),
                Value<String?> baseIssuer = const Value.absent(),
                Value<String> quoteCurrency = const Value.absent(),
                Value<String?> quoteIssuer = const Value.absent(),
                Value<String> targetAmount = const Value.absent(),
                Value<String> filledAmount = const Value.absent(),
                Value<String> orderType = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String?> txHash = const Value.absent(),
                Value<int?> offerSequence = const Value.absent(),
                Value<int?> lastLedgerSequence = const Value.absent(),
                Value<int?> lastLedgerIndex = const Value.absent(),
                Value<DateTime?> expiration = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TradeExecutionsCompanion(
                id: id,
                walletId: walletId,
                network: network,
                side: side,
                baseCurrency: baseCurrency,
                baseIssuer: baseIssuer,
                quoteCurrency: quoteCurrency,
                quoteIssuer: quoteIssuer,
                targetAmount: targetAmount,
                filledAmount: filledAmount,
                orderType: orderType,
                status: status,
                lastError: lastError,
                txHash: txHash,
                offerSequence: offerSequence,
                lastLedgerSequence: lastLedgerSequence,
                lastLedgerIndex: lastLedgerIndex,
                expiration: expiration,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String walletId,
                required String network,
                required String side,
                required String baseCurrency,
                Value<String?> baseIssuer = const Value.absent(),
                required String quoteCurrency,
                Value<String?> quoteIssuer = const Value.absent(),
                required String targetAmount,
                Value<String> filledAmount = const Value.absent(),
                required String orderType,
                required String status,
                Value<String?> lastError = const Value.absent(),
                Value<String?> txHash = const Value.absent(),
                Value<int?> offerSequence = const Value.absent(),
                Value<int?> lastLedgerSequence = const Value.absent(),
                Value<int?> lastLedgerIndex = const Value.absent(),
                Value<DateTime?> expiration = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TradeExecutionsCompanion.insert(
                id: id,
                walletId: walletId,
                network: network,
                side: side,
                baseCurrency: baseCurrency,
                baseIssuer: baseIssuer,
                quoteCurrency: quoteCurrency,
                quoteIssuer: quoteIssuer,
                targetAmount: targetAmount,
                filledAmount: filledAmount,
                orderType: orderType,
                status: status,
                lastError: lastError,
                txHash: txHash,
                offerSequence: offerSequence,
                lastLedgerSequence: lastLedgerSequence,
                lastLedgerIndex: lastLedgerIndex,
                expiration: expiration,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TradeExecutionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TradeExecutionsTable,
      TradeExecution,
      $$TradeExecutionsTableFilterComposer,
      $$TradeExecutionsTableOrderingComposer,
      $$TradeExecutionsTableAnnotationComposer,
      $$TradeExecutionsTableCreateCompanionBuilder,
      $$TradeExecutionsTableUpdateCompanionBuilder,
      (
        TradeExecution,
        BaseReferences<_$AppDatabase, $TradeExecutionsTable, TradeExecution>,
      ),
      TradeExecution,
      PrefetchHooks Function()
    >;
typedef $$TradeFillsTableCreateCompanionBuilder =
    TradeFillsCompanion Function({
      required String executionId,
      required String txHash,
      required int ledgerIndex,
      required String filledBase,
      required String filledQuote,
      required String rate,
      Value<String?> feeDrops,
      required DateTime date,
      Value<int> rowid,
    });
typedef $$TradeFillsTableUpdateCompanionBuilder =
    TradeFillsCompanion Function({
      Value<String> executionId,
      Value<String> txHash,
      Value<int> ledgerIndex,
      Value<String> filledBase,
      Value<String> filledQuote,
      Value<String> rate,
      Value<String?> feeDrops,
      Value<DateTime> date,
      Value<int> rowid,
    });

class $$TradeFillsTableFilterComposer
    extends Composer<_$AppDatabase, $TradeFillsTable> {
  $$TradeFillsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get executionId => $composableBuilder(
    column: $table.executionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get txHash => $composableBuilder(
    column: $table.txHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ledgerIndex => $composableBuilder(
    column: $table.ledgerIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filledBase => $composableBuilder(
    column: $table.filledBase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filledQuote => $composableBuilder(
    column: $table.filledQuote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rate => $composableBuilder(
    column: $table.rate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get feeDrops => $composableBuilder(
    column: $table.feeDrops,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TradeFillsTableOrderingComposer
    extends Composer<_$AppDatabase, $TradeFillsTable> {
  $$TradeFillsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get executionId => $composableBuilder(
    column: $table.executionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get txHash => $composableBuilder(
    column: $table.txHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ledgerIndex => $composableBuilder(
    column: $table.ledgerIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filledBase => $composableBuilder(
    column: $table.filledBase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filledQuote => $composableBuilder(
    column: $table.filledQuote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rate => $composableBuilder(
    column: $table.rate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get feeDrops => $composableBuilder(
    column: $table.feeDrops,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TradeFillsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TradeFillsTable> {
  $$TradeFillsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get executionId => $composableBuilder(
    column: $table.executionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get txHash =>
      $composableBuilder(column: $table.txHash, builder: (column) => column);

  GeneratedColumn<int> get ledgerIndex => $composableBuilder(
    column: $table.ledgerIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get filledBase => $composableBuilder(
    column: $table.filledBase,
    builder: (column) => column,
  );

  GeneratedColumn<String> get filledQuote => $composableBuilder(
    column: $table.filledQuote,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rate =>
      $composableBuilder(column: $table.rate, builder: (column) => column);

  GeneratedColumn<String> get feeDrops =>
      $composableBuilder(column: $table.feeDrops, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);
}

class $$TradeFillsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TradeFillsTable,
          TradeFill,
          $$TradeFillsTableFilterComposer,
          $$TradeFillsTableOrderingComposer,
          $$TradeFillsTableAnnotationComposer,
          $$TradeFillsTableCreateCompanionBuilder,
          $$TradeFillsTableUpdateCompanionBuilder,
          (
            TradeFill,
            BaseReferences<_$AppDatabase, $TradeFillsTable, TradeFill>,
          ),
          TradeFill,
          PrefetchHooks Function()
        > {
  $$TradeFillsTableTableManager(_$AppDatabase db, $TradeFillsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TradeFillsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TradeFillsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TradeFillsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> executionId = const Value.absent(),
                Value<String> txHash = const Value.absent(),
                Value<int> ledgerIndex = const Value.absent(),
                Value<String> filledBase = const Value.absent(),
                Value<String> filledQuote = const Value.absent(),
                Value<String> rate = const Value.absent(),
                Value<String?> feeDrops = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TradeFillsCompanion(
                executionId: executionId,
                txHash: txHash,
                ledgerIndex: ledgerIndex,
                filledBase: filledBase,
                filledQuote: filledQuote,
                rate: rate,
                feeDrops: feeDrops,
                date: date,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String executionId,
                required String txHash,
                required int ledgerIndex,
                required String filledBase,
                required String filledQuote,
                required String rate,
                Value<String?> feeDrops = const Value.absent(),
                required DateTime date,
                Value<int> rowid = const Value.absent(),
              }) => TradeFillsCompanion.insert(
                executionId: executionId,
                txHash: txHash,
                ledgerIndex: ledgerIndex,
                filledBase: filledBase,
                filledQuote: filledQuote,
                rate: rate,
                feeDrops: feeDrops,
                date: date,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TradeFillsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TradeFillsTable,
      TradeFill,
      $$TradeFillsTableFilterComposer,
      $$TradeFillsTableOrderingComposer,
      $$TradeFillsTableAnnotationComposer,
      $$TradeFillsTableCreateCompanionBuilder,
      $$TradeFillsTableUpdateCompanionBuilder,
      (TradeFill, BaseReferences<_$AppDatabase, $TradeFillsTable, TradeFill>),
      TradeFill,
      PrefetchHooks Function()
    >;
typedef $$PendingPaymentsTableCreateCompanionBuilder =
    PendingPaymentsCompanion Function({
      required String id,
      required String walletId,
      required String network,
      required String txHash,
      required String signedBlob,
      Value<int?> lastLedgerSequence,
      required String status,
      Value<String?> lastError,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$PendingPaymentsTableUpdateCompanionBuilder =
    PendingPaymentsCompanion Function({
      Value<String> id,
      Value<String> walletId,
      Value<String> network,
      Value<String> txHash,
      Value<String> signedBlob,
      Value<int?> lastLedgerSequence,
      Value<String> status,
      Value<String?> lastError,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$PendingPaymentsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingPaymentsTable> {
  $$PendingPaymentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get walletId => $composableBuilder(
    column: $table.walletId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get network => $composableBuilder(
    column: $table.network,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get txHash => $composableBuilder(
    column: $table.txHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get signedBlob => $composableBuilder(
    column: $table.signedBlob,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastLedgerSequence => $composableBuilder(
    column: $table.lastLedgerSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingPaymentsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingPaymentsTable> {
  $$PendingPaymentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get walletId => $composableBuilder(
    column: $table.walletId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get network => $composableBuilder(
    column: $table.network,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get txHash => $composableBuilder(
    column: $table.txHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get signedBlob => $composableBuilder(
    column: $table.signedBlob,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastLedgerSequence => $composableBuilder(
    column: $table.lastLedgerSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingPaymentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingPaymentsTable> {
  $$PendingPaymentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get walletId =>
      $composableBuilder(column: $table.walletId, builder: (column) => column);

  GeneratedColumn<String> get network =>
      $composableBuilder(column: $table.network, builder: (column) => column);

  GeneratedColumn<String> get txHash =>
      $composableBuilder(column: $table.txHash, builder: (column) => column);

  GeneratedColumn<String> get signedBlob => $composableBuilder(
    column: $table.signedBlob,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastLedgerSequence => $composableBuilder(
    column: $table.lastLedgerSequence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PendingPaymentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingPaymentsTable,
          PendingPayment,
          $$PendingPaymentsTableFilterComposer,
          $$PendingPaymentsTableOrderingComposer,
          $$PendingPaymentsTableAnnotationComposer,
          $$PendingPaymentsTableCreateCompanionBuilder,
          $$PendingPaymentsTableUpdateCompanionBuilder,
          (
            PendingPayment,
            BaseReferences<
              _$AppDatabase,
              $PendingPaymentsTable,
              PendingPayment
            >,
          ),
          PendingPayment,
          PrefetchHooks Function()
        > {
  $$PendingPaymentsTableTableManager(
    _$AppDatabase db,
    $PendingPaymentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingPaymentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingPaymentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingPaymentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> walletId = const Value.absent(),
                Value<String> network = const Value.absent(),
                Value<String> txHash = const Value.absent(),
                Value<String> signedBlob = const Value.absent(),
                Value<int?> lastLedgerSequence = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingPaymentsCompanion(
                id: id,
                walletId: walletId,
                network: network,
                txHash: txHash,
                signedBlob: signedBlob,
                lastLedgerSequence: lastLedgerSequence,
                status: status,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String walletId,
                required String network,
                required String txHash,
                required String signedBlob,
                Value<int?> lastLedgerSequence = const Value.absent(),
                required String status,
                Value<String?> lastError = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PendingPaymentsCompanion.insert(
                id: id,
                walletId: walletId,
                network: network,
                txHash: txHash,
                signedBlob: signedBlob,
                lastLedgerSequence: lastLedgerSequence,
                status: status,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingPaymentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingPaymentsTable,
      PendingPayment,
      $$PendingPaymentsTableFilterComposer,
      $$PendingPaymentsTableOrderingComposer,
      $$PendingPaymentsTableAnnotationComposer,
      $$PendingPaymentsTableCreateCompanionBuilder,
      $$PendingPaymentsTableUpdateCompanionBuilder,
      (
        PendingPayment,
        BaseReferences<_$AppDatabase, $PendingPaymentsTable, PendingPayment>,
      ),
      PendingPayment,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$WalletsTableTableManager get wallets =>
      $$WalletsTableTableManager(_db, _db.wallets);
  $$BalancesTableTableManager get balances =>
      $$BalancesTableTableManager(_db, _db.balances);
  $$CachedTxsTableTableManager get cachedTxs =>
      $$CachedTxsTableTableManager(_db, _db.cachedTxs);
  $$AppSettingsRowsTableTableManager get appSettingsRows =>
      $$AppSettingsRowsTableTableManager(_db, _db.appSettingsRows);
  $$TradeExecutionsTableTableManager get tradeExecutions =>
      $$TradeExecutionsTableTableManager(_db, _db.tradeExecutions);
  $$TradeFillsTableTableManager get tradeFills =>
      $$TradeFillsTableTableManager(_db, _db.tradeFills);
  $$PendingPaymentsTableTableManager get pendingPayments =>
      $$PendingPaymentsTableTableManager(_db, _db.pendingPayments);
}
