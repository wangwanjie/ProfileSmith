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

# 分架构 DMG 的命名与解析
assert_equals "ProfileSmith_V_1.5.0_arm64.dmg" "$(dmg_file_name 1.5.0 arm64)" "arm64 DMG name"
assert_equals "ProfileSmith_V_1.5.0_x86_64.dmg" "$(dmg_file_name 1.5.0 x86_64)" "x86_64 DMG name"
assert_equals "arm64" "$(arch_from_dmg_name /tmp/ProfileSmith_V_1.5.0_arm64.dmg)" "arch from arm64 DMG"
assert_equals "x86_64" "$(arch_from_dmg_name ProfileSmith_V_1.5.0_x86_64.dmg)" "arch from x86_64 DMG"
assert_equals "universal" "$(arch_from_dmg_name ProfileSmith_V_1.4.3.dmg)" "legacy DMG is universal"
assert_equals "1.5.0" "$(version_from_dmg_name ProfileSmith_V_1.5.0_x86_64.dmg)" "version from arch DMG"
assert_equals "1.4.3" "$(version_from_dmg_name ProfileSmith_V_1.4.3.dmg)" "version from legacy DMG"
if version_from_dmg_name "Other_V_1.0.dmg" >/dev/null; then
    printf 'FAIL: unrelated DMG names must be rejected\n' >&2
    exit 1
fi
if is_supported_arch "i386"; then
    printf 'FAIL: i386 must not be a supported arch\n' >&2
    exit 1
fi
assert_file_contains "$PROJECT_DIR/scripts/build_dmg.sh" 'verify_binary_arch'

printf 'PASS: per-arch DMG naming helpers\n'
