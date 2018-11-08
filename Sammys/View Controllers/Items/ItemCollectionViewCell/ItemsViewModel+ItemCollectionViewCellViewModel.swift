//
//  ItemCollectionViewCellViewModel.swift
//  Sammys
//
//  Created by Natanel Niazoff on 11/4/18.
//  Copyright © 2018 Natanel Niazoff. All rights reserved.
//

import Foundation

extension ItemsViewModel {
	struct ItemCollectionViewCellViewModel: CollectionViewCellViewModel {
		let foodItem: FoodItem
		let identifier: String
		let width: Double
		let height: Double
		let commands: [CollectionViewCommandActionKey : CollectionViewCellCommand]
	}
}
