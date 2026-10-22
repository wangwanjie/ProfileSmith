#!/usr/bin/env bash

# 为新版本生成 Sparkle appcast 条目，并合并进仓库根目录的 appcast.xml。
#
# 分架构分发后，同一版本会有 arm64 与 x86_64 两个 DMG：
# - arm64 条目带 <sparkle:hardwareRequirements>arm64</sparkle:hardwareRequirements>，Intel 机器会跳过它；
# - Sparkle 在版本号相同的候选里选择 appcast 中靠前的条目，因此 arm64 条目排在 x86_64 之前，
#   Apple 芯片机器（包括旧版通用包用户）会升级到原生 arm64 版本，Intel 机器则落到 x86_64 版本。
# 旧版本条目原样保留，不依赖本地是否还留着历史 DMG。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

DEFAULT_OUTPUT_PATH="$PROJECT_DIR/appcast.xml"

ARCHIVE_PATHS=()
OUTPUT_PATH="$DEFAULT_OUTPUT_PATH"
REPO=""
ACCOUNT="$DEFAULT_SPARKLE_ACCOUNT"
NOTES=""
NOTES_FILE=""

usage() {
    cat <<EOF
Usage:
  ./scripts/generate_appcast.sh --archive PATH [--archive PATH ...] [--output PATH]
                                [--repo OWNER/REPO] [--account ACCOUNT]
                                [--notes TEXT | --notes-file FILE]

  --archive 可重复传入同一版本不同架构的 DMG（${APP_NAME}_V_<版本>_<arm64|x86_64>.dmg）。
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --archive)
            ARCHIVE_PATHS+=("${2:-}")
            shift 2
            ;;
        --output)
            OUTPUT_PATH="${2:-}"
            shift 2
            ;;
        --repo)
            REPO="${2:-}"
            shift 2
            ;;
        --account)
            ACCOUNT="${2:-}"
            shift 2
            ;;
        --notes)
            NOTES="${2:-}"
            shift 2
            ;;
        --notes-file)
            NOTES_FILE="${2:-}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "error: unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ -n "$NOTES" && -n "$NOTES_FILE" ]]; then
    echo "error: --notes and --notes-file are mutually exclusive" >&2
    exit 1
fi

if [[ ${#ARCHIVE_PATHS[@]} -eq 0 ]]; then
    echo "error: at least one --archive is required" >&2
    usage >&2
    exit 1
fi

require_command /usr/bin/python3
require_command /usr/libexec/PlistBuddy

OUTPUT_PATH="$(expand_path "$OUTPUT_PATH")"

RESOLVED_ARCHIVES=()
for archive_path in "${ARCHIVE_PATHS[@]}"; do
    resolved="$(resolve_existing_path "$archive_path")"
    if [[ -z "$resolved" || ! -f "$resolved" ]]; then
        echo "error: archive not found: $archive_path" >&2
        exit 1
    fi
    RESOLVED_ARCHIVES+=("$resolved")
done

if [[ -n "$NOTES_FILE" ]]; then
    NOTES_FILE="$(resolve_existing_path "$NOTES_FILE")"
    if [[ -z "$NOTES_FILE" || ! -f "$NOTES_FILE" ]]; then
        echo "error: notes file not found" >&2
        exit 1
    fi
fi

if [[ -z "$REPO" ]]; then
    REPO="$(detect_repo)"
fi

if ! [[ "$REPO" =~ ^[^/]+/[^/]+$ ]]; then
    echo "error: invalid repo format: $REPO" >&2
    exit 1
fi

GENERATE_KEYS_TOOL="$(ensure_sparkle_tool generate_keys)"
GENERATE_APPCAST_TOOL="$(ensure_sparkle_tool generate_appcast)"

if ! "$GENERATE_KEYS_TOOL" --account "$ACCOUNT" -p >/dev/null 2>&1; then
    echo "error: Sparkle key is missing for account $ACCOUNT" >&2
    echo "run: $GENERATE_KEYS_TOOL --account $ACCOUNT" >&2
    exit 1
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/profilesmith-appcast.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

TMP_PRIVATE_KEY="$TMP_DIR/private_ed25519.key"
"$GENERATE_KEYS_TOOL" --account "$ACCOUNT" -x "$TMP_PRIVATE_KEY"

# 每个 DMG 单独放进一个目录生成条目：同版本号的多个归档放在一起时 generate_appcast 只会保留一个。
GENERATED_APPCASTS=()
index=0
for archive_path in "${RESOLVED_ARCHIVES[@]}"; do
    work_dir="$TMP_DIR/archive-$index"
    mkdir -p "$work_dir"
    cp "$archive_path" "$work_dir/"

    base_name="$(basename "${archive_path%.*}")"
    if [[ -n "$NOTES_FILE" ]]; then
        cp "$NOTES_FILE" "$work_dir/${base_name}.${NOTES_FILE##*.}"
    elif [[ -n "$NOTES" ]]; then
        printf '%s\n' "$NOTES" > "$work_dir/${base_name}.md"
    fi

    "$GENERATE_APPCAST_TOOL" \
        --account "$ACCOUNT" \
        --ed-key-file "$TMP_PRIVATE_KEY" \
        --embed-release-notes \
        --link "https://github.com/$REPO" \
        -o "$work_dir/appcast.xml" \
        "$work_dir"

    GENERATED_APPCASTS+=("$work_dir/appcast.xml")
    index=$((index + 1))
done

mkdir -p "$(dirname "$OUTPUT_PATH")"

/usr/bin/python3 "$SCRIPT_DIR/merge_appcast.py" "$OUTPUT_PATH" "$REPO" "$APP_NAME" "${GENERATED_APPCASTS[@]}"

echo "appcast written to $OUTPUT_PATH"
