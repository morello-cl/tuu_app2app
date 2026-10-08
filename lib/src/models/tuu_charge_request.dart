import 'dart:convert';

import 'tuu_cashback_policy.dart';
import 'tuu_dte_type.dart';
import 'tuu_extra_data.dart';
import 'tuu_payment_method.dart';
import 'tuu_tip_policy.dart';

/// Solicitud de cobro a la app TUU.
///
/// Modela el `paymentData` que documenta TUU oficialmente. Sus campos se
/// serializan al body JSON que se envía como `Intent.EXTRA_TEXT` con
/// `MIME = text/json` y `Action = ACTION_SEND`.
///
/// Forma final del JSON serializado (referencia):
///
/// ```json
/// {
///   "amount": 12000,
///   "tip": -1,
///   "cashback": -1,
///   "method": 0,
///   "installmentsQuantity": 0,
///   "printVoucherOnApp": true,
///   "dteType": 48,
///   "extraData": {
///     "sourceName": "DTEx",
///     "sourceVersion": "1.16.0"
///   }
/// }
/// ```
///
/// **Validaciones del lado TUU** (no replicadas aquí; el cliente confía
/// en los rechazos del adquirente):
///  - `amount > 0`, máx 12 dígitos.
///  - Si se envía `taxIdnValidation` en [extraData], debe coincidir con el
///    RUT configurado en el terminal.
///  - Si se envía `netAmount + exemptAmount`, su suma debe ser igual a
///    `amount`.
///  - `cashback` sólo aplica a `method == debit`.
///  - `installmentsQuantity > 0` sólo aplica a `method == credit`.
class TuuChargeRequest {
  /// Monto total a cobrar, en pesos chilenos (entero positivo).
  ///
  /// Debe coincidir con `netAmount + exemptAmount` si esos campos se
  /// envían dentro de [extraData] — la app TUU rechaza con
  /// `errorCode: 6` si la suma no cuadra.
  final int amount;

  /// Política de propina. Default: [TuuTipPolicy.disabled] (no se pide
  /// propina).
  final TuuTipPolicy tip;

  /// Política de cashback. Default: [TuuCashbackPolicy.disabled].
  ///
  /// Sólo se honra si [method] es [TuuPaymentMethod.debit]; con otros
  /// métodos TUU lo ignora o responde `errorCode: 5`.
  final TuuCashbackPolicy cashback;

  /// Método de pago a sugerir. Default: [TuuPaymentMethod.askUser].
  final TuuPaymentMethod method;

  /// Cantidad de cuotas a sugerir. `0` = al contado. Sólo aplica a
  /// transacciones de crédito; TUU ignora el campo para débito.
  final int installmentsQuantity;

  /// Override puntual del flag [TuuConfig.printVoucherOnApp].
  ///
  /// `null` → usar el valor del config.
  final bool? printVoucherOnApp;

  /// Override puntual del [TuuConfig.dteType] usando alguna constante de
  /// [TuuDteType].
  ///
  /// `null` → usar el valor del config.
  final int? dteType;

  /// Bloque `extraData` con metadatos opcionales (RUT, netAmount,
  /// sourceName, customFields, etc.). `null` para enviar sólo
  /// `sourceName` / `sourceVersion` desde el config.
  final TuuExtraData? extraData;

  /// Construye una solicitud de cobro inmutable.
  ///
  /// [amount] es el único parámetro obligatorio; el resto tiene defaults
  /// seguros equivalentes a "cobro contado, sin propina, sin cashback,
  /// que el cajero elija el método".
  const TuuChargeRequest({
    required this.amount,
    this.tip = TuuTipPolicy.disabled,
    this.cashback = TuuCashbackPolicy.disabled,
    this.method = TuuPaymentMethod.askUser,
    this.installmentsQuantity = 0,
    this.printVoucherOnApp,
    this.dteType,
    this.extraData,
  });

  /// Serializa la request a un `Map<String, Object?>` listo para
  /// `jsonEncode`.
  ///
  /// Los parámetros vienen del [TuuConfig] que invoca este método —
  /// `TuuChargeRequest` no conoce el config para mantener la
  /// responsabilidad separada:
  ///
  ///  - [sourceName] / [sourceVersion]: se inyectan dentro de `extraData`,
  ///    rellenando esos campos sólo si la app consumidora no los fijó.
  ///  - [defaultPrintVoucherOnApp] / [defaultDteType]: se usan como
  ///    fallback si la request no los pisó explícitamente.
  ///
  /// Retorna el map (la conversión a String se hace en
  /// [toJsonString]). El `Map<String, Object?>` aquí es **detalle de
  /// serialización** — la API consumidora debería usar [toJsonString].
  Map<String, Object?> toJson({
    required String sourceName,
    required String sourceVersion,
    required bool defaultPrintVoucherOnApp,
    required int defaultDteType,
    String? externalReferenceId,
  }) {
    final TuuExtraData mergedExtra = (extraData ?? const TuuExtraData())
        .mergeDefaults(
      sourceName: sourceName,
      sourceVersion: sourceVersion,
      externalReferenceId: externalReferenceId,
    );

    return <String, Object?>{
      'amount': amount,
      'tip': tip.toJsonValue(),
      'cashback': cashback.toJsonValue(),
      'method': method.value,
      'installmentsQuantity': installmentsQuantity,
      'printVoucherOnApp': printVoucherOnApp ?? defaultPrintVoucherOnApp,
      'dteType': dteType ?? defaultDteType,
      'extraData': mergedExtra.toJson(),
    };
  }

  /// Serializa la request al **String JSON** final listo para enviar
  /// como `Intent.EXTRA_TEXT` a la app TUU.
  ///
  /// Internamente delega en [toJson] y aplica `jsonEncode`. Es el método
  /// preferido para uso externo cuando se inspecciona / loggea el body.
  String toJsonString({
    required String sourceName,
    required String sourceVersion,
    required bool defaultPrintVoucherOnApp,
    required int defaultDteType,
    String? externalReferenceId,
  }) {
    return jsonEncode(toJson(
      sourceName: sourceName,
      sourceVersion: sourceVersion,
      defaultPrintVoucherOnApp: defaultPrintVoucherOnApp,
      defaultDteType: defaultDteType,
      externalReferenceId: externalReferenceId,
    ));
  }
}
