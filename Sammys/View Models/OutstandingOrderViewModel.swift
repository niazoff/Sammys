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
    
    // MARK: - View Settable Properties
    /// Required to be non-`nil` before beginning downloads.
    /// If not set, calling `beginDownloads()` will first attempt to set.
    var outstandingOrderID: OutstandingOrder.ID?
    
    /// Allowed to be `nil`. Use `beginUserIDDownload()` to attempt to set.
    /// Must be set to the outstanding order's user's ID before beginning downloads.
    /// If set and verifiable, calling `beginDownloads()` will set the
    /// outstanding order's user to the one specified if necessary.
    var userID: User.ID? {
        didSet { isUserIDSet.value = userID != nil }
    }
    
    var itemCellViewModelActions = [UITableViewCellAction: UITableViewCellActionHandler]()
    
    var errorHandler: (Error) -> Void = { _ in }
    
    // MARK: - View Gettable Properties
    var isUserSignedIn: Bool { return userAuthManager.isUserSignedIn }
    
    // MARK: - Dynamic Properties
    private(set) lazy var tableViewSectionModels = Dynamic(makeTableViewSectionModels())
    
    let taxPriceText: Dynamic<String?> = Dynamic(nil)
    let subtotalPriceText: Dynamic<String?> = Dynamic(nil)
    let isItemsEmpty: Dynamic<Bool?> = Dynamic(nil)
    
    private(set) lazy var isUserIDSet = Dynamic(userID != nil)
    
    let isLoading = Dynamic(false)
    
    // MARK: - Section Model Properties
    private var constructedItemsTableViewSectionModel: UITableViewSectionModel? {
        didSet { updateTableViewSectionModels() }
    }
    
    enum CellIdentifier: String {
        case itemTableViewCell
    }
    
    init(httpClient: HTTPClient = URLSession.shared,
         keyValueStore: KeyValueStore = UserDefaults.standard,
         userAuthManager: UserAuthManager = Auth.auth()) {
        self.httpClient = httpClient
        self.keyValueStore = keyValueStore
        self.userAuthManager = userAuthManager
    }
    
    // MARK: - Setup Methods
    private func setUp(forOutstandingOrderID outstandingOrderID: OutstandingOrder.ID?) {
        self.outstandingOrderID = outstandingOrderID
        keyValueStore.set(outstandingOrderID?.uuidString, forKey: KeyValueStoreKeys.currentOutstandingOrderID)
    }
    
    private func setUp(forOutstandingOrder outstandingOrder: OutstandingOrder?) {
        taxPriceText.value = outstandingOrder?.taxPrice?.toUSDUnits().toPriceString()
        subtotalPriceText.value = outstandingOrder?.totalPrice?.toUSDUnits().toPriceString()
    }
    
    private func setUp(for constructedItems: [ConstructedItem]) {
        constructedItemsTableViewSectionModel = makeConstructedItemsTableViewSectionModel(constructedItems: constructedItems)
        isItemsEmpty.value = constructedItems.isEmpty
    }
    
    private func updateTableViewSectionModels() {
        tableViewSectionModels.value = makeTableViewSectionModels()
    }
    
    // MARK: - Methods
    func clear() {
        setUp(forOutstandingOrderID: nil)
        setUp(forOutstandingOrder: nil)
        setUp(for: [ConstructedItem]())
    }
    
    // MARK: - Download Methods
    func beginDownloads() {
        isLoading.value = true
        makeDownloads()
            .ensure { self.isLoading.value = false }
            .catch(errorHandler)
    }
    
    func beginUpdateOutstandingOrderUserDownload(successHandler: @escaping () -> Void = {}) {
        isLoading.value = true
        _beginUpdateOutstandingOrderUserDownload()
            .ensure { self.isLoading.value = false }
            .done(successHandler)
            .catch(errorHandler)
    }
    
    func beginUpdateConstructedItemQuantityDownload(constructedItemID: ConstructedItem.ID, quantity: Int) {
        isLoading.value = true
        makeUpdateConstructedItemQuantityDownload(constructedItemID: constructedItemID, quantity: quantity)
            .then { when(fulfilled: [
                self.beginOutstandingOrderConstructedItemsDownload(),
                self.beginOutstandingOrderDownload()
            ]) }
            .ensure { self.isLoading.value = false }
            .catch(errorHandler)
    }
    
    func beginUserIDDownload(successHandler: @escaping () -> Void = {}) {
        isLoading.value = true
        userAuthManager.getCurrentUserIDToken()
            .then { self.getTokenUser(token: $0) }
            .ensure { self.isLoading.value = false }
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
    
    private func _beginUpdateOutstandingOrderUserDownload() -> Promise<Void> {
        return userAuthManager.getCurrentUserIDToken().then { token in
            self.getOutstandingOrder(token: token).then { outstandingOrder -> Promise<OutstandingOrder> in
                outstandingOrder.userID = self.userID
                return self.updateOutstandingOrder(data: outstandingOrder, token: token)
            }
        }.done(setUp)
    }
    
    private func makeDownloads() -> Promise<Void> {
        var downloads = [
            beginOutstandingOrderDownload,
            beginOutstandingOrderConstructedItemsDownload
        ]
        if userID != nil { downloads.append(_beginUpdateOutstandingOrderUserDownload) }
        if outstandingOrderID == nil {
            return beginOutstandingOrderIDDownload()
                .then { when(fulfilled: downloads.map { $0() }) }
        } else { return when(fulfilled: downloads.map { $0() }) }
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
    
    private func makeOutstandingOrderDownload() -> Promise<OutstandingOrder> {
        if userID != nil {
            return userAuthManager.getCurrentUserIDToken()
                .then { self.getOutstandingOrder(token: $0) }
        } else { return getOutstandingOrder() }
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
    
    private func updateOutstandingOrder(data: OutstandingOrder, token: JWT) -> Promise<OutstandingOrder> {
        do {
            return try httpClient.send(apiURLRequestFactory.makeUpdateOutstandingOrderRequest(id: outstandingOrderID ?? preconditionFailure(), data: data, token: token)).validate()
                .map { try self.apiURLRequestFactory.defaultJSONDecoder.decode(OutstandingOrder.self, from: $0.data) }
        } catch { preconditionFailure(error.localizedDescription) }
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
    private func makeConstructedItemsTableViewSectionModel(constructedItems: [ConstructedItem]) -> UITableViewSectionModel {
        return UITableViewSectionModel(cellViewModels: constructedItems.map { self.makeItemTableViewCellViewModel(constructedItem: $0) })
    }
    
    private func makeTableViewSectionModels() -> [UITableViewSectionModel] {
        var sectionModels = [UITableViewSectionModel]()
        if let constructedItemsModel = constructedItemsTableViewSectionModel { sectionModels.append(constructedItemsModel) }
        return sectionModels
    }
    
    // MARK: - Cell View Model Methods
    private func makeItemTableViewCellViewModel(constructedItem: ConstructedItem) -> UITableViewCellViewModel {
        return ItemTableViewCellViewModel(
            identifier: CellIdentifier.itemTableViewCell.rawValue,
            height: .automatic,
            actions: itemCellViewModelActions,
            configurationData: .init(
                titleText: constructedItem.name,
                descriptionText: constructedItem.description,
                priceText: constructedItem.totalPrice?.toUSDUnits().toPriceString(),
                quantityText: constructedItem.quantity?.toString(),
                constructedItemID: constructedItem.id
            )
        )
    }
}

extension OutstandingOrderViewModel {
    struct ItemTableViewCellViewModel: UITableViewCellViewModel {
        let identifier: String
        let height: UITableViewCellViewModelHeight
        let isSelectable = false
        let actions: [UITableViewCellAction: UITableViewCellActionHandler]
        let configurationData: ConfigurationData
        
        struct ConfigurationData {
            let titleText: String?
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
