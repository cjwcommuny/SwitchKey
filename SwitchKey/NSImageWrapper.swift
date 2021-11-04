//
//  AppIcon.swift
//  SwitchKey
//
//  Created by 陈佳伟 on 2021-11-4.
//  Copyright © 2021 Jinyu Li. All rights reserved.
//

import Foundation
import Cocoa

struct NSImageWrapper: Codable {
    let image: NSImage
    
    enum CodingKeys: CodingKey {
        case image
    }
    
    public init(_ image: NSImage) {
        self.image = image
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.image = try container.decode(NSImage.self, forKey: CodingKeys.image)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.image, forKey: CodingKeys.image)
    }
}

extension KeyedEncodingContainer {
    mutating func encode(_ value: NSImage, forKey key: KeyedEncodingContainer.Key) throws {
        guard let cgRef = value.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw EncodingError.invalidValue(value, .init(codingPath: [key], debugDescription: "Fail to convert NSImage to CGImage"))
        }
        let newRep = NSBitmapImageRep(cgImage: cgRef)
        newRep.size = value.size
        guard let pngData = newRep.representation(using: .png, properties: [:]) else {
            throw EncodingError.invalidValue(value, .init(codingPath: [key], debugDescription: "Fail to convert NSBitmapImageRep to Data"))
        }
        try encode(pngData, forKey: key)
    }
}

extension KeyedDecodingContainer {
    func decode(_ type: NSImage.Type, forKey key: KeyedDecodingContainer.Key) throws -> NSImage {
        let imageData = try decode(Data.self, forKey: key)
        if let image = NSImage(data: imageData) {
            return image
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [key], debugDescription: "Failed load UIImage from decoded data")
            )
        }
    }
}
