//
//  DIJSONObjectDecoder.swift
//  DINetwork
//
//  Created by Alexandr Lobanov on 19.03.2020.
//  Copyright © 2020 Alexandr Lobanov. All rights reserved.
//

import Foundation

public class DIJSONObjectDecoder {
    static func decode<DataType>(type: DataType.Type, data: Data, keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .convertFromSnakeCase) throws -> DataType where DataType: Decodable {
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = keyDecodingStrategy
            let object = try decoder.decode(type, from: data)
            return object
        } catch {
            throw DINetworkError.decodigFailed
        }
    }
}

