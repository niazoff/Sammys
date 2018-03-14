//
//  UserViewController.swift
//  Sammys
//
//  Created by Natanel Niazoff on 1/11/18.
//  Copyright © 2018 Natanel Niazoff. All rights reserved.
//

import UIKit
import Stripe

class UserViewController: UIViewController, Storyboardable {
    typealias ViewController = UserViewController
    
    let viewModel = UserViewModel()
    
    /// Indicates whether the user canceled logging in.
    var didCancelLogin = false
    
    // MARK: - IBOutlets & View Properties
    @IBOutlet var tableView: UITableView!
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        viewModel.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Prompt to login if needed.
        if viewModel.needsUser && !didCancelLogin {
            presentLoginPageViewController()
        }
        
        // Dismiss if returning from canceled login.
        if didCancelLogin {
            dismiss(animated: true, completion: nil)
        }
    }
    // MARK: -
    
    func presentLoginPageViewController() {
        let loginPageViewController = LoginPageViewController.storyboardInstance()
        present(loginPageViewController, animated: true, completion: nil)
    }
    
    func pushAddCardViewController() {
        let theme = STPTheme()
        theme.accentColor = .mocha
        let addCardViewController = STPAddCardViewController(configuration: STPPaymentConfiguration.shared(), theme: theme)
        addCardViewController.delegate = self
        navigationController?.pushViewController(addCardViewController, animated: true)
    }
    
    func pushPaymentMethodsViewController() {
        let theme = STPTheme()
        theme.accentColor = .mocha
        let paymentMethodsViewController = STPPaymentMethodsViewController(configuration: STPPaymentConfiguration.shared(), theme: theme, customerContext: viewModel.stripeCustomerContext, delegate: self)
        navigationController?.pushViewController(paymentMethodsViewController, animated: true)
    }

    // MARK: - IBActions
    @IBAction func didTapDone(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }
}

// MARK: - Table View Data Source & Delegate
extension UserViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfSections
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfRows(in: section)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = viewModel.item(for: indexPath)!
        
        switch item.key {
        case .name:
            let nameItem = item as! NameUserItem
            let nameCell = cell(for: nameItem)!
            nameCell.detailTextLabel?.text = nameItem.name
            return nameCell
        case .email:
            let emailItem = item as! EmailUserItem
            let emailCell = cell(for: emailItem)!
            emailCell.detailTextLabel?.text = emailItem.email
            return emailCell
        default: return cell(for: item)!
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = viewModel.item(for: indexPath)!
        
        switch item.key {
        case .creditCard:
            pushAddCardViewController()
        case .paymentMethods:
            pushPaymentMethodsViewController()
        case .logOut:
            let logOutItem = item as! LogOutUserItem
            logOutItem.didSelect()
        default: break
        }
    }
    
    func cell(for item: UserItem) -> UITableViewCell? {
        let cell = tableView.dequeueReusableCell(withIdentifier: item.cellIdentifier)
        cell?.textLabel?.text = item.title
        return cell
    }
}

// MARK: - View Model Delegate
extension UserViewController: UserViewModelDelegate {
    var userDidChange: () -> Void {
        return {
            self.tableView.reloadData()
            if self.viewModel.needsUser {
                self.presentLoginPageViewController()
            }
        }
    }
}

// MARK: - Stripe Add Card View Controller Delegate
extension UserViewController: STPAddCardViewControllerDelegate {
    func addCardViewControllerDidCancel(_ addCardViewController: STPAddCardViewController) {
        navigationController?.popViewController(animated: true)
    }
    
    func addCardViewController(_ addCardViewController: STPAddCardViewController, didCreateToken token: STPToken, completion: @escaping STPErrorBlock) {
        navigationController?.popViewController(animated: true)
        viewModel.setUserAsCustomer(with: token.tokenId)
    }
}

extension UserViewController: STPPaymentMethodsViewControllerDelegate {
    func paymentMethodsViewController(_ paymentMethodsViewController: STPPaymentMethodsViewController, didFailToLoadWithError error: Error) {
        print(error.localizedDescription)
        paymentMethodsViewController.dismiss()
    }
    
    func paymentMethodsViewControllerDidFinish(_ paymentMethodsViewController: STPPaymentMethodsViewController) {
        paymentMethodsViewController.dismiss()
    }
    
    func paymentMethodsViewControllerDidCancel(_ paymentMethodsViewController: STPPaymentMethodsViewController) {
        paymentMethodsViewController.dismiss()
    }
}
