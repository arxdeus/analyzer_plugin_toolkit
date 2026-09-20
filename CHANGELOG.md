## 1.0.0

- **The fix-test harness is gone from the published surface.** It was
  `lib/testing.dart` here, which made this package unpublishable: the harness
  imports `package:test` and `package:analyzer_testing`, and a library under
  `lib/` may only import from `dependencies`. Declaring them as real
  dependencies was not an option either, because `test` cannot coexist with the
  `test_api` that `flutter_test` pins, so every plugin built on this toolkit
  would have become unresolvable inside a Flutter package.

  Migration: keep a harness in your plugin's own `test/`. The extension and its
  members can move there unchanged.

- `export` directives no longer carry `show` clauses. A `show` that lists
  exactly what the file declares is noise, and one that drifts out of date is
  worse than noise, so the exported surface is now decided by what the `src/`
  files declare publicly.

  That is only safe with something checking it, because without a `show` a
  helper added to an exported `src/` file becomes public API the moment it is
  written. `test/public_api_test.dart` pins the exported names of every
  published library and fails naming the symbol when one leaks. The removal
  itself was verified the same way: the exported surface is byte-identical to
  what the `show` clauses produced, so the clauses were redundant rather than
  load-bearing.

- Initial release.

  Shared building blocks for annotation-driven analyzer plugins: the
  per-element memo table, the annotation lookup, and the element normalization
  that makes elements comparable by identity. A correctness-critical lookup
  maintained in one place rather than copied into every plugin that needs it.

  What the toolkit provides:

  - `ElementCache`, per-element memoization keyed by `Expando`, so an entry
    lives exactly as long as the element it describes rather than pinning
    every element the analysis server has ever seen.
  - `AnnotationFinder`, which resolves annotations by declaring *package*
    rather than by class name alone, so a same-named annotation from an
    unrelated package cannot drive rules that know nothing about it. Rejects
    non-candidates by name before evaluating a constant, which is the
    expensive part.
  - `normalizeElement` and `referencedElement`, which undo the two analyzer
    details that stop elements comparing by identity: a field read resolving
    to its synthetic getter, and a generic member resolving to a wrapper.
  - `AliasResolver`, which follows a value through the local aliases it hides
    behind within one function body.
  - `bodyOf`, which finds the body of an element declared in the units under
    analysis.
  - A `testing` library with a harness that drives the analysis server's real
    fix pipeline, for asserting what a quick fix produces.
