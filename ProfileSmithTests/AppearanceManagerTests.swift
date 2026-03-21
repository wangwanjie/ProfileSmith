import AppKit
import Testing
@testable import ProfileSmith

struct AppearanceManagerTests {
    @MainActor
    @Test
    func appearanceModesMapToExpectedAppKitAppearances() {
        let manager = AppearanceManager()

        #expect(manager.resolvedAppearance(for: .system) == nil)
        #expect(manager.resolvedAppearance(for: .light)?.name == .aqua)
        #expect(manager.resolvedAppearance(for: .dark)?.name == .darkAqua)
    }
}
