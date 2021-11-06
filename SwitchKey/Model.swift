//
//  Model.swift
//  SwitchKey
//
//  Created by 陈佳伟 on 2021-11-5.
//  Copyright © 2021 Jinyu Li. All rights reserved.
//

import Foundation
import Defaults
import Cocoa

enum ModelError: Error {
    case applicationIdentifierNotFound(String)
}

class Model: ObservableObject {
    @Published var conditionItems: [CommonCondition] = []
    @Published var defaultCondition: DefaultCondition = .placeholder
}

extension Model {
    func inputSourceID(applicationIdentifier: String, enabled: Bool=true) -> String? {
        let condition = self.conditionItems.filter({ $0.enabled == enabled }).first(where: { $0.applicationIdentifier == applicationIdentifier })
        return condition?.inputSourceID
    }
    
    func updateOrAdd(
        applicationIdentifier: String,
        inputSourceID: String,
        inputSourceIcon: NSImage,
        enabled: Bool,
        applicationName: String,
        applicationIcon: NSImage
    ) {
        if let itemIndex = conditionItems.firstIndex(where: { $0.applicationIdentifier == applicationIdentifier }) {
            update(
                itemIndex: itemIndex,
                applicationIdentifier: applicationIdentifier,
                inputSourceID: inputSourceID,
                inputSourceIcon: inputSourceIcon,
                enabled: enabled,
                applicationName: applicationName,
                applicationIcon: applicationIcon)
        } else {
            add(
                applicationIdentifier: applicationIdentifier,
                inputSourceID: inputSourceID,
                inputSourceIcon: inputSourceIcon,
                enabled: enabled,
                applicationName: applicationName,
                applicationIcon: applicationIcon
            )
        }
    }
    
    private func add(
        applicationIdentifier: String,
        inputSourceID: String,
        inputSourceIcon: NSImage,
        enabled: Bool,
        applicationName: String,
        applicationIcon: NSImage
    ) {
        conditionItems.insert(
            CommonCondition(
                applicationIdentifier: applicationIdentifier,
                inputSourceID: inputSourceID,
                inputSourceIcon: NSImageWrapper(inputSourceIcon),
                enabled: enabled,
                applicationName: applicationName,
                applicationIcon: NSImageWrapper(applicationIcon)
            ),
            at: 0
        )
    }
    
    private func update(
        itemIndex: Int,
        applicationIdentifier: String?,
        inputSourceID: String? = nil,
        inputSourceIcon: NSImage? = nil,
        enabled: Bool? = nil,
        applicationName: String? = nil,
        applicationIcon: NSImage? = nil
    ) {
        let newItem = self.conditionItems[itemIndex].update(
            applicationIdentifier: applicationIdentifier,
            inputSourceID: inputSourceID,
            inputSourceIcon: inputSourceIcon,
            enabled: enabled,
            applicationName: applicationName,
            applicationIcon: applicationIcon
        )
        self.conditionItems[itemIndex] = newItem
    }
    
    func delete(applicationIdentifier: String) {
        self.conditionItems = self.conditionItems.filter { $0.applicationIdentifier != applicationIdentifier }
    }
}

extension Model {
    func setDefault(inputSourceID: String, inputSourceIcon: NSImage, enabled: Bool) {
        self.defaultCondition = DefaultCondition(
            inputSourceID: inputSourceID,
            inputSourceIcon: NSImageWrapper(inputSourceIcon),
            enabled: enabled
        )
    }
    
    var defaultConditionEnabled: Bool {
        defaultCondition.enabled
    }
    
    var defaultConditionInputSourceID: String? {
        if defaultCondition.inputSourceID != "" {
            return nil
        } else {
            return defaultCondition.inputSourceID
        }
    }
}

extension Model {
    func saveDefaults() {
        Defaults[.commonConditions] = self.conditionItems
        Defaults[.defaultCondition] = self.defaultCondition
    }
    
    func loadDefaults() {
//        self.conditionItems = Defaults[.commonConditions]
        self.defaultCondition = Defaults[.defaultCondition]
        self.conditionItems = [
            CommonCondition(
                applicationIdentifier: "hello",
                inputSourceID: "hello.test.test",
                inputSourceIcon: NSImageWrapper(NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)!),
                enabled: true,
                applicationName: "hello1",
                applicationIcon: NSImageWrapper(NSImage(systemSymbolName: "printer", accessibilityDescription: nil)!)
            )
        ]
    }
}


protocol Condition {
    var inputSourceID: String { get }
    var inputSourceIcon: NSImageWrapper { get }
    var enabled: Bool { get }
}

struct DefaultCondition: Condition, Codable, DefaultsSerializable {
    let inputSourceID: String
    let inputSourceIcon: NSImageWrapper
    let enabled: Bool
    //
    static let placeholder = DefaultCondition(
        inputSourceID: "",
        inputSourceIcon: NSImageWrapper(NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)!),
        enabled: false
    )
    
    func update(inputSourceID: String? = nil, inputSourceIcon: NSImage? = nil, enabled: Bool? = nil) -> Self {
        return .init(
            inputSourceID: inputSourceID ?? self.inputSourceID,
            inputSourceIcon: NSImageWrapper(inputSourceIcon ?? self.inputSourceIcon.image),
            enabled: enabled ?? self.enabled
        )
    }
}

struct CommonCondition: Condition, Codable, DefaultsSerializable, Identifiable, Hashable {
    static func == (lhs: CommonCondition, rhs: CommonCondition) -> Bool {
        return lhs.applicationIdentifier == rhs.applicationIdentifier
    }
    
    var id: String {
        applicationIdentifier
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(applicationIdentifier)
    }
    
    let applicationIdentifier: String
    let inputSourceID: String
    let inputSourceIcon: NSImageWrapper
    var enabled: Bool
    let applicationName: String
    let applicationIcon: NSImageWrapper
    
    func update(
        applicationIdentifier: String? = nil,
        inputSourceID: String? = nil,
        inputSourceIcon: NSImage? = nil,
        enabled: Bool? = nil,
        applicationName: String? = nil,
        applicationIcon: NSImage? = nil
    ) -> Self {
        return .init(
            applicationIdentifier: applicationIdentifier ?? self.applicationIdentifier,
            inputSourceID: inputSourceID ?? self.inputSourceID,
            inputSourceIcon: NSImageWrapper(inputSourceIcon ?? self.inputSourceIcon.image),
            enabled: enabled ?? self.enabled,
            applicationName: applicationName ?? self.applicationName,
            applicationIcon: NSImageWrapper(applicationIcon ?? self.applicationIcon.image)
        )
    }
}
