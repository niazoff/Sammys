//
//  BagFoodTableViewCellViewModel.swift
//  Sammys
//
//  Created by Natanel Niazoff on 11/8/18.
//  Copyright © 2018 Natanel Niazoff. All rights reserved.
//

import Foundation

struct BagFoodTableViewCellViewModel: TableViewCellViewModel {
	let food: Food
	let identifier: String
	let height: Double
	let commands: [TableViewCommandActionKey : TableViewCellCommand]
}
