# analyzer_plugin_toolkit

[![pub package](https://img.shields.io/pub/v/analyzer_plugin_toolkit.svg)](https://pub.dev/packages/analyzer_plugin_toolkit)
[![ci](https://github.com/arxdeus/analyzer_plugin_toolkit/actions/workflows/ci.yml/badge.svg)](https://github.com/arxdeus/analyzer_plugin_toolkit/actions/workflows/ci.yml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Shared building blocks for annotation-driven Dart analyzer plugins.

These are the pieces such a plugin needs and none of them should have to write
twice: recognising *your* annotation rather than a same-named one from
somebody else's package, doing that fast enough to run on every node of every
file, comparing elements the analyzer hands back in more than one shape, and
following a value through the local aliases it hides behind.

## Install

```yaml
dependencies:
  analyzer_plugin_toolkit: ^1.0.0
```

```dart
import 'package:analyzer_plugin_toolkit/analyzer_plugin_toolkit.dart';
```

This package is for people **writing** an analyzer plugin. If you are looking
to *use* lint rules in your own project, you want a plugin package, not this.

Requires Dart 3.13.2 or later. Analyzer plugins first appeared in 3.10, but
the element APIs this package is written against settled after that.

## What it gives you

| API | Solves |
| --- | --- |
| `AnnotationFinder` | Does this declaration carry my annotation? Resolved by package, fast enough to ask everywhere. |
| `ElementCache` | Memoize a per-element answer without leaking memory in a long-running server. |
| `normalizeElement` | Compare elements the analyzer returns in more than one shape. |
| `referencedElement` | Find the declaration an expression denotes, through `()`, `!` and `this.`. |
| `AliasResolver` | Follow a value through the local names it hides behind. |

The `example/` directory sketches a complete rule using all five.

## `AnnotationFinder`

The core of an annotation-driven rule: does this declaration carry my
annotation?

```dart
final _annotations = AnnotationFinder('my_package');

bool isMarked(Element? element) => _annotations.has(element, 'Marker');

String? reasonFor(Element? element) =>
    _annotations.valueOf(element, 'Marker')?.getField('reason')?.toStringValue();
```

Two things make this more than a name comparison.

**It resolves by package.** Matching on the class name alone would let
somebody else's `Throws` or `Disposable` drive rules that know nothing about
it. Matching on the exact library URI would be too strict instead: a package
may re-export its annotations from several libraries, and a rule should not
care which one the user imported. So the finder compares the declaring
package, which is the thing that actually identifies an annotation.

**It is fast enough to run everywhere.** Evaluating a constant is the most
expensive thing a rule does, and real code is full of annotations belonging to
somebody else (`@override`, `@immutable`, a generator's), so that evaluation
is almost always wasted. A candidate is therefore rejected by name *before* it
is evaluated. The remaining answer is memoized per element, because the same
element is asked about once per mention though the answer depends only on the
element.

## `ElementCache`

The memoization underneath, usable directly:

```dart
final _isWidget = ElementCache<InterfaceElement, bool>('isWidget');

bool isWidget(InterfaceType type) =>
    _isWidget.of(type.element, () => _computeIsWidget(type));
```

Keyed with an [`Expando`][], so an entry lives exactly as long as the element
it describes. That matters in the analysis server, which is long-running and
rebuilds element models as files change: a plain `Map` would pin every element
of every file ever analysed, and an LRU would need a size nobody can pick
correctly.

Values are boxed so that `null` can be cached. "This element carries no
annotation" is the common answer, and a cache that could not tell it apart
from "not computed yet" would recompute on every mention, which is the case
the cache exists for.

This is sound only because editing a file yields *fresh* element objects, so a
memoized answer can never be read back for changed source. That guarantee is
the analyzer's rather than this package's, so it is checked empirically rather
than assumed:

```sh
dart run tool/verify_cache_invalidation.dart
```

## Element helpers

`normalizeElement` undoes the two analyzer details that stop elements
comparing by identity: reading a field resolves to its synthetic getter, and a
member reached through a generic class resolves to a `*Member` wrapper. A rule
comparing the raw elements would fail to recognise the field it is tracking.

`referencedElement` looks through parentheses, null-assertions and `this.`
access to the declaration an expression denotes. Its `anyTarget` flag decides
whose state counts: by default only the enclosing instance's own members
resolve, so a rule about an object cleaning up after itself is not satisfied
by somebody else's field of the same name.

## `AliasResolver`

Follows a value through the local aliases it hides behind, within one function
body:

```dart
final aliases = AliasResolver.forBody(body);
if (aliases.refersTo(expression, field)) { /* ... */ }
```

Resolution returns a *set*, because one expression can refer to several
declarations: `cond ? _a : _b` is either one, and the loop variable of
`for (final c in [_a, _b])` takes both in turn. A local is an alias for its
initializer only when it is never reassigned. The walk over the body is
deferred until the first question is asked, so building a resolver for a
member that turns out to have nothing of interest costs nothing.

## Testing quick fixes

`analyzer_testing` ships a harness for *rules* but not for *fixes*. This
package does not ship one either, deliberately: such a harness must import
`package:test`, a library under `lib/` may only import from `dependencies`,
and making `test` a real dependency here would push it onto every plugin built
on the toolkit, where it cannot coexist with the `test_api` that
`flutter_test` pins.

Keep one in your plugin's own `test/src/` instead. Under about 200 lines is
enough: run the fix your rule produced through the server's fix pipeline, apply
the edits to the source under test, and compare the result against the expected
output.

## Development

```sh
dart analyze --fatal-infos                    # must be clean
dart test                                     # the toolkit's own behaviour
dart run tool/verify_cache_invalidation.dart  # the cache cannot go stale
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the scope of the package, the
commit conventions, and how a release is cut.

## License

MIT. See [LICENSE](LICENSE).

[`Expando`]: https://api.dart.dev/stable/dart-core/Expando-class.html
