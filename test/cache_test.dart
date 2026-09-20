import 'package:analyzer_plugin_toolkit/analyzer_plugin_toolkit.dart';
import 'package:test/test.dart';

void main() {
  group('ElementCache', () {
    test('computes once and returns the memoized answer afterwards', () {
      final cache = ElementCache<Object, int>('counting');
      final key = Object();
      var computed = 0;

      expect(cache.of(key, () => ++computed), 1);
      expect(cache.of(key, () => ++computed), 1);
      expect(cache.of(key, () => ++computed), 1);
      expect(
        computed,
        1,
        reason: 'the second and third calls must not recompute',
      );
    });

    test('memoizes a null answer instead of recomputing it', () {
      // The reason values are boxed. "This element carries no annotation" is
      // the common answer, and an unboxed cache could not tell it apart from
      // "not computed yet", so it would recompute on every single mention:
      // exactly the case the cache exists for.
      final cache = ElementCache<Object, String?>('nullable');
      final key = Object();
      var computed = 0;

      expect(
        cache.of(key, () {
          computed++;
          return null;
        }),
        isNull,
      );
      expect(
        cache.of(key, () {
          computed++;
          return null;
        }),
        isNull,
      );
      expect(computed, 1, reason: 'a null answer must be cached too');
    });

    test('keeps answers for different keys apart', () {
      final cache = ElementCache<Object, String>('distinct');
      final first = Object();
      final second = Object();

      expect(cache.of(first, () => 'a'), 'a');
      expect(cache.of(second, () => 'b'), 'b');
      expect(cache.of(first, () => 'unused'), 'a');
      expect(cache.of(second, () => 'unused'), 'b');
    });

    test('distinguishes equal-but-not-identical keys', () {
      // Keyed on identity, because that is what an Expando does and what the
      // element model needs: two distinct elements are two questions even when
      // something about them compares equal.
      final cache = ElementCache<List<int>, String>('identity');
      final first = [1, 2, 3];
      final second = [1, 2, 3];

      expect(first, equals(second));
      expect(identical(first, second), isFalse);
      expect(cache.of(first, () => 'first'), 'first');
      expect(cache.of(second, () => 'second'), 'second');
    });
  });
}
