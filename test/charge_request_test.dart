import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tuu_app2app/tuu_app2app.dart';

void main() {
  group('TuuChargeRequest.toJson — defaults', () {
    test('amount obligatorio; resto con defaults seguros', () {
      const request = TuuChargeRequest(amount: 1000);

      final Map<String, Object?> json = request.toJson(
        sourceName: 'DTEx',
        sourceVersion: '1.16.0',
        defaultPrintVoucherOnApp: true,
        defaultDteType: TuuDteType.boleta,
      );

      expect(json['amount'], 1000);
      expect(json['tip'], -1, reason: 'TuuTipPolicy.disabled → -1');
      expect(json['cashback'], -1, reason: 'TuuCashbackPolicy.disabled → -1');
      expect(json['method'], TuuPaymentMethod.askUser.value);
      expect(json['method'], 0);
      expect(json['installmentsQuantity'], 0);
      expect(json['printVoucherOnApp'], true);
      expect(json['dteType'], 48);

      final Object? extra = json['extraData'];
      expect(extra, isA<Map<String, Object?>>());
      final Map<String, Object?> extraMap = extra! as Map<String, Object?>;
      expect(extraMap['sourceName'], 'DTEx');
      expect(extraMap['sourceVersion'], '1.16.0');
    });
  });

  group('TuuChargeRequest.toJson — tip / cashback policies', () {
    test('tip askUser → 0 (preguntar al usuario)', () {
      const request = TuuChargeRequest(
        amount: 1000,
        tip: TuuTipPolicy.askUser,
      );

      final json = request.toJson(
        sourceName: 'X',
        sourceVersion: 'Y',
        defaultPrintVoucherOnApp: true,
        defaultDteType: TuuDteType.boleta,
      );

      expect(json['tip'], 0);
    });

    test('tip fixed → monto exacto', () {
      const request = TuuChargeRequest(
        amount: 5000,
        tip: TuuTipPolicy.fixed(500),
      );

      final json = request.toJson(
        sourceName: 'X',
        sourceVersion: 'Y',
        defaultPrintVoucherOnApp: true,
        defaultDteType: TuuDteType.boleta,
      );

      expect(json['tip'], 500);
    });

    test('cashback askUser → 0', () {
      const request = TuuChargeRequest(
        amount: 5000,
        method: TuuPaymentMethod.debit,
        cashback: TuuCashbackPolicy.askUser,
      );

      final json = request.toJson(
        sourceName: 'X',
        sourceVersion: 'Y',
        defaultPrintVoucherOnApp: true,
        defaultDteType: TuuDteType.boleta,
      );

      expect(json['cashback'], 0);
    });

    test('cashback fixed → monto exacto', () {
      const request = TuuChargeRequest(
        amount: 5000,
        method: TuuPaymentMethod.debit,
        cashback: TuuCashbackPolicy.fixed(2000),
      );

      final json = request.toJson(
        sourceName: 'X',
        sourceVersion: 'Y',
        defaultPrintVoucherOnApp: true,
        defaultDteType: TuuDteType.boleta,
      );

      expect(json['cashback'], 2000);
    });
  });

  group('TuuChargeRequest.toJson — method values per doc oficial', () {
    test('askUser → 0', () {
      const request = TuuChargeRequest(
        amount: 1,
        method: TuuPaymentMethod.askUser,
      );
      expect(
        request
            .toJson(
              sourceName: 'X',
              sourceVersion: 'Y',
              defaultPrintVoucherOnApp: true,
              defaultDteType: 48,
            )['method'],
        0,
      );
    });

    test('credit → 1', () {
      const request = TuuChargeRequest(
        amount: 1,
        method: TuuPaymentMethod.credit,
      );
      expect(
        request
            .toJson(
              sourceName: 'X',
              sourceVersion: 'Y',
              defaultPrintVoucherOnApp: true,
              defaultDteType: 48,
            )['method'],
        1,
      );
    });

    test('debit → 2', () {
      const request = TuuChargeRequest(
        amount: 1,
        method: TuuPaymentMethod.debit,
      );
      expect(
        request
            .toJson(
              sourceName: 'X',
              sourceVersion: 'Y',
              defaultPrintVoucherOnApp: true,
              defaultDteType: 48,
            )['method'],
        2,
      );
    });
  });

  group('TuuChargeRequest.toJson — extraData merging', () {
    test('extraData del config (sourceName/Version) se inyecta', () {
      const request = TuuChargeRequest(amount: 1000);

      final json = request.toJson(
        sourceName: 'DTEx',
        sourceVersion: '1.16.0',
        defaultPrintVoucherOnApp: true,
        defaultDteType: 48,
      );
      final extra = json['extraData']! as Map<String, Object?>;

      expect(extra['sourceName'], 'DTEx');
      expect(extra['sourceVersion'], '1.16.0');
    });

    test('sourceName explícito en TuuExtraData pisa al del config', () {
      const request = TuuChargeRequest(
        amount: 1000,
        extraData: TuuExtraData(sourceName: 'Custom', sourceVersion: '9.9.9'),
      );

      final json = request.toJson(
        sourceName: 'DTEx',
        sourceVersion: '1.16.0',
        defaultPrintVoucherOnApp: true,
        defaultDteType: 48,
      );
      final extra = json['extraData']! as Map<String, Object?>;

      expect(extra['sourceName'], 'Custom');
      expect(extra['sourceVersion'], '9.9.9');
    });

    test('customFields se serializa como array de objetos', () {
      const request = TuuChargeRequest(
        amount: 1000,
        extraData: TuuExtraData(
          customFields: [
            TuuCustomField(name: 'orden', value: 'ORD-1', print: true),
            TuuCustomField(name: 'patente', value: 'AB-12-CD', print: false),
          ],
        ),
      );

      final json = request.toJson(
        sourceName: 'DTEx',
        sourceVersion: '1.16.0',
        defaultPrintVoucherOnApp: true,
        defaultDteType: 48,
      );
      final extra = json['extraData']! as Map<String, Object?>;
      final fields = extra['customFields']! as List;

      expect(fields.length, 2);
      final first = fields.first as Map;
      expect(first['name'], 'orden');
      expect(first['value'], 'ORD-1');
      expect(first['print'], true);
    });

    test('campos null de TuuExtraData se omiten del JSON', () {
      const request = TuuChargeRequest(amount: 1000);

      final json = request.toJson(
        sourceName: 'DTEx',
        sourceVersion: '1.16.0',
        defaultPrintVoucherOnApp: true,
        defaultDteType: 48,
      );
      final extra = json['extraData']! as Map<String, Object?>;

      expect(extra.containsKey('taxIdnValidation'), isFalse);
      expect(extra.containsKey('exemptAmount'), isFalse);
      expect(extra.containsKey('netAmount'), isFalse);
      expect(extra.containsKey('customFields'), isFalse);
    });
  });

  group('TuuChargeRequest.toJsonString', () {
    test('produce un JSON parseable con la misma forma que toJson', () {
      const request = TuuChargeRequest(
        amount: 1500,
        tip: TuuTipPolicy.fixed(150),
      );

      final String encoded = request.toJsonString(
        sourceName: 'DTEx',
        sourceVersion: '1.16.0',
        defaultPrintVoucherOnApp: true,
        defaultDteType: 48,
      );

      final decoded = jsonDecode(encoded) as Map<String, Object?>;
      expect(decoded['amount'], 1500);
      expect(decoded['tip'], 150);
    });
  });

  group('TuuChargeRequest — overrides puntuales', () {
    test('printVoucherOnApp/dteType de la request pisan al config', () {
      const request = TuuChargeRequest(
        amount: 1000,
        printVoucherOnApp: false,
        dteType: TuuDteType.factura,
      );

      final json = request.toJson(
        sourceName: 'X',
        sourceVersion: 'Y',
        defaultPrintVoucherOnApp: true,
        defaultDteType: TuuDteType.boleta,
      );

      expect(json['printVoucherOnApp'], false);
      expect(json['dteType'], 33);
    });
  });
}
