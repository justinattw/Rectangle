import AppKit
import MASShortcut

/// Persistent app preferences. The legacy defaults domain is read only when
/// creating the file for the first time, and is never deleted.
final class JSONPreferences {
    static let configPathDefaultsKey = "JRectangleConfigFilePath"

    static let shared: JSONPreferences = {
        #if DEBUG
        if ProcessInfo.processInfo.environment["JRECTANGLE_TESTING"] == "1" {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("jrectangle-test-\(getpid())", isDirectory: true)
            do {
                return try JSONPreferences(url: directory.appendingPathComponent("config.json"), legacyValues: [:])
            } catch {
                fatalError("Could not create isolated test preferences: \(error)")
            }
        }
        #endif
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let configDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/jrectangle", isDirectory: true)
        #if DEBUG
        let defaultURL = configDirectory.appendingPathComponent("debug/config.json")
        let legacyURL = support.appendingPathComponent("JRectangle/Debug/config.json")
        #else
        let defaultURL = configDirectory.appendingPathComponent("config.json")
        let legacyURL = support.appendingPathComponent("JRectangle/config.json")
        #endif
        var url = defaultURL
        do {
            url = try configuredURL(defaultURL: defaultURL)
            let domain = Bundle.main.bundleIdentifier.flatMap {
                UserDefaults.standard.persistentDomain(forName: $0)
            } ?? [:]
            return try JSONPreferences(url: url, legacyValues: domain, migratingFrom: legacyURL)
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "JRectangle could not open its settings"
            alert.informativeText = "\(url.path)\n\n\(error.localizedDescription)\n\nThe existing settings have not been deleted."
            alert.runModal()
            exit(EXIT_FAILURE)
        }
    }()

    let url: URL
    private let lock = NSRecursiveLock()
    private var values: [String: Any]
    private var savedData: Data
    private var batchDepth = 0

    static func fileURL(for path: String) throws -> URL {
        let expanded = (path as NSString).expandingTildeInPath
        guard expanded.hasPrefix("/") else { throw PreferencesError.invalidLocation }
        return URL(fileURLWithPath: expanded).standardizedFileURL
    }

    static func configuredURL(defaultURL: URL, localDefaults: UserDefaults = .standard) throws -> URL {
        guard let value = localDefaults.object(forKey: configPathDefaultsKey) else { return defaultURL }
        guard let path = value as? String else { throw PreferencesError.invalidLocation }
        let url = try fileURL(for: path)
        guard pathExists(url) else { throw PreferencesError.missingConfiguredFile(url.path) }
        return url
    }

    private static func pathExists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path) ||
            (try? FileManager.default.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType) == .typeSymbolicLink
    }

    init(url: URL, legacyValues: [String: Any], migratingFrom legacyURL: URL? = nil) throws {
        self.url = url
        if !Self.pathExists(url), let legacyURL, Self.pathExists(legacyURL) {
            let previous = try JSONPreferences(url: legacyURL, legacyValues: [:])
            let destination = url.resolvingSymlinksInPath()
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try previous.savedData.write(to: destination, options: .withoutOverwriting)
        }
        if Self.pathExists(url) {
            let data = try Data(contentsOf: url)
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let version = root["version"] as? Int, version == 1,
                  var values = root["values"] as? [String: Any] else {
                throw PreferencesError.invalidFile
            }
            if let profiles = root["profiles"] {
                guard profiles is [String: Any] else { throw PreferencesError.invalidFile }
                let data = try JSONSerialization.data(withJSONObject: profiles, options: [.sortedKeys])
                _ = try JSONDecoder().decode([String: [String: CodableDefault]].self, from: data)
                values["displayBehaviorProfiles"] = String(decoding: data, as: UTF8.self)
            }
            self.values = values
            self.savedData = data
        } else {
            var migrated: [String: Any] = [:]
            for (key, value) in legacyValues {
                // AppKit and Sparkle own these keys, even in the app domain.
                guard key != Self.configPathDefaultsKey,
                      !key.hasPrefix("NS"), !key.hasPrefix("Apple"), !key.hasPrefix("SU") else { continue }
                if let data = value as? Data {
                    guard let unarchiver = ValueTransformer(forName: .secureUnarchiveFromDataTransformerName),
                          let shortcut = unarchiver.transformedValue(data) as? MASShortcut,
                          let transformer = ValueTransformer(forName: NSValueTransformerName(rawValue: MASDictionaryTransformerName)),
                          let dictionary = transformer.reverseTransformedValue(shortcut) else {
                        throw PreferencesError.unsupportedLegacyValue(key)
                    }
                    migrated[key] = dictionary
                } else {
                    migrated[key] = value
                }
            }
            self.values = migrated
            self.savedData = try Self.encode(migrated)
            let destination = url.resolvingSymlinksInPath()
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try savedData.write(to: destination, options: .withoutOverwriting)
        }
    }

    func useLocationAfterRestart(_ destination: URL, localDefaults: UserDefaults = .standard) throws {
        lock.lock()
        defer { lock.unlock() }
        try persist()
        let preferences = try JSONPreferences(url: destination, legacyValues: [:], migratingFrom: url)
        localDefaults.set(preferences.url.path, forKey: Self.configPathDefaultsKey)
    }

    func object(forKey key: String) -> Any? {
        lock.lock()
        defer { lock.unlock() }
        return values[key]
    }

    func string(forKey key: String) -> String? { object(forKey: key) as? String }
    func dictionary(forKey key: String) -> [String: Any]? { object(forKey: key) as? [String: Any] }
    func integer(forKey key: String) -> Int { (object(forKey: key) as? NSNumber)?.intValue ?? 0 }
    func bool(forKey key: String) -> Bool { (object(forKey: key) as? NSNumber)?.boolValue ?? false }
    func float(forKey key: String) -> Float { (object(forKey: key) as? NSNumber)?.floatValue ?? 0 }
    func double(forKey key: String) -> Double { (object(forKey: key) as? NSNumber)?.doubleValue ?? 0 }

    var isPerformingBatch: Bool {
        lock.lock()
        defer { lock.unlock() }
        return batchDepth > 0
    }

    func set(_ value: Any?, forKey key: String) {
        do {
            try setAndSave(value, forKey: key)
            if batchDepth == 0, key != "displayBehaviorProfiles", self === JSONPreferences.shared {
                BehaviorProfileStore.removeRedundantOverrides()
            }
        } catch {
            report(error)
        }
    }

    @discardableResult
    func performBatch(_ block: () -> Void) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        batchDepth += 1
        block()
        batchDepth -= 1
        if batchDepth == 0 {
            do { try persist() } catch {
                report(error)
                return false
            }
        }
        return true
    }

    func setAndSave(_ value: Any?, forKey key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        if let value {
            values[key] = value
        } else {
            values.removeValue(forKey: key)
        }
        if batchDepth == 0 { try persist() }
    }

    private func persist() throws {
        // Resolve on every write so atomic replacement preserves dotfiles symlinks.
        let destination = url.resolvingSymlinksInPath()
        let current = try Data(contentsOf: destination)
        guard current == savedData else { throw PreferencesError.modifiedExternally }
        let data = try Self.encode(values)
        try data.write(to: destination, options: .atomic)
        savedData = data
    }

    func removeObject(forKey key: String) { set(nil, forKey: key) }

    private static func encode(_ values: [String: Any]) throws -> Data {
        var defaults = values
        var root: [String: Any] = ["version": 1]
        if let profiles = defaults.removeValue(forKey: "displayBehaviorProfiles") as? String {
            let data = Data(profiles.utf8)
            if let decoded = try JSONDecoder().decode([String: [String: CodableDefault]]?.self, from: data) {
                root["profiles"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded))
            }
        }
        root["values"] = defaults
        guard JSONSerialization.isValidJSONObject(root) else {
            throw PreferencesError.unsupportedValues
        }
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }

    private func report(_ error: Error) {
        DispatchQueue.main.async {
            AlertUtil.oneButtonAlert(
                question: "Could not save JRectangle settings",
                text: "\(self.url.path)\n\n\(error.localizedDescription)\n\nYour changes remain in memory but have not been saved."
            )
        }
    }

    private enum PreferencesError: LocalizedError {
        case invalidFile
        case unsupportedLegacyValue(String)
        case modifiedExternally
        case unsupportedValues
        case invalidLocation
        case missingConfiguredFile(String)

        var errorDescription: String? {
            switch self {
            case .invalidFile: return "The settings file is invalid or has an unsupported version."
            case .unsupportedLegacyValue(let key): return "The old setting '\(key)' could not be migrated."
            case .modifiedExternally: return "The settings file was changed outside JRectangle. Restart to load it; unsaved changes in this session will be lost."
            case .unsupportedValues: return "A setting cannot be represented in JSON."
            case .invalidLocation: return "Enter an absolute file path, or a path beginning with ~/."
            case .missingConfiguredFile(let path):
                return "The selected settings file is missing: \(path). Restore it, or remove \(JSONPreferences.configPathDefaultsKey) from this app's local defaults to use the default location."
            }
        }
    }
}
