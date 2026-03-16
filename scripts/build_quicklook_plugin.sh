#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLUGIN_ROOT="$PROJECT_ROOT/ProfileSmithQuickLookExtensions"
PLUGIN_PROJECT="$PLUGIN_ROOT/ProfileSmithQuickLookExtensions.xcodeproj"
BUILD_CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA_PATH="$PROJECT_ROOT/build/QuickLookDerivedData"
CACHE_ROOT="$PROJECT_ROOT/build/QuickLookArtifacts/$BUILD_CONFIGURATION"
PREVIEW_PRODUCT_NAME="ProfileSmithQuickLookPreview.appex"
THUMBNAIL_PRODUCT_NAME="ProfileSmithQuickLookThumbnail.appex"
PREVIEW_CACHE_PATH="$CACHE_ROOT/$PREVIEW_PRODUCT_NAME"
THUMBNAIL_CACHE_PATH="$CACHE_ROOT/$THUMBNAIL_PRODUCT_NAME"

if [[ "${SKIP_PROFILESMITH_QUICKLOOK_BUILD:-0}" == "1" ]]; then
    exit 0
fi

if [[ ! -f "$PLUGIN_PROJECT/project.pbxproj" ]]; then
    echo "error: Quick Look project not found: $PLUGIN_PROJECT" >&2
    exit 1
fi

if [[ -z "${TARGET_BUILD_DIR:-}" || -z "${UNLOCALIZED_RESOURCES_FOLDER_PATH:-}" ]]; then
    echo "error: TARGET_BUILD_DIR and UNLOCALIZED_RESOURCES_FOLDER_PATH are required" >&2
    exit 1
fi

mkdir -p "$CACHE_ROOT"

needs_rebuild=0
if [[ ! -d "$PREVIEW_CACHE_PATH" || ! -d "$THUMBNAIL_CACHE_PATH" ]]; then
    needs_rebuild=1
elif [[ "$SCRIPT_DIR/build_quicklook_plugin.sh" -nt "$PREVIEW_CACHE_PATH" || "$SCRIPT_DIR/build_quicklook_plugin.sh" -nt "$THUMBNAIL_CACHE_PATH" ]]; then
    needs_rebuild=1
elif find "$PLUGIN_ROOT" -type f \
    ! -path '*/project.xcworkspace/*' \
    ! -path '*/xcuserdata/*' \
    \( -newer "$PREVIEW_CACHE_PATH" -o -newer "$THUMBNAIL_CACHE_PATH" \) -print -quit | grep -q .; then
    needs_rebuild=1
fi

if [[ "$needs_rebuild" -eq 1 ]]; then
    rm -rf "$DERIVED_DATA_PATH" "$PREVIEW_CACHE_PATH" "$THUMBNAIL_CACHE_PATH"

    for scheme in ProfileSmithQuickLookPreview ProfileSmithQuickLookThumbnail; do
        echo "Building $scheme for $BUILD_CONFIGURATION"
        /usr/bin/env -i \
            HOME="$HOME" \
            PATH="$PATH" \
            TMPDIR="${TMPDIR:-/tmp}" \
            LANG="${LANG:-en_US.UTF-8}" \
            DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" \
            /usr/bin/xcodebuild \
            -project "$PLUGIN_PROJECT" \
            -scheme "$scheme" \
            -configuration "$BUILD_CONFIGURATION" \
            -destination "generic/platform=macOS" \
            -derivedDataPath "$DERIVED_DATA_PATH" \
            build
    done

    BUILT_PRODUCTS_DIR="$DERIVED_DATA_PATH/Build/Products/$BUILD_CONFIGURATION"
    BUILT_PREVIEW_PATH="$BUILT_PRODUCTS_DIR/$PREVIEW_PRODUCT_NAME"
    BUILT_THUMBNAIL_PATH="$BUILT_PRODUCTS_DIR/$THUMBNAIL_PRODUCT_NAME"

    if [[ ! -d "$BUILT_PREVIEW_PATH" ]]; then
        echo "error: built Quick Look preview extension not found: $BUILT_PREVIEW_PATH" >&2
        exit 1
    fi

    if [[ ! -d "$BUILT_THUMBNAIL_PATH" ]]; then
        echo "error: built Quick Look thumbnail extension not found: $BUILT_THUMBNAIL_PATH" >&2
        exit 1
    fi

    /bin/cp -R "$BUILT_PREVIEW_PATH" "$PREVIEW_CACHE_PATH"
    /bin/cp -R "$BUILT_THUMBNAIL_PATH" "$THUMBNAIL_CACHE_PATH"
fi

PLUGINS_OUTPUT_DIR="$TARGET_BUILD_DIR/${PLUGINS_FOLDER_PATH:-$CONTENTS_FOLDER_PATH/PlugIns}"
rm -rf "$PLUGINS_OUTPUT_DIR/$PREVIEW_PRODUCT_NAME" "$PLUGINS_OUTPUT_DIR/$THUMBNAIL_PRODUCT_NAME"
mkdir -p "$PLUGINS_OUTPUT_DIR"
/bin/cp -R "$PREVIEW_CACHE_PATH" "$PLUGINS_OUTPUT_DIR/$PREVIEW_PRODUCT_NAME"
/bin/cp -R "$THUMBNAIL_CACHE_PATH" "$PLUGINS_OUTPUT_DIR/$THUMBNAIL_PRODUCT_NAME"
