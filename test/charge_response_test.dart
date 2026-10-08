import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tuu_app2app/tuu_app2app.dart';

void main() {
  group('TuuChargeResponse.fromJson', () {
    test('mapea response aprobada per doc oficial', () {
      final json = <String, Object?>{
        'sequenceNumber': '000000017978',
        'transactionStatus': true,
        'transactionMethod': 'Tarjeta de Débito',
        'transactionInstallments': 0,
        'last4': '****7664',
        'authCode': '029074',
        'transactionAmountInstallments': 0,
        'transactionDeferredPeriod': 0,
        'maxInstallmentsChargeFree': 12,
        'printerVoucherCommerce': false,
        'transactionTip': 1500,
        'transactionCashback': 0,
      };

      final r = TuuChargeResponse.fromJson(json);

      expect(r.approved, isTrue);
      expect(r.sequenceNumber, '000000017978');
      expect(r.transactionMethod, 'Tarjeta de Débito');
      expect(r.last4, '****7664');
      expect(r.authCode, '029074');
      expect(r.maxInstallmentsChargeFree, 12);
      expect(r.printerVoucherCommerce, false);
      expect(r.transactionTip, 1500);
      expect(r.transactionCashback, 0);
    });

    test('campos opcionales faltantes → null o 0 sin lanzar', () {
      final r = TuuChargeResponse.fromJson({'transactionStatus': true});

      expect(r.approved, isTrue);
      expect(r.transactionInstallments, 0);
      expect(r.maxInstallmentsChargeFree, 0);
      expect(r.printerVoucherCommerce, false);
      expect(r.transactionTip, isNull);
      expect(r.transactionCashback, isNull);
      expect(r.extraData, isNull);
    });

    test('extraData como String escapada (DTEx legacy) → TuuExtraData', () {
      final json = <String, Object?>{
        'transactionStatus': true,
        'extraData': '{"sourceName":"DTEx","sourceVersion":"1.16.0"}',
      };

      final r = TuuChargeResponse.fromJson(json);

      expect(r.extraData, isNotNull);
      expect(r.extraData!.sourceName, 'DTEx');
      expect(r.extraData!.sourceVersion, '1.16.0');
    });

    test('extraData como objeto JSON directo → TuuExtraData', () {
      final json = <String, Object?>{
        'transactionStatus': true,
        'extraData': <String, Object?>{
          'sourceName': 'DTEx',
          'sourceVersion': '1.16.0',
        },
      };

      final r = TuuChargeResponse.fromJson(json);

      expect(r.extraData!.sourceName, 'DTEx');
    });

    test('extraData con customFields → TuuExtraData con la lista parseada',
        () {
      final extraJson = jsonEncode({
        'sourceName': 'DTEx',
        'customFields': [
          {'name': 'orden', 'value': 'ORD-1', 'print': true},
        ],
      });

      final r = TuuChargeResponse.fromJson({
        'transactionStatus': true,
        'extraData': extraJson,
      });

      expect(r.extraData!.customFields.length, 1);
      expect(r.extraData!.customFields.first.name, 'orden');
      expect(r.extraData!.customFields.first.value, 'ORD-1');
      expect(r.extraData!.customFields.first.print, isTrue);
    });
  });

  group('TuuChargeResponse.fromJsonString', () {
    test('parsea String y conserva rawJson', () {
      const String raw =
          '{"transactionStatus":true,"sequenceNumber":"000000999"}';

      final r = TuuChargeResponse.fromJsonString(raw);

      expect(r.approved, isTrue);
      expect(r.sequenceNumber, '000000999');
      expect(r.rawJson, raw);
    });

    test('JSON inválido → FormatException', () {
      expect(
        () => TuuChargeResponse.fromJsonString('not json'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
