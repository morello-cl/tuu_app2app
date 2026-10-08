import 'dart:convert';
import 'dart:io';

import '../models/tuu_transaction_status.dart';

/// Consulta a TUU qué pasó con un cobro, por la referencia que generó la app.
///
/// Es la única forma de cerrar el caso en que el POS lanzó el Intent y no supo
/// más: la integración app-to-app es síncrona y no reentrega nada. Este
/// endpoint vive aparte, en la API REST de Haulmer, y **busca por
/// `externalReferenceId`, no por `sequenceNumber`** — por eso el cobro tiene
/// que salir con esa referencia o queda irrecuperable.
///
/// Usa `HttpClient` de `dart:io` para no agregarle una dependencia al plugin
/// por una sola llamada.
class TuuTransactionApi {
  /// Base de producción.
  static const String baseProduccion =
      'https://integrations.payment.haulmer.com';

  /// Base de desarrollo.
  static const String baseDesarrollo =
      'https://integrations.payment.haulmer.dev';

  final String baseUrl;
  final Duration timeout;

  const TuuTransactionApi({
    this.baseUrl = baseProduccion,
    this.timeout = const Duration(seconds: 15),
  });

  /// Pregunta por el cobro identificado por [externalReferenceId] en el equipo
  /// [serial].
  ///
  /// [apiKey] es por comercio y va en el header `X-API-Key`.
  ///
  /// Devuelve [TuuTransactionStatus.desconocido] cuando no se puede saber —sin
  /// red, timeout, error del servidor—, que **no es lo mismo que no cobrada**:
  /// quien llama no debe tomar eso como permiso para volver a cobrar.
  Future<TuuTransactionStatus> consultar({
    required String externalReferenceId,
    required String serial,
    required String apiKey,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/Transaction/ByExternalReferenceId/'
      '${Uri.encodeComponent(externalReferenceId)}/'
      '${Uri.encodeComponent(serial)}',
    );

    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = timeout;
      final request = await client.getUrl(uri).timeout(timeout);
      request.headers.set('X-API-Key', apiKey);
      final response = await request.close().timeout(timeout);
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode == 404) {
        // El 404 sí es informativo: TUU no conoce esa referencia, así que el
        // cobro no llegó a registrarse.
        return const TuuTransactionStatus.noEncontrada();
      }
      if (response.statusCode != 200) {
        return TuuTransactionStatus.desconocido(
          'HTTP ${response.statusCode}',
        );
      }

      final json = jsonDecode(body);
      if (json is! Map) {
        return const TuuTransactionStatus.desconocido('respuesta no es un objeto');
      }
      return TuuTransactionStatus.fromJson(json.cast<String, Object?>(), body);
    } catch (e) {
      // Sin red o con el servidor caído no se sabe nada. Decir «no cobrada»
      // acá sería invitar a cobrar dos veces.
      return TuuTransactionStatus.desconocido(e.toString());
    } finally {
      client?.close(force: true);
    }
  }
}
