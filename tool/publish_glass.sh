#!/bin/bash
# Publishes packages/iphone_duo_ui_pro_glass from a copy outside the repository.
#
# The core package keeps packages/ out of its own archive with .pubignore, and pub
# applies the ignore files of parent directories to a nested package as well.
# Published in place, the companion would come out empty ("The pubspec is hidden").
#
#   tool/publish_glass.sh --dry-run          validate against pub.dev
#   tool/publish_glass.sh --dry-run --local  validate against the core package in
#                                            this checkout (before it is published)
#   tool/publish_glass.sh                    publish (the core version it needs
#                                            must be on pub.dev first)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

LOCAL=0
ARGS=()
for arg in "$@"; do
  if [ "$arg" = "--local" ]; then LOCAL=1; else ARGS+=("$arg"); fi
done

rsync -a \
  --exclude '.dart_tool' --exclude 'build' --exclude 'Pods' --exclude '.symlinks' \
  --exclude 'pubspec.lock' --exclude 'pubspec_overrides.yaml' --exclude 'ephemeral' \
  "$ROOT/packages/iphone_duo_ui_pro_glass/" "$TMP/iphone_duo_ui_pro_glass/"

cd "$TMP/iphone_duo_ui_pro_glass"
if [ "$LOCAL" = "1" ]; then
  printf 'dependency_overrides:\n  iphone_duo_ui_pro:\n    path: %s\n' "$ROOT" > pubspec_overrides.yaml
fi
dart pub publish ${ARGS[@]+"${ARGS[@]}"}
