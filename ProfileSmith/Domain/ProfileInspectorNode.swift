import Foundation

enum InspectorNodeKind: String {
    case dictionary = "Dictionary"
    case array = "Array"
    case string = "String"
    case number = "Number"
    case date = "Date"
    case data = "Data"
    case boolean = "Bool"
    case certificate = ".cer"
    case unknown = "Value"
}

final class InspectorNode {
    let key: String
    let type: String
    let detail: String
    let children: [InspectorNode]
    let kind: InspectorNodeKind
    let certificateSummary: CertificateSummary?
    let rawValue: Any?

    init(
        key: String,
        type: String,
        detail: String,
        children: [InspectorNode] = [],
        kind: InspectorNodeKind = .unknown,
        certificateSummary: CertificateSummary? = nil,
        rawValue: Any? = nil
    ) {
        self.key = key
        self.type = type
        self.detail = detail
        self.children = children
        self.kind = kind
        self.certificateSummary = certificateSummary
        self.rawValue = rawValue
    }
}

enum InspectorNodeBuilder {
    static func makeRootNode(from plist: Any, certificates: [CertificateSummary]) -> InspectorNode {
        buildNode(key: "Profile", value: plist, certificates: certificates)
    }

    private static func buildNode(key: String, value: Any, certificates: [CertificateSummary]) -> InspectorNode {
        switch value {
        case let dictionary as [String: Any]:
            let sortedKeys = dictionary.keys.sorted { left, right in
                if left == "DeveloperCertificates" { return true }
                if right == "DeveloperCertificates" { return false }
                return left.localizedCaseInsensitiveCompare(right) == .orderedAscending
            }

            let children = sortedKeys.map { childKey -> InspectorNode in
                if childKey == "DeveloperCertificates", let entries = dictionary[childKey] as? [Data] {
                    return buildCertificatesNode(key: childKey, values: entries, certificates: certificates)
                }
                return buildNode(key: childKey, value: dictionary[childKey] as Any, certificates: certificates)
            }

            return InspectorNode(
                key: key,
                type: InspectorNodeKind.dictionary.rawValue,
                detail: "\(dictionary.count) items",
                children: children,
                kind: .dictionary,
                rawValue: dictionary
            )
        case let array as [Any]:
            let children = array.enumerated().map { offset, value in
                buildNode(key: "\(offset)", value: value, certificates: certificates)
            }
            return InspectorNode(
                key: key,
                type: InspectorNodeKind.array.rawValue,
                detail: "\(array.count) items",
                children: children,
                kind: .array,
                rawValue: array
            )
        case let date as Date:
            return InspectorNode(
                key: key,
                type: InspectorNodeKind.date.rawValue,
                detail: Formatters.timestampString(from: date),
                kind: .date,
                rawValue: date
            )
        case let number as NSNumber:
            let boolValue = CFGetTypeID(number) == CFBooleanGetTypeID()
            return InspectorNode(
                key: key,
                type: boolValue ? InspectorNodeKind.boolean.rawValue : InspectorNodeKind.number.rawValue,
                detail: boolValue ? (number.boolValue ? "true" : "false") : number.stringValue,
                kind: boolValue ? .boolean : .number,
                rawValue: number
            )
        case let data as Data:
            return InspectorNode(
                key: key,
                type: InspectorNodeKind.data.rawValue,
                detail: data.base64EncodedString(),
                kind: .data,
                rawValue: data
            )
        case let string as String:
            return InspectorNode(
                key: key,
                type: InspectorNodeKind.string.rawValue,
                detail: string,
                kind: .string,
                rawValue: string
            )
        default:
            return InspectorNode(
                key: key,
                type: InspectorNodeKind.unknown.rawValue,
                detail: String(describing: value),
                kind: .unknown,
                rawValue: value
            )
        }
    }

    private static func buildCertificatesNode(key: String, values: [Data], certificates: [CertificateSummary]) -> InspectorNode {
        let children = values.enumerated().map { offset, data -> InspectorNode in
            let certificateSummary = offset < certificates.count ? certificates[offset] : CertificateSummary.fromRawData(data)
            let detailItems = certificateSummary.asDictionary.map { pair in
                buildNode(key: pair.key, value: pair.value, certificates: [])
            }
            return InspectorNode(
                key: certificateSummary.summary,
                type: InspectorNodeKind.certificate.rawValue,
                detail: certificateSummary.sha1,
                children: detailItems,
                kind: .certificate,
                certificateSummary: certificateSummary,
                rawValue: data
            )
        }

        return InspectorNode(
            key: key,
            type: InspectorNodeKind.array.rawValue,
            detail: "\(values.count) items",
            children: children,
            kind: .array,
            rawValue: values
        )
    }
}
