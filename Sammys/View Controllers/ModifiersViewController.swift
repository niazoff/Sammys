//
//  ModifiersViewController.swift
//  Sammys
//
//  Created by Natanel Niazoff on 5/20/19.
//  Copyright © 2019 Natanel Niazoff. All rights reserved.
//

import UIKit

class ModifiersViewController: UIViewController {
    let viewModel = ModifiersViewModel()
    
    let tableView = UITableView()
    
    private let tableViewDataSource = UITableViewSectionModelsDataSource()
    private let tableViewDelegate = UITableViewSectionModelsDelegate()
    
    private lazy var doneBarButtonItemTarget = Target(action: doneBarButtonItemAction)
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureTableView()
        setUpView()
        configureNavigation()
        configureViewModel()
    }
    
    // MARK: - Setup Methods
    private func setUpView() {
        addSubviews()
    }
    
    private func addSubviews() {
        [tableView].forEach { self.view.addSubview($0) }
        tableView.edgesToSuperview()
    }
    
    private func configureNavigation() {
        self.navigationItem.rightBarButtonItem = .init(barButtonSystemItem: .done, target: doneBarButtonItemTarget)
    }
    
    private func configureTableView() {
        tableView.dataSource = tableViewDataSource
        tableView.delegate = tableViewDelegate
        tableView.register(SubtitleTableViewCell.self, forCellReuseIdentifier: ModifiersViewModel.CellIdentifier.subtitleTableViewCell.rawValue)
    }
    
    private func configureViewModel() {
        viewModel.modifierTableViewCellViewModelActions = [
            .configuration: modifierTableViewCellConfigurationAction,
            .selection: modifierTableViewCellSelectionAction
        ]
        
        viewModel.tableViewSectionModels.bindAndRun { value in
            self.tableViewDataSource.sectionModels = value
            self.tableViewDelegate.sectionModels = value
            self.tableView.reloadData()
        }
        
        viewModel.errorHandler = { value in
            switch value {
            default: print(value.localizedDescription)
            }
        }
    }
    
    // MARK: - Target Actions
    private func doneBarButtonItemAction() {
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Cell Actions
    private func modifierTableViewCellConfigurationAction(data: UITableViewCellActionHandlerData) {
        guard let cellViewModel = data.cellViewModel as? ModifiersViewModel.ModifierTableViewCellViewModel,
            let cell = data.cell as? SubtitleTableViewCell else { return }
        
        cell.textLabel?.text = cellViewModel.configurationData.text
        cell.detailTextLabel?.text = cellViewModel.configurationData.detailText
        cell.accessoryType = cellViewModel.configurationData.isSelected ? .checkmark : .none
    }
    
    private func modifierTableViewCellSelectionAction(data: UITableViewCellActionHandlerData) {
        guard let cellViewModel = data.cellViewModel as? ModifiersViewModel.ModifierTableViewCellViewModel else { return }
        
        if cellViewModel.selectionData.isSelected {
            viewModel.remove(cellViewModel.selectionData.modifierID)
        } else { viewModel.add(cellViewModel.selectionData.modifierID) }
    }
}
