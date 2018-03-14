//
//  PayAPIClient.swift
//  Sammys
//
//  Created by Natanel Niazoff on 1/14/18.
//  Copyright © 2018 Natanel Niazoff. All rights reserved.
//

import Foundation
import Alamofire
import Stripe

/// A type that represents a Stripe customer.
struct Customer: Decodable {
    let id: String
    let email: String
}

/// A client to make calls to the payment 💰 API 🏭.
struct PayAPIClient {
    typealias JSON = [String : Any]
    
    static let baseURL = "https://sammysapp.herokuapp.com"
    
    /**
     A type returned by the charge API call.
     - `success`: ended with success.
     - `failure`
     */
    enum ChargeAPIResult {
        case success
        case failure(message: String)
    }
    
    /**
     A type returned by the create ephemeral key API call.
     - `success`: ended with success.
     - `error`
     */
    enum CreateCustomerAPIResult {
        case success(Customer)
        case failure(message: String)
    }
    
    /**
     A type returned by the create customer API call.
     - `success`: ended with success.
     - `failure`
     */
    enum CreateEphemeralKeyAPIResult {
        case success(JSON)
        case failure(Error)
    }
    
    /// A collection of parameter symbols to send the API.
    struct Symbols {
        static let email = "email"
        static let customerID = "customer_id"
        static let tokenID = "token_id"
        static let amount = "amount"
        static let apiVersion = "api_version"
    }
    
    /**
     Charges the given customer ID for the given amount.
     - Parameter customerID: The customer ID to charge.
     - Parameter amount: The amount to charge the customer. Represented in cents.
     - Parameter completed: The closure to call upon completion.
     */
    static func charge(_ customerID: String, amount: Int, completed: ((_ result: ChargeAPIResult) -> Void)? = nil) {
        let parameters: Parameters = [Symbols.customerID: customerID, Symbols.amount: amount]
        Alamofire.request(baseURL.chargeCustomer, method: .post, parameters: parameters)
            .validate(statusCode: 200..<300)
            .responseJSON { response in
            if response.value != nil {
                completed?(.success)
            } else if let error = response.error {
                completed?(.failure(message: error.localizedDescription))
            }
        }
    }
    
    /**
     Charges the a guest customer with the given token ID for the given amount.
     - Parameter tokenID: The token ID to charge.
     - Parameter amount: The amount to charge the customer. Represented in cents.
     - Parameter completed: The closure to call upon completion.
     */
    static func chargeGuest(_ tokenID: String, amount: Int, completed: ((_ result: ChargeAPIResult) -> Void)? = nil) {
        let parameters: Parameters = [Symbols.tokenID: tokenID, Symbols.amount: amount]
        Alamofire.request(baseURL.chargeGuestCustomer, method: .post, parameters: parameters)
            .validate(statusCode: 200..<300)
            .responseJSON { response in
                if response.value != nil {
                    completed?(.success)
                } else if let error = response.error {
                    completed?(.failure(message: error.localizedDescription))
                }
        }
    }
    
    /**
     Creates a new customer with the given parameter data by the Stripe SDK.
     - Parameter parameters: The parameter data to associate with the customer. Use `Symbol` type properties for parameter names.
     - Parameter completed: The closure to call upon completion.
     */
    static func createNewCustomer(parameters: Parameters = [:], completed: ((_ result: CreateCustomerAPIResult) -> Void)? = nil) {
        Alamofire.request(baseURL.newCustomer, method: .post, parameters: parameters)
            .validate(statusCode: 200..<300)
            .responseJSON { response in
            if let jsonData = response.data {
                let decoder = JSONDecoder()
                if let customer = try? decoder.decode(Customer.self, from: jsonData) {
                    completed?(.success(customer))
                }
            } else if let error = response.error {
                completed?(.failure(message: error.localizedDescription))
            }
        }
    }
    
    /**
     Creates an ephemeral key from the given customer ID and the Stripe API version.
     - Parameter customerID: The customer ID to create from.
     - Parameter apiVersion: The Stripe API version.
     - Parameter completed: The closure to call upon completion.
     */
    static func createEphemeralKey(with customerID: String, apiVersion: String, completed: @escaping (_ result: CreateEphemeralKeyAPIResult) -> Void) {
        let params: Parameters = [Symbols.apiVersion: apiVersion, Symbols.customerID: customerID]
        Alamofire.request(baseURL.createEphemeralKey, method: .post, parameters: params)
            .validate(statusCode: 200..<300)
            .responseJSON { response in
                if let json = response.value as? JSON {
                    completed(.success(json))
                } else if let error = response.error {
                    completed(.failure(error))
                }
        }
    }
}

// MARK: - Stripe Ephemeral Key Provider
class EphemeralKeyProvider: NSObject, STPEphemeralKeyProvider {
    static let shared = EphemeralKeyProvider()
    
    private override init() {}
    
    func createCustomerKey(withAPIVersion apiVersion: String, completion: @escaping STPJSONResponseCompletionBlock) {
        PayAPIClient.createEphemeralKey(with: "cus_CSXmXhUTXRmOYX", apiVersion: apiVersion) { result in
            switch result {
            case .success(let json):
                completion(json, nil)
            case .failure(let error):
                completion(nil, error)
            }
        }
    }
}

/// A collection of endpoints to append to the base url.
private extension String {
    var newCustomer: String {
        return self + "/create-customer"
    }
    
    var chargeCustomer: String {
        return self + "/charge-customer"
    }
    
    var chargeGuestCustomer: String {
        return self + "/charge-guest-customer"
    }
    
    var createEphemeralKey: String {
        return self + "/create-ephemeral-key"
    }
}

extension Double {
    /// Transfers a `Double` decimal dollar amount to cents as an `Int`.
    func toCents() -> Int {
        return Int(self * 100)
    }
}
