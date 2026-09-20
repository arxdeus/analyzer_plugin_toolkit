# Changelog

All notable changes to this package are recorded here. Versions follow
[semver](https://semver.org): for a library other packages build plugins on, a
rename is breaking even when the behaviour is unchanged.

## 1.0.0

Initial release.

Shared building blocks for annotation-driven Dart analyzer plugins.

- **`AnnotationFinder`** resolves annotations by the declaring *package*, not
  by class name alone, so a same-named annotation from an unrelated package
  cannot drive rules that know nothing about it. Matching the exact library URI
  would be too strict instead, since a package may re-export its annotations
  from several libraries. Non-candidates are rejected by name before a constant
  is evaluated, which is the expensive part, and the answer is memoized per
  element.

- **`ElementCache`** is that memoization, usable directly. Keyed by `Expando`,
  so an entry lives exactly as long as the element it describes rather than
  pinning every element the analysis server has ever seen. Values are boxed so
  `null` can be cached, which matters because "carries no annotation" is the
  common answer and the case the cache exists for.

  Soundness depends on the analyzer yielding fresh element objects for edited
  files, which is its guarantee rather than this package's, so
  `tool/verify_cache_invalidation.dart` checks it empirically.

- **`normalizeElement`** and **`referencedElement`** undo the analyzer details
  that stop elements comparing by identity: a field read resolving to its
  synthetic getter, and a member reached through a generic class resolving to a
  `*Member` wrapper. `referencedElement` also looks through parentheses,
  null-assertions and `this.` access, and its `anyTarget` flag decides whether
  only the enclosing instance's own members resolve.

- **`AliasResolver`** follows a value through the local aliases it hides behind
  within one function body. Resolution returns a set, because `cond ? _a : _b`
  is either one and a loop variable over `[_a, _b]` is both in turn. A local
  counts as an alias only when it is never reassigned, and the walk over the
  body is deferred until the first question is asked.

- **`bodyOf`** finds the body of an element declared in the units under
  analysis, and **`aliasDepthLimit`** exposes the bound on alias chasing.

The exported surface is pinned by a test, so a helper added to an exported
`src/` file cannot become public API unnoticed.

This package deliberately ships no test harness. One for quick fixes has to
import `package:test`, which a plugin's own `lib/` must not pull in: it cannot
coexist with the `test_api` that `flutter_test` pins, and every plugin built on
this toolkit would inherit the conflict.
