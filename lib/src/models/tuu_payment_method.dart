/// Método de pago a sugerir a la app TUU.
///
/// Se serializa al campo `method` del body JSON, según los valores
/// **oficiales documentados por TUU**:
///
///  - `0` → la app pregunta al usuario / cajero (default recomendado).
///  - `1` → crédito.
///  - `2` → débito.
///
/// La app TUU siempre permite al cajero o cliente cambiar el método en
/// pantalla; este valor es sólo una sugerencia para preseleccionar la
/// opción en su UI.
///
/// > **Importante:** este orden corrige un error del wrapper legacy de
/// > DTEx, que tenía `1 = débito, 2 = crédito`. El plugin sigue el orden
/// > oficial de TUU.
enum TuuPaymentMethod {
  /// La app TUU pregunta al usuario qué método usar. **Default recomendado.**
  ///
  /// Valor JSON: `0`.
  askUser(0),

  /// Sugerir tarjeta de **crédito**.
  ///
  /// Valor JSON: `1`. Habilita el campo `installmentsQuantity`.
  credit(1),

  /// Sugerir tarjeta de **débito**.
  ///
  /// Valor JSON: `2`. Habilita el campo `cashback`.
  debit(2);

  /// Valor entero que TUU espera en el JSON (`method`).
  final int value;

  /// Constructor del enum — asocia cada caso con su valor numérico oficial.
  const TuuPaymentMethod(this.value);

  /// Convierte un entero (típicamente leído del JSON de TUU) al enum
  /// correspondiente.
  ///
  /// Si [value] no coincide con ningún caso conocido (incluyendo `null`),
  /// devuelve [TuuPaymentMethod.askUser] para mantener un comportamiento
  /// permisivo ante respuestas inesperadas.
  static TuuPaymentMethod fromValue(int? value) {
    for (final TuuPaymentMethod method in TuuPaymentMethod.values) {
      if (method.value == value) return method;
    }
    return TuuPaymentMethod.askUser;
  }
}
