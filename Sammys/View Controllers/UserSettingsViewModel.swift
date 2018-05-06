//
//  UserSettingsViewModel.swift
//  Sammys
//
//  Created by Natanel Niazoff on 5/6/18.
//  Copyright © 2018 Natanel Niazoff. All rights reserved.
//

import Foundation

private struct UserSettingsSection {
    /// The tile of the section.
    let title: String?
    
    /// The cell view models in the section.
    let cellViewModels: [TableViewCellViewModel]
    
    init(title: String? = nil, cellViewModels: [TableViewCellViewModel]) {
        self.title = title
        self.cellViewModels = cellViewModels
    }
}

class UserSettingsViewModel {
    private var user: User? {
        return UserDataStore.shared.user
    }
    
    private var sections: [UserSettingsSection] {
        guard let user = user else { return [] }
        return [
            UserSettingsSection(cellViewModels: [
                TextFieldTableViewCellViewModelFactory(height: 60, text: user.name, placeholder: "Name") { UserAPIClient.updateCurrentUserName($0) }.create(),
                TextFieldTableViewCellViewModelFactory(height: 60, text: user.email, placeholder: "Email") { UserAPIClient.updateCurrentUserEmail($0) }.create()
            ])
        ]
    }
    
    var numberOfSections: Int {
        return sections.count
    }
    
    func numberOfRows(inSection section: Int) -> Int {
        return sections[section].cellViewModels.count
    }
    
    func cellViewModel(for indexPath: IndexPath) -> TableViewCellViewModel {
        return sections[indexPath.section].cellViewModels[indexPath.row]
    }
}
