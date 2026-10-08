import 'tuu_charge_response.dart';

/// Un cobro que quedó sin resolver porque el proceso murió mientras TUU
/// estaba en pantalla.
///
/// Pasa seguido en un POS: Android mata la app que está en segundo plano para
/// darle memoria a la app de pagos. El resultado del Intent sí se reentrega
/// cuando la actividad se recrea, pero para entonces el estado de Dart ya no
/// existe, así que el plugin lo guarda en disco y lo deja acá.
class TuuPendingCharge {
  /// El cuerpo que se le envió a TUU, tal como salió.
  ///
  /// Sirve para reconocer de qué cobro se trata: lleva el monto y los datos
  /// que la app haya puesto en `extraData`.
  final String? request;

  /// La respuesta de TUU, si alcanzó a llegar antes de que el proceso muriera.
  final TuuChargeResponse? response;

  /// Cuándo se lanzó el cobro.
  final DateTime? startedAt;

  const TuuPendingCharge({this.request, this.response, this.startedAt});

  /// `true` si TUU respondió y nadie recibió la respuesta.
  ///
  /// Es el caso resoluble: el cobro ocurrió y lo que falta es registrarlo.
  bool get tieneRespuesta => response != null;

  /// `true` si se lanzó el cobro y no se supo más.
  ///
  /// **Puede haberse cobrado igual.** TUU no expone ninguna forma de
  /// preguntarle por una transacción, así que desde el plugin no hay manera de
  /// saberlo: hay que resolverlo por fuera —preguntándole al operador, o
  /// cruzando contra el reporte de TUU— antes de volver a cobrar.
  bool get esIncierto => request != null && response == null;

  /// Hace cuánto se lanzó, o `null` si no se sabe.
  Duration? get antiguedad =>
      startedAt == null ? null : DateTime.now().difference(startedAt!);

  factory TuuPendingCharge.fromMap(Map<dynamic, dynamic> map) {
    final crudo = map['result'] as String?;
    final millis = map['startedAt'] as int?;
    return TuuPendingCharge(
      request: map['request'] as String?,
      // `fromJsonString` conserva el crudo y no lanza con JSON incompleto,
      // que es lo que hace falta acá: lo guardado puede venir de una versión
      // anterior de la app TUU.
      response: crudo == null || crudo.isEmpty
          ? null
          : TuuChargeResponse.fromJsonString(crudo),
      startedAt: millis == null || millis == 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(millis),
    );
  }

  @override
  String toString() => 'TuuPendingCharge(tieneRespuesta: $tieneRespuesta, '
      'esIncierto: $esIncierto, startedAt: $startedAt)';
}
