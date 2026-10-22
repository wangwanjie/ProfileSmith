#!/usr/bin/env bash

# 验证 merge_appcast.py：新版本按架构生成两个条目、arm64 排在前面并带硬件要求，历史条目保持不变。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/merge-appcast-test.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

write_generated() {
    local path="$1"
    local file_name="$2"
    cat > "$path" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
    <channel>
        <title>ProfileSmith</title>
        <item>
            <title>1.5.0</title>
            <sparkle:version>12</sparkle:version>
            <sparkle:shortVersionString>1.5.0</sparkle:shortVersionString>
            <sparkle:releaseNotesLink>https://example.com/notes.html</sparkle:releaseNotesLink>
            <enclosure url="https://github.com/wangwanjie/ProfileSmith/$file_name" length="1" type="application/octet-stream" sparkle:edSignature="sig" />
        </item>
    </channel>
</rss>
EOF
}

cat > "$WORK_DIR/appcast.xml" <<'EOF'
<?xml version='1.0' encoding='utf-8'?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
    <channel>
        <title>ProfileSmith</title>
        <item>
            <title>1.5.0</title>
            <sparkle:shortVersionString>1.5.0</sparkle:shortVersionString>
            <enclosure url="https://example.com/stale.dmg" length="1" type="application/octet-stream" />
        </item>
        <item>
            <title>1.4.3</title>
            <sparkle:version>11</sparkle:version>
            <sparkle:shortVersionString>1.4.3</sparkle:shortVersionString>
            <enclosure url="https://github.com/wangwanjie/ProfileSmith/releases/download/v1.4.3/ProfileSmith_V_1.4.3.dmg" length="1" type="application/octet-stream" />
        </item>
    </channel>
</rss>
EOF

# 故意先传 x86_64，验证输出顺序与传入顺序无关。
write_generated "$WORK_DIR/x86.xml" "ProfileSmith_V_1.5.0_x86_64.dmg"
write_generated "$WORK_DIR/arm.xml" "ProfileSmith_V_1.5.0_arm64.dmg"

/usr/bin/python3 "$PROJECT_DIR/scripts/merge_appcast.py" \
    "$WORK_DIR/appcast.xml" wangwanjie/ProfileSmith ProfileSmith \
    "$WORK_DIR/x86.xml" "$WORK_DIR/arm.xml" >/dev/null

/usr/bin/python3 - "$WORK_DIR/appcast.xml" <<'PY' || fail "merged appcast has unexpected structure"
import sys
import xml.etree.ElementTree as ET

ns = {"sparkle": "http://www.andymatuschak.org/xml-namespaces/sparkle"}
items = ET.parse(sys.argv[1]).getroot().find("channel").findall("item")
urls = [item.find("enclosure").get("url") for item in items]

expected = [
    "https://github.com/wangwanjie/ProfileSmith/releases/download/v1.5.0/ProfileSmith_V_1.5.0_arm64.dmg",
    "https://github.com/wangwanjie/ProfileSmith/releases/download/v1.5.0/ProfileSmith_V_1.5.0_x86_64.dmg",
    "https://github.com/wangwanjie/ProfileSmith/releases/download/v1.4.3/ProfileSmith_V_1.4.3.dmg",
]
assert urls == expected, urls

arm, intel, legacy = items
assert arm.find("sparkle:hardwareRequirements", ns).text == "arm64"
assert intel.find("sparkle:hardwareRequirements", ns) is None
assert legacy.find("sparkle:hardwareRequirements", ns) is None
assert arm.find("sparkle:releaseNotesLink", ns) is None
assert arm.find("link").text == "https://github.com/wangwanjie/ProfileSmith/releases/tag/v1.5.0"
PY

printf 'PASS: merge_appcast orders arm64 first and keeps history\n'
