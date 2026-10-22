#!/usr/bin/env python3
"""把 generate_appcast 生成的新条目合并进 appcast.xml。

用法：merge_appcast.py <输出 appcast.xml> <owner/repo> <AppName> <生成的 appcast.xml>...

规则：
- enclosure 指向 GitHub Release 下载地址；
- arm64 条目添加 sparkle:hardwareRequirements=arm64，并排在同版本 x86_64 条目之前；
- 已存在的同版本条目被替换，其余历史条目保持不变。
"""
import os
import pathlib
import re
import sys
import urllib.parse
import xml.etree.ElementTree as ET

output_path, repo, app_name = sys.argv[1:4]
generated_paths = sys.argv[4:]

SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"
DC_NS = "http://purl.org/dc/elements/1.1/"
ET.register_namespace("sparkle", SPARKLE_NS)
ET.register_namespace("dc", DC_NS)

def sparkle(tag):
    return f"{{{SPARKLE_NS}}}{tag}"

def find_or_create(parent, tag):
    node = parent.find(tag)
    if node is None:
        node = ET.SubElement(parent, tag)
    return node

dmg_pattern = re.compile(rf"^{re.escape(app_name)}_V_(.+?)(?:_(arm64|x86_64))?\.dmg$")
# 同版本条目的排列顺序：arm64 必须排在最前面（见脚本开头说明）。
arch_order = {"arm64": 0, "universal": 1, "x86_64": 2}

def normalize_item(item):
    enclosure = item.find("enclosure")
    if enclosure is None:
        raise SystemExit("generated item is missing enclosure")

    raw_url = enclosure.attrib.get("url", "")
    filename = pathlib.PurePosixPath(urllib.parse.urlparse(raw_url).path).name or pathlib.Path(raw_url).name
    match = dmg_pattern.match(filename)
    if not match:
        raise SystemExit(f"unexpected archive name: {filename}")

    version = match.group(1).lstrip("vV")
    arch = match.group(2) or "universal"
    tag = f"v{version}"
    quoted_tag = urllib.parse.quote(tag, safe="")
    enclosure.set("url", f"https://github.com/{repo}/releases/download/{quoted_tag}/{urllib.parse.quote(filename, safe='')}")
    find_or_create(item, "link").text = f"https://github.com/{repo}/releases/tag/{quoted_tag}"

    for tag_name in ("releaseNotesLink", "fullReleaseNotesLink"):
        node = item.find(sparkle(tag_name))
        if node is not None:
            item.remove(node)

    hardware = item.find(sparkle("hardwareRequirements"))
    if arch == "arm64":
        if hardware is None:
            hardware = ET.SubElement(item, sparkle("hardwareRequirements"))
        hardware.text = "arm64"
    elif hardware is not None:
        item.remove(hardware)

    short_version = item.find(sparkle("shortVersionString"))
    item_version = (short_version.text or "").strip() if short_version is not None else version
    return item_version, arch

new_items = []
for path in generated_paths:
    channel = ET.parse(path).getroot().find("channel")
    if channel is None:
        raise SystemExit(f"missing channel in {path}")
    for item in channel.findall("item"):
        version, arch = normalize_item(item)
        new_items.append((version, arch, item))

if not new_items:
    raise SystemExit("generate_appcast produced no items")

new_versions = {version for version, _, _ in new_items}
new_items.sort(key=lambda entry: arch_order.get(entry[1], 99))

if os.path.exists(output_path):
    tree = ET.parse(output_path)
    root = tree.getroot()
else:
    root = ET.Element("rss", {"version": "2.0"})
    tree = ET.ElementTree(root)

channel = root.find("channel")
if channel is None:
    channel = ET.SubElement(root, "channel")

title_node = find_or_create(channel, "title")
if not (title_node.text or "").strip():
    title_node.text = app_name

# 重新发布同一版本时替换旧条目，其余历史版本保持不变。
for item in list(channel.findall("item")):
    short_version = item.find(sparkle("shortVersionString"))
    if short_version is not None and (short_version.text or "").strip() in new_versions:
        channel.remove(item)

children = list(channel)
first_item_index = next((i for i, child in enumerate(children) if child.tag == "item"), len(children))
for offset, (_, _, item) in enumerate(new_items):
    channel.insert(first_item_index + offset, item)

ET.indent(tree, space="    ")
tree.write(output_path, encoding="utf-8", xml_declaration=True)
for version, arch, _ in new_items:
    print(f"appcast item: {version} ({arch})")
