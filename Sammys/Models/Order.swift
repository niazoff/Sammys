//
//  Order.swift
//  Sammys
//
//  Created by Natanel Niazoff on 4/23/18.
//  Copyright © 2018 Natanel Niazoff. All rights reserved.
//

import Foundation

typealias Foods = [FoodType : [Food]]
private typealias SavedFoods = [FoodType : [AnyFood]]

struct Order: Codable {
    let id: String
    let number: String
    let date: Date
    let foods: Foods
    
    enum CodingKeys: CodingKey {
        case id, number, date, foods
    }
    
    init(number: String, date: Date, foods: [FoodType : [Food]]) {
        self.id = UUID().uuidString
        self.number = number
        self.date = date
        self.foods = foods
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.number = try container.decode(String.self, forKey: .number)
        self.date = try container.decode(Date.self, forKey: .date)
        let savedFoods = try container.decode(SavedFoods.self, forKey: .foods)
        self.foods = savedFoods.encodableUnwrapped()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(number, forKey: .number)
        try container.encode(date, forKey: .date)
        try container.encode(foods.toEncodable(), forKey: .foods)
    }
}

private extension Dictionary where Key == FoodType, Value == [Food] {
    func toEncodable() -> SavedFoods {
        return self.mapValues { $0.map { AnyFood($0) } }
    }
}

private extension Dictionary where Key == FoodType, Value == [AnyFood] {
    func encodableUnwrapped() -> Foods {
        return self.mapValues { $0.map { $0.food } }
    }
}