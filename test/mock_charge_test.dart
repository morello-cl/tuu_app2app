import 'package:flutter_test/flutter_test.dart';
import 'package:tuu_app2app/tuu_app2app.dart';

void main() {
  group('TuuClient en modo mock', () {
    test('approved → TuuChargeResponse con datos del behavior', () async {
      final tuu = TuuClient(
        config: const TuuConfig(
          mode: TuuMode.mock,
          mockBehavior: TuuMockBehavior(
            chargeOutcome: TuuMockOutcome.approved,
            responseDelayMs: 0,
            approvedAuthCode: 'MOCKAB',
            approvedLast4: '****1234',
            approvedTransactionTip: 500,
          ),
        ),
      );

      final r = await tuu.charge(const TuuChargeRequest(amount: 1000));

      expect(r.approved, isTrue);
      expect(r.authCode, 'MOCKAB');
      expect(r.last4, '****1234');
      expect(r.transactionTip, 500);
      expect(r.rawJson, isNotNull,
          reason: 'el cliente debe preservar el JSON crudo');
    });

    test('declined → TuuRejectedException con errorCode 9', () async {
      final tuu = TuuClient(
        config: const TuuConfig(
          mode: TuuMode.mock,
          mockBehavior: TuuMockBehavior(
            chargeOutcome: TuuMockOutcome.declined,
            responseDelayMs: 0,
            declineErrorCode: 9,
            declineMessage: 'Error en proceso de pago',
          ),
        ),
      );

      await expectLater(
        tuu.charge(const TuuChargeRequest(amount: 1000)),
        throwsA(
          isA<TuuRejectedException>()
              .having((e) => e.errorCode, 'errorCode', 9)
              .having((e) => e.message, 'message', 'Error en proceso de pago'),
        ),
      );
    });

    test('userCancelled → TuuUserCancelledException', () async {
      final tuu = TuuClient(
        config: const TuuConfig(
          mode: TuuMode.mock,
          mockBehavior: TuuMockBehavior(
            chargeOutcome: TuuMockOutcome.userCancelled,
            responseDelayMs: 0,
          ),
        ),
      );

      await expectLater(
        tuu.charge(const TuuChargeRequest(amount: 1000)),
        throwsA(isA<TuuUserCancelledException>()),
      );
    });

    test('internalError (errorCode 12 / ICE-12) → TuuInternalException',
        () async {
      final tuu = TuuClient(
        config: const TuuConfig(
          mode: TuuMode.mock,
          mockBehavior: TuuMockBehavior(
            chargeOutcome: TuuMockOutcome.internalError,
            responseDelayMs: 0,
            internalErrorCode: 12,
            internalErrorCodeOnApp: 'ICE-12',
            internalErrorMessage: 'Llaves no inyectadas',
          ),
        ),
      );

      await expectLater(
        tuu.charge(const TuuChargeRequest(amount: 1000)),
        throwsA(
          isA<TuuInternalException>()
              .having((e) => e.errorCode, 'errorCode', 12)
              .having((e) => e.errorCodeOnApp, 'errorCodeOnApp', 'ICE-12')
              .having((e) => e.message, 'message', 'Llaves no inyectadas'),
        ),
      );
    });

    test('isInstalled() en modo mock siempre devuelve true', () async {
      final tuu = TuuClient(
        config: const TuuConfig(
          mode: TuuMode.mock,
          mockBehavior: TuuMockBehavior(responseDelayMs: 0),
        ),
      );

      expect(await tuu.isInstalled(), isTrue);
      expect(await tuu.isInstalledDev(), isTrue);
    });
  });

  group('TuuClient — mapeo per doc oficial TUU', () {
    test('errorCode 10 → TuuUserCancelledException', () async {
      final tuu = TuuClient(
        config: const TuuConfig(
          mode: TuuMode.mock,
          mockBehavior: TuuMockBehavior(
            chargeOutcome: TuuMockOutcome.declined,
            responseDelayMs: 0,
            declineErrorCode: 10,
            declineMessage: 'La transacción fue cancelada.',
          ),
        ),
      );

      await expectLater(
        tuu.charge(const TuuChargeRequest(amount: 1000)),
        throwsA(isA<TuuUserCancelledException>()),
      );
    });

    test('errorCodeOnApp ICE-10 → TuuUserCancelledException', () async {
      final tuu = TuuClient(
        config: const TuuConfig(
          mode: TuuMode.mock,
          mockBehavior: TuuMockBehavior(
            chargeOutcome: TuuMockOutcome.declined,
            responseDelayMs: 0,
            declineErrorCode: 99,
            declineErrorCodeOnApp: 'ICE-10',
          ),
        ),
      );

      await expectLater(
        tuu.charge(const TuuChargeRequest(amount: 1000)),
        throwsA(isA<TuuUserCancelledException>()),
      );
    });

    test('errorCode 14 (sin internet) → TuuInternalException', () async {
      final tuu = TuuClient(
        config: const TuuConfig(
          mode: TuuMode.mock,
          mockBehavior: TuuMockBehavior(
            chargeOutcome: TuuMockOutcome.internalError,
            responseDelayMs: 0,
            internalErrorCode: 14,
            internalErrorCodeOnApp: 'ICE-14',
            internalErrorMessage:
                'El dispositivo no esta conectado a internet.',
          ),
        ),
      );

      await expectLater(
        tuu.charge(const TuuChargeRequest(amount: 1000)),
        throwsA(isA<TuuInternalException>()),
      );
    });

    test('errorCodeOnApp HP-500 (legacy) → TuuInternalException', () async {
      final tuu = TuuClient(
        config: const TuuConfig(
          mode: TuuMode.mock,
          mockBehavior: TuuMockBehavior(
            chargeOutcome: TuuMockOutcome.declined,
            responseDelayMs: 0,
            declineErrorCode: 99,
            declineErrorCodeOnApp: 'HP-500',
          ),
        ),
      );

      await expectLater(
        tuu.charge(const TuuChargeRequest(amount: 1000)),
        throwsA(isA<TuuInternalException>()),
      );
    });
  });
}
