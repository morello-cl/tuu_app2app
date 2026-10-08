# Guía técnica — `tuu_app2app`

> **Versión:** 0.2.0
> **Fecha:** 2026-05-13
> **Contacto:** marco@mufin.cl
> **Documentación oficial TUU:** https://developers.tuu.cl/docs/integraci%C3%B3n-de-aplicaciones-de-pago-inter-app-new

Plugin Flutter para integración **app-to-app** con la app de pagos
**TUU** (ex-Haulmer Pagos). Pensado para apps Flutter de MUFIN (DTEx,
ParkingCash) que necesiten cobrar con tarjeta delegando la captura del
plástico a la app TUU instalada en el mismo dispositivo Android.

---

## Tabla de contenidos

1. [Arquitectura](#1-arquitectura)
2. [Instalación](#2-instalación)
3. [Configuración Android](#3-configuración-android)
4. [API pública](#4-api-pública)
5. [Modos de operación](#5-modos-de-operación)
6. [Flujo de cobro](#6-flujo-de-cobro)
7. [Modelos de datos](#7-modelos-de-datos)
8. [Manejo de errores](#8-manejo-de-errores)
9. [Tabla de códigos `errorCode`](#9-tabla-de-códigos-errorcode)
10. [Modo mock para desarrollo](#10-modo-mock-para-desarrollo)
11. [Migración desde la integración legacy de DTEx](#11-migración-desde-la-integración-legacy-de-dtex)
12. [Limitaciones conocidas](#12-limitaciones-conocidas)
13. [Troubleshooting](#13-troubleshooting)

---

## 1. Arquitectura

```
┌──────────────────────┐  Intent ACTION_SEND     ┌──────────────────────┐
│  App Flutter MUFIN   │  text/json + EXTRA_TEXT │  App TUU             │
│  (DTEx / ParkingCash)│ ──────────────────────► │  com.haulmer.        │
│                      │                         │  paymentapp(.dev)    │
│  TuuClient           │ ◄────────────────────── │                      │
└──────────────────────┘  onActivityResult       └──────────┬───────────┘
                         (transactionResult)                │
                                                            │ HTTPS
                                                            ▼
                                                  ┌──────────────────────┐
                                                  │  Backend TUU         │
                                                  │  (Autorización)      │
                                                  └──────────────────────┘
```

- La **app Flutter** dispara un `Intent.ACTION_SEND` con `MIME = text/json`
  contra el package de TUU. El body es un JSON serializado en `EXTRA_TEXT`.
- La **app TUU** toma control de pantalla, opera el lector de tarjeta y
  habla con el backend de TUU por su cuenta.
- Cuando TUU termina, devuelve el control a la app Flutter vía
  `onActivityResult` con el resultado JSON en el extra
  `transactionResult` (versiones nuevas) o `resultJson` (versiones
  antiguas — DTEx legacy). El plugin lee ambos.

El plugin **no** habla HTTP con TUU; toda esa comunicación queda
encapsulada en la app TUU.

---

## 2. Instalación

### Dependencia local (vía path)

En el `pubspec.yaml` de la app consumidora:

```yaml
dependencies:
  tuu_app2app:
    path: ../tuu_app2app   # ajustar al path real
```

```bash
flutter pub get
```

### Requisitos

- Flutter ≥ 3.0.0, Dart ≥ 3.0.0.
- Android `minSdkVersion ≥ 23`, `compileSdk = 34`.
- App TUU instalada en el dispositivo (`com.haulmer.paymentapp` o
  `com.haulmer.paymentapp.dev`).

---

## 3. Configuración Android

### 3.1 `<queries>` — visibilidad de package en Android 11+

El plugin **ya declara** el bloque `<queries>` en su propio
`AndroidManifest.xml`. Gradle lo mergea automáticamente al manifest de la
app consumidora — no requiere cambios manuales:

```xml
<queries>
    <package android:name="com.haulmer.paymentapp" />
    <package android:name="com.haulmer.paymentapp.dev" />
</queries>
```

Sin este bloque, `PackageManager.getLaunchIntentForPackage(...)` devuelve
`null` en Android 11+ aunque la app esté instalada.

### 3.2 `launchMode` recomendado

La `MainActivity` de la app consumidora debería declarar
`android:launchMode="singleTask"` para evitar que Android cree una nueva
instancia al volver desde TUU:

```xml
<activity
    android:name=".MainActivity"
    android:launchMode="singleTask"
    ...>
```

DTEx ya lo tiene desde la integración Kushki — no requiere cambio.

### 3.3 Permissions

Ninguna especial. Los Intents inter-app no requieren `<uses-permission>`.

---

## 4. API pública

Toda la API se importa desde un único entrypoint:

```dart
import 'package:tuu_app2app/tuu_app2app.dart';
```

### 4.1 `TuuClient`

Fachada principal. Tres métodos:

```dart
class TuuClient {
  TuuClient({
    required TuuConfig config,
    TuuMethodChannel? channel,         // inyectable para tests
    TuuMockSimulator? mockSimulator,   // inyectable para tests
  });

  /// `true` si com.haulmer.paymentapp está instalada.
  /// En modo mock siempre devuelve true.
  Future<bool> isInstalled();

  /// `true` si com.haulmer.paymentapp.dev está instalada.
  Future<bool> isInstalledDev();

  /// Ejecuta un cobro. Retorna [TuuChargeResponse] aprobada, o lanza
  /// una subclase de [TuuException].
  Future<TuuChargeResponse> charge(TuuChargeRequest request);
}
```

### 4.2 `TuuConfig`

```dart
const config = TuuConfig(
  mode: TuuMode.production,          // production | debug | mock
  packageName: null,                 // override opcional del package
  printVoucherOnApp: true,           // TUU imprime voucher comercio
  dteType: TuuDteType.boleta,        // 48 por default
  sourceName: 'DTEx',                // identificación en dashboard TUU
  sourceVersion: '1.16.0',           // versión de la app llamante
  mockBehavior: TuuMockBehavior(),   // sólo se honra en mode = mock
);
```

---

## 5. Modos de operación

| Modo | `packageName` default | Logs | Origen de la respuesta |
|------|----------------------|------|------------------------|
| `production` | `com.haulmer.paymentapp` | — | Intent real |
| `debug` | `com.haulmer.paymentapp.dev` | `[TUU:DEBUG]` | Intent real |
| `mock` | `com.haulmer.paymentapp.dev` | `[TUU:MOCK]` | `TuuMockSimulator` (sin Intent) |

### Diseño deliberado: no auto-mock en `kDebugMode`

El wrapper legacy de DTEx (`haulmer_native.dart`) tenía un comportamiento
que en `kDebugMode` re-aprobaba transacciones rechazadas. Este plugin
**no** repite ese anti-patrón: el mock es **explícito** vía
`TuuMode.mock`. Un `TuuMode.debug` real dispara siempre el Intent
verdadero, sin substituciones.

---

## 6. Flujo de cobro

### 6.1 Construcción del cliente

```dart
final tuu = TuuClient(
  config: TuuConfig(
    mode: TuuMode.production,
    sourceName: 'DTEx',
    sourceVersion: appVersion,        // p.ej. package_info_plus
  ),
);
```

### 6.2 Detección de TUU

```dart
if (!await tuu.isInstalled()) {
  // mostrar UI alternativa de pago / bloquear botón tarjeta
  return;
}
```

### 6.3 Cobro

```dart
final request = TuuChargeRequest(
  amount: 12000,
  tip: TuuTipPolicy.disabled,
  method: TuuPaymentMethod.askUser,
);

try {
  final TuuChargeResponse result = await tuu.charge(request);

  // Persistir lo importante para conciliación / soporte:
  await db.insertCardPayment(
    sequenceNumber: result.sequenceNumber,
    authCode: result.authCode,
    last4: result.last4,
    method: result.transactionMethod,
    installments: result.transactionInstallments,
    appliedTip: result.transactionTip,
  );
} on TuuException catch (e) {
  // Ver sección 8 para el manejo de errores.
}
```

### 6.4 Cobro con propina configurable

```dart
// Caso 1: la app integradora calcula la propina ella misma.
const request = TuuChargeRequest(
  amount: 12000,
  tip: TuuTipPolicy.fixed(1500),
);

// Caso 2: el cajero ingresa la propina en pantalla TUU.
const request = TuuChargeRequest(
  amount: 12000,
  tip: TuuTipPolicy.askUser,
);

// Caso 3: cobro sin propina.
const request = TuuChargeRequest(
  amount: 12000,
  tip: TuuTipPolicy.disabled,   // default
);
```

### 6.5 Cobro con cashback (sólo débito)

```dart
const request = TuuChargeRequest(
  amount: 12000,
  method: TuuPaymentMethod.debit,
  cashback: TuuCashbackPolicy.fixed(5000),
);
```

Si se envía `cashback != disabled` con `TuuPaymentMethod.credit` o
`askUser`, la app TUU ignora el campo o responde `errorCode: 5`.

### 6.6 Cobro con campos custom para el voucher

```dart
const request = TuuChargeRequest(
  amount: 12000,
  extraData: TuuExtraData(
    netAmount: 10084,
    exemptAmount: 0,
    customFields: [
      TuuCustomField(name: 'orden', value: 'ORD-2026-00123', print: true),
      TuuCustomField(name: 'caja', value: 'C-04', print: true),
    ],
  ),
);
```

Restricciones (TUU las valida):
- `name`: alfanumérico, max 50 chars.
- `value`: alfanumérico, max 200 chars.
- Sin caracteres `&` ni `/` (TUU responde `errorCode: I-03`).

---

## 7. Modelos de datos

### 7.1 `TuuChargeRequest`

| Campo | Tipo | Default | Notas |
|-------|------|---------|-------|
| `amount` | `int` | — (obligatorio) | CLP, entero, > 0, max 12 dígitos |
| `tip` | `TuuTipPolicy` | `disabled` | `disabled` / `askUser` / `fixed(n)` |
| `cashback` | `TuuCashbackPolicy` | `disabled` | Igual; sólo aplica a débito |
| `method` | `TuuPaymentMethod` | `askUser` | `askUser=0`, `credit=1`, `debit=2` |
| `installmentsQuantity` | `int` | `0` | Sólo crédito |
| `printVoucherOnApp` | `bool?` | (config) | Override puntual |
| `dteType` | `int?` | (config) | Override puntual; usar `TuuDteType.*` |
| `extraData` | `TuuExtraData?` | `null` | Metadatos opcionales |

### 7.2 `TuuChargeResponse`

| Campo | Tipo | Notas |
|-------|------|-------|
| `approved` | `bool` | Siempre `true` en instancias del cliente |
| `sequenceNumber` | `String?` | 12 dígitos — persistir |
| `transactionMethod` | `String?` | `'Tarjeta de Débito'`, etc. |
| `transactionInstallments` | `int` | `0` = contado |
| `last4` | `String?` | `'****7664'` |
| `authCode` | `String?` | Código de autorización adquirente |
| `transactionAmountInstallments` | `int` | Monto por cuota |
| `transactionDeferredPeriod` | `int` | Meses diferidos |
| `maxInstallmentsChargeFree` | `int` | Cuotas sin interés permitidas |
| `printerVoucherCommerce` | `bool` | TUU imprimió voucher comercio |
| `transactionTip` | `int?` | Propina efectivamente aplicada |
| `transactionCashback` | `int?` | Cashback efectivamente aplicado |
| `extraData` | `TuuExtraData?` | Echo del request |
| `rawJson` | `String?` | JSON crudo original (para soporte) |

### 7.3 `TuuExtraData`

| Campo | Tipo | Notas |
|-------|------|-------|
| `taxIdnValidation` | `String?` | RUT comercio, formato `11111111-1` |
| `exemptAmount` | `int?` | CLP exento de IVA |
| `netAmount` | `int?` | CLP afecto a IVA |
| `sourceName` | `String?` | Auto-rellenado desde `TuuConfig` |
| `sourceVersion` | `String?` | Auto-rellenado desde `TuuConfig` |
| `customFields` | `List<TuuCustomField>` | Para imprimir en voucher |

### 7.4 `TuuPaymentMethod` — valores oficiales

```dart
TuuPaymentMethod.askUser   // 0 — TUU pregunta en pantalla
TuuPaymentMethod.credit    // 1
TuuPaymentMethod.debit     // 2
```

> **Ojo:** este orden corrige un error del wrapper legacy de DTEx que
> tenía `1 = débito, 2 = crédito`. El plugin sigue el orden oficial.

### 7.5 `TuuTipPolicy` / `TuuCashbackPolicy`

Tres casos cada una:

```dart
TuuTipPolicy.disabled            // -1 → TUU no pedirá propina
TuuTipPolicy.askUser             //  0 → TUU pregunta al usuario
const TuuTipPolicy.fixed(1500)   // >0 → propina fija

TuuCashbackPolicy.disabled       // -1
TuuCashbackPolicy.askUser        //  0
const TuuCashbackPolicy.fixed(5000)
```

### 7.6 `TuuDteType` — constantes oficiales

```dart
TuuDteType.none              // 0
TuuDteType.factura           // 33
TuuDteType.facturaExenta     // 34
TuuDteType.facturaCompra     // 44
TuuDteType.boleta            // 48 — default histórico DTEx
TuuDteType.other             // 99
```

---

## 8. Manejo de errores

Jerarquía sealed; permite `switch` exhaustivo en Dart 3.

```dart
try {
  final result = await tuu.charge(request);
  // happy path
} on TuuUserCancelledException {
  // Cajero o cliente canceló en pantalla TUU. No reintentar
  // automáticamente — el usuario tomó una decisión.
} on TuuNotInstalledException {
  // App TUU no instalada o package no visible (Android 11+).
  // Mostrar UI alternativa o instrucciones de instalación.
} on TuuRejectedException catch (e) {
  // Adquirente rechazó o request inválida.
  // e.errorCode / e.errorCodeOnApp / e.errorMessageOnApp para diagnóstico.
  await analytics.log('tuu_rejected', {
    'errorCode': e.errorCode,
    'errorCodeOnApp': e.errorCodeOnApp,
  });
} on TuuInternalException catch (e) {
  // Error de configuración / red / SDK del terminal.
  // No reintentar — requiere intervención humana (revisar terminal,
  // red, llaves).
  showSupportAlert(e.message);
} on TuuException catch (e) {
  // Catch-all: TuuUnknownException, errores nativos no contemplados.
  // Loggear e.rawJson para enviarlo a soporte TUU.
  await crashlytics.recordError(e, null, fatal: false, information: [
    DiagnosticsProperty('rawJson', e.rawJson),
  ]);
}
```

### Política de reintentos

| Excepción | ¿Reintentar? |
|-----------|--------------|
| `TuuUserCancelledException` | **No.** El usuario decidió cancelar. |
| `TuuNotInstalledException` | **No.** Cambiar de medio de pago. |
| `TuuRejectedException` | **Posiblemente sí** — pedir otra tarjeta. |
| `TuuInternalException` | **No automático.** Diagnosticar terminal. |
| `TuuUnknownException` | **No automático.** Reportar a soporte. |

---

## 9. Tabla de códigos `errorCode`

Tabla oficial TUU (campo `errorCode` del JSON de respuesta). El plugin
clasifica automáticamente según esta tabla:

| Código | Mensaje (TUU) | Mapeo en el plugin |
|--------|---------------|---------------------|
| `1` | "La app de Pago no soporta propina..." | `TuuRejectedException` |
| `2` | "...no soporta vuelto..." | `TuuRejectedException` |
| `3` | "El método de pago no está definido..." | `TuuRejectedException` |
| `4` | "...no admite cuotas..." | `TuuRejectedException` |
| `5` | "...no admite vuelto en este tipo de transacción." | `TuuRejectedException` |
| `6` | "El monto no fue especificado." | `TuuRejectedException` |
| `7` | "El monto excede el máximo permitido." | `TuuRejectedException` |
| `8` | "No todos los atributos requeridos están presentes." | `TuuRejectedException` |
| `9` | **"Error en proceso de pago."** | `TuuRejectedException` |
| **`10`** | **"La transacción fue cancelada."** | **`TuuUserCancelledException`** |
| **`11`** | "El Terminal no está correctamente configurado." | **`TuuInternalException`** |
| **`12`** | "...llaves no inyectadas..." | **`TuuInternalException`** |
| `13` | "...monto de más de 12 dígitos." | `TuuRejectedException` |
| **`14`** | "El dispositivo no está conectado a internet." | **`TuuInternalException`** |
| **`15`** | "No se pudo obtener configuración..." | **`TuuInternalException`** |
| **`16`** | "El rubro está en espera de asignación..." | **`TuuInternalException`** |
| **`17`** | "El rubro tuvo un error durante la asignación." | **`TuuInternalException`** |
| `18` | "El tipo de DTE no está definido..." | `TuuRejectedException` |
| `19` | "El RUT no coincide con el utilizado." | `TuuRejectedException` |
| **`20`** | "El SDK de Pagos no se encuentra instalado." | **`TuuInternalException`** |
| **`21`** | "La aplicación de Pago necesita ser actualizada." | **`TuuInternalException`** |
| `I-01..I-04` | Errores de validación de `customFields` | `TuuRejectedException` |

### Códigos `errorCodeOnApp`

`errorCodeOnApp` es un String adicional. Si está presente, refina el
diagnóstico:

- Formato moderno (recomendado): **`ICE-XX`**.
- Formato legacy DTEx: **`HP-XXX`** (HTTP-like).

Códigos `ICE-XX` que el plugin clasifica como **internos**:

```
ICE-12  ICE-20  ICE-30  ICE-31  ICE-32  ICE-33  ICE-34
ICE-35  ICE-37  ICE-43  ICE-44  ICE-45  ICE-46  ICE-47
ICE-50  ICE-60  ICE-61
```

Cualquier `errorCodeOnApp` con prefijo `HP-5` también se clasifica como
interno (compat legacy DTEx).

`ICE-10` se clasifica como cancelación de usuario (mismo significado
que `errorCode == 10`).

---

## 10. Modo mock para desarrollo

Permite desarrollar sin tener la app TUU instalada (útil para CI / unit
tests / desarrollo en emuladores sin TUU).

```dart
final tuu = TuuClient(
  config: const TuuConfig(
    mode: TuuMode.mock,
    sourceName: 'DTEx',
    mockBehavior: TuuMockBehavior(
      chargeOutcome: TuuMockOutcome.approved,
      responseDelayMs: 0,         // 0 para tests; 400ms para "feel" real
    ),
  ),
);
```

### Ejercitar cada rama de error

```dart
// Rechazo del adquirente
const behavior = TuuMockBehavior(
  chargeOutcome: TuuMockOutcome.declined,
  declineErrorCode: 9,
  declineMessage: 'Error en proceso de pago',
);

// Error interno: sin internet
const behavior = TuuMockBehavior(
  chargeOutcome: TuuMockOutcome.internalError,
  internalErrorCode: 14,
  internalErrorMessage: 'El dispositivo no está conectado a internet.',
  internalErrorCodeOnApp: 'ICE-14',
);

// Cancelación
const behavior = TuuMockBehavior(
  chargeOutcome: TuuMockOutcome.userCancelled,
);
```

El simulador devuelve un JSON con la misma forma que TUU real — el
camino de parseo y mapeo de errores es idéntico al de producción.

---

## 11. Migración desde la integración legacy de DTEx

Plan en fases para reemplazar `lib/src/native/haulmer_native.dart` +
handler `CHANNEL_HAULMER` en `MainActivity.java`.

### Fase 1 — Agregar dependencia (sin tocar el código legacy)

```yaml
# pubspec.yaml de DTEx
dependencies:
  tuu_app2app:
    path: ../tuu_app2app
```

### Fase 2 — Crear wrapper de servicio

`lib/common/services/tuu_pay_service.dart` (espejo de `KushkiPayService`):

```dart
class TuuPayService {
  final TuuClient _client;

  TuuPayService(this._client);

  Future<bool> isAvailable() => _client.isInstalled();

  Future<TuuChargeResponse> charge({
    required int amount,
    int? tipAmount,
  }) {
    return _client.charge(TuuChargeRequest(
      amount: amount,
      tip: tipAmount == null || tipAmount <= 0
          ? TuuTipPolicy.disabled
          : TuuTipPolicy.fixed(tipAmount),
    ));
  }
}
```

Inyectar en `MultiProvider` de `main.dart`.

### Fase 3 — Migrar `step2_page.dart`

Reemplazar el bloque actual (líneas ~168):

```dart
// ANTES (legacy):
haulmerRequestPayment = await HaulmerNative().requestPayment(
  global.company.tid!,
  venta.montoTotal,
  venta.propina,
);
if (haulmerRequestPayment['transactionStatus'] ?? false) {
  // ...
}

// DESPUÉS (plugin):
try {
  final result = await context.read<TuuPayService>().charge(
    amount: venta.montoTotal.round(),
    tipAmount: venta.propina > 0 ? venta.propina.round() : null,
  );

  paymentResponseStatus = await global.onTapEfectivo(
    context,
    ventaEnProceso: venta,
    skipPrint: optImpresionClienteCard,
    pagoConTarjeta: true,
    pagoConTarjetaServicio: 'TUU',  // antes 'Haulmer'
    pagoConTarjetaAutorizacion: result.authCode,
    pagoConTarjetaTipo: result.transactionMethod,
    pagoConTarjetaDigitos: result.last4,
    pagoConTarjetaSecuencia: result.sequenceNumber,
  );
} on TuuUserCancelledException {
  checkout.markCardAttempted();
} on TuuException catch (e) {
  checkout.markCardAttempted();
  NotificationService.showSnackbarError(
    context,
    AppLocalizations.of(context).errorProcessingCardPayment(e.message),
  );
}
```

### Fase 4 — Eliminar código legacy

1. Borrar `lib/src/native/haulmer_native.dart` (88 líneas).
2. Borrar en `android/app/.../MainActivity.java`:
   - Constantes `INTENT_HAULMER_RESPONSE_ID`, `CHANNEL_HAULMER`,
     `m_haulmerResult`.
   - El bloque `new MethodChannel(..., CHANNEL_HAULMER)...` (líneas 319-371).
   - El bloque `onActivityResult` para `INTENT_HAULMER_RESPONSE_ID`
     (líneas 2097-2126).
3. Borrar el `<queries>` para `com.haulmer.paymentapp*` del manifest de
   DTEx (se mergea desde el plugin).

### Fase 5 — Rename Haulmer → TUU en el resto del código

- `optHaulmer` → `optTuu` en backend `/equipment/v2/` (coordinar con
  backend).
- `pagoConTarjetaServicio: 'Haulmer'` → `'TUU'` en ticket impreso y
  persistencia DB.

---

## 12. Limitaciones conocidas

| Funcionalidad | Kushki ONE | TUU (este plugin) |
|---------------|------------|---------------------|
| Transporte | HTTP local | Android Intent |
| Reintentos automáticos | Sí | No |
| Idempotencia (UUID cliente) | Sí | No (TUU genera `sequenceNumber`) |
| Reversa programática | Sí | **No** — sólo desde la app TUU |
| Pre-autorización | Sí | **No** |
| Búsqueda de transacciones | Sí | **No** |
| `abort()` programático | Sí | **No** |
| Auto-return foreground | Sí | Innecesario (Intent vuelve solo) |

Si la app consumidora necesita reversa o reimpresión, debe abrir la app
TUU manualmente y operar desde ahí.

---

## 13. Troubleshooting

### "App TUU no instalada" aunque sí está

Verificar que el `<queries>` se haya mergeado al manifest final:

```bash
./gradlew :app:processDebugManifest --info | grep -A2 paymentapp
```

Debería aparecer el bloque `<queries>` del plugin. Si no aparece, hacer
`flutter clean && flutter pub get`.

### `TuuUnknownException` en producción

Capturar `e.rawJson` y enviarlo a soporte TUU. Puede ser una versión de
la app TUU que devuelve campos nuevos no contemplados en este plugin.

### Otra carga en curso (`MFN-05`)

Aparece si la UI permite que el usuario dispare dos cobros casi
simultáneos (doble tap). Bloquear el botón al iniciar el primer cobro.

### Logs

En modo `debug` / `mock`, todos los requests y respuestas van a
`dart:developer.log` con prefijo `[TUU:DEBUG]` / `[TUU:MOCK]`. Filtrar
en DevTools por el name `tuu_app2app`.

### Probar contra el package dev sin recompilar

```dart
const config = TuuConfig(
  mode: TuuMode.production,                    // logs apagados
  packageName: tuuPackageDevelopment,          // pero apuntando a .dev
);
```

---

> **Soporte TUU (técnico):** https://haulmer.com / soporte de Haulmer Pagos
> **Doc oficial inter-app:** https://developers.tuu.cl/docs/integraci%C3%B3n-de-aplicaciones-de-pago-inter-app-new
> **Mantenido por:** MUFIN SpA — marco@mufin.cl
