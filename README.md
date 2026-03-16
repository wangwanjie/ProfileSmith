# ProfileSmith

ProfileSmith 是一个原生 macOS 描述文件管理器，用来索引、搜索、预览和维护 `.mobileprovision`、`.provisionprofile`，以及包含嵌入描述文件的 `.ipa`、`.xcarchive`、`.app`、`.appex`。

## 功能

- 扫描 `~/Library/MobileDevice/Provisioning Profiles` 和 `~/Library/Developer/Xcode/UserData/Provisioning Profiles`
- SQLite + GRDB 建索引，支持按名称、Bundle ID、Team、UUID、类型全文搜索
- 详情面板展示概要、Entitlements、证书摘要和原始 plist 结构
- 支持导入、导出、Finder 定位、移到废纸篓、彻底删除、文件名美化
- 内建 Finder Quick Look 扩展，可预览描述文件、IPA、XCArchive、App、App Extension
- 集成 Sparkle / GitHub Releases 更新检查，并可在偏好设置里配置检查策略

## 工程结构

- `ProfileSmith/`: 主应用代码
- `ProfileSmithQuickLookExtensions/`: Quick Look 预览与缩略图扩展
- `ProfileSmithTests/`: 单元测试
- `ProfileSmithUITests/`: UI 测试
- `scripts/`: DMG、GitHub Release、appcast 相关脚本
- `release-notes/`: 每个版本的发布说明

## 本地开发

要求：

- Xcode 17 或更新版本
- macOS 10.15 及以上

常用命令：

```bash
xcodebuild test \
  -project ProfileSmith.xcodeproj \
  -scheme ProfileSmith \
  -derivedDataPath /tmp/ProfileSmithDerivedData \
  -destination 'platform=macOS' \
  -only-testing:ProfileSmithTests \
  CODE_SIGNING_ALLOWED=NO
```

主工程使用本地依赖：

- `Vendor/GRDB.swift`
- `Vendor/SnapKit`
- `Vendor/Sparkle`

## 使用说明

1. 启动后左侧会自动显示已索引的描述文件。
2. 选中单个条目后，右侧可以查看概要、原始结构和 HTML 预览。
3. 拖入 `.mobileprovision` / `.provisionprofile` 会执行导入。
4. 拖入 `.ipa` / `.xcarchive` / `.app` / `.appex` 会打开预览窗口。
5. 通过“偏好设置…”可以切换更新策略：手动检查、每天自动检查、启动时检查。

## 发布

版本号来自：

- 主应用：`ProfileSmith.xcodeproj/project.pbxproj`
- Quick Look 扩展：`ProfileSmithQuickLookExtensions/ProfileSmithQuickLookExtensions.xcodeproj/project.pbxproj`

常用脚本：

- `./scripts/build_dmg.sh`
- `./scripts/publish_github_release.sh`
- `./scripts/generate_appcast.sh`

典型流程：

1. 更新 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`
2. 编写 `release-notes/vX.Y.md`
3. 构建并签名 DMG
4. 发布 GitHub Release
5. 生成并提交 `appcast.xml`

## 1.1 更新

- 修复美化文件名后的详情刷新异常
- 修正快速预览窗口总览页 UI
- 新增偏好设置中的更新策略配置
