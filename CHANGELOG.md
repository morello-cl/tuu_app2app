# Changelog

## 0.3.0

### Agregado

- `pendingCharge()` y `clearPending()`: recuperan un cobro que quedó sin
  resolver porque Android mató el proceso mientras TUU estaba en pantalla.

  El plugin persiste el cobro antes de lanzar el Intent y la respuesta apenas
  llega, desde el lado nativo. Antes, `onActivityResult` descartaba el
  resultado cuando `pendingResult` era `null` —vive en memoria— y un cobro
  aprobado se perdía sin que la app se enterara.

  `TuuPendingCharge` distingue dos casos: con respuesta, el cobro ocurrió y hay
  que registrarlo; sin respuesta, es incierto y **pudo haberse cobrado igual**.
  Lo segundo no se puede cerrar por software: TUU no expone forma de consultar
  una transacción.

### Cambiado

- **El paquete pasó de `tuu_app_to_app` a `tuu_app2app`**, para seguir el mismo
  esquema que `recibopagos_app2app`. Cambia el import, el nombre del canal
  (`cl.mufin.tuu_app2app`) y la clase nativa (`TuuApp2appPlugin`).

## 0.2.0 — 2026-05-13

### API tipada por nombre TUU (breaking)

Refactor para alinear la API 1:1 con la documentación oficial de TUU
(developers.tuu.cl) y eliminar `Object?` / `dynamic` de los modelos
públicos.

- **Nuevo: `TuuTipPolicy`** (sealed-ish): `disabled` (-1), `askUser` (0),
  `fixed(amount)` (>0). Reemplaza el campo `tip: int?` del request.
- **Nuevo: `TuuCashbackPolicy`** con los mismos tres casos.
- **Nuevo: `TuuExtraData`** modela el bloque `extraData` con campos
  documentados: `taxIdnValidation`, `exemptAmount`, `netAmount`,
  `sourceName`, `sourceVersion`, `customFields`.
- **Nuevo: `TuuCustomField`** modela cada entrada de `customFields`
  (`name`, `value`, `print`).
- **Nuevo: `TuuDteType`** con constantes para los valores documentados
  (`factura = 33`, `boleta = 48`, etc.).
- **`TuuChargeResponse`** agrega `transactionTip` y `transactionCashback`
  (per doc oficial). El campo `raw` (era `Map<String, Object?>`) pasa a
  `rawJson: String?` para mantener la API libre de `Object?`.
- **`TuuException.raw`** se renombró a `rawJson: String?` (mismo motivo).
- **`TuuException`** agrega `TuuInternalException.errorCode` /
  `errorCodeOnApp`.

### Correcciones contra la doc oficial

- **`TuuPaymentMethod` corregido:** `askUser = 0`, `credit = 1`,
  `debit = 2`. Versiones previas usaban un orden inverso heredado del
  wrapper legacy de DTEx.
- **`tip == 0`** ya no significa "no propina"; ahora significa "preguntar
  al usuario" (consistente con la doc TUU). "No propina" es
  `TuuTipPolicy.disabled`.
- **Mapeo de errores reescrito** según tablas oficiales:
  - `errorCode == 10` o `errorCodeOnApp == 'ICE-10'` → `TuuUserCancelledException`.
  - `errorCode` ∈ {11,12,14,15,16,17,20,21} o `errorCodeOnApp` ∈
    {`ICE-12`, `ICE-20`, `ICE-30..ICE-35`, `ICE-37`, `ICE-43..ICE-47`,
    `ICE-50`, `ICE-60`, `ICE-61`} → `TuuInternalException`.
  - Prefijo legacy `HP-5xx` sigue mapeando a `TuuInternalException`.
  - Resto → `TuuRejectedException`.

### Android nativo

- El plugin ahora lee primero el extra `transactionResult` (clave oficial)
  y cae a `resultJson` (clave legacy DTEx) para compatibilidad con
  versiones antiguas de la app TUU.

### Defaults del mock

- `declineErrorCode = 9` ("Error en proceso de pago"), sin
  `errorCodeOnApp` (default realista de rechazo del adquirente).
- `internalErrorCode = 12` + `errorCodeOnApp = 'ICE-12'` (default
  realista de error interno: llaves no inyectadas).

### Documentación

- Nuevo `docs/GUIA_TECNICA.md` con guía completa de integración: setup,
  uso, modos, manejo de errores, tabla de códigos oficiales, migración
  desde DTEx legacy.
- DartDoc ampliado en todos los archivos públicos.

---

## 0.1.0 — 2026-05-13

### Plugin inicial
- Cliente Flutter para integración TUU vía Android Intent.
- API: `TuuClient.isInstalled()`, `isInstalledDev()`, `charge()`.
- Modos: `production`, `debug`, `mock`.
- Modelos: `TuuChargeRequest`, `TuuChargeResponse`, `TuuPaymentMethod`.
- Jerarquía `sealed TuuException`.
- `TuuMockSimulator` opt-in vía `TuuMode.mock`.
- `<queries>` para `com.haulmer.paymentapp(.dev)` en el manifest del plugin.
