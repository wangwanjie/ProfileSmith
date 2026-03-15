import Foundation

enum Formatters {
    nonisolated static func timestampString(from date: Date) -> String {
        makeTimestampFormatter().string(from: date)
    }

    nonisolated static func dayString(from date: Date) -> String {
        makeDayFormatter().string(from: date)
    }

    nonisolated static func backupTimestampString(from date: Date) -> String {
        makeBackupTimestampFormatter().string(from: date)
    }

    private nonisolated static func makeTimestampFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }

    private nonisolated static func makeDayFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private nonisolated static func makeBackupTimestampFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }
}
