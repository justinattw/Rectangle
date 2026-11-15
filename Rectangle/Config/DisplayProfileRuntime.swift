import AppKit

extension Notification.Name {
    static let activeDisplayProfileChanged = Notification.Name("activeDisplayProfileChanged")
}

/// Tracks the focused window, not the profile being edited in Settings.
final class DisplayProfileRuntime {
    static let shared = DisplayProfileRuntime()
    private var observer: AXObserver?
    private var observedWindow: AXUIElement?
    private var tokens: [NSObjectProtocol] = []

    func start() {
        guard tokens.isEmpty else { return }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification,
                     NSWorkspace.sessionDidBecomeActiveNotification] {
            tokens.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.observeApplication()
            })
        }
        tokens.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                              object: nil, queue: .main) { [weak self] _ in
            BehaviorProfileStore.registerProfiles(NSScreen.screens.map(\.behaviorProfileID))
            BehaviorProfileStore.removeRedundantOverrides()
            self?.refresh()
        })
        BehaviorProfileStore.registerProfiles(NSScreen.screens.map(\.behaviorProfileID))
        BehaviorProfileStore.removeRedundantOverrides()
        observeApplication()
    }

    private func observeApplication() {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observer = nil
        observedWindow = nil
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return }
        let callback: AXObserverCallback = { _, _, _, context in
            guard let context else { return }
            Unmanaged<DisplayProfileRuntime>.fromOpaque(context).takeUnretainedValue().refresh()
        }
        var newObserver: AXObserver?
        let result = AXObserverCreate(pid, callback, &newObserver)
        guard result == .success, let newObserver else {
            Logger.log("Could not observe display profile focus changes: \(result.rawValue)")
            refresh()
            return
        }
        observer = newObserver
        addNotification(kAXFocusedWindowChangedNotification, element: AXUIElementCreateApplication(pid))
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(newObserver), .commonModes)
        refresh()
    }

    private func addNotification(_ name: String, element: AXUIElement) {
        guard let observer else { return }
        let result = AXObserverAddNotification(observer, element, name as CFString, Unmanaged.passUnretained(self).toOpaque())
        if result != .success && result != .notificationAlreadyRegistered && result != .notificationUnsupported {
            Logger.log("Could not observe \(name) for display profiles: \(result.rawValue)")
        }
    }

    private func refresh() {
        let window = AccessibilityElement.getFrontWindowElement()
        let element = window?.axElement
        if let observer, let previous = observedWindow,
           element.map({ !CFEqual($0, previous) }) ?? true {
            for name in [kAXMovedNotification, kAXResizedNotification] {
                AXObserverRemoveNotification(observer, previous, name as CFString)
            }
            observedWindow = nil
        }
        if observedWindow == nil, let element {
            observedWindow = element
            for name in [kAXMovedNotification, kAXResizedNotification] {
                addNotification(name, element: element)
            }
        }
        let profileID = ScreenDetection().detectScreens(using: window)?.currentScreen.behaviorProfileID
        guard BehaviorProfileContext.activeProfileID != profileID else { return }
        BehaviorProfileContext.activeProfileID = profileID
        Notification.Name.activeDisplayProfileChanged.post()
    }
}
