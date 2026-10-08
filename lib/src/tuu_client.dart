import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:flutter/services.dart';

import 'config/tuu_config.dart';
import 'config/tuu_mode.dart';
import 'models/tuu_charge_request.dart';
import 'models/tuu_pending_resolution.dart';
import 'models/tuu_transaction_status.dart';
import 'native/tuu_transaction_api.dart';
import 'models/tuu_charge_response.dart';
import 'models/tuu_pending_charge.dart';
import 'models/tuu_exception.dart';
import 'native/tuu_method_channel.dart';
import 'testing/tuu_mock_simulator.dart';

// ── Clasificación de errorCode según doc oficial TUU ─────────────────────

/// `errorCode` que TUU usa para "transacción cancelada por el usuario".
const int _tuuErrorCodeUserCancelled = 10;

/// `errorCodeOnApp` equivalente a cancelación, según doc oficial.
const String _tuuErrorCodeOnAppCancelled = 'ICE-10';

/// `errorCode` que la doc oficial de TUU clasifica como errores internos
/// del terminal o de la app TUU (configuración, llaves, red, SDK).
const Set<int> _tuuErrorCodesInternal = <int>{
  11, // El Terminal no esta correctamente configurado.
  12, // El dispositivo esta aprobado pero no se han cargado las llaves.
  14, // El dispositivo no esta conectado a internet.
  15, // El dispositivo no pudo obtener la configuración desde su cuenta.
  16, // El rubro esta en espera de asignación.
  17, // El rubro utilizado tuvo un error durante la asignación.
  20, // El SDK de Pagos no se encuentra instalado.
  21, // La aplicación de Pago necesita ser actualizada.
};

/// `errorCodeOnApp` que la doc oficial de TUU clasifica como errores
/// internos. Códigos ICE-XX devueltos por versiones recientes de la app.
const Set<String> _tuuErrorCodesOnAppInternal = <String>{
  'ICE-12', 'ICE-20', 'ICE-30', 'ICE-31', 'ICE-32', 'ICE-33', 'ICE-34',
  'ICE-35', 'ICE-37', 'ICE-43', 'ICE-44', 'ICE-45', 'ICE-46', 'ICE-47',
  'ICE-50', 'ICE-60', 'ICE-61',
};

/// Prefijo legacy `HP-5xx` para errores internos.
///
/// Versiones antiguas de la app TUU (pre-ICE) reportaban errores internos
/// con códigos `HP-5xx` (similar a HTTP 5xx). Se mantiene para
/// compatibilidad con builds desplegados.
const String _tuuErrorCodeOnAppLegacyInternalPrefix = 'HP-5';

/// Cliente principal del plugin TUU.
///
/// Fachada sobre el [TuuMethodChannel] nativo (modos `production` /
/// `debug`) o sobre el [TuuMockSimulator] (modo `mock`). Ambos son
/// inyectables vía constructor para facilitar tests.
///
/// La API pública es deliberadamente reducida: detección de instalación y
/// cobro. TUU **no** soporta vía Intent operaciones como reversa, búsqueda
/// de transacciones, pre-autorización ni cancelación programática.
///
/// ## Ejemplo
///
/// ```dart
/// final tuu = TuuClient(
///   config: const TuuConfig(
///     mode: TuuMode.production,
///     sourceName: 'DTEx',
///     sourceVersion: '1.16.0',
///   ),
/// );
///
/// if (!await tuu.isInstalled()) {
///   return; // mostrar UI alternativa
/// }
///
/// try {
///   final TuuChargeResponse result = await tuu.charge(
///     const TuuChargeRequest(amount: 12000),
///   );
///   // result.authCode, result.last4, result.sequenceNumber
/// } on TuuUserCancelledException {
///   // cajero o cliente canceló en pantalla TUU
/// } on TuuRejectedException catch (e) {
///   // adquirente rechazó; e.errorCode disponible para diagnóstico
/// } on TuuInternalException catch (e) {
///   // error de configuración / red del terminal
/// } on TuuException catch (e) {
///   // catch-all (no instalada, JSON inesperado)
/// }
/// ```
class TuuClient {
  /// Configuración del cliente. Inmutable después de la construcción.
  final TuuConfig config;

  /// Canal nativo Android (o mock inyectado en tests).
  final TuuMethodChannel _channel;

  /// Simulador para modo [TuuMode.mock] (o mock inyectado).
  final TuuMockSimulator _mock;

  /// Crea un cliente con la [config] indicada.
  ///
  /// Parámetros opcionales:
  ///  - [channel]: inyectar un [TuuMethodChannel] alternativo (tests con
  ///    `MethodChannel` mockeado).
  ///  - [mockSimulator]: inyectar un [TuuMockSimulator] alternativo. Si
  ///    no se pasa, se construye uno a partir de `config.mockBehavior`.
  TuuClient({
    required this.config,
    TuuMethodChannel? channel,
    TuuMockSimulator? mockSimulator,
  })  : _channel = channel ?? TuuMethodChannel(),
        _mock =
            mockSimulator ?? TuuMockSimulator(behavior: config.mockBehavior);

  /// `true` si `com.haulmer.paymentapp` (producción) está instalada.
  ///
  /// En modo [TuuMode.mock] siempre devuelve `true`.
  Future<bool> isInstalled() async {
    if (config.mode == TuuMode.mock) return true;
    return _channel.isInstalled(tuuPackageProduction);
  }

  /// `true` si `com.haulmer.paymentapp.dev` (desarrollo) está instalada.
  ///
  /// En modo [TuuMode.mock] siempre devuelve `true`.
  Future<bool> isInstalledDev() async {
    if (config.mode == TuuMode.mock) return true;
    return _channel.isInstalled(tuuPackageDevelopment);
  }

  /// Ejecuta un cobro contra la app TUU.
  ///
  /// Construye el body JSON usando [TuuChargeRequest.toJsonString] y los
  /// metadatos del [TuuConfig], invoca el canal nativo (o el simulador en
  /// modo mock), y parsea la respuesta para devolver un
  /// [TuuChargeResponse] aprobado.
  ///
  /// **Mapeo de errores** desde la respuesta JSON o desde la capa nativa:
  ///
  ///  - JSON con `transactionStatus: true` → retorna [TuuChargeResponse].
  ///  - JSON con `errorCode == 10` o `errorCodeOnApp == 'ICE-10'` →
  ///    [TuuUserCancelledException].
  ///  - JSON con `errorCode` en `{11,12,14,15,16,17,20,21}` o
  ///    `errorCodeOnApp` en el set de códigos `ICE-XX` internos (o con
  ///    prefijo legacy `HP-5`) → [TuuInternalException].
  ///  - Cualquier otro JSON con `errorCode` o `errorCodeOnApp` definidos →
  ///    [TuuRejectedException].
  ///  - Respuesta `null` (gesto back / RESULT_CANCELED con `data == null`)
  ///    → [TuuUserCancelledException].
  ///  - JSON no parseable o sin estructura reconocible →
  ///    [TuuUnknownException].
  ///  - [PlatformException] desde el lado nativo →
  ///    [TuuNotInstalledException] (código `MFN-04`) o
  ///    [TuuUnknownException] (cualquier otro).
  /// Devuelve el cobro que quedó sin resolver, o `null` si no hay ninguno.
  ///
  /// **Hay que llamarlo al arrancar la app, antes de ofrecer cobrar de nuevo.**
  /// En un POS, Android mata la app que pasa a segundo plano para darle memoria
  /// a la app de pagos, y eso ocurre justo mientras TUU está cobrando. El
  /// resultado del Intent sí se reentrega cuando la actividad se recrea, pero
  /// el estado de Dart ya no existe: sin esto, un cobro aprobado se pierde y
  /// el comercio cobra dos veces o no registra el primero.
  ///
  /// Lo que vuelve distingue dos situaciones, y la diferencia importa:
  ///
  ///  - [TuuPendingCharge.tieneRespuesta]: TUU respondió y nadie la recibió.
  ///    El cobro ocurrió; queda registrarlo y llamar a [clearPending].
  ///  - [TuuPendingCharge.esIncierto]: se lanzó y no se supo más. **Puede
  ///    haberse cobrado igual.** TUU no expone forma de consultar una
  ///    transacción, así que esto no se resuelve desde acá: hay que
  ///    preguntarle al operador o cruzar contra el reporte de TUU antes de
  ///    volver a cobrar.
  ///
  /// En modo mock siempre devuelve `null`: no hay proceso que morir.
  /// Le pregunta a TUU qué pasó con un cobro, por su referencia.
  ///
  /// Es lo que cierra el caso que el Intent no puede: si el POS lanzó el cobro
  /// y no supo más, esto dice si se cobró. Va contra la API REST de Haulmer,
  /// no por Intent.
  ///
  /// [serial] es el número de serie del equipo y [apiKey] la clave del
  /// comercio, que viaja en el header `X-API-Key`.
  ///
  /// Ojo con [TuuTransactionStatus.esDesconocido]: significa que no se pudo
  /// averiguar —sin red, timeout, servidor caído— y **no** que no se cobró.
  /// Volver a cobrar en ese caso puede duplicar.
  Future<TuuTransactionStatus> consultarTransaccion({
    required String externalReferenceId,
    required String serial,
    required String apiKey,
  }) async {
    final api = TuuTransactionApi(
      baseUrl: config.mode == TuuMode.production
          ? TuuTransactionApi.baseProduccion
          : TuuTransactionApi.baseDesarrollo,
    );
    return api.consultar(
      externalReferenceId: externalReferenceId,
      serial: serial,
      apiKey: apiKey,
    );
  }

  /// Resuelve el cobro pendiente consultándole a TUU, cuando hace falta.
  ///
  /// Es el camino completo y el que conviene usar al arrancar: si el pendiente
  /// ya trae respuesta no consulta nada, y si es incierto pregunta por su
  /// referencia. Devuelve `null` si no había nada pendiente.
  ///
  /// **No borra el pendiente**: eso lo decide quien llama, después de haber
  /// registrado la venta. Si se borrara acá y el registro fallara, el cobro se
  /// perdería igual.
  Future<TuuPendingResolution?> resolverPendiente({
    required String serial,
    required String apiKey,
  }) async {
    final pendiente = await pendingCharge();
    if (pendiente == null) return null;

    if (pendiente.tieneRespuesta) {
      return TuuPendingResolution(pendiente: pendiente);
    }

    final referencia = pendiente.externalReferenceId;
    if (referencia == null) {
      // Cobro lanzado antes de que el plugin mandara la referencia, o con una
      // app que la quitó: no hay por dónde preguntar.
      return TuuPendingResolution(pendiente: pendiente);
    }

    final estado = await consultarTransaccion(
      externalReferenceId: referencia,
      serial: serial,
      apiKey: apiKey,
    );
    return TuuPendingResolution(pendiente: pendiente, estado: estado);
  }

  /// Referencia de 32 hex, el mismo formato que usa ParkingCash (uuid v4 sin
  /// guiones). Se arma con [Random.secure] para no sumarle una dependencia al
  /// plugin por esto.
  String _nuevaReferencia() {
    final r = Random.secure();
    return List<String>.generate(
      16,
      (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<TuuPendingCharge?> pendingCharge() async {
    if (config.mode == TuuMode.mock) return null;
    final map = await _channel.pendingCharge();
    if (map == null) return null;
    return TuuPendingCharge.fromMap(map);
  }

  /// Da por resuelto el cobro pendiente.
  ///
  /// Hay que llamarlo después de registrar lo que devolvió [pendingCharge];
  /// si no, el mismo cobro va a reaparecer en cada arranque.
  Future<void> clearPending() async {
    if (config.mode == TuuMode.mock) return;
    await _channel.clearPending();
  }

  Future<TuuChargeResponse> charge(TuuChargeRequest request) async {
    final String packageName = config.resolvePackageName();
    // La referencia va siempre, la ponga o no la app: es la única llave con la
    // que después se le puede preguntar a TUU qué pasó con este cobro. Sin
    // ella, un cobro cuya respuesta se pierde queda irrecuperable.
    final String referencia =
        request.extraData?.externalReferenceId ?? _nuevaReferencia();
    final String jsonBody = request.toJsonString(
      sourceName: config.sourceName,
      sourceVersion: config.sourceVersion,
      defaultPrintVoucherOnApp: config.printVoucherOnApp,
      defaultDteType: config.dteType,
      externalReferenceId: referencia,
    );

    _logRequest(packageName, jsonBody);

    final String? rawResponse;
    if (config.mode == TuuMode.mock) {
      rawResponse = await _mock.simulateCharge(
        requestBody: request.toJson(
          sourceName: config.sourceName,
          sourceVersion: config.sourceVersion,
          defaultPrintVoucherOnApp: config.printVoucherOnApp,
          defaultDteType: config.dteType,
        ),
      );
    } else {
      try {
        rawResponse = await _channel.charge(
          packageName: packageName,
          jsonBody: jsonBody,
        );
      } on PlatformException catch (e) {
        _logResponse('PlatformException: ${e.code} ${e.message}');
        throw _mapPlatformException(e);
      }
    }

    _logResponse(rawResponse);

    if (rawResponse == null) {
      // Sin respuesta = gesto back / RESULT_CANCELED con data null.
      throw const TuuUserCancelledException();
    }

    return _parseAndMap(rawResponse);
  }

  // ── Parseo y mapeo de la respuesta ─────────────────────────────────────

  /// Parsea el [rawResponse] crudo y lo mapea a [TuuChargeResponse] o a
  /// la excepción correspondiente.
  TuuChargeResponse _parseAndMap(String rawResponse) {
    final Map<String, Object?> json;
    try {
      final Object? decoded = jsonDecode(rawResponse);
      if (decoded is Map<String, Object?>) {
        json = decoded;
      } else if (decoded is Map) {
        json = decoded.cast<String, Object?>();
      } else {
        throw TuuUnknownException(
          message: 'Respuesta TUU no es un objeto JSON',
          rawJson: rawResponse,
        );
      }
    } on FormatException catch (e) {
      throw TuuUnknownException(
        message: 'Respuesta TUU no es JSON válido: ${e.message}',
        rawJson: rawResponse,
      );
    }

    if (json['transactionStatus'] == true) {
      return TuuChargeResponse.fromJson(json, rawJson: rawResponse);
    }

    final int? errorCode = (json['errorCode'] as num?)?.toInt();
    final String? errorCodeOnApp = json['errorCodeOnApp'] as String?;
    final String errorMessage =
        (json['errorMessage'] as String?) ?? 'Error desconocido de TUU';
    final String? errorMessageOnApp = json['errorMessageOnApp'] as String?;

    // 1) Cancelación por usuario (errorCode == 10 o ICE-10).
    if (errorCode == _tuuErrorCodeUserCancelled ||
        errorCodeOnApp == _tuuErrorCodeOnAppCancelled) {
      throw TuuUserCancelledException(rawJson: rawResponse);
    }

    // 2) Error interno (terminal / app TUU / red / SDK / config).
    final bool isInternal = (errorCode != null &&
            _tuuErrorCodesInternal.contains(errorCode)) ||
        (errorCodeOnApp != null &&
            (_tuuErrorCodesOnAppInternal.contains(errorCodeOnApp) ||
                errorCodeOnApp.startsWith(
                  _tuuErrorCodeOnAppLegacyInternalPrefix,
                )));

    if (isInternal) {
      throw TuuInternalException(
        message: errorMessage,
        errorCode: errorCode,
        errorCodeOnApp: errorCodeOnApp,
        rawJson: rawResponse,
      );
    }

    // 3) Rechazo del adquirente / validación de campos.
    if (errorCode != null || errorCodeOnApp != null) {
      throw TuuRejectedException(
        message: errorMessage,
        errorCode: errorCode,
        errorCodeOnApp: errorCodeOnApp,
        errorMessageOnApp: errorMessageOnApp,
        rawJson: rawResponse,
      );
    }

    // 4) JSON sin transactionStatus, errorCode ni errorCodeOnApp.
    throw TuuUnknownException(
      message: 'Respuesta TUU sin transactionStatus ni errorCode',
      rawJson: rawResponse,
    );
  }

  /// Mapea una [PlatformException] del plugin Kotlin a la subclase de
  /// [TuuException] que corresponda.
  ///
  /// Códigos definidos en `TuuApp2appPlugin.kt`:
  ///  - `MFN-01` packageName faltante (bug interno del wrapper Dart).
  ///  - `MFN-02` json faltante (bug interno).
  ///  - `MFN-03` plugin sin activity attached.
  ///  - `MFN-04` app TUU no instalada.
  ///  - `MFN-05` otra carga en curso.
  ///  - `MFN-06` failure al lanzar el Intent.
  TuuException _mapPlatformException(PlatformException e) {
    if (e.code == 'MFN-04') {
      return TuuNotInstalledException(
        message: e.message ?? 'App TUU no instalada',
      );
    }
    return TuuUnknownException(
      code: e.code,
      message: e.message ?? 'Error nativo desconocido',
    );
  }

  // ── Logging ────────────────────────────────────────────────────────────

  /// `true` cuando el modo amerita emitir logs.
  bool get _shouldLog =>
      config.mode == TuuMode.debug || config.mode == TuuMode.mock;

  /// Prefijo de log según el modo activo.
  String get _logPrefix =>
      config.mode == TuuMode.mock ? '[TUU:MOCK]' : '[TUU:DEBUG]';

  /// Loggea el request vía `dart:developer.log` si el modo lo permite.
  void _logRequest(String packageName, String jsonBody) {
    if (!_shouldLog) return;
    developer.log(
      '$_logPrefix charge → $packageName\n$jsonBody',
      name: 'tuu_app2app',
    );
  }

  /// Loggea la respuesta cruda vía `dart:developer.log` si el modo lo
  /// permite. `null` se loggea explícitamente como "user cancelled".
  void _logResponse(String? rawResponse) {
    if (!_shouldLog) return;
    developer.log(
      '$_logPrefix charge ← ${rawResponse ?? '(null, user cancelled)'}',
      name: 'tuu_app2app',
    );
  }
}
