import 'tuu_pending_charge.dart';
import 'tuu_transaction_status.dart';

/// Qué hacer con un cobro que quedó sin resolver.
///
/// Junta lo que quedó guardado con lo que TUU haya respondido al consultarlo,
/// y traduce eso a la única pregunta que le importa al POS: **¿se cobró o no?**
class TuuPendingResolution {
  /// Lo que quedó guardado del cobro interrumpido.
  final TuuPendingCharge pendiente;

  /// Lo que respondió TUU, si hizo falta consultar.
  final TuuTransactionStatus? estado;

  const TuuPendingResolution({required this.pendiente, this.estado});

  /// `true` si el cobro ocurrió: o porque la respuesta quedó guardada, o
  /// porque TUU confirmó que está completada.
  ///
  /// En este caso hay que registrar la venta y recién después limpiar el
  /// pendiente.
  bool get cobrado => pendiente.tieneRespuesta || (estado?.cobrada ?? false);

  /// `true` si se puede volver a cobrar sin riesgo de duplicar.
  ///
  /// Exige una respuesta de TUU que diga que no existe o no se completó. La
  /// ausencia de información nunca alcanza.
  bool get sePuedeReintentar => estado?.sePuedeVolverACobrar ?? false;

  /// `true` si no se pudo averiguar qué pasó.
  ///
  /// Pasa cuando el equipo está sin red, cuando TUU no responde, o cuando el
  /// cobro salió sin referencia y no hay por dónde preguntar. **No se puede
  /// tratar como no cobrado**: acá es donde el POS tiene que parar y
  /// preguntarle al operador antes de volver a cobrar.
  bool get necesitaRevisionManual => !cobrado && !sePuedeReintentar;

  @override
  String toString() => 'TuuPendingResolution(cobrado: $cobrado, '
      'sePuedeReintentar: $sePuedeReintentar, '
      'necesitaRevisionManual: $necesitaRevisionManual)';
}
