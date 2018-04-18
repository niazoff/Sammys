//
//  CollectionViewCellCommand.swift
//  Sammys
//
//  Created by Natanel Niazoff on 3/22/18.
//  Copyright © 2018 Natanel Niazoff. All rights reserved.
//

import UIKit

struct CommandParameters {
    let cell: UICollectionViewCell?
    let viewController: UIViewController?
    
    init(cell: UICollectionViewCell? = nil, viewController: UIViewController? = nil) {
        self.cell = cell
        self.viewController = viewController
    }
}

protocol CollectionViewCellCommand {
    func perform(parameters: CommandParameters)
}

enum CollectionViewCommandActionKey {
    case configuration
    case selection
}
