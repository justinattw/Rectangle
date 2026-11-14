import AppKit
import MASShortcut
import SwiftUI

// MARK: - AppKit View Controller Wrapper
final class BehaviorSettingsViewController: NSViewController {
    private var hostingController: NSHostingController<BehaviorSettingsView>?

    override func viewDidLoad() {
        super.viewDidLoad()

        let swiftUIView = BehaviorSettingsView()
        let hostingController = NSHostingController(rootView: swiftUIView)
        self.hostingController = hostingController
        
        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingController.view)
        
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

// MARK: - SwiftUI Settings View
@MainActor
struct BehaviorSettingsView: View {
    @State private var viewModel = BehaviorSettingsViewModel()
    
    // Popover state
    @State private var showTodoInfoPopover = false

    // Cached formatter to avoid expensive re-allocations during view body updates
    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.allowsFloats = false
        formatter.minimum = 1
        formatter.maximum = 99
        return formatter
    }()

    var body: some View {
        Form {
            // MARK: - Cycle Sizes & Window Behaviors
            Section {
                HStack {
                    Text("Repeated commands")
                        .foregroundColor(overrideColor(Defaults.subsequentExecutionMode.key))
                    Spacer()
                    Picker("", selection: $viewModel.subsequentExecutionMode) {
                        ForEach(SubsequentExecutionMode.ordered, id: \.self) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                }
                
                if viewModel.subsequentExecutionMode.resizes {
                    VStack(alignment: .leading, spacing: 8) {
                        // Keep fraction choices as compact checkboxes
                        HStack(spacing: 12) {
                            Spacer()
                            ForEach(CycleSize.sortedSizes, id: \.self) { size in
                                Toggle(size.title, isOn: viewModel.binding(for: size))
                                    .toggleStyle(.checkbox)
                            }
                        }
                        .foregroundColor(overrideColor(Defaults.selectedCycleSizes.key))
                        
                        HStack(spacing: 12) {
                            Text("Cyclic corner shortcuts expand")
                                .foregroundColor(overrideColor(Defaults.cornerCycleExpansionAxis.key))
                            Spacer()
                            Picker("", selection: $viewModel.cornerCycleExpansionAxis) {
                                Text("horizontally").tag(CornerCycleExpansionAxis.horizontal)
                                Text("vertically").tag(CornerCycleExpansionAxis.vertical)
                            }
                            .pickerStyle(.radioGroup)
                            .horizontalRadioGroupLayout()
                        }
                        
                        if viewModel.showCooperativeCornerResize {
                            Toggle("Resize adjacent windows when cycling side or corner shortcuts", isOn: $viewModel.cooperativeCornerResize)
                                .toggleStyle(.switch)
                                .foregroundColor(overrideColor(Defaults.cooperativeCornerResize.key))
                        }
                    }
                    .padding(.leading, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            
            // MARK: - Gaps
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Gaps between windows")
                            .foregroundColor(overrideColor(Defaults.gapSize.key))
                        Spacer(minLength: 8)
                        Slider(
                            value: $viewModel.gapSize,
                            in: 0...100,
                            onEditingChanged: { editing in
                                if !editing { viewModel.commitGapSize() }
                            }
                        )
                        .frame(width: 120)
                        Text("\(Int(viewModel.gapSize)) px")
                            .frame(width: 45, alignment: .trailing)
                    }
                    
                    if viewModel.gapSize > 0 {
                        Toggle("Remove top gap when snapping to top edge", isOn: $viewModel.skipGapTopEdge)
                            .toggleStyle(.switch)
                            .foregroundColor(overrideColor(Defaults.skipGapTopEdge.key))
                    }
                    HStack {
                        Text("Horizontal display edge margins")
                            .foregroundColor(overrideColor(Defaults.screenEdgeGapLeft.key, Defaults.screenEdgeGapRight.key))
                        Spacer(minLength: 8)
                        Slider(value: pixelBinding($viewModel.edgeHorizontal), in: 0...100,
                               onEditingChanged: { if !$0 { viewModel.commitEdgeHorizontal() } })
                            .frame(width: 120)
                        Text("\(Int(viewModel.edgeHorizontal)) px").frame(width: 45, alignment: .trailing)
                    }
                    HStack {
                        Text("Vertical display edge margins")
                            .foregroundColor(overrideColor(Defaults.screenEdgeGapTop.key, Defaults.screenEdgeGapBottom.key))
                        Spacer(minLength: 8)
                        Slider(value: pixelBinding($viewModel.edgeVertical), in: 0...100,
                               onEditingChanged: { if !$0 { viewModel.commitEdgeVertical() } })
                            .frame(width: 120)
                        Text("\(Int(viewModel.edgeVertical)) px").frame(width: 45, alignment: .trailing)
                    }
                    if viewModel.horizontalEdgesDiffer || viewModel.verticalEdgesDiffer {
                        Text("Some existing edge margins differ. Changing an axis sets both edges equally.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Text("A separately configured notch margin and main-screen-only setting still apply.")
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            // MARK: - Maximize
            Section {
                CustomDisclosureGroup {
                    VStack(alignment: .leading, spacing: 12) {
                        Divider()
                        if viewModel.showCursorScreenDetection {
                            Toggle("Use cursor screen detection", isOn: $viewModel.useCursorScreenDetection)
                        }
                        
                        Toggle("Double-click window title bar to maximize/restore", isOn: $viewModel.doubleClickTitleBar)
                        Toggle("Repeated maximize restores the previous size and position", isOn: $viewModel.repeatedMaximizeRestoresPrevious)

                        VStack(alignment: .leading, spacing: 2) {
                            Toggle("Green stoplight button maximizes instead of Full Screen", isOn: $viewModel.greenButtonOverride)
                            Text("Hold any modifier key or use the window menu for default macOS behavior")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 4)
                    .padding(.leading, 12)
                } label: {
                    Label("Maximize Settings", systemImage: "arrow.up.left.and.arrow.down.right")
                }
            }

            // MARK: - Across Display Settings
            Section {
                CustomDisclosureGroup {
                    VStack(alignment: .leading, spacing: 12) {
                        Divider()
                        Toggle("Move cursor along with window across displays", isOn: $viewModel.moveCursorAcrossDisplays)
                            .foregroundColor(overrideColor(Defaults.moveCursorAcrossDisplays.key))
                        Toggle("Preserve maximize state when moving across displays", isOn: $viewModel.autoMaximize)
                            .foregroundColor(overrideColor(Defaults.autoMaximize.key))
                        VStack(alignment: .leading, spacing: 2) {
                            Toggle("Center windows when moving across displays", isOn: $viewModel.centerAcrossDisplays)
                                .foregroundColor(overrideColor(Defaults.centerAcrossDisplays.key))
                            Text("When off, window-to-screen edges are preserved where applicable.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 4)
                    .padding(.leading, 12)
                } label: {
                    Label("Across Display Settings", systemImage: "display.2")
                        .foregroundColor(overrideColor(Defaults.moveCursorAcrossDisplays.key, Defaults.autoMaximize.key,
                                                       Defaults.centerAcrossDisplays.key))
                }
            }

            // MARK: - Stacked Windows
            Section {
                CustomDisclosureGroup {
                    VStack(alignment: .leading, spacing: 12) {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Offset window position on overlap", isOn: $viewModel.cyclingOverlapOffset)
                                .foregroundColor(overrideColor(Defaults.cyclingOverlapOffset.key))
                            Text("When enabled, newly placed windows shift slightly if another window already occupies that position.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack {
                                Text("Horizontal overlap offset")
                                    .foregroundColor(overrideColor(Defaults.cyclingOverlapOffsetHorizontal.key, Defaults.cyclingOverlapOffsetSize.key))
                                Spacer(minLength: 8)
                                Slider(value: pixelBinding($viewModel.overlapHorizontal), in: 0...100,
                                       onEditingChanged: { if !$0 { viewModel.commitOverlapHorizontal() } })
                                    .frame(width: 120)
                                Text("\(Int(viewModel.overlapHorizontal)) px").frame(width: 45, alignment: .trailing)
                            }
                            HStack {
                                Text("Vertical overlap offset")
                                    .foregroundColor(overrideColor(Defaults.cyclingOverlapOffsetVertical.key, Defaults.cyclingOverlapOffsetSize.key))
                                Spacer(minLength: 8)
                                Slider(value: pixelBinding($viewModel.overlapVertical), in: 0...100,
                                       onEditingChanged: { if !$0 { viewModel.commitOverlapVertical() } })
                                    .frame(width: 120)
                                Text("\(Int(viewModel.overlapVertical)) px").frame(width: 45, alignment: .trailing)
                            }
                            Text("Offsets only apply where there is room within the display's usable area.")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Only stack windows of the same size", isOn: $viewModel.stackSameSizeOnly)
                                .foregroundColor(overrideColor(Defaults.stackSameSizeOnly.key))
                            Text("For the window list and the cycle shortcuts. When off, windows stacked at the same top-left position count whatever their size")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Show stacked window list on hover", isOn: $viewModel.stackBadge)
                            Text("Hover cursor near the top left corner of a window to show the list")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("Toggle window list")
                            Spacer()
                            MASShortcutViewRepresentable(defaultsKey: StackBadgeManager.toggleDefaultsKey, validator: nil,
                                                         recordingObserver: viewModel.shortcutRecordingObserver)
                                .frame(width: 160, height: 24)
                        }
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Cycle windows on this Space")
                                Spacer()
                                MASShortcutViewRepresentable(
                                    defaultsKey: CurrentSpaceWindowSwitcher.shortcutDefaultsKey,
                                    validator: nil,
                                    recordingObserver: viewModel.shortcutRecordingObserver
                                )
                                .frame(width: 160, height: 24)
                            }
                            Text("Cycles through visible windows on the current Space. Command-Tab remains macOS's app switcher.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Cycle stacked windows")
                                Spacer()
                                windowActionShortcutView(.cycleStackedWindows)
                            }
                            HStack {
                                Text("Cycle stacked windows backward")
                                Spacer()
                                windowActionShortcutView(.cycleStackedWindowsBackward)
                            }
                            Text("Bring forward the windows snapped to the same area as the focused window, one at a time")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 4)
                    .padding(.leading, 12)
                } label: {
                    Label("Stacked Windows", systemImage: "square.on.square")
                        .foregroundColor(overrideColor(Defaults.cyclingOverlapOffset.key,
                                                       Defaults.cyclingOverlapOffsetSize.key, Defaults.cyclingOverlapOffsetHorizontal.key,
                                                       Defaults.cyclingOverlapOffsetVertical.key, Defaults.stackSameSizeOnly.key))
                }
            }

            // MARK: - Side Split Ratios
            Section {
                CustomDisclosureGroup {
                    VStack(alignment: .leading, spacing: 10) {
                        Divider()
                        Text("Configure the divide between side and corner actions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Text("Horizontal (L/R, %)")
                                .foregroundColor(overrideColor(Defaults.horizontalSplitRatio.key))
                            Spacer()

                            if viewModel.selectedHSplitPreset == nil {
                                TextField("", value: $viewModel.horizontalSplitRatio, formatter: Self.percentFormatter)
                                    .multilineTextAlignment(.trailing)
                            }

                            Picker("", selection: Binding(
                                get: { viewModel.selectedHSplitPreset },
                                set: { viewModel.selectHSplitPreset($0) }
                            )) {
                                ForEach(CycleSize.sortedSizes, id: \.self) { size in
                                    Text(size.title).tag(Optional(size))
                                }
                                Text("Other").tag(Optional<CycleSize>.none)
                            }
                            .labelsHidden()
                        }

                        HStack {
                            Text("Vertical (T/B, %)")
                                .foregroundColor(overrideColor(Defaults.verticalSplitRatio.key))
                            Spacer()

                            if viewModel.selectedVSplitPreset == nil {
                                TextField("", value: $viewModel.verticalSplitRatio, formatter: Self.percentFormatter)
                                    .multilineTextAlignment(.trailing)
                            }

                            Picker("", selection: Binding(
                                get: { viewModel.selectedVSplitPreset },
                                set: { viewModel.selectVSplitPreset($0) }
                            )) {
                                ForEach(CycleSize.sortedSizes, id: \.self) { size in
                                    Text(size.title).tag(Optional(size))
                                }
                                Text("Other").tag(Optional<CycleSize>.none)
                            }
                            .labelsHidden()
                        }
                    }
                    .padding(.top, 4)
                    .padding(.leading, 12)
                } label: {
                    Label("Side Split Ratio", systemImage: "rectangle.split.2x1")
                        .foregroundColor(overrideColor(Defaults.horizontalSplitRatio.key, Defaults.verticalSplitRatio.key))
                }
            }
            
            // MARK: - Todo Mode
            Section {
                CustomDisclosureGroup {
                    VStack(alignment: .leading, spacing: 12) {
                        Divider()
                        
                        Toggle("Show Todo Mode in menu", isOn: $viewModel.todoEnabled)
                        
                        // Dynamically show/hide the controls based on toggle state
                        if viewModel.todoEnabled {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Todo app width")
                                        .foregroundColor(overrideColor(Defaults.todoSidebarWidth.key, Defaults.todoSidebarWidthUnit.key))
                                    Spacer()
                                    HStack(spacing: 4) {
                                        TextField("", value: $viewModel.todoSidebarWidth, format: .number)
                                            .frame(width: 100)
                                            .textFieldStyle(.roundedBorder)
                                            .onSubmit { viewModel.commitTodoWidth() }
                                        
                                        Picker("", selection: $viewModel.todoSidebarWidthUnit) {
                                            Text("px").tag(TodoSidebarWidthUnit.pixels)
                                            Text("%").tag(TodoSidebarWidthUnit.pct)
                                        }
                                        .labelsHidden()
                                        .fixedSize()
                                    }
                                }
                                
                                HStack {
                                    Text("Todo side")
                                        .foregroundColor(overrideColor(Defaults.todoSidebarSide.key))
                                    Spacer()
                                    Picker("", selection: $viewModel.todoSidebarSide) {
                                        Text("Left").tag(TodoSidebarSide.left)
                                        Text("Right").tag(TodoSidebarSide.right)
                                    }
                                    .frame(width: 90)
                                }
                                
                                HStack {
                                    Text("Toggle Todo")
                                    Spacer()
                                    MASShortcutViewRepresentable(
                                        defaultsKey: TodoManager.toggleDefaultsKey,
                                        validator: TodoShortcutValidator(defaultsKey: TodoManager.toggleDefaultsKey),
                                        recordingObserver: viewModel.shortcutRecordingObserver
                                    )
                                    .frame(width: 130, height: 22)
                                }
                                
                                HStack {
                                    Text("Reflow Todo")
                                    Spacer()
                                    MASShortcutViewRepresentable(
                                        defaultsKey: TodoManager.reflowDefaultsKey,
                                        validator: TodoShortcutValidator(defaultsKey: TodoManager.reflowDefaultsKey),
                                        recordingObserver: viewModel.shortcutRecordingObserver
                                    )
                                    .frame(width: 130, height: 22)
                                }
                            }
                            .transition(.opacity)
                        }
                    }
                    .padding(.leading, 12)
                } label: {
                    HStack(spacing: 6) {
                        Label("Todo Mode", systemImage: "list.bullet.rectangle.portrait")
                            .foregroundColor(overrideColor(Defaults.todoSidebarWidth.key, Defaults.todoSidebarWidthUnit.key,
                                                           Defaults.todoSidebarSide.key))
                        
                        Button(action: { showTodoInfoPopover.toggle() }) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showTodoInfoPopover, arrowEdge: .trailing) {
                            TodoModeInfoView()
                        }
                    }
                }
            }
            
            // MARK: - Stage Manager
            if viewModel.stageCapable {
                Section {
                    CustomDisclosureGroup {
                        VStack(alignment: .leading, spacing: 4) {
                            Divider()
                            HStack {
                                Text("Recent apps area")
                                    .foregroundColor(overrideColor(Defaults.stageSize.key))
                                Spacer(minLength: 8)
                                Slider(
                                    value: $viewModel.stageSize,
                                    in: 0...400,
                                    onEditingChanged: { editing in
                                        if !editing { viewModel.commitStageSize() }
                                    }
                                )
                                .frame(width: 120)
                                Text("\(Int(viewModel.stageSize)) px")
                                    .frame(width: 45, alignment: .trailing)
                            }
                            Text("If the area is too small, recent apps will be hidden")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                        .padding(.leading, 12)
                    } label: {
                        Label("Stage Manager", systemImage: "squares.leading.rectangle")
                            .foregroundColor(overrideColor(Defaults.stageSize.key))
                    }
                }
            }
            
            // MARK: - Extras
            Section {
                CustomDisclosureGroup {
                    VStack(alignment: .leading, spacing: 12) {
                        Divider()
                        Toggle("Animate windows", isOn: $viewModel.experimentalAnimations)
                        Toggle("Preserve side axis size for half actions, similar to Windows", isOn: $viewModel.halvesPreserveOtherAxisSize)
                            .foregroundColor(overrideColor(Defaults.halvesPreserveOtherAxisSize.key))
                        Toggle("Show warning when windows cannot be resized small enough", isOn: $viewModel.showMinimumWindowSizeWarning)
                        Toggle("Show *Extra* shortcuts in menu", isOn: $viewModel.showAdditionalSizesInMenu)
                        VStack(alignment: .leading, spacing: 2) {
                            Toggle("Mouse button shortcuts act on the window under the pointer", isOn: $viewModel.mouseButtonShortcutsUseWindowUnderCursor)
                            Text("Keyboard shortcuts always act on the focused window")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if viewModel.showCombinedDisplayMode {
                            VStack(alignment: .leading, spacing: 2) {
                                Toggle("Treat multiple displays as one", isOn: $viewModel.combinedDisplayMode)
                                Text("When using multiple displays, treats them as a single display. Requires System Settings > Desktop & Dock > Displays have separate Spaces to be OFF.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.top, 4)
                    .padding(.leading, 12)
                } label: {
                    Label("Extras", systemImage: "ellipsis.viewfinder")
                        .foregroundColor(overrideColor(Defaults.halvesPreserveOtherAxisSize.key))
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 500)
        .animation(.easeInOut(duration: 0.2), value: viewModel.todoEnabled)
        .animation(.easeInOut(duration: 0.2), value: viewModel.subsequentExecutionMode)
    }

    private func overrideColor(_ keys: String...) -> Color {
        let selection = DisplayProfileSelectionModel.shared
        _ = selection.overrideCount
        return keys.contains { BehaviorProfileStore.override(for: $0, profileID: selection.selectedProfileID) != nil }
            ? .blue : .primary
    }

    private func pixelBinding(_ value: Binding<Double>) -> Binding<Double> {
        Binding(get: { value.wrappedValue }, set: { value.wrappedValue = $0.rounded() })
    }

    /// A recorder for a window action's shortcut, validated like the ones on
    /// the Shortcuts tab.
    private func windowActionShortcutView(_ action: WindowAction) -> some View {
        MASShortcutViewRepresentable(
            defaultsKey: action.name,
            validator: viewModel.allowAnyShortcut ? PassthroughShortcutValidator() : MASShortcutValidator(),
            recordingObserver: viewModel.shortcutRecordingObserver,
            recordsMouseButtons: true
        )
        .frame(width: 160, height: 24)
    }
}

// MARK: - Todo Mode Info Popover View
struct TodoModeInfoView: View {
    // Structural data wrapper to hold LocalizedStringKey
    private struct Step: Identifiable {
        let id: Int
        let number: String
        let text: LocalizedStringKey
    }

    private let steps: [Step] = [
        Step(id: 1, number: "1.", text: "Bring your chosen todo application frontmost"),
        Step(id: 2, number: "2.", text: "In the Rectangle menu, select\n\"Use [Application] as Todo App\""),
        Step(id: 3, number: "3.", text: "In the Rectangle menu, enable Todo Mode.")
    ]

    var body: some View {
        VStack(spacing: 16) {
            Text("About Todo Mode")
                .font(.title2)
                .bold()

            Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)

            Text("Keep a chosen application visible on the right side of your primary screen at all times")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .foregroundColor(.secondary)

            // MARK: - Formatted Steps
            VStack(alignment: .leading, spacing: 10) {
                ForEach(steps) { step in
                    HStack(alignment: .top, spacing: 10) {
                        Text(step.number)
                            .font(.body)
                            .bold()
                            .foregroundColor(.accentColor)

                        Text(step.text)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            Text("While in Todo Mode, you can refresh the Todo Mode layout by selecting \"Reflow Todo\" in the Rectangle menu or executing the associated keyboard shortcut.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding(20)
        .frame(width: 330)
    }
}
