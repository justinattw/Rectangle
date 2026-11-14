import Cocoa
import Carbon

/// Moves a window using the same drag and Space shortcut a user would use.
final class DesktopMoveManager {
    enum Direction: CaseIterable {
        case previous, next

        var defaultsKey: String {
            switch self {
            case .previous: return "moveWindowToPreviousDesktop"
            case .next: return "moveWindowToNextDesktop"
            }
        }

        var title: String {
            switch self {
            case .previous: return String(localized: "Previous Desktop (Experimental)")
            case .next: return String(localized: "Next Desktop (Experimental)")
            }
        }

        var icon: String { self == .previous ? "arrow.left.square" : "arrow.right.square" }
        var keyCode: Int { self == .previous ? 123 : 124 }
        var symbolicHotKey: String { self == .previous ? "79" : "81" }
    }

    static var defaultsKeys: [String] { Direction.allCases.map(\.defaultsKey) }
    static let eventMarker: Int64 = 0x4a524453

    private var generation = 0
    private var busy = false
    private var mouseHeld = false
    private var originalPosition: CGPoint?
    private var grabPosition: CGPoint?
    private var process: Process?
    private var mouseUpEvent: CGEvent?
    private var mouseDraggedEvent: CGEvent?

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillTerminate),
                                               name: NSApplication.willTerminateNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func applicationWillTerminate() {
        cancel()
    }

    func move(_ direction: Direction) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !busy else { NSSound.beep(); return }
        guard AXIsProcessTrusted() else {
            fail("Accessibility permission is required.")
            return
        }
        guard Self.systemShortcutIsSupported(direction) else {
            fail("Enable the default Control-Left and Control-Right shortcuts in System Settings > Keyboard > Keyboard Shortcuts > Mission Control.")
            return
        }
        guard let window = AccessibilityElement.getFrontWindowElement(),
              window.isStandardWindow == true, window.isFullScreen == false else {
            fail("Select a standard, non-full-screen window first.")
            return
        }

        busy = true
        generation += 1
        let token = generation
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", "tell application \"System Events\" to count processes"]
        task.standardOutput = FileHandle.nullDevice
        let errors = Pipe()
        task.standardError = errors
        task.terminationHandler = { process in
            let detail = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            DispatchQueue.main.async {
                guard self.busy, self.generation == token else { return }
                self.process = nil
                guard process.terminationStatus == 0 else {
                    self.finish()
                    self.fail("System Events could not be accessed. \(detail)")
                    return
                }
                self.waitForKeys(direction, window: window, token: token, deadline: ProcessInfo.processInfo.systemUptime + 2)
            }
        }
        process = task
        do {
            try task.run()
        } catch {
            finish()
            fail("Could not request System Events access: \(error.localizedDescription)")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
            guard self.busy, self.generation == token, task.isRunning else { return }
            task.terminate()
            self.finish()
            self.fail("The System Events permission request timed out.")
        }
    }

    func cancel() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard busy else { return }
        if let process, process.isRunning { process.terminate() }
        releaseMouse(drag: false)
        finish()
    }

    private func waitForKeys(_ direction: Direction, window: AccessibilityElement, token: Int, deadline: TimeInterval) {
        guard busy, generation == token else { return }
        let flags = CGEventSource.flagsState(.hidSystemState)
        let modifiers: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]
        if !flags.intersection(modifiers).isEmpty {
            guard ProcessInfo.processInfo.systemUptime < deadline else {
                finish()
                fail("Release the shortcut keys before moving the window.")
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.waitForKeys(direction, window: window, token: token, deadline: deadline)
            }
            return
        }
        guard !CGEventSource.buttonState(.hidSystemState, button: .left),
              !CGEventSource.buttonState(.hidSystemState, button: .right),
              !CGEventSource.buttonState(.hidSystemState, button: .center) else {
            finish()
            fail("Release the mouse buttons before moving the window.")
            return
        }
        guard AccessibilityElement.getFrontWindowElement() == window else {
            finish()
            fail("The focused window changed. Select the window and try again.")
            return
        }
        guard let point = Self.grabPoint(for: window),
              let cursor = CGEvent(source: nil)?.location else {
            finish()
            fail("Could not find a safe, visible title-bar area on the focused window.")
            return
        }
        guard let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown,
                                 mouseCursorPosition: point, mouseButton: .left),
              let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp,
                               mouseCursorPosition: point, mouseButton: .left),
              let dragged = CGEvent(mouseEventSource: source, mouseType: .leftMouseDragged,
                                    mouseCursorPosition: point, mouseButton: .left) else {
            finish()
            fail("Could not create the mouse event.")
            return
        }

        originalPosition = cursor
        grabPosition = point
        mouseUpEvent = up
        mouseDraggedEvent = dragged
        down.setIntegerValueField(.eventSourceUserData, value: Self.eventMarker)
        up.setIntegerValueField(.eventSourceUserData, value: Self.eventMarker)
        dragged.setIntegerValueField(.eventSourceUserData, value: Self.eventMarker)
        CGWarpMouseCursorPosition(point)
        down.post(tap: .cghidEventTap)
        mouseHeld = true

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", "tell application \"System Events\" to key code \(direction.keyCode) using control down"]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        task.terminationHandler = { process in
            DispatchQueue.main.async {
                guard self.busy, self.generation == token else { return }
                if process.terminationStatus != 0 {
                    self.releaseMouse(drag: false)
                    self.finish()
                    self.fail("System Events could not switch desktops. Check Automation permission and Mission Control shortcuts.")
                    return
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    guard self.busy, self.generation == token else { return }
                    self.releaseMouse(drag: true)
                    self.finish()
                }
            }
        }
        process = task
        do {
            try task.run()
        } catch {
            releaseMouse(drag: false)
            finish()
            fail("Could not start System Events: \(error.localizedDescription)")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            guard self.busy, self.generation == token, task.isRunning else { return }
            task.terminate()
            self.releaseMouse(drag: false)
            self.finish()
            self.fail("Switching desktops timed out.")
        }
    }

    private func releaseMouse(drag: Bool) {
        guard mouseHeld else { return }
        mouseHeld = false
        guard let up = mouseUpEvent, let dragged = mouseDraggedEvent else { return }
        let current = CGEvent(source: nil)?.location ?? grabPosition ?? .zero
        let unmoved = grabPosition.map { hypot(current.x - $0.x, current.y - $0.y) < 2 } ?? false
        let end = drag && unmoved ? CGPoint(x: current.x + 3, y: current.y) : current
        if drag && unmoved {
            dragged.location = end
            dragged.post(tap: .cghidEventTap)
        }
        up.location = end
        up.post(tap: .cghidEventTap)
        if unmoved, let originalPosition { CGWarpMouseCursorPosition(originalPosition) }
    }

    private func finish() {
        busy = false
        generation += 1
        originalPosition = nil
        grabPosition = nil
        process = nil
        mouseUpEvent = nil
        mouseDraggedEvent = nil
    }

    private func fail(_ message: String) {
        NSSound.beep()
        Logger.log("Experimental desktop move: \(message)")
        let alert = NSAlert()
        alert.messageText = String(localized: "Could not move window to desktop")
        alert.informativeText = message
        alert.addButton(withTitle: String(localized: "OK"))
        alert.runModal()
    }

    static func systemShortcutIsSupported(_ direction: Direction) -> Bool {
        guard let settings = CFPreferencesCopyAppValue("AppleSymbolicHotKeys" as CFString, "com.apple.symbolichotkeys" as CFString) as? [String: Any] else { return false }
        return systemShortcutIsSupported(direction, settings: settings)
    }

    static func systemShortcutIsSupported(_ direction: Direction, settings: [String: Any]) -> Bool {
        guard let item = settings[direction.symbolicHotKey] as? [String: Any],
              let enabled = item["enabled"] as? Bool, enabled,
              let value = item["value"] as? [String: Any],
              let parameters = value["parameters"] as? [Int], parameters.count >= 3 else { return false }
        let modifiers = parameters[2] & Int(CGEventFlags.maskCommand.rawValue | CGEventFlags.maskControl.rawValue
                                          | CGEventFlags.maskAlternate.rawValue | CGEventFlags.maskShift.rawValue)
        return parameters[1] == direction.keyCode && modifiers == Int(CGEventFlags.maskControl.rawValue)
    }

    private static func grabPoint(for window: AccessibilityElement) -> CGPoint? {
        guard let titleBar = window.titleBarFrame, !titleBar.isEmpty, !titleBar.isInfinite else { return nil }
        let visibleFrames = NSScreen.screens.map { $0.visibleFrame.screenFlipped }
        for offset in stride(from: 80.0, through: Double(titleBar.width - 10), by: 10) {
            let point = CGPoint(x: titleBar.minX + offset, y: titleBar.midY)
            guard visibleFrames.contains(where: { $0.contains(point) && $0.contains(CGPoint(x: point.x + 3, y: point.y)) }),
                  let hit = AccessibilityElement(point)?.getSelfOrChildElementRecursively(point),
                  hit.windowElement == window else { continue }
            if hit.isWindow == true || hit.isToolbar == true || hit.isGroup == true
                || hit.isTitleBarSpacer(in: titleBar) { return point }
        }
        return nil
    }
}
