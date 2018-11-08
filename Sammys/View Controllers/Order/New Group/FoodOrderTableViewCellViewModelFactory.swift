//
//  FoodOrderTableViewCellViewModelFactory.swift
//  Sammys
//
//  Created by Natanel Niazoff on 4/24/18.
//  Copyright © 2018 Natanel Niazoff. All rights reserved.
//

import UIKit

struct FoodOrderTableViewCellViewModel/*: TableViewCellViewModel*/ {
    let food: Food
    let identifier: String
    let height: CGFloat
    let commands: [TableViewCommandActionKey : TableViewCellCommand]
}

enum FoodOrderCellIdentifier: String {
    case foodCell
}

struct FoodOrderTableViewCellViewModelFactory/*: TableViewCellViewModelFactory*/ {
//    let food: Food
//    let height: CGFloat
	
//    func create() -> TableViewCellViewModel {
//        return FoodOrderTableViewCellViewModel(food: food, identifier: FoodOrderCellIdentifier.foodCell.rawValue, height: height, commands: [.configuration: FoodOrderTableViewCellConfigurationCommand(food: food)])
//    }
}
