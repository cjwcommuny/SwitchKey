//
//  MenuView.swift
//  SwitchKey
//
//  Created by 陈佳伟 on 2021-11-4.
//  Copyright © 2021 Jinyu Li. All rights reserved.
//

import SwiftUI

struct MenuItemView: View {
    @EnvironmentObject private var model: Model
    @Binding var condition: CommonCondition
    
    var body: some View {
        HStack {
            Toggle("No Label", isOn: $condition.enabled)
                .labelsHidden()
            Image(nsImage: condition.inputSourceIcon.image)
            Spacer()
            Image(nsImage: condition.applicationIcon.image)
            Text(condition.applicationName)
            Button(
                action: {
                    model.delete(applicationIdentifier: condition.applicationIdentifier)
                } ) { Image(systemName: "xmark.circle.fill") }.buttonStyle(PlainButtonStyle())
        }
    }
}

struct MenuView: View {
    @EnvironmentObject private var model: Model
    @State private var selection: CommonCondition?
    
    var body: some View {
        List(selection: $selection) {
            ForEach($model.conditionItems) { item in
                MenuItemView(condition: item)
            }
        }
        .listStyle(.sidebar)
    }
}

struct MenuView_Previews: PreviewProvider {
    private static let model = Model()
    
    static var previews: some View {
        model.loadDefaults()
        return MenuView().environmentObject(model)
    }
}
