import 'package:flutter_test/flutter_test.dart';
import 'package:tuu_app2app/tuu_app2app.dart';

void main() {
  group('TuuTipPolicy', () {
    test('disabled → -1', () {
      expect(TuuTipPolicy.disabled.toJsonValue(), -1);
      expect(TuuTipPolicy.disabled.isDisabled, isTrue);
      expect(TuuTipPolicy.disabled.isAskUser, isFalse);
      expect(TuuTipPolicy.disabled.isFixed, isFalse);
      expect(TuuTipPolicy.disabled.fixedAmount, isNull);
    });

    test('askUser → 0', () {
      expect(TuuTipPolicy.askUser.toJsonValue(), 0);
      expect(TuuTipPolicy.askUser.isAskUser, isTrue);
      expect(TuuTipPolicy.askUser.isDisabled, isFalse);
      expect(TuuTipPolicy.askUser.isFixed, isFalse);
    });

    test('fixed(500) → 500', () {
      const policy = TuuTipPolicy.fixed(500);

      expect(policy.toJsonValue(), 500);
      expect(policy.isFixed, isTrue);
      expect(policy.fixedAmount, 500);
      expect(policy.isAskUser, isFalse);
      expect(policy.isDisabled, isFalse);
    });

    test('fromJsonValue reconstruye correctamente', () {
      expect(TuuTipPolicy.fromJsonValue(-1), TuuTipPolicy.disabled);
      expect(TuuTipPolicy.fromJsonValue(null), TuuTipPolicy.disabled);
      expect(TuuTipPolicy.fromJsonValue(-5), TuuTipPolicy.disabled);
      expect(TuuTipPolicy.fromJsonValue(0), TuuTipPolicy.askUser);
      expect(TuuTipPolicy.fromJsonValue(750),
          equals(const TuuTipPolicy.fixed(750)));
    });

    test('equality + hashCode coherentes', () {
      expect(
        const TuuTipPolicy.fixed(100),
        equals(const TuuTipPolicy.fixed(100)),
      );
      expect(
        const TuuTipPolicy.fixed(100).hashCode,
        const TuuTipPolicy.fixed(100).hashCode,
      );
      expect(TuuTipPolicy.disabled, isNot(equals(TuuTipPolicy.askUser)));
    });
  });

  group('TuuCashbackPolicy', () {
    test('disabled / askUser / fixed valores', () {
      expect(TuuCashbackPolicy.disabled.toJsonValue(), -1);
      expect(TuuCashbackPolicy.askUser.toJsonValue(), 0);
      expect(const TuuCashbackPolicy.fixed(2000).toJsonValue(), 2000);
    });

    test('fromJsonValue maneja todos los rangos', () {
      expect(TuuCashbackPolicy.fromJsonValue(-1), TuuCashbackPolicy.disabled);
      expect(TuuCashbackPolicy.fromJsonValue(0), TuuCashbackPolicy.askUser);
      expect(
        TuuCashbackPolicy.fromJsonValue(3000),
        equals(const TuuCashbackPolicy.fixed(3000)),
      );
    });
  });
}
