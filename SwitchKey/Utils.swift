//
//  Utils.swift
//  SwitchKey
//
//  Created by 陈佳伟 on 2021-11-5.
//  Copyright © 2021 Jinyu Li. All rights reserved.
//

import Foundation
import Cocoa

func buildFullConstraint(super superView: NSView, sub subView: NSView) {
    subView.translatesAutoresizingMaskIntoConstraints = false
    subView.leadingAnchor.constraint(equalTo: superView.leadingAnchor).isActive = true
    subView.trailingAnchor.constraint(equalTo: superView.trailingAnchor).isActive = true
    subView.topAnchor.constraint(equalTo: superView.topAnchor).isActive = true
    subView.bottomAnchor.constraint(equalTo: superView.bottomAnchor).isActive = true
}
