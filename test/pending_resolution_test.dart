import 'package:flutter_test/flutter_test.dart';
import 'package:tuu_app2app/tuu_app2app.dart';

/// La pregunta que decide si se duplica un cobro: ¿se puede volver a cobrar?
///
/// La regla es que sólo una respuesta explícita de TUU habilita el reintento.
/// No saber nunca alcanza: sin red o con TUU caído, volver a cobrar duplica.
void main() {
  TuuPendingCharge pendienteIncierto() => TuuPendingCharge.fromMap({
        'request': '{"amount":1000,"extraData":{"externalReferenceId":"abc123"}}',
      });

  TuuPendingCharge pendienteConRespuesta() => TuuPendingCharge.fromMap({
        'request': '{"amount":1000}',
        'result': '{"transactionStatus":true,"sequenceNumber":"000000017978"}',
      });

  group('TuuPendingResolution', () {
    test('con respuesta guardada: cobrado, sin consultar nada', () {
      final r = TuuPendingResolution(pendiente: pendienteConRespuesta());

      expect(r.cobrado, isTrue);
      expect(r.sePuedeReintentar, isFalse);
      expect(r.necesitaRevisionManual, isFalse);
    });

    test('TUU dice completed: cobrado', () {
      final r = TuuPendingResolution(
        pendiente: pendienteIncierto(),
        estado: TuuTransactionStatus.fromJson({'status': 'completed'}),
      );

      expect(r.cobrado, isTrue);
      expect(r.sePuedeReintentar, isFalse);
    });

    test('TUU no la encuentra: se puede volver a cobrar', () {
      final r = TuuPendingResolution(
        pendiente: pendienteIncierto(),
        estado: const TuuTransactionStatus.noEncontrada(),
      );

      expect(r.cobrado, isFalse);
      expect(r.sePuedeReintentar, isTrue);
      expect(r.necesitaRevisionManual, isFalse);
    });

    test('sin red NO habilita reintentar: va a revisión manual', () {
      // El caso que más caro sale si se trata como «no cobrada».
      final r = TuuPendingResolution(
        pendiente: pendienteIncierto(),
        estado: const TuuTransactionStatus.desconocido('SocketException'),
      );

      expect(r.cobrado, isFalse);
      expect(r.sePuedeReintentar, isFalse);
      expect(r.necesitaRevisionManual, isTrue);
    });

    test('un cobro sin referencia no se puede consultar: revisión manual', () {
      // Lanzado por una versión del plugin anterior a la referencia.
      final r = TuuPendingResolution(pendiente: pendienteIncierto());

      expect(r.cobrado, isFalse);
      expect(r.sePuedeReintentar, isFalse);
      expect(r.necesitaRevisionManual, isTrue);
    });

    test('un status desconocido no se lee como cobrado', () {
      final r = TuuPendingResolution(
        pendiente: pendienteIncierto(),
        estado: TuuTransactionStatus.fromJson({'status': 'pending'}),
      );

      expect(r.cobrado, isFalse);
      // Se puede reintentar porque TUU respondió y no está completada.
      expect(r.sePuedeReintentar, isTrue);
    });
  });

  group('TuuPendingCharge.externalReferenceId', () {
    test('lo saca del extraData del request', () {
      final p = TuuPendingCharge.fromMap({
        'request': '{"amount":1000,"extraData":{"externalReferenceId":"abc123",'
            '"sourceName":"DTEx"}}',
      });

      expect(p.externalReferenceId, 'abc123');
    });

    test('también si extraData viene como String escapado (legacy)', () {
      final p = TuuPendingCharge.fromMap({
        'request': r'{"amount":1000,"extraData":"{\"externalReferenceId\":\"abc123\"}"}',
      });

      expect(p.externalReferenceId, 'abc123');
    });

    test('null si el cobro salió sin referencia', () {
      final p = TuuPendingCharge.fromMap({
        'request': '{"amount":1000,"extraData":{"sourceName":"DTEx"}}',
      });

      expect(p.externalReferenceId, isNull);
    });

    test('null si el request no es JSON válido, sin lanzar', () {
      final p = TuuPendingCharge.fromMap({'request': 'no soy json'});

      expect(p.externalReferenceId, isNull);
    });
  });
}
