#!/usr/bin/env bash
#
# Makes a standalone clone of this repository resolvable.
#
# The package is developed from a workspace root above it, so the tree carries
# two things that only make sense with that root in place:
#
#   * `resolution: workspace` in pubspec.yaml, which needs a workspace root in
#     a parent directory, and
#   * example/pubspec_overrides.yaml, which redirects both this package and
#     arxdeus_lints to sibling paths.
#
# Neither survives publication: pub strips `resolution` from the pubspec it
# uploads, and .pubignore keeps the overrides file out of the archive. So the
# detached tree this produces is the one a consumer actually gets, which is
# why CI checks that rather than the workspace.
#
# The example keeps an override for *this* package alone, pointing at the
# working tree. Its pubspec depends on a published version, and the point of
# running CI is to check the code in front of us. Everything else, including
# arxdeus_lints, resolves from pub.dev like any consumer's project.
#
# Idempotent, and safe to run in a clone you are working in, though it does
# edit files: do not commit what it changes.

set -euo pipefail

cd "$(dirname "$0")/../.."

sed -i.bak '/^resolution: workspace$/d' pubspec.yaml && rm -f pubspec.yaml.bak

cat > example/pubspec_overrides.yaml <<'YAML'
# Written by .github/tool/detach_workspace.sh. Not the file in git.
dependency_overrides:
  analyzer_plugin_toolkit:
    path: ../
YAML

echo "detached: pubspec.yaml and example/pubspec_overrides.yaml rewritten"
