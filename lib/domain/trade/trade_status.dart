/// Lifecycle of one XRP ⇄ RLUSD order.
///
/// Persisted as `trade_executions.status` (the enum *name*, not its index — the
/// index must never be written, so reordering stays safe).
///
/// ```
/// draft → reviewing → awaitingApproval → signing → submitted
///       → resting → partiallyFilled → filled | cancelled | expired | failed
///       (interrupted = recovery only, re-entered by the reconciler)
/// ```
enum TradeStatus {
  /// Being composed in the order sheet. Not persisted today; reserved.
  draft,

  /// Fields fixed, review dialog on screen.
  reviewing,

  /// Reviewed, waiting on the wallet PIN.
  awaitingApproval,

  /// PIN accepted; building / signing / submitting.
  signing,

  /// Submitted and accepted by a node; not yet known to be validated.
  ///
  /// This is the genuinely *unknown* state. It must never be used for an order
  /// that has been seen in a validated ledger — conflating "we don't know if
  /// it landed" with "it landed and is waiting" is the dishonesty the
  /// reconciler exists to remove.
  submitted,

  /// Validated, unfilled, and resting on the book holding an owner reserve.
  resting,

  /// Validated with a partial fill; a resting offer may still be on the book.
  partiallyFilled,

  /// Fully filled. Terminal.
  filled,

  /// Cancelled by the user (OfferCancel validated). Terminal.
  cancelled,

  /// Passed its `Expiration`, or past `LastLedgerSequence` without validating.
  /// Terminal.
  expired,

  /// Rejected, or failed before/at submission. Terminal.
  failed,

  /// Process died mid-flight; the reconciler must resolve it against the
  /// ledger before anything else happens to this row.
  interrupted;

  /// Terminal states are never revisited by the reconciler.
  bool get isTerminal => switch (this) {
    TradeStatus.filled ||
    TradeStatus.cancelled ||
    TradeStatus.expired ||
    TradeStatus.failed => true,
    _ => false,
  };

  /// True when the reconciler must resolve this row against the ledger.
  bool get needsReconciliation => !isTerminal;

  /// Storage form. Always the enum name.
  String get storageValue => name;

  /// Names of every terminal state, for DB queries.
  static List<String> get terminalValues => [
    for (final s in TradeStatus.values)
      if (s.isTerminal) s.name,
  ];

  /// Parse a persisted value. Unknown values map to [interrupted] so an
  /// unrecognised row is reconciled rather than silently treated as done.
  static TradeStatus fromStorage(String? value) {
    if (value == null) return TradeStatus.interrupted;
    for (final s in TradeStatus.values) {
      if (s.name == value) return s;
    }
    return TradeStatus.interrupted;
  }
}
