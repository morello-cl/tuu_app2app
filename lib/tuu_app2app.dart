/// Cliente Flutter para integración **app-to-app** con la app de pagos
/// **TUU** (ex-Haulmer Pagos).
///
/// La comunicación se realiza vía **Android Intent + `startActivityForResult`**
/// contra los packages:
///
///  - `com.haulmer.paymentapp` (producción)
///  - `com.haulmer.paymentapp.dev` (desarrollo)
///
/// **No** usa HTTP, sockets ni red local. La app TUU debe estar
/// instalada en el mismo dispositivo Android.
///
/// ## Componentes públicos
///
///  - [TuuClient]: fachada principal. `isInstalled()`, `isInstalledDev()`,
///    `charge()`.
///  - [TuuConfig] / [TuuMode]: configuración (modo, package, metadatos,
///    comportamiento del mock).
///  - **Modelos tipados** (no `Object?` ni `dynamic` en la API pública):
///    - [TuuChargeRequest] / [TuuChargeResponse]
///    - [TuuPaymentMethod] (askUser / credit / debit)
///    - [TuuTipPolicy] (disabled / askUser / fixed)
///    - [TuuCashbackPolicy] (disabled / askUser / fixed)
///    - [TuuExtraData] / [TuuCustomField]
///    - [TuuDteType] (constantes documentadas: factura, boleta, ...)
///  - [TuuException] (sealed) + subclases: errores tipados.
///  - [TuuMockBehavior] / [TuuMockOutcome] / [TuuMockSimulator]:
///    simulador para desarrollo sin app TUU instalada.
///  - [PackageInfo]: versión, equipo y changelog del paquete.
///
/// Ver `docs/GUIA_TECNICA.md` para la guía completa de integración.
library;

// ── Config ───────────────────────────────────────────────────────────────
export 'src/config/tuu_config.dart';
export 'src/config/tuu_mode.dart';

// ── Modelos tipados ──────────────────────────────────────────────────────
export 'src/models/tuu_charge_request.dart';
export 'src/models/tuu_charge_response.dart';
export 'src/models/tuu_pending_charge.dart';
export 'src/models/tuu_payment_method.dart';
export 'src/models/tuu_tip_policy.dart';
export 'src/models/tuu_cashback_policy.dart';
export 'src/models/tuu_dte_type.dart';
export 'src/models/tuu_extra_data.dart';
export 'src/models/tuu_custom_field.dart';
export 'src/models/tuu_exception.dart';

// ── Testing / mock ──────────────────────────────────────────────────────
export 'src/testing/tuu_mock_behavior.dart';
export 'src/testing/tuu_mock_simulator.dart';

// ── Native (advanced — para inyección en tests) ─────────────────────────
export 'src/native/tuu_method_channel.dart';

// ── Info del paquete ─────────────────────────────────────────────────────
export 'src/package_info.dart';

// ── Cliente ──────────────────────────────────────────────────────────────
export 'src/tuu_client.dart';
