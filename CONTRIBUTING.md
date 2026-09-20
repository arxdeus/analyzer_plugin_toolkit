# Contributing

Thanks for taking an interest. This package is small and its scope is narrow
on purpose, so the most useful thing you can do before writing code is to open
an issue describing the problem you hit.

## Scope

`analyzer_plugin_toolkit` holds the pieces that *more than one* annotation
driven analyzer plugin needs. A helper used by exactly one plugin belongs in
that plugin, not here. A helper that would pull `package:test` (or anything
else a plugin's `lib/` may not import) into consumers cannot live here at all.

## Where development happens

`pubspec.yaml` carries `resolution: workspace`, because the package is
developed from a workspace root above it.

You can work on it standalone. Clone it and run
`.github/tool/detach_workspace.sh`, which drops the `resolution: workspace`
line and points the example at your working tree, then `dart pub get`. Do not
commit what it changes: pub strips `resolution` itself when publishing, and CI
runs the same script.

## Checks

Everything CI runs, you can run:

```sh
dart format .
dart analyze --fatal-infos                    # must be clean
dart test                                     # the toolkit's own behaviour
dart run tool/verify_cache_invalidation.dart  # the cache cannot go stale
dart pub publish --dry-run                    # the archive still validates
```

Two of these are less obvious than they look.

`ElementCache` is sound only because the analyzer hands back *fresh* element
objects for a file that was edited, so a memoized answer can never be read
back for changed source. That is the analyzer's guarantee rather than this
package's, so `tool/verify_cache_invalidation.dart` checks it empirically
against the analyzer version actually resolved. Run it after any analyzer
upgrade.

The exported surface is pinned by a test, which lives in the workspace rather
than here because it pins every package's surface in one place. If you add a
declaration to a file under `lib/src/` that is exported, that test fails until
you acknowledge it, which is the point: public API should be added
deliberately rather than by being in the wrong file. Run it from a workspace
checkout with `dart test test/public_api_test.dart`.

## Commit messages

Commits follow [Conventional Commits][cc]:

```
<type>(<optional scope>): <summary in the imperative mood>
```

Types in use here:

| Type | For |
| --- | --- |
| `feat` | A new capability in the public API. |
| `fix` | A behaviour that was wrong. |
| `perf` | Same behaviour, less work. Relevant: rules run on every node. |
| `refactor` | Internal shape, no behaviour change. |
| `docs` | README, CHANGELOG, comments. |
| `test` | Tests and the tools that check invariants. |
| `build` | `pubspec.yaml`, dependency constraints, the archive. |
| `ci` | Workflows. |
| `chore` | Anything left over. |

Append `!` after the type (`refactor!:`) for a breaking change, and explain the
migration in the body. For a library other people build plugins on, a rename
is breaking even when the behaviour is identical.

Keep the summary under about 72 characters, lowercase, no trailing period.
Explain *why* in the body when the diff does not already say it.

## Pull requests

- One concern per pull request.
- Add a test with any behaviour change. If the behaviour is about how the
  analyzer models something, prefer a test that resolves real source over one
  that asserts against a hand-built element.
- Update `CHANGELOG.md` under an `## Unreleased` heading for anything a
  consumer would notice. Version bumps happen at release time, not in the
  pull request.

## Releasing

1. `CHANGELOG.md`: turn `## Unreleased` into the version, and check that it
   describes what changed rather than which files moved.
2. `pubspec.yaml`: bump `version`, following [semver][]. Bump the constraint in
   the README's install snippet and in `example/pubspec.yaml` to match.
3. `dart pub publish --dry-run` must be clean.
4. Merge, then tag: `git tag v<version> && git push origin v<version>`.

The tag triggers the `publish` workflow, which publishes to pub.dev through
GitHub's OIDC token. There is no stored pub credential to leak.

## License

By contributing you agree that your contribution is MIT licensed, as the rest
of the package is.

[cc]: https://www.conventionalcommits.org/en/v1.0.0/
[semver]: https://semver.org
