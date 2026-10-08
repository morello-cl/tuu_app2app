import '../testing/tuu_mock_behavior.dart';
import 'tuu_mode.dart';

/// Identificador (package name) de la app TUU de **producción**.
///
/// Es el package real que Haulmer despliega en Play Store / preinstalado
/// en los terminales Kozen y Sunmi. Coincide con `BuildConfig.applicationId`
/// del proyecto TUU release.
const String tuuPackageProduction = 'com.haulmer.paymentapp';

/// Identificador (package name) de la app TUU de **desarrollo**.
///
/// Build firmado de debug que el equipo de Haulmer distribuye para QA. Suele
/// convivir lado a lado con la versión de producción en el mismo terminal.
const String tuuPackageDevelopment = 'com.haulmer.paymentapp.dev';

/// Configuración del cliente TUU.
///
/// Agrupa todo lo necesario para que [TuuClient] sepa:
///  - Contra qué package de TUU disparar el Intent (resuelto vía
///    [resolvePackageName]).
///  - En qué modo operar ([TuuMode]).
///  - Qué valores enviar en el body JSON del cobro (banderas operativas
///    y metadatos de origen).
///  - Cómo comportarse el simulador cuando el modo es [TuuMode.mock].
///
/// `const`-construible, por lo que se puede declarar como literal en código
/// e inyectar en `Provider` / DI sin penalización.
///
/// ## Ejemplo — producción
///
/// ```dart
/// final tuu = TuuClient(
///   config: const TuuConfig(
///     mode: TuuMode.production,
///     sourceName: 'DTEx',
///     sourceVersion: '1.16.0',
///   ),
/// );
/// ```
///
/// ## Ejemplo — forzar package específico
///
/// Útil en QA cuando se quiere disparar la app dev desde un build release:
///
/// ```dart
/// const config = TuuConfig(
///   mode: TuuMode.production,
///   packageName: tuuPackageDevelopment,
/// );
/// ```
///
/// ## Ejemplo — desarrollo sin app TUU
///
/// ```dart
/// const config = TuuConfig(
///   mode: TuuMode.mock,
///   sourceName: 'DTEx',
///   mockBehavior: TuuMockBehavior(
///     chargeOutcome: TuuMockOutcome.approved,
///   ),
/// );
/// ```
class TuuConfig {
  /// Override puntual del package a invocar.
  ///
  /// Si es `null` o vacío, el package se resuelve automáticamente a partir
  /// de [mode] (ver [resolvePackageName]). Si se define, este valor
  /// prevalece sobre cualquier default — útil para forzar el package de
  /// QA desde un build de producción, o viceversa.
  final String? packageName;

  /// Modo de operación: producción, debug o mock. Ver [TuuMode] para detalle.
  final TuuMode mode;

  /// Si `true`, TUU imprime el voucher del **comercio** en su propia app.
  ///
  /// La app consumidora puede seguir imprimiendo el voucher del cliente
  /// por separado (típicamente desde la impresora térmica del POS).
  ///
  /// Default: `true` (matching el comportamiento histórico de DTEx).
  final bool printVoucherOnApp;

  /// Tipo de DTE que se reporta a TUU para tracking interno en su backend.
  ///
  /// Valores típicos en Chile:
  ///  - `33` → Factura electrónica
  ///  - `48` → Boleta electrónica (default; matching DTEx)
  ///
  /// Cambia este valor si la app consumidora emite documentos distintos
  /// o si el área comercial de TUU pide segmentar por tipo de doc.
  final int dteType;

  /// Nombre de la app llamante (ej. `'DTEx'`, `'ParkingCash'`).
  ///
  /// Se envía dentro de `extraData.sourceName` del JSON y aparece en el
  /// dashboard de TUU para identificar desde dónde llegó el cobro.
  final String sourceName;

  /// Versión de la app llamante (ej. `'1.16.0'`).
  ///
  /// Se envía dentro de `extraData.sourceVersion`. La app consumidora
  /// suele obtenerla de `package_info_plus` y pasarla al construir el
  /// [TuuConfig] — el plugin no la determina por sí mismo.
  final String sourceVersion;

  /// Comportamiento del simulador cuando [mode] == [TuuMode.mock].
  ///
  /// Ignorado en los otros modos. Default: `const TuuMockBehavior()` que
  /// aprueba todos los cobros.
  final TuuMockBehavior mockBehavior;

  /// Crea una nueva configuración.
  ///
  /// Todos los parámetros tienen defaults seguros para producción salvo
  /// [sourceVersion], que conviene fijar a la versión real de la app.
  const TuuConfig({
    this.packageName,
    this.mode = TuuMode.production,
    this.printVoucherOnApp = true,
    this.dteType = 48,
    this.sourceName = 'tuu_app2app',
    this.sourceVersion = 'unknown',
    this.mockBehavior = const TuuMockBehavior(),
  });

  /// Resuelve el `packageName` efectivo a invocar.
  ///
  /// Lógica:
  ///  - Si [packageName] no es `null` ni vacío → se usa tal cual.
  ///  - Si [mode] == [TuuMode.production] → [tuuPackageProduction].
  ///  - En cualquier otro caso → [tuuPackageDevelopment].
  ///
  /// Retorna el package name a pasar al `MethodChannel` nativo.
  String resolvePackageName() {
    final String? override = packageName;
    if (override != null && override.isNotEmpty) return override;
    return mode == TuuMode.production
        ? tuuPackageProduction
        : tuuPackageDevelopment;
  }
}
