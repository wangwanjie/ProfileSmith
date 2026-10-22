import Combine
import Foundation

final class AppLocalization: ObservableObject {
    static let shared = AppLocalization()

    @Published private(set) var language: AppLanguage {
        didSet {
            cacheLock.lock()
            cachedLocalizedBundle = nil
            cacheLock.unlock()
        }
    }

    var locale: Locale {
        language.locale
    }

    private let baseBundle: Bundle
    /// 每次取文案都重新创建 Bundle 开销较大（列表每个单元格都会调用），按当前语言缓存。
    /// 预览 HTML、解析错误文案会在后台队列生成，缓存读写需要加锁。
    private var cachedLocalizedBundle: Bundle?
    private let cacheLock = NSLock()

    init(bundle: Bundle = .main, initialLanguage: AppLanguage = AppLanguage.systemPreferred) {
        self.baseBundle = bundle
        self.language = initialLanguage
    }

    func setLanguage(_ language: AppLanguage) {
        guard self.language != language else { return }
        self.language = language
    }

    func string(_ key: String, _ arguments: CVarArg..., table: String = "Localizable") -> String {
        string(key, arguments: arguments, table: table)
    }

    func string(_ key: String, arguments: [CVarArg], table: String = "Localizable") -> String {
        let format = localizedBundle.localizedString(forKey: key, value: nil, table: table)
        guard arguments.isEmpty == false else { return format }
        return String(format: format, locale: locale, arguments: arguments)
    }

    private var localizedBundle: Bundle {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cachedLocalizedBundle {
            return cachedLocalizedBundle
        }
        let bundle: Bundle
        if let path = baseBundle.path(forResource: language.rawValue, ofType: "lproj"),
           let localized = Bundle(path: path) {
            bundle = localized
        } else {
            bundle = baseBundle
        }
        cachedLocalizedBundle = bundle
        return bundle
    }
}
