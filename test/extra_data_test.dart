import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tuu_app2app/tuu_app2app.dart';

void main() {
  group('TuuExtraData.toJson', () {
    test('omite campos null', () {
      const extra = TuuExtraData(sourceName: 'DTEx');

      final json = extra.toJson();

      expect(json, {'sourceName': 'DTEx'});
    });

    test('serializa todos los campos cuando están presentes', () {
      const extra = TuuExtraData(
        taxIdnValidation: '76123456-7',
        exemptAmount: 0,
        netAmount: 12000,
        sourceName: 'DTEx',
        sourceVersion: '1.16.0',
        customFields: [
          TuuCustomField(name: 'orden', value: 'O-1', print: true),
        ],
      );

      final json = extra.toJson();

      expect(json['taxIdnValidation'], '76123456-7');
      expect(json['exemptAmount'], 0);
      expect(json['netAmount'], 12000);
      expect(json['sourceName'], 'DTEx');
      expect(json['sourceVersion'], '1.16.0');
      expect((json['customFields']! as List).length, 1);
    });
  });

  group('TuuExtraData.mergeDefaults', () {
    test('rellena sourceName / sourceVersion sólo si están null', () {
      const original = TuuExtraData(sourceName: 'X');

      final merged = original.mergeDefaults(
        sourceName: 'DEFAULT',
        sourceVersion: '1.0.0',
      );

      expect(merged.sourceName, 'X', reason: 'no se pisa si existe');
      expect(merged.sourceVersion, '1.0.0');
    });

    test('preserva customFields y demás campos', () {
      const original = TuuExtraData(
        netAmount: 5000,
        customFields: [
          TuuCustomField(name: 'a', value: 'b', print: true),
        ],
      );

      final merged = original.mergeDefaults(
        sourceName: 'D',
        sourceVersion: 'V',
      );

      expect(merged.netAmount, 5000);
      expect(merged.customFields.length, 1);
    });
  });

  group('TuuExtraData.tryParseResponseValue', () {
    test('null → null', () {
      expect(TuuExtraData.tryParseResponseValue(null), isNull);
    });

    test('String JSON escapado → TuuExtraData', () {
      final encoded = jsonEncode({
        'sourceName': 'DTEx',
        'sourceVersion': '1.16.0',
      });

      final parsed = TuuExtraData.tryParseResponseValue(encoded);

      expect(parsed, isNotNull);
      expect(parsed!.sourceName, 'DTEx');
    });

    test('String no JSON → null', () {
      expect(TuuExtraData.tryParseResponseValue('not json'), isNull);
    });

    test('Map directo → TuuExtraData', () {
      final parsed = TuuExtraData.tryParseResponseValue(<String, Object?>{
        'sourceName': 'DTEx',
        'customFields': [
          {'name': 'a', 'value': 'b', 'print': true},
        ],
      });

      expect(parsed, isNotNull);
      expect(parsed!.customFields.length, 1);
    });
  });

  group('TuuCustomField', () {
    test('toJson / fromJson roundtrip', () {
      const original = TuuCustomField(
        name: 'orden',
        value: 'O-123',
        print: true,
      );

      final json = original.toJson();
      final parsed = TuuCustomField.fromJson(json);

      expect(parsed.name, original.name);
      expect(parsed.value, original.value);
      expect(parsed.print, original.print);
    });
  });
}
