//
//  OrdersViewModel.swift
//  Sammys Kitchen
//
//  Created by Natanel Niazoff on 5/31/18.
//  Copyright © 2018 Natanel Niazoff. All rights reserved.
//

import Foundation

enum OrdersViewControllerViewKey {
    case orders, foods
}

protocol OrdersViewModelDelegate: class {
    func updateUI()
    func didGetNewOrder()
}

private protocol Section {
    var key: SectionKey { get }
    var cellViewModels: [TableViewCellViewModel] { get }
}

private enum SectionKey {
    case scheduled([KitchenOrder])
    case today([KitchenOrder])
    case orderFoods([Food])
    
    var title: String? {
        switch self {
        case .scheduled: return "Scheduled"
        case .today: return "Today"
        default: return nil
        }
    }
    
    var kitchenOrders: [KitchenOrder]? {
        switch self {
        case .scheduled(let kitchenOrders), .today(let kitchenOrders):
            return kitchenOrders
        default: return nil
        }
    }
}

private struct KitchenOrdersSection: Section {
    let key: SectionKey
    var cellViewModels: [TableViewCellViewModel] {
        guard let kitchenOrders = key.kitchenOrders else { return [] }
        return kitchenOrders.map({ OrderTableViewCellViewModelFactory(kitchenOrder: $0).create() })
    }
}

private struct OrderFoodsSection: Section {
    let key: SectionKey
    var cellViewModels: [TableViewCellViewModel] {
        guard case .orderFoods(let orderFoods) = key else { return [] }
        return orderFoods.map({ FoodTableViewCellViewModelFactory(food: $0).create() })
    }
}

class OrdersViewModel {
    var viewKey: OrdersViewControllerViewKey = .orders
    weak var delegate: OrdersViewModelDelegate?
    let id = UUID().uuidString
    
    private var kitchenOrders: [KitchenOrder]? {
        didSet {
            delegate?.updateUI()
        }
    }
    
    private var scheduledKitchenOrders: [KitchenOrder] {
        guard let kitchenOrders = kitchenOrders else { return [] }
        return kitchenOrders.filter { $0.order.pickupDate != nil }.sorted { $0.order.date < $1.order.date }
    }
    
    private var todayKitchenOrders: [KitchenOrder] {
        guard let kitchenOrders = kitchenOrders else { return [] }
        return kitchenOrders.filter { $0.order.pickupDate == nil }.sorted { $0.order.date > $1.order.date }
    }
    
    var orderFoods: [Food]? {
        didSet {
            delegate?.updateUI()
        }
    }
    
    private var setTitle: String?
    
    var title: String? {
        get {
            let title: String
            switch UserDataStore.shared.observingDate {
            case .current: title = "Today"
            case .another(let date):
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE, MMM d"
                title = formatter.string(from: date)
            }
            return setTitle ?? title
        } set {
            setTitle = newValue
        }
    }
    
    private var sections: [Section]? {
        switch viewKey {
        case .orders:
            var sections = [Section]()
            if !scheduledKitchenOrders.isEmpty {
                sections.append(KitchenOrdersSection(key: .scheduled(scheduledKitchenOrders)))
            }
            if !todayKitchenOrders.isEmpty {
                sections.append(KitchenOrdersSection(key: .today(todayKitchenOrders)))
            }
            return sections.isEmpty ? nil : sections
        case .foods:
            guard let orderFoods = orderFoods else { return nil }
            return [OrderFoodsSection(key: .orderFoods(orderFoods))]
        }
    }
    
    var numberOfSections: Int {
        return sections?.count ?? 0
    }
    
    var dateButtonShouldHide: Bool {
        return viewKey == .foods
    }
    
    var datePickerDate: Date {
        return UserDataStore.shared.currentDateObserving
    }
    
    var datePickerMinDate: Date {
        return Date().addingTimeInterval(-Constants.week)
    }
    
    var datePickerMaxDate: Date {
        return Date().addingTimeInterval(Constants.week)
    }
    
    var todayButtonShouldHide: Bool {
        return isObservingToday
    }
    
    var nothingLabelText: String {
        return isObservingToday ? "Nothing\nYet" : "Nothing\nHere"
    }
    
    var isOrdersEmpty: Bool {
        return kitchenOrders?.isEmpty ?? true
    }
    
    var isObservingToday: Bool {
        return UserDataStore.shared.observingDate == .current
    }
    
    var lastObservingDate = UserDataStore.shared.observingDate
    
    var shouldHideSectionTitles: Bool {
        return scheduledKitchenOrders.isEmpty
    }
    
    private struct Constants {
        static let week: TimeInterval = 7 * 24 * 60 * 60
    }
    
    func handleViewDidAppear() {
        OrdersAPIClient.addObserver(self)
    }
    
    func handleViewDidDisappear() {
        OrdersAPIClient.removeObserver(self)
    }
    
    func numberOfRows(inSection section: Int) -> Int {
        return sections?[section].cellViewModels.count ?? 0
    }
    
    func cellViewModel(for indexPath: IndexPath) -> TableViewCellViewModel? {
        return sections?[indexPath.section].cellViewModels[indexPath.row]
    }
    
    func title(forSection section: Int) -> String? {
        return shouldHideSectionTitles ? nil : sections?[section].key.title
    }
    
    func orderTitle(for indexPath: IndexPath) -> String? {
        return sections?[indexPath.section].key.kitchenOrders?[indexPath.row].order.userName
    }
    
    /// Use when showing orders to get the foods for the given order's index path.
    func foods(for indexPath: IndexPath) -> [Food]? {
        return sections?[indexPath.section].key.kitchenOrders?[indexPath.row].order.foods[.salad]
    }
    
    /// Use when showing foods to get the food at the given index path.
    func food(for indexPath: IndexPath) -> Food? {
        return orderFoods?[indexPath.row]
    }
    
    func isDateCurrent(_ date: Date) -> Bool {
        let dateComponents: Set<Calendar.Component> = [.day, .month]
        return Calendar.current.dateComponents(dateComponents, from: date) == Calendar.current.dateComponents(dateComponents, from: Date())
    }
    
    func handleDatePickerValueChange(_ date: Date) {
        UserDataStore.shared.observingDate = isDateCurrent(date) ? .current : .another(date)
    }
}

extension OrdersViewModel: OrdersAPIObserver {
    func ordersValueDidChange(_ kitchenOrders: [KitchenOrder]) {
        if let currentKitchenOrders = self.kitchenOrders,
            kitchenOrders.count > currentKitchenOrders.count,
            isObservingToday && lastObservingDate == .current {
            delegate?.didGetNewOrder()
        }
        self.kitchenOrders = kitchenOrders
        lastObservingDate = UserDataStore.shared.observingDate
    }
}
