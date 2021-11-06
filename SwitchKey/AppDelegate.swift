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


class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var statusBarMenu: NSMenu = {
        NSMenu(title: "")
    }()
    
    private var applicationObservers: [pid_t: AXObserver] = [:]
    private var currentPid: pid_t = getpid()
    
    private var model = Model()
    
    private lazy var statusBarItem: NSStatusItem = {
        NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    }()
    private lazy var launchAtStartupItem: NSMenuItem = {
        let menuItem = NSMenuItem(title: "Launch at login", action: #selector(menuDidLaunchAtStartupToggled), keyEquivalent: "")
        menuItem.state = LoginServiceKit.isExistLoginItems() ? .on : .off
        menuItem.target = self
        return menuItem
    }()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if !hasAccessibilityPermission() {
            askForAccessibilityPermission()
        }
        self.model.loadDefaults()
        self.buildStatusBar()
        
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
        //
        statusBarMenu.addItem(launchAtStartupItem)
        statusBarMenu.addItem(buildQuitMenuItem())
        statusBarMenu.addItem(NSMenuItem.separator())
        statusBarMenu.addItem(buildSwiftUIMenuItem())
    }
    
    private func buildSwiftUIMenuItem() -> NSMenuItem {
        let menuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        let view = NSHostingView(rootView: MenuView().environmentObject(self.model))
        view.frame = NSRect(x: 0, y: 0, width: 200, height: 700)
        menuItem.view = view
        return menuItem
    }
    
    private func buildQuitMenuItem() -> NSMenuItem {
        let menuItem = NSMenuItem(title: "Quit", action: #selector(menuDidQuitClicked), keyEquivalent: "")
        menuItem.target = self
        return menuItem
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        self.model.saveDefaults()
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
            guard let appIdentifier = application.bundleIdentifier else { return }
            if let id = self.model.inputSourceID(applicationIdentifier: appIdentifier),
               let inputSource = InputSource.with(id) {
                inputSource.activate()
            } else if self.model.defaultConditionEnabled, let id = self.model.defaultConditionInputSourceID, let inputSource = InputSource.with(id) {
                inputSource.activate()
            }
            self.currentPid = switchedPid
        }
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
    
    func saveConditions() {
        self.model.saveDefaults()
    }
    
    func setDefaultCondition() {
        let inputSource = InputSource.current()
        self.model.setDefault(inputSourceID: inputSource.inputSourceID(), inputSourceIcon: inputSource.icon(), enabled: true)
    }
    
    func addCondition() {
        guard let currentApplication = NSWorkspace.shared.frontmostApplication else { return }
        let inputSource = InputSource.current()
        
        self.model.updateOrAdd(
            applicationIdentifier: currentApplication.bundleIdentifier ?? "",
            inputSourceID: inputSource.inputSourceID(),
            inputSourceIcon: inputSource.icon(),
            enabled: true,
            applicationName: currentApplication.localizedName ?? "",
            applicationIcon: currentApplication.icon ?? NSImage()
        )
    }
    
    func removeCondition(row: Int) {
        // TODO
    }
}

extension String {
    subscript(to: Int) -> String {
        let index = self.index(self.startIndex, offsetBy: to)
        return String(self[..<index])
    }
}
