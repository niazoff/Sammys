//
//  OrderViewController.swift
//  Sammys
//
//  Created by Natanel Niazoff on 4/24/18.
//  Copyright © 2018 Natanel Niazoff. All rights reserved.
//

import UIKit

class OrderViewController: UIViewController {
    var viewModel: OrderViewModel!
    
    // MARK: - IBOutlets
    @IBOutlet var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
}

extension OrderViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfSections
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfRows
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = viewModel.cellViewModels[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: model.identifier)!
        model.commands[.configuration]?.perform(cell: cell)
        return cell
    }
}

extension OrderViewController: UITableViewDelegate {
    
}

extension OrderViewController: Storyboardable {
    typealias ViewController = OrderViewController
}