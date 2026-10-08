/// Constantes para el campo `dteType` que envía TUU al SII como tipo de
/// documento tributario electrónico.
///
/// Sólo los valores listados en la documentación oficial de TUU son
/// aceptados por la app. Pasar un valor fuera de esta lista provoca
/// `errorCode: 18` ("El tipo de documento electrónico no esta definido
/// en las configuraciones").
///
/// ## Ejemplo
///
/// ```dart
/// const config = TuuConfig(dteType: TuuDteType.boleta);
/// // o por request individual:
/// const request = TuuChargeRequest(amount: 1000, dteType: TuuDteType.factura);
/// ```
class TuuDteType {
  /// Constructor privado — esta clase sólo expone constantes estáticas.
  TuuDteType._();

  /// `0` — sin DTE asociado (uso interno de TUU).
  static const int none = 0;

  /// `33` — **Factura Electrónica**.
  ///
  /// Documento tributario afecto a IVA usado entre contribuyentes.
  static const int factura = 33;

  /// `34` — **Factura Exenta Electrónica**.
  ///
  /// Factura para operaciones exentas o no afectas a IVA.
  static const int facturaExenta = 34;

  /// `44` — **Factura de Compra Electrónica**.
  ///
  /// Documento emitido por el comprador cuando el vendedor no puede emitir
  /// factura (cambio de sujeto del IVA).
  static const int facturaCompra = 44;

  /// `48` — **Boleta Electrónica** (default usado por DTEx históricamente).
  ///
  /// Documento estándar para operaciones con consumidor final.
  static const int boleta = 48;

  /// `99` — Otro / personalizado (validar uso con TUU antes).
  static const int other = 99;

  /// Set inmutable de valores aceptados por TUU. Útil para validación
  /// en formularios de configuración.
  static const Set<int> validValues = <int>{
    none,
    factura,
    facturaExenta,
    facturaCompra,
    boleta,
    other,
  };

  /// `true` si [value] está en [validValues].
  static bool isValid(int value) => validValues.contains(value);
}
