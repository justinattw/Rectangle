/// SettingsWindowController.swift

import AppKit
import SwiftUI

class SettingsWindowController: NSWindowController, NSWindowDelegate {

    var onClose: (() -> Void)?
    private var settingsTabViewController: SettingsTabViewController?

    convenience init() {
        let tabsViewController = SettingsTabViewController()
        let contentViewController = SettingsWindowContentViewController(tabViewController: tabsViewController)
        let window = NSWindow(contentViewController: contentViewController)

        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]

        let initialTab = SettingsTabViewController.currentTab
        window.title = initialTab.label
        let minimumContentSize = NSSize(width: 500, height: 350)
        let minimumFrameSize = NSSize(width: minimumContentSize.width,
                                      height: minimumContentSize.height + SettingsTabViewController.profilePickerHeaderHeight)
        if let savedWindowSize = initialTab.savedWindowSize {
            tabsViewController.resizeWindow(toFrameSize: savedWindowSize, animated: false)
        } else {
            let initialSize = initialTab.defaultSize
            ?? tabsViewController.tabViewItems[initialTab.rawValue].viewController?.view.fittingSize
            ?? minimumContentSize
            window.setContentSize(NSSize(width: initialSize.width,
                                         height: initialSize.height + SettingsTabViewController.profilePickerHeaderHeight))
        }
        window.minSize = minimumFrameSize
        window.center()

        self.init(window: window)
        settingsTabViewController = tabsViewController
        window.delegate = self
    }

    func windowWillClose(_ notification: Notification) {
        settingsTabViewController?.saveCurrentSize()
        onClose?()
        DispatchQueue.main.async { self.window?.contentViewController = nil }
    }
}

private final class SettingsWindowContentViewController: NSViewController {
    private let tabViewController: SettingsTabViewController

    init(tabViewController: SettingsTabViewController) {
        self.tabViewController = tabViewController
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        addChild(tabViewController)
        let profilePickerView = NSHostingView(rootView: DisplayProfilePickerView())
        profilePickerView.translatesAutoresizingMaskIntoConstraints = false
        let tabsView = tabViewController.view
        tabsView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(profilePickerView)
        view.addSubview(tabsView)

        NSLayoutConstraint.activate([
            profilePickerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            profilePickerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            profilePickerView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -12),
            profilePickerView.heightAnchor.constraint(equalToConstant: 32),
            tabsView.topAnchor.constraint(equalTo: profilePickerView.bottomAnchor, constant: 4),
            tabsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabsView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}

@Observable
final class DisplayProfileSelectionModel {
    static let shared = DisplayProfileSelectionModel()
    private static let selectedProfileDefaultsKey = "selectedDisplayBehaviorProfile"

    private(set) var selectedProfileID: String
    private(set) var overrideCount = 0
    private(set) var overrideKeys: [String] = []
    private(set) var connectedScreens = NSScreen.screens

    var availableProfileIDs: [String] {
        let connectedProfiles = connectedScreens.map(\.behaviorProfileID)
        return [BehaviorProfileStore.defaultProfileID] + Set(connectedProfiles + BehaviorProfileStore.profileIDs + [selectedProfileID])
            .filter { $0 != BehaviorProfileStore.defaultProfileID }
            .sorted()
    }

    var statusDescription: String {
        if selectedProfileID == BehaviorProfileStore.defaultProfileID {
            return "Global defaults"
        }
        return overrideCount == 0 ? "Inherits defaults" : "Overrides \(overrideCount) settings"
    }

    private init() {
        selectedProfileID = JSONPreferences.shared.string(forKey: Self.selectedProfileDefaultsKey)
            ?? BehaviorProfileStore.defaultProfileID
        refreshOverrideCount()
        Notification.Name.displayBehaviorProfileOverridesChanged.onPost { [weak self] _ in
            self?.refreshOverrideCount()
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            self?.connectedScreens = NSScreen.screens
            BehaviorProfileStore.registerProfiles(NSScreen.screens.map(\.behaviorProfileID))
        }
    }

    func profileTitle(for profileID: String) -> String {
        guard profileID != BehaviorProfileStore.defaultProfileID else { return "Default" }
        let components = profileID.split(separator: "x")
        guard components.count == 2 else { return profileID }
        let builtIn = connectedScreens.contains {
            guard $0.behaviorProfileID == profileID,
                  let number = $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
            return CGDisplayIsBuiltin(CGDirectDisplayID(number.uint32Value)) != 0
        }
        return "\(components[0]) × \(components[1])" + (builtIn ? " (Built-in)" : "")
    }

    func selectProfile(_ profileID: String) {
        guard availableProfileIDs.contains(profileID), selectedProfileID != profileID else { return }
        selectedProfileID = profileID
        JSONPreferences.shared.set(profileID, forKey: Self.selectedProfileDefaultsKey)
        refreshOverrideCount()
        Notification.Name.displayBehaviorProfileChanged.post()
    }

    func resetSelectedProfile() {
        guard selectedProfileID != BehaviorProfileStore.defaultProfileID, overrideCount > 0 else { return }
        BehaviorProfileStore.reset(profileID: selectedProfileID)
        refreshOverrideCount()
        Notification.Name.displayBehaviorProfileChanged.post()
    }

    func removeSelectedProfile() {
        let profileID = selectedProfileID
        guard profileID != BehaviorProfileStore.defaultProfileID else { return }
        let response = AlertUtil.twoButtonAlert(
            question: "Remove display profile?",
            text: "Remove the saved profile for \(profileTitle(for: profileID)) and all of its overrides? A connected resolution will be discovered again when displays change or JRectangle restarts.",
            confirmText: "Remove",
            cancelText: "Cancel"
        )
        guard response == .alertFirstButtonReturn else { return }
        selectProfile(BehaviorProfileStore.defaultProfileID)
        BehaviorProfileStore.removeProfile(profileID)
    }

    private func refreshOverrideCount() {
        overrideCount = BehaviorProfileStore.overrideCount(for: selectedProfileID)
        overrideKeys = (Defaults.displayBehaviorProfiles.typedValue?[selectedProfileID] ?? [:]).keys.sorted()
    }
}

private struct DisplayProfilePickerView: View {
    @State private var viewModel = DisplayProfileSelectionModel.shared

    var body: some View {
        HStack(spacing: 6) {
            Text("Display profile")

            Picker("Display profile", selection: Binding(
                get: { viewModel.selectedProfileID },
                set: { viewModel.selectProfile($0) }
            )) {
                ForEach(viewModel.availableProfileIDs, id: \.self) { profileID in
                    Text(viewModel.profileTitle(for: profileID)).tag(profileID)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()

            Text(viewModel.statusDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()

            if viewModel.selectedProfileID != BehaviorProfileStore.defaultProfileID {
                Menu("Profile") {
                    if viewModel.overrideCount > 0 {
                        Menu("Inherit a setting from Default") {
                            ForEach(viewModel.overrideKeys, id: \.self) { key in
                                Button(key.replacingOccurrences(of: "shortcut:", with: "Shortcut: ")) {
                                    BehaviorProfileStore.removeOverride(for: key, profileID: viewModel.selectedProfileID)
                                }
                            }
                        }
                        Button("Use Default for All Settings") {
                            viewModel.resetSelectedProfile()
                        }
                        Divider()
                    }
                    Button("Remove Profile") {
                        viewModel.removeSelectedProfile()
                    }
                }
                .controlSize(.small)
                .fixedSize()
                .help("Inherit individual settings, clear overrides, or remove this saved profile.")
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
    }
}

class SettingsTabViewController: NSTabViewController {
    static var currentTab: Tab = .shortcuts
    static var savedWindowSizes: [Int: NSSize] = [:]
    static let profilePickerHeaderHeight: CGFloat = 42
    
    enum Tab: Int, CaseIterable {
        case shortcuts
        case snapAreas
        case behavior
        case appSettings
        
        var label: String {
            switch self {
            case .shortcuts:   return String(localized:"Shortcuts")
            case .snapAreas:   return String(localized:"Snap Areas")
            case .behavior:    return String(localized:"Behavior")
            case .appSettings: return String(localized:"App Settings")
            }
        }
        
        var imageName: String {
            switch self {
            case .shortcuts:   return "keyboardToolbarTemplate"
            case .snapAreas:   return "snapAreaTemplate"
            case .behavior:    return "toolbarSettingsTemplate"
            case .appSettings: return "appSettingsTemplate"
            }
        }
        
        var defaultSize: NSSize? {
            switch self {
            case .shortcuts:   return NSSize(width: 500, height: 540)
            default: return nil
            }
        }
        
        func makeViewController() -> NSViewController {
            switch self {
            case .shortcuts:
                return ShortcutsViewController()
            case .snapAreas:
                return SnapAreaSettingsViewController()
            case .behavior:
                return BehaviorSettingsViewController()
            case .appSettings:
                return AppSettingsViewController()
            }
        }
        
        var savedWindowSize: NSSize? {
            SettingsTabViewController.savedWindowSizes[rawValue]
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tabStyle = .toolbar
        
        for tab in Tab.allCases {
            let item = NSTabViewItem(viewController: tab.makeViewController())
            item.label = tab.label
            item.image = NSImage(imageLiteralResourceName: tab.imageName)
            addTabViewItem(item)
        }
        selectedTabViewItemIndex = SettingsTabViewController.currentTab.rawValue
        
        Notification.Name.snapAreaSettingsNeedsResize.onPost {[weak self] notification in
            guard let self,
                  let snapAreasIndex = Tab.allCases.firstIndex(of: .snapAreas)
            else { return }

            Self.savedWindowSizes.removeValue(forKey: snapAreasIndex)
            
            if selectedTabViewItemIndex == snapAreasIndex {
                let viewController = tabViewItems[snapAreasIndex].viewController!
                
                viewController.view.layoutSubtreeIfNeeded()
                
                DispatchQueue.main.async {
                    let dynamicSize = self.calculateContentSize(for: viewController)
                    self.resizeWindow(toContentSize: dynamicSize, animated: true)
                }
            }
        }
    }
    
    override var selectedTabViewItemIndex: Int {
        willSet {
            if selectedTabViewItemIndex != -1, let window = view.window {
                Self.savedWindowSizes[selectedTabViewItemIndex] = window.frame.size
            }
        }
        didSet {
            guard selectedTabViewItemIndex != -1 else { return }
            let selectedItem = tabViewItems[selectedTabViewItemIndex]
            tabDidSwitch(to: selectedItem, at: selectedTabViewItemIndex)
        }
    }
    
    func saveCurrentSize() {
        if let window = view.window {
            Self.savedWindowSizes[Self.currentTab.rawValue] = window.frame.size
        }
    }
    
    private func tabDidSwitch(to item: NSTabViewItem, at index: Int) {
        guard let window = view.window, let viewController = item.viewController else { return }
        
        if let tab = Tab(rawValue: index) {
            SettingsTabViewController.currentTab = tab
        }
        window.title = item.label
        
        if let savedSize = Self.savedWindowSizes[index] {
            resizeWindow(toFrameSize: savedSize, animated: true)
        } else if Tab.allCases.indices.contains(index) {
            let tab = Tab.allCases[index]
            
            if let explicitSize = tab.defaultSize {
                resizeWindow(toContentSize: explicitSize, animated: true)
            } else {
                let dynamicSize = calculateContentSize(for: viewController)
                resizeWindow(toContentSize: dynamicSize, animated: true)
            }
        }
    }
    
    private func calculateContentSize(for vc: NSViewController) -> NSSize {
        _ = vc.view // Ensure the view hierarchy is loaded
        
        if vc.preferredContentSize != .zero {
            return vc.preferredContentSize
        }
        
        let fitting = vc.view.fittingSize
        if fitting != .zero {
            return fitting
        }
        
        return vc.view.bounds.size
    }
    
    func resizeWindow(toFrameSize targetFrameSize: NSSize, animated: Bool) {
        guard let window = view.window else { return }
        
        var frame = window.frame
        frame.origin.y -= (targetFrameSize.height - frame.size.height)
        frame.size = targetFrameSize
        
        window.setFrame(frame, display: true, animate: animated)
    }
    
    private func resizeWindow(toContentSize contentSize: NSSize, animated: Bool) {
        guard let window = view.window else { return }

        // Convert inner content size to total window frame rect (accounting for title bar and toolbar)
        let contentSizeWithProfilePicker = NSSize(width: contentSize.width,
                                                  height: contentSize.height + Self.profilePickerHeaderHeight)
        let targetFrameRect = window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSizeWithProfilePicker))
        resizeWindow(toFrameSize: targetFrameRect.size, animated: animated)
    }
}
