/// Campo personalizado a imprimir en el voucher de TUU.
///
/// Se envía dentro de `extraData.customFields` (array). Permite a la app
/// consumidora agregar información adicional al ticket que TUU imprime —
/// por ejemplo, número de boleta, patente del vehículo, ID de orden, etc.
///
/// ## Restricciones (per docs TUU)
///
///  - [name]: alfanumérico, máximo **50 caracteres**.
///  - [value]: alfanumérico, máximo **200 caracteres**.
///  - **No** se permiten los caracteres reservados `&` ni `/` en ningún
///    campo (la app TUU responde `errorCode: I-03` si los detecta).
///  - **No** se permiten espacios en blanco como valor completo
///    (`errorCode: I-04`).
///
/// El plugin **no valida** estas restricciones en runtime — confía en que
/// el llamador conoce las reglas. Pasarlo y dejar que TUU rechace es más
/// barato que duplicar la validación.
///
/// ## Ejemplo
///
/// ```dart
/// const ticket = TuuCustomField(
///   name: 'orden',
///   value: 'ORD-2026-00123',
///   print: true,
/// );
/// ```
class TuuCustomField {
  /// Identificador del campo (max 50 chars alfanuméricos).
  final String name;

  /// Contenido del campo (max 200 chars alfanuméricos).
  final String value;

  /// Si `true`, TUU imprime el campo en el voucher; si `false`, sólo
  /// queda en la metadata de la transacción.
  final bool print;

  /// Crea un `TuuCustomField` inmutable. Todos los campos son obligatorios
  /// — TUU rechaza con `errorCode: I-01` si alguno falta.
  const TuuCustomField({
    required this.name,
    required this.value,
    required this.print,
  });

  /// Serializa al map que se anida dentro de `extraData.customFields`
  /// del JSON principal.
  Map<String, Object?> toJson() => <String, Object?>{
        'name': name,
        'value': value,
        'print': print,
      };

  /// Reconstruye un `TuuCustomField` desde un map JSON.
  ///
  /// Espera las claves `'name'`, `'value'` y `'print'`. Si alguna falta,
  /// usa defaults seguros (`''` o `false`) para no perder la traza —
  /// la validación dura es responsabilidad del backend de TUU.
  factory TuuCustomField.fromJson(Map<String, Object?> json) {
    return TuuCustomField(
      name: (json['name'] as String?) ?? '',
      value: (json['value'] as String?) ?? '',
      print: json['print'] == true,
    );
  }

  @override
  String toString() => 'TuuCustomField(name: $name, print: $print)';
}
