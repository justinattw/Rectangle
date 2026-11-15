/// JSONDefaultTests.swift

import XCTest
@testable import Rectangle

class JSONDefaultTests: XCTestCase {

    func testUsesIsolatedTestPreferences() {
        XCTAssertEqual(ProcessInfo.processInfo.environment["JRECTANGLE_TESTING"], "1")
    }

    /// Defaults with a fallback must still honor persisted values.
    private static let testKey = "testJSONDefaultStoredValueRoundTrip"

    private func writeJSON<T: Encodable>(_ value: T, forKey key: String) throws {
        let data = try JSONEncoder().encode(value)
        JSONPreferences.shared.set(String(data: data, encoding: .utf8), forKey: key)
    }

    func testStoredValueIsHonoredOverDefault() throws {
        let key = Self.testKey
        let storedValue: Set<String> = ["com.example.customApp", "org.something.other"]
        let defaultValue: Set<String> = ["org.languagetool.desktop", "com.microsoft.teams2"]

        try writeJSON(storedValue, forKey: key)
        defer { JSONPreferences.shared.removeObject(forKey: key) }

        let jsonDefault = JSONDefault<Set<String>>(key: key, defaultValue: defaultValue)
        XCTAssertEqual(jsonDefault.typedValue, storedValue)
    }

    func testMissingValueFallsBackToDefault() throws {
        let key = Self.testKey
        let defaultValue: Set<String> = ["org.languagetool.desktop", "com.microsoft.teams2"]

        JSONPreferences.shared.removeObject(forKey: key)
        defer { JSONPreferences.shared.removeObject(forKey: key) }

        let jsonDefault = JSONDefault<Set<String>>(key: key, defaultValue: defaultValue)
        XCTAssertEqual(jsonDefault.typedValue, defaultValue)
    }

    func testInvalidJSONFallsBackToDefault() throws {
        let key = Self.testKey
        let defaultValue: Set<String> = ["org.languagetool.desktop", "com.microsoft.teams2"]

        JSONPreferences.shared.set("not valid json", forKey: key)
        defer { JSONPreferences.shared.removeObject(forKey: key) }

        let jsonDefault = JSONDefault<Set<String>>(key: key, defaultValue: defaultValue)
        XCTAssertEqual(jsonDefault.typedValue, defaultValue)
    }

    func testDefaultBackedValueCanBeChangedAndReloaded() {
        let key = Self.testKey
        JSONPreferences.shared.removeObject(forKey: key)
        defer { JSONPreferences.shared.removeObject(forKey: key) }
        let value = JSONDefault<Set<String>>(key: key, defaultValue: [])
        value.typedValue = ["com.example.changed"]
        XCTAssertEqual(JSONDefault<Set<String>>(key: key).typedValue, ["com.example.changed"])
    }

    func testLegacyMigrationIsOneTimeAndPreservesSystemKeysInDefaults() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("config.json")
        let legacy: [String: Any] = ["gapSize": 12, "leftHalf": [:], "NSWindow Frame Settings": "system",
                                     JSONPreferences.configPathDefaultsKey: "/machine-specific/config.json"]
        let first = try JSONPreferences(url: url, legacyValues: legacy)
        XCTAssertEqual(first.integer(forKey: "gapSize"), 12)
        XCTAssertNotNil(first.dictionary(forKey: "leftHalf"))
        XCTAssertNil(first.object(forKey: "NSWindow Frame Settings"))
        XCTAssertNil(first.object(forKey: JSONPreferences.configPathDefaultsKey))
        try first.setAndSave(20, forKey: "gapSize")
        let second = try JSONPreferences(url: url, legacyValues: ["gapSize": 99])
        XCTAssertEqual(second.integer(forKey: "gapSize"), 20)
    }

    func testInvalidExistingFileIsNotOverwritten() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("config.json")
        let data = Data("invalid".utf8)
        try data.write(to: url)
        XCTAssertThrowsError(try JSONPreferences(url: url, legacyValues: ["gapSize": 12]))
        XCTAssertEqual(try Data(contentsOf: url), data)
    }

    func testExternalChangesAreNotOverwritten() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("config.json")
        let preferences = try JSONPreferences(url: url, legacyValues: [:])
        let externalData = Data("{\"version\":1,\"values\":{\"gapSize\":42}}".utf8)
        try externalData.write(to: url)
        XCTAssertThrowsError(try preferences.setAndSave(20, forKey: "gapSize"))
        XCTAssertEqual(try Data(contentsOf: url), externalData)
    }

    func testProfilesAreNativeJSONAndSurviveReloadWithoutOverrides() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("config.json")
        let preferences = try JSONPreferences(url: url, legacyValues: [:])
        let profiles = #"{"1920x1080":{},"2560x1440":{"gapSize":{"float":20}}}"#
        try preferences.setAndSave(profiles, forKey: "displayBehaviorProfiles")
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let stored = try XCTUnwrap(root["profiles"] as? [String: Any])
        XCTAssertNotNil(stored["1920x1080"])
        XCTAssertNil((root["values"] as? [String: Any])?["displayBehaviorProfiles"])
        let reloaded = try JSONPreferences(url: url, legacyValues: [:])
        let decoded = try JSONDecoder().decode([String: [String: CodableDefault]].self,
            from: Data(try XCTUnwrap(reloaded.string(forKey: "displayBehaviorProfiles")).utf8))
        XCTAssertEqual(decoded["1920x1080"], [:])
        XCTAssertEqual(decoded["2560x1440"]?["gapSize"]?.float, 20)
    }

    func testLegacyProfileStringMigratesOnNextWrite() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("config.json")
        let data = try JSONSerialization.data(withJSONObject: [
            "version": 1, "values": ["displayBehaviorProfiles": #"{"1280x720":{}}"#]
        ])
        try data.write(to: url)
        let preferences = try JSONPreferences(url: url, legacyValues: [:])
        try preferences.setAndSave(5, forKey: "gapSize")
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        XCTAssertNotNil((root["profiles"] as? [String: Any])?["1280x720"])
    }

    func testInvalidProfileLayerIsRejectedWithoutOverwritingTheFile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("config.json")
        for profiles in [#"[]"#, #"{"1920x1080":{"gapSize":20}}"#] {
            let data = Data(#"{"version":1,"values":{},"profiles":\#(profiles)}"#.utf8)
            try data.write(to: url)
            XCTAssertThrowsError(try JSONPreferences(url: url, legacyValues: [:]))
            XCTAssertEqual(try Data(contentsOf: url), data)
        }
    }

    func testAbsentProfileStoreCanBeSavedAndReopened() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("config.json")
        let preferences = try JSONPreferences(url: url, legacyValues: [:])
        try preferences.setAndSave("null", forKey: "displayBehaviorProfiles")
        XCTAssertNoThrow(try JSONPreferences(url: url, legacyValues: [:]))
    }

    func testDotfileMigrationPreservesNativeSettingsAndLegacyFile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let legacyURL = directory.appendingPathComponent("legacy/config.json")
        let destination = directory.appendingPathComponent(".config/jrectangle/config.json")
        let legacy = try JSONPreferences(url: legacyURL, legacyValues: ["gapSize": 12])
        try legacy.setAndSave(#"{"1920x1080":{"gapSize":{"float":20}}}"#, forKey: "displayBehaviorProfiles")
        let original = try Data(contentsOf: legacyURL)

        let migrated = try JSONPreferences(url: destination, legacyValues: ["gapSize": 99], migratingFrom: legacyURL)

        XCTAssertEqual(migrated.integer(forKey: "gapSize"), 12)
        XCTAssertEqual(migrated.string(forKey: "displayBehaviorProfiles"), legacy.string(forKey: "displayBehaviorProfiles"))
        XCTAssertEqual(try Data(contentsOf: destination), original)
        XCTAssertEqual(try Data(contentsOf: legacyURL), original)
    }

    func testExistingDotfilesSymlinkTakesPrecedenceOverLegacyConfig() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let legacyURL = directory.appendingPathComponent("legacy.json")
        let trackedURL = directory.appendingPathComponent("dotfiles/config.json")
        let link = directory.appendingPathComponent("config.json")
        _ = try JSONPreferences(url: legacyURL, legacyValues: ["gapSize": 12])
        _ = try JSONPreferences(url: trackedURL, legacyValues: ["gapSize": 42])
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: trackedURL)
        let trackedData = try Data(contentsOf: trackedURL)

        let preferences = try JSONPreferences(url: link, legacyValues: [:], migratingFrom: legacyURL)

        XCTAssertEqual(preferences.integer(forKey: "gapSize"), 42)
        XCTAssertEqual(try Data(contentsOf: trackedURL), trackedData)
        try preferences.setAndSave(50, forKey: "gapSize")
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: link.path), trackedURL.path)
        XCTAssertEqual(try JSONPreferences(url: trackedURL, legacyValues: [:]).integer(forKey: "gapSize"), 50)
        XCTAssertEqual(try JSONPreferences(url: legacyURL, legacyValues: [:]).integer(forKey: "gapSize"), 12)
        try trackedData.write(to: trackedURL, options: .atomic)
        XCTAssertThrowsError(try preferences.setAndSave(60, forKey: "gapSize"))
        XCTAssertEqual(try Data(contentsOf: trackedURL), trackedData)
    }

    func testAtomicWritesThroughSymlinkedDirectoryPreserveTheLink() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let trackedDirectory = directory.appendingPathComponent("dotfiles/jrectangle")
        try FileManager.default.createDirectory(at: trackedDirectory, withIntermediateDirectories: true)
        let link = directory.appendingPathComponent("jrectangle")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: trackedDirectory)
        let preferences = try JSONPreferences(url: link.appendingPathComponent("config.json"), legacyValues: [:])

        try preferences.setAndSave(30, forKey: "gapSize")

        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: link.path), trackedDirectory.path)
        XCTAssertEqual(try JSONPreferences(url: trackedDirectory.appendingPathComponent("config.json"),
                                           legacyValues: [:]).integer(forKey: "gapSize"), 30)
    }

    func testBrokenConfigSymlinkIsNotReplacedByMigration() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let legacyURL = directory.appendingPathComponent("legacy.json")
        let link = directory.appendingPathComponent("config.json")
        let missing = directory.appendingPathComponent("missing.json")
        _ = try JSONPreferences(url: legacyURL, legacyValues: ["gapSize": 12])
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: missing)

        XCTAssertThrowsError(try JSONPreferences(url: link, legacyValues: [:], migratingFrom: legacyURL))
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: link.path), missing.path)
        XCTAssertFalse(FileManager.default.fileExists(atPath: missing.path))
    }

    func testChoosingConfigLocationCopiesSettingsAndKeepsPointerLocal() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let suite = UUID().uuidString
        let localDefaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { localDefaults.removePersistentDomain(forName: suite) }
        let original = directory.appendingPathComponent("original.json")
        let destination = directory.appendingPathComponent("dotfiles/jrectangle.json")
        let preferences = try JSONPreferences(url: original, legacyValues: ["gapSize": 12])

        try preferences.useLocationAfterRestart(destination, localDefaults: localDefaults)

        XCTAssertEqual(try JSONPreferences.configuredURL(defaultURL: original, localDefaults: localDefaults), destination)
        XCTAssertEqual(try Data(contentsOf: original), try Data(contentsOf: destination))
        XCTAssertEqual(preferences.url, original)
        XCTAssertNil(try JSONPreferences(url: destination, legacyValues: [:]).object(forKey: JSONPreferences.configPathDefaultsKey))
        try FileManager.default.removeItem(at: destination)
        XCTAssertThrowsError(try JSONPreferences.configuredURL(defaultURL: original, localDefaults: localDefaults))
    }

    func testChoosingExistingConfigValidatesWithoutOverwritingIt() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let suite = UUID().uuidString
        let localDefaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { localDefaults.removePersistentDomain(forName: suite) }
        let original = directory.appendingPathComponent("original.json")
        let destination = directory.appendingPathComponent("shared.json")
        let preferences = try JSONPreferences(url: original, legacyValues: ["gapSize": 12])
        _ = try JSONPreferences(url: destination, legacyValues: ["gapSize": 42])
        let data = try Data(contentsOf: destination)

        try preferences.useLocationAfterRestart(destination, localDefaults: localDefaults)

        XCTAssertEqual(try Data(contentsOf: destination), data)
        XCTAssertEqual(try JSONPreferences(url: destination, legacyValues: [:]).integer(forKey: "gapSize"), 42)
        let invalid = Data("invalid".utf8)
        try invalid.write(to: destination)
        localDefaults.removeObject(forKey: JSONPreferences.configPathDefaultsKey)
        XCTAssertThrowsError(try preferences.useLocationAfterRestart(destination, localDefaults: localDefaults))
        XCTAssertNil(localDefaults.object(forKey: JSONPreferences.configPathDefaultsKey))
        XCTAssertEqual(try Data(contentsOf: destination), invalid)
    }

    func testConfigurationPathsExpandTildeAndRejectRelativePaths() throws {
        let expected = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/jrectangle/config.json")
        XCTAssertEqual(try JSONPreferences.fileURL(for: "~/.config/jrectangle/config.json"), expected)
        XCTAssertThrowsError(try JSONPreferences.fileURL(for: "relative/config.json"))
        XCTAssertThrowsError(try JSONPreferences.fileURL(for: ""))
    }
}

class DisplayConfigurationLayerTests: XCTestCase {
    private let profile = "9876x5432"
    private var savedProfiles: [String: [String: CodableDefault]]?
    private var savedActive: String?
    private var savedContext: String?
    private var savedGap: Float = 0
    private var savedFit = false

    override func setUp() {
        super.setUp()
        savedContext = BehaviorProfileContext.setCurrentProfileID(BehaviorProfileStore.defaultProfileID)
        savedActive = BehaviorProfileContext.activeProfileID
        savedProfiles = Defaults.displayBehaviorProfiles.typedValue
        savedGap = Defaults.gapSize.value
        savedFit = Defaults.stackFitToSnapArea.enabled
        Defaults.displayBehaviorProfiles.typedValue = [:]
        Defaults.gapSize.value = 10
        Defaults.stackFitToSnapArea.enabled = false
    }

    override func tearDown() {
        Defaults.gapSize.value = savedGap
        Defaults.stackFitToSnapArea.enabled = savedFit
        Defaults.displayBehaviorProfiles.typedValue = savedProfiles
        BehaviorProfileContext.activeProfileID = savedActive
        _ = BehaviorProfileContext.setCurrentProfileID(savedContext)
        super.tearDown()
    }

    func testEncounteredProfilesPersistAfterResetAndRemovingLastOverride() {
        BehaviorProfileStore.registerProfiles([profile, "1234x5678"])
        XCTAssertTrue(BehaviorProfileStore.profileIDs.contains(profile))
        BehaviorProfileStore.setOverride(CodableDefault(float: 30), for: Defaults.gapSize.key, profileID: profile)
        BehaviorProfileStore.removeOverride(for: Defaults.gapSize.key, profileID: profile)
        XCTAssertEqual(Defaults.displayBehaviorProfiles.typedValue?[profile], [:])
        BehaviorProfileStore.reset(profileID: profile)
        XCTAssertTrue(BehaviorProfileStore.profileIDs.contains(profile))
        BehaviorProfileStore.removeProfile(profile)
        XCTAssertFalse(BehaviorProfileStore.profileIDs.contains(profile))
        XCTAssertTrue(BehaviorProfileStore.profileIDs.contains("1234x5678"))
    }

    func testReturningToDefaultRemovesOverrideWithoutForgettingResolution() {
        BehaviorProfileStore.setOverride(CodableDefault(float: 30), for: Defaults.gapSize.key, profileID: profile)
        BehaviorProfileStore.setOverride(CodableDefault(float: 10), for: Defaults.gapSize.key, profileID: profile)
        XCTAssertEqual(BehaviorProfileStore.overrideCount(for: profile), 0)
        XCTAssertTrue(BehaviorProfileStore.profileIDs.contains(profile))
        Defaults.gapSize.value = 12
        XCTAssertEqual(BehaviorProfileContext.withProfileID(profile) { Defaults.gapSize.value }, 12)
    }

    func testChangingDefaultRemovesNowRedundantOverrides() {
        BehaviorProfileStore.setOverride(CodableDefault(float: 30), for: Defaults.gapSize.key, profileID: profile)
        Defaults.gapSize.value = 30
        XCTAssertEqual(BehaviorProfileStore.overrideCount(for: profile), 0)
        Defaults.gapSize.value = 40
        XCTAssertEqual(BehaviorProfileContext.withProfileID(profile) { Defaults.gapSize.value }, 40)
    }

    func testScopedEditingDoesNotChangeGlobalAndEqualBooleanInherits() {
        BehaviorProfileContext.edit(profile) {
            Defaults.stackFitToSnapArea.enabled = true
            XCTAssertTrue(Defaults.stackFitToSnapArea.enabled)
            Defaults.gapSize.value = 22
        }
        XCTAssertFalse(Defaults.stackFitToSnapArea.enabled)
        XCTAssertEqual(Defaults.gapSize.value, 10)
        BehaviorProfileContext.edit(profile) { Defaults.stackFitToSnapArea.enabled = false }
        XCTAssertNil(BehaviorProfileStore.override(for: Defaults.stackFitToSnapArea.key, profileID: profile))
    }

    func testOptionalBooleanComparesAgainstItsEffectiveUnsetDefault() {
        let saved = Defaults.windowSnapping.enabled
        defer { Defaults.windowSnapping.enabled = saved }
        Defaults.windowSnapping.enabled = nil
        BehaviorProfileContext.edit(profile) { Defaults.windowSnapping.enabled = true }
        XCTAssertEqual(BehaviorProfileStore.overrideCount(for: profile), 0)
        BehaviorProfileContext.edit(profile) { Defaults.windowSnapping.enabled = false }
        XCTAssertEqual(BehaviorProfileStore.overrideCount(for: profile), 1)
        BehaviorProfileContext.edit(profile) { Defaults.windowSnapping.enabled = true }
        XCTAssertEqual(BehaviorProfileStore.overrideCount(for: profile), 0)
    }

    func testOverrideNotificationsUseRuntimeContextNotEditingContext() {
        BehaviorProfileContext.activeProfileID = "runtime"
        var notified = false
        let token = NotificationCenter.default.addObserver(forName: .displayBehaviorProfileOverridesChanged,
            object: nil, queue: nil) { _ in
                notified = true
                XCTAssertEqual(BehaviorProfileContext.currentProfileID, "runtime")
                XCTAssertNil(BehaviorProfileContext.editingProfileID)
            }
        defer { NotificationCenter.default.removeObserver(token) }
        BehaviorProfileContext.edit(profile) {
            Defaults.gapSize.value = 22
            XCTAssertEqual(BehaviorProfileContext.currentProfileID, profile)
            XCTAssertEqual(BehaviorProfileContext.editingProfileID, profile)
        }
        XCTAssertTrue(notified)
    }

    func testShortcutOverrideInheritsAgainWhenMatchingGlobal() {
        let key = "testProfileShortcut"
        let saved = JSONPreferences.shared.object(forKey: key)
        defer { JSONPreferences.shared.set(saved, forKey: key) }
        let shortcut = Shortcut(NSEvent.ModifierFlags.option.rawValue, 0).toMASSHortcut()
        ShortcutPreferences.shared.set(shortcut, for: key)
        BehaviorProfileContext.edit(profile) { ShortcutPreferences.shared.set(nil, for: key) }
        XCTAssertNil(BehaviorProfileContext.withProfileID(profile) { ShortcutPreferences.shared.shortcut(for: key) })
        XCTAssertNotNil(ShortcutPreferences.shared.shortcut(for: key))
        BehaviorProfileContext.edit(profile) { ShortcutPreferences.shared.set(shortcut, for: key) }
        XCTAssertNil(BehaviorProfileStore.override(for: "shortcut:\(key)", profileID: profile))
        XCTAssertNotNil(BehaviorProfileContext.withProfileID(profile) { ShortcutPreferences.shared.shortcut(for: key) })
    }

    func testCycleSizesCompareWithEffectiveDefaultAndResumeInheriting() {
        let savedSizes = Defaults.selectedCycleSizes.value
        let savedChanged = Defaults.cycleSizesIsChanged.enabled
        defer {
            JSONPreferences.shared.performBatch {
                Defaults.selectedCycleSizes.value = savedSizes
                Defaults.cycleSizesIsChanged.enabled = savedChanged
            }
        }
        Defaults.cycleSizesIsChanged.enabled = false
        BehaviorProfileContext.edit(profile) {
            Defaults.selectedCycleSizes.value = [.fourFifths, .nineTenths]
        }
        XCTAssertEqual(BehaviorProfileContext.withProfileID(profile) { CycleSize.sortedSelectedSizes() },
                       [.fourFifths, .nineTenths])
        BehaviorProfileContext.edit(profile) {
            Defaults.selectedCycleSizes.value = CycleSize.defaultSizes
        }
        XCTAssertNil(BehaviorProfileStore.override(for: Defaults.selectedCycleSizes.key, profileID: profile))
        JSONPreferences.shared.performBatch {
            Defaults.selectedCycleSizes.value = [.oneQuarter, .nineTenths]
            Defaults.cycleSizesIsChanged.enabled = true
        }
        XCTAssertEqual(BehaviorProfileContext.withProfileID(profile) { CycleSize.sortedSelectedSizes() },
                       [.nineTenths, .oneQuarter])
    }

    func testSnapMappingsReturnToBuiltInDefaultRegardlessOfJSONOrder() throws {
        let saved = Defaults.landscapeSnapAreas.typedValue
        defer { Defaults.landscapeSnapAreas.typedValue = saved }
        Defaults.landscapeSnapAreas.typedValue = nil
        BehaviorProfileContext.edit(profile) {
            SnapAreaModel.instance.setLandscape(directional: .tl, snapAreaConfig: SnapAreaConfig(action: .maximize))
        }
        XCTAssertNotNil(BehaviorProfileStore.override(for: Defaults.landscapeSnapAreas.key, profileID: profile))

        let data = try JSONEncoder().encode(SnapAreaModel.defaultLandscape)
        let array = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [Any])
        let reordered = stride(from: array.count - 2, through: 0, by: -2).flatMap { [array[$0], array[$0 + 1]] }
        let reorderedData = try JSONSerialization.data(withJSONObject: reordered)
        BehaviorProfileStore.setOverride(CodableDefault(string: String(decoding: reorderedData, as: UTF8.self)),
            for: Defaults.landscapeSnapAreas.key, profileID: profile)
        XCTAssertNil(BehaviorProfileStore.override(for: Defaults.landscapeSnapAreas.key, profileID: profile))

        BehaviorProfileContext.edit(profile) {
            SnapAreaModel.instance.setLandscape(directional: .tl, snapAreaConfig: SnapAreaConfig(action: .maximize))
        }
        var newDefault = SnapAreaModel.defaultLandscape
        newDefault[.tl] = SnapAreaConfig(action: .maximize)
        Defaults.landscapeSnapAreas.typedValue = newDefault
        XCTAssertNil(BehaviorProfileStore.override(for: Defaults.landscapeSnapAreas.key, profileID: profile))
    }

    func testSnapAreaSelectionRefreshesOfflineProfilesWithoutCreatingOverrides() {
        let selection = DisplayProfileSelectionModel.shared
        let savedSelection = selection.selectedProfileID
        defer { selection.selectProfile(savedSelection) }
        let portrait = "5432x9876"
        BehaviorProfileStore.registerProfiles([profile, portrait])
        let model = SnapAreaViewModel()
        selection.selectProfile(profile)
        model.updateSnapArea(selectedTag: WindowAction.maximize.rawValue, directional: .tl, orientation: .landscape)
        XCTAssertEqual(model.getSelectedTag(for: .tl, orientation: .landscape), WindowAction.maximize.rawValue)
        selection.selectProfile(BehaviorProfileStore.defaultProfileID)
        XCTAssertEqual(model.getSelectedTag(for: .tl, orientation: .landscape),
                       SnapAreaModel.instance.landscape[.tl]?.action?.rawValue)
        selection.selectProfile(portrait)
        XCTAssertTrue(model.isPortraitConnected)
        XCTAssertEqual(BehaviorProfileStore.overrideCount(for: portrait), 0)
        selection.selectProfile(profile)
        XCTAssertEqual(model.getSelectedTag(for: .tl, orientation: .landscape), WindowAction.maximize.rawValue)
        XCTAssertEqual(BehaviorProfileStore.overrideCount(for: profile), 1)
    }

    func testExportUsesDefaultValuesWhileEditingAnotherProfile() throws {
        BehaviorProfileContext.edit(profile) { Defaults.gapSize.value = 22 }
        let exported = BehaviorProfileContext.edit(profile) { Defaults.encoded() }
        let config = try XCTUnwrap(Defaults.convert(jsonString: XCTUnwrap(exported)))
        XCTAssertEqual(config.defaults[Defaults.gapSize.key]?.float, 10)
        XCTAssertEqual(config.profiles?[profile]?[Defaults.gapSize.key]?.float, 22)
    }
}
