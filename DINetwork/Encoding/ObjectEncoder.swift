//
//  ObjectEncoder.swift
//  DINetwork
//
//  Created by Alexandr Lobanov on 22.03.2020.
//  Copyright © 2020 Alexandr Lobanov. All rights reserved.
//

import Foundation

public class ObjectEncoder {
    // TODO: somehow handle catch result here
    public static func encode<T: Encodable>(object: T, keyEncoding: JSONEncoder.KeyEncodingStrategy = .convertToSnakeCase) -> [String: Any]? {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = keyEncoding
        guard let data = try? encoder.encode(object) else {
            return [:]
        }
        let result = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        
        return result ?? [:]
    }
    
    public static func encodeToData<T: Encodable>(object: T) throws -> Data {
        let encoder = JSONEncoder()
        
        return try encoder.encode(object)
    }
}
