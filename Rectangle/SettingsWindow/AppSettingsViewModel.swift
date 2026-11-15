/// AppSettingsViewModel.swift

import SwiftUI
import AppKit

@Observable
final class AppSettingsViewModel {
    // MARK: - General Settings
     var launchOnLogin: Bool {
        didSet {
            LaunchOnLogin.isEnabled = launchOnLogin
            Defaults.launchOnLogin.enabled = launchOnLogin
        }
    }

     var hideMenuBarIcon: Bool {
        didSet {
            Defaults.hideMenuBarIcon.enabled = hideMenuBarIcon
            RectangleStatusItem.instance.refreshVisibility()
        }
    }

     var versionString: String = ""
     var configPath: String

     var allowAnyShortcut: Bool {
        didSet {
            Defaults.allowAnyShortcut.enabled = allowAnyShortcut
            Notification.Name.allowAnyShortcut.post(object: allowAnyShortcut)
        }
    }

    // MARK: - Initialization
    init() {
        self.launchOnLogin = Defaults.launchOnLogin.enabled
        self.hideMenuBarIcon = Defaults.hideMenuBarIcon.enabled
        self.allowAnyShortcut = Defaults.allowAnyShortcut.enabled
        self.configPath = (JSONPreferences.shared.url.path as NSString).abbreviatingWithTildeInPath

        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        self.versionString = "v\(appVersion) (\(build))"

        setupObservers()
    }

    private func setupObservers() {
        Notification.Name.menuBarIconHidden.onPost { [weak self] _ in
            self?.hideMenuBarIcon = true
        }

        Notification.Name.configImported.onPost { [weak self] _ in
            self?.reloadFromDefaults()
        }
    }

    func reloadFromDefaults() {
        self.launchOnLogin = Defaults.launchOnLogin.enabled
        self.hideMenuBarIcon = Defaults.hideMenuBarIcon.enabled
        self.allowAnyShortcut = Defaults.allowAnyShortcut.enabled
    }

    func restoreDefaults() {
        let currentDefaults = Defaults.alternateDefaultShortcuts.enabled ? "JRectangle" : "Spectacle"
        let defaultShortcutsTitle = String(localized: "Default Shortcuts")
        let currentlyUsingText = String(localized: "Currently using: ")
        let cancelText = String(localized: "Cancel")

        let response = AlertUtil.threeButtonAlert(question: defaultShortcutsTitle, text: currentlyUsingText + currentDefaults, buttonOneText: "JRectangle", buttonTwoText: "Spectacle", buttonThreeText: cancelText)
        if response == .alertThirdButtonReturn { return }

        let rectangleDefaults = (response == .alertFirstButtonReturn)
        JSONPreferences.shared.performBatch {
            ShortcutPreferences.shared.performBatch {
                WindowAction.active.forEach { ShortcutPreferences.shared.reset($0.name) }
                Defaults.alternateDefaultShortcuts.enabled = rectangleDefaults
            }
        }
        Notification.Name.changeDefaults.post()

        Defaults.portraitSnapAreas.typedValue = nil
        Defaults.landscapeSnapAreas.typedValue = nil
        Notification.Name.defaultSnapAreas.post()
    }

    func exportConfig() {
        Notification.Name.windowSnapping.post(object: false)
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "RectangleConfig"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                if let jsonString = Defaults.encoded() {
                    try jsonString.write(to: url, atomically: true, encoding: .utf8)
                } else {
                    AlertUtil.oneButtonAlert(question: "Could not export configuration", text: "The settings could not be encoded.")
                }
            } catch {
                Logger.log(error.localizedDescription)
                AlertUtil.oneButtonAlert(question: "Could not export configuration", text: error.localizedDescription)
            }
        }
        Notification.Name.windowSnapping.post(object: true)
    }

    func showConfigInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([JSONPreferences.shared.url])
    }

    func changeConfigLocation() {
        do {
            let destination = try JSONPreferences.fileURL(for: configPath)
            guard destination != JSONPreferences.shared.url.standardizedFileURL else { return }
            let response = AlertUtil.twoButtonAlert(
                question: "Change configuration location?",
                text: "Use \(destination.path)?\n\nIf the file exists, its settings will be loaded without overwriting it. Otherwise, your current settings will be copied there. The original file will be kept.\n\nJRectangle will quit. Reopen it to use the selected configuration.",
                confirmText: "Use and Quit"
            )
            guard response == .alertFirstButtonReturn else { return }
            try JSONPreferences.shared.useLocationAfterRestart(destination)
            NSApp.terminate(nil)
        } catch {
            Logger.log(error.localizedDescription)
            AlertUtil.oneButtonAlert(question: "Could not change configuration location",
                                     text: error.localizedDescription)
        }
    }

    func importConfig() {
        Notification.Name.windowSnapping.post(object: false)
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            Defaults.load(fileUrl: url)
        }
        Notification.Name.windowSnapping.post(object: true)
    }
}
