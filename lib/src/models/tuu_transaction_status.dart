/// Lo que TUU responde cuando se le pregunta por un cobro.
///
/// Tres resultados, y confundirlos cuesta plata:
///
///  - [cobrada]: está registrada y completada. Hay que registrarla, no cobrar
///    de nuevo.
///  - [noEncontrada]: TUU no conoce la referencia, así que el cobro no se
///    registró. Se puede volver a cobrar.
///  - [desconocido]: no se pudo averiguar —sin red, timeout, error del
///    servidor—. **No es lo mismo que no cobrada**: volver a cobrar acá puede
///    duplicar.
class TuuTransactionStatus {
  /// `status` tal como lo devuelve TUU. Sólo `completed` cuenta como cobrada.
  final String? status;

  /// Código de autorización, cuando la transacción existe.
  final String? authCode;

  /// Correlativo que asigna TUU.
  final String? sequenceNumber;

  /// Medio usado, por ejemplo «Tarjeta de Débito».
  final String? transactionMethod;

  /// Últimos dígitos enmascarados, por ejemplo `****7664`.
  final String? last4;

  /// Por qué no se pudo averiguar, cuando corresponde.
  final String? motivoDesconocido;

  /// `true` si no se pudo saber. Distinto de no cobrada.
  final bool esDesconocido;

  /// JSON crudo, para depurar lo que el modelo no declara.
  final String? raw;

  const TuuTransactionStatus({
    this.status,
    this.authCode,
    this.sequenceNumber,
    this.transactionMethod,
    this.last4,
    this.motivoDesconocido,
    this.esDesconocido = false,
    this.raw,
  });

  const TuuTransactionStatus.noEncontrada()
      : status = null,
        authCode = null,
        sequenceNumber = null,
        transactionMethod = null,
        last4 = null,
        motivoDesconocido = null,
        esDesconocido = false,
        raw = null;

  const TuuTransactionStatus.desconocido(String motivo)
      : status = null,
        authCode = null,
        sequenceNumber = null,
        transactionMethod = null,
        last4 = null,
        motivoDesconocido = motivo,
        esDesconocido = true,
        raw = null;

  factory TuuTransactionStatus.fromJson(
    Map<String, Object?> json, [
    String? raw,
  ]) {
    return TuuTransactionStatus(
      status: json['status'] as String?,
      authCode: json['authCode'] as String?,
      sequenceNumber: json['sequenceNumber'] as String?,
      transactionMethod: json['transactionMethod'] as String?,
      last4: json['last4'] as String?,
      raw: raw,
    );
  }

  /// `true` sólo si TUU dice `completed`.
  ///
  /// Cualquier otro valor se trata como no cobrada, que es el criterio con el
  /// que ParkingCash lleva esto en producción. Los demás valores de `status`
  /// no están documentados.
  bool get cobrada => status == 'completed';

  /// `true` si se pudo preguntar y la transacción no existe o no se completó.
  bool get sePuedeVolverACobrar => !esDesconocido && !cobrada;

  @override
  String toString() => 'TuuTransactionStatus(status: $status, '
      'cobrada: $cobrada, desconocido: $esDesconocido'
      '${motivoDesconocido != null ? ', motivo: $motivoDesconocido' : ''})';
}
