/// Per-element memoization for the answers an analysis rule asks repeatedly.
///
/// A rule runs over every node of every unit, and the expensive questions it
/// asks ("is this class a Flutter widget?", "does this element carry the
/// annotation?") are questions about *elements*, of which a file mentions far
/// fewer than it has nodes. `Text(...)` appearing four hundred times in a
/// widget tree is four hundred questions about a single `Text` element, and a
/// call to `int.parse` from four hundred places is four hundred questions
/// about one method.
///
/// Answers are keyed on the element with an [Expando], so an entry lives
/// exactly as long as the element it describes. That matters in the analysis
/// server, which is a long-running process that discards and rebuilds element
/// models as files change: a plain `Map` would pin every element of every file
/// ever analysed, and an LRU would need a size nobody can pick correctly.
/// [Expando] entries are collected with their keys, so the cache cannot leak.
///
/// Soundness rests on one assumption: that editing a file yields *fresh*
/// element objects, so a memoized answer can never be read back for a
/// declaration whose source has changed. That is the analyzer's guarantee
/// rather than this package's, so it is checked empirically by
/// `tool/verify_cache_invalidation.dart`.
library;

/// A memo table for answers of type [T] about elements of type [K].
///
/// [Expando] cannot store `null`, and "the answer is `null`" is a real answer
/// worth caching (most elements carry no given annotation), so values are
/// boxed. The box is what distinguishes "computed, and the answer was nothing"
/// from "not computed yet".
final class ElementCache<K extends Object, T> {
  /// Creates a memo table, named [_name] for debugging.
  ElementCache(this._name);

  final String _name;
  late final Expando<_Box<T>> _entries = Expando<_Box<T>>(_name);

  /// Returns the memoized answer for [key], computing it with [ifAbsent] on
  /// the first call.
  T of(K key, T Function() ifAbsent) {
    final existing = _entries[key];
    if (existing != null) {
      return existing.value;
    }
    final value = ifAbsent();
    _entries[key] = _Box(value);
    return value;
  }
}

/// A memoized value, boxed so that `null` can be stored.
final class _Box<T> {
  const _Box(this.value);

  final T value;
}
