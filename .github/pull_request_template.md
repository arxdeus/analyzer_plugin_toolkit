<!--
The title should read as a conventional commit, since it becomes one:

    feat(aliases): resolve through cascade targets

See CONTRIBUTING.md for the types in use.
-->

## What and why

<!-- What changes, and the reason the diff does not already show. -->

## Checks

- [ ] `dart format .`
- [ ] `dart analyze --fatal-infos` is clean
- [ ] `dart test` passes
- [ ] `dart run tool/verify_cache_invalidation.dart` passes (required if the
      analyzer constraint moved)
- [ ] `CHANGELOG.md` updated under `## Unreleased`, if a consumer would notice

## Public API

- [ ] Unchanged
- [ ] Added to, and the workspace's `public_api_test.dart` was updated
- [ ] Breaking, the title carries `!`, and the body explains the migration
