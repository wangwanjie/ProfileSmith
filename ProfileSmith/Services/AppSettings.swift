import Combine
import Foundation

enum UpdateCheckStrategy: String, CaseIterable {
    case manual
    case daily
    case onLaunch

    var title: String {
        switch self {
        case .manual:
            return L10n.updateStrategyManual
        case .daily:
            return L10n.updateStrategyDaily
        case .onLaunch:
            return L10n.updateStrategyOnLaunch
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    static let defaultUpdateCheckStrategy: UpdateCheckStrategy = .daily
    static let defaultLanguage: AppLanguage = .simplifiedChinese
    static let defaultAppearance: AppAppearance = .system

    private enum Keys {
        static let updateCheckStrategy = "ProfileSmithUpdateCheckStrategy"
        static let appLanguage = "ProfileSmithAppLanguage"
        static let appAppearance = "ProfileSmithAppAppearance"
    }

    private let defaults: UserDefaults

    @Published var appLanguage: AppLanguage {
        didSet {
            guard oldValue != appLanguage else { return }
            defaults.set(appLanguage.rawValue, forKey: Keys.appLanguage)
            AppLocalization.shared.setLanguage(appLanguage)
        }
    }

    @Published var appAppearance: AppAppearance {
        didSet {
            guard oldValue != appAppearance else { return }
            defaults.set(appAppearance.rawValue, forKey: Keys.appAppearance)
            AppearanceManager.shared.apply(appAppearance)
        }
    }

    @Published var updateCheckStrategy: UpdateCheckStrategy {
        didSet {
            guard oldValue != updateCheckStrategy else { return }
            defaults.set(updateCheckStrategy.rawValue, forKey: Keys.updateCheckStrategy)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let rawLanguage = defaults.string(forKey: Keys.appLanguage),
           let language = AppLanguage(rawValue: rawLanguage) {
            appLanguage = language
        } else {
            appLanguage = Self.defaultLanguage
        }

        if let rawAppearance = defaults.string(forKey: Keys.appAppearance),
           let appearance = AppAppearance(rawValue: rawAppearance) {
            appAppearance = appearance
        } else {
            appAppearance = Self.defaultAppearance
        }

        if let rawValue = defaults.string(forKey: Keys.updateCheckStrategy),
           let strategy = UpdateCheckStrategy(rawValue: rawValue) {
            updateCheckStrategy = strategy
        } else {
            updateCheckStrategy = Self.defaultUpdateCheckStrategy
        }

        AppLocalization.shared.setLanguage(appLanguage)
        AppearanceManager.shared.apply(appAppearance)
    }

    func resetToDefaults() {
        appLanguage = Self.defaultLanguage
        appAppearance = Self.defaultAppearance
        updateCheckStrategy = Self.defaultUpdateCheckStrategy
    }
}
