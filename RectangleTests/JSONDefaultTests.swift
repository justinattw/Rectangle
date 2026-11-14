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
        let legacy: [String: Any] = ["gapSize": 12, "leftHalf": [:], "NSWindow Frame Settings": "system"]
        let first = try JSONPreferences(url: url, legacyValues: legacy)
        XCTAssertEqual(first.integer(forKey: "gapSize"), 12)
        XCTAssertNotNil(first.dictionary(forKey: "leftHalf"))
        XCTAssertNil(first.object(forKey: "NSWindow Frame Settings"))
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
}
