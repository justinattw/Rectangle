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
            NotificationCenter.default.post(name: .shortcutPreferencesChanged, object: nil)
        }
    }

    private func changed(_ key: String?) {
        guard batchDepth == 0 else { return }
        NotificationCenter.default.post(name: .shortcutPreferencesChanged, object: key)
    }

    func registerDefaults(_ shortcuts: [String: MASShortcut]) {
        defaults = shortcuts
        changed(nil)
    }

    func shortcut(for key: String) -> MASShortcut? {
        guard let value = JSONPreferences.shared.object(forKey: key) else { return defaults[key] }
        guard let dictionary = value as? [String: Any],
              let transformer = ValueTransformer(forName: NSValueTransformerName(rawValue: MASDictionaryTransformerName))
        else { return nil }
        return transformer.transformedValue(dictionary) as? MASShortcut
    }

    func set(_ shortcut: MASShortcut?, for key: String) {
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
    private var updating = false

    init(view: MASShortcutView, key: String) {
        self.view = view
        self.key = key
        refresh()
        view.shortcutValueChange = { [weak self] view in
            guard let self, !self.updating else { return }
            ShortcutPreferences.shared.set(view.shortcutValue, for: self.key)
        }
        observer = NotificationCenter.default.addObserver(forName: .shortcutPreferencesChanged, object: nil, queue: .main) {
            [weak self] notification in
            guard let self, notification.object == nil || notification.object as? String == self.key else { return }
            self.refresh()
        }
    }

    private func refresh() {
        updating = true
        view?.shortcutValue = ShortcutPreferences.shared.shortcut(for: key)
        updating = false
    }

    deinit {
        view?.shortcutValueChange = nil
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }
}
