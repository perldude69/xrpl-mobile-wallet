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
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _ledgerAccountIndexMeta = const VerificationMeta(
    'ledgerAccountIndex',
  );
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
  final int? accentColor;
  final bool useLedger;
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
    this.useLedger = false,
    this.ledgerAccountIndex = 0,
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
      if (ledgerAccountIndex != null) 'ledger_account_index': ledgerAccountIndex,
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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $WalletsTable wallets = $WalletsTable(this);
  late final $BalancesTable balances = $BalancesTable(this);
  late final $CachedTxsTable cachedTxs = $CachedTxsTable(this);
  late final $AppSettingsRowsTable appSettingsRows = $AppSettingsRowsTable(
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
}
