/// Política de propina (`tip`) para un cobro TUU.
///
/// Modela los tres valores que la app TUU acepta para el campo `tip`
/// del JSON, según la documentación oficial:
///
///  - `-1` → la app **no** pedirá propina (deshabilitado).
///  - `0`  → la app pregunta al cajero/cliente el monto en pantalla.
///  - `>0` → propina fija en pesos chilenos.
///
/// Usar valores tipados en lugar de un `int` crudo elimina los "magic
/// numbers" del código de aplicación.
///
/// ## Ejemplos
///
/// ```dart
/// // Sin propina — la app TUU no la solicitará.
/// const policy = TuuTipPolicy.disabled;
///
/// // El cajero ingresa el monto en pantalla TUU.
/// const policy = TuuTipPolicy.askUser;
///
/// // Propina fija (1.500 CLP) calculada por la app integradora.
/// const policy = TuuTipPolicy.fixed(1500);
/// ```
class TuuTipPolicy {
  /// Valor entero que se enviará a TUU (`-1`, `0` o `>0`).
  final int _value;

  const TuuTipPolicy._(this._value);

  /// La app TUU **no** pedirá propina. Se envía `-1` al JSON.
  static const TuuTipPolicy disabled = TuuTipPolicy._(-1);

  /// La app TUU **pregunta** al usuario el monto en pantalla. Se envía `0`.
  static const TuuTipPolicy askUser = TuuTipPolicy._(0);

  /// Propina con monto **fijo**.
  ///
  /// [amount] debe ser estrictamente positivo (CLP). Lanza `AssertionError`
  /// en modo debug si se pasa un valor `<= 0`. Para "sin propina" usar
  /// [disabled]; para "preguntar al usuario" usar [askUser].
  const TuuTipPolicy.fixed(int amount)
      : assert(amount > 0, 'TuuTipPolicy.fixed: amount debe ser > 0'),
        _value = amount;

  /// `true` si la política representa un monto fijo (> 0).
  bool get isFixed => _value > 0;

  /// `true` si la política representa "preguntar al usuario" (`0`).
  bool get isAskUser => _value == 0;

  /// `true` si la política representa "no usar" (`-1`).
  bool get isDisabled => _value == -1;

  /// Monto efectivamente fijado, o `null` si la política no es [fixed].
  int? get fixedAmount => isFixed ? _value : null;

  /// Valor entero a serializar en el JSON enviado a TUU.
  int toJsonValue() => _value;

  /// Reconstruye una [TuuTipPolicy] desde el valor que viajó al/del JSON.
  ///
  /// Política aplicada:
  ///  - `null` o cualquier valor `<= -1` → [disabled].
  ///  - `0` → [askUser].
  ///  - `>0` → [TuuTipPolicy.fixed].
  factory TuuTipPolicy.fromJsonValue(int? value) {
    if (value == null || value <= -1) return disabled;
    if (value == 0) return askUser;
    return TuuTipPolicy.fixed(value);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TuuTipPolicy && _value == other._value;

  @override
  int get hashCode => _value.hashCode;

  @override
  String toString() {
    if (isDisabled) return 'TuuTipPolicy.disabled';
    if (isAskUser) return 'TuuTipPolicy.askUser';
    return 'TuuTipPolicy.fixed($_value)';
  }
}
