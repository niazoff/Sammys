//
//  OrdersAPIClient.swift
//  Sammys
//
//  Created by Natanel Niazoff on 5/15/18.
//  Copyright © 2018 Natanel Niazoff. All rights reserved.
//

import Foundation
import Firebase
import FirebaseDatabase
import CodableFirebase

protocol PathStringRepresentable: CustomStringConvertible {
    var pathString: String { get }
}

extension PathStringRepresentable {
    var description: String {
        return pathString
    }
}

enum FirebasePath: String, PathStringRepresentable {
    case develop, live, orders, numberCounter, order, kitchen, isCompleted, isInProgress, calendarDate, userID
    
    var pathString: String {
        return rawValue
    }
}

protocol OrdersAPIObserver {
    /// A unique id to identify the specific observer. Primarily used to remove the observer from observing.
    var id: String { get }
    
    func ordersValueDidChange(_ kitchenOrders: [KitchenOrder])
}

/// A singleton class that stores observers to `OrdersAPIClient`.
private class OrdersAPIObservers {
    /// The shared singleton property.
    static let shared = OrdersAPIObservers()
    
    /// The array of observers.
    var observers = [OrdersAPIObserver]()
    
    private init() {}
}

struct OrdersAPIClient {
    /// The shared Firebase database reference.
    private static var database: DatabaseReference {
        let database =  Database.database().reference()
        return environment.isLive ? database.child(.live) : database.child(.develop)
    }
    
    // MARK: - Observers
    private static var observers: [OrdersAPIObserver] {
        get {
            return OrdersAPIObservers.shared.observers
        } set {
            OrdersAPIObservers.shared.observers = newValue
        }
    }
    
    fileprivate static var calendarDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yyyy"
        return formatter
    }
    
    private static var firebaseEncoder: FirebaseEncoder {
        let encoder = FirebaseEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
    
    private static var firebaseDecoder: FirebaseDecoder {
        let decoder = FirebaseDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
    
    enum APIResult<T> {
        case success(T)
        case failure(Error)
    }
    
    static func addObserver(_ observer: OrdersAPIObserver) {
        observers.append(observer)
    }
    
    static func removeObserver(_ observer: OrdersAPIObserver) {
        // Filter observer array to disclude the given observer by its unique id.
        observers = observers.filter { $0.id != observer.id }
    }
    
    private static func ordersReference(for date: Date) -> DatabaseQuery {
        return database.ordersQueryEqual(to: date)
    }
    
    static func fetchNewOrderNumber(completed: @escaping (Int) -> Void) {
        database.child(.orders, .numberCounter).runTransactionBlock({ currentData in
            // If the counter doesn't exist...
            guard let value = currentData.value as? Int else {
                // ...set the counter to 1.
                currentData.value = 1
                return TransactionResult.success(withValue: currentData)
            }
            // Otherwise increment the value by 1.
            currentData.value = value + 1
            return TransactionResult.success(withValue: currentData)
        }) { error, committed, snapshot in
            if committed {
                guard let count = snapshot?.value as? Int else { return }
                completed(count)
            }
        }
    }
    
    static func startOrdersValueChangeObserver(for date: Date) { 
        ordersReference(for: date).observe(.value) { snapshot in
            guard snapshot.exists() else {
                observers.forEach { $0.ordersValueDidChange([]) }
                return
            }
            var kitchenOrders = [KitchenOrder]()
            for orderSnapshot in snapshot.children.allObjects as! [DataSnapshot] {
                let kitchenSnapshot = orderSnapshot.childSnapshot(forPath: FirebasePath.kitchen.rawValue)
                guard let orderData = orderSnapshot.childSnapshot(forPath: FirebasePath.order.rawValue).value,
                    let isInProgress = kitchenSnapshot.childSnapshot(forPath: FirebasePath.isInProgress.rawValue).value as? Bool,
                    let isCompleted = kitchenSnapshot.childSnapshot(forPath: FirebasePath.isCompleted.rawValue).value as? Bool else { continue }
                do {
                    let order = try firebaseDecoder.decode(Order.self, from: orderData)
                    kitchenOrders.append(KitchenOrder(order: order, isInProgress: isInProgress, isCompleted: isCompleted))
                } catch {
                    print(error)
                }
            }
            observers.forEach { $0.ordersValueDidChange(kitchenOrders) }
        }
    }
    
    static func removeAllOrdersObservers(for date: Date) {
        ordersReference(for: date).removeAllObservers()
    }
    
    private static func kitchenDictionary(for order: Order) -> [String : Any] {
        let calendarDateString = calendarDateFormatter.string(from: order.pickupDate ?? order.date)
        return [
            FirebasePath.calendarDate.rawValue: calendarDateString,
            FirebasePath.isInProgress.rawValue: false,
            FirebasePath.isCompleted.rawValue: false
        ]
    }
    
    private static func orderDictionary(for order: Order) -> [String : Any]? {
        do {
            let orderData = try firebaseEncoder.encode(order)
            return [
                FirebasePath.order.rawValue: orderData,
                FirebasePath.kitchen.rawValue: kitchenDictionary(for: order)
            ]
        } catch {
            print(error)
            return nil
        }
    }
    
    static func add(_ order: Order) {
        guard let orderDictionary = orderDictionary(for: order) else { return }
        database.child(.orders).child(order.number).setValue(orderDictionary)
    }
}

private extension DatabaseReference {
    func ordersQueryEqual(to date: Date) -> DatabaseQuery {
        return child(.orders)
            .queryOrdered(byChild: .kitchen, .calendarDate)
            .queryEqual(toValue: OrdersAPIClient.calendarDateFormatter.string(from: date))
    }
}

extension DatabaseReference {
    func child(_ path: [PathStringRepresentable]) -> DatabaseReference {
        guard let firstPath = path.first else { fatalError() }
        var finalChild = child(firstPath.pathString)
        path.dropFirst().forEach { finalChild = finalChild.child($0.pathString) }
        return finalChild
    }
    
    func child(_ path: PathStringRepresentable...) -> DatabaseReference {
        return child(path)
    }
    
    func child(_ path: FirebasePath...) -> DatabaseReference {
        return child(path)
    }
}

extension DatabaseQuery {
    func queryOrdered(byChild path: [PathStringRepresentable]) -> DatabaseQuery {
        guard let firstPath = path.first else { fatalError() }
        var pathString = firstPath.pathString
        path.dropFirst().forEach { pathString += "/\($0)" }
        return queryOrdered(byChild: pathString)
    }
    
    func queryOrdered(byChild path: PathStringRepresentable...) -> DatabaseQuery {
        return queryOrdered(byChild: path)
    }
    
    func queryOrdered(byChild path: FirebasePath...) -> DatabaseQuery {
        return queryOrdered(byChild: path)
    }
}
