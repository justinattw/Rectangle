import AppKit
import MASShortcut

/// Persistent app preferences. The legacy defaults domain is read only when
/// creating the file for the first time, and is never deleted.
final class JSONPreferences {
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
        #if DEBUG
        let directory = support.appendingPathComponent("JRectangle/Debug", isDirectory: true)
        #else
        let directory = support.appendingPathComponent("JRectangle", isDirectory: true)
        #endif
        let url = directory.appendingPathComponent("config.json")
        do {
            let domain = Bundle.main.bundleIdentifier.flatMap {
                UserDefaults.standard.persistentDomain(forName: $0)
            } ?? [:]
            return try JSONPreferences(url: url, legacyValues: domain)
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "JRectangle could not open its settings"
            alert.informativeText = "\(url.path)\n\n\(error.localizedDescription)\n\nThe existing settings have not been deleted."
            alert.runModal()
            exit(EXIT_FAILURE)
        }
    }()

    private let url: URL
    private let lock = NSRecursiveLock()
    private var values: [String: Any]
    private var savedData: Data
    private var batchDepth = 0

    init(url: URL, legacyValues: [String: Any]) throws {
        self.url = url
        if FileManager.default.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let version = root["version"] as? Int, version == 1,
                  let values = root["values"] as? [String: Any] else {
                throw PreferencesError.invalidFile
            }
            self.values = values
            self.savedData = data
        } else {
            var migrated: [String: Any] = [:]
            for (key, value) in legacyValues {
                // AppKit and Sparkle own these keys, even in the app domain.
                guard !key.hasPrefix("NS"), !key.hasPrefix("Apple"), !key.hasPrefix("SU") else { continue }
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
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try savedData.write(to: url, options: .atomic)
        }
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

    func set(_ value: Any?, forKey key: String) {
        do {
            try setAndSave(value, forKey: key)
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
        let current = try Data(contentsOf: url)
        guard current == savedData else { throw PreferencesError.modifiedExternally }
        let data = try Self.encode(values)
        try data.write(to: url, options: .atomic)
        savedData = data
    }

    func removeObject(forKey key: String) { set(nil, forKey: key) }

    private static func encode(_ values: [String: Any]) throws -> Data {
        guard JSONSerialization.isValidJSONObject(["version": 1, "values": values]) else {
            throw PreferencesError.unsupportedValues
        }
        return try JSONSerialization.data(withJSONObject: ["version": 1, "values": values], options: [.prettyPrinted, .sortedKeys])
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

        var errorDescription: String? {
            switch self {
            case .invalidFile: return "The settings file is invalid or has an unsupported version."
            case .unsupportedLegacyValue(let key): return "The old setting '\(key)' could not be migrated."
            case .modifiedExternally: return "The settings file was changed outside JRectangle. Restart to load it; unsaved changes in this session will be lost."
            case .unsupportedValues: return "A setting cannot be represented in JSON."
            }
        }
    }
}
