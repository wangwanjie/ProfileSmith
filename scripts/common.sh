#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="ProfileSmith"
SCHEME="ProfileSmith"
MAIN_PROJECT="$PROJECT_DIR/ProfileSmith.xcodeproj"
MAIN_WORKSPACE="$PROJECT_DIR/ProfileSmith.xcworkspace"
MAIN_PBXPROJ="$MAIN_PROJECT/project.pbxproj"
INFO_PLIST="$PROJECT_DIR/ProfileSmith-Info.plist"
SPARKLE_PROJECT="$PROJECT_DIR/Vendor/Sparkle/Sparkle.xcodeproj"
SPARKLE_DERIVED_DATA="$PROJECT_DIR/build/SparkleTools"
SPARKLE_BIN_DIR="$SPARKLE_DERIVED_DATA/Build/Products/Release"
DEFAULT_REPO="wangwanjie/ProfileSmith"
DEFAULT_SPARKLE_ACCOUNT="cn.vanjay.ProfileSmith.sparkle"
DEFAULT_NOTARY_PROFILE="vanjay_mac_stapler"

# 分发支持的 CPU 架构：Apple 芯片（arm64）与 Intel（x86_64）分别打包，减小下载体积。
SUPPORTED_ARCHS=(arm64 x86_64)

is_supported_arch() {
    local candidate="$1"
    local arch
    for arch in "${SUPPORTED_ARCHS[@]}"; do
        if [[ "$arch" == "$candidate" ]]; then
            return 0
        fi
    done
    return 1
}

# DMG 命名约定：ProfileSmith_V_<版本>_<架构>.dmg
dmg_file_name() {
    local version="$1"
    local arch="$2"
    printf '%s_V_%s_%s.dmg\n' "$APP_NAME" "$version" "$arch"
}

# 从 DMG 文件名解析出架构；旧版通用包（无架构后缀）输出 universal。
arch_from_dmg_name() {
    local dmg_name
    dmg_name="$(basename "$1")"

    if [[ "$dmg_name" =~ ^${APP_NAME}_V_.+_(arm64|x86_64)\.dmg$ ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
    else
        printf 'universal\n'
    fi
}

# 从 DMG 文件名解析出版本号，兼容带架构后缀与不带后缀两种命名。
version_from_dmg_name() {
    local dmg_name
    dmg_name="$(basename "$1")"

    if [[ "$dmg_name" =~ ^${APP_NAME}_V_(.+)_(arm64|x86_64)\.dmg$ ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
        return 0
    fi

    if [[ "$dmg_name" =~ ^${APP_NAME}_V_(.+)\.dmg$ ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
        return 0
    fi

    return 1
}

main_build_xcodebuild_args() {
    if [[ -d "$MAIN_WORKSPACE" ]]; then
        printf '%s\n' "-workspace" "$MAIN_WORKSPACE" "-scheme" "$SCHEME"
    else
        printf '%s\n' "-project" "$MAIN_PROJECT" "-scheme" "$SCHEME"
    fi
}

require_command() {
    local command_name="$1"
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "error: missing command: $command_name" >&2
        exit 1
    fi
}

expand_path() {
    local input_path="$1"
    local candidate="${input_path/#\~/$HOME}"

    if [[ "$candidate" = /* ]]; then
        printf '%s\n' "$candidate"
    else
        printf '%s\n' "$PROJECT_DIR/$candidate"
    fi
}

resolve_existing_path() {
    local candidate
    candidate="$(expand_path "$1")"

    if [[ -e "$candidate" ]]; then
        printf '%s\n' "$candidate"
    fi
}

read_pbxproj_setting() {
    local key="$1"
    if [[ ! -f "$MAIN_PBXPROJ" ]]; then
        return 1
    fi

    grep -m1 "$key" "$MAIN_PBXPROJ" | sed "s/.*$key = \\([^;]*\\);/\\1/" | tr -d ' '
}

read_marketing_version() {
    read_pbxproj_setting "MARKETING_VERSION"
}

read_build_number() {
    read_pbxproj_setting "CURRENT_PROJECT_VERSION"
}

read_development_team() {
    read_pbxproj_setting "DEVELOPMENT_TEAM"
}

read_plist_string() {
    local key="$1"
    /usr/libexec/PlistBuddy -c "Print :$key" "$INFO_PLIST" 2>/dev/null || true
}

extract_github_repo_from_url() {
    local url="$1"

    if [[ "$url" =~ ^https://github\.com/([^/]+)/([^/]+)(\.git)?/?$ ]]; then
        printf '%s/%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]%.git}"
        return 0
    fi

    if [[ "$url" =~ ^git@github\.com:([^/]+)/([^/]+)(\.git)?$ ]]; then
        printf '%s/%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]%.git}"
        return 0
    fi

    if [[ "$url" =~ ^ssh://git@github\.com/([^/]+)/([^/]+)(\.git)?$ ]]; then
        printf '%s/%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]%.git}"
        return 0
    fi

    return 1
}

detect_repo() {
    local repo_url

    repo_url="$(read_plist_string "ProfileSmithGitHubURL")"
    if [[ -n "$repo_url" ]]; then
        extract_github_repo_from_url "$repo_url" && return 0
    fi

    if repo_url="$(git remote get-url origin 2>/dev/null)"; then
        extract_github_repo_from_url "$repo_url" && return 0
    fi

    while IFS=$'\t' read -r _remote_name candidate_url; do
        extract_github_repo_from_url "$candidate_url" && return 0
    done < <(git remote -v | awk '$3=="(push)" {print $1 "\t" $2}' | awk '!seen[$1]++')

    printf '%s\n' "$DEFAULT_REPO"
}

ensure_sparkle_tool() {
    local tool_name="$1"
    local tool_path="$SPARKLE_BIN_DIR/$tool_name"

    if [[ -x "$tool_path" ]]; then
        printf '%s\n' "$tool_path"
        return 0
    fi

    require_command xcodebuild
    mkdir -p "$PROJECT_DIR/build"

    echo "building Sparkle tool: $tool_name" >&2
    # Sparkle 工程默认部署目标为 10.13，新版 Xcode 已不支持，这些工具只在本机运行，统一提升到 12.0。
    xcodebuild \
        -project "$SPARKLE_PROJECT" \
        -scheme "$tool_name" \
        -configuration Release \
        -derivedDataPath "$SPARKLE_DERIVED_DATA" \
        MACOSX_DEPLOYMENT_TARGET=12.0 \
        CODE_SIGNING_ALLOWED=NO \
        build >&2

    if [[ ! -x "$tool_path" ]]; then
        echo "error: Sparkle tool not found after build: $tool_path" >&2
        exit 1
    fi

    printf '%s\n' "$tool_path"
}

find_developer_id_identity() {
    local team_id
    local identities
    local matching_identity

    team_id="$(read_development_team)"
    identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"

    if [[ -n "$team_id" ]]; then
        matching_identity="$(printf '%s\n' "$identities" | sed -n "s/.*\"\\(Developer ID Application:.*(${team_id})\\)\"/\\1/p" | head -1)"
        if [[ -n "$matching_identity" ]]; then
            printf '%s\n' "$matching_identity"
            return 0
        fi
    fi

    matching_identity="$(printf '%s\n' "$identities" | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' | head -1)"
    if [[ -n "$matching_identity" ]]; then
        printf '%s\n' "$matching_identity"
        return 0
    fi

    return 1
}

verify_developer_id_signature() {
    local target_path="$1"
    local target_name="$2"
    local sign_info

    sign_info="$(codesign -dv --verbose=4 "$target_path" 2>&1)"

    if ! grep -q "Authority=Developer ID Application" <<<"$sign_info"; then
        echo "error: $target_name is not signed with Developer ID Application" >&2
        echo "$sign_info" >&2
        exit 1
    fi

    if ! grep -q "Timestamp=" <<<"$sign_info"; then
        echo "error: $target_name signature is missing a secure timestamp" >&2
        echo "$sign_info" >&2
        exit 1
    fi
}
