import Combine
import Carbon.HIToolbox
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

    @Published var hotKeyKeyCode: UInt32 {
        didSet { defaults.set(Int(hotKeyKeyCode), forKey: Keys.hotKeyKeyCode) }
    }

    @Published var hotKeyModifiers: UInt32 {
        didSet { defaults.set(Int(hotKeyModifiers), forKey: Keys.hotKeyModifiers) }
    }

    @Published var hotKeyKeyLabel: String {
        didSet { defaults.set(hotKeyKeyLabel, forKey: Keys.hotKeyKeyLabel) }
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let historyLimit = "historyLimit"
        static let excludedBundleIDs = "excludedBundleIDs"
        static let ignoreUnknownSources = "ignoreUnknownSources"
        static let hotKeyKeyCode = "hotKeyKeyCode"
        static let hotKeyModifiers = "hotKeyModifiers"
        static let hotKeyKeyLabel = "hotKeyKeyLabel"
    }

    init() {
        historyLimit = defaults.object(forKey: Keys.historyLimit) as? Int ?? 500
        excludedBundleIDs = defaults.stringArray(forKey: Keys.excludedBundleIDs) ?? [
            "com.agilebits.onepassword7",
            "com.bitwarden.desktop",
            "com.apple.keychainaccess"
        ]
        ignoreUnknownSources = defaults.object(forKey: Keys.ignoreUnknownSources) as? Bool ?? false
        hotKeyKeyCode = UInt32(defaults.object(forKey: Keys.hotKeyKeyCode) as? Int ?? Int(kVK_ANSI_V))
        hotKeyModifiers = UInt32(
            defaults.object(forKey: Keys.hotKeyModifiers) as? Int
                ?? Int(UInt32(cmdKey) | UInt32(shiftKey))
        )
        hotKeyKeyLabel = defaults.string(forKey: Keys.hotKeyKeyLabel) ?? "V"
    }

    var shortcutDisplay: String {
        var parts: [String] = []
        if hotKeyModifiers & UInt32(cmdKey) != 0 { parts.append("Command") }
        if hotKeyModifiers & UInt32(shiftKey) != 0 { parts.append("Shift") }
        if hotKeyModifiers & UInt32(optionKey) != 0 { parts.append("Option") }
        if hotKeyModifiers & UInt32(controlKey) != 0 { parts.append("Control") }
        parts.append(hotKeyKeyLabel)
        return parts.joined(separator: "-")
    }

    func setGlobalShortcut(keyCode: UInt32, modifiers: UInt32, keyLabel: String) {
        hotKeyKeyCode = keyCode
        hotKeyModifiers = modifiers
        hotKeyKeyLabel = keyLabel
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
