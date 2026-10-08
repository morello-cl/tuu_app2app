/// Resultado simulado en modo [TuuMode.mock].
///
/// Cada valor corresponde a uno de los caminos posibles que la app TUU real
/// recorre al procesar un cobro. Permite ejercitar todas las ramas del
/// [TuuClient] sin requerir hardware.
enum TuuMockOutcome {
  /// Cobro aprobado por el adquirente.
  ///
  /// El simulador devuelve un JSON con `transactionStatus: true` usando
  /// los campos `approved*` de [TuuMockBehavior]. El cliente lo mapea a
  /// un [TuuChargeResponse] aprobado.
  approved,

  /// Cobro rechazado por el banco / adquirente, o falla de validación.
  ///
  /// El simulador devuelve un JSON con `errorCode` / `errorMessage`
  /// poblados desde los campos `decline*` de [TuuMockBehavior]. El cliente
  /// lo mapea a una [TuuRejectedException].
  declined,

  /// El cajero / cliente canceló en pantalla TUU.
  ///
  /// El simulador no devuelve JSON (retorna `null`, simulando
  /// `RESULT_CANCELED` con `data == null`). El cliente lo mapea a una
  /// [TuuUserCancelledException].
  userCancelled,

  /// Error interno simulado de la app TUU o del terminal
  /// (configuración, llaves, red, SDK).
  ///
  /// El simulador devuelve un JSON con los campos `internalError*` de
  /// [TuuMockBehavior]. El cliente lo mapea a una [TuuInternalException].
  internalError,
}

/// Configuración del comportamiento simulado en modo [TuuMode.mock].
///
/// Los defaults usan códigos `errorCode` y `errorCodeOnApp` reales de la
/// doc oficial de TUU para que el flujo simulado se sienta lo más cercano
/// posible al de producción.
///
/// ## Ejemplo — rechazo personalizado
///
/// ```dart
/// const behavior = TuuMockBehavior(
///   chargeOutcome: TuuMockOutcome.declined,
///   declineErrorCode: 9,
///   declineMessage: 'Tarjeta rechazada',
/// );
/// ```
///
/// ## Ejemplo — error interno
///
/// ```dart
/// const behavior = TuuMockBehavior(
///   chargeOutcome: TuuMockOutcome.internalError,
///   internalErrorCode: 14, // sin internet
///   internalErrorMessage: 'El dispositivo no esta conectado a internet.',
///   internalErrorCodeOnApp: 'ICE-14',
/// );
/// ```
class TuuMockBehavior {
  /// Resultado simulado para `TuuClient.charge()`.
  final TuuMockOutcome chargeOutcome;

  /// Delay (ms) antes de devolver la respuesta simulada.
  ///
  /// Default: 400 ms. Usar `0` en tests unitarios para que corran rápido.
  final int responseDelayMs;

  // ─── Datos simulados para `approved` ─────────────────────────────────

  /// `sequenceNumber` simulado en aprobaciones. Default: `'000000000001'`.
  final String approvedSequenceNumber;

  /// `transactionMethod` simulado. Default: `'Tarjeta de Débito'`.
  final String approvedTransactionMethod;

  /// `last4` simulado. Default: `'****0000'`.
  final String approvedLast4;

  /// `authCode` simulado. Default: `'MOCK01'`.
  final String approvedAuthCode;

  /// `transactionTip` simulado en aprobaciones. Default: `0`.
  final int approvedTransactionTip;

  /// `transactionCashback` simulado en aprobaciones. Default: `0`.
  final int approvedTransactionCashback;

  // ─── Datos simulados para `declined` ─────────────────────────────────

  /// `errorCode` numérico simulado en rechazos.
  ///
  /// Default: `9` ("Error en proceso de pago" — el rechazo genérico
  /// más común).
  ///
  /// **No usar `10`** aquí — ese valor está reservado por TUU para
  /// "cancelado por usuario" y el cliente lo mapea a
  /// [TuuUserCancelledException], no a [TuuRejectedException].
  ///
  /// **No usar `11`, `12`, `14-17`, `20-21`** — esos códigos se mapean a
  /// [TuuInternalException].
  final int declineErrorCode;

  /// `errorMessage` simulado. Default: `'Error en proceso de pago'`.
  final String declineMessage;

  /// `errorCodeOnApp` simulado en rechazos. Default: `null` (la mayoría
  /// de los rechazos puros del adquirente no traen `errorCodeOnApp`).
  final String? declineErrorCodeOnApp;

  /// `errorMessageOnApp` simulado en rechazos. Default: `null`.
  final String? declineErrorMessageOnApp;

  // ─── Datos simulados para `internalError` ────────────────────────────

  /// `errorCode` simulado en errores internos.
  ///
  /// Default: `12` ("El dispositivo esta aprobado pero no se han cargado
  /// las llaves" — caso común al activar terminales nuevos).
  final int internalErrorCode;

  /// `errorMessage` simulado. Default coincide con el `errorCode 12` real.
  final String internalErrorMessage;

  /// `errorCodeOnApp` simulado. Default: `'ICE-12'` (matching `errorCode 12`).
  final String internalErrorCodeOnApp;

  /// `errorMessageOnApp` simulado. Default: `'Llaves no inyectadas'`.
  final String internalErrorMessageOnApp;

  /// Crea un comportamiento de mock con defaults que aprueban todo cobro.
  const TuuMockBehavior({
    this.chargeOutcome = TuuMockOutcome.approved,
    this.responseDelayMs = 400,
    this.approvedSequenceNumber = '000000000001',
    this.approvedTransactionMethod = 'Tarjeta de Débito',
    this.approvedLast4 = '****0000',
    this.approvedAuthCode = 'MOCK01',
    this.approvedTransactionTip = 0,
    this.approvedTransactionCashback = 0,
    this.declineErrorCode = 9,
    this.declineMessage = 'Error en proceso de pago',
    this.declineErrorCodeOnApp,
    this.declineErrorMessageOnApp,
    this.internalErrorCode = 12,
    this.internalErrorMessage =
        'El dispositivo esta aprobado pero no se han cargado las llaves.',
    this.internalErrorCodeOnApp = 'ICE-12',
    this.internalErrorMessageOnApp = 'Llaves no inyectadas',
  });
}
