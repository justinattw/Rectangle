/// Defaults.swift

import Cocoa

class Defaults {
    static let launchOnLogin = BoolDefault(key: "launchOnLogin")
    static let disabledApps = JSONDefault<Set<String>>(key: "disabledApps")
    static let hideMenuBarIcon = BoolDefault(key: "hideMenubarIcon")
    static let alternateDefaultShortcuts = BoolDefault(key: "alternateDefaultShortcuts") // switch to magnet defaults
    static let subsequentExecutionMode = SubsequentExecutionDefault()
    static let tileColumnsMaxWindows = PositiveIntDefault(key: "tileColumnsMaxWindows", defaultValue: 3)
    static let tileRowsMaxWindows = PositiveIntDefault(key: "tileRowsMaxWindows", defaultValue: 3)
    static let selectedCycleSizes = CycleSizesDefault()
    static let cycleSizesIsChanged = BoolDefault(key: "cycleSizesIsChanged")
    static let cornerCycleExpansionAxis = IntEnumDefault<CornerCycleExpansionAxis>(key: "cornerCycleExpansionAxis", defaultValue: .horizontal)
    static let cooperativeCornerResize = BoolDefault(key: "cooperativeCornerResize")
    static let experimentalWindowAnimations = BoolDefault(key: "experimentalWindowAnimations")
    static let showMinimumWindowSizeWarning = OptionalBoolDefault(key: "showMinimumWindowSizeWarning")
    static let allowAnyShortcut = BoolDefault(key: "allowAnyShortcut")
    static let windowSnapping = OptionalBoolDefault(key: "windowSnapping")
    static let almostMaximizeHeight = FloatDefault(key: "almostMaximizeHeight")
    static let almostMaximizeWidth = FloatDefault(key: "almostMaximizeWidth")
    static let gapSize = FloatDefault(key: "gapSize")
    static let skipGapTopEdge = BoolDefault(key: "skipGapTopEdge")
    static let snapBeforeReachingEdges = DoubleDefault(key: "snapBeforeReachingEdges")

    static let snapEdgeMarginTop = FloatDefault(key: "snapEdgeMarginTop", defaultValue: 5)
    static let snapEdgeMarginBottom = FloatDefault(key: "snapEdgeMarginBottom", defaultValue: 5)
    static let snapEdgeMarginLeft = FloatDefault(key: "snapEdgeMarginLeft", defaultValue: 5)
    static let snapEdgeMarginRight = FloatDefault(key: "snapEdgeMarginRight", defaultValue: 5)
    static let centeredDirectionalMove = OptionalBoolDefault(key: "centeredDirectionalMove")
    static let resizeOnDirectionalMove = BoolDefault(key: "resizeOnDirectionalMove")
    static let halvesPreserveOtherAxisSize = BoolDefault(key: "halvesPreserveOtherAxisSize")
    static let repeatedMaximizeRestoresPrevious = BoolDefault(key: "repeatedMaximizeRestoresPrevious")
    static let moveFixedSizeToEdge = IntEnumDefault<EdgeAlignment>(key: "moveFixedSizeToEdge", defaultValue: .edgesAndCorners)
    static let ignoredSnapAreas = IntDefault(key: "ignoredSnapAreas")
    static let traverseSingleScreen = OptionalBoolDefault(key: "traverseSingleScreen")
    static let thirdsAndFourthsAcrossDisplays = OptionalBoolDefault(key: "thirdsAndFourthsAcrossDisplays")
    static let useCursorScreenDetection = BoolDefault(key: "useCursorScreenDetection")
    static let minimumWindowWidth = DoubleDefault(key: "minimumWindowWidth", defaultValue: 0.25)
    static let minimumWindowHeight = DoubleDefault(key: "minimumWindowHeight", defaultValue: 0.25)
    static let sizeOffset = FloatDefault(key: "sizeOffset")
    static let widthStepSize = FloatDefault(key: "widthStepSize", defaultValue: 30)
    static let unsnapRestore = OptionalBoolDefault(key: "unsnapRestore")
    static let unsnapRestoreFromSizeChange = OptionalBoolDefault(key: "unsnapRestoreFromSizeChange")
    static let curtainChangeSize = OptionalBoolDefault(key: "curtainChangeSize")
    static let smallerShrinksMaximizedHeight = BoolDefault(key: "smallerShrinksMaximizedHeight")
    static let relaunchOpensMenu = BoolDefault(key: "relaunchOpensMenu")
    static let obtainWindowOnClick = OptionalBoolDefault(key: "obtainWindowOnClick")
    static let screenEdgeGapTop = FloatDefault(key: "screenEdgeGapTop", defaultValue: 0)
    static let screenEdgeGapBottom = FloatDefault(key: "screenEdgeGapBottom", defaultValue: 0)
    static let screenEdgeGapLeft = FloatDefault(key: "screenEdgeGapLeft", defaultValue: 0)
    static let screenEdgeGapRight = FloatDefault(key: "screenEdgeGapRight", defaultValue: 0)
    static let screenEdgeGapsOnMainScreenOnly = BoolDefault(key: "screenEdgeGapsOnMainScreenOnly")
    static let screenEdgeGapTopNotch = DoubleDefault(key: "screenEdgeGapTopNotch", defaultValue: -1)
    static let ignoreMenuBar = OptionalBoolDefault(key: "ignoreMenuBar")
    static let lastVersion = StringDefault(key: "lastVersion")
    static let installVersion = StringDefault(key: "installVersion")
    static let showAllActionsInMenu = OptionalBoolDefault(key: "showAllActionsInMenu")
    static let showAdditionalSizesInMenu = OptionalBoolDefault(key: "showAdditionalSizesInMenu")
    static let footprintAlpha = DoubleDefault(key: "footprintAlpha")
    static var effectiveFootprintAlpha: Double {
        effectiveFootprintAlpha(usesBlur: footprintBlur.enabled)
    }
    static func effectiveFootprintAlpha(usesBlur: Bool) -> Double {
        if JSONPreferences.shared.object(forKey: footprintAlpha.key) == nil {
            return usesBlur ? 0 : 0.3
        }
        return footprintAlpha.value
    }
    static let footprintBorderWidth = FloatDefault(key: "footprintBorderWidth", defaultValue: 2)
    static let footprintFade = OptionalBoolDefault(key: "footprintFade")
    static let footprintColor = JSONDefault<CodableColor>(key: "footprintColor")
    static let footprintBlur = BoolDefault(key: "footprintBlur")
    static let blurAppearance = IntEnumDefault<BlurAppearance>(key: "blurAppearance", defaultValue: .system)

    static let todo = OptionalBoolDefault(key: "todo")
    static let todoMode = BoolDefault(key: "todoMode")
    static let todoApplication = StringDefault(key: "todoApplication")
    static let todoSidebarWidth = FloatDefault(key: "todoSidebarWidth", defaultValue: 400)
    static let todoSidebarWidthUnit = IntEnumDefault<TodoSidebarWidthUnit>(key: "todoSidebarWidthUnit", defaultValue: .pixels)
    static let todoSidebarSide = IntEnumDefault<TodoSidebarSide>(key: "todoSidebarSide", defaultValue: .right)
    static let snapModifiers = IntDefault(key: "snapModifiers")
    static let attemptMatchOnNextPrevDisplay = OptionalBoolDefault(key: "attemptMatchOnNextPrevDisplay")
    static let centerAcrossDisplays = OptionalBoolDefault(key: "centerAcrossDisplays")
    static let altThirdCycle = OptionalBoolDefault(key: "altThirdCycle")
    static let centerHalfCycles = OptionalBoolDefault(key: "centerHalfCycles")
    static let cyclingOverlapOffset = OptionalBoolDefault(key: "cyclingOverlapOffset")
    static let cyclingOverlapOffsetSize = FloatDefault(key: "cyclingOverlapOffsetSize", defaultValue: 11)
    static let cyclingOverlapOffsetHorizontal = DoubleDefault(key: "cyclingOverlapOffsetHorizontal", defaultValue: -1)
    static let cyclingOverlapOffsetVertical = DoubleDefault(key: "cyclingOverlapOffsetVertical", defaultValue: -1)
    static let stackOffsetX = DoubleDefault(key: "stackOffsetX", defaultValue: 11)
    static let stackOffsetY = DoubleDefault(key: "stackOffsetY", defaultValue: 11)
    static let stackFitToSnapArea = BoolDefault(key: "stackFitToSnapArea")
    static var overlapOffset: CGVector {
        func resolved(_ axis: DoubleDefault, signed: DoubleDefault) -> CGFloat {
            let profileID = BehaviorProfileContext.currentProfileID
            if BehaviorProfileStore.override(for: signed.key, profileID: profileID) != nil
                || JSONPreferences.shared.object(forKey: signed.key) != nil {
                return CGFloat(signed.value)
            }
            let axisOverride = BehaviorProfileStore.override(for: axis.key, profileID: profileID)
            let legacyOverride = BehaviorProfileStore.override(for: cyclingOverlapOffsetSize.key, profileID: profileID)
            if axisOverride == nil, let value = legacyOverride?.float {
                return CGFloat(max(0, value))
            }
            let value = axis.value
            return CGFloat(max(0, value < 0 ? Double(cyclingOverlapOffsetSize.value) : value))
        }
        return CGVector(dx: resolved(cyclingOverlapOffsetHorizontal, signed: stackOffsetX),
                        dy: resolved(cyclingOverlapOffsetVertical, signed: stackOffsetY))
    }
    static let cyclingOverlapMaxCascade = IntDefault(key: "cyclingOverlapMaxCascade", defaultValue: 1)
    static let stackBadge = OptionalBoolDefault(key: "stackBadge")
    static let stackSameSizeOnly = OptionalBoolDefault(key: "stackSameSizeOnly")
    static let fullIgnoreBundleIds = JSONDefault<[String]>(key: "fullIgnoreBundleIds")
    static let notifiedOfProblemApps = BoolDefault(key: "notifiedOfProblemApps")
    static let specifiedHeight = FloatDefault(key: "specifiedHeight", defaultValue: 1050)
    static let specifiedWidth = FloatDefault(key: "specifiedWidth", defaultValue: 1680)
    static let horizontalSplitRatio = FloatDefault(key: "horizontalSplitRatio", defaultValue: 50)
    static let verticalSplitRatio = FloatDefault(key: "verticalSplitRatio", defaultValue: 50)
    static let moveCursorAcrossDisplays = OptionalBoolDefault(key: "moveCursorAcrossDisplays")
    static let moveCursor = OptionalBoolDefault(key: "moveCursor")
    static let autoMaximize = OptionalBoolDefault(key: "autoMaximize")
    static let applyGapsToMaximize = OptionalBoolDefault(key: "applyGapsToMaximize")
    static let applyGapsToMaximizeHeight = OptionalBoolDefault(key: "applyGapsToMaximizeHeight")
    static let cornerSnapAreaSize = FloatDefault(key: "cornerSnapAreaSize", defaultValue: 20)
    static let shortEdgeSnapAreaSize = FloatDefault(key: "shortEdgeSnapAreaSize", defaultValue: 145)
    static let cascadeAllDeltaSize = FloatDefault(key: "cascadeAllDeltaSize", defaultValue: 30)
    static let displayBehaviorProfiles = JSONDefault<[String: [String: CodableDefault]]>(
        key: "displayBehaviorProfiles",
        defaultValue: [:]
    )
    static let sixthsSnapArea = OptionalBoolDefault(key: "sixthsSnapArea")
    static let stageSize = FloatDefault(key: "stageSize", defaultValue: 190)
    static let dragFromStage = OptionalBoolDefault(key: "dragFromStage")
    static let alwaysAccountForStage = OptionalBoolDefault(key: "alwaysAccountForStage")
    static let landscapeSnapAreas = JSONDefault<[Directional:SnapAreaConfig]>(key: "landscapeSnapAreas")
    static let portraitSnapAreas = JSONDefault<[Directional:SnapAreaConfig]>(key: "portraitSnapAreas")
    static let missionControlDragging = OptionalBoolDefault(key: "missionControlDragging")
    static let enhancedUI = IntEnumDefault<EnhancedUI>(
        key: "enhancedUI",
        defaultValue: .automatic,
        invalidValueFallback: .disableEnable
    )
    static let footprintAnimationDurationMultiplier = FloatDefault(key: "footprintAnimationDurationMultiplier", defaultValue: 0)
    static let hapticFeedbackOnSnap = OptionalBoolDefault(key: "hapticFeedbackOnSnap")
    static let missionControlDraggingAllowedOffscreenDistance = FloatDefault(key: "missionControlDraggingAllowedOffscreenDistance", defaultValue: 25)
    static let missionControlDraggingDisallowedDuration = IntDefault(key: "missionControlDraggingDisallowedDuration", defaultValue: 250)
    static let doubleClickTitleBar = IntDefault(key: "doubleClickTitleBar")
    static let doubleClickTitleBarRestore = OptionalBoolDefault(key: "doubleClickTitleBarRestore")
    static let doubleClickTitleBarIgnoredApps = JSONDefault<[String]>(key: "doubleClickTitleBarIgnoredApps")
    static let doubleClickToolBarIgnoredApps = JSONDefault<Set<String>>(key: "doubleClickToolBarIgnoredApps", defaultValue: ["epp.package.java"])
    static let ignoreDragSnapToo = OptionalBoolDefault(key: "ignoreDragSnapToo")
    static let systemWideMouseDown = OptionalBoolDefault(key: "systemWideMouseDown")
    static let systemWideMouseDownApps = JSONDefault<Set<String>>(key:"systemWideMouseDownApps", defaultValue: Set<String>(["org.languagetool.desktop", "com.microsoft.teams2"]))
    static let directAnimationNativeResizeApps = JSONDefault<Set<String>>(key: "directAnimationNativeResizeApps", defaultValue: Set<String>(["com.colliderli.iina"]))
    static let internalTilingNotified = BoolDefault(key: "internalTilingNotified")
    static let screensOrderedByX = IntEnumDefault<ScreenOrdering>(key: "screensOrderedByX", defaultValue: .yThenMinX)
    static let combinedDisplayMode = OptionalBoolDefault(key: "combinedDisplayMode")
    static let greenButtonOverride = BoolDefault(key: "greenButtonOverride")
    static let mouseButtonShortcutsUseWindowUnderCursor = BoolDefault(key: "mouseButtonShortcutsUseWindowUnderCursor")
    static let ignoreShortcutsInMissionControl = BoolDefault(key: "ignoreShortcutsInMissionControl", defaultValue: true)
    static let newWindowAction = StringDefault(key: "newWindowAction")
    static let wasWelcomeDisplayed = BoolDefault(key: "wasWelcomeDisplayed")
    static var array: [Default] = [
        launchOnLogin,
        disabledApps,
        hideMenuBarIcon,
        alternateDefaultShortcuts,
        subsequentExecutionMode,
        tileColumnsMaxWindows,
        tileRowsMaxWindows,
        selectedCycleSizes,
        cycleSizesIsChanged,
        cornerCycleExpansionAxis,
        cooperativeCornerResize,
        experimentalWindowAnimations,
        showMinimumWindowSizeWarning,
        allowAnyShortcut,
        windowSnapping,
        almostMaximizeHeight,
        almostMaximizeWidth,
        gapSize,
        skipGapTopEdge,
        snapBeforeReachingEdges,
        snapEdgeMarginTop,
        snapEdgeMarginBottom,
        snapEdgeMarginLeft,
        snapEdgeMarginRight,
        centeredDirectionalMove,
        resizeOnDirectionalMove,
        halvesPreserveOtherAxisSize,
        repeatedMaximizeRestoresPrevious,
        ignoredSnapAreas,
        traverseSingleScreen,
        thirdsAndFourthsAcrossDisplays,
        useCursorScreenDetection,
        minimumWindowWidth,
        minimumWindowHeight,
        sizeOffset,
        widthStepSize,
        unsnapRestore,
        unsnapRestoreFromSizeChange,
        curtainChangeSize,
        smallerShrinksMaximizedHeight,
        relaunchOpensMenu,
        obtainWindowOnClick,
        screenEdgeGapTop,
        screenEdgeGapBottom,
        screenEdgeGapLeft,
        screenEdgeGapRight,
        screenEdgeGapsOnMainScreenOnly,
        screenEdgeGapTopNotch,
        ignoreMenuBar,
        newWindowAction,
        showAllActionsInMenu,
        showAdditionalSizesInMenu,
        footprintAlpha,
        footprintBorderWidth,
        footprintFade,
        footprintColor,
        footprintBlur,
        blurAppearance,
        todo,
        todoMode,
        todoApplication,
        todoSidebarWidth,
        todoSidebarWidthUnit,
        todoSidebarSide,
        snapModifiers,
        attemptMatchOnNextPrevDisplay,
        centerAcrossDisplays,
        altThirdCycle,
        centerHalfCycles,
        fullIgnoreBundleIds,
        notifiedOfProblemApps,
        specifiedHeight,
        specifiedWidth,
        horizontalSplitRatio,
        verticalSplitRatio,
        moveCursorAcrossDisplays,
        moveCursor,
        autoMaximize,
        applyGapsToMaximize,
        applyGapsToMaximizeHeight,
        cornerSnapAreaSize,
        shortEdgeSnapAreaSize,
        cascadeAllDeltaSize,
        sixthsSnapArea,
        stageSize,
        dragFromStage,
        alwaysAccountForStage,
        landscapeSnapAreas,
        portraitSnapAreas,
        missionControlDragging,
        enhancedUI,
        footprintAnimationDurationMultiplier,
        hapticFeedbackOnSnap,
        missionControlDraggingAllowedOffscreenDistance,
        missionControlDraggingDisallowedDuration,
        doubleClickTitleBar,
        doubleClickTitleBarRestore,
        doubleClickTitleBarIgnoredApps,
        doubleClickToolBarIgnoredApps,
        ignoreDragSnapToo,
        systemWideMouseDown,
        systemWideMouseDownApps,
        directAnimationNativeResizeApps,
        screensOrderedByX,
        combinedDisplayMode,
        cyclingOverlapOffset,
        cyclingOverlapOffsetSize,
        cyclingOverlapOffsetHorizontal,
        cyclingOverlapOffsetVertical,
        cyclingOverlapMaxCascade,
        stackBadge,
        stackSameSizeOnly,
        moveFixedSizeToEdge,
        greenButtonOverride,
        mouseButtonShortcutsUseWindowUnderCursor,
        ignoreShortcutsInMissionControl,
        displayBehaviorProfiles,
        stackOffsetX, stackOffsetY, stackFitToSnapArea
    ]
}

struct CodableDefault: Codable, Equatable {
    let bool: Bool?
    let int: Int?
    let float: Float?
    let double: Double?
    let string: String?
    
    init(bool: Bool? = nil, int: Int? = nil, float: Float? = nil, double: Double? = nil, string: String? = nil) {
        self.bool = bool
        self.int = int
        self.float = float
        self.double = double
        self.string = string
    }
}

enum BehaviorProfileStore {
    static let defaultProfileID = "default"

    static var profileIDs: [String] {
        (Defaults.displayBehaviorProfiles.typedValue ?? [:]).keys.sorted()
    }

    static func overrideCount(for profileID: String) -> Int {
        Defaults.displayBehaviorProfiles.typedValue?[profileID]?.count ?? 0
    }

    static func override(for key: String, profileID: String?) -> CodableDefault? {
        guard let profileID, profileID != defaultProfileID else { return nil }
        return Defaults.displayBehaviorProfiles.typedValue?[profileID]?[key]
    }

    static func setOverride(_ value: CodableDefault, for key: String, profileID: String) {
        guard profileID != defaultProfileID else { return }
        var profiles = Defaults.displayBehaviorProfiles.typedValue ?? [:]
        var profile = profiles[profileID] ?? [:]
        if matchesDefault(value, for: key) {
            profile.removeValue(forKey: key)
        } else {
            profile[key] = value
        }
        profiles[profileID] = profile
        Defaults.displayBehaviorProfiles.typedValue = profiles
        notifyChanges()
    }

    static func removeRedundantOverrides() {
        guard !JSONPreferences.shared.isPerformingBatch,
              JSONPreferences.shared.object(forKey: "displayBehaviorProfiles") != nil else { return }
        let profiles = Defaults.displayBehaviorProfiles.typedValue ?? [:]
        var normalized = profiles
        for (profileID, values) in profiles {
            normalized[profileID] = values.filter { !matchesDefault($0.value, for: $0.key) }
        }
        guard normalized != profiles else { return }
        Defaults.displayBehaviorProfiles.typedValue = normalized
        notifyChanges()
    }

    private static func matchesDefault(_ value: CodableDefault, for key: String) -> Bool {
        BehaviorProfileContext.withProfileID(defaultProfileID) {
            if key.hasPrefix("shortcut:") {
                guard let string = value.string,
                      let shortcut = try? JSONDecoder().decode(Shortcut.self, from: Data(string.utf8)) else { return false }
                let inherited = ShortcutPreferences.shared.shortcut(for: String(key.dropFirst("shortcut:".count)))
                if shortcut.keyCode < 0 { return inherited == nil }
                guard let inherited else { return false }
                return ShortcutCycle.ShortcutIdentity(shortcut.toMASSHortcut()) == ShortcutCycle.ShortcutIdentity(inherited)
            }
            guard key != "displayBehaviorProfiles",
                  let setting = Defaults.array.first(where: { $0.key == key }) else { return false }
            if key == Defaults.selectedCycleSizes.key {
                return value.int == Set(CycleSize.sortedSelectedSizes()).toBits()
            }
            if let string = value.string {
                let data = Data(string.utf8)
                if key == Defaults.landscapeSnapAreas.key {
                    return (try? JSONDecoder().decode([Directional: SnapAreaConfig].self, from: data))
                        == (Defaults.landscapeSnapAreas.typedValue ?? SnapAreaModel.defaultLandscape)
                }
                if key == Defaults.portraitSnapAreas.key {
                    return (try? JSONDecoder().decode([Directional: SnapAreaConfig].self, from: data))
                        == (Defaults.portraitSnapAreas.typedValue ?? SnapAreaModel.defaultPortrait)
                }
                if let setting = setting as? JSONDefault<Set<String>> {
                    return (try? JSONDecoder().decode(Set<String>.self, from: data)) == setting.typedValue
                }
            }
            let inherited: CodableDefault
            if key == Defaults.stackOffsetX.key {
                inherited = CodableDefault(double: Double(Defaults.overlapOffset.dx))
            } else if key == Defaults.stackOffsetY.key {
                inherited = CodableDefault(double: Double(Defaults.overlapOffset.dy))
            } else {
                inherited = setting.toCodable()
            }
            if setting is OptionalBoolDefault, inherited.int == 0, let int = value.int {
                let enabledWhenUnset: Set<String> = ["windowSnapping", "unsnapRestore",
                                                    "unsnapRestoreFromSizeChange", "autoMaximize"]
                return int == (enabledWhenUnset.contains(key) ? 1 : 2) || int == 0
            }
            if let lhs = value.string, let rhs = inherited.string,
               let leftJSON = try? JSONSerialization.jsonObject(with: Data(lhs.utf8), options: .fragmentsAllowed),
               let rightJSON = try? JSONSerialization.jsonObject(with: Data(rhs.utf8), options: .fragmentsAllowed) {
                return NSDictionary(dictionary: ["value": leftJSON]).isEqual(to: ["value": rightJSON])
            }
            return value == inherited
        }
    }

    static func removeOverride(for key: String, profileID: String) {
        var profiles = Defaults.displayBehaviorProfiles.typedValue ?? [:]
        profiles[profileID]?.removeValue(forKey: key)
        Defaults.displayBehaviorProfiles.typedValue = profiles
        notifyChanges()
    }

    static func registerProfiles(_ profileIDs: [String]) {
        var profiles = Defaults.displayBehaviorProfiles.typedValue ?? [:]
        var changed = false
        for id in profileIDs where id != defaultProfileID && profiles[id] == nil {
            profiles[id] = [:]
            changed = true
        }
        guard changed else { return }
        Defaults.displayBehaviorProfiles.typedValue = profiles
        notifyChanges()
    }

    static func removeProfile(_ profileID: String) {
        guard profileID != defaultProfileID else { return }
        var profiles = Defaults.displayBehaviorProfiles.typedValue ?? [:]
        profiles.removeValue(forKey: profileID)
        Defaults.displayBehaviorProfiles.typedValue = profiles
        notifyChanges()
    }

    @discardableResult
    static func writeOverride(_ value: CodableDefault, for key: String) -> Bool {
        guard key != "displayBehaviorProfiles",
              let profileID = BehaviorProfileContext.editingProfileID,
              profileID != defaultProfileID else { return false }
        setOverride(value, for: key, profileID: profileID)
        return true
    }

    static func reset(profileID: String) {
        guard profileID != defaultProfileID else { return }
        var profiles = Defaults.displayBehaviorProfiles.typedValue ?? [:]
        profiles[profileID] = [:]
        Defaults.displayBehaviorProfiles.typedValue = profiles
        notifyChanges()
    }

    private static func notifyChanges() {
        BehaviorProfileContext.withActiveProfile {
            Notification.Name.displayBehaviorProfileOverridesChanged.post()
        }
    }
}

enum BehaviorProfileContext {
    private static let key = "com.knollsoft.Rectangle.behaviorProfileID"
    private static let editingKey = "jrectangle.editingProfileID"
    static var activeProfileID: String?

    static var currentProfileID: String? {
        Thread.current.threadDictionary[key] as? String ?? activeProfileID
    }

    static var editingProfileID: String? {
        Thread.current.threadDictionary[editingKey] as? String
    }

    @discardableResult
    static func setCurrentProfileID(_ profileID: String?) -> String? {
        let previous = Thread.current.threadDictionary[key] as? String
        if let profileID {
            Thread.current.threadDictionary[key] = profileID
        } else {
            Thread.current.threadDictionary.removeObject(forKey: key)
        }
        return previous
    }

    static func withProfileID<T>(_ profileID: String?, perform: () throws -> T) rethrows -> T {
        let previous = setCurrentProfileID(profileID)
        defer { _ = setCurrentProfileID(previous) }
        return try perform()
    }

    static func edit<T>(_ profileID: String, perform: () throws -> T) rethrows -> T {
        let previous = editingProfileID
        Thread.current.threadDictionary[editingKey] = profileID
        defer {
            if let previous { Thread.current.threadDictionary[editingKey] = previous }
            else { Thread.current.threadDictionary.removeObject(forKey: editingKey) }
        }
        return try withProfileID(profileID, perform: perform)
    }

    static func withActiveProfile<T>(perform: () throws -> T) rethrows -> T {
        let previous = editingProfileID
        Thread.current.threadDictionary.removeObject(forKey: editingKey)
        defer {
            if let previous { Thread.current.threadDictionary[editingKey] = previous }
        }
        return try withProfileID(activeProfileID ?? BehaviorProfileStore.defaultProfileID, perform: perform)
    }
}

protocol Default {
    var key: String { get }
    func load(from codable: CodableDefault)
    func toCodable() -> CodableDefault
}

class BoolDefault: Default {
    public private(set) var key: String
    private var initialized = false
    private var storedEnabled: Bool
    
    var enabled: Bool {
        get {
            BehaviorProfileStore.override(for: key, profileID: BehaviorProfileContext.currentProfileID)?.bool ?? storedEnabled
        }
        set {
            if initialized, BehaviorProfileStore.writeOverride(CodableDefault(bool: newValue), for: key) { return }
            storedEnabled = newValue
            if initialized {
                JSONPreferences.shared.set(newValue, forKey: key)
            }
        }
    }
    
    init(key: String, defaultValue: Bool = false) {
        self.key = key
        if JSONPreferences.shared.object(forKey: key) == nil {
            storedEnabled = defaultValue
        } else {
            storedEnabled = JSONPreferences.shared.bool(forKey: key)
        }
        initialized = true
    }

    func load(from codable: CodableDefault) {
        if let value = codable.bool {
            self.enabled = value
        }
    }
    
    func toCodable() -> CodableDefault {
        return CodableDefault(bool: enabled)
    }
}

class OptionalBoolDefault: Default {
    public private(set) var key: String
    private var initialized = false
    private var storedEnabled: Bool?
    
    var enabled: Bool? {
        get {
            if let value = BehaviorProfileStore.override(for: key, profileID: BehaviorProfileContext.currentProfileID)?.int {
                return value == 1 ? true : value == 2 ? false : nil
            }
            return storedEnabled
        }
        set {
            if initialized, BehaviorProfileStore.writeOverride(CodableDefault(int: newValue == true ? 1 : newValue == false ? 2 : 0), for: key) { return }
            storedEnabled = newValue
            if initialized {
                if newValue == true {
                    JSONPreferences.shared.set(1, forKey: key)
                } else if newValue == false {
                    JSONPreferences.shared.set(2, forKey: key)
                } else {
                    JSONPreferences.shared.set(0, forKey: key)
                }
            }
        }
    }
    
    var userDisabled: Bool { enabled == false }
    var userEnabled: Bool { enabled == true }
    var userModified: Bool { enabled != nil }
    var notSet: Bool { enabled == nil }
    
    init(key: String) {
        self.key = key
        let intValue = JSONPreferences.shared.integer(forKey: key)
        set(using: intValue)
        initialized = true
    }
    
    private func set(using intValue: Int) {
        switch intValue {
        case 0: enabled = nil
        case 1: enabled = true
        case 2: enabled = false
        default: break
        }
    }
    
    func load(from codable: CodableDefault) {
        if let value = codable.int {
            set(using: value)
        }
    }
    
    func toCodable() -> CodableDefault {
        guard let enabled = enabled else { return CodableDefault(int: 0)}
        let intValue = enabled ? 1 : 2
        return CodableDefault(int: intValue)
    }
}

class StringDefault: Default {
    public private(set) var key: String
    private var initialized = false
    
    private var storedValue: String?
    var value: String? {
        get {
            if key == "displayBehaviorProfiles" { return storedValue }
            return BehaviorProfileStore.override(for: key, profileID: BehaviorProfileContext.currentProfileID)?.string ?? storedValue
        }
        set {
            if initialized, BehaviorProfileStore.writeOverride(CodableDefault(string: newValue), for: key) { return }
            storedValue = newValue
            if initialized {
                JSONPreferences.shared.set(newValue, forKey: key)
            }
        }
    }
    
    init(key: String) {
        self.key = key
        storedValue = JSONPreferences.shared.string(forKey: key)
        initialized = true
    }
    
    func load(from codable: CodableDefault) {
        value = codable.string
    }
    
    func toCodable() -> CodableDefault {
        return CodableDefault(string: value)
    }
}

class FloatDefault: Default {
    public private(set) var key: String
    private var initialized = false
    private var storedValue: Float
    
    var value: Float {
        get {
            BehaviorProfileStore.override(for: key, profileID: BehaviorProfileContext.currentProfileID)?.float ?? storedValue
        }
        set {
            if initialized, BehaviorProfileStore.writeOverride(CodableDefault(float: newValue), for: key) { return }
            storedValue = newValue
            if initialized {
                JSONPreferences.shared.set(newValue, forKey: key)
            }
        }
    }
    
    var cgFloat: CGFloat { CGFloat(value) }

    init(key: String, defaultValue: Float = 0) {
        self.key = key
        storedValue = JSONPreferences.shared.float(forKey: key)
        if defaultValue != 0 && storedValue == 0 {
            storedValue = defaultValue
        }
        initialized = true
    }
    
    func load(from codable: CodableDefault) {
        if let float = codable.float {
            value = float
        }
    }
    
    func toCodable() -> CodableDefault {
        return CodableDefault(float: value)
    }
}

class DoubleDefault: Default {
    public private(set) var key: String
    private var initialized = false
    private let defaultValue: Double
    private var storedValue: Double

    var value: Double {
        get {
            if let profileValue = BehaviorProfileStore.override(for: key, profileID: BehaviorProfileContext.currentProfileID) {
                return profileValue.double ?? profileValue.float.map(Double.init) ?? storedValue
            }
            return storedValue
        }
        set {
            if initialized, BehaviorProfileStore.writeOverride(CodableDefault(double: newValue), for: key) { return }
            storedValue = newValue
            if initialized {
                JSONPreferences.shared.set(newValue, forKey: key)
            }
        }
    }

    init(key: String, defaultValue: Double = 0) {
        self.key = key
        self.defaultValue = defaultValue
        if JSONPreferences.shared.object(forKey: key) == nil {
            storedValue = defaultValue
        } else {
            storedValue = JSONPreferences.shared.double(forKey: key)
        }
        initialized = true
    }

    func load(from codable: CodableDefault) {
        if let double = codable.double {
            value = double
        } else if let float = codable.float {
            // Legacy float-backed defaults could not distinguish an absent value
            // from zero; preserve their effective default when migrating.
            value = float == 0 && defaultValue != 0 ? defaultValue : Double(float)
        }
    }

    func toCodable() -> CodableDefault {
        CodableDefault(double: value)
    }
}

class PositiveIntDefault: Default {
    let key: String
    private let userDefaults: UserDefaults?
    private var storedValue: Int

    var value: Int {
        get { max(1, BehaviorProfileStore.override(for: key, profileID: BehaviorProfileContext.currentProfileID)?.int ?? storedValue) }
        set {
            if userDefaults == nil, BehaviorProfileStore.writeOverride(CodableDefault(int: max(1, newValue)), for: key) { return }
            storedValue = max(1, newValue)
            if let userDefaults {
                userDefaults.set(storedValue, forKey: key)
            } else {
                JSONPreferences.shared.set(storedValue, forKey: key)
            }
        }
    }

    init(key: String, defaultValue: Int, userDefaults: UserDefaults? = nil) {
        precondition(defaultValue > 0)
        self.key = key
        self.userDefaults = userDefaults
        let savedValue: Any?
        if let userDefaults { savedValue = userDefaults.object(forKey: key) }
        else { savedValue = JSONPreferences.shared.object(forKey: key) }
        if let savedValue {
            storedValue = max(1, savedValue as? Int ?? 1)
        } else {
            storedValue = defaultValue
        }
    }

    func load(from codable: CodableDefault) {
        if let int = codable.int {
            value = int
        }
    }

    func toCodable() -> CodableDefault {
        CodableDefault(int: value)
    }
}

class IntDefault: Default {
    public private(set) var key: String
    private var initialized = false
    
    private var storedValue: Int
    var value: Int {
        get { BehaviorProfileStore.override(for: key, profileID: BehaviorProfileContext.currentProfileID)?.int ?? storedValue }
        set {
            if initialized, BehaviorProfileStore.writeOverride(CodableDefault(int: newValue), for: key) { return }
            storedValue = newValue
            if initialized {
                JSONPreferences.shared.set(newValue, forKey: key)
            }
        }
    }
    
    init(key: String, defaultValue: Int = 0) {
        self.key = key
        storedValue = JSONPreferences.shared.integer(forKey: key)
        if(defaultValue != 0 && storedValue == 0) {
            storedValue = defaultValue
        }
        initialized = true
    }
    
    func load(from codable: CodableDefault) {
        if let int = codable.int {
            value = int
        }
    }
    
    func toCodable() -> CodableDefault {
        return CodableDefault(int: value)
    }
}

class JSONDefault<T: Codable>: StringDefault {
    
    private var typeInitialized = false
    
    private var storedTypedValue: T?
    var typedValue: T? {
        get {
            // The profile store itself must never resolve through a profile.
            if key != "displayBehaviorProfiles",
               let json = BehaviorProfileStore.override(for: key, profileID: BehaviorProfileContext.currentProfileID)?.string,
               let decoded = try? JSONDecoder().decode(T.self, from: Data(json.utf8)) {
                return decoded
            }
            return storedTypedValue
        }
        set {
            if typeInitialized, key != "displayBehaviorProfiles",
               let profileID = BehaviorProfileContext.editingProfileID,
               profileID != BehaviorProfileStore.defaultProfileID {
                saveToJSON(newValue)
                return
            }
            storedTypedValue = newValue
            if typeInitialized {
                saveToJSON(newValue)
            }
        }
    }
    
    override init(key: String) {
        super.init(key: key)
        loadFromJSON()
        typeInitialized = true
    }
    
    init(key: String, defaultValue: T) {
        super.init(key: key)
        loadFromJSON()
        if typedValue == nil {
            typedValue = defaultValue
        }
        typeInitialized = true
    }
    
    override func load(from codable: CodableDefault) {
        if value != codable.string {
            JSONPreferences.shared.performBatch {
                value = codable.string
                typeInitialized = false
                loadFromJSON()
                typeInitialized = true
            }
            BehaviorProfileStore.removeRedundantOverrides()
        }
    }

    override func toCodable() -> CodableDefault {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(typedValue) else { return super.toCodable() }
        return CodableDefault(string: String(decoding: data, as: UTF8.self))
    }

    private func loadFromJSON() {
        guard let jsonString = value else { return }
        let decoder = JSONDecoder()
        guard let jsonData = jsonString.data(using: .utf8) else { return }
        typedValue = try? decoder.decode(T.self, from: jsonData)
    }
    
    private func saveToJSON(_ obj: T?) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        if let jsonData = try? encoder.encode(obj) {
            let jsonString = String(data: jsonData, encoding: .utf8)
            if jsonString != value {
                value = jsonString
            }
        }
    }
}

class IntEnumDefault<E: RawRepresentable>: Default where E.RawValue == Int {
    public private(set) var key: String
    private let invalidValueFallback: E
    private var storedValue: E

    var value: E {
        set {
            if BehaviorProfileStore.writeOverride(CodableDefault(int: newValue.rawValue), for: key) { return }
            if newValue != storedValue {
                storedValue = newValue
                JSONPreferences.shared.set(storedValue.rawValue, forKey: key)
            }
        }
        get {
            guard let rawValue = BehaviorProfileStore.override(for: key, profileID: BehaviorProfileContext.currentProfileID)?.int else {
                return storedValue
            }
            return E(rawValue: rawValue) ?? invalidValueFallback
        }
    }

    init(key: String, defaultValue: E, invalidValueFallback: E? = nil) {
        self.key = key
        let invalidValueFallback = invalidValueFallback ?? defaultValue
        self.invalidValueFallback = invalidValueFallback
        if JSONPreferences.shared.object(forKey: key) == nil {
            storedValue = defaultValue
        } else {
            let intValue = JSONPreferences.shared.integer(forKey: key)
            storedValue = E(rawValue: intValue) ?? invalidValueFallback
        }
    }

    func load(from codable: CodableDefault) {
        if let intValue = codable.int, storedValue.rawValue != intValue {
            storedValue = E(rawValue: intValue) ?? invalidValueFallback
            JSONPreferences.shared.set(storedValue.rawValue, forKey: key)
        }
    }
    
    func toCodable() -> CodableDefault {
        CodableDefault(int: value.rawValue)
    }
}

struct CodableColor : Codable {
    var red: CGFloat = 0.0
    var green: CGFloat = 0.0
    var blue: CGFloat = 0.0
    var alpha: CGFloat? = 1.0

    var nsColor : NSColor {
        return NSColor(red: red, green: green, blue: blue, alpha: alpha ?? 1.0)
    }

    init(nsColor: NSColor) {
        self.red = nsColor.redComponent
        self.green = nsColor.greenComponent
        self.blue = nsColor.blueComponent
        self.alpha = nsColor.alphaComponent
    }
}

enum BlurAppearance: Int, CaseIterable {
    case system = 0
    case light = 1
    case dark = 2

    var appearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

