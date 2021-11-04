//
//  AppDelegate.swift
//  SwitchKey
//
//  Created by Jinyu Li on 2019/03/16.
//  Copyright © 2019 Jinyu Li. All rights reserved.
//

import Cocoa
import Carbon
import ServiceManagement
import Defaults
import SwiftUI

extension Notification.Name {
    static let killLauncher = Notification.Name("KillSwitchKeyLauncher")
}

private let itemCellIdentifier = NSUserInterfaceItemIdentifier("item-cell")
private let editCellIdentifier = NSUserInterfaceItemIdentifier("edit-cell")
private let defaultCellIdentifier = NSUserInterfaceItemIdentifier("default-cell")

private func applicationSwitchedCallback(_ axObserver: AXObserver, axElement: AXUIElement, notification: CFString, userData: UnsafeMutableRawPointer?) {
    if let userData = userData {
        let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
        appDelegate.applicationSwitched()
    }
}

private func hasAccessibilityPermission() -> Bool {
    let promptFlag = kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString
    let myDict: CFDictionary = NSDictionary(dictionary: [promptFlag: false])
    return AXIsProcessTrustedWithOptions(myDict)
}

private func askForAccessibilityPermission() {
    let alert = NSAlert.init()
    alert.messageText = "SwitchKey requires accessibility permissions."
    alert.informativeText = "Please re-launch SwitchKey after you've granted permission in system preferences."
    alert.addButton(withTitle: "Configure Accessibility Settings")
    alert.alertStyle = NSAlert.Style.warning
    
    if alert.runModal() == .alertFirstButtonReturn {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.systempreferences").first?.activate(options: .activateIgnoringOtherApps)
        NSApplication.shared.terminate(nil)
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private lazy var statusBarMenu: NSMenu = {
        NSMenu(title: "")
    }()
    
    @IBOutlet weak var conditionTableView: TableView! {
        didSet {
            conditionTableView.appDelegate = self
            conditionTableView.register(NSNib(nibNamed: "SwitchKey", bundle: nil), forIdentifier: itemCellIdentifier)
            conditionTableView.register(NSNib(nibNamed: "SwitchKey", bundle: nil), forIdentifier: editCellIdentifier)
            conditionTableView.register(NSNib(nibNamed: "SwitchKey", bundle: nil), forIdentifier: defaultCellIdentifier)
        }
    }
    
    private var applicationObservers: [pid_t: AXObserver] = [:]
    private var currentPid: pid_t = getpid()
    
    private var conditionItems: [CommonCondition] = []
    private var defaultCondition: DefaultCondition = .placeholder
    
    private lazy var statusBarItem: NSStatusItem = {
        NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    }()
    private var launchAtStartupItem: NSMenuItem!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if !hasAccessibilityPermission() {
            askForAccessibilityPermission()
        }
        
        loadConditions()
        
        conditionTableView.dataSource = self
        conditionTableView.delegate = self
        
        buildStatusBar()
        
        NotificationCenter.default.addObserver(self, selector: #selector(menuDidEndTracking(_:)), name: NSMenu.didEndTrackingNotification, object: nil)
        
        let workspace = NSWorkspace.shared
        
        workspace.notificationCenter.addObserver(self, selector: #selector(applicationLaunched(_:)), name: NSWorkspace.didLaunchApplicationNotification, object: workspace)
        
        workspace.notificationCenter.addObserver(self, selector: #selector(applicationTerminated(_:)), name: NSWorkspace.didTerminateApplicationNotification, object: workspace)
        
        for application in workspace.runningApplications {
            registerForAppSwitchNotification(application.processIdentifier)
        }
        
        applicationSwitched()
    }
    
    private func buildStatusBar() {
        if let button = statusBarItem.button {
            button.image = NSImage(named: "StatusIcon")
        }
        statusBarItem.menu = statusBarMenu
        statusBarMenu.addItem(buildContentMenuItem())
        statusBarMenu.addItem(NSMenuItem.separator())
        statusBarMenu.addItem(buildLaunchAtStartupMenuItem())
        statusBarMenu.addItem(buildQuitMenuItem())
    }
    
    private func buildContentMenuItem() -> NSMenuItem {
        let menuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        menuItem.view = conditionTableView
        return menuItem
    }
    
    private func buildLaunchAtStartupMenuItem() -> NSMenuItem {
        let menuItem = NSMenuItem(title: "Launch at login", action: #selector(menuDidLaunchAtStartupToggled), keyEquivalent: "")
        menuItem.state = LoginServiceKit.isExistLoginItems() ? .on : .off
        menuItem.target = self
        return menuItem
    }
    
    private func buildQuitMenuItem() -> NSMenuItem {
        let menuItem = NSMenuItem(title: "Quit", action: #selector(menuDidQuitClicked), keyEquivalent: "")
        menuItem.target = self
        return menuItem
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        for (_, observer) in applicationObservers {
            CFRunLoopRemoveSource(RunLoop.current.getCFRunLoop(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
    }
    
    fileprivate func applicationSwitched() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let application = NSWorkspace.shared.frontmostApplication else { return }
            let switchedPid: pid_t = application.processIdentifier
            guard switchedPid != self.currentPid && switchedPid != getpid() else { return }
            let condition = self.conditionItems.filter({ $0.enabled }).first(where: { $0.applicationIdentifier == application.bundleIdentifier })
            if let condition = condition, let inputSource = InputSource.with(condition.inputSourceID) {
                inputSource.activate()
            } else if self.defaultCondition.inputSourceID != "" && self.defaultCondition.enabled {
                if let inputSource = InputSource.with(self.defaultCondition.inputSourceID) {
                    inputSource.activate()
                }
            }
            self.currentPid = switchedPid
        }
    }
    
    @objc private func menuDidEndTracking(_ notification: Notification) {
        conditionTableView.selectRowIndexes([], byExtendingSelection: false)
    }
    
    @objc private func menuDidLaunchAtStartupToggled() {
        if launchAtStartupItem.state == .on {
            launchAtStartupItem.state = .off
            LoginServiceKit.removeLoginItems()
        } else {
            launchAtStartupItem.state = .on
            LoginServiceKit.addLoginItems()
        }
    }
    
    @objc private func menuDidQuitClicked() {
        NSApplication.shared.terminate(nil)
    }
    
    @objc private func applicationLaunched(_ notification: NSNotification) {
        let pid = notification.userInfo!["NSApplicationProcessIdentifier"] as! pid_t
        registerForAppSwitchNotification(pid)
        applicationSwitched()
    }
    
    @objc private func applicationTerminated(_ notification: NSNotification) {
        let pid = notification.userInfo!["NSApplicationProcessIdentifier"] as! pid_t
        if let observer = applicationObservers[pid] {
            CFRunLoopRemoveSource(RunLoop.current.getCFRunLoop(), AXObserverGetRunLoopSource(observer), .defaultMode)
            applicationObservers.removeValue(forKey: pid)
        }
    }
    
    private func registerForAppSwitchNotification(_ pid: pid_t) {
        guard pid >= 0 && pid != getpid() else { return }
        guard applicationObservers[pid] != nil else { return }
        var observer: AXObserver!
        guard AXObserverCreate(pid, applicationSwitchedCallback, &observer) == .success else {
            fatalError("")
        }
        CFRunLoopAddSource(RunLoop.current.getCFRunLoop(), AXObserverGetRunLoopSource(observer), .defaultMode)
        
        let element = AXUIElementCreateApplication(pid)
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        AXObserverAddNotification(observer, element, NSAccessibility.Notification.applicationActivated.rawValue as CFString, selfPtr)
        applicationObservers[pid] = observer
    }
    
    func loadConditions() {
        defer {
            conditionTableView.reloadData()
        }
        self.conditionItems = Defaults[.commonConditions]
        self.defaultCondition = Defaults[.defaultCondition]
    }
    
    func saveConditions() {
        Defaults[.commonConditions] = self.conditionItems
        Defaults[.defaultCondition] = self.defaultCondition
    }
    
    func setDefaultCondition() {
        defer {
            conditionTableView.reloadData()
            saveConditions()
        }
        let inputSource = InputSource.current()
        self.defaultCondition = DefaultCondition(
            inputSourceID: inputSource.inputSourceID(),
            inputSourceIcon: NSImageWrapper(inputSource.icon()),
            enabled: true
        )
    }
    
    func addCondition() {
        guard let currentApplication = NSWorkspace.shared.frontmostApplication else { return }
        defer {
            conditionTableView.reloadData()
            conditionTableView.selectRowIndexes([1], byExtendingSelection: false)
            saveConditions()
        }
        let inputSource = InputSource.current()
        
        let currentAppItemIndex = conditionItems.firstIndex(where: { $0.applicationIdentifier == currentApplication.bundleIdentifier })
        if let currentAppItemIndex = currentAppItemIndex {
            conditionItems[currentAppItemIndex].inputSourceID = inputSource.inputSourceID()
            conditionItems[currentAppItemIndex].inputSourceIcon = .init(inputSource.icon())
        }
        
        let conditionItem = CommonCondition(
            applicationIdentifier: currentApplication.bundleIdentifier ?? "",
            inputSourceID: inputSource.inputSourceID(),
            inputSourceIcon: NSImageWrapper(inputSource.icon()),
            enabled: true,
            applicationName: currentApplication.localizedName ?? "",
            applicationIcon: NSImageWrapper(currentApplication.icon ?? NSImage())
        )
        conditionItems.insert(conditionItem, at: 0)
    }
    
    func removeCondition(row: Int) {
        if row > 2 {
            conditionItems.remove(at: row - 3)
            conditionTableView.reloadData()
            saveConditions()
        }
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        switch row {
        case 0:
            return conditionTableView.makeView(withIdentifier: editCellIdentifier, owner: nil)
        case 1:
            return conditionTableView.makeView(withIdentifier: defaultCellIdentifier, owner: nil)
        case 2:
            let itemCell = conditionTableView.makeView(withIdentifier: itemCellIdentifier, owner: nil) as! ConditionCell
            
            let icon = defaultCondition.inputSourceIcon.image
            itemCell.appName.stringValue = "Default"
            itemCell.appIcon.image = NSImage()
            
            itemCell.inputSourceButton.image = icon
            itemCell.inputSourceButton.image?.isTemplate = icon.canTemplate()
            
            itemCell.conditionEnabled.state = defaultCondition.enabled ? .on : .off
            return itemCell
        default:
            let item = conditionItems[row - 3]
            let itemCell = conditionTableView.makeView(withIdentifier: itemCellIdentifier, owner: nil) as! ConditionCell
            itemCell.appIcon.image = item.applicationIcon.image
            itemCell.appName.stringValue = item.applicationName
            
            let icon = item.inputSourceIcon.image
            itemCell.inputSourceButton.image = icon
            itemCell.inputSourceButton.image?.isTemplate = icon.canTemplate()
            
            itemCell.conditionEnabled.state = item.enabled ? .on : .off
            return itemCell
        }
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        if row == 2 {
            return defaultCondition
        } else if row > 2 {
            return conditionItems[row - 3]
        } else {
            return self
        }
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        if row > 1 {
            return 64
        } else {
            return 24
        }
    }
    
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let view = TableRowView()
        view.highlight = row > 1
        return view
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return conditionItems.count + 3
    }
}

class TableView: NSTableView {
    var appDelegate: AppDelegate! = nil
    
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let rowAtPoint = row(at: point)
        selectRowIndexes([rowAtPoint], byExtendingSelection: false)
        super.mouseDown(with: event)
    }
    
    override func keyDown(with event: NSEvent) {
        if event.type == NSEvent.EventType.keyDown && event.keyCode == kVK_Delete {
            appDelegate.removeCondition(row: selectedRow)
        } else {
            super.keyDown(with: event)
        }
    }
}

class TableRowView: NSTableRowView {
    var highlight: Bool = true
    
    override func drawSelection(in dirtyRect: NSRect) {
        if highlight {
            NSColor.labelColor.withAlphaComponent(0.2).setFill()
            self.bounds.fill()
        }
    }
}

class ConditionCell: NSTableCellView {
    @IBOutlet weak var appIcon: NSImageView!
    @IBOutlet weak var appName: NSTextField!
    @IBOutlet weak var conditionEnabled: NSButton!
    @IBOutlet weak var inputSourceButton: NSButton!
    @IBAction func inputSourceButtonClicked(_ sender: Any) {
        let item = objectValue as! Condition
        if let inputSource = InputSource.with(item.inputSourceID) {
            inputSource.activate()
        }
    }
    
    @IBAction func toggleEnabled(_ sender: Any) {
        var item = objectValue as! Condition
        item.enabled = conditionEnabled.state == .on;
    }
}

class EditCell: NSTableCellView {
    @IBAction func addItemClicked(_ sender: Any) {
        let app = objectValue as! AppDelegate
        app.addCondition()
    }
}

class DefaultCell: NSTableCellView {
    @IBAction func addItemClicked(_ sender: Any) {
        let app = objectValue as! AppDelegate
        app.setDefaultCondition()
    }
}

extension String {
    subscript(to: Int) -> String {
        let index = self.index(self.startIndex, offsetBy: to)
        return String(self[..<index])
    }
}
