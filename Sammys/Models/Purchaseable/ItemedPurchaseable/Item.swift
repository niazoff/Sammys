//
//  Item.swift
//  Sammys
//
//  Created by Natanel Niazoff on 1/12/18.
//  Copyright © 2018 Natanel Niazoff. All rights reserved.
//

import Foundation

protocol Item: Codable {
	static var itemName: String { get }
	var name: String { get }
    var description: String { get }
}

protocol PricedItem: Item {
	var price: Double { get }
}

protocol OptionallyPricedItem: Item {
	var price: Double? { get }
}

protocol ModifiableItem: Item {
	var modifiers: [Modifier] { get }
}

protocol OptionallyModifiableItem: Item {
	var modifiers: [Modifier]? { get }
}