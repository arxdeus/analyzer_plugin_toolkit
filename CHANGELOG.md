## 1.0.0

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
