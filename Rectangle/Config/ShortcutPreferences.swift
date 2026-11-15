import AppKit
import MASShortcut

extension Notification.Name {
    static let shortcutPreferencesChanged = Notification.Name("shortcutPreferencesChanged")
}

final class ShortcutPreferences {
    static let shared = ShortcutPreferences()
    private var defaults: [String: MASShortcut] = [:]
    private var bindings: [String: MASShortcut] = [:]
    private var batchDepth = 0

    func performBatch(_ block: () -> Void) {
        batchDepth += 1
        block()
        batchDepth -= 1
        if batchDepth == 0 {
            changed(nil)
        }
    }

    private func changed(_ key: String?) {
        guard batchDepth == 0 else { return }
        BehaviorProfileContext.withActiveProfile {
            NotificationCenter.default.post(name: .shortcutPreferencesChanged, object: key)
        }
    }

    func registerDefaults(_ shortcuts: [String: MASShortcut]) {
        defaults = shortcuts
        changed(nil)
    }

    func shortcut(for key: String) -> MASShortcut? {
        if let value = BehaviorProfileStore.override(for: "shortcut:\(key)", profileID: BehaviorProfileContext.currentProfileID)?.string,
           let data = value.data(using: .utf8),
           let shortcut = try? JSONDecoder().decode(Shortcut.self, from: data) {
            return shortcut.keyCode < 0 ? nil : shortcut.toMASSHortcut()
        }
        guard let value = JSONPreferences.shared.object(forKey: key) else { return defaults[key] }
        guard let dictionary = value as? [String: Any],
              let transformer = ValueTransformer(forName: NSValueTransformerName(rawValue: MASDictionaryTransformerName))
        else { return nil }
        return transformer.transformedValue(dictionary) as? MASShortcut
    }

    func set(_ shortcut: MASShortcut?, for key: String) {
        if let profileID = BehaviorProfileContext.editingProfileID, profileID != BehaviorProfileStore.defaultProfileID {
            do {
                let value = shortcut.map(Shortcut.init(masShortcut:)) ?? Shortcut(0, -1)
                let data = try JSONEncoder().encode(value)
                BehaviorProfileStore.setOverride(CodableDefault(string: String(decoding: data, as: UTF8.self)),
                                                 for: "shortcut:\(key)", profileID: profileID)
                changed(key)
            } catch {
                AlertUtil.oneButtonAlert(question: "Could not save shortcut", text: error.localizedDescription)
            }
            return
        }
        if let shortcut {
            guard let transformer = ValueTransformer(forName: NSValueTransformerName(rawValue: MASDictionaryTransformerName)),
                  let value = transformer.reverseTransformedValue(shortcut) else {
                NSLog("JRectangle could not encode shortcut %@", key)
                return
            }
            JSONPreferences.shared.set(value, forKey: key)
        } else {
            JSONPreferences.shared.set(NSNull(), forKey: key)
        }
        changed(key)
    }

    func reset(_ key: String) {
        if let profileID = BehaviorProfileContext.editingProfileID, profileID != BehaviorProfileStore.defaultProfileID {
            BehaviorProfileStore.removeOverride(for: "shortcut:\(key)", profileID: profileID)
            changed(key)
            return
        }
        JSONPreferences.shared.removeObject(forKey: key)
        changed(key)
    }

    func bind(_ key: String, action: @escaping () -> Void) {
        unbind(key)
        guard let shortcut = shortcut(for: key),
              let monitor = MASShortcutMonitor.shared() else { return }
        guard !monitor.isShortcutRegistered(shortcut) else {
            NSLog("JRectangle could not register duplicate shortcut %@", key)
            return
        }
        if monitor.register(shortcut, withAction: action) {
            bindings[key] = shortcut
        } else {
            NSLog("JRectangle could not register shortcut %@", key)
        }
    }

    func unbind(_ key: String) {
        guard let shortcut = bindings.removeValue(forKey: key) else { return }
        MASShortcutMonitor.shared()?.unregisterShortcut(shortcut)
    }
}

final class ShortcutViewBinding {
    private weak var view: MASShortcutView?
    private let key: String
    private var observer: NSObjectProtocol?
    private var profileObserver: NSObjectProtocol?
    private var overridesObserver: NSObjectProtocol?
    private var updating = false

    init(view: MASShortcutView, key: String) {
        self.view = view
        self.key = key
        refresh()
        view.shortcutValueChange = { [weak self] view in
            guard let self, !self.updating else { return }
            BehaviorProfileContext.edit(DisplayProfileSelectionModel.shared.selectedProfileID) {
                ShortcutPreferences.shared.set(view.shortcutValue, for: self.key)
            }
            self.refresh()
        }
        profileObserver = NotificationCenter.default.addObserver(forName: .displayBehaviorProfileChanged, object: nil, queue: .main) {
            [weak self] _ in self?.refresh()
        }
        overridesObserver = NotificationCenter.default.addObserver(forName: .displayBehaviorProfileOverridesChanged, object: nil, queue: .main) {
            [weak self] _ in self?.refresh()
        }
        observer = NotificationCenter.default.addObserver(forName: .shortcutPreferencesChanged, object: nil, queue: .main) {
            [weak self] notification in
            guard let self, notification.object == nil || notification.object as? String == self.key else { return }
            self.refresh()
        }
    }

    private func refresh() {
        updating = true
        let profileID = DisplayProfileSelectionModel.shared.selectedProfileID
        view?.shortcutValue = BehaviorProfileContext.withProfileID(profileID) {
            ShortcutPreferences.shared.shortcut(for: key)
        }
        let overridden = BehaviorProfileStore.override(for: "shortcut:\(key)", profileID: profileID) != nil
        view?.toolTip = overridden ? "Overrides Default. Use the profile's inheritance controls to reset." : "Inherited from Default"
        view?.wantsLayer = true
        view?.layer?.borderWidth = overridden ? 1 : 0
        view?.layer?.borderColor = overridden ? NSColor.systemBlue.cgColor : NSColor.clear.cgColor
        updating = false
    }

    deinit {
        view?.shortcutValueChange = nil
        if let observer { NotificationCenter.default.removeObserver(observer) }
        if let profileObserver { NotificationCenter.default.removeObserver(profileObserver) }
        if let overridesObserver { NotificationCenter.default.removeObserver(overridesObserver) }
    }
}
