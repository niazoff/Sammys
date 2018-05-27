//
//  Lettuce.swift
//  Sammys
//
//  Created by Natanel Niazoff on 1/3/18.
//  Copyright © 2018 Natanel Niazoff. All rights reserved.
//

import Foundation

/// A type that represents a lettuce 🌱 in a `Salad` instance.
struct Lettuce: Item, Codable, Equatable {
    static let type: ItemType = SaladItemType.lettuce
    let name: String
    let description: String
    var modifiers: [Modifier]?
    let hex: String
    
    static func ==(lhs: Lettuce, rhs: Lettuce) -> Bool {
        return lhs.name == rhs.name
    }
}
