import Combine
import Foundation

enum UpdateCheckStrategy: String, CaseIterable {
    case manual
    case daily
    case onLaunch

    var title: String {
        switch self {
        case .manual:
            return "手动检查"
        case .daily:
            return "每天自动检查"
        case .onLaunch:
            return "启动时检查"
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    static let defaultUpdateCheckStrategy: UpdateCheckStrategy = .daily

    private enum Keys {
        static let updateCheckStrategy = "ProfileSmithUpdateCheckStrategy"
    }

    private let defaults: UserDefaults

    @Published var updateCheckStrategy: UpdateCheckStrategy {
        didSet {
            guard oldValue != updateCheckStrategy else { return }
            defaults.set(updateCheckStrategy.rawValue, forKey: Keys.updateCheckStrategy)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let rawValue = defaults.string(forKey: Keys.updateCheckStrategy),
           let strategy = UpdateCheckStrategy(rawValue: rawValue) {
            updateCheckStrategy = strategy
        } else {
            updateCheckStrategy = Self.defaultUpdateCheckStrategy
        }
    }

    func resetToDefaults() {
        updateCheckStrategy = Self.defaultUpdateCheckStrategy
    }
}
