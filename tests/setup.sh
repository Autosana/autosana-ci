#!/usr/bin/env bash
# Install bats helper libraries into tests/lib/
# Run this once locally, or in CI before running tests.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

mkdir -p "$LIB_DIR"

if [ ! -d "$LIB_DIR/bats-support" ]; then
    echo "Installing bats-support..."
    git clone --depth 1 --branch v0.3.0 https://github.com/bats-core/bats-support.git "$LIB_DIR/bats-support"
fi

if [ ! -d "$LIB_DIR/bats-assert" ]; then
    echo "Installing bats-assert..."
    git clone --depth 1 --branch v2.2.4 https://github.com/bats-core/bats-assert.git "$LIB_DIR/bats-assert"
fi

echo "Bats helpers installed in $LIB_DIR"
