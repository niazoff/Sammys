//
//  OutstandingOrderViewModel.swift
//  Sammys
//
//  Created by Natanel Niazoff on 3/7/19.
//  Copyright © 2019 Natanel Niazoff. All rights reserved.
//

import Foundation
import PromiseKit
import FirebaseAuth

class OutstandingOrderViewModel {
    private let apiURLRequestFactory = APIURLRequestFactory()
    
    // MARK: - Dependencies
    var httpClient: HTTPClient
    var keyValueStore: KeyValueStore
    var userAuthManager: UserAuthManager
    
    // MARK: - Section Model Properties
    private var constructedItemsTableViewSectionModel: UITableViewSectionModel? {
        didSet { updateTableViewSectionModels() }
    }
    
    // MARK: - View Settable Properties
    /// Required to be non-`nil` before beginning downloads.
    /// If not set, calling `beginDownloads()` will first attempt to set.
    var outstandingOrderID: OutstandingOrder.ID?
    
    /// Allowed to be `nil`. Use `beginUserIDDownload()` to attempt to set.
    /// Must be set to the outstanding order's user's ID before beginning downloads.
    /// If set and verifiable, calling `beginDownloads()` will set the
    /// outstanding order's user to the one specified if necessary.
    var userID: User.ID?
    
    var constructedItemStackCellViewModelActions = [UITableViewCellAction: UITableViewCellActionHandler]()
    
    var errorHandler: ((Error) -> Void) = { _ in }
    
    // MARK: - View Gettable Properties
    var isUserSignedIn: Bool { return userAuthManager.isUserSignedIn }
    
    // MARK: - Dynamic Properties
    private(set) lazy var tableViewSectionModels = Dynamic(makeTableViewSectionModels())
    
    let taxPriceText: Dynamic<String?> = Dynamic(nil)
    let subtotalPriceText: Dynamic<String?> = Dynamic(nil)
    
    enum CellIdentifier: String {
        case itemStackTableViewCell
    }
    
    init(httpClient: HTTPClient = URLSession.shared,
         keyValueStore: KeyValueStore = UserDefaults.standard,
         userAuthManager: UserAuthManager = Auth.auth()) {
        self.httpClient = httpClient
        self.keyValueStore = keyValueStore
        self.userAuthManager = userAuthManager
    }
    
    // MARK: - Setup Methods
    private func setUp(for outstandingOrderID: OutstandingOrder.ID) {
        self.outstandingOrderID = outstandingOrderID
        keyValueStore.set(outstandingOrderID.uuidString, forKey: KeyValueStoreKeys.currentOutstandingOrderID)
    }
    
    private func setUp(for outstandingOrder: OutstandingOrder) {
        taxPriceText.value = outstandingOrder.taxPrice?.toUSDUnits().toPriceString()
        subtotalPriceText.value = outstandingOrder.totalPrice?.toUSDUnits().toPriceString()
    }
    
    private func setUp(for constructedItems: [ConstructedItem]) {
        constructedItemsTableViewSectionModel = makeConstructedItemsTableViewSectionModel(constructedItems: constructedItems)
    }
    
    private func updateTableViewSectionModels() {
        tableViewSectionModels.value = makeTableViewSectionModels()
    }
    
    // MARK: - Download Methods
    func beginDownloads() {
        firstly { self.beginOutstandingOrderIDDownload() }.then {
            when(fulfilled: [
                self.beginOutstandingOrderDownload(),
                self.beginOutstandingOrderConstructedItemsDownload()
            ])
        }.catch(errorHandler)
    }
    
    func beginUpdateConstructedItemQuantityDownload(constructedItemID: ConstructedItem.ID, quantity: Int) {
        makeUpdateConstructedItemQuantityDownload(constructedItemID: constructedItemID, quantity: quantity)
            .then { self.beginOutstandingOrderConstructedItemsDownload() }
            .then { self.beginOutstandingOrderDownload() }
            .catch(errorHandler)
    }
    
    func beginUserIDDownload(successHandler: @escaping (() -> Void) = {}) {
        userAuthManager.getCurrentUserIDToken()
            .then { self.getTokenUser(token: $0) }
            .get { self.userID = $0.id }.asVoid()
            .done(successHandler)
            .catch(errorHandler)
    }
    
    private func beginOutstandingOrderIDDownload() -> Promise<Void> {
        return makeOutstandingOrderIDDownload().done(setUp)
    }
    
    private func beginOutstandingOrderDownload() -> Promise<Void> {
        return makeOutstandingOrderDownload().done(setUp)
    }
    
    private func beginOutstandingOrderConstructedItemsDownload() -> Promise<Void> {
        return makeOutstandingOrderConstructedItemsDownload().done(setUp)
    }
    
    private func makeOutstandingOrderIDDownload() -> Promise<OutstandingOrder.ID> {
        if let idString = keyValueStore.value(of: String.self, forKey: KeyValueStoreKeys.currentOutstandingOrderID),
            let id = OutstandingOrder.ID(uuidString: idString) {
            return Promise { $0.fulfill(id) }
        } else if userID != nil {
            return userAuthManager.getCurrentUserIDToken()
                .then(getUserOutstandingOrders).map { outstandingOrders in
                    guard let outstandingOrder = outstandingOrders.first
                        else { throw OutstandingOrderViewModelError.noOutstandingOrderFound }
                    return outstandingOrder.id
            }
        } else { return Promise(error: OutstandingOrderViewModelError.noOutstandingOrderFound) }
    }
    
    private func makeTokenAndOutstandingOrderDownload() -> Promise<OutstandingOrder> {
        if userID != nil {
            return userAuthManager.getCurrentUserIDToken()
                .then { self.getOutstandingOrder(token: $0) }
        } else { return getOutstandingOrder() }
    }
    
    private func makeOutstandingOrderDownload() -> Promise<OutstandingOrder> {
        if outstandingOrderID == nil {
            return beginOutstandingOrderIDDownload()
                .then { self.makeTokenAndOutstandingOrderDownload() }
        } else { return makeTokenAndOutstandingOrderDownload() }
    }
    
    private func makeOutstandingOrderConstructedItemsDownload() -> Promise<[ConstructedItem]> {
        if userID != nil {
            return userAuthManager.getCurrentUserIDToken()
                .then { self.getOutstandingOrderConstructedItems(token: $0) }
        } else { return getOutstandingOrderConstructedItems() }
    }
    
    private func makeUpdateConstructedItemQuantityOrRemoveDownload(constructedItemID: ConstructedItem.ID, quantity: Int, token: JWT? = nil) -> Promise<Void> {
        if quantity > 0 {
            return partiallyUpdateOutstandingOrderConstructedItem(constructedItemID: constructedItemID, data: .init(quantity: quantity), token: token).asVoid()
        } else {
            return removeOutstandingOrderConstructedItem(outstandingOrderID: outstandingOrderID ?? preconditionFailure(), constructedItemID: constructedItemID, token: token).asVoid()
        }
    }
    
    private func makeUpdateConstructedItemQuantityDownload(constructedItemID: ConstructedItem.ID, quantity: Int) -> Promise<Void> {
        if userID != nil {
            return userAuthManager.getCurrentUserIDToken().then { token in
                self.makeUpdateConstructedItemQuantityOrRemoveDownload(constructedItemID: constructedItemID, quantity: quantity, token: token)
            }
        } else { return makeUpdateConstructedItemQuantityOrRemoveDownload(constructedItemID: constructedItemID, quantity: quantity) }
    }
    
    private func getUserOutstandingOrders(token: JWT) -> Promise<[OutstandingOrder]> {
        return httpClient.send(apiURLRequestFactory.makeGetUserOutstandingOrdersRequest(id: userID ?? preconditionFailure(), token: token)).validate()
            .map { try self.apiURLRequestFactory.defaultJSONDecoder.decode([OutstandingOrder].self, from: $0.data) }
    }
    
    private func getOutstandingOrder(token: JWT? = nil) -> Promise<OutstandingOrder> {
        return httpClient.send(apiURLRequestFactory.makeGetOutstandingOrderRequest(id: outstandingOrderID ?? preconditionFailure(), token: token)).validate()
            .map { try self.apiURLRequestFactory.defaultJSONDecoder.decode(OutstandingOrder.self, from: $0.data) }
    }
    
    private func getOutstandingOrderConstructedItems(token: JWT? = nil) -> Promise<[ConstructedItem]> {
        return httpClient.send(apiURLRequestFactory.makeGetOutstandingOrderConstructedItemsRequest(id: outstandingOrderID ?? preconditionFailure(), token: token)).validate()
            .map { try self.apiURLRequestFactory.defaultJSONDecoder.decode([ConstructedItem].self, from: $0.data) }
    }
    
    private func partiallyUpdateOutstandingOrderConstructedItem(constructedItemID: ConstructedItem.ID, data: PartiallyUpdateOutstandingOrderConstructedItemRequestData, token: JWT? = nil) -> Promise<ConstructedItem> {
        do {
            return try httpClient.send(apiURLRequestFactory.makePartiallyUpdateOutstandingOrderConstructedItemRequest(
                outstandingOrderID: outstandingOrderID ?? preconditionFailure(), constructedItemID: constructedItemID, data: data, token: token)).validate()
                .map { try self.apiURLRequestFactory.defaultJSONDecoder.decode(ConstructedItem.self, from: $0.data) }
        } catch { preconditionFailure(error.localizedDescription) }
    }
    
    private func removeOutstandingOrderConstructedItem(outstandingOrderID: OutstandingOrder.ID, constructedItemID: ConstructedItem.ID, token: JWT? = nil) -> Promise<OutstandingOrder> {
        return httpClient.send(apiURLRequestFactory.makeRemoveOutstandingOrderConstructedItem(outstandingOrderID: outstandingOrderID, constructedItemID: constructedItemID, token: token)).validate()
            .map { try self.apiURLRequestFactory.defaultJSONDecoder.decode(OutstandingOrder.self, from: $0.data) }
    }
    
    private func getTokenUser(token: JWT) -> Promise<User> {
        return httpClient.send(apiURLRequestFactory.makeGetTokenUserRequest(token: token)).validate()
            .map { try self.apiURLRequestFactory.defaultJSONDecoder.decode(User.self, from: $0.data) }
    }
    
    // MARK: - Section Model Methods
    private func makeTableViewSectionModels() -> [UITableViewSectionModel] {
        var sectionModels = [UITableViewSectionModel]()
        if let constructedItemsModel = constructedItemsTableViewSectionModel { sectionModels.append(constructedItemsModel) }
        return sectionModels
    }
    
    private func makeConstructedItemsTableViewSectionModel(constructedItems: [ConstructedItem]) -> UITableViewSectionModel {
        return UITableViewSectionModel(cellViewModels: constructedItems.map { self.makeConstructedItemStackTableViewCellViewModel(constructedItem: $0) })
    }
    
    // MARK: - Cell View Model Methods
    private func makeConstructedItemStackTableViewCellViewModel(constructedItem: ConstructedItem) -> UITableViewCellViewModel {
        return ConstructedItemStackTableViewCellViewModel(
            identifier: CellIdentifier.itemStackTableViewCell.rawValue,
            height: .automatic,
            actions: constructedItemStackCellViewModelActions,
            configurationData: .init(
                nameText: constructedItem.name,
                descriptionText: constructedItem.description,
                priceText: constructedItem.totalPrice?.toUSDUnits().toPriceString(),
                quantityText: constructedItem.quantity?.toString(),
                constructedItemID: constructedItem.id
            )
        )
    }
}

extension OutstandingOrderViewModel {
    struct ConstructedItemStackTableViewCellViewModel: UITableViewCellViewModel {
        let identifier: String
        let height: UITableViewCellViewModelHeight
        let actions: [UITableViewCellAction: UITableViewCellActionHandler]
        let configurationData: ConfigurationData
        
        struct ConfigurationData {
            let nameText: String?
            let descriptionText: String?
            let priceText: String?
            let quantityText: String?
            let constructedItemID: ConstructedItem.ID
        }
    }
}

enum OutstandingOrderViewModelError: Error {
    case noOutstandingOrderFound
}
