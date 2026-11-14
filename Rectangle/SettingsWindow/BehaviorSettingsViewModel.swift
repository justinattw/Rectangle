/// BehaviorSettingsViewModel.swift

import SwiftUI
import AppKit

@Observable
final class BehaviorSettingsViewModel {
    let shortcutRecordingObserver = ShortcutRecordingObserver()
    private var selectedProfileID: String {
        DisplayProfileSelectionModel.shared.selectedProfileID
    }
    private var isLoadingProfile = false

    private func persistProfiledValue(_ value: CodableDefault, key: String, updateDefault: () -> Void) {
        guard !isLoadingProfile else { return }
        if selectedProfileID == BehaviorProfileStore.defaultProfileID {
            updateDefault()
        } else {
            BehaviorProfileStore.setOverride(value, for: key, profileID: selectedProfileID)
        }
    }

    // MARK: - Window Behavior & Cycle Settings
    var subsequentExecutionMode: SubsequentExecutionMode {
        didSet {
            persistProfiledValue(CodableDefault(int: subsequentExecutionMode.rawValue), key: Defaults.subsequentExecutionMode.key) {
                Defaults.subsequentExecutionMode.value = subsequentExecutionMode
            }
        }
    }
    
    var selectedCycleSizes: Set<CycleSize> = []
    var cornerCycleExpansionAxis: CornerCycleExpansionAxis {
        didSet {
            persistProfiledValue(CodableDefault(int: cornerCycleExpansionAxis.rawValue), key: Defaults.cornerCycleExpansionAxis.key) {
                Defaults.cornerCycleExpansionAxis.value = cornerCycleExpansionAxis
            }
        }
    }
    
    var cooperativeCornerResize: Bool {
        didSet {
            persistProfiledValue(CodableDefault(bool: cooperativeCornerResize), key: Defaults.cooperativeCornerResize.key) {
                Defaults.cooperativeCornerResize.enabled = cooperativeCornerResize
            }
        }
    }
    
    var gapSize: Double
    var overlapHorizontal: Double = 11
    var overlapVertical: Double = 11
    var edgeHorizontal: Double = 0
    var edgeVertical: Double = 0
    var horizontalEdgesDiffer = false
    var verticalEdgesDiffer = false
    var skipGapTopEdge: Bool {
        didSet {
            persistProfiledValue(CodableDefault(bool: skipGapTopEdge), key: Defaults.skipGapTopEdge.key) {
                Defaults.skipGapTopEdge.enabled = skipGapTopEdge
            }
        }
    }
    
    var moveCursorAcrossDisplays: Bool {
        didSet {
            persistProfiledValue(CodableDefault(int: moveCursorAcrossDisplays ? 1 : 2), key: Defaults.moveCursorAcrossDisplays.key) {
                Defaults.moveCursorAcrossDisplays.enabled = moveCursorAcrossDisplays
            }
        }
    }
    
    var centerAcrossDisplays: Bool {
        didSet {
            persistProfiledValue(CodableDefault(int: centerAcrossDisplays ? 1 : 2), key: Defaults.centerAcrossDisplays.key) {
                Defaults.centerAcrossDisplays.enabled = centerAcrossDisplays
            }
        }
    }
    
    var useCursorScreenDetection: Bool {
        didSet {
            Defaults.useCursorScreenDetection.enabled = useCursorScreenDetection
        }
    }
    
    var doubleClickTitleBar: Bool {
        didSet {
            handleDoubleClickTitleBarToggle(doubleClickTitleBar)
        }
    }
    
    var autoMaximize: Bool {
        didSet {
            persistProfiledValue(CodableDefault(int: autoMaximize ? 1 : 2), key: Defaults.autoMaximize.key) {
                Defaults.autoMaximize.enabled = autoMaximize
            }
        }
    }
    
    var greenButtonOverride: Bool {
        didSet {
            Defaults.greenButtonOverride.enabled = greenButtonOverride
            Notification.Name.greenButtonOverride.post()
        }
    }
    
    var experimentalAnimations: Bool {
        didSet {
            guard oldValue != experimentalAnimations else { return }
            Defaults.experimentalWindowAnimations.enabled = experimentalAnimations
            Notification.Name.windowAnimationPreferencesChanged.post()
        }
    }
    
    var combinedDisplayMode: Bool {
        didSet {
            Defaults.combinedDisplayMode.enabled = combinedDisplayMode
        }
    }
    
    var showMinimumWindowSizeWarning: Bool {
        didSet {
            Defaults.showMinimumWindowSizeWarning.enabled = showMinimumWindowSizeWarning
        }
    }
    
    // MARK: - Todo Mode Settings
    var todoEnabled: Bool {
        didSet {
            Defaults.todo.enabled = todoEnabled
            Notification.Name.todoMenuToggled.post()
        }
    }
    
    var todoSidebarWidth: Float {
        didSet {
            persistProfiledValue(CodableDefault(float: todoSidebarWidth), key: Defaults.todoSidebarWidth.key) {
                Defaults.todoSidebarWidth.value = todoSidebarWidth
            }
        }
    }
    
    var todoSidebarWidthUnit: TodoSidebarWidthUnit {
        didSet {
            guard !isLoadingProfile else { return }
            persistProfiledValue(CodableDefault(int: todoSidebarWidthUnit.rawValue), key: Defaults.todoSidebarWidthUnit.key) {
                Defaults.todoSidebarWidthUnit.value = todoSidebarWidthUnit
            }
            BehaviorProfileContext.withProfileID(selectedProfileID) {
                TodoManager.refreshTodoScreen()
                TodoManager.changeSidebarWidthUnit(to: todoSidebarWidthUnit)
                todoSidebarWidth = Defaults.todoSidebarWidth.value
                TodoManager.moveAllIfNeeded(false)
            }
        }
    }
    
    var todoSidebarSide: TodoSidebarSide {
        didSet {
            persistProfiledValue(CodableDefault(int: todoSidebarSide.rawValue), key: Defaults.todoSidebarSide.key) {
                Defaults.todoSidebarSide.value = todoSidebarSide
            }
            TodoManager.moveAllIfNeeded(false)
        }
    }
    
    var showAdditionalSizesInMenu: Bool {
        didSet {
            Defaults.showAdditionalSizesInMenu.enabled = showAdditionalSizesInMenu
            Notification.Name.showAdditionalSizesInMenuChanged.post()
        }
    }
    var cyclingOverlapOffset = false {
        didSet {
            persistProfiledValue(CodableDefault(int: cyclingOverlapOffset ? 1 : 2), key: Defaults.cyclingOverlapOffset.key) {
                Defaults.cyclingOverlapOffset.enabled = cyclingOverlapOffset
            }
        }
    }
    var stackBadge: Bool {
        didSet {
            Defaults.stackBadge.enabled = stackBadge
            Notification.Name.stackBadgeChanged.post()
        }
    }
    var stackSameSizeOnly: Bool {
        didSet {
            persistProfiledValue(CodableDefault(int: stackSameSizeOnly ? 1 : 2), key: Defaults.stackSameSizeOnly.key) {
                Defaults.stackSameSizeOnly.enabled = stackSameSizeOnly
            }
        }
    }
    /// Mirrors the App Settings restriction toggle, so the window action
    /// recorders here pick up a change made while Settings is open.
    var allowAnyShortcut = Defaults.allowAnyShortcut.enabled
    var horizontalSplitRatio: Float {
        didSet {
            persistProfiledValue(CodableDefault(float: horizontalSplitRatio), key: Defaults.horizontalSplitRatio.key) {
                Defaults.horizontalSplitRatio.value = horizontalSplitRatio
            }
            ActiveSideSplitRatios.shared.resetAll()
        }
    }
    var verticalSplitRatio: Float {
        didSet {
            persistProfiledValue(CodableDefault(float: verticalSplitRatio), key: Defaults.verticalSplitRatio.key) {
                Defaults.verticalSplitRatio.value = verticalSplitRatio
            }
            ActiveSideSplitRatios.shared.resetAll()
        }
    }
    var halvesPreserveOtherAxisSize: Bool {
        didSet {
            persistProfiledValue(CodableDefault(bool: halvesPreserveOtherAxisSize), key: Defaults.halvesPreserveOtherAxisSize.key) {
                Defaults.halvesPreserveOtherAxisSize.enabled = halvesPreserveOtherAxisSize
            }
        }
    }
    var mouseButtonShortcutsUseWindowUnderCursor: Bool {
        didSet { Defaults.mouseButtonShortcutsUseWindowUnderCursor.enabled = mouseButtonShortcutsUseWindowUnderCursor }
    }
    
    // Preset Selection States
    var selectedHSplitPreset: CycleSize?
    var selectedVSplitPreset: CycleSize?
    
    
    var repeatedMaximizeRestoresPrevious: Bool {
        didSet { Defaults.repeatedMaximizeRestoresPrevious.enabled = repeatedMaximizeRestoresPrevious }
    }
    
    // MARK: - Stage Manager Settings
    var stageSize: Double
    
    // MARK: - UI Conditional Flags
    var showCooperativeCornerResize: Bool { Defaults.cooperativeCornerResize.enabled }
    var showCursorScreenDetection: Bool { Defaults.useCursorScreenDetection.enabled }
    var showCombinedDisplayMode: Bool { !NSScreen.screensHaveSeparateSpaces }
    var stageCapable: Bool { StageUtil.stageCapable }
    
    private var aboutTodoWindowController: NSWindowController?
    
    // MARK: - Initialization
    init() {
        
        self.subsequentExecutionMode = Defaults.subsequentExecutionMode.value
        let isCycleChanged = Defaults.cycleSizesIsChanged.enabled
        self.selectedCycleSizes = isCycleChanged ? Defaults.selectedCycleSizes.value : CycleSize.defaultSizes
        self.cornerCycleExpansionAxis = Defaults.cornerCycleExpansionAxis.value
        self.cooperativeCornerResize = Defaults.cooperativeCornerResize.enabled
        
        self.gapSize = Double(Defaults.gapSize.value)
        let overlap = Defaults.overlapOffset
        self.overlapHorizontal = Double(overlap.dx)
        self.overlapVertical = Double(overlap.dy)
        self.edgeHorizontal = Double(Defaults.screenEdgeGapLeft.value)
        self.edgeVertical = Double(Defaults.screenEdgeGapTop.value)
        self.horizontalEdgesDiffer = Defaults.screenEdgeGapLeft.value != Defaults.screenEdgeGapRight.value
        self.verticalEdgesDiffer = Defaults.screenEdgeGapTop.value != Defaults.screenEdgeGapBottom.value
        self.skipGapTopEdge = Defaults.skipGapTopEdge.enabled
        
        self.moveCursorAcrossDisplays = Defaults.moveCursorAcrossDisplays.userEnabled
        self.centerAcrossDisplays = Defaults.centerAcrossDisplays.userEnabled
        self.useCursorScreenDetection = Defaults.useCursorScreenDetection.enabled
        
        self.doubleClickTitleBar = WindowAction(rawValue: Defaults.doubleClickTitleBar.value - 1) != nil
        self.autoMaximize = !Defaults.autoMaximize.userDisabled
        self.greenButtonOverride = Defaults.greenButtonOverride.enabled
        self.experimentalAnimations = Defaults.experimentalWindowAnimations.enabled
        self.combinedDisplayMode = Defaults.combinedDisplayMode.userEnabled
        self.repeatedMaximizeRestoresPrevious = Defaults.repeatedMaximizeRestoresPrevious.enabled
        
        self.todoEnabled = Defaults.todo.userEnabled
        self.todoSidebarWidth = Defaults.todoSidebarWidth.value
        self.todoSidebarWidthUnit = Defaults.todoSidebarWidthUnit.value
        self.todoSidebarSide = Defaults.todoSidebarSide.value
        
        self.stageSize = Double(Defaults.stageSize.value)
        
        let hRatio = Defaults.horizontalSplitRatio.value
        let vRatio = Defaults.verticalSplitRatio.value
        
        self.showAdditionalSizesInMenu = Defaults.showAdditionalSizesInMenu.userEnabled
        self.cyclingOverlapOffset = Defaults.cyclingOverlapOffset.userEnabled
        self.stackBadge = Defaults.stackBadge.userEnabled
        self.stackSameSizeOnly = Defaults.stackSameSizeOnly.userEnabled
        self.horizontalSplitRatio = hRatio
        self.verticalSplitRatio = vRatio
        self.halvesPreserveOtherAxisSize = Defaults.halvesPreserveOtherAxisSize.enabled
        self.mouseButtonShortcutsUseWindowUnderCursor = Defaults.mouseButtonShortcutsUseWindowUnderCursor.enabled
        
        self.selectedHSplitPreset = CycleSize.matching(percentValue: hRatio)
        self.selectedVSplitPreset = CycleSize.matching(percentValue: vRatio)
        self.showMinimumWindowSizeWarning = Defaults.showMinimumWindowSizeWarning.userEnabled
        
        setupObservers()
        reloadFromDefaults()
    }
    
    private func setupObservers() {
        Notification.Name.configImported.onPost { [weak self] _ in
            self?.reloadFromDefaults()
        }
        Notification.Name.displayBehaviorProfileChanged.onPost { [weak self] _ in
            self?.reloadFromDefaults()
        }
        Notification.Name.stackBadgeChanged.onPost { [weak self] _ in
            guard let self else { return }
            if self.stackBadge != Defaults.stackBadge.userEnabled {
                self.stackBadge = Defaults.stackBadge.userEnabled
            }
        }
        Notification.Name.allowAnyShortcut.onPost { [weak self] _ in
            self?.allowAnyShortcut = Defaults.allowAnyShortcut.enabled
        }
    }
    
    func reloadFromDefaults() {
        let previousProfileID = BehaviorProfileContext.setCurrentProfileID(selectedProfileID)
        defer { _ = BehaviorProfileContext.setCurrentProfileID(previousProfileID) }
        isLoadingProfile = true
        defer { isLoadingProfile = false }

        self.subsequentExecutionMode = Defaults.subsequentExecutionMode.value
        let hasCycleSizeOverride = BehaviorProfileStore.override(for: Defaults.selectedCycleSizes.key, profileID: selectedProfileID) != nil
        let isCycleChanged = hasCycleSizeOverride || Defaults.cycleSizesIsChanged.enabled
        self.selectedCycleSizes = isCycleChanged ? Defaults.selectedCycleSizes.value : CycleSize.defaultSizes
        self.cornerCycleExpansionAxis = Defaults.cornerCycleExpansionAxis.value
        self.cooperativeCornerResize = Defaults.cooperativeCornerResize.enabled
        
        self.gapSize = Double(Defaults.gapSize.value)
        let overlap = Defaults.overlapOffset
        self.overlapHorizontal = Double(overlap.dx)
        self.overlapVertical = Double(overlap.dy)
        self.edgeHorizontal = Double(Defaults.screenEdgeGapLeft.value)
        self.edgeVertical = Double(Defaults.screenEdgeGapTop.value)
        self.horizontalEdgesDiffer = Defaults.screenEdgeGapLeft.value != Defaults.screenEdgeGapRight.value
        self.verticalEdgesDiffer = Defaults.screenEdgeGapTop.value != Defaults.screenEdgeGapBottom.value
        self.skipGapTopEdge = Defaults.skipGapTopEdge.enabled
        
        self.moveCursorAcrossDisplays = Defaults.moveCursorAcrossDisplays.userEnabled
        self.centerAcrossDisplays = Defaults.centerAcrossDisplays.userEnabled
        self.useCursorScreenDetection = Defaults.useCursorScreenDetection.enabled
        
        self.doubleClickTitleBar = WindowAction(rawValue: Defaults.doubleClickTitleBar.value - 1) != nil
        self.autoMaximize = !Defaults.autoMaximize.userDisabled
        self.greenButtonOverride = Defaults.greenButtonOverride.enabled
        self.experimentalAnimations = Defaults.experimentalWindowAnimations.enabled
        self.combinedDisplayMode = Defaults.combinedDisplayMode.userEnabled
        self.repeatedMaximizeRestoresPrevious = Defaults.repeatedMaximizeRestoresPrevious.enabled
        
        self.todoEnabled = Defaults.todo.userEnabled
        self.todoSidebarWidth = Defaults.todoSidebarWidth.value
        self.todoSidebarWidthUnit = Defaults.todoSidebarWidthUnit.value
        self.todoSidebarSide = Defaults.todoSidebarSide.value
        
        self.stageSize = Double(Defaults.stageSize.value)
        
        let hRatio = Defaults.horizontalSplitRatio.value
        let vRatio = Defaults.verticalSplitRatio.value
        
        self.showAdditionalSizesInMenu = Defaults.showAdditionalSizesInMenu.userEnabled
        self.cyclingOverlapOffset = Defaults.cyclingOverlapOffset.userEnabled
        self.stackBadge = Defaults.stackBadge.userEnabled
        self.stackSameSizeOnly = Defaults.stackSameSizeOnly.userEnabled
        self.allowAnyShortcut = Defaults.allowAnyShortcut.enabled
        self.horizontalSplitRatio = hRatio
        self.verticalSplitRatio = vRatio
        self.halvesPreserveOtherAxisSize = Defaults.halvesPreserveOtherAxisSize.enabled
        self.mouseButtonShortcutsUseWindowUnderCursor = Defaults.mouseButtonShortcutsUseWindowUnderCursor.enabled
        
        self.selectedHSplitPreset = CycleSize.matching(percentValue: hRatio)
        self.selectedVSplitPreset = CycleSize.matching(percentValue: vRatio)
        self.showMinimumWindowSizeWarning = Defaults.showMinimumWindowSizeWarning.userEnabled
    }
    
    // MARK: - Cycle Sizes Binding Helper
    func binding(for size: CycleSize) -> Binding<Bool> {
        Binding(
            get: { self.selectedCycleSizes.contains(size) },
            set: { isChecked in
                if self.selectedProfileID != BehaviorProfileStore.defaultProfileID {
                    if isChecked {
                        self.selectedCycleSizes.insert(size)
                    } else {
                        self.selectedCycleSizes.remove(size)
                    }
                    BehaviorProfileStore.setOverride(
                        CodableDefault(int: self.selectedCycleSizes.toBits()),
                        for: Defaults.selectedCycleSizes.key,
                        profileID: self.selectedProfileID
                    )
                    return
                }

                if !Defaults.cycleSizesIsChanged.enabled {
                    Defaults.selectedCycleSizes.value = CycleSize.defaultSizes
                }
                Defaults.cycleSizesIsChanged.enabled = true
                
                if isChecked {
                    self.selectedCycleSizes.insert(size)
                } else {
                    self.selectedCycleSizes.remove(size)
                }
                Defaults.selectedCycleSizes.value = self.selectedCycleSizes
            }
        )
    }
    
    // MARK: - Action Handlers
    func commitOverlapHorizontal() {
        persistProfiledValue(CodableDefault(double: overlapHorizontal), key: Defaults.cyclingOverlapOffsetHorizontal.key) {
            Defaults.cyclingOverlapOffsetHorizontal.value = overlapHorizontal
        }
    }

    func commitOverlapVertical() {
        persistProfiledValue(CodableDefault(double: overlapVertical), key: Defaults.cyclingOverlapOffsetVertical.key) {
            Defaults.cyclingOverlapOffsetVertical.value = overlapVertical
        }
    }

    func commitEdgeHorizontal() {
        for setting in [Defaults.screenEdgeGapLeft, Defaults.screenEdgeGapRight] {
            persistProfiledValue(CodableDefault(float: Float(edgeHorizontal)), key: setting.key) {
                setting.value = Float(edgeHorizontal)
            }
        }
        horizontalEdgesDiffer = false
    }

    func commitEdgeVertical() {
        for setting in [Defaults.screenEdgeGapTop, Defaults.screenEdgeGapBottom] {
            persistProfiledValue(CodableDefault(float: Float(edgeVertical)), key: setting.key) {
                setting.value = Float(edgeVertical)
            }
        }
        verticalEdgesDiffer = false
    }

    func commitGapSize() {
        persistProfiledValue(CodableDefault(float: Float(gapSize)), key: Defaults.gapSize.key) {
            Defaults.gapSize.value = Float(gapSize)
        }
    }

    func commitStageSize() {
        let value: Float = stageSize == 0 ? -1 : Float(stageSize)
        persistProfiledValue(CodableDefault(float: value), key: Defaults.stageSize.key) {
            Defaults.stageSize.value = value
        }
    }
    
    func commitTodoWidth() {
        TodoManager.moveAllIfNeeded(false)
    }
    
    private func handleDoubleClickTitleBarToggle(_ enabled: Bool) {
        if enabled && !TitleBarManager.systemSettingDisabled {
            let openSettings = String(localized: "Open System Settings")
            let conflictTitleText = String(localized: "Conflict with system setting")
            let conflictDescriptionText = String(localized: "To let JRectangle manage the title bar double click functionality, you need to disable the corresponding macOS setting.")
            let closeText = String(localized: "Close")
            
            Task {
                await MainActor.run {
                    let response = AlertUtil.twoButtonAlert(question: conflictTitleText, text: conflictDescriptionText, confirmText: openSettings, cancelText: closeText)
                    if response == .alertFirstButtonReturn {
                        if let systemSettingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.dock") {
                            NSWorkspace.shared.open(systemSettingsURL)
                        }
                    }
                }
            }
        }
        Defaults.doubleClickTitleBar.value = (enabled ? WindowAction.maximize.rawValue : -1) + 1
        Notification.Name.windowTitleBar.post()
    }
    
    func showTodoModeHelp() {
        if aboutTodoWindowController == nil {
            aboutTodoWindowController = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "AboutTodoWindowController") as? NSWindowController
        }
        NSApp.activate(ignoringOtherApps: true)
        aboutTodoWindowController?.showWindow(nil)
    }
    
    func exportConfig() {
        Notification.Name.windowSnapping.post(object: false)
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "RectangleConfig"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                if let jsonString = Defaults.encoded() {
                    try jsonString.write(to: url, atomically: false, encoding: .utf8)
                }
            } catch {
                Logger.log(error.localizedDescription)
            }
        }
        Notification.Name.windowSnapping.post(object: true)
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
    
    func selectHSplitPreset(_ preset: CycleSize?) {
        selectedHSplitPreset = preset
        if let percentValue = preset?.percentValue {
            horizontalSplitRatio = percentValue
        }
    }
    
    func selectVSplitPreset(_ preset: CycleSize?) {
        selectedVSplitPreset = preset
        if let percentValue = preset?.percentValue {
            verticalSplitRatio = percentValue
        }
    }
}
