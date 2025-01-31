//
//  PurchasedOrdersViewModel.swift
//  Kitchen
//
//  Created by Natanel Niazoff on 4/17/19.
//  Copyright © 2019 Natanel Niazoff. All rights reserved.
//

import Foundation
import PromiseKit

class PurchasedOrdersViewModel {
    private let apiURLRequestFactory = APIURLRequestFactory()
    
    private var purchasedOrders = [PurchasedOrder]()
    
    // MARK: - Dependencies
    var httpClient: HTTPClient
    
    // MARK: - Section Model Properties
    private var scheduledPurchasedOrdersTableViewSectionModel: UITableViewSectionModel? {
        didSet { updateTableViewSectionModels() }
    }
    
    private var purchasedOrdersTableViewSectionModel: UITableViewSectionModel? {
        didSet { updateTableViewSectionModels() }
    }
    
    // MARK: - View Settable Properties
    var purchasedOrderCellViewModelActions = [UITableViewCellAction: UITableViewCellActionHandler]() {
        didSet { updatePurchasedOrdersTableViewSectionModel() }
    }
    
    var errorHandler: (Error) -> Void = { _ in }
    
    // MARK: - Dynamic Properties
    private(set) lazy var tableViewSectionModels = Dynamic(makeTableViewSectionModels())
    
    enum CellIdentifier: String {
        case orderTableViewCell
    }
    
    private struct Constants {
        static let scheduledPurchasedOrdersTableViewSectionModelTitle = "Scheduled"
        static let purchasedOrdersTableViewSectionModelTitle = "ASAP"
        
        static let purchasedOrderCellViewModelHeight = Double(100)
        static let purchasedOrderDateTextFormat = "h:mm a"
    }
    
    init(httpClient: HTTPClient = URLSession.shared) {
        self.httpClient = httpClient
    }
    
    // MARK: - Setup Methods
    private func setUp(for purchasedOrders: [PurchasedOrder]) {
        self.purchasedOrders = purchasedOrders
        updateScheduledPurchasedOrdersTableViewSectionModel()
        updatePurchasedOrdersTableViewSectionModel()
    }
    
    private func updateScheduledPurchasedOrdersTableViewSectionModel() {
        let scheduledPurchasedOrders = purchasedOrders.filter { $0.preparedForDate != nil }
        scheduledPurchasedOrdersTableViewSectionModel = makeScheduledPurchasedOrdersTableViewSectionModel(purchasedOrders: scheduledPurchasedOrders)
    }
    
    private func updatePurchasedOrdersTableViewSectionModel() {
        let nonScheduledPurchasedOrders = purchasedOrders.filter { $0.preparedForDate == nil }
        purchasedOrdersTableViewSectionModel = makePurchasedOrdersTableViewSectionModel(purchasedOrders: nonScheduledPurchasedOrders)
    }
    
    private func updateTableViewSectionModels() {
        tableViewSectionModels.value = makeTableViewSectionModels()
    }
    
    // MARK: - Download Methods
    func beginDownloads() {
        beginPurchasedOrdersDownload()
            .catch(errorHandler)
    }
    
    private func beginPurchasedOrdersDownload() -> Promise<Void> {
        return getPurchasedOrders().done(setUp)
    }
    
    private func getPurchasedOrders() -> Promise<[PurchasedOrder]> {
        return httpClient.send(apiURLRequestFactory.makeGetPurchasedOrdersRequest()).validate()
            .map { try self.apiURLRequestFactory.defaultJSONDecoder.decode([PurchasedOrder].self, from: $0.data) }
    }
    
    // MARK: - Section Model Methods
    private func makeScheduledPurchasedOrdersTableViewSectionModel(purchasedOrders: [PurchasedOrder]) -> UITableViewSectionModel? {
        guard !purchasedOrders.isEmpty else { return nil }
        return UITableViewSectionModel(
            title: Constants.scheduledPurchasedOrdersTableViewSectionModelTitle,
            cellViewModels: purchasedOrders.map(makePurchasedOrderCellViewModel)
        )
    }
    
    private func makePurchasedOrdersTableViewSectionModel(purchasedOrders: [PurchasedOrder]) -> UITableViewSectionModel? {
        guard !purchasedOrders.isEmpty else { return nil }
        return UITableViewSectionModel(
            title: Constants.purchasedOrdersTableViewSectionModelTitle,
            cellViewModels: purchasedOrders.map(makePurchasedOrderCellViewModel)
        )
    }
    
    private func makeTableViewSectionModels() -> [UITableViewSectionModel] {
        var sectionModels = [UITableViewSectionModel]()
        if let scheduledPurchasedOrdersModel = scheduledPurchasedOrdersTableViewSectionModel {
            sectionModels.append(scheduledPurchasedOrdersModel)
        }
        if let purchasedOrdersModel = purchasedOrdersTableViewSectionModel {
            sectionModels.append(purchasedOrdersModel)
        }
        return sectionModels
    }
    
    // MARK: - Cell View Model Methods
    private func makePurchasedOrderCellViewModel(purchasedOrder: PurchasedOrder) -> PurchasedOrderCellViewModel {
        let descriptionText = "Order #\(purchasedOrder.number)"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = Constants.purchasedOrderDateTextFormat
        
        let dateText: String
        let isPickupDateText: Bool
        if let preparedForDate = purchasedOrder.preparedForDate {
            dateText = dateFormatter.string(from: preparedForDate)
            isPickupDateText = true
        } else {
            dateText = dateFormatter.string(from: purchasedOrder.purchasedDate)
            isPickupDateText = false
        }
        
        return PurchasedOrderCellViewModel(
            identifier: CellIdentifier.orderTableViewCell.rawValue,
            height: .fixed(Constants.purchasedOrderCellViewModelHeight),
            actions: purchasedOrderCellViewModelActions,
            configurationData: .init(titleText: purchasedOrder.user?.fullName, descriptionText: descriptionText, dateText: dateText, isPickupDateText: isPickupDateText, progress: purchasedOrder.progress),
            selectionData: .init(id: purchasedOrder.id, title: purchasedOrder.user?.firstName)
        )
    }
}

extension PurchasedOrdersViewModel {
    struct PurchasedOrderCellViewModel: UITableViewCellViewModel {
        let identifier: String
        let height: UITableViewCellViewModelHeight
        let actions: [UITableViewCellAction: UITableViewCellActionHandler]
        let configurationData: ConfigurationData
        let selectionData: SelectionData
        
        struct ConfigurationData {
            let titleText: String?
            let descriptionText: String
            let dateText: String
            let isPickupDateText: Bool
            let progress: OrderProgress
        }
        
        struct SelectionData {
            let id: PurchasedOrder.ID
            let title: String?
        }
    }
}
