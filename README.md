# tuu_app2app

Plugin Flutter para Android que cobra con la app **TUU** (ex-Haulmer) instalada
en el mismo equipo. Tu app le pasa el monto por un Intent, el cliente paga con
tarjeta en la pantalla de TUU y el resultado vuelve como un objeto tipado. No
hay red de por medio para cobrar.

Y recupera el cobro cuando el terminal mata tu app a mitad del pago, que es la
razón por la que este plugin existe.

Implementa la [integración entre aplicaciones de TUU](https://developers.tuu.cl).

<sub>Paquete mantenido por Mufin. No es un producto oficial de TUU; el nombre y
el logo pertenecen a TUU.</sub>

## Antes de empezar

- La app `com.haulmer.paymentapp` instalada en el equipo (`.dev` en desarrollo).
- Nada que agregar al `AndroidManifest.xml` de tu app: el plugin ya declara la
  visibilidad del package que exige Android 11+.
- Para consultar cobros perdidos, la **API key del comercio**, que se pide a TUU
  y viaja en el header `X-API-Key`.

## Instalación

```yaml
dependencies:
  tuu_app2app:
    git:
      url: https://github.com/morello-cl/tuu_app2app.git
      ref: v0.4.0
```

## Cobrar

```dart
import 'package:tuu_app2app/tuu_app2app.dart';

final tuu = TuuClient(
  config: const TuuConfig(sourceName: 'DTEx', sourceVersion: '6.27.0'),
);

if (!await tuu.isInstalled()) {
  // Ofrece otro medio de pago.
}

try {
  final pago = await tuu.charge(const TuuChargeRequest(amount: 20000));
  // Recién aquí emites la boleta.
} on TuuRejectedException {
  // Pide otra tarjeta.
} on TuuUserCancelledException {
  // El cajero canceló.
}
```

> [!WARNING]
> Llama a `resolverPendiente()` **al arrancar la app**, antes de ofrecer un
> cobro nuevo. Si no, un cobro que se perdió vuelve a cobrarse.

## Cuando el terminal mata tu app

Es lo más común en un POS: Android necesita memoria para la app de pagos y mata
la tuya, que quedó en segundo plano. El cliente paga, el cobro se aprueba y tu
app nunca se entera.

El plugin guarda el cobro en disco antes de lanzar el Intent, y la respuesta
apenas llega, desde el lado nativo. Al volver, pregunta:

```dart
final r = await tuu.resolverPendiente(serial: serieDelEquipo, apiKey: apiKey);

if (r != null) {
  if (r.cobrado) {
    registrarVenta(r.pendiente.response);   // y recién después:
    await tuu.clearPending();
  } else if (r.sePuedeReintentar) {
    await tuu.clearPending();               // cobrar de nuevo es seguro
  } else if (r.necesitaRevisionManual) {
    mostrarConciliacion(r);                 // no se pudo averiguar
  }
}
```

`resolverPendiente` no borra nada: lo cierras tú después de registrar la venta.
Si lo borrara y el registro fallara, el cobro se perdería igual.

### Las tres salidas

| Resultado | Qué pasó | Qué hacer |
|---|---|---|
| `cobrado` | La respuesta quedó guardada, o TUU confirmó `completed` | Registrar la venta y `clearPending()` |
| `sePuedeReintentar` | TUU respondió que no existe o no se completó | Cobrar de nuevo sin riesgo |
| `necesitaRevisionManual` | No se pudo averiguar | **Preguntar al operador antes de cobrar** |

**Sólo una respuesta explícita de TUU habilita reintentar.** Sin red, con el
servidor caído o con un cobro sin referencia, el resultado es revisión manual y
nunca «no cobrada»: tratar la falta de información como ausencia de cobro es
exactamente lo que duplica un cobro.

### Cómo se consulta

El Intent es síncrono y no reentrega nada, así que la consulta va por la API
REST de Haulmer, aparte:

```
GET /Transaction/ByExternalReferenceId/{externalReferenceId}/{serial}
X-API-Key: <clave del comercio>
```

**Busca por `externalReferenceId`, no por `sequenceNumber`.** Esa referencia la
genera `charge()` y la manda en el `extraData` del Intent, así que un cobro
lanzado por una versión anterior del plugin —o por una app que no la mande— no
se puede consultar.

Un cobro cuenta como cobrado sólo si `status == 'completed'`. Los demás valores
no están documentados.

## Probar sin terminal

```dart
final tuu = TuuClient(
  config: const TuuConfig(
    mode: TuuMode.mock,
    sourceName: 'DTEx',
    sourceVersion: '1.0.0',
  ),
);
```

| Modo | Qué hace |
|---|---|
| `production` | Cobra con la app real contra `integrations.payment.haulmer.com`. |
| `debug` | Cobra con la app `.dev` y registra lo enviado y lo recibido. |
| `mock` | No abre nada. Responde según el `TuuMockBehavior` configurado. |

<details>
<summary>Correspondencia con el JSON del Intent</summary>

Lo que viaja en `Intent.EXTRA_TEXT`:

| Plugin | Campo | Notas |
|---|---|---|
| `amount` | `amount` | pesos enteros |
| `tip` | `tip` | `-1` desactivado, `0` preguntar, `>0` monto fijo |
| `cashback` | `cashback` | igual que `tip` |
| `method` | `method` | `0` preguntar, `1` crédito, `2` débito |
| `installmentsQuantity` | `installmentsQuantity` | |
| `printVoucherOnApp` | `printVoucherOnApp` | |
| `dteType` | `dteType` | `48` boleta por defecto |
| — | `extraData.externalReferenceId` | lo genera el plugin |
| `config.sourceName` | `extraData.sourceName` | |

Respuesta: `transactionStatus`, `sequenceNumber`, `transactionMethod`,
`transactionInstallments`, `last4`, `authCode`, `errorCode`, `errorMessage`,
`extraData`. El `extraData` se acepta como objeto JSON o como String escapado,
que es el formato de las versiones antiguas de la app TUU.

Claves del resultado leídas por compatibilidad: `transactionResult` (actual) y
`resultJson` (legacy).

</details>

## Desarrollo

```sh
flutter test
```

Pendiente: capturar respuestas reales de la consulta en desarrollo, para fijar
los valores de `status` más allá de `completed`, y medir cuánto tarda una
transacción en aparecer después de cobrada.
