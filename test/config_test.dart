import 'package:flutter_test/flutter_test.dart';
import 'package:tuu_app2app/tuu_app2app.dart';

void main() {
  group('TuuConfig.resolvePackageName', () {
    test('production → com.haulmer.paymentapp', () {
      const config = TuuConfig(mode: TuuMode.production);
      expect(config.resolvePackageName(), tuuPackageProduction);
      expect(tuuPackageProduction, 'com.haulmer.paymentapp');
    });

    test('debug → com.haulmer.paymentapp.dev', () {
      const config = TuuConfig(mode: TuuMode.debug);
      expect(config.resolvePackageName(), tuuPackageDevelopment);
      expect(tuuPackageDevelopment, 'com.haulmer.paymentapp.dev');
    });

    test('mock → com.haulmer.paymentapp.dev', () {
      const config = TuuConfig(mode: TuuMode.mock);
      expect(config.resolvePackageName(), tuuPackageDevelopment);
    });

    test('packageName explícito pisa al default', () {
      const config = TuuConfig(
        mode: TuuMode.production,
        packageName: 'com.haulmer.paymentapp.dev',
      );
      expect(config.resolvePackageName(), 'com.haulmer.paymentapp.dev');
    });

    test('packageName vacío vuelve al default', () {
      const config = TuuConfig(
        mode: TuuMode.production,
        packageName: '',
      );
      expect(config.resolvePackageName(), tuuPackageProduction);
    });
  });

  group('TuuDteType', () {
    test('valores documentados están en validValues', () {
      expect(TuuDteType.isValid(TuuDteType.boleta), isTrue);
      expect(TuuDteType.isValid(TuuDteType.factura), isTrue);
      expect(TuuDteType.isValid(TuuDteType.facturaExenta), isTrue);
      expect(TuuDteType.isValid(TuuDteType.facturaCompra), isTrue);
      expect(TuuDteType.isValid(TuuDteType.none), isTrue);
      expect(TuuDteType.isValid(TuuDteType.other), isTrue);
    });

    test('valor no documentado → isValid false', () {
      expect(TuuDteType.isValid(1), isFalse);
      expect(TuuDteType.isValid(100), isFalse);
    });

    test('boleta == 48 (default histórico)', () {
      expect(TuuDteType.boleta, 48);
    });

    test('factura == 33', () {
      expect(TuuDteType.factura, 33);
    });
  });

  group('TuuPaymentMethod — values per doc oficial', () {
    test('askUser=0, credit=1, debit=2', () {
      expect(TuuPaymentMethod.askUser.value, 0);
      expect(TuuPaymentMethod.credit.value, 1);
      expect(TuuPaymentMethod.debit.value, 2);
    });

    test('fromValue recupera correctamente', () {
      expect(TuuPaymentMethod.fromValue(0), TuuPaymentMethod.askUser);
      expect(TuuPaymentMethod.fromValue(1), TuuPaymentMethod.credit);
      expect(TuuPaymentMethod.fromValue(2), TuuPaymentMethod.debit);
      expect(TuuPaymentMethod.fromValue(null), TuuPaymentMethod.askUser);
      expect(TuuPaymentMethod.fromValue(99), TuuPaymentMethod.askUser);
    });
  });
}
