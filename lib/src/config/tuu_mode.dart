/// Modo de operación del cliente TUU.
///
/// El modo seleccionado determina tres comportamientos del [TuuClient]:
///
///  1. **Resolución del `packageName` por default** cuando el consumidor no
///     lo fija explícitamente en [TuuConfig.packageName]:
///       - [production] → `com.haulmer.paymentapp`
///       - [debug] / [mock] → `com.haulmer.paymentapp.dev`
///  2. **Nivel de logging:** [production] no loggea nada, mientras que
///     [debug] y [mock] emiten líneas con prefijo `[TUU:DEBUG]` / `[TUU:MOCK]`
///     vía `dart:developer.log`.
///  3. **Origen de la respuesta:** [production] / [debug] disparan un Intent
///     real contra la app TUU, mientras que [mock] devuelve respuestas
///     simuladas por [TuuMockSimulator] sin tocar el plugin nativo.
///
/// ## Ejemplo
///
/// ```dart
/// // Producción — Intent real contra com.haulmer.paymentapp, sin logs.
/// const config = TuuConfig(mode: TuuMode.production);
///
/// // Debug — Intent real contra com.haulmer.paymentapp.dev + logs.
/// const config = TuuConfig(mode: TuuMode.debug);
///
/// // Mock — sin Intent; respuesta simulada según [TuuMockBehavior].
/// const config = TuuConfig(mode: TuuMode.mock);
/// ```
enum TuuMode {
  /// Modo producción.
  ///
  /// - `packageName` por default: `com.haulmer.paymentapp`.
  /// - Sin logs.
  /// - Sólo Intent real contra la app TUU. **Nunca** mockea, ni siquiera
  ///   ante errores transitorios.
  production,

  /// Modo debug.
  ///
  /// - `packageName` por default: `com.haulmer.paymentapp.dev`.
  /// - Logs detallados de request y response con prefijo `[TUU:DEBUG]`.
  /// - Sólo Intent real. **Nunca** mockea (a diferencia del comportamiento
  ///   histórico de DTEx, que en `kDebugMode` re-aprobaba rechazos).
  debug,

  /// Modo mock — desarrollo sin app TUU instalada en el dispositivo.
  ///
  /// - `packageName` por default: `com.haulmer.paymentapp.dev` (sólo para
  ///   consistencia de logs; no se usa porque no se dispara Intent).
  /// - **No** dispara ningún Intent.
  /// - Devuelve respuestas simuladas vía [TuuMockSimulator], configurable
  ///   con [TuuMockBehavior]. La respuesta simulada se serializa al mismo
  ///   formato JSON que la app real, garantizando que el camino de parseo
  ///   y mapeo de errores es idéntico al de producción.
  /// - Logs con prefijo `[TUU:MOCK]`.
  ///
  /// Útil para desarrollar flujos de UI y lógica de negocio sin requerir
  /// un dispositivo Android con `com.haulmer.paymentapp` (o tests que no
  /// pueden depender de `package:flutter/services.dart` real).
  mock,
}
