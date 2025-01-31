//
//  CheckoutViewModel.swift
//  Sammys
//
//  Created by Natanel Niazoff on 3/31/19.
//  Copyright © 2019 Natanel Niazoff. All rights reserved.
//

import Foundation
import PromiseKit
import FirebaseAuth
import PassKit
import SquareInAppPaymentsSDK

class CheckoutViewModel {
    private let calendar = Calendar.current
    
    private let apiURLRequestFactory = APIURLRequestFactory()
    
    private var outstandingOrder: OutstandingOrder?
    private var offers: [Offer]?
    
    private let pickupDateTableViewCellViewModelDetailTextDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = Constants.pickupDateTableViewCellViewModelDetailTextDateFormat
        return formatter
    }()
    
    // MARK: - Dependencies
    var httpClient: HTTPClient
    var userAuthManager: UserAuthManager
    
    // MARK: - Section Model Properties
    private var outstandingOrderDetailsTableViewSectionModel: UITableViewSectionModel? {
        didSet { updateTableViewSectionModels() }
    }
    
    private var offersTableViewSectionModel: UITableViewSectionModel? {
        didSet { updateTableViewSectionModels() }
    }
    
    private var totalTableViewSectionModel: UITableViewSectionModel? {
        didSet { updateTableViewSectionModels() }
    }
    
    // MARK: - View Settable Properties
    /// Required to be non-`nil` before beginning downloads.
    var outstandingOrderID: OutstandingOrder.ID?
    
    /// Required to be non-`nil` before beginning downloads.
    var userID: User.ID?
    
    var paymentMethodTableViewCellViewModelActions = [UITableViewCellAction: UITableViewCellActionHandler]() {
        didSet { updateOutstandingOrderDetailsTableViewSectionModel() }
    }
    
    var pickupDateTableViewCellViewModelActions = [UITableViewCellAction: UITableViewCellActionHandler]() {
        didSet { updateOutstandingOrderDetailsTableViewSectionModel() }
    }
    
    var noteTableViewCellViewModelActions = [UITableViewCellAction: UITableViewCellActionHandler]() {
        didSet { updateOutstandingOrderDetailsTableViewSectionModel() }
    }
    
    var offerTableViewCellViewModelActions = [UITableViewCellAction: UITableViewCellActionHandler]() {
        didSet { updateOffersTableViewSectionModel() }
    }
    
    var addOfferButtonTableViewCellViewModelActions = [UITableViewCellAction: UITableViewCellActionHandler]() {
        didSet { updateOffersTableViewSectionModel() }
    }
    
    var totalTableViewCellViewModelActions = [UITableViewCellAction: UITableViewCellActionHandler]() {
        didSet { updateTotalTableViewSectionModel() }
    }
    
    var errorHandler: (Error) -> Void = { _ in }
    
    // MARK: - Dynamic Properties
    private(set) lazy var tableViewSectionModels = Dynamic(makeTableViewSectionModels())
    
    let paymentMethod: Dynamic<PaymentMethodsViewModel.PaymentMethod?> = Dynamic(nil)
    
    let pickupDate: Dynamic<Date?> = Dynamic(nil)
    
    let minimumPickupDate: Dynamic<Date?> = Dynamic(nil)
    let maximumPickupDate: Dynamic<Date?> = Dynamic(nil)
    
    let isLoading = Dynamic(false)
    
    enum CellIdentifier: String {
        case tableViewCell
        case subtitleTableViewCell
        case textViewTableViewCell
        case totalTableViewCell
    }
    
    private struct Constants {
        static let totalTableViewCellViewModelHeight = Double(100)
        
        static let paymentMethodTableViewCellViewModelHeight = Double(60)
        static let paymentMethodTableViewCellViewModelDefaultDetailText = "Choose a payment method..."
        
        static let pickupDateTableViewCellViewModelHeight = Double(60)
        static let pickupDateTableViewCellViewModelDefaultDetailText = "ASAP"
        static let pickupDateTableViewCellViewModelDetailTextDateFormat = "h:mm a"
        
        static let noteTableViewCellViewModelPlaceholderText = "Add a note for the kitchen..."
        
        static let offerTableViewCellViewModelHeight = Double(60)
        
        static let addOfferButtonTableViewCellViewModelHeight = Double(60)
        static let addOfferButtonTableViewCellViewModelText = "Add Discount Code"
        
        static let paymentSummaryItemLabel = "Sammy's"
    }
    
    init(httpClient: HTTPClient = URLSession.shared,
         userAuthManager: UserAuthManager = Auth.auth()) {
        self.httpClient = httpClient
        self.userAuthManager = userAuthManager
        setUp()
    }
    
    // MARK: - Setup Methods
    private func setUp() {
        paymentMethod.bind { _ in self.updateOutstandingOrderDetailsTableViewSectionModel() }
        pickupDate.bind { _ in self.updateOutstandingOrderDetailsTableViewSectionModel() }
        if SQIPInAppPaymentsSDK.canUseApplePay {
            paymentMethod.value = .applePay
        }
    }
    
    private func setUp(for outstandingOrder: OutstandingOrder) {
        self.outstandingOrder = outstandingOrder
        pickupDate.value = outstandingOrder.preparedForDate
        updateOutstandingOrderDetailsTableViewSectionModel()
        updateTotalTableViewSectionModel()
    }
    
    private func setUp(for offers: [Offer]) {
        self.offers = offers
        updateOffersTableViewSectionModel()
    }
    
    private func setUp(for storeDateHours: StoreDateHours) {
        let currentDate = Date()
        if let openingDate = storeDateHours.openingDate,
            let minimumPickupDate = max(currentDate, openingDate).roundedToNextQuarterHour(calendar: calendar) {
            self.minimumPickupDate.value = minimumPickupDate
        }
        maximumPickupDate.value = storeDateHours.closingDate
    }
    
    private func updateOutstandingOrderDetailsTableViewSectionModel() {
        guard let outstandingOrder = outstandingOrder else {
            totalTableViewSectionModel = nil; return
        }
        outstandingOrderDetailsTableViewSectionModel = makeOutstandingOrderDetailsTableViewSectionModel(outstandingOrder: outstandingOrder)
    }
    
    private func updateOffersTableViewSectionModel() {
        guard let offers = offers else { offersTableViewSectionModel = nil; return }
        offersTableViewSectionModel = makeOffersTableViewSectionModel(offers: offers)
    }
    
    private func updateTotalTableViewSectionModel() {
        guard let outstandingOrder = outstandingOrder else {
            totalTableViewSectionModel = nil; return
        }
        totalTableViewSectionModel = makeTotalTableViewSectionModel(outstandingOrder: outstandingOrder)
    }
    
    private func updateTableViewSectionModels() {
        tableViewSectionModels.value = makeTableViewSectionModels()
    }
    
    // MARK: - Download Methods
    func beginDownloads() {
        isLoading.value = true
        when(fulfilled: [
            beginOutstandingOrderDownload(),
            beginOutstandingOrderOffersDownload(),
            _beginStoreHoursDownload()
        ]).ensure { self.isLoading.value = false }
            .catch { self.errorHandler($0) }
    }
    
    func beginStoreHoursDownload() {
        _beginStoreHoursDownload()
            .catch { self.errorHandler($0) }
    }
    
    func beginUpdateOutstandingOrderDownload(preparedForDate: Date?) {
        let currentDate = Date()
        if let date = preparedForDate {
            guard date > currentDate
                else { errorHandler(CheckoutViewModelError.invalidPickupDate); return }
        }
        isLoading.value = true
        userAuthManager.getCurrentUserIDToken()
            .then { self.getOutstandingOrder(token: $0) }.get { outstandingOrder in
                outstandingOrder.preparedForDate = preparedForDate
            }.then(beginUpdateOutstandingOrder)
            .ensure { self.isLoading.value = false }
            .catch { self.errorHandler($0) }
    }
    
    func beginUpdateOutstandingOrderDownload(note: String?) {
        userAuthManager.getCurrentUserIDToken().then { token in
            self.getOutstandingOrder(token: token).map { ($0, token) }
        }.get { outstandingOrder, _ in
            outstandingOrder.note = note
        }.then { self.updateOutstandingOrder(data: $0, token: $1) }
        .catch(errorHandler)
    }
    
    func beginAddOutstandingOrderOfferDownload(code: String) {
        isLoading.value = true
        getOffer(code: code).then { offer in
            self.userAuthManager.getCurrentUserIDToken()
                .then { self.addOutstandingOrderOffer(id: offer.id, token: $0) }.then { outstandingOrder in
                    self.beginOutstandingOrderOffersDownload().map { outstandingOrder }
                }
        }.ensure { self.isLoading.value = false }
            .done(setUp).catch(errorHandler)
    }
    
    func beginPaymentRequestDownload(successHandler: @escaping (PKPaymentRequest) -> Void = { _ in }) {
        isLoading.value = true
        userAuthManager.getCurrentUserIDToken()
            .then(getOutstandingOrder)
            .ensure { self.isLoading.value = false }
            .map(makePaymentRequest)
            .done(successHandler)
            .catch(errorHandler)
    }
    
    func beginCreatePurchasedOrderDownload(customerCardID: String, successHandler: @escaping (PurchasedOrder.ID) -> Void = { _ in }) {
        isLoading.value = true
        beginCreatePurchasedOrderDownload(cardNonce: nil, customerCardID: customerCardID)
            .ensure { self.isLoading.value = false }
            .done { successHandler($0.id) }
            .catch(errorHandler)
    }
    
    func beginCreatePurchasedOrderDownload(payment: PKPayment, completionHandler: @escaping (Result<PurchasedOrder.ID>) -> Void = { _ in }) {
        isLoading.value = true
        beginApplePayNonceDownload(payment: payment)
            .then { self.beginCreatePurchasedOrderDownload(cardNonce: $0.nonce, customerCardID: nil) }
            .ensure { self.isLoading.value = false }
            .done { completionHandler(.fulfilled($0.id)) }
            .catch { completionHandler(.rejected($0)) }
    }
    
    private func beginOutstandingOrderDownload() -> Promise<Void> {
        return userAuthManager.getCurrentUserIDToken()
            .then { self.getOutstandingOrder(token: $0) }.done(setUp)
    }
    
    private func beginOutstandingOrderOffersDownload() -> Promise<Void> {
        return userAuthManager.getCurrentUserIDToken()
            .then { self.getOutstandingOrderOffers(token: $0) }.done(setUp)
    }
    
    private func _beginStoreHoursDownload() -> Promise<Void> {
        return getStoreHours().done(setUp)
    }
    
    private func beginUpdateOutstandingOrder(data: OutstandingOrder) -> Promise<Void> {
        return userAuthManager.getCurrentUserIDToken()
            .then { self.updateOutstandingOrder(data: data, token: $0) }.done(setUp)
    }
    
    private func beginApplePayNonceDownload(payment: PKPayment) -> Promise<SQIPCardDetails> {
        return Promise { resolver in
            SQIPApplePayNonceRequest(payment: payment).perform { details, error in
                if let details = details { resolver.fulfill(details) }
                else if let error = error { resolver.reject(error) }
            }
        }
    }
    
    private func beginCreatePurchasedOrderDownload(cardNonce: String?, customerCardID: String?) -> Promise<PurchasedOrder> {
        return userAuthManager.getCurrentUserIDToken()
            .then { self.createPurchasedOrder(data: .init(outstandingOrderID: self.outstandingOrderID ?? preconditionFailure(), cardNonce: cardNonce, customerCardID: customerCardID), token: $0) }
    }
    
    private func getOutstandingOrder(token: JWT) -> Promise<OutstandingOrder> {
        return httpClient.send(apiURLRequestFactory.makeGetOutstandingOrderRequest(id: outstandingOrderID ?? preconditionFailure(), token: token)).validate()
            .map { try self.apiURLRequestFactory.defaultJSONDecoder.decode(OutstandingOrder.self, from: $0.data) }
    }
    
    private func getOutstandingOrderOffers(token: JWT) -> Promise<[Offer]> {
        return httpClient.send(apiURLRequestFactory.makeGetOutstandingOrderOffersRequest(id: outstandingOrderID ?? preconditionFailure(), token: token)).validate()
            .map { try self.apiURLRequestFactory.defaultJSONDecoder.decode([Offer].self, from: $0.data) }
    }
    
    private func getStoreHours() -> Promise<StoreDateHours> {
        return httpClient.send(apiURLRequestFactory.makeStoreHoursRequest()).validate()
            .map { try self.apiURLRequestFactory.defaultJSONDecoder.decode(StoreDateHours.self, from: $0.data) }
    }
    
    private func updateOutstandingOrder(data: OutstandingOrder, token: JWT) -> Promise<OutstandingOrder> {
        do {
            return try httpClient.send(apiURLRequestFactory.makeUpdateOutstandingOrderRequest(id: outstandingOrderID ?? preconditionFailure(), data: data, token: token)).validate()
                .map { try self.apiURLRequestFactory.defaultJSONDecoder.decode(OutstandingOrder.self, from: $0.data) }
        } catch { preconditionFailure(error.localizedDescription) }
    }
    
    private func getOffer(code: Offer.Code) -> Promise<Offer> {
        return httpClient.send(apiURLRequestFactory.makeGetOfferRequest(code: code)).validate()
            .map { try self.apiURLRequestFactory.defaultJSONDecoder.decode(Offer.self, from: $0.data) }
    }
    
    private func addOutstandingOrderOffer(id: Offer.ID, token: JWT) -> Promise<OutstandingOrder> {
        return httpClient.send(apiURLRequestFactory.makeAddOutstandingOrderOfferRequest(outstandingOrderID: outstandingOrderID ?? preconditionFailure(), offerID: id, token: token)).validate()
            .map { try self.apiURLRequestFactory.defaultJSONDecoder.decode(OutstandingOrder.self, from: $0.data) }
    }
    
    private func createPurchasedOrder(data: CreateUserPurchasedOrderRequestData, token: JWT) -> Promise<PurchasedOrder> {
        do {
            return try httpClient.send(apiURLRequestFactory.makeCreateUserPurchasedOrdersRequest(id: userID ?? preconditionFailure(), data: data, token: token)).validate()
                .map { try self.apiURLRequestFactory.defaultJSONDecoder.decode(PurchasedOrder.self, from: $0.data) }
        } catch { preconditionFailure(error.localizedDescription) }
    }
    
    // MARK: - Factory Methods
    func makeOutstandingOrderTotalPrice(outstandingOrder: OutstandingOrder) -> Int? {
        guard let subtotalPrice = outstandingOrder.totalPrice,
            let taxPrice = outstandingOrder.taxPrice else { return nil }
        return subtotalPrice + taxPrice
    }
    
    func makePaymentRequest(outstandingOrder: OutstandingOrder) -> PKPaymentRequest {
        let request = PKPaymentRequest.squarePaymentRequest(
            merchantIdentifier: AppConstants.ApplePay.merchantID,
            countryCode: AppConstants.ApplePay.countryCode,
            currencyCode: AppConstants.ApplePay.currencyCode
        )
        request.paymentSummaryItems = [PKPaymentSummaryItem(label: Constants.paymentSummaryItemLabel, amount: NSDecimalNumber(value: (makeOutstandingOrderTotalPrice(outstandingOrder: outstandingOrder) ?? 0).toUSDUnits()))]
        return request
    }
    
    // MARK: - Section Model Methods
    private func makeOutstandingOrderDetailsTableViewSectionModel(outstandingOrder: OutstandingOrder) -> UITableViewSectionModel {
        return UITableViewSectionModel(cellViewModels: [
            makePaymentMethodTableViewCellViewModel(),
            makePickupDateTableViewCellViewModel(),
            makeNoteTableViewCellViewModel(outstandingOrder: outstandingOrder)
        ])
    }
    
    private func makeOffersTableViewSectionModel(offers: [Offer]) -> UITableViewSectionModel {
        let offerCellViewModels = offers.map(makeOfferTableViewCellViewModel)
        return UITableViewSectionModel(cellViewModels: offerCellViewModels.isEmpty ? [makeAddOfferButtonTableViewCellViewModel()] : offerCellViewModels)
    }
    
    private func makeTotalTableViewSectionModel(outstandingOrder: OutstandingOrder) -> UITableViewSectionModel {
        return UITableViewSectionModel(cellViewModels: [makeTotalTableViewCellViewModel(outstandingOrder: outstandingOrder)])
    }
    
    private func makeTableViewSectionModels() -> [UITableViewSectionModel] {
        var sectionModels = [UITableViewSectionModel]()
        if let outstandingOrderDetailsModel = outstandingOrderDetailsTableViewSectionModel {
            sectionModels.append(outstandingOrderDetailsModel)
        }
        if let offersModel = offersTableViewSectionModel {
            sectionModels.append(offersModel)
        }
        if let totalModel = totalTableViewSectionModel {
            sectionModels.append(totalModel)
        }
        return sectionModels
    }
    
    // MARK: - Cell View Model Methods
    private func makePaymentMethodTableViewCellViewModel() -> PaymentMethodTableViewCellViewModel {
        return PaymentMethodTableViewCellViewModel(
            identifier: CellIdentifier.subtitleTableViewCell.rawValue,
            height: .fixed(Constants.paymentMethodTableViewCellViewModelHeight),
            actions: paymentMethodTableViewCellViewModelActions,
            configurationData: .init(detailText: paymentMethod.value?.name ?? Constants.paymentMethodTableViewCellViewModelDefaultDetailText))
    }
    
    private func makePickupDateTableViewCellViewModel() -> PickupDateTableViewCellViewModel {
        let detailText: String
        if let date = pickupDate.value { detailText = pickupDateTableViewCellViewModelDetailTextDateFormatter.string(from: date) }
        else { detailText = Constants.pickupDateTableViewCellViewModelDefaultDetailText }
        
        return PickupDateTableViewCellViewModel(
            identifier: CellIdentifier.subtitleTableViewCell.rawValue,
            height: .fixed(Constants.pickupDateTableViewCellViewModelHeight),
            actions: pickupDateTableViewCellViewModelActions,
            configurationData: .init(detailText: detailText)
        )
    }
    
    private func makeNoteTableViewCellViewModel(outstandingOrder: OutstandingOrder) -> NoteTableViewCellViewModel {
        return NoteTableViewCellViewModel(
            identifier: CellIdentifier.textViewTableViewCell.rawValue,
            height: .automatic,
            actions: noteTableViewCellViewModelActions,
            configurationData: .init(placeholderText: Constants.noteTableViewCellViewModelPlaceholderText, text: outstandingOrder.note)
        )
    }
    
    private func makeOfferTableViewCellViewModel(offer: Offer) -> OfferTableViewCellViewModel {
        return OfferTableViewCellViewModel(
            identifier: CellIdentifier.tableViewCell.rawValue,
            height: .fixed(Constants.offerTableViewCellViewModelHeight),
            actions: offerTableViewCellViewModelActions,
            configurationData: .init(text: offer.name)
        )
    }
    
    private func makeAddOfferButtonTableViewCellViewModel() -> AddOfferButtonTableViewCellViewModel {
        return AddOfferButtonTableViewCellViewModel(
            identifier: CellIdentifier.tableViewCell.rawValue,
            height: .fixed(Constants.addOfferButtonTableViewCellViewModelHeight),
            actions: addOfferButtonTableViewCellViewModelActions,
            configurationData: .init(title: Constants.addOfferButtonTableViewCellViewModelText)
        )
    }
    
    private func makeTotalTableViewCellViewModel(outstandingOrder: OutstandingOrder) -> TotalTableViewCellViewModel {
        return TotalTableViewCellViewModel(
            identifier: CellIdentifier.totalTableViewCell.rawValue,
            height: .fixed(Constants.totalTableViewCellViewModelHeight),
            actions: totalTableViewCellViewModelActions,
            configurationData: .init(subtotalText: outstandingOrder.totalPrice?.toUSDUnits().toPriceString(), taxText: outstandingOrder.taxPrice?.toUSDUnits().toPriceString(), totalText: makeOutstandingOrderTotalPrice(outstandingOrder: outstandingOrder)?.toUSDUnits().toPriceString())
        )
    }
}

extension CheckoutViewModel {
    struct PaymentMethodTableViewCellViewModel: UITableViewCellViewModel {
        let identifier: String
        let height: UITableViewCellViewModelHeight
        let actions: [UITableViewCellAction: UITableViewCellActionHandler]
        let configurationData: ConfigurationData
        
        struct ConfigurationData {
            let detailText: String?
        }
    }
}

extension CheckoutViewModel {
    struct PickupDateTableViewCellViewModel: UITableViewCellViewModel {
        let identifier: String
        let height: UITableViewCellViewModelHeight
        let actions: [UITableViewCellAction: UITableViewCellActionHandler]
        
        let configurationData: ConfigurationData
        
        struct ConfigurationData {
            let detailText: String
        }
    }
}

extension CheckoutViewModel {
    struct NoteTableViewCellViewModel: UITableViewCellViewModel {
        let identifier: String
        let height: UITableViewCellViewModelHeight
        let isSelectable: Bool = false
        let actions: [UITableViewCellAction: UITableViewCellActionHandler]
        
        let configurationData: ConfigurationData
        
        struct ConfigurationData {
            let placeholderText: String
            let text: String?
        }
    }
}

extension CheckoutViewModel {
    struct OfferTableViewCellViewModel: UITableViewCellViewModel {
        let identifier: String
        let height: UITableViewCellViewModelHeight
        let actions: [UITableViewCellAction: UITableViewCellActionHandler]
        
        let configurationData: ConfigurationData
        
        struct ConfigurationData {
            let text: String
        }
    }
}

extension CheckoutViewModel {
    struct AddOfferButtonTableViewCellViewModel: UITableViewCellViewModel {
        let identifier: String
        let height: UITableViewCellViewModelHeight
        let actions: [UITableViewCellAction: UITableViewCellActionHandler]
        
        let configurationData: ConfigurationData
        
        struct ConfigurationData {
            let title: String
        }
    }
}

extension CheckoutViewModel {
    struct TotalTableViewCellViewModel: UITableViewCellViewModel {
        let identifier: String
        let height: UITableViewCellViewModelHeight
        let isSelectable = false
        let actions: [UITableViewCellAction: UITableViewCellActionHandler]
        
        let configurationData: ConfigurationData
        
        struct ConfigurationData {
            let subtotalText: String?
            let taxText: String?
            let totalText: String?
        }
    }
}

enum CheckoutViewModelError: Error {
    case invalidPickupDate
}
