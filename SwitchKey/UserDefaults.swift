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

extension Defaults.Keys {
    static let commonConditions = Key<[CommonCondition]>("commonConditions", default: [])
    static let defaultCondition = Key<DefaultCondition>("defaultCondition", default: .placeholder)
}
