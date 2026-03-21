import Foundation
import GRDB

final class ProfileDatabase {
    let dbQueue: DatabaseQueue

    init(databaseURL: URL) throws {
        dbQueue = try DatabaseQueue(path: databaseURL.path)
        try migrator.migrate(dbQueue)
    }

    func close() throws {
        try dbQueue.close()
    }

    func indexedFileStates() throws -> [String: IndexedFileState] {
        try dbQueue.read { db in
            let states = try IndexedFileState.fetchAll(
                db,
                sql: """
                SELECT path, fileSize, fileModificationTime
                FROM profiles
                """
            )
            return Dictionary(uniqueKeysWithValues: states.map { ($0.path, $0) })
        }
    }

    func save(records: [ProfileRecord], removingPaths: [String]) throws {
        try dbQueue.write { db in
            for path in removingPaths {
                try db.execute(sql: "DELETE FROM profile_search WHERE path = ?", arguments: [path])
                try db.execute(sql: "DELETE FROM profiles WHERE path = ?", arguments: [path])
            }

            for record in records {
                try record.save(db)
                try db.execute(sql: "DELETE FROM profile_search WHERE path = ?", arguments: [record.path])
                try db.execute(
                    sql: """
                    INSERT INTO profile_search (
                        path,
                        name,
                        bundleIdentifier,
                        teamName,
                        teamIdentifier,
                        uuid,
                        profileType,
                        searchText
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    arguments: [
                        record.path,
                        record.name ?? "",
                        record.bundleIdentifier ?? "",
                        record.teamName ?? "",
                        record.teamIdentifier ?? "",
                        record.uuid ?? "",
                        record.profileType ?? "",
                        record.searchText,
                    ]
                )
            }
        }
    }

    func fetchProfiles(query: ProfileQuery) throws -> [ProfileRecord] {
        try dbQueue.read { db in
            let expirationExpressions = makeExpirationExpressions(referenceDate: Date())
            let predicate = makeFilterClause(for: query.filter, expirationExpressions: expirationExpressions)
            let orderBy = makeOrderClause(for: query.sort, expirationExpressions: expirationExpressions)
            let selectClause = makeProfileSelectClause(expirationExpressions: expirationExpressions)

            if query.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return try ProfileRecord.fetchAll(
                    db,
                    sql: """
                    \(selectClause)
                    \(predicate.clause)
                    \(orderBy)
                    """,
                    arguments: predicate.arguments
                )
            }

            let ftsQuery = makeFTSQuery(from: query.searchText)
            if !ftsQuery.isEmpty {
                do {
                    return try ProfileRecord.fetchAll(
                        db,
                        sql: """
                        \(selectClause)
                        JOIN profile_search ON profile_search.path = profiles.path
                        WHERE profile_search MATCH ?
                        \(predicate.andClause)
                        \(orderBy)
                        """,
                        arguments: [ftsQuery] + predicate.arguments
                    )
                } catch {
                    // Fall through to LIKE matching if FTS syntax cannot represent the user query.
                }
            }

            return try ProfileRecord.fetchAll(
                db,
                sql: """
                \(selectClause)
                WHERE LOWER(searchText) LIKE ?
                \(predicate.andClause)
                \(orderBy)
                """,
                arguments: ["%\(query.searchText.lowercased())%"] + predicate.arguments
            )
        }
    }

    func fetchMetrics() throws -> ProfileMetrics {
        try dbQueue.read { db in
            let expirationExpressions = makeExpirationExpressions(referenceDate: Date())
            let row = try Row.fetchOne(
                db,
                sql: """
                SELECT
                    COUNT(*) AS totalCount,
                    SUM(CASE WHEN \(expirationExpressions.isExpired) = 1 THEN 1 ELSE 0 END) AS expiredCount,
                    SUM(CASE WHEN \(expirationExpressions.isExpired) = 0 AND \(expirationExpressions.daysUntilExpiration) BETWEEN 0 AND 30 THEN 1 ELSE 0 END) AS expiringSoonCount
                FROM profiles
                """
            )

            return ProfileMetrics(
                totalCount: row?["totalCount"] ?? 0,
                expiredCount: row?["expiredCount"] ?? 0,
                expiringSoonCount: row?["expiringSoonCount"] ?? 0
            )
        }
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("createProfiles") { db in
            try db.create(table: "profiles", ifNotExists: true) { table in
                table.column("path", .text).notNull().primaryKey()
                table.column("sourceKind", .text).notNull()
                table.column("sourceName", .text).notNull()
                table.column("fileName", .text).notNull()
                table.column("fileExtension", .text).notNull()
                table.column("fileSize", .integer).notNull()
                table.column("fileModificationTime", .double).notNull()
                table.column("fileCreationTime", .double).notNull()
                table.column("uuid", .text)
                table.column("name", .text)
                table.column("teamName", .text)
                table.column("teamIdentifier", .text)
                table.column("appIDName", .text)
                table.column("applicationIdentifier", .text)
                table.column("bundleIdentifier", .text)
                table.column("applicationIdentifierPrefix", .text)
                table.column("profilePlatform", .text)
                table.column("profileType", .text)
                table.column("isExpired", .boolean).notNull()
                table.column("daysUntilExpiration", .integer)
                table.column("creationDate", .double)
                table.column("expirationDate", .double)
                table.column("certificateCount", .integer).notNull()
                table.column("deviceCount", .integer).notNull()
                table.column("searchText", .text).notNull()
                table.column("lastIndexedAt", .double).notNull()
            }

            try db.create(index: "profiles_expiration_idx", on: "profiles", columns: ["expirationDate"])
            try db.create(index: "profiles_team_idx", on: "profiles", columns: ["teamName"])
            try db.create(index: "profiles_name_idx", on: "profiles", columns: ["name"])

            try db.create(virtualTable: "profile_search", using: FTS5()) { table in
                table.column("path").notIndexed()
                table.column("name")
                table.column("bundleIdentifier")
                table.column("teamName")
                table.column("teamIdentifier")
                table.column("uuid")
                table.column("profileType")
                table.column("searchText")
                table.tokenizer = .unicode61()
            }
        }

        return migrator
    }

    private func makeFilterClause(
        for filter: ProfileFilter,
        expirationExpressions: (isExpired: String, daysUntilExpiration: String)
    ) -> (clause: String, andClause: String, arguments: StatementArguments) {
        switch filter {
        case .all:
            return ("", "", [])
        case .expiringSoon:
            let clause = "\(expirationExpressions.isExpired) = 0 AND \(expirationExpressions.daysUntilExpiration) BETWEEN 0 AND 30"
            return ("WHERE \(clause)", "AND \(clause)", [])
        case .expired:
            let clause = "\(expirationExpressions.isExpired) = 1"
            return ("WHERE \(clause)", "AND \(clause)", [])
        case .development:
            return ("WHERE profiles.profileType = ?", "AND profiles.profileType = ?", ["Development"])
        case .distribution:
            return ("WHERE profiles.profileType LIKE ?", "AND profiles.profileType LIKE ?", ["Distribution%"])
        case .enterprise:
            return ("WHERE profiles.profileType = ?", "AND profiles.profileType = ?", ["Enterprise"])
        case .mac:
            return ("WHERE profiles.profilePlatform = ?", "AND profiles.profilePlatform = ?", ["Mac"])
        }
    }

    private func makeOrderClause(
        for sort: ProfileSort,
        expirationExpressions: (isExpired: String, daysUntilExpiration: String)
    ) -> String {
        switch sort {
        case .expirationAscending:
            return "ORDER BY \(expirationExpressions.isExpired) ASC, profiles.expirationDate ASC, LOWER(profiles.name) ASC"
        case .expirationDescending:
            return "ORDER BY \(expirationExpressions.isExpired) ASC, profiles.expirationDate DESC, LOWER(profiles.name) ASC"
        case .nameAscending:
            return "ORDER BY LOWER(profiles.name) ASC, profiles.expirationDate ASC"
        case .teamAscending:
            return "ORDER BY LOWER(profiles.teamName) ASC, LOWER(profiles.name) ASC"
        case .modificationDescending:
            return "ORDER BY profiles.fileModificationTime DESC, LOWER(profiles.name) ASC"
        }
    }

    private func makeProfileSelectClause(expirationExpressions: (isExpired: String, daysUntilExpiration: String)) -> String {
        let columns = [
            "profiles.path",
            "profiles.sourceKind",
            "profiles.sourceName",
            "profiles.fileName",
            "profiles.fileExtension",
            "profiles.fileSize",
            "profiles.fileModificationTime",
            "profiles.fileCreationTime",
            "profiles.uuid",
            "profiles.name",
            "profiles.teamName",
            "profiles.teamIdentifier",
            "profiles.appIDName",
            "profiles.applicationIdentifier",
            "profiles.bundleIdentifier",
            "profiles.applicationIdentifierPrefix",
            "profiles.profilePlatform",
            "profiles.profileType",
            "\(expirationExpressions.isExpired) AS isExpired",
            "\(expirationExpressions.daysUntilExpiration) AS daysUntilExpiration",
            "profiles.creationDate",
            "profiles.expirationDate",
            "profiles.certificateCount",
            "profiles.deviceCount",
            "profiles.searchText",
            "profiles.lastIndexedAt",
        ].joined(separator: ",\n")

        return """
        SELECT
        \(columns)
        FROM profiles
        """
    }

    private func makeExpirationExpressions(referenceDate: Date) -> (isExpired: String, daysUntilExpiration: String) {
        let timestamp = String(format: "%.6f", referenceDate.timeIntervalSince1970)
        let isExpired = """
        CASE
            WHEN profiles.expirationDate IS NOT NULL AND profiles.expirationDate < \(timestamp) THEN 1
            ELSE 0
        END
        """
        let daysUntilExpiration = """
        CASE
            WHEN profiles.expirationDate IS NULL THEN NULL
            WHEN profiles.expirationDate < \(timestamp) THEN 0
            ELSE MAX(
                0,
                CAST(
                    julianday(date(profiles.expirationDate, 'unixepoch', 'localtime')) -
                    julianday(date(\(timestamp), 'unixepoch', 'localtime'))
                    AS INTEGER
                )
            )
        END
        """
        return (isExpired, daysUntilExpiration)
    }

    private func makeFTSQuery(from searchText: String) -> String {
        let tokens = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: { character in
                !(character.isLetter || character.isNumber || character == "." || character == "-" || character == "_")
            })
            .map(String.init)

        return tokens.map { "\($0)*" }.joined(separator: " AND ")
    }
}
