//
//  UserDefaults.swift
//  SwitchKey
//
//  Created by 陈佳伟 on 2021-11-4.
//  Copyright © 2021 Jinyu Li. All rights reserved.
//

import Foundation
import Defaults
import Cocoa
import SwiftUI

protocol Condition {
    var inputSourceID: String { set get }
    var inputSourceIcon: NSImageWrapper { set get }
    var enabled: Bool { get set }
}

class DefaultCondition: Condition, Codable, DefaultsSerializable {
    internal init(inputSourceID: String, inputSourceIcon: NSImageWrapper, enabled: Bool) {
        self.inputSourceID = inputSourceID
        self.inputSourceIcon = inputSourceIcon
        self.enabled = enabled
    }
    
    var inputSourceID: String
    var inputSourceIcon: NSImageWrapper
    var enabled: Bool
    //
    static let placeholder = DefaultCondition(
        inputSourceID: "",
        inputSourceIcon: NSImageWrapper(NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)!),
        enabled: false
    )
}

class CommonCondition: Condition, Codable, DefaultsSerializable {
    internal init(applicationIdentifier: String, inputSourceID: String, inputSourceIcon: NSImageWrapper, enabled: Bool, applicationName: String, applicationIcon: NSImageWrapper) {
        self.applicationIdentifier = applicationIdentifier
        self.inputSourceID = inputSourceID
        self.inputSourceIcon = inputSourceIcon
        self.enabled = enabled
        self.applicationName = applicationName
        self.applicationIcon = applicationIcon
    }
    
    var applicationIdentifier: String
    var inputSourceID: String
    var inputSourceIcon: NSImageWrapper
    var enabled: Bool
    var applicationName: String
    var applicationIcon: NSImageWrapper
}

extension Defaults.Keys {
    static let commonConditions = Key<[CommonCondition]>("commonConditions", default: [])
    static let defaultCondition = Key<DefaultCondition>("defaultCondition", default: .placeholder)
}
