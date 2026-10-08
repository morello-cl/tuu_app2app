# tuu_app2app

Cliente Flutter para integración **app-to-app** con la app de pagos TUU (ex-Haulmer).

La comunicación se realiza vía **Android Intent + `startActivityForResult`** contra
los packages `com.haulmer.paymentapp` (producción) y `com.haulmer.paymentapp.dev`
(desarrollo). No usa HTTP.

Pensado para apps Flutter de MUFIN (DTEx, ParkingCash) que necesiten cobrar
con tarjeta a través de la app TUU instalada en el mismo dispositivo Android
(Kozen, Sunmi y similares).

## Instalación

```yaml
dependencies:
  tuu_app2app:
    path: ../tuu_app2app
```

## Configuración Android

El plugin declara automáticamente en su `AndroidManifest.xml` el bloque
`<queries>` para que `PackageManager.getLaunchIntentForPackage(...)` funcione
en Android 11+:

```xml
<queries>
    <package android:name="com.haulmer.paymentapp" />
    <package android:name="com.haulmer.paymentapp.dev" />
</queries>
```

Este bloque se mergea al manifest de la app consumidora en build time — no
requiere cambios manuales.

Se recomienda que la `MainActivity` de la app consumidora use
`android:launchMode="singleTask"` para que al volver desde TUU vía
`onActivityResult` la activity recupere su estado intacto.

## Uso

### Detección

```dart
final tuu = TuuClient(config: const TuuConfig());
final available = await tuu.isInstalled();         // true si com.haulmer.paymentapp existe
final availableDev = await tuu.isInstalledDev();   // true si com.haulmer.paymentapp.dev existe
```

### Cobro

```dart
final tuu = TuuClient(
  config: const TuuConfig(
    mode: TuuMode.production,
    sourceName: 'DTEx',
    sourceVersion: '1.16.0',
  ),
);

try {
  final result = await tuu.charge(
    const TuuChargeRequest(
      amount: 12000,
      tip: 0,
      method: TuuPaymentMethod.any,
    ),
  );

  if (result.approved) {
    print('Autorizado: ${result.authCode} — ${result.last4}');
    // Persistir: sequenceNumber, authCode, transactionMethod, last4
  } else {
    print('Rechazado: ${result.errorMessage}');
  }
} on TuuUserCancelledException {
  // Cancelado por el cajero o cliente
} on TuuNotInstalledException {
  // App TUU no está en este device
} on TuuException catch (e) {
  // Error genérico — e.code y e.message disponibles
}
```

### Modo mock (desarrollo sin app TUU)

```dart
final tuu = TuuClient(
  config: const TuuConfig(
    mode: TuuMode.mock,
    sourceName: 'DTEx',
  ),
  mockBehavior: const TuuMockBehavior(
    chargeOutcome: TuuMockOutcome.approved,
  ),
);

final result = await tuu.charge(
  const TuuChargeRequest(amount: 12000),
);
```

## Modos de operación

| Modo | Comportamiento |
|------|----------------|
| `production` | Solo Intent real, sin logs. |
| `debug` | Intent real + logs `[TUU:DEBUG]` detallados de request/response. |
| `mock` | No dispara Intent. Devuelve respuesta simulada según `TuuMockBehavior`. |

## Limitaciones (vs Kushki ONE)

| Característica | Kushki ONE | TUU |
|----------------|------------|-----|
| Transporte | HTTP local | Android Intent |
| Reintentos automáticos | Sí | No |
| Idempotencia (UUID cliente) | Sí | No (TUU genera `sequenceNumber`) |
| Reversa programática | Sí | No (sólo cancelación in-app) |
| Pre-autorización | Sí | No |
| Búsqueda de transacciones | Sí | No |
| `abort()` programático | Sí | No |

Cualquier reversa o reimpresión debe hacerse desde la app TUU.

## Documentación detallada

- **Guía técnica completa:** [`docs/GUIA_TECNICA.md`](docs/GUIA_TECNICA.md) — arquitectura, modelos tipados, tabla de `errorCode` oficiales, migración desde DTEx legacy, troubleshooting.
- **Doc oficial TUU:** https://developers.tuu.cl/docs/integraci%C3%B3n-de-aplicaciones-de-pago-inter-app-new

## Contacto

- MUFIN SpA — marco@mufin.cl
- Soporte TUU: https://haulmer.com

## Recuperar un cobro cuando el POS mata la app

En un terminal con poca memoria, Android mata la app que pasa a segundo plano
para dársela a la app de pagos — justo mientras TUU está cobrando. El resultado
del Intent **sí** se reentrega cuando la actividad se recrea, pero para entonces
el estado de Dart ya no existe, así que un cobro aprobado se perdía en silencio.

El plugin lo guarda en disco desde el lado nativo: anota el cobro antes de
lanzar el Intent y la respuesta apenas llega, antes de pasarla a Dart.

**Hay que preguntarlo al arrancar, antes de ofrecer cobrar de nuevo:**

```dart
final pendiente = await client.pendingCharge();
if (pendiente != null) {
  if (pendiente.tieneRespuesta) {
    // TUU respondió y nadie recibió la respuesta: el cobro ocurrió.
    registrarVenta(pendiente.response!);
    await client.clearPending();
  } else if (pendiente.esIncierto) {
    // Se lanzó y no se supo más: PUEDE haberse cobrado.
    // TUU no expone forma de consultar una transacción, así que esto no se
    // resuelve desde acá — hay que preguntarle al operador o cruzar contra
    // el reporte de TUU antes de volver a cobrar.
    mostrarPantallaDeConciliacion(pendiente);
  }
}
```

`clearPending()` hay que llamarlo después de registrar; si no, el mismo cobro
reaparece en cada arranque.

### Cerrar el caso incierto: preguntarle a TUU

Para el cobro que se lanzó y del que no se supo más, el plugin consulta la API
REST de Haulmer. **Busca por `externalReferenceId`, no por `sequenceNumber`**,
y esa referencia la genera `charge()` sola y la manda en el `extraData` del
Intent: un cobro lanzado sin ella es irrecuperable.

```dart
final r = await client.resolverPendiente(serial: serieDelEquipo, apiKey: apiKey);
if (r != null) {
  if (r.cobrado) {
    registrarVenta(r.pendiente.response);     // y recién después:
    await client.clearPending();
  } else if (r.sePuedeReintentar) {
    // TUU respondió que no existe o no se completó: cobrar de nuevo es seguro.
    await client.clearPending();
  } else if (r.necesitaRevisionManual) {
    // No se pudo averiguar. NO es lo mismo que no cobrada.
    mostrarPantallaDeConciliacion(r);
  }
}
```

La `apiKey` es por comercio y va en el header `X-API-Key`.

**La regla que evita el doble cobro:** sólo una respuesta explícita de TUU
habilita reintentar. Sin red, con TUU caído o con un cobro sin referencia, el
resultado es `necesitaRevisionManual` — nunca «no cobrada»—, porque tratar la
falta de información como ausencia de cobro es exactamente lo que duplica.

Lo que **no** existe es consulta por `sequenceNumber`: el Intent es síncrono y
la API sólo indexa por la referencia que uno mismo mandó.

