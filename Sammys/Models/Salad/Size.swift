//
//  Size.swift
//  Sammys
//
//  Created by Natanel Niazoff on 1/3/18.
//  Copyright © 2018 Natanel Niazoff. All rights reserved.
//

import Foundation

struct Size: NonModifiableFoodItem, PricedFoodItem {
	static let itemName = SaladFoodItemCategory.size.rawValue
    let name: String
    let description: String
    let price: Double
}

extension Size: Hashable {}