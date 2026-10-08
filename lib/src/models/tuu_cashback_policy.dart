/// Política de cashback (`cashback`) para un cobro TUU.
///
/// Mismos semánticos que [TuuTipPolicy] pero aplicada al campo `cashback`:
///
///  - `-1` → cashback **deshabilitado**.
///  - `0`  → la app pregunta al cliente el monto en pantalla.
///  - `>0` → cashback fijo en pesos chilenos.
///
/// **Importante (per docs TUU):** sólo aplica a transacciones de **débito**
/// ([TuuPaymentMethod.debit]). Si se envía con crédito o `askUser`, la app
/// TUU ignora el campo o devuelve `errorCode: 5`.
///
/// ## Ejemplos
///
/// ```dart
/// // Sin cashback (caso común).
/// const policy = TuuCashbackPolicy.disabled;
///
/// // El cliente ingresa el monto en pantalla TUU.
/// const policy = TuuCashbackPolicy.askUser;
///
/// // Cashback fijo (5.000 CLP).
/// const policy = TuuCashbackPolicy.fixed(5000);
/// ```
class TuuCashbackPolicy {
  /// Valor entero a enviar a TUU.
  final int _value;

  const TuuCashbackPolicy._(this._value);

  /// Cashback **deshabilitado**. Se envía `-1` al JSON.
  static const TuuCashbackPolicy disabled = TuuCashbackPolicy._(-1);

  /// La app TUU **pregunta** al cliente. Se envía `0`.
  static const TuuCashbackPolicy askUser = TuuCashbackPolicy._(0);

  /// Cashback con monto **fijo**.
  ///
  /// [amount] debe ser estrictamente positivo (CLP).
  const TuuCashbackPolicy.fixed(int amount)
      : assert(amount > 0, 'TuuCashbackPolicy.fixed: amount debe ser > 0'),
        _value = amount;

  /// `true` si la política representa un monto fijo (> 0).
  bool get isFixed => _value > 0;

  /// `true` si la política representa "preguntar al usuario" (`0`).
  bool get isAskUser => _value == 0;

  /// `true` si la política representa "no usar" (`-1`).
  bool get isDisabled => _value == -1;

  /// Monto fijo si aplica, `null` en caso contrario.
  int? get fixedAmount => isFixed ? _value : null;

  /// Valor entero a serializar en el JSON.
  int toJsonValue() => _value;

  /// Reconstruye una [TuuCashbackPolicy] desde el valor leído del JSON.
  ///
  /// Política aplicada:
  ///  - `null` o cualquier valor `<= -1` → [disabled].
  ///  - `0` → [askUser].
  ///  - `>0` → [TuuCashbackPolicy.fixed].
  factory TuuCashbackPolicy.fromJsonValue(int? value) {
    if (value == null || value <= -1) return disabled;
    if (value == 0) return askUser;
    return TuuCashbackPolicy.fixed(value);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TuuCashbackPolicy && _value == other._value;

  @override
  int get hashCode => _value.hashCode;

  @override
  String toString() {
    if (isDisabled) return 'TuuCashbackPolicy.disabled';
    if (isAskUser) return 'TuuCashbackPolicy.askUser';
    return 'TuuCashbackPolicy.fixed($_value)';
  }
}
