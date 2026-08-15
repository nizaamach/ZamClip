import Combine
import Foundation

@MainActor
final class AppSettings: ObservableObject {
    @Published var historyLimit: Int {
        didSet { defaults.set(historyLimit, forKey: Keys.historyLimit) }
    }

    @Published var excludedBundleIDs: [String] {
        didSet { defaults.set(excludedBundleIDs, forKey: Keys.excludedBundleIDs) }
    }

    @Published var ignoreUnknownSources: Bool {
        didSet { defaults.set(ignoreUnknownSources, forKey: Keys.ignoreUnknownSources) }
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let historyLimit = "historyLimit"
        static let excludedBundleIDs = "excludedBundleIDs"
        static let ignoreUnknownSources = "ignoreUnknownSources"
    }

    init() {
        historyLimit = defaults.object(forKey: Keys.historyLimit) as? Int ?? 500
        excludedBundleIDs = defaults.stringArray(forKey: Keys.excludedBundleIDs) ?? [
            "com.agilebits.onepassword7",
            "com.bitwarden.desktop",
            "com.apple.keychainaccess"
        ]
        ignoreUnknownSources = defaults.object(forKey: Keys.ignoreUnknownSources) as? Bool ?? false
    }

    func isExcluded(bundleID: String?) -> Bool {
        guard let bundleID else { return ignoreUnknownSources }
        return excludedBundleIDs.contains(bundleID)
    }

    func addExcludedBundleID(_ bundleID: String) {
        let value = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !excludedBundleIDs.contains(value) else { return }
        excludedBundleIDs.append(value)
    }

    func removeExcludedBundleID(_ bundleID: String) {
        excludedBundleIDs.removeAll { $0 == bundleID }
    }
}
