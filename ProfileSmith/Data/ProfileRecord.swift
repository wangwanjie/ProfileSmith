import Foundation
import GRDB

struct ProfileRecord: Codable, FetchableRecord, PersistableRecord, Hashable, Identifiable {
    static let databaseTableName = "profiles"

    var path: String
    var sourceKind: String
    var sourceName: String
    var fileName: String
    var fileExtension: String
    var fileSize: Int64
    var fileModificationTime: TimeInterval
    var fileCreationTime: TimeInterval
    var uuid: String?
    var name: String?
    var teamName: String?
    var teamIdentifier: String?
    var appIDName: String?
    var applicationIdentifier: String?
    var bundleIdentifier: String?
    var applicationIdentifierPrefix: String?
    var profilePlatform: String?
    var profileType: String?
    var isExpired: Bool
    var daysUntilExpiration: Int?
    var creationDate: TimeInterval?
    var expirationDate: TimeInterval?
    var certificateCount: Int
    var deviceCount: Int
    var searchText: String
    var lastIndexedAt: TimeInterval

    var id: String { path }

    enum Columns: String, ColumnExpression, CaseIterable {
        case path
        case sourceKind
        case sourceName
        case fileName
        case fileExtension
        case fileSize
        case fileModificationTime
        case fileCreationTime
        case uuid
        case name
        case teamName
        case teamIdentifier
        case appIDName
        case applicationIdentifier
        case bundleIdentifier
        case applicationIdentifierPrefix
        case profilePlatform
        case profileType
        case isExpired
        case daysUntilExpiration
        case creationDate
        case expirationDate
        case certificateCount
        case deviceCount
        case searchText
        case lastIndexedAt
    }
}

extension ProfileRecord {
    private var effectiveExpirationState: (isExpired: Bool, daysUntilExpiration: Int?) {
        guard let expirationDateValue else {
            return (isExpired, daysUntilExpiration)
        }
        return (
            expirationDateValue < Date(),
            MobileProvisionParser.daysUntilExpiration(for: expirationDateValue)
        )
    }

    var displayName: String {
        name?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? fileName
    }

    var creationDateValue: Date? {
        creationDate.map(Date.init(timeIntervalSince1970:))
    }

    var expirationDateValue: Date? {
        expirationDate.map(Date.init(timeIntervalSince1970:))
    }

    var modificationDateValue: Date {
        Date(timeIntervalSince1970: fileModificationTime)
    }

    var currentIsExpired: Bool {
        effectiveExpirationState.isExpired
    }

    var currentDaysUntilExpiration: Int? {
        effectiveExpirationState.daysUntilExpiration
    }

    var statusText: String {
        let expirationState = effectiveExpirationState
        if expirationState.isExpired {
            return L10n.profileStatusExpired
        }
        guard let daysUntilExpiration = expirationState.daysUntilExpiration else {
            return L10n.profileStatusValid
        }
        if daysUntilExpiration == 0 {
            return L10n.profileStatusExpiringToday
        }
        if daysUntilExpiration <= 30 {
            return L10n.profileStatusExpiringSoon(daysUntilExpiration)
        }
        return L10n.profileStatusValid
    }

    func recalculatingExpirationState(referenceDate: Date = Date()) -> ProfileRecord {
        guard let expirationDateValue else { return self }

        var record = self
        record.isExpired = expirationDateValue < referenceDate
        record.daysUntilExpiration = MobileProvisionParser.daysUntilExpiration(
            for: expirationDateValue,
            referenceDate: referenceDate
        )
        return record
    }
}

struct ProfileMetrics: Equatable {
    var totalCount: Int
    var expiredCount: Int
    var expiringSoonCount: Int

    static let empty = ProfileMetrics(totalCount: 0, expiredCount: 0, expiringSoonCount: 0)
}

enum ProfileFilter: String, CaseIterable {
    case all
    case expiringSoon
    case expired
    case development
    case distribution
    case enterprise
    case mac

    var title: String {
        switch self {
        case .all:
            return L10n.filterAll
        case .expiringSoon:
            return L10n.filterExpiringSoon
        case .expired:
            return L10n.filterExpired
        case .development:
            return L10n.filterDevelopment
        case .distribution:
            return L10n.filterDistribution
        case .enterprise:
            return L10n.filterEnterprise
        case .mac:
            return L10n.filterMac
        }
    }
}

enum ProfileSort: String, CaseIterable {
    case expirationAscending
    case expirationDescending
    case nameAscending
    case teamAscending
    case modificationDescending

    var title: String {
        switch self {
        case .expirationAscending:
            return L10n.sortExpirationAscending
        case .expirationDescending:
            return L10n.sortExpirationDescending
        case .nameAscending:
            return L10n.sortNameAscending
        case .teamAscending:
            return L10n.sortTeamAscending
        case .modificationDescending:
            return L10n.sortModificationDescending
        }
    }
}

struct ProfileQuery: Equatable {
    var searchText: String = ""
    var filter: ProfileFilter = .all
    var sort: ProfileSort = .expirationAscending
}

struct IndexedFileState: FetchableRecord, Decodable {
    var path: String
    var fileSize: Int64
    var fileModificationTime: TimeInterval
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
