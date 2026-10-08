/// Clase base sellada para todas las excepciones del plugin TUU.
///
/// Es **sealed** — el compilador de Dart 3 obliga a que un `switch`
/// exhaustivo cubra todos los casos:
///
/// ```dart
/// try {
///   await tuu.charge(...);
/// } on TuuException catch (e) {
///   switch (e) {
///     case TuuNotInstalledException():
///     case TuuUserCancelledException():
///     case TuuRejectedException():
///     case TuuInternalException():
///     case TuuUnknownException():
///   }
/// }
/// ```
///
/// Todas las subclases preservan el JSON crudo en [rawJson] cuando lo
/// hubo (como String, no como Map, para mantener la API libre de
/// `Object?` o `dynamic`).
sealed class TuuException implements Exception {
  /// Código identificador del error.
  ///
  /// Puede ser un `errorCode` numérico de TUU envuelto como String
  /// (`'10'`, `'9'`), un `errorCodeOnApp` (`'ICE-12'`, `'HP-400'`) o un
  /// código generado por el plugin (`'TUU-USER-CANCELLED'`,
  /// `'TUU-NOT-INSTALLED'`).
  final String code;

  /// Descripción legible del error.
  final String message;

  /// JSON crudo (String) devuelto por TUU, si lo hubo.
  ///
  /// Es `null` cuando la excepción se generó **antes** de tener respuesta
  /// (ej. app no instalada). Se preserva como String — no como Map — para
  /// mantener la API tipada y permitir reenviarlo a soporte tal cual TUU
  /// lo emitió.
  final String? rawJson;

  /// Constructor base de la jerarquía.
  const TuuException({
    required this.code,
    required this.message,
    this.rawJson,
  });

  @override
  String toString() => '$runtimeType(code: $code, message: $message)';
}

/// La app TUU (`com.haulmer.paymentapp` o `.dev`) no está instalada en
/// el dispositivo, o el plugin no pudo construir un launch intent.
///
/// Casos típicos:
///  - El terminal no tiene la app TUU desplegada.
///  - Android 11+ no encuentra el package porque el bloque `<queries>` no
///    se mergeó al manifest de la app consumidora (revisar build).
class TuuNotInstalledException extends TuuException {
  /// Crea una excepción "app no instalada" con [code] y [message] por
  /// default.
  const TuuNotInstalledException({
    super.code = 'TUU-NOT-INSTALLED',
    super.message = 'App TUU no instalada en este dispositivo',
    super.rawJson,
  });
}

/// El usuario canceló la operación en pantalla TUU.
///
/// Se levanta cuando ocurre cualquiera de:
///  - TUU devuelve un JSON con `errorCode == 10`.
///  - `onActivityResult` recibe `data == null` (gesto back sin que la app
///    haya escrito nada en el Intent de respuesta).
class TuuUserCancelledException extends TuuException {
  /// Crea una excepción "cancelado por usuario".
  const TuuUserCancelledException({
    super.code = 'TUU-USER-CANCELLED',
    super.message = 'Transacción cancelada por el usuario',
    super.rawJson,
  });
}

/// El adquirente (banco emisor) rechazó la transacción, o la app TUU
/// rechazó la request por validación de campos.
///
/// Corresponde a JSONs con `transactionStatus: false` cuyos `errorCode`
/// numéricos no caen en los rangos de [TuuInternalException] ni de
/// [TuuUserCancelledException].
///
/// Mapeo per doc oficial:
///  - `errorCode == 9` → rechazo del adquirente ("Error en proceso de
///    pago").
///  - `errorCode` en `[1..8, 13, 18, 19]` → validación / setup
///    incorrecta de la request (la app integradora debería corregir el
///    body antes de reintentar).
class TuuRejectedException extends TuuException {
  /// `errorCode` numérico de TUU (campo `errorCode` del JSON).
  final int? errorCode;

  /// Código adicional del lado de la app TUU (campo `errorCodeOnApp`).
  ///
  /// Formato típico: `'ICE-XX'` en versiones nuevas, `'HP-XXX'` en
  /// versiones antiguas. Es String porque los códigos no son numéricos.
  final String? errorCodeOnApp;

  /// Mensaje adicional del lado de la app TUU (`errorMessageOnApp`).
  final String? errorMessageOnApp;

  /// Crea una excepción de rechazo. [message] suele ser el `errorMessage`
  /// que envió TUU.
  const TuuRejectedException({
    super.code = 'TUU-REJECTED',
    required super.message,
    this.errorCode,
    this.errorCodeOnApp,
    this.errorMessageOnApp,
    super.rawJson,
  });

  @override
  String toString() => 'TuuRejectedException(code: $code, message: $message, '
      'errorCode: $errorCode, onApp: $errorCodeOnApp)';
}

/// Error **interno** de la app TUU o del terminal (configuración,
/// llaves, red, SDK).
///
/// Mapeo per doc oficial:
///  - `errorCode == 11` (terminal no configurado).
///  - `errorCode == 12` (llaves no inyectadas).
///  - `errorCode == 14` (sin internet).
///  - `errorCode == 15` (no se pudo obtener configuración desde la cuenta).
///  - `errorCode == 16` / `17` (rubro en espera / con error).
///  - `errorCode == 20` (SDK de pagos no instalado).
///  - `errorCode == 21` (app TUU requiere actualización).
///
/// Estos errores típicamente no se resuelven con un simple reintento —
/// requieren intervención humana (revisar terminal, conectividad, etc.).
class TuuInternalException extends TuuException {
  /// `errorCode` numérico de TUU.
  final int? errorCode;

  /// `errorCodeOnApp` (ej. `'ICE-12'`).
  final String? errorCodeOnApp;

  /// Crea una excepción de error interno.
  const TuuInternalException({
    super.code = 'TUU-INTERNAL',
    required super.message,
    this.errorCode,
    this.errorCodeOnApp,
    super.rawJson,
  });

  @override
  String toString() => 'TuuInternalException(code: $code, message: $message, '
      'errorCode: $errorCode, onApp: $errorCodeOnApp)';
}

/// Respuesta de TUU que el plugin no pudo clasificar, o
/// `PlatformException` con código nativo no contemplado.
///
/// Casos típicos:
///  - JSON malformado / no parseable.
///  - JSON parseable pero sin `transactionStatus` ni `errorCode`.
///  - `PlatformException` con código `MFN-XX` distinto de `MFN-04`.
///
/// Si esta excepción aparece en producción conviene capturar [rawJson] y
/// reportarlo a soporte TUU.
class TuuUnknownException extends TuuException {
  /// Crea una excepción "desconocida".
  const TuuUnknownException({
    super.code = 'TUU-UNKNOWN',
    required super.message,
    super.rawJson,
  });
}
