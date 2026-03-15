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

    enum Columns: String, ColumnExpression {
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

    var statusText: String {
        if isExpired {
            return "已过期"
        }
        guard let daysUntilExpiration else {
            return "有效"
        }
        if daysUntilExpiration == 0 {
            return "今天到期"
        }
        if daysUntilExpiration <= 30 {
            return "\(daysUntilExpiration) 天内到期"
        }
        return "有效"
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
            return "全部"
        case .expiringSoon:
            return "30 天内到期"
        case .expired:
            return "已过期"
        case .development:
            return "开发"
        case .distribution:
            return "分发"
        case .enterprise:
            return "企业"
        case .mac:
            return "Mac"
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
            return "到期时间升序"
        case .expirationDescending:
            return "到期时间降序"
        case .nameAscending:
            return "名称"
        case .teamAscending:
            return "团队"
        case .modificationDescending:
            return "最近修改"
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
