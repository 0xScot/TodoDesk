#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/tests"
mkdir -p "$BUILD_DIR"

clang -fobjc-arc -Wall -Wextra -Werror \
    -I"$ROOT_DIR/Sources/TodoDeskCore" \
    "$ROOT_DIR"/Sources/TodoDeskCore/*.m \
    "$ROOT_DIR/Tests/TodoDeskCoreTests/TodoDeskCoreTests.m" \
    -framework Foundation \
    -o "$BUILD_DIR/TodoDeskCoreTests"

"$BUILD_DIR/TodoDeskCoreTests"
