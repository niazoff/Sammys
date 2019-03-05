//
//  ConstructedItemViewController.swift
//  Sammys
//
//  Created by Natanel Niazoff on 2/25/19.
//  Copyright © 2019 Natanel Niazoff. All rights reserved.
//

import UIKit
import TinyConstraints

class ConstructedItemViewController: UIViewController {
    let viewModel = ConstructedItemViewModel()
    
    let categoryCollectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
    let itemsViewController = ItemsViewController()
    let addToBagRoundedButton = RoundedButton()
    
    private let categoryCollectionViewDataSource = UICollectionViewSectionModelsDataSource()
    private let categoryCollectionViewDelegate = UICollectionViewSectionModelsDelegateFlowLayout()
    
    private lazy var addToBagRoundedButtonTarget = UIControl.Target(action: addToBagRoundedButtonAction)
    
    private struct Constants {
        static let categoryCollectionViewInset: CGFloat = 10
        static let categoryCollectionViewHeight: CGFloat = 40
        static let addToBagRoundedButtonTitleLabelText = "Add to Bag"
        static let addToBagRoundedButtonHeight: CGFloat = 40
    }
    
    enum CellIdentifier: String {
        case roundedTextCell
    }
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpView()
        configureCategoryCollectionView()
        configureItemsViewController()
        configureAddToBagRoundedButton()
        configureViewModel()
    }
    
    // MARK: - Setup Methods
    private func setUpView() {
        self.view.backgroundColor = .white
        addSubviews()
    }
    
    private func addSubviews() {
        [categoryCollectionView, addToBagRoundedButton]
            .forEach { self.view.addSubview($0) }
    }
    
    private func configureCategoryCollectionView() {
        if let layout = categoryCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .horizontal
        }
        categoryCollectionView.dataSource = categoryCollectionViewDataSource
        categoryCollectionView.delegate = categoryCollectionViewDelegate
        categoryCollectionView.register(RoundedTextCollectionViewCell.self, forCellWithReuseIdentifier: CellIdentifier.roundedTextCell.rawValue)
        categoryCollectionView.backgroundColor = .clear
        categoryCollectionView.showsHorizontalScrollIndicator = false
        categoryCollectionView.contentInset.left = Constants.categoryCollectionViewInset
        categoryCollectionView.contentInset.right = Constants.categoryCollectionViewInset
        categoryCollectionView.edgesToSuperview(excluding: .bottom, insets: .top(Constants.categoryCollectionViewInset), usingSafeArea: true)
        categoryCollectionView.height(Constants.categoryCollectionViewHeight)
    }
    
    private func configureItemsViewController() {
        itemsViewController.viewModel.httpClient = viewModel.httpClient
        itemsViewController.itemSelectionHandler = { data in
            self.viewModel.beginAddConstructedItemItemsDownload(categoryItemIDs: [data.categoryItemID])
        }
        add(itemsViewController)
        view.sendSubviewToBack(itemsViewController.view)
        itemsViewController.tableView.contentInset.top =
            Constants.categoryCollectionViewHeight + (Constants.categoryCollectionViewInset * 2)
        itemsViewController.tableView.scrollIndicatorInsets.top = itemsViewController.tableView.contentInset.top
        itemsViewController.view.edgesToSuperview(usingSafeArea: true)
    }
    
    private func configureAddToBagRoundedButton() {
        addToBagRoundedButton.titleLabel.text = Constants.addToBagRoundedButtonTitleLabelText
        addToBagRoundedButton.add(addToBagRoundedButtonTarget, for: .touchUpInside)
        addToBagRoundedButton.height(Constants.addToBagRoundedButtonHeight)
        addToBagRoundedButton.centerX(to: self.view)
        addToBagRoundedButton.bottom(to: self.view.safeAreaLayoutGuide)
    }
    
    private func configureViewModel() {
        let sizeCalculationLabel = UILabel()
        viewModel.categoryRoundedTextCollectionViewCellViewModelActions = [
            .configuration: categoryRoundedTextCollectionViewCellConfigurationAction,
            .selection: categoryRoundedTextCollectionViewCellSelectionAction
        ]
        viewModel.categoryRoundedTextCollectionViewCellViewModelSize = { cellViewModel in
            sizeCalculationLabel.text = cellViewModel.configurationData.text
            return (Double(sizeCalculationLabel.intrinsicContentSize.width) + 20, Double(self.categoryCollectionView.frame.height))
        }
        viewModel.selectedCategoryID.bind { id in
            self.itemsViewController.viewModel.categoryID = id
            self.itemsViewController.viewModel.beginDownloads()
        }
        viewModel.categoryCollectionViewSectionModels.bind { sectionModels in
            self.categoryCollectionViewDataSource.sectionModels = sectionModels
            self.categoryCollectionViewDelegate.sectionModels = sectionModels
            self.categoryCollectionView.reloadData()
        }
        viewModel.totalPriceText.bind { text in
            if let text = text {
                self.addToBagRoundedButton.titleLabel.text = Constants.addToBagRoundedButtonTitleLabelText + " " + text
            } else { self.addToBagRoundedButton.titleLabel.text = Constants.addToBagRoundedButtonTitleLabelText }
        }
        viewModel.beginDownloads()
    }
    
    // MARK: - Target Actions
    private func addToBagRoundedButtonAction() {
        
    }
    
    // MARK: - Cell Actions
    private func categoryRoundedTextCollectionViewCellConfigurationAction(data: UICollectionViewCellActionHandlerData) {
        guard let cellViewModel = data.cellViewModel as? ConstructedItemViewModel.CategoryRoundedTextCollectionViewCellViewModel,
            let cell = data.cell as? RoundedTextCollectionViewCell else { return }
        cell.textLabel.text = cellViewModel.configurationData.text
    }
    
    private func categoryRoundedTextCollectionViewCellSelectionAction(data: UICollectionViewCellActionHandlerData) {
        guard let cellViewModel = data.cellViewModel as? ConstructedItemViewModel.CategoryRoundedTextCollectionViewCellViewModel else { return }
        viewModel.selectedCategoryID.value = cellViewModel.selectionData.categoryID
    }
}