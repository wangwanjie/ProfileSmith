import Foundation
import Testing
@testable import ProfileSmith

struct ProfileDatabaseTests {
    @Test
    func searchFilterAndSortUseSQLiteIndexesAndFTS() throws {
        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        let databaseURL = temporaryDirectory.url.appendingPathComponent("ProfileSmith.sqlite")
        let database = try ProfileDatabase(databaseURL: databaseURL)
        defer { try? database.close() }

        let alphaExpiration = Date().addingTimeInterval((10 * 86_400) + 3_600)
        let betaExpiration = Date().addingTimeInterval(45 * 86_400)
        let gammaExpiration = Date().addingTimeInterval(-2 * 86_400)

        let alpha = TestFixtureFactory.makeRecord(
            path: "/tmp/alpha.mobileprovision",
            name: "Alpha Development",
            teamName: "Alpha Team",
            bundleIdentifier: "com.example.alpha",
            profileType: "Development",
            profilePlatform: "iOS",
            isExpired: false,
            daysUntilExpiration: 10,
            expirationDate: alphaExpiration.timeIntervalSince1970
        )
        let beta = TestFixtureFactory.makeRecord(
            path: "/tmp/beta.provisionprofile",
            name: "Beta Mac Store",
            teamName: "Beta Team",
            bundleIdentifier: "com.example.beta.mac",
            profileType: "Distribution (App Store)",
            profilePlatform: "Mac",
            isExpired: false,
            daysUntilExpiration: 45,
            expirationDate: betaExpiration.timeIntervalSince1970
        )
        let gamma = TestFixtureFactory.makeRecord(
            path: "/tmp/gamma.mobileprovision",
            name: "Gamma Legacy",
            teamName: "Gamma Team",
            bundleIdentifier: "com.example.gamma",
            profileType: "Distribution (Ad Hoc)",
            profilePlatform: "iOS",
            isExpired: true,
            daysUntilExpiration: 0,
            expirationDate: gammaExpiration.timeIntervalSince1970
        )

        try database.save(records: [alpha, beta, gamma], removingPaths: [])

        let searchResults = try database.fetchProfiles(query: ProfileQuery(searchText: "beta mac", filter: .all, sort: .nameAscending))
        #expect(searchResults.map(\.displayName) == ["Beta Mac Store"])

        let expiredResults = try database.fetchProfiles(query: ProfileQuery(searchText: "", filter: .expired, sort: .nameAscending))
        #expect(expiredResults.map(\.displayName) == ["Gamma Legacy"])

        let macResults = try database.fetchProfiles(query: ProfileQuery(searchText: "", filter: .mac, sort: .expirationAscending))
        #expect(macResults.map(\.displayName) == ["Beta Mac Store"])

        let sortedResults = try database.fetchProfiles(query: ProfileQuery(searchText: "", filter: .all, sort: .expirationAscending))
        #expect(sortedResults.map(\.displayName) == ["Alpha Development", "Beta Mac Store", "Gamma Legacy"])

        let metrics = try database.fetchMetrics()
        #expect(metrics.totalCount == 3)
        #expect(metrics.expiredCount == 1)
        #expect(metrics.expiringSoonCount == 1)
    }

    @Test
    func fetchProfilesAndMetricsRecalculateExpirationStateFromCurrentDate() throws {
        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        let databaseURL = temporaryDirectory.url.appendingPathComponent("ProfileSmith.sqlite")
        let database = try ProfileDatabase(databaseURL: databaseURL)
        defer { try? database.close() }

        let soonExpiration = Date().addingTimeInterval((25 * 86_400) + 3_600)
        let expiredExpiration = Date().addingTimeInterval(-2 * 86_400)
        let freshExpiration = Date().addingTimeInterval(60 * 86_400)

        let soonRecord = TestFixtureFactory.makeRecord(
            path: "/tmp/recalc-soon.mobileprovision",
            name: "Recalc Soon",
            teamName: "Recalc Team",
            bundleIdentifier: "com.example.recalc.soon",
            profileType: "Development",
            profilePlatform: "iOS",
            isExpired: false,
            daysUntilExpiration: 28,
            expirationDate: soonExpiration.timeIntervalSince1970
        )
        let expiredRecord = TestFixtureFactory.makeRecord(
            path: "/tmp/recalc-expired.mobileprovision",
            name: "Recalc Expired",
            teamName: "Recalc Team",
            bundleIdentifier: "com.example.recalc.expired",
            profileType: "Distribution (Ad Hoc)",
            profilePlatform: "iOS",
            isExpired: false,
            daysUntilExpiration: 28,
            expirationDate: expiredExpiration.timeIntervalSince1970
        )
        let freshRecord = TestFixtureFactory.makeRecord(
            path: "/tmp/recalc-fresh.mobileprovision",
            name: "Recalc Fresh",
            teamName: "Recalc Team",
            bundleIdentifier: "com.example.recalc.fresh",
            profileType: "Development",
            profilePlatform: "iOS",
            isExpired: false,
            daysUntilExpiration: 60,
            expirationDate: freshExpiration.timeIntervalSince1970
        )

        try database.save(records: [soonRecord, expiredRecord, freshRecord], removingPaths: [])

        let allProfiles = try database.fetchProfiles(query: ProfileQuery(searchText: "", filter: .all, sort: .expirationAscending))
        let recalculatedSoonRecord = try #require(allProfiles.first(where: { $0.path == soonRecord.path }))
        let recalculatedExpiredRecord = try #require(allProfiles.first(where: { $0.path == expiredRecord.path }))

        #expect(recalculatedSoonRecord.daysUntilExpiration == MobileProvisionParser.daysUntilExpiration(for: soonExpiration))
        #expect(recalculatedSoonRecord.isExpired == false)
        #expect(recalculatedExpiredRecord.isExpired)
        #expect(recalculatedExpiredRecord.daysUntilExpiration == 0)

        let expiringSoonProfiles = try database.fetchProfiles(query: ProfileQuery(searchText: "", filter: .expiringSoon, sort: .expirationAscending))
        #expect(expiringSoonProfiles.map(\.path) == [soonRecord.path])

        let expiredProfiles = try database.fetchProfiles(query: ProfileQuery(searchText: "", filter: .expired, sort: .expirationAscending))
        #expect(expiredProfiles.map(\.path) == [expiredRecord.path])

        let metrics = try database.fetchMetrics()
        #expect(metrics.totalCount == 3)
        #expect(metrics.expiredCount == 1)
        #expect(metrics.expiringSoonCount == 1)
    }

    @Test
    func searchFallsBackToSubstringMatchingAndEscapesLikeWildcards() throws {
        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        let database = try ProfileDatabase(databaseURL: temporaryDirectory.url.appendingPathComponent("ProfileSmith.sqlite"))
        defer { try? database.close() }

        let expiration = Date().addingTimeInterval(90 * 86_400).timeIntervalSince1970
        let smith = TestFixtureFactory.makeRecord(
            path: "/tmp/smith.mobileprovision",
            name: "ProfileSmith Dev",
            teamName: "Smith Team",
            bundleIdentifier: "com.example.profilesmith",
            profileType: "Development",
            profilePlatform: "iOS",
            isExpired: false,
            daysUntilExpiration: 90,
            expirationDate: expiration
        )
        let other = TestFixtureFactory.makeRecord(
            path: "/tmp/other.mobileprovision",
            name: "Other App",
            teamName: "Other Team",
            bundleIdentifier: "com.example.other",
            profileType: "Development",
            profilePlatform: "iOS",
            isExpired: false,
            daysUntilExpiration: 90,
            expirationDate: expiration
        )
        try database.save(records: [smith, other], removingPaths: [])

        // FTS 只做词首前缀匹配，“Smith”命中不了“ProfileSmith”，必须回退到子串匹配。
        let substringResults = try database.fetchProfiles(query: ProfileQuery(searchText: "fileSmi"))
        #expect(substringResults.map(\.path) == [smith.path])

        // 带 "." 的 Bundle ID 无法用 FTS 语法表达，同样走子串匹配。
        let bundleResults = try database.fetchProfiles(query: ProfileQuery(searchText: "com.example.other"))
        #expect(bundleResults.map(\.path) == [other.path])

        // "%" 和 "_" 必须按字面量匹配，不能当作通配符把所有记录都搜出来。
        #expect(try database.fetchProfiles(query: ProfileQuery(searchText: "%")).isEmpty)
        #expect(try database.fetchProfiles(query: ProfileQuery(searchText: "_")).isEmpty)
    }

    @Test
    func savingAgainReplacesSearchIndexAndRemovingDeletesRows() throws {
        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        let database = try ProfileDatabase(databaseURL: temporaryDirectory.url.appendingPathComponent("ProfileSmith.sqlite"))
        defer { try? database.close() }

        var record = TestFixtureFactory.makeRecord(
            path: "/tmp/replace.mobileprovision",
            name: "Before Rename",
            teamName: "Replace Team",
            bundleIdentifier: "com.example.replace",
            profileType: "Development",
            profilePlatform: "iOS",
            isExpired: false,
            daysUntilExpiration: 90,
            expirationDate: Date().addingTimeInterval(90 * 86_400).timeIntervalSince1970
        )
        try database.save(records: [record], removingPaths: [])

        record.name = "After Rename"
        record.searchText = "After Rename"
        try database.save(records: [record], removingPaths: [])

        #expect(try database.fetchProfiles(query: ProfileQuery()).count == 1)
        #expect(try database.fetchProfiles(query: ProfileQuery(searchText: "after")).map(\.displayName) == ["After Rename"])
        #expect(try database.fetchProfiles(query: ProfileQuery(searchText: "before")).isEmpty)
        #expect(try database.indexedFileStates().keys.sorted() == [record.path])

        try database.save(records: [], removingPaths: [record.path])
        #expect(try database.fetchProfiles(query: ProfileQuery()).isEmpty)
        #expect(try database.fetchProfiles(query: ProfileQuery(searchText: "after")).isEmpty)
        #expect(try database.fetchMetrics() == .empty)
    }
}
