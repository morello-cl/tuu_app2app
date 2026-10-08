import 'dart:convert';

import 'tuu_custom_field.dart';

/// Bloque `extraData` del JSON de TUU.
///
/// Modela exactamente los campos opcionales documentados por TUU en su
/// integración inter-app. **Todos** son opcionales — un `TuuExtraData()`
/// sin parámetros es válido (aunque normalmente se envía al menos
/// `sourceName` / `sourceVersion`).
///
/// El plugin auto-rellena [sourceName] y [sourceVersion] desde [TuuConfig]
/// si la app consumidora no los fija aquí.
///
/// ## Campos
///
///  - [taxIdnValidation]: RUT del comercio (formato `11111111-1`). Si
///    se envía, TUU lo compara con el RUT configurado en el terminal —
///    discrepancia produce `errorCode: 19`.
///  - [exemptAmount]: porción exenta de IVA reportada al SII (≥ 0,
///    máx 12 dígitos).
///  - [netAmount]: porción afecta a IVA reportada al SII (≥ 0,
///    máx 12 dígitos). Debe cumplir `netAmount + exemptAmount == amount`.
///  - [sourceName]: nombre alfanumérico de la app llamante (max 50).
///  - [sourceVersion]: versión alfanumérica de la app (max 20).
///  - [customFields]: lista de campos para imprimir en el voucher.
///
/// ## Ejemplo
///
/// ```dart
/// const extra = TuuExtraData(
///   taxIdnValidation: '76123456-7',
///   netAmount: 8400,
///   exemptAmount: 0,
///   customFields: [
///     TuuCustomField(name: 'orden', value: 'ORD-001', print: true),
///   ],
/// );
/// ```
class TuuExtraData {
  /// RUT del comercio (formato `11111111-1`), o `null` para no validar.
  final String? taxIdnValidation;

  /// Porción exenta de IVA, en pesos chilenos.
  final int? exemptAmount;

  /// Porción afecta a IVA, en pesos chilenos.
  final int? netAmount;

  /// Nombre de la app integradora. Si es `null`, el cliente lo completa
  /// desde [TuuConfig.sourceName].
  final String? sourceName;

  /// Versión de la app integradora. Si es `null`, el cliente lo completa
  /// desde [TuuConfig.sourceVersion].
  final String? sourceVersion;

  /// Campos personalizados para imprimir en el voucher.
  final List<TuuCustomField> customFields;

  /// Identificador que genera la app para poder preguntarle después a TUU qué
  /// pasó con este cobro.
  ///
  /// Es **la única llave de consulta**: el endpoint
  /// `/Transaction/ByExternalReferenceId/{id}/{serial}` busca por esto y no por
  /// `sequenceNumber`. Un cobro lanzado sin este campo queda irrecuperable si
  /// la respuesta se pierde, así que [TuuClient.charge] genera uno cuando la
  /// app no lo pone.
  final String? externalReferenceId;

  /// Crea un `TuuExtraData` inmutable.
  const TuuExtraData({
    this.taxIdnValidation,
    this.exemptAmount,
    this.netAmount,
    this.sourceName,
    this.sourceVersion,
    this.externalReferenceId,
    this.customFields = const <TuuCustomField>[],
  });

  /// Devuelve una nueva copia mergeando defaults para [sourceName] y
  /// [sourceVersion] si aquí están `null`.
  ///
  /// Usado por [TuuChargeRequest.toJson] para inyectar el `sourceName` /
  /// `sourceVersion` del [TuuConfig] sin perder los valores que la app
  /// consumidora ya haya definido.
  TuuExtraData mergeDefaults({
    required String sourceName,
    required String sourceVersion,
    String? externalReferenceId,
  }) {
    return TuuExtraData(
      taxIdnValidation: taxIdnValidation,
      exemptAmount: exemptAmount,
      netAmount: netAmount,
      sourceName: this.sourceName ?? sourceName,
      sourceVersion: this.sourceVersion ?? sourceVersion,
      externalReferenceId: this.externalReferenceId ?? externalReferenceId,
      customFields: customFields,
    );
  }

  /// Serializa a un map JSON. Campos `null` se omiten para no enviar
  /// claves vacías al JSON final.
  Map<String, Object?> toJson() {
    final Map<String, Object?> result = <String, Object?>{};
    if (taxIdnValidation != null) {
      result['taxIdnValidation'] = taxIdnValidation;
    }
    if (exemptAmount != null) result['exemptAmount'] = exemptAmount;
    if (netAmount != null) result['netAmount'] = netAmount;
    if (sourceName != null) result['sourceName'] = sourceName;
    if (sourceVersion != null) result['sourceVersion'] = sourceVersion;
    if (externalReferenceId != null) {
      result['externalReferenceId'] = externalReferenceId;
    }
    if (customFields.isNotEmpty) {
      result['customFields'] =
          customFields.map((TuuCustomField c) => c.toJson()).toList();
    }
    return result;
  }

  /// Reconstruye un `TuuExtraData` desde un map JSON (campos faltantes
  /// quedan `null`).
  factory TuuExtraData.fromJson(Map<String, Object?> json) {
    final List<TuuCustomField> fields = <TuuCustomField>[];
    final Object? rawFields = json['customFields'];
    if (rawFields is List) {
      for (final Object? entry in rawFields) {
        if (entry is Map<String, Object?>) {
          fields.add(TuuCustomField.fromJson(entry));
        } else if (entry is Map) {
          fields.add(TuuCustomField.fromJson(entry.cast<String, Object?>()));
        }
      }
    }

    return TuuExtraData(
      taxIdnValidation: json['taxIdnValidation'] as String?,
      exemptAmount: (json['exemptAmount'] as num?)?.toInt(),
      netAmount: (json['netAmount'] as num?)?.toInt(),
      sourceName: json['sourceName'] as String?,
      sourceVersion: json['sourceVersion'] as String?,
      externalReferenceId: json['externalReferenceId'] as String?,
      customFields: fields,
    );
  }

  /// Parsea `extraData` tal como aparece en la **respuesta** de TUU.
  ///
  /// TUU echo del `extraData` del request puede llegar de dos formas
  /// según la versión de la app:
  ///  - Como **String** con JSON escapado (formato observado en DTEx
  ///    legacy: `"{\"sourceName\":\"DTEx\",...}"`).
  ///  - Como **objeto JSON** directamente (formato más reciente).
  ///
  /// Esta factory acepta ambos. Devuelve `null` si [value] es `null` o
  /// no se puede parsear.
  static TuuExtraData? tryParseResponseValue(Object? value) {
    if (value == null) return null;

    if (value is String) {
      if (value.isEmpty) return null;
      try {
        final Object? decoded = jsonDecode(value);
        if (decoded is Map<String, Object?>) {
          return TuuExtraData.fromJson(decoded);
        }
        if (decoded is Map) {
          return TuuExtraData.fromJson(decoded.cast<String, Object?>());
        }
      } on FormatException {
        return null;
      }
      return null;
    }

    if (value is Map<String, Object?>) {
      return TuuExtraData.fromJson(value);
    }
    if (value is Map) {
      return TuuExtraData.fromJson(value.cast<String, Object?>());
    }

    return null;
  }

  @override
  String toString() => 'TuuExtraData(sourceName: $sourceName, '
      'sourceVersion: $sourceVersion, customFields: ${customFields.length})';
}
