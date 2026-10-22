import Foundation

/// 日期格式化工具。
///
/// DateFormatter 创建成本较高，而列表滚动、全文索引都会频繁调用这里，因此复用同一个实例。
/// DateFormatter 在 macOS 10.9+ 上是线程安全的，可在后台扫描队列中直接使用。
enum Formatters {
    private nonisolated static let timestampFormatter = makeFormatter(
        localeIdentifier: "zh_CN",
        dateFormat: "yyyy-MM-dd HH:mm"
    )
    private nonisolated static let dayFormatter = makeFormatter(
        localeIdentifier: "zh_CN",
        dateFormat: "yyyy-MM-dd"
    )
    private nonisolated static let backupTimestampFormatter = makeFormatter(
        localeIdentifier: "en_US_POSIX",
        dateFormat: "yyyyMMdd-HHmmss"
    )

    nonisolated static func timestampString(from date: Date) -> String {
        timestampFormatter.string(from: date)
    }

    nonisolated static func dayString(from date: Date) -> String {
        dayFormatter.string(from: date)
    }

    nonisolated static func backupTimestampString(from date: Date) -> String {
        backupTimestampFormatter.string(from: date)
    }

    /// 把 plist 中的值转成适合展示的单行文本：布尔值显示 true/false（而不是 NSNumber 的 1/0），
    /// 数组和字典展开为逗号分隔的列表（而不是 Objective-C 风格的多行括号描述）。
    nonisolated static func plistValueString(_ value: Any) -> String {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "true" : "false"
            }
            return number.stringValue
        case let date as Date:
            return timestampString(from: date)
        case let data as Data:
            return data.base64EncodedString()
        case let array as [Any]:
            return "[" + array.map(plistValueString(_:)).joined(separator: ", ") + "]"
        case let dictionary as [String: Any]:
            let pairs = dictionary.keys.sorted().map { key in
                "\(key): \(plistValueString(dictionary[key] as Any))"
            }
            return "{" + pairs.joined(separator: ", ") + "}"
        default:
            return String(describing: value)
        }
    }

    private nonisolated static func makeFormatter(localeIdentifier: String, dateFormat: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: localeIdentifier)
        formatter.dateFormat = dateFormat
        return formatter
    }
}
