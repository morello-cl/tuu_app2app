import 'package:flutter_test/flutter_test.dart';
import 'package:tuu_app2app/tuu_app2app.dart';

/// Qué significa cada forma de quedar sin resolver.
///
/// El caso existe porque en un POS Android mata la app que pasa a segundo
/// plano para darle memoria a la app de pagos, justo mientras TUU cobra. El
/// resultado del Intent se reentrega al recrear la actividad, pero el estado
/// de Dart ya no existe.
void main() {
  group('TuuPendingCharge', () {
    const respuestaOk = '{"transactionStatus":true,"sequenceNumber":'
        '"000000017978","transactionMethod":"Tarjeta de Débito",'
        '"last4":"****7664","authCode":"029074"}';

    test('con respuesta guardada: el cobro ocurrió y hay que registrarlo', () {
      final p = TuuPendingCharge.fromMap({
        'request': '{"amount":1000}',
        'result': respuestaOk,
        'startedAt': 1760000000000,
      });

      expect(p.tieneRespuesta, isTrue);
      expect(p.esIncierto, isFalse);
      expect(p.response!.approved, isTrue);
      expect(p.response!.sequenceNumber, '000000017978');
    });

    test('sin respuesta: incierto, pudo haberse cobrado igual', () {
      final p = TuuPendingCharge.fromMap({
        'request': '{"amount":1000}',
        'result': null,
        'startedAt': 1760000000000,
      });

      expect(p.esIncierto, isTrue);
      expect(p.tieneRespuesta, isFalse);
      // No se puede dar por no cobrado: TUU no expone consulta de transacción.
      expect(p.response, isNull);
    });

    test('una respuesta de rechazo también cuenta como resuelta', () {
      // Lo que importa es que TUU contestó, no que haya aprobado: un rechazo
      // recibido tarde sigue siendo una respuesta y cierra el caso.
      final p = TuuPendingCharge.fromMap({
        'request': '{"amount":1000}',
        'result': '{"transactionStatus":false,"errorMessage":"Rechazada"}',
      });

      expect(p.tieneRespuesta, isTrue);
      expect(p.esIncierto, isFalse);
      expect(p.response!.approved, isFalse);
    });

    test('un result vacío no se confunde con una respuesta', () {
      final p = TuuPendingCharge.fromMap({
        'request': '{"amount":1000}',
        'result': '',
      });

      expect(p.tieneRespuesta, isFalse);
      expect(p.esIncierto, isTrue);
    });

    test('sin startedAt no inventa antigüedad', () {
      final p = TuuPendingCharge.fromMap({
        'request': '{"amount":1000}',
        'startedAt': 0,
      });

      expect(p.startedAt, isNull);
      expect(p.antiguedad, isNull);
    });

    test('con startedAt calcula hace cuánto se lanzó', () {
      final hace5min = DateTime.now().subtract(const Duration(minutes: 5));
      final p = TuuPendingCharge.fromMap({
        'request': '{"amount":1000}',
        'startedAt': hace5min.millisecondsSinceEpoch,
      });

      expect(p.antiguedad!.inMinutes, closeTo(5, 1));
    });
  });
}
