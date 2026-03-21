# ProfileSmith Language and Appearance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add runtime language switching and runtime appearance switching to ProfileSmith, covering the main app, app menu, status bar menu, update alerts, and Quick Look resources while keeping Quick Look on system language and system appearance.

**Architecture:** Introduce centralized runtime state for localization and appearance through `AppLocalization`, `L10n`, `AppAppearance`, and `AppearanceManager`, with `AppSettings` persisting the user’s selections and applying them at launch. App UI controllers subscribe to localization changes and refresh static text in place, while the app menu and status item rebuild from current state when needed.

**Tech Stack:** Swift, AppKit, Combine, Quick Look extensions, XCTest-style `Testing`, SnapKit

---

### Task 1: Add failing tests for settings persistence and localization helpers

**Files:**
- Create: `ProfileSmithTests/LocalizationTests.swift`
- Modify: `ProfileSmithTests/AppSettingsTests.swift`

- [ ] **Step 1: Write the failing tests**

Add tests that cover:

- `AppSettings` persists `appLanguage`
- `AppSettings` persists `appAppearance`
- supported language resolution prefers `zh-Hans`, `zh-Hant`, and `en`
- unsupported language identifiers fall back correctly

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project ProfileSmith.xcodeproj -scheme ProfileSmith -destination platform=macOS -derivedDataPath /tmp/profilesmith-deriveddata CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= -only-testing:ProfileSmithTests/AppSettingsTests -only-testing:ProfileSmithTests/LocalizationTests`

Expected: FAIL because the new types and settings do not exist yet.

- [ ] **Step 3: Write the minimal implementation**

Create:

- `ProfileSmith/Localization/AppLanguage.swift`
- `ProfileSmith/Appearance/AppAppearance.swift`

Extend:

- `ProfileSmith/Services/AppSettings.swift`

Implement just enough for the new tests to pass.

- [ ] **Step 4: Run tests to verify they pass**

Run the same command from Step 2.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ProfileSmith/Localization/AppLanguage.swift ProfileSmith/Appearance/AppAppearance.swift ProfileSmith/Services/AppSettings.swift ProfileSmithTests/AppSettingsTests.swift ProfileSmithTests/LocalizationTests.swift
git commit -m "Add persisted language and appearance settings"
```

### Task 2: Add failing tests for runtime managers

**Files:**
- Create: `ProfileSmithTests/AppLocalizationTests.swift`
- Create: `ProfileSmithTests/AppearanceManagerTests.swift`

- [ ] **Step 1: Write the failing tests**

Add tests that cover:

- `AppLocalization` switches bundles when language changes
- formatted localized strings use the selected locale
- `AppearanceManager` maps `system`, `light`, and `dark` to the expected `NSAppearance` behavior

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project ProfileSmith.xcodeproj -scheme ProfileSmith -destination platform=macOS -derivedDataPath /tmp/profilesmith-deriveddata CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= -only-testing:ProfileSmithTests/AppLocalizationTests -only-testing:ProfileSmithTests/AppearanceManagerTests`

Expected: FAIL because the runtime managers do not exist yet.

- [ ] **Step 3: Write the minimal implementation**

Create:

- `ProfileSmith/Localization/AppLocalization.swift`
- `ProfileSmith/Localization/L10n.swift`
- `ProfileSmith/Appearance/AppearanceManager.swift`

Add `Localizable.strings` for:

- `ProfileSmith/en.lproj/Localizable.strings`
- `ProfileSmith/zh-Hans.lproj/Localizable.strings`
- `ProfileSmith/zh-Hant.lproj/Localizable.strings`

- [ ] **Step 4: Run tests to verify they pass**

Run the same command from Step 2.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ProfileSmith/Localization/AppLocalization.swift ProfileSmith/Localization/L10n.swift ProfileSmith/Appearance/AppearanceManager.swift ProfileSmith/en.lproj/Localizable.strings ProfileSmith/zh-Hans.lproj/Localizable.strings ProfileSmith/zh-Hant.lproj/Localizable.strings ProfileSmithTests/AppLocalizationTests.swift ProfileSmithTests/AppearanceManagerTests.swift
git commit -m "Add runtime localization and appearance infrastructure"
```

### Task 3: Add failing tests for preferences and application wiring

**Files:**
- Modify: `ProfileSmith/AppDelegate.swift`
- Modify: `ProfileSmith/ApplicationMain.swift`
- Modify: `ProfileSmith/App/AppContext.swift`
- Modify: `ProfileSmith/UI/ViewControllers/PreferencesWindowController.swift`
- Modify: `ProfileSmithTests/AppLaunchRegressionTests.swift`
- Modify: `ProfileSmithTests/AppSettingsTests.swift`

- [ ] **Step 1: Write the failing tests**

Add tests that cover:

- launch applies persisted language before first UI is created
- launch applies persisted appearance before first UI is created
- preferences expose language and appearance options through settings-bound controls

- [ ] **Step 2: Run tests to verify they fail**

Run a focused `xcodebuild test` command that targets the updated tests.

Expected: FAIL because the app launch and preferences wiring do not yet use the new managers.

- [ ] **Step 3: Write the minimal implementation**

Update:

- `ProfileSmith/Services/AppSettings.swift`
- `ProfileSmith/AppDelegate.swift`
- `ProfileSmith/ApplicationMain.swift`
- `ProfileSmith/App/AppContext.swift`
- `ProfileSmith/UI/ViewControllers/PreferencesWindowController.swift`

Implement:

- launch-time application of language and appearance
- preferences controls for language and appearance
- immediate persistence and propagation

- [ ] **Step 4: Run tests to verify they pass**

Run the same focused test command from Step 2.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ProfileSmith/Services/AppSettings.swift ProfileSmith/AppDelegate.swift ProfileSmith/ApplicationMain.swift ProfileSmith/App/AppContext.swift ProfileSmith/UI/ViewControllers/PreferencesWindowController.swift ProfileSmithTests/AppLaunchRegressionTests.swift ProfileSmithTests/AppSettingsTests.swift
git commit -m "Wire runtime language and appearance settings into launch and preferences"
```

### Task 4: Add failing tests for UI refresh behavior

**Files:**
- Modify: `ProfileSmith/UI/Components/StatusItemController.swift`
- Modify: `ProfileSmith/UI/ViewControllers/MainViewController.swift`
- Modify: `ProfileSmith/UI/ViewControllers/PreviewWindowController.swift`
- Modify: `ProfileSmith/Services/UpdateManager.swift`
- Modify: `ProfileSmithTests/MainViewControllerTests.swift`

- [ ] **Step 1: Write the failing tests**

Add tests that cover:

- localized strings update after language changes in `MainViewController`
- status item menu rebuilds with localized strings
- update alerts source their copy from localization helpers

- [ ] **Step 2: Run tests to verify they fail**

Run a focused `xcodebuild test` command that targets the updated UI tests.

Expected: FAIL because the controllers still use hardcoded strings.

- [ ] **Step 3: Write the minimal implementation**

Replace hardcoded strings with `L10n` in:

- `ProfileSmith/AppDelegate.swift`
- `ProfileSmith/UI/Components/StatusItemController.swift`
- `ProfileSmith/UI/ViewControllers/MainViewController.swift`
- `ProfileSmith/UI/ViewControllers/PreviewWindowController.swift`
- `ProfileSmith/Services/UpdateManager.swift`

Add:

- controller localization refresh hooks
- app menu rebuild on language changes
- status menu rebuild on language changes

- [ ] **Step 4: Run tests to verify they pass**

Run the same focused UI test command from Step 2.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ProfileSmith/AppDelegate.swift ProfileSmith/UI/Components/StatusItemController.swift ProfileSmith/UI/ViewControllers/MainViewController.swift ProfileSmith/UI/ViewControllers/PreviewWindowController.swift ProfileSmith/Services/UpdateManager.swift ProfileSmithTests/MainViewControllerTests.swift
git commit -m "Localize app UI and refresh menus at runtime"
```

### Task 5: Add failing tests for Quick Look localization resources

**Files:**
- Modify: `ProfileSmithQuickLookExtensions/Shared/QuickLookInspection.swift`
- Modify: `ProfileSmithQuickLookExtensions/Preview/PreviewProvider.swift`
- Modify: `ProfileSmithQuickLookExtensions/Thumbnail/ThumbnailProvider.swift`
- Modify: `ProfileSmithQuickLookExtensions/ProfileSmithQuickLookExtensions.xcodeproj/project.pbxproj`
- Create: `ProfileSmithQuickLookExtensions/Shared/QuickLookLocalization.swift`
- Create: `ProfileSmithTests/QuickLookLocalizationTests.swift`

- [ ] **Step 1: Write the failing tests**

Add tests that cover:

- Quick Look localization resolves from preferred system languages
- Quick Look text generation no longer depends on hardcoded Chinese

- [ ] **Step 2: Run tests to verify they fail**

Run a focused `xcodebuild test` command that targets the Quick Look localization tests.

Expected: FAIL because the Quick Look shared layer is still hardcoded.

- [ ] **Step 3: Write the minimal implementation**

Add extension-safe localization helpers and update Quick Look shared code to use them. Include `.lproj` resources in the extension targets.

- [ ] **Step 4: Run tests to verify they pass**

Run the same focused test command from Step 2.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ProfileSmithQuickLookExtensions/Shared/QuickLookLocalization.swift ProfileSmithQuickLookExtensions/Shared/QuickLookInspection.swift ProfileSmithQuickLookExtensions/Preview/PreviewProvider.swift ProfileSmithQuickLookExtensions/Thumbnail/ThumbnailProvider.swift ProfileSmithQuickLookExtensions/ProfileSmithQuickLookExtensions.xcodeproj/project.pbxproj ProfileSmithTests/QuickLookLocalizationTests.swift
git commit -m "Localize Quick Look resources with system language fallback"
```

### Task 6: Final verification

**Files:**
- Verify only

- [ ] **Step 1: Run the focused feature test suite**

Run:

`xcodebuild test -project ProfileSmith.xcodeproj -scheme ProfileSmith -destination platform=macOS -derivedDataPath /tmp/profilesmith-deriveddata CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= -only-testing:ProfileSmithTests/AppSettingsTests -only-testing:ProfileSmithTests/LocalizationTests -only-testing:ProfileSmithTests/AppLocalizationTests -only-testing:ProfileSmithTests/AppearanceManagerTests -only-testing:ProfileSmithTests/MainViewControllerTests -only-testing:ProfileSmithTests/QuickLookLocalizationTests`

Expected: PASS.

- [ ] **Step 2: Run an app build verification**

Run:

`xcodebuild build -project ProfileSmith.xcodeproj -scheme ProfileSmith -destination platform=macOS -derivedDataPath /tmp/profilesmith-deriveddata CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=`

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Review git diff and ensure only scoped files changed**

Run:

`git status --short`

Expected: only files related to runtime language and appearance support remain changed.
