//
//  PurchasedOrderViewModel.swift
//  Kitchen
//
//  Created by Natanel Niazoff on 4/18/19.
//  Copyright © 2019 Natanel Niazoff. All rights reserved.
//

import Foundation
import PromiseKit

class PurchasedOrderViewModel {
    private let apiURLRequestFactory = APIURLRequestFactory()
    
    private var purchasedOrder: PurchasedOrder?
    private var purchasedConstructedItems = [PurchasedConstructedItem]()
    
    // MARK: - Dependencies
    var httpClient: HTTPClient
    
    // MARK: - Section Model Properties
    private var noteTableViewSectionModel: UITableViewSectionModel? {
        didSet { updateTableViewSectionModels() }
    }
    
    private var purchasedConstructedItemsTableViewSectionModel: UITableViewSectionModel? {
        didSet { updateTableViewSectionModels() }
    }
    
    // MARK: - View Settable Properties
    var purchasedOrderID: PurchasedOrder.ID?
    
    var noteTableViewCellViewModelActions = [UITableViewCellAction: UITableViewCellActionHandler]() {
        didSet { updateNoteTableViewSectionModel() }
    }
    
    var purchasedConstructedItemTableViewCellViewModelActions = [UITableViewCellAction: UITableViewCellActionHandler]() {
        didSet { updatePurchasedConstructedItemsTableViewSectionModel() }
    }
    
    var errorHandler: (Error) -> Void = { _ in }
    
    // MARK: - Dynamic Properties
    private(set) lazy var tableViewSectionModels = Dynamic(makeTableViewSectionModels())
    
    let purchasedOrderIsCompleted = Dynamic(false)
    
    let purchasedConstructedItemItems = Dynamic([CategorizedItemsViewModel.CategorizedItems]())
    
    enum CellIdentifier: String {
        case textViewTableViewCell
        case itemTableViewCell
    }
    
    private struct Constants {
        static let purchasedConstructedItemTableViewCellViewModelHeight = Double(100)
    }
    
    init(httpClient: HTTPClient = URLSession.shared) {
        self.httpClient = httpClient
    }
    
    // MARK: - Setup Methods
    private func setUp(for purchasedOrder: PurchasedOrder) {
        self.purchasedOrder = purchasedOrder
        purchasedOrderIsCompleted.value = purchasedOrder.progress == .isCompleted
        updateNoteTableViewSectionModel()
    }
    
    private func setUp(for purchasedConstructedItems: [PurchasedConstructedItem]) {
        self.purchasedConstructedItems = purchasedConstructedItems
        updatePurchasedConstructedItemsTableViewSectionModel()
    }
    
    private func setUp(for purchasedConstructedItemItems: [CategorizedItemsViewModel.CategorizedItems]) {
        self.purchasedConstructedItemItems.value = purchasedConstructedItemItems
    }
    
    private func updateNoteTableViewSectionModel() {
        guard let purchasedOrder = purchasedOrder else {
            noteTableViewSectionModel = nil; return
        }
        noteTableViewSectionModel = makeNoteTableViewSectionModel(purchasedOrder: purchasedOrder)
    }
    
    private func updatePurchasedConstructedItemsTableViewSectionModel() {
        purchasedConstructedItemsTableViewSectionModel = makePurchasedConstructedItemsTableViewSectionModel(purchasedConstructedItems: purchasedConstructedItems)
    }
    
    private func updateTableViewSectionModels() {
        tableViewSectionModels.value = makeTableViewSectionModels()
    }
    
    // MARK: - Download Methods
    func beginDownloads() {
        when(fulfilled: [
            beginPurchasedOrderDownload(),
            beginPurchasedConstructedItemsDownload(),
            beginUpdatePurchasedOrderProgressIsPreparing()
        ]).catch(errorHandler)
    }
    
    func beginPurchasedConstructedItemItemsDownload(id: PurchasedConstructedItem.ID) {
        getPurchasedConstructedItemItems(id: id).done(setUp)
            .catch(errorHandler)
    }
    
    func beginUpdatePurchasedOrderProgressIsCompleted(successHandler: @escaping () -> Void = {}) {
        partiallyUpdatePurchasedOrder(data: .init(progress: .isCompleted)).asVoid()
            .done(successHandler)
            .catch(errorHandler)
    }
    
    private func beginPurchasedOrderDownload() -> Promise<Void> {
        return getPurchasedOrder().done(setUp)
    }
    
    private func beginPurchasedConstructedItemsDownload() -> Promise<Void> {
        return getPurchasedConstructedItems().done(setUp)
    }
    
    private func beginUpdatePurchasedOrderProgressIsPreparing() -> Promise<Void> {
        return getPurchasedOrder().then { purchasedOrder -> Promise<Void> in
            guard purchasedOrder.progress != .isCompleted
                else { return Promise { $0.fulfill(()) } }
            return self.partiallyUpdatePurchasedOrder(data: .init(progress: .isPreparing)).asVoid()
        }
    }
    
    private func getPurchasedOrder() -> Promise<PurchasedOrder> {
        return httpClient.send(apiURLRequestFactory.makeGetPurchasedOrderRequest(id: purchasedOrderID ?? preconditionFailure())).validate()
            .map { try self.apiURLRequestFactory.defaultJSONDecoder.decode(PurchasedOrder.self, from: $0.data) }
    }
    
    private func getPurchasedConstructedItems() -> Promise<[PurchasedConstructedItem]> {
        return httpClient.send(apiURLRequestFactory.makeGetPurchasedOrderConstructedItems(id: purchasedOrderID ?? preconditionFailure())).validate()
            .map { try self.apiURLRequestFactory.defaultJSONDecoder.decode([PurchasedConstructedItem].self, from: $0.data) }
    }
    
    private func getPurchasedConstructedItemItems(id: PurchasedConstructedItem.ID) -> Promise<[CategorizedItemsViewModel.CategorizedItems]> {
        return httpClient.send(apiURLRequestFactory.makeGetPurchasedOrderConstructedItemItems(purchasedOrderID: purchasedOrderID ?? preconditionFailure(), purchasedConstructedItemID: id)).validate()
            .map { try self.apiURLRequestFactory.defaultJSONDecoder.decode([CategorizedItemsViewModel.CategorizedItems].self, from: $0.data) }
    }
    
    private func partiallyUpdatePurchasedOrder(data: PartiallyUpdatePurchasedOrderRequestData) -> Promise<PurchasedOrder> {
        do {
            return try httpClient.send(apiURLRequestFactory.makePartiallyUpdatePurchasedOrderRequest(id: purchasedOrderID ?? preconditionFailure(), data: data)).validate()
            .map { try self.apiURLRequestFactory.defaultJSONDecoder.decode(PurchasedOrder.self, from: $0.data) }
        } catch { preconditionFailure(error.localizedDescription) }
    }
    
    // MARK: - Section Model Methods
    private func makeNoteTableViewSectionModel(purchasedOrder: PurchasedOrder) -> UITableViewSectionModel? {
        guard let note = purchasedOrder.note else { return nil }
        return UITableViewSectionModel(cellViewModels: [makeNoteTableViewCellViewModel(note: note)])
    }
    
    private func makePurchasedConstructedItemsTableViewSectionModel(purchasedConstructedItems: [PurchasedConstructedItem]) -> UITableViewSectionModel? {
        guard !purchasedConstructedItems.isEmpty else { return nil }
        return UITableViewSectionModel(cellViewModels: purchasedConstructedItems.map(makePurchasedConstructedItemTableViewCellViewModel))
    }
    
    private func makeTableViewSectionModels() -> [UITableViewSectionModel] {
        var sectionModels = [UITableViewSectionModel]()
        if let noteModel = noteTableViewSectionModel {
            sectionModels.append(noteModel)
        }
        if let purchasedConstructedItemsModel = purchasedConstructedItemsTableViewSectionModel {
            sectionModels.append(purchasedConstructedItemsModel)
        }
        return sectionModels
    }
    
    // MARK: - Cell View Model Methods
    private func makeNoteTableViewCellViewModel(note: String) -> NoteTableViewCellViewModel {
        return NoteTableViewCellViewModel(
            identifier: CellIdentifier.textViewTableViewCell.rawValue,
            height: .automatic,
            actions: noteTableViewCellViewModelActions,
            configurationData: .init(text: note)
        )
    }
    
    private func makePurchasedConstructedItemTableViewCellViewModel(purchasedConstructedItem: PurchasedConstructedItem) -> PurchasedConstructedItemTableViewCellViewModel {
        var titleText: String?
        if let name = purchasedConstructedItem.name {
            var text = name
            if purchasedConstructedItem.quantity > 1 {
                text = text + " x \(purchasedConstructedItem.quantity)"
            }
            titleText = text
        }
        
        return PurchasedConstructedItemTableViewCellViewModel(
            identifier: CellIdentifier.itemTableViewCell.rawValue,
            height: .fixed(Constants.purchasedConstructedItemTableViewCellViewModelHeight),
            actions: purchasedConstructedItemTableViewCellViewModelActions,
            configurationData: .init(titleText: titleText),
            selectionData: .init(id: purchasedConstructedItem.id, title: titleText)
        )
    }
}

extension PurchasedOrderViewModel {
    struct NoteTableViewCellViewModel: UITableViewCellViewModel {
        let identifier: String
        let height: UITableViewCellViewModelHeight
        let isSelectable = false
        let actions: [UITableViewCellAction: UITableViewCellActionHandler]
        
        let configurationData: ConfigurationData
        
        struct ConfigurationData {
            let text: String
        }
    }
}

extension PurchasedOrderViewModel {
    struct PurchasedConstructedItemTableViewCellViewModel: UITableViewCellViewModel {
        let identifier: String
        let height: UITableViewCellViewModelHeight
        let actions: [UITableViewCellAction: UITableViewCellActionHandler]
        
        let configurationData: ConfigurationData
        let selectionData: SelectionData
        
        struct ConfigurationData {
            let titleText: String?
        }
        
        struct SelectionData {
            let id: PurchasedConstructedItem.ID
            let title: String?
        }
    }
}
