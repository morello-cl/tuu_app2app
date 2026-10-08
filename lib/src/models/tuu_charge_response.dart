import 'dart:convert';

import 'tuu_extra_data.dart';

/// Respuesta tipada de un `charge()` ejecutado contra la app TUU.
///
/// Modela el `transactionResult` que documenta TUU oficialmente, con
/// campos adicionales que la app TUU devuelve en la práctica (observados
/// en DTEx, no listados en el doc resumen: `transactionMethod`, `last4`,
/// `authCode`, etc.).
///
/// Sólo se construye para transacciones **aprobadas**. Las respuestas de
/// rechazo (`transactionStatus: false`) las convierte [TuuClient] en
/// excepciones ([TuuRejectedException], [TuuInternalException],
/// [TuuUserCancelledException]) antes de devolver al llamador, por lo que
/// [approved] es siempre `true` en una instancia entregada por el cliente.
///
/// El JSON crudo original queda preservado en [rawJson] como String
/// para diagnóstico de soporte y trazabilidad.
class TuuChargeResponse {
  /// Siempre `true` en instancias construidas por [TuuClient].
  final bool approved;

  /// Número de secuencia (12 dígitos) generado por TUU. Persistir.
  final String? sequenceNumber;

  /// Descripción legible del método efectivamente usado.
  ///
  /// Valores observados: `'Tarjeta de Débito'`, `'Tarjeta de Crédito'`.
  /// No está en el doc resumen oficial pero la app TUU lo devuelve.
  final String? transactionMethod;

  /// Cantidad de cuotas efectivamente cobradas. `0` = contado.
  final int transactionInstallments;

  /// Últimos 4 dígitos enmascarados de la tarjeta (ej. `'****7664'`).
  final String? last4;

  /// Código de autorización del adquirente. Persistir para conciliación.
  final String? authCode;

  /// Monto por cuota (`0` si es contado).
  final int transactionAmountInstallments;

  /// Período diferido en meses (`0` si no aplica).
  final int transactionDeferredPeriod;

  /// Máximo de cuotas sin interés permitido por el adquirente.
  final int maxInstallmentsChargeFree;

  /// `true` si TUU efectivamente imprimió el voucher del comercio.
  final bool printerVoucherCommerce;

  /// Monto de propina efectivamente aplicado (per doc oficial).
  ///
  /// `null` si la app TUU omitió el campo (versiones antiguas).
  final int? transactionTip;

  /// Monto de cashback efectivamente aplicado (per doc oficial).
  ///
  /// `null` si la app TUU omitió el campo o si no aplica (crédito).
  final int? transactionCashback;

  /// `extraData` devuelto por TUU (echo del request). `null` si TUU no
  /// lo devolvió o no se pudo parsear.
  final TuuExtraData? extraData;

  /// JSON crudo (String) tal como llegó del Intent. Preservado para
  /// diagnóstico — útil para soporte de TUU ante respuestas inesperadas.
  final String? rawJson;

  /// Constructor de bajo nivel — pensado para tests y simulador.
  ///
  /// El path normal para consumir respuestas reales es
  /// [TuuChargeResponse.fromJsonString].
  const TuuChargeResponse({
    required this.approved,
    this.sequenceNumber,
    this.transactionMethod,
    this.transactionInstallments = 0,
    this.last4,
    this.authCode,
    this.transactionAmountInstallments = 0,
    this.transactionDeferredPeriod = 0,
    this.maxInstallmentsChargeFree = 0,
    this.printerVoucherCommerce = false,
    this.transactionTip,
    this.transactionCashback,
    this.extraData,
    this.rawJson,
  });

  /// Construye una respuesta aprobada desde el JSON parseado devuelto por
  /// TUU.
  ///
  /// Asume que el llamador ya validó `json['transactionStatus'] == true`
  /// (es responsabilidad de [TuuClient] redirigir los rechazos a
  /// excepciones antes de invocar este factory).
  ///
  /// El campo `extraData` se intenta parsear con
  /// [TuuExtraData.tryParseResponseValue] — soporta tanto el formato
  /// String escapado (DTEx legacy) como el objeto JSON nuevo.
  ///
  /// Campos faltantes se rellenan con defaults numéricos `0` o `null`
  /// según el tipo — el factory nunca lanza por JSON incompleto.
  factory TuuChargeResponse.fromJson(
    Map<String, Object?> json, {
    String? rawJson,
  }) {
    return TuuChargeResponse(
      approved: json['transactionStatus'] == true,
      sequenceNumber: json['sequenceNumber'] as String?,
      transactionMethod: json['transactionMethod'] as String?,
      transactionInstallments:
          (json['transactionInstallments'] as num?)?.toInt() ?? 0,
      last4: json['last4'] as String?,
      authCode: json['authCode'] as String?,
      transactionAmountInstallments:
          (json['transactionAmountInstallments'] as num?)?.toInt() ?? 0,
      transactionDeferredPeriod:
          (json['transactionDeferredPeriod'] as num?)?.toInt() ?? 0,
      maxInstallmentsChargeFree:
          (json['maxInstallmentsChargeFree'] as num?)?.toInt() ?? 0,
      printerVoucherCommerce: json['printerVoucherCommerce'] == true,
      transactionTip: (json['transactionTip'] as num?)?.toInt(),
      transactionCashback: (json['transactionCashback'] as num?)?.toInt(),
      extraData: TuuExtraData.tryParseResponseValue(json['extraData']),
      rawJson: rawJson,
    );
  }

  /// Construye una respuesta desde el **String JSON crudo** tal como vino
  /// del Intent (`Intent.data.transactionResult` o `resultJson`).
  ///
  /// Lanza [FormatException] si el String no es JSON válido o no es un
  /// objeto JSON. [TuuClient] envuelve esta excepción en
  /// `TuuUnknownException` antes de propagarla.
  factory TuuChargeResponse.fromJsonString(String rawJson) {
    final Object? decoded = jsonDecode(rawJson);
    if (decoded is Map<String, Object?>) {
      return TuuChargeResponse.fromJson(decoded, rawJson: rawJson);
    }
    if (decoded is Map) {
      return TuuChargeResponse.fromJson(
        decoded.cast<String, Object?>(),
        rawJson: rawJson,
      );
    }
    throw const FormatException('TUU response is not a JSON object');
  }

  @override
  String toString() =>
      'TuuChargeResponse(approved: $approved, authCode: $authCode, '
      'last4: $last4, method: $transactionMethod, seq: $sequenceNumber)';
}
