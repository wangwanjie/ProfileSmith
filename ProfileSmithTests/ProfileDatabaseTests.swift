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

        let alpha = TestFixtureFactory.makeRecord(
            path: "/tmp/alpha.mobileprovision",
            name: "Alpha Development",
            teamName: "Alpha Team",
            bundleIdentifier: "com.example.alpha",
            profileType: "Development",
            profilePlatform: "iOS",
            isExpired: false,
            daysUntilExpiration: 10,
            expirationDate: 1_900_000_000
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
            expirationDate: 1_905_000_000
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
            expirationDate: 1_600_000_000
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
}
