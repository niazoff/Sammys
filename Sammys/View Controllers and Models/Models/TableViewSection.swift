//
//  TableViewSection.swift
//  Sammys
//
//  Created by Natanel Niazoff on 11/8/18.
//  Copyright © 2018 Natanel Niazoff. All rights reserved.
//

import Foundation

struct TableViewSection<T: TableViewCellViewModel> {
	typealias CellViewModel = T
	
	let title: String?
	let cellViewModels: [CellViewModel]
	
	init(title: String? = nil, cellViewModels: [CellViewModel]) {
		self.title = title
		self.cellViewModels = cellViewModels
	}
}
