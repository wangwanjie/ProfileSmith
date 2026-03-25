#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=../common.sh
source "$PROJECT_DIR/scripts/common.sh"

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if [[ "$expected" != "$actual" ]]; then
        printf 'FAIL: %s\nexpected: %s\nactual:   %s\n' "$message" "$expected" "$actual" >&2
        exit 1
    fi
}

assert_file_contains() {
    local file_path="$1"
    local expected="$2"

    if ! grep -Fq -- "$expected" "$file_path"; then
        printf 'FAIL: %s does not contain %s\n' "$file_path" "$expected" >&2
        exit 1
    fi
}

expected_workspace="$PROJECT_DIR/ProfileSmith.xcworkspace"
assert_equals "$expected_workspace" "$MAIN_WORKSPACE" "main workspace path should point to the CocoaPods workspace"

build_args=()
while IFS= read -r arg; do
    build_args+=("$arg")
done < <(main_build_xcodebuild_args)

assert_equals "-workspace" "${build_args[0]:-}" "first xcodebuild selector should be -workspace"
assert_equals "$expected_workspace" "${build_args[1]:-}" "xcodebuild should use the main workspace path"
assert_equals "-scheme" "${build_args[2]:-}" "workspace selector should be followed by -scheme"
assert_equals "$SCHEME" "${build_args[3]:-}" "workspace build should keep using the main scheme"

assert_file_contains "$PROJECT_DIR/scripts/build_dmg.sh" 'main_build_xcodebuild_args'

printf 'PASS: main build scripts use xcworkspace\n'
