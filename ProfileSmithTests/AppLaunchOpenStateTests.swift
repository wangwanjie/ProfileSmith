import Foundation
import Testing
@testable import ProfileSmith

struct AppLaunchOpenStateTests {
    @Test
    func externalOpenBeforeWindowReadyDefersURLsWithoutConsumingInitialPresentation() {
        var state = AppLaunchOpenState()
        let firstURL = URL(fileURLWithPath: "/tmp/one.mobileprovision")
        let secondURL = URL(fileURLWithPath: "/tmp/two.mobileprovision")

        let shouldPresentImmediately = state.registerExternalOpen([firstURL, secondURL], windowControllerReady: false)

        #expect(!shouldPresentImmediately)
        #expect(!state.hasPresentedInitialWindow)
        #expect(state.pendingExternalURLs == [firstURL, secondURL])
    }

    @Test
    func firstReadyPresentationConsumesDeferredURLs() {
        var state = AppLaunchOpenState()
        let fileURL = URL(fileURLWithPath: "/tmp/deferred.mobileprovision")

        _ = state.registerExternalOpen([fileURL], windowControllerReady: false)
        let shouldBeginPresentation = state.beginInitialPresentationIfPossible(windowControllerReady: true)

        #expect(shouldBeginPresentation)
        #expect(state.hasPresentedInitialWindow)
        #expect(state.takePendingExternalURLs() == [fileURL])
        #expect(state.takePendingExternalURLs().isEmpty)
    }
}
