import 'dart:convert';

import 'tuu_mock_behavior.dart';

/// Simulador de respuestas de la app TUU para el modo [TuuMode.mock].
///
/// Genera JSONs con la misma forma que devuelve la app TUU real (per
/// doc oficial), configurables vía [TuuMockBehavior]. **No** dispara
/// ningún Intent y no requiere `package:flutter/services.dart` — funciona
/// en tests Dart puros y en `flutter test` indistintamente.
///
/// Diseño: el simulador devuelve un `String?` (JSON crudo o `null` para
/// representar cancelación por gesto back). El [TuuClient] luego parsea
/// ese String exactamente igual que cuando viene del Intent real. De esta
/// forma **mock y producción comparten el código de parseo y mapeo de
/// errores**.
class TuuMockSimulator {
  /// Comportamiento configurado.
  final TuuMockBehavior behavior;

  /// Crea un simulador con el [behavior] indicado.
  const TuuMockSimulator({required this.behavior});

  /// Simula la respuesta de un `charge()`.
  ///
  /// El [requestBody] es el body JSON que [TuuClient] habría enviado a la
  /// app TUU real. El simulador no lo valida — sólo extrae `extraData`
  /// para hacer eco de ello en la respuesta simulada (matching el
  /// comportamiento real de TUU, que reenvía `extraData` como string
  /// escapada).
  ///
  /// Retorna:
  ///  - String JSON aprobado para [TuuMockOutcome.approved].
  ///  - String JSON con `errorCode` para [TuuMockOutcome.declined] y
  ///    [TuuMockOutcome.internalError].
  ///  - `null` para [TuuMockOutcome.userCancelled].
  Future<String?> simulateCharge({
    required Map<String, Object?> requestBody,
  }) async {
    if (behavior.responseDelayMs > 0) {
      await Future<void>.delayed(
        Duration(milliseconds: behavior.responseDelayMs),
      );
    }

    // Eco de `extraData` como String escapada — TUU real lo hace así.
    final Object? extra = requestBody['extraData'];
    final String? extraEncoded = extra is Map ? jsonEncode(extra) : null;

    switch (behavior.chargeOutcome) {
      case TuuMockOutcome.approved:
        return jsonEncode(<String, Object?>{
          'sequenceNumber': behavior.approvedSequenceNumber,
          'transactionStatus': true,
          'transactionMethod': behavior.approvedTransactionMethod,
          'transactionInstallments': 0,
          'last4': behavior.approvedLast4,
          'authCode': behavior.approvedAuthCode,
          'transactionAmountInstallments': 0,
          'transactionDeferredPeriod': 0,
          'maxInstallmentsChargeFree': 12,
          'printerVoucherCommerce': false,
          'transactionTip': behavior.approvedTransactionTip,
          'transactionCashback': behavior.approvedTransactionCashback,
          if (extraEncoded != null) 'extraData': extraEncoded,
        });

      case TuuMockOutcome.declined:
        return jsonEncode(<String, Object?>{
          'errorCode': behavior.declineErrorCode,
          'errorMessage': behavior.declineMessage,
          if (behavior.declineErrorCodeOnApp != null)
            'errorCodeOnApp': behavior.declineErrorCodeOnApp,
          if (behavior.declineErrorMessageOnApp != null)
            'errorMessageOnApp': behavior.declineErrorMessageOnApp,
          if (extraEncoded != null) 'extraData': extraEncoded,
        });

      case TuuMockOutcome.userCancelled:
        // Simula gesto back / RESULT_CANCELED con data null.
        return null;

      case TuuMockOutcome.internalError:
        return jsonEncode(<String, Object?>{
          'errorCode': behavior.internalErrorCode,
          'errorMessage': behavior.internalErrorMessage,
          'errorCodeOnApp': behavior.internalErrorCodeOnApp,
          'errorMessageOnApp': behavior.internalErrorMessageOnApp,
          if (extraEncoded != null) 'extraData': extraEncoded,
        });
    }
  }
}
