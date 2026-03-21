import Foundation
import Testing
@testable import ProfileSmith

struct AppLocalizationTests {
    @Test
    func localizationSwitchesBundlesAndFormatsArguments() throws {
        let temporaryDirectory = try TestTemporaryDirectory(prefix: "ProfileSmithLocalization")
        defer { temporaryDirectory.cleanup() }

        let bundleURL = temporaryDirectory.url.appendingPathComponent("Localization.bundle", isDirectory: true)
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)

        try writeLocalization(
            bundleURL: bundleURL,
            language: "en",
            contents: """
            "greeting" = "Hello";
            "countdown" = "%d days left";
            """
        )
        try writeLocalization(
            bundleURL: bundleURL,
            language: "zh-Hans",
            contents: """
            "greeting" = "你好";
            "countdown" = "还有 %d 天";
            """
        )
        try writeLocalization(
            bundleURL: bundleURL,
            language: "zh-Hant",
            contents: """
            "greeting" = "你好";
            "countdown" = "還有 %d 天";
            """
        )

        let bundle = try #require(Bundle(path: bundleURL.path))
        let localization = AppLocalization(bundle: bundle, initialLanguage: .english)

        #expect(localization.string("greeting") == "Hello")
        #expect(localization.string("countdown", 7) == "7 days left")

        localization.setLanguage(.traditionalChinese)
        #expect(localization.string("greeting") == "你好")
        #expect(localization.string("countdown", 3) == "還有 3 天")
    }

    private func writeLocalization(bundleURL: URL, language: String, contents: String) throws {
        let directoryURL = bundleURL.appendingPathComponent("\(language).lproj", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let fileURL = directoryURL.appendingPathComponent("Localizable.strings")
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
