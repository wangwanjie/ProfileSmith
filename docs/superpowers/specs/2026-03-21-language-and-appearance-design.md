# ProfileSmith Dynamic Language and Appearance Design

Date: 2026-03-21

## Goal

Add runtime language switching and runtime appearance switching to ProfileSmith.

The supported languages are:

- English
- Simplified Chinese
- Traditional Chinese

The supported appearance modes are:

- Follow System
- Light
- Dark

The feature must cover:

- Main app UI
- App menu
- Status bar menu
- Update alerts
- Quick Look preview and thumbnail extensions

Quick Look extensions do not need to follow the app's manually selected language or appearance. They should continue to follow system language and system appearance.

## Confirmed Scope

### In Scope

- Persist the selected app language in user defaults
- Persist the selected app appearance in user defaults
- Apply language changes immediately in the main app without restart
- Apply appearance changes immediately in the main app without restart
- Add language and appearance controls to Preferences
- Localize the main app UI strings that participate in this flow
- Localize Quick Look extension strings using the same translation resources
- Keep Quick Look on system language and system appearance

### Out of Scope

- App Group or shared settings between the app and Quick Look extensions
- Forcing Quick Look to mirror the app's selected language
- Forcing Quick Look to mirror the app's selected appearance
- Refactoring unrelated business logic
- Reworking existing layout or visual design beyond what is needed for the new controls

## Design Summary

Use a centralized localization layer and a centralized appearance layer.

- `AppSettings` remains the persistence entry point for user-facing preferences
- `AppLocalization` becomes the single source of truth for current app language
- `AppearanceManager` becomes the single source of truth for current app appearance
- `L10n` becomes the typed access layer for localized strings

This avoids scattered per-controller state and keeps future UI additions on the same path.

## Architecture

### `AppLanguage`

Add a language enum with:

- `english = "en"`
- `simplifiedChinese = "zh-Hans"`
- `traditionalChinese = "zh-Hant"`

Responsibilities:

- Resolve persisted identifiers into supported languages
- Resolve `Locale.preferredLanguages` into the closest supported language
- Provide locale information for string formatting

### `AppAppearance`

Add an appearance enum with:

- `system`
- `light`
- `dark`

Responsibilities:

- Represent the user preference
- Map to the correct `NSAppearance` behavior

### `AppLocalization`

Add a shared localization manager that:

- Stores the current `AppLanguage`
- Resolves the correct localized bundle for the app
- Returns localized strings by key
- Formats parameterized strings using the active locale
- Exposes a lightweight background-safe string lookup for non-UI call sites when needed

`AppLocalization` is the only runtime language source used by the main app.

### `L10n`

Add a typed localization wrapper around string keys.

Responsibilities:

- Hold typed accessors for all strings used by the app menu, main window, preferences, status item, update alerts, and Quick Look UI
- Hold formatting helpers for dynamic strings with arguments

This is intentionally explicit. The point is to replace hardcoded Chinese strings with a single typed entry layer.

### `AppearanceManager`

Add a shared appearance manager that:

- Receives `AppAppearance`
- Applies it to `NSApp.appearance`
- Uses:
  - `nil` for system
  - `.aqua` for light
  - `.darkAqua` for dark

No controller should own its own appearance state.

### `AppSettings`

Extend the existing settings object with:

- `appLanguage`
- `appAppearance`
- existing `updateCheckStrategy`

Responsibilities:

- Load persisted values or defaults on startup
- Persist new values immediately on change
- Forward language changes to `AppLocalization.shared`
- Forward appearance changes to `AppearanceManager.shared`

Startup order must apply language and appearance before creating windows and menus so the app does not briefly show the wrong state.

## UI Integration

### Preferences

Keep Preferences as the settings entry point and expand it to include:

- A `General` section or segment for:
  - Language
  - Appearance
- The existing update settings section or segment

Behavior:

- Selecting a language updates the entire main app immediately
- Selecting an appearance updates the entire main app immediately
- No restart prompt

### App Menu

The app menu should rebuild when language changes.

Reason:

- AppKit menus are simpler and safer to rebuild than to partially mutate
- This avoids stale titles on menu items created once during launch

The menu content itself stays the same. Only titles are localized.

### Main Window and Other App Windows

Controllers should expose an `applyLocalization()` path for static text and continue using existing render/update methods for dynamic content.

Examples of content that must switch immediately:

- Window titles
- Static labels
- Buttons
- Empty states
- Context menu item titles
- Alert button titles and message text

Dynamic summaries should continue to use the current data model, but format their user-facing text through `L10n`.

### Status Bar Menu

`StatusItemController` should rebuild its menu when either of these changes:

- repository snapshot changes
- app language changes

The metrics stay data-driven. Only user-visible text becomes localized.

### Update Alerts

`UpdateManager` should build alerts using current localized strings at presentation time.

This keeps behavior simple:

- no alert caching
- no stale strings after a language switch

Appearance will naturally follow the current app appearance because alerts are shown from the app process.

## Quick Look Extension Behavior

Quick Look extensions are separate processes and will not read the app's manual language or appearance settings.

Required behavior:

- Reuse the same translation keys and localized resource files
- Resolve language from the system preferred languages
- Follow the system appearance automatically

Implications:

- If the app is manually set to English and Dark, Quick Look may still appear in system Chinese and system Light
- This is expected and accepted for this feature

Implementation boundary:

- Share localization helpers that are safe for extension targets
- Add localized resources to both the app target and Quick Look extension targets
- Do not add App Group plumbing

## Resource Strategy

Add `Localizable.strings` resources for:

- `en.lproj`
- `zh-Hans.lproj`
- `zh-Hant.lproj`

The same resource set should be included in:

- the main app target
- the Quick Look preview extension target
- the Quick Look thumbnail extension target

## Data Flow

### Startup

1. `AppSettings` loads persisted values or derives defaults from system state
2. `AppLocalization.shared` applies the selected language
3. `AppearanceManager.shared` applies the selected appearance
4. App context, menus, windows, and status item are created

### Runtime Language Switch

1. User changes language in Preferences
2. `AppSettings.appLanguage` persists the new value
3. `AppLocalization.shared` publishes the new language
4. App menu is rebuilt
5. Status bar menu is rebuilt
6. Open view controllers refresh localized UI

### Runtime Appearance Switch

1. User changes appearance in Preferences
2. `AppSettings.appAppearance` persists the new value
3. `AppearanceManager.shared` applies the new appearance to `NSApp`
4. Existing windows and future windows reflect the new appearance immediately

## Error Handling and Fallbacks

- Unsupported persisted language identifiers fall back to the closest supported language, then to English
- Unsupported persisted appearance values fall back to `system`
- Missing localization keys fall back to the key lookup behavior of the active bundle
- Missing localized bundles fall back to the main bundle
- Quick Look should never fail because app-specific settings are unavailable

## Migration Strategy

Implement in this order:

1. Add `AppLanguage`, `AppAppearance`, `AppLocalization`, `AppearanceManager`
2. Extend `AppSettings` persistence and startup application
3. Add localization resource files
4. Update Preferences to expose language and appearance controls
5. Update `AppDelegate` menu rebuild behavior
6. Update `StatusItemController`
7. Update `MainViewController`, `PreviewWindowController`, and related alerts/menus
8. Update `UpdateManager`
9. Update Quick Look shared strings and views

This order ensures the settings mechanism and runtime propagation exist before the wider UI is migrated.

## Testing Strategy

### Unit Tests

- `AppSettingsTests`
  - language persistence
  - appearance persistence
  - defaults resolution
- localization tests
  - supported language resolution
  - preferred language fallback
  - formatted string output for each supported locale
- appearance tests
  - `system`, `light`, and `dark` mapping behavior

### UI / Integration Tests

Cover at least:

- language switch updates Preferences labels immediately
- language switch updates main window labels immediately
- language switch updates status bar menu labels on rebuild
- appearance switch updates app appearance immediately
- `system` appearance does not force a custom `NSApp.appearance`

### Quick Look Verification

Verify:

- Quick Look preview still renders correctly with localized strings
- Quick Look thumbnail still renders correctly with localized strings
- Quick Look does not depend on app-specific stored language or appearance values

## Risks and Controls

### Risk: Hardcoded strings are missed

Control:

- Use repo-wide search to inventory hardcoded user-visible strings in main app and Quick Look
- Migrate by module, not ad hoc

### Risk: Menus or context menus keep stale language

Control:

- Rebuild the app menu on language changes
- Build context menus at display time instead of caching titles

### Risk: Appearance only affects future windows

Control:

- Drive appearance through `NSApp.appearance`
- Avoid per-window custom appearance state unless a window proves it needs an exception

### Risk: Quick Look resources are missing from extension targets

Control:

- Explicitly add localization resources to all required targets
- Verify extension output with targeted tests or manual checks

### Risk: The first pass grows into an unrelated refactor

Control:

- Limit code movement to what is required for localization and appearance switching
- Do not rename unrelated types or rewrite existing workflows

## Implementation Notes for Planning

- Keep the runtime state centralized
- Prefer rebuilding menus over piecemeal menu mutation
- Prefer typed string access over repeated raw keys in controllers
- Keep Quick Look localization helper code extension-safe
- Do not introduce App Group complexity in this task
