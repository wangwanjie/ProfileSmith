#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

CONFIGURATION="Release"
BUILD_DIR="$PROJECT_DIR/build"
DMG_OUTPUT_DIR="$BUILD_DIR/dmg"
KEYCHAIN_PROFILE="$DEFAULT_NOTARY_PROFILE"
DO_NOTARIZE=true
SIGNING_IDENTITY=""

generate_dmg_background() {
    local output_path="$1"

    /usr/bin/swift - "$output_path" <<'SWIFT'
import Cocoa
import Foundation

// 获取输出路径
guard CommandLine.arguments.count >= 2 else {
    fputs("Error: Missing output path\n", stderr)
    exit(1)
}
let outputPath = CommandLine.arguments[1]

// MARK: - BackgroundView Definition
class BackgroundView: NSView {
    private enum Constants {
        static let imageWidth: CGFloat = 620
        static let imageHeight: CGFloat = 360
        static let backgroundColor = NSColor(srgbRed: 0.95, green: 0.97, blue: 0.98, alpha: 1)
        static let topGradientColor = NSColor(srgbRed: 0.80, green: 0.90, blue: 0.95, alpha: 1)
        static let accentColor = NSColor(calibratedRed: 0.11, green: 0.43, blue: 0.63, alpha: 1)
        static let textColor = NSColor(srgbRed: 0.10, green: 0.17, blue: 0.24, alpha: 1)
        static let subtitleColor = NSColor(srgbRed: 0.28, green: 0.35, blue: 0.42, alpha: 1)
        static let panelFillColor = NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.94)
        static let panelStrokeColor = NSColor(srgbRed: 0.73, green: 0.83, blue: 0.90, alpha: 1)
        static let cornerRadius: CGFloat = 24
        static let panelCornerRadius: CGFloat = 26
        static let panelStrokeWidth: CGFloat = 2
        static let titleFont = NSFont(name: "Avenir Next Demi Bold", size: 26) ?? .systemFont(ofSize: 26, weight: .semibold)
        static let subtitleFont = NSFont(name: "Avenir Next Regular", size: 14) ?? .systemFont(ofSize: 14)
        static let titleText = "Drag ProfileSmith to Applications"
        static let subtitleText = "Install the native macOS inspector by dragging it onto the Applications shortcut"
    }

    override func draw(_ dirtyRect: NSRect) {
        // 背景
        let path = NSBezierPath(roundedRect: bounds, xRadius: Constants.cornerRadius, yRadius: Constants.cornerRadius)
        Constants.backgroundColor.setFill()
        path.fill()

        // 渐变头 (y=0 在底部)
        let headerRect = NSRect(x: 0, y: 250, width: bounds.width, height: 110)
        let gradient = NSGradient(starting: Constants.topGradientColor, ending: Constants.backgroundColor)!
        gradient.draw(in: headerRect, angle: -90)

        // 文字
        drawText(Constants.titleText, font: Constants.titleFont, color: Constants.textColor, in: NSRect(x: 60, y: 286, width: 500, height: 34))
        drawText(Constants.subtitleText, font: Constants.subtitleFont, color: Constants.subtitleColor, in: NSRect(x: 70, y: 242, width: 480, height: 24))

        // 面板
        drawPanel(NSRect(x: 58, y: 72, width: 192, height: 168))
        drawPanel(NSRect(x: 370, y: 72, width: 192, height: 168))

        // 箭头
        let arrowBody = NSBezierPath()
        arrowBody.move(to: NSPoint(x: 254, y: 156))
        arrowBody.line(to: NSPoint(x: 338, y: 156))
        Constants.accentColor.setStroke()
        arrowBody.lineWidth = 14
        arrowBody.stroke()

        let arrowHead = NSBezierPath()
        arrowHead.move(to: NSPoint(x: 326, y: 178))
        arrowHead.line(to: NSPoint(x: 364, y: 156))
        arrowHead.line(to: NSPoint(x: 326, y: 134))
        arrowHead.close()
        Constants.accentColor.setFill()
        arrowHead.fill()
    }

    private func drawPanel(_ rect: NSRect) {
        let path = NSBezierPath(roundedRect: rect, xRadius: Constants.panelCornerRadius, yRadius: Constants.panelCornerRadius)
        Constants.panelFillColor.setFill()
        path.fill()
        Constants.panelStrokeColor.setStroke()
        path.lineWidth = Constants.panelStrokeWidth
        path.stroke()
    }

    private func drawText(_ text: String, font: NSFont, color: NSColor, in rect: NSRect) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
        (text as NSString).draw(in: rect, withAttributes: attributes)
    }
}

// MARK: - Execution
let width = 620
let height = 360
let frame = NSRect(x: 0, y: 0, width: width, height: height)
let view = BackgroundView(frame: frame)

// 关键步骤：将 View 内容捕获为 Bitmap
guard let bitmapRep = view.bitmapImageRepForCachingDisplay(in: frame) else {
    fputs("Error: Could not create bitmap rep\n", stderr)
    exit(1)
}

// 强制进行绘制到 bitmap
view.cacheDisplay(in: frame, to: bitmapRep)

// 转换为 PNG 数据
guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
    fputs("Error: Could not generate PNG data\n", stderr)
    exit(1)
}

// 写入文件
do {
    try pngData.write(to: URL(fileURLWithPath: outputPath))
} catch {
    fputs("Error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
SWIFT
}

extract_sanitized_entitlements() {
    local source_path="$1"
    local output_path="$2"

    if ! /usr/bin/codesign -d --entitlements :- "$source_path" >"$output_path" 2>/dev/null; then
        rm -f "$output_path"
        return 1
    fi

    if ! grep -q "<plist" "$output_path"; then
        rm -f "$output_path"
        return 1
    fi

    /usr/libexec/PlistBuddy -c "Delete :com.apple.security.get-task-allow" "$output_path" >/dev/null 2>&1 || true
}

sign_nested_target() {
    local target_path="$1"
    local identity="$2"
    local entitlements_file

    entitlements_file="$(mktemp "${TMPDIR:-/tmp}/profilesmith-nested-entitlements.XXXXXX")"

    if extract_sanitized_entitlements "$target_path" "$entitlements_file"; then
        /usr/bin/codesign \
            --force \
            --sign "$identity" \
            --timestamp \
            --options runtime \
            --preserve-metadata=identifier \
            --entitlements "$entitlements_file" \
            "$target_path"
    else
        /usr/bin/codesign \
            --force \
            --sign "$identity" \
            --timestamp \
            --options runtime \
            --preserve-metadata=identifier \
            "$target_path"
    fi

    rm -f "$entitlements_file"
}

resign_for_distribution() {
    local app_path="$1"
    local identity="$2"
    local nested_bundle
    local file_path
    local entitlements_file

    entitlements_file="$(mktemp "${TMPDIR:-/tmp}/profilesmith-entitlements.XXXXXX")"
    if ! extract_sanitized_entitlements "$app_path" "$entitlements_file"; then
        rm -f "$entitlements_file"
        entitlements_file=""
    fi

    trap '[[ -n "${entitlements_file:-}" ]] && rm -f "$entitlements_file"' RETURN

    while IFS= read -r -d '' file_path; do
        if file "$file_path" | grep -q "Mach-O"; then
            sign_nested_target "$file_path" "$identity"
        fi
    done < <(find "$app_path" -type f -print0)

    while IFS= read -r nested_bundle; do
        [[ -n "$nested_bundle" ]] || continue
        sign_nested_target "$nested_bundle" "$identity"
    done < <(
        find "$app_path" -mindepth 2 \
            \( -name "*.app" -o -name "*.framework" -o -name "*.xpc" -o -name "*.appex" -o -name "*.bundle" \) \
            -print | /usr/bin/awk '{ print length, $0 }' | sort -rn | cut -d" " -f2-
    )

    if [[ -n "$entitlements_file" ]]; then
        /usr/bin/codesign \
            --force \
            --sign "$identity" \
            --timestamp \
            --options runtime \
            --entitlements "$entitlements_file" \
            "$app_path"
    else
        /usr/bin/codesign \
            --force \
            --sign "$identity" \
            --timestamp \
            --options runtime \
            "$app_path"
    fi
}

create_pretty_dmg() {
    local app_path="$1"
    local dmg_path="$2"
    local volume_name="$3"
    local work_dir="$BUILD_DIR/dmg-tmp"
    local staging_dir="$work_dir/staging"
    local background_dir="$staging_dir/.background"
    local background_path="$background_dir/installer-background.png"
    local fsevents_dir="$staging_dir/.fseventsd"
    local rw_dmg_path="$work_dir/${volume_name}.temp.dmg"
    local app_name
    local device
    local attach_output
    local mounted_volume_path
    local mounted_volume_name

    app_name="$(basename "$app_path")"

    rm -rf "$work_dir"
    mkdir -p "$staging_dir" "$background_dir" "$fsevents_dir"
    cp -R "$app_path" "$staging_dir/"
    ln -s /Applications "$staging_dir/Applications"
    generate_dmg_background "$background_path"
    touch "$fsevents_dir/no_log"
    chflags hidden "$background_dir" 2>/dev/null || true
    chflags hidden "$fsevents_dir" 2>/dev/null || true

    hdiutil create -volname "$volume_name" \
        -srcfolder "$staging_dir" \
        -fs HFS+ \
        -fsargs "-c c=64,a=16,e=16" \
        -ov -format UDRW \
        "$rw_dmg_path"

    attach_output="$(hdiutil attach -readwrite -noverify -noautoopen "$rw_dmg_path")"
    device="$(printf '%s\n' "$attach_output" | awk -F '\t' '/\/Volumes\// {print $1; exit}')"
    mounted_volume_path="$(printf '%s\n' "$attach_output" | awk -F '\t' '/\/Volumes\// {print $NF; exit}')"
    mounted_volume_name="$(basename "$mounted_volume_path")"

    if [[ -z "$device" || -z "$mounted_volume_name" ]]; then
        echo "error: failed to mount temporary DMG" >&2
        echo "$attach_output" >&2
        exit 1
    fi

    chflags hidden "$mounted_volume_path/.background" 2>/dev/null || true
    chflags hidden "$mounted_volume_path/.fseventsd" 2>/dev/null || true

    osascript <<EOF
tell application "Finder"
    tell disk "$mounted_volume_name"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {220, 120, 840, 520}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 96
        set text size of viewOptions to 13
        set background picture of viewOptions to file ".background:installer-background.png"
        set position of item "$app_name" of container window to {154, 186}
        set position of item "Applications" of container window to {466, 186}
        try
            set position of item ".background" of container window to {860, 320}
        end try
        try
            set position of item ".fseventsd" of container window to {960, 320}
        end try
        close
        open
        update without registering applications
        try
            set position of item ".background" of container window to {860, 320}
        end try
        try
            set position of item ".fseventsd" of container window to {960, 320}
        end try
        delay 1
        set bounds of container window to {220, 120, 830, 510}
        delay 1
        set bounds of container window to {220, 120, 840, 520}
        delay 2
    end tell
end tell
EOF

    sync
    sleep 1
    hdiutil detach "$mounted_volume_path" || hdiutil detach "$device" -force
    hdiutil convert "$rw_dmg_path" -format UDZO -imagekey zlib-level=9 -o "$dmg_path"
    rm -rf "$work_dir"
}

usage() {
    cat <<EOF
Usage:
  ./scripts/build_dmg.sh [--arch arm64|x86_64|all] [--keychain-profile PROFILE]
                         [--signing-identity IDENTITY] [--no-notarize]

Options:
  --arch ARCH                  要打包的架构，可重复指定；默认 all（arm64 与 x86_64 各出一个 DMG）
  --keychain-profile PROFILE   Notarytool keychain profile. Default: $DEFAULT_NOTARY_PROFILE
  --signing-identity IDENTITY  Developer ID Application identity to use
  --no-notarize                Skip notarization

Output:
  build/dmg/${APP_NAME}_V_<version>_arm64.dmg
  build/dmg/${APP_NAME}_V_<version>_x86_64.dmg
EOF
}

# 列出 app 包内所有 Mach-O 文件（主程序、框架、XPC 服务、辅助程序等）。
list_macho_files() {
    local app_path="$1"
    local file_path

    while IFS= read -r -d '' file_path; do
        if file "$file_path" | grep -q "Mach-O"; then
            printf '%s\n' "$file_path"
        fi
    done < <(find "$app_path" -type f -print0)
}

# Sparkle 等通过 SPM 引入的预编译框架是通用二进制，ARCHS 构建设置对它们不生效，这里统一裁剪为目标架构。
thin_bundle_to_arch() {
    local app_path="$1"
    local arch="$2"
    local macho_path
    local archs

    while IFS= read -r macho_path; do
        archs="$(lipo -archs "$macho_path")"
        if [[ "$archs" == "$arch" ]]; then
            continue
        fi
        if [[ " $archs " != *" $arch "* ]]; then
            echo "error: $macho_path does not contain $arch (has: $archs)" >&2
            exit 1
        fi
        lipo "$macho_path" -thin "$arch" -output "$macho_path.thin"
        # 保留原文件权限（可执行位），否则辅助程序与 XPC 服务无法启动。
        chmod "$(stat -f '%Lp' "$macho_path")" "$macho_path.thin"
        mv "$macho_path.thin" "$macho_path"
        echo "thinned ${macho_path#"$app_path"/} -> $arch"
    done < <(list_macho_files "$app_path")
}

# 校验包内所有 Mach-O 都只包含目标架构，防止误打出通用包或错误架构的包。
verify_binary_arch() {
    local app_path="$1"
    local expected_arch="$2"
    local macho_path
    local actual_archs

    while IFS= read -r macho_path; do
        actual_archs="$(lipo -archs "$macho_path")"
        if [[ "$actual_archs" != "$expected_arch" ]]; then
            echo "error: $macho_path contains [$actual_archs], expected [$expected_arch]" >&2
            exit 1
        fi
    done < <(list_macho_files "$app_path")
}

notarize_dmg() {
    local dmg_path="$1"
    local notary_output

    echo "submitting $(basename "$dmg_path") for notarization"
    notary_output="$(xcrun notarytool submit "$dmg_path" --keychain-profile "$KEYCHAIN_PROFILE" --wait 2>&1)" || true
    echo "$notary_output"

    if ! grep -q "status: Accepted" <<<"$notary_output"; then
        echo "error: notarization failed for $dmg_path" >&2
        exit 1
    fi

    xcrun stapler staple "$dmg_path"
    xcrun stapler validate "$dmg_path"
}

build_dmg_for_arch() {
    local arch="$1"
    # 每个架构使用独立的 DerivedData，避免两次构建互相清理产物。
    local derived_data="$BUILD_DIR/DerivedData-$arch"
    local app_path="$derived_data/Build/Products/$CONFIGURATION/${APP_NAME}.app"
    local dmg_path
    local volume_name="${APP_NAME} V$VERSION $arch"

    dmg_path="$DMG_OUTPUT_DIR/$(dmg_file_name "$VERSION" "$arch")"

    echo "building $APP_NAME $VERSION ($arch)"
    xcodebuild \
        "${MAIN_BUILD_ARGS[@]}" \
        -configuration "$CONFIGURATION" \
        -derivedDataPath "$derived_data" \
        -destination "generic/platform=macOS" \
        ARCHS="$arch" \
        ONLY_ACTIVE_ARCH=NO \
        clean \
        build

    if [[ ! -d "$app_path" ]]; then
        echo "error: app bundle not found: $app_path" >&2
        exit 1
    fi
    thin_bundle_to_arch "$app_path" "$arch"
    verify_binary_arch "$app_path" "$arch"

    echo "re-signing $arch app with $SIGNING_IDENTITY"
    resign_for_distribution "$app_path" "$SIGNING_IDENTITY"
    verify_developer_id_signature "$app_path" "$APP_NAME.app ($arch)"
    codesign --verify --deep --strict --verbose=2 "$app_path"

    rm -f "$dmg_path"
    echo "creating DMG: $dmg_path"
    create_pretty_dmg "$app_path" "$dmg_path" "$volume_name"
    codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$dmg_path"
    codesign --verify --strict --verbose=2 "$dmg_path"

    if [[ "$DO_NOTARIZE" == true ]]; then
        notarize_dmg "$dmg_path"
    else
        echo "skipping notarization for $arch"
    fi

    BUILT_DMGS+=("$dmg_path")
}

REQUESTED_ARCHS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --arch)
            if [[ "${2:-}" == "all" ]]; then
                REQUESTED_ARCHS+=("${SUPPORTED_ARCHS[@]}")
            elif is_supported_arch "${2:-}"; then
                REQUESTED_ARCHS+=("$2")
            else
                echo "error: unsupported arch: ${2:-}" >&2
                usage >&2
                exit 1
            fi
            shift 2
            ;;
        --keychain-profile)
            KEYCHAIN_PROFILE="${2:-}"
            shift 2
            ;;
        --signing-identity)
            SIGNING_IDENTITY="${2:-}"
            shift 2
            ;;
        --no-notarize)
            DO_NOTARIZE=false
            shift
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

if [[ ${#REQUESTED_ARCHS[@]} -eq 0 ]]; then
    REQUESTED_ARCHS=("${SUPPORTED_ARCHS[@]}")
fi

require_command xcodebuild
require_command codesign
require_command hdiutil
require_command osascript
require_command xcrun
require_command lipo

VERSION="$(read_marketing_version)"
if [[ -z "$VERSION" ]]; then
    echo "error: failed to read MARKETING_VERSION from $MAIN_PBXPROJ" >&2
    exit 1
fi

if [[ -z "$SIGNING_IDENTITY" ]]; then
    SIGNING_IDENTITY="$(find_developer_id_identity || true)"
fi

if [[ -z "$SIGNING_IDENTITY" ]]; then
    echo "error: failed to find a Developer ID Application identity" >&2
    exit 1
fi

MAIN_BUILD_ARGS=()
while IFS= read -r arg; do
    MAIN_BUILD_ARGS+=("$arg")
done < <(main_build_xcodebuild_args)

mkdir -p "$DMG_OUTPUT_DIR"

BUILT_DMGS=()
# 去重后依次构建，避免重复传入同一架构。
SEEN_ARCHS=" "
for arch in "${REQUESTED_ARCHS[@]}"; do
    if [[ "$SEEN_ARCHS" == *" $arch "* ]]; then
        continue
    fi
    SEEN_ARCHS+="$arch "
    build_dmg_for_arch "$arch"
done

echo "done:"
printf '  %s\n' "${BUILT_DMGS[@]}"
