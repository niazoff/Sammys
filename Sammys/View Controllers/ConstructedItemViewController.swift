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
    private let categoryCollectionViewDataSource = UICollectionViewSectionModelsDataSource()
    private let categoryCollectionViewDelegate = UICollectionViewSectionModelsDelegateFlowLayout()
    let itemsViewController = ItemsViewController()
    
    private struct Constants {
        static let categoryCollectionViewInset: CGFloat = 10
        static let categoryCollectionViewHeight: CGFloat = 40
    }
    
    enum CellIdentifier: String {
        case roundedTextCell
    }
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        self.view.backgroundColor = .white
        
        addSubviews()
        configureCategoryCollectionView()
        configureItemsViewController()
        configureViewModel()
    }
    
    // MARK: - Setup Methods
    private func addSubviews() {
        [categoryCollectionView]
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
        itemsViewController.categoryItemIDSelectionHandler = { id in
            self.viewModel.beginAddConstructedItemItemsDownload(categoryItemIDs: [id])
        }
        add(itemsViewController)
        itemsViewController.view.edgesToSuperview(excluding: .top)
        itemsViewController.view.topToBottom(of: categoryCollectionView)
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
        viewModel.beginDownloads()
    }
    
    // MARK: - UITableViewCellViewModel Actions
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
