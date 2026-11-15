/// ShortcutManager.swift

import Cocoa
import Carbon.HIToolbox
import CoreGraphics
import MASShortcut

protocol ShortcutBindingStore {
    func configure()
    func registerDefaultShortcuts(_ shortcuts: [String: MASShortcut])
    func bindShortcut(withDefaultsKey defaultsKey: String, toAction action: @escaping () -> Void)
    func breakBinding(withDefaultsKey defaultsKey: String)
}

struct MASShortcutBindingStore: ShortcutBindingStore {
    func configure() {
    }

    func registerDefaultShortcuts(_ shortcuts: [String: MASShortcut]) {
        ShortcutPreferences.shared.registerDefaults(shortcuts)
    }

    func bindShortcut(withDefaultsKey defaultsKey: String, toAction action: @escaping () -> Void) {
        ShortcutPreferences.shared.bind(defaultsKey, action: action)
    }

    func breakBinding(withDefaultsKey defaultsKey: String) {
        ShortcutPreferences.shared.unbind(defaultsKey)
    }
}

typealias ShortcutRebindScheduler = (@escaping () -> Void) -> Void

class ShortcutManager {

    let windowManager: WindowManager
    private let screenDetection: ScreenDetection
    private let bindingStore: ShortcutBindingStore
    private let mouseButtonBindingStore: MouseButtonBindingStore
    private let notificationCenter: NotificationCenter
    private let workspaceNotificationCenter: NotificationCenter
    private let shortcutsProvider: () -> [WindowAction: MASShortcut]
    private let appDisabledProvider: () -> Bool
    private let missionControlActiveProvider: () -> Bool
    private let ignoreShortcutsInMissionControlProvider: () -> Bool
    private let windowUnderCursorProvider: (MouseButtonPress) -> AccessibilityElement?
    private let scheduler: ShortcutRebindScheduler
    private let todoSessionStateChanged: (Bool) -> Void
    private let heldShortcutRepeater = HeldShortcutRepeater()
    private let desktopMoveManager = DesktopMoveManager()
    private var boundShortcutActions = Set<WindowAction>()
    private var shortcutIdentities = [WindowAction: ShortcutCycle.ShortcutIdentity]()
    private var currentSpaceSwitcherShortcutIdentity: ShortcutCycle.ShortcutIdentity?
    private var desktopMoveShortcutIdentities = [String: ShortcutCycle.ShortcutIdentity]()
    private var isUpdatingShortcutBindings = false
    private var shortcutsSuspendedForRecording = false
    private var sessionIsActive: Bool
    private var sessionRebindPending = false
    private var sessionGeneration = 0

    init(
        windowManager: WindowManager,
        screenDetection: ScreenDetection = ScreenDetection(),
        bindingStore: ShortcutBindingStore = MASShortcutBindingStore(),
        mouseButtonBindingStore: MouseButtonBindingStore = MouseButtonShortcutMonitor(),
        notificationCenter: NotificationCenter = .default,
        workspaceNotificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        shortcutsProvider: @escaping () -> [WindowAction: MASShortcut] = { ShortcutCycle.shortcutsByAction() },
        activeStateProvider: () -> Bool = {
            let session = CGSessionCopyCurrentDictionary() as? [String: Any]
            return session?[kCGSessionOnConsoleKey] as? Bool ?? true
        },
        appDisabledProvider: @escaping () -> Bool = { ApplicationToggle.shortcutsDisabled },
        missionControlActiveProvider: @escaping () -> Bool = { WindowAnimationInterruptionPolicy.missionControlActive },
        ignoreShortcutsInMissionControlProvider: @escaping () -> Bool = { Defaults.ignoreShortcutsInMissionControl.enabled },
        windowUnderCursorProvider: @escaping (MouseButtonPress) -> AccessibilityElement? = { press in
            AccessibilityElement.getWindowElementUnderCursor(at: press.location, eventWindowID: press.windowId)
        },
        scheduler: @escaping ShortcutRebindScheduler = { action in
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100), execute: action)
        },
        todoSessionStateChanged: @escaping (Bool) -> Void = { isActive in
            TodoManager.setShortcutBindingsSessionActive(isActive)
            StackBadgeManager.setShortcutBindingsSessionActive(isActive)
        }
    ) {
        self.windowManager = windowManager
        self.screenDetection = screenDetection
        self.bindingStore = bindingStore
        self.mouseButtonBindingStore = mouseButtonBindingStore
        self.notificationCenter = notificationCenter
        self.workspaceNotificationCenter = workspaceNotificationCenter
        self.shortcutsProvider = shortcutsProvider
        self.appDisabledProvider = appDisabledProvider
        self.missionControlActiveProvider = missionControlActiveProvider
        self.ignoreShortcutsInMissionControlProvider = ignoreShortcutsInMissionControlProvider
        self.windowUnderCursorProvider = windowUnderCursorProvider
        self.scheduler = scheduler
        self.todoSessionStateChanged = todoSessionStateChanged
        self.sessionIsActive = activeStateProvider()

        bindingStore.configure()
        todoSessionStateChanged(sessionIsActive)

        registerDefaults()

        bindShortcuts()

        subscribeAll(selector: #selector(windowActionTriggered))

        notificationCenter.addObserver(self, selector: #selector(defaultShortcutsChanged), name: .changeDefaults, object: nil)
        notificationCenter.addObserver(self, selector: #selector(userDefaultsChanged), name: UserDefaults.didChangeNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(shortcutPreferencesChanged), name: .shortcutPreferencesChanged, object: nil)
        notificationCenter.addObserver(self, selector: #selector(shortcutPreferencesChanged), name: .activeDisplayProfileChanged, object: nil)
        notificationCenter.addObserver(self, selector: #selector(shortcutPreferencesChanged), name: .displayBehaviorProfileOverridesChanged, object: nil)
        notificationCenter.addObserver(self, selector: #selector(shortcutRecordingChanged), name: .shortcutRecording, object: nil)
        workspaceNotificationCenter.addObserver(self, selector: #selector(sessionDidResignActive), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        workspaceNotificationCenter.addObserver(self, selector: #selector(sessionDidBecomeActive), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
    }

    public func reloadFromDefaults() {
        unsubscribeWindowActions()
        unbindShortcuts()
        registerDefaults()
        bindShortcuts()
        subscribeAll(selector: #selector(windowActionTriggered))
    }

    public func bindShortcuts() {
        let previous = BehaviorProfileContext.setCurrentProfileID(BehaviorProfileContext.activeProfileID ?? BehaviorProfileStore.defaultProfileID)
        defer { _ = BehaviorProfileContext.setCurrentProfileID(previous) }
        guard sessionIsActive,
              !sessionRebindPending,
              !shortcutsSuspendedForRecording,
              !appDisabledProvider()
        else { return }

        let shortcutsByAction = shortcutsProvider()
        let groups = ShortcutCycle.groups(shortcutsByAction: shortcutsByAction)

        shortcutIdentities = ShortcutCycle.shortcutIdentities(shortcutsByAction: shortcutsByAction)

        for group in groups {
            let representativeAction = group.representativeAction

            if MouseButtonShortcut.isMouseButton(group.shortcut) {
                mouseButtonBindingStore.bindShortcut(group.shortcut, toAction: { [weak self] press in
                    self?.executeMouseButtonShortcut(group, press: press)
                })
                continue
            }

            boundShortcutActions.insert(representativeAction)

            if group.isCycle {
                bindingStore.bindShortcut(withDefaultsKey: representativeAction.name, toAction: { [weak self] in
                    self?.executeCycle(group)
                })
            } else if ShortcutRepeatPolicy.shouldRepeat(representativeAction) {
                bindingStore.bindShortcut(withDefaultsKey: representativeAction.name, toAction: { [weak self] in
                    self?.heldShortcutRepeater.start(shortcut: group.shortcut) {
                        representativeAction.post()
                    }
                })
            } else {
                bindingStore.bindShortcut(withDefaultsKey: representativeAction.name, toAction: representativeAction.post)
            }
        }

        if let shortcut = ShortcutCycle.shortcut(forDefaultsKey: CurrentSpaceWindowSwitcher.shortcutDefaultsKey) {
            currentSpaceSwitcherShortcutIdentity = ShortcutCycle.ShortcutIdentity(shortcut)
            bindingStore.bindShortcut(withDefaultsKey: CurrentSpaceWindowSwitcher.shortcutDefaultsKey) {
                CurrentSpaceWindowSwitcher.cycle()
            }
        } else {
            currentSpaceSwitcherShortcutIdentity = nil
        }
        desktopMoveShortcutIdentities = desktopMoveIdentities()
        for direction in DesktopMoveManager.Direction.allCases where desktopMoveShortcutIdentities[direction.defaultsKey] != nil {
            bindingStore.bindShortcut(withDefaultsKey: direction.defaultsKey) { [weak self] in
                guard let self else { return }
                if self.ignoreShortcutsInMissionControlProvider() && self.missionControlActiveProvider() {
                    NSSound.beep()
                    return
                }
                self.desktopMoveManager.move(direction)
            }
        }
    }

    public func unbindShortcuts() {
        isUpdatingShortcutBindings = true
        defer { isUpdatingShortcutBindings = false }

        for action in Set(WindowAction.active).union(boundShortcutActions) {
            bindingStore.breakBinding(withDefaultsKey: action.name)
        }

        heldShortcutRepeater.cancel()
        desktopMoveManager.cancel()
        for direction in DesktopMoveManager.Direction.allCases {
            bindingStore.breakBinding(withDefaultsKey: direction.defaultsKey)
        }
        desktopMoveShortcutIdentities.removeAll()
        bindingStore.breakBinding(withDefaultsKey: CurrentSpaceWindowSwitcher.shortcutDefaultsKey)
        currentSpaceSwitcherShortcutIdentity = nil
        boundShortcutActions.removeAll()
        mouseButtonBindingStore.breakAllBindings()
    }

    public func getKeyEquivalent(action: WindowAction) -> (String?, NSEvent.ModifierFlags)? {
        guard let masShortcut = ShortcutCycle.shortcut(for: action),
              !MouseButtonShortcut.isMouseButton(masShortcut)
        else { return nil }
        return (masShortcut.keyCodeStringForKeyEquivalent, masShortcut.modifierFlags)
    }

    deinit {
        notificationCenter.removeObserver(self)
        workspaceNotificationCenter.removeObserver(self)
        heldShortcutRepeater.cancel()
    }

    private func registerDefaults() {

        var defaultShortcuts = WindowAction.active.reduce(into: [String: MASShortcut]()) { dict, windowAction in
            guard let defaultShortcut = Defaults.alternateDefaultShortcuts.enabled
                ? windowAction.alternateDefault
                : windowAction.spectacleDefault
            else { return }
            let shortcut = MASShortcut(keyCode: defaultShortcut.keyCode, modifierFlags: NSEvent.ModifierFlags(rawValue: defaultShortcut.modifierFlags))
            dict[windowAction.name] = shortcut
        }
        defaultShortcuts[CurrentSpaceWindowSwitcher.shortcutDefaultsKey] = MASShortcut(
            keyCode: Int(kVK_Tab),
            modifierFlags: .option
        )

        bindingStore.registerDefaultShortcuts(defaultShortcuts)
    }

    @objc private func sessionDidResignActive(_ notification: Notification) {
        guard sessionIsActive else { return }

        sessionIsActive = false
        sessionRebindPending = false
        sessionGeneration &+= 1
        unbindShortcuts()
        todoSessionStateChanged(false)
    }

    @objc private func sessionDidBecomeActive(_ notification: Notification) {
        guard !sessionIsActive else { return }

        sessionIsActive = true
        sessionRebindPending = true
        sessionGeneration &+= 1
        let generation = sessionGeneration

        scheduler { [weak self] in
            guard let self,
                  self.sessionIsActive,
                  self.sessionRebindPending,
                  self.sessionGeneration == generation
            else { return }

            self.sessionRebindPending = false
            self.unbindShortcuts()
            self.bindShortcuts()
            self.todoSessionStateChanged(true)
        }
    }

    @objc func windowActionTriggered(notification: NSNotification) {
        guard let parameters = notification.object as? ExecutionParameters else { return }
        execute(parameters)
    }

    private func execute(_ originalParameters: ExecutionParameters) {
        var parameters = originalParameters
        let screen = originalParameters.screen
            ?? screenDetection.detectScreens(using: originalParameters.windowElement ?? AccessibilityElement.getFrontWindowElement())?.currentScreen
        let previousProfile = BehaviorProfileContext.setCurrentProfileID(screen?.behaviorProfileID)
        defer { _ = BehaviorProfileContext.setCurrentProfileID(previousProfile) }
        // Snap previews use completion to dismiss after placement finishes. If this
        // method returns before handing off to WindowManager, finish that cleanup here.
        // After handoff, WindowManager owns completion (including animated moves);
        // running it here as well would dismiss the preview before the move finishes.
        var completionHandledByWindowManager = false
        defer { if !completionHandledByWindowManager { originalParameters.completion?() } }

        // Mission Control leaves the previous app frontmost, so a shortcut would
        // move the window behind the overview and distort its thumbnail (#1739).
        // Opt out with: defaults write com.knollsoft.Rectangle ignoreShortcutsInMissionControl -bool false
        if parameters.source == .keyboardShortcut,
           ignoreShortcutsInMissionControlProvider(),
           missionControlActiveProvider() {
            Logger.log("Ignoring \(parameters.action.name) while Mission Control is active")
            return
        }

        Notification.Name.windowActionWillExecute.post(object: parameters)

        if MultiWindowManager.execute(parameters: parameters) {
            return
        }

        if TodoManager.execute(parameters: parameters) {
            return
        }

        // Check if repeat cycles displays
        if Defaults.subsequentExecutionMode.value == .cycleMonitor,
           parameters.source != .titleBar, parameters.source != .newWindow,
           parameters.action.classification != .size,
           parameters.action.classification != .display {
            guard let windowElement = parameters.windowElement ?? AccessibilityElement.getFrontWindowElement(),
                  let windowId = parameters.windowId ?? windowElement.getWindowId()
            else {
                NSSound.beep()
                return
            }

            if isRepeatAction(parameters: parameters, windowElement: windowElement, windowId: windowId),
               RepeatedMaximizeRestore.restoreRect(for: parameters.action, windowId: windowId, windowRect: windowManager.logicalFrame(for: windowElement)) == nil {
                if let screen = screenDetection.detectScreens(using: windowElement)?.adjacentScreens?.next{
                    parameters = ExecutionParameters(parameters.action, updateRestoreRect: parameters.updateRestoreRect, screen: screen, windowElement: windowElement, windowId: windowId, source: parameters.source, preservesFocus: parameters.preservesFocus, completion: parameters.completion, cancellation: parameters.cancellation)
                    // Bypass any other subsequent action by removing the last action
                    AppDelegate.windowHistory.lastRectangleActions.removeValue(forKey: windowId)
                }
            }
        }

        completionHandledByWindowManager = true
        windowManager.execute(parameters)
    }

    /// Mouse buttons work on the focused window, like keys, unless they've
    /// been set to work on the window under the pointer.
    private func executeMouseButtonShortcut(_ group: ShortcutCycle.Group, press: MouseButtonPress) {
        guard Defaults.mouseButtonShortcutsUseWindowUnderCursor.enabled else {
            if group.isCycle {
                executeCycle(group)
            } else {
                execute(ExecutionParameters(group.representativeAction))
            }
            return
        }

        guard let windowElement = windowUnderCursorProvider(press) else {
            NSSound.beep()
            return
        }

        if group.isCycle {
            executeCycle(group, windowUnderCursor: windowElement)
        } else {
            execute(ExecutionParameters(group.representativeAction, windowElement: windowElement,
                                        windowId: windowElement.getWindowId(), preservesFocus: true))
        }
    }

    private func executeCycle(_ group: ShortcutCycle.Group, windowUnderCursor: AccessibilityElement? = nil) {
        guard let windowElement = windowUnderCursor ?? AccessibilityElement.getFrontWindowElement(),
              let windowId = windowElement.getWindowId()
        else {
            NSSound.beep()
            return
        }

        let logicalFrame = windowManager.logicalFrame(for: windowElement)
        let lastAction = AppDelegate.windowHistory.lastRectangleActions[windowId]
        if ShortcutCycle.isStale(lastAction: lastAction, currentWindowRect: logicalFrame) {
            AppDelegate.windowHistory.lastRectangleActions.removeValue(forKey: windowId)
        }

        let selectedAction = ShortcutCycle.action(
            in: group,
            lastAction: AppDelegate.windowHistory.lastRectangleActions[windowId],
            currentWindowRect: logicalFrame
        )
        execute(ExecutionParameters(selectedAction, windowElement: windowElement, windowId: windowId,
                                    preservesFocus: windowUnderCursor != nil))
    }

    @objc private func defaultShortcutsChanged() {
        registerDefaults()
        reloadShortcutBindingsIfNeeded()
    }

    @objc private func userDefaultsChanged(_ notification: Notification) {
        reloadShortcutBindingsIfNeeded()
    }

    @objc private func shortcutPreferencesChanged(_ notification: Notification) {
        let previous = BehaviorProfileContext.setCurrentProfileID(BehaviorProfileContext.activeProfileID ?? BehaviorProfileStore.defaultProfileID)
        defer { _ = BehaviorProfileContext.setCurrentProfileID(previous) }
        reloadShortcutBindingsIfNeeded()
        TodoManager.registerUnregisterToggleShortcut()
        TodoManager.registerUnregisterReflowShortcut()
        StackBadgeManager.reevaluateToggleShortcut()
    }

    private func reloadShortcutBindingsIfNeeded() {
        guard !isUpdatingShortcutBindings && !shortcutsSuspendedForRecording else { return }

        MASShortcutMigration.syncRenamedSideShortcutAliases()
        let currentShortcuts = shortcutsProvider()
        let currentIdentities = ShortcutCycle.shortcutIdentities(shortcutsByAction: currentShortcuts)
        let currentSpaceSwitcherIdentity = ShortcutCycle.shortcut(
            forDefaultsKey: CurrentSpaceWindowSwitcher.shortcutDefaultsKey
        ).map(ShortcutCycle.ShortcutIdentity.init)
        guard currentIdentities != shortcutIdentities
                || currentSpaceSwitcherIdentity != currentSpaceSwitcherShortcutIdentity
                || desktopMoveIdentities() != desktopMoveShortcutIdentities
        else { return }

        unbindShortcuts()
        if !appDisabledProvider() {
            bindShortcuts()
        } else {
            shortcutIdentities = currentIdentities
        }

    }

    private func desktopMoveIdentities() -> [String: ShortcutCycle.ShortcutIdentity] {
        DesktopMoveManager.Direction.allCases.reduce(into: [:]) { identities, direction in
            if let shortcut = ShortcutCycle.shortcut(forDefaultsKey: direction.defaultsKey) {
                identities[direction.defaultsKey] = ShortcutCycle.ShortcutIdentity(shortcut)
            }
        }
    }

    @objc private func shortcutRecordingChanged(_ notification: Notification) {
        guard let isRecording = notification.object as? Bool else { return }

        if isRecording {
            guard !shortcutsSuspendedForRecording else { return }
            shortcutsSuspendedForRecording = true
            unbindShortcuts()
        } else {
            guard shortcutsSuspendedForRecording else { return }
            shortcutsSuspendedForRecording = false
            if !appDisabledProvider() {
                bindShortcuts()
            } else {
                let currentShortcuts = shortcutsProvider()
                shortcutIdentities = ShortcutCycle.shortcutIdentities(shortcutsByAction: currentShortcuts)
            }
        }

        TodoManager.setShortcutBindingsSuspended(isRecording)
        StackBadgeManager.setShortcutBindingsSuspended(isRecording)
    }

    private func isRepeatAction(parameters: ExecutionParameters, windowElement: AccessibilityElement, windowId: CGWindowID) -> Bool {

        if parameters.action == .maximize {
            if screenDetection.detectScreens(using: windowElement)?.currentScreen.visibleFrame.size == windowManager.logicalFrame(for: windowElement).size {
                return true
            }
        }
        if parameters.action == AppDelegate.windowHistory.lastRectangleActions[windowId]?.action {
            return true
        }
        return false
    }

    private func subscribe(notification: WindowAction, selector: Selector) {
        notificationCenter.addObserver(self, selector: selector, name: notification.notificationName, object: nil)
    }

    private func unsubscribeWindowActions() {
        for windowAction in WindowAction.active {
            notificationCenter.removeObserver(self, name: windowAction.notificationName, object: nil)
        }
    }

    private func subscribeAll(selector: Selector) {
        for windowAction in WindowAction.active {
            subscribe(notification: windowAction, selector: selector)
        }
    }
}

struct ShortcutCycle {

    struct ShortcutIdentity: Hashable {
        let keyCode: Int
        let modifierFlags: UInt

        init(_ shortcut: MASShortcut) {
            keyCode = shortcut.keyCode
            modifierFlags = shortcut.modifierFlags.rawValue
        }
    }

    struct Group {
        let shortcut: MASShortcut
        let actions: [WindowAction]

        var representativeAction: WindowAction { actions[0] }
        var isCycle: Bool { actions.count > 1 }

        func action(after previousAction: WindowAction?) -> WindowAction {
            guard let previousAction,
                  let index = actions.firstIndex(of: previousAction)
            else {
                return representativeAction
            }

            return actions[(index + 1) % actions.count]
        }
    }

    static func shortcut(for action: WindowAction, userDefaults: UserDefaults? = nil) -> MASShortcut? {
        return shortcut(forDefaultsKey: action.name, userDefaults: userDefaults)
    }

    static func shortcut(forDefaultsKey defaultsKey: String, userDefaults: UserDefaults? = nil) -> MASShortcut? {
        guard let userDefaults else { return ShortcutPreferences.shared.shortcut(for: defaultsKey) }
        guard let shortcutDict = userDefaults.dictionary(forKey: defaultsKey),
              let dictTransformer = ValueTransformer(forName: NSValueTransformerName(rawValue: MASDictionaryTransformerName)),
              let shortcut = dictTransformer.transformedValue(shortcutDict) as? MASShortcut
        else {
            return nil
        }

        return shortcut
    }

    static func shortcutsByAction(actions: [WindowAction] = WindowAction.active, userDefaults: UserDefaults? = nil) -> [WindowAction: MASShortcut] {
        actions.reduce(into: [WindowAction: MASShortcut]()) { dict, action in
            if let shortcut = shortcut(for: action, userDefaults: userDefaults) {
                dict[action] = shortcut
            }
        }
    }

    static func shortcutIdentities(shortcutsByAction: [WindowAction: MASShortcut]) -> [WindowAction: ShortcutIdentity] {
        shortcutsByAction.reduce(into: [WindowAction: ShortcutIdentity]()) { dict, item in
            dict[item.key] = ShortcutIdentity(item.value)
        }
    }

    static func groups(actions: [WindowAction] = WindowAction.active,
                       shortcutsByAction: [WindowAction: MASShortcut]) -> [Group] {
        var groups = [Group]()
        var groupIndexesByShortcut = [ShortcutIdentity: Int]()

        for action in actions {
            guard let shortcut = shortcutsByAction[action] else { continue }

            let identity = ShortcutIdentity(shortcut)
            if let groupIndex = groupIndexesByShortcut[identity] {
                let group = groups[groupIndex]
                groups[groupIndex] = Group(shortcut: group.shortcut, actions: group.actions + [action])
            } else {
                groupIndexesByShortcut[identity] = groups.count
                groups.append(Group(shortcut: shortcut, actions: [action]))
            }
        }

        return groups
    }

    static func action(in group: Group, lastAction: RectangleAction?, currentWindowRect: CGRect?) -> WindowAction {
        guard !isStale(lastAction: lastAction, currentWindowRect: currentWindowRect) else {
            return group.representativeAction
        }

        return group.action(after: lastAction?.action)
    }

    static func isStale(lastAction: RectangleAction?, currentWindowRect: CGRect?) -> Bool {
        guard let lastAction, let currentWindowRect else { return false }
        return currentWindowRect != lastAction.rect
    }
}

enum ShortcutRepeatPolicy {
    static func shouldRepeat(_ action: WindowAction) -> Bool {
        switch action {
        case .moveLeft, .moveRight, .moveUp, .moveDown,
             .larger, .smaller, .largerWidth, .smallerWidth, .largerHeight, .smallerHeight:
            return true
        default:
            return false
        }
    }
}

private final class HeldShortcutRepeater {
    private static let initialDelay: TimeInterval = 0.35
    private static let repeatInterval: TimeInterval = 0.1
    private static let pollInterval: DispatchTimeInterval = .milliseconds(20)

    private var shortcut: MASShortcut?
    private var identity: ShortcutCycle.ShortcutIdentity?
    private var timer: DispatchSourceTimer?
    private var startedAt: TimeInterval = 0
    private var lastRepeatAt: TimeInterval = 0
    private var repeatAction: (() -> Void)?

    func start(shortcut: MASShortcut, action: @escaping () -> Void) {
        let newIdentity = ShortcutCycle.ShortcutIdentity(shortcut)
        guard identity != newIdentity else { return }

        cancel()
        self.shortcut = shortcut
        identity = newIdentity
        repeatAction = action
        startedAt = ProcessInfo.processInfo.systemUptime
        lastRepeatAt = startedAt
        action()

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + Self.pollInterval, repeating: Self.pollInterval)
        timer.setEventHandler { [weak self] in self?.repeatIfHeld() }
        self.timer = timer
        timer.resume()
    }

    func cancel() {
        timer?.setEventHandler {}
        timer?.cancel()
        timer = nil
        shortcut = nil
        identity = nil
        repeatAction = nil
    }

    private func repeatIfHeld() {
        guard let shortcut, Self.isHeld(shortcut) else {
            cancel()
            return
        }

        let now = ProcessInfo.processInfo.systemUptime
        guard now - startedAt >= Self.initialDelay,
              now - lastRepeatAt >= Self.repeatInterval
        else { return }

        lastRepeatAt = now
        repeatAction?()
    }

    private static func isHeld(_ shortcut: MASShortcut) -> Bool {
        let state = CGEventSourceStateID.hidSystemState
        guard CGEventSource.keyState(state, key: CGKeyCode(truncatingIfNeeded: shortcut.keyCode)) else {
            return false
        }

        let currentFlags = CGEventSource.flagsState(state)
        let requiredModifiers = shortcut.modifierFlags
        let modifiers: [(NSEvent.ModifierFlags, CGEventFlags)] = [
            (.command, .maskCommand),
            (.option, .maskAlternate),
            (.control, .maskControl),
            (.shift, .maskShift),
            (.function, .maskSecondaryFn)
        ]
        return modifiers.allSatisfy { modifier, eventFlag in
            !requiredModifiers.contains(modifier) || currentFlags.contains(eventFlag)
        }
    }
}
