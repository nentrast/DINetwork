//
//  NetworkError.swift
//  DINetwork
//
//  Created by Alexandr Lobanov on 19.03.2020.
//  Copyright © 2020 Alexandr Lobanov. All rights reserved.
//

import Foundation

public enum NetworkError: Error {
    case parametrsNil
    case encodingFailed
    case missingURL
    case decodigFailed
    case response(NetworkResponseError)
    
    var description: String {
        switch self {
        case .parametrsNil:
            return "paraametrs were nil"
        case .encodingFailed:
            return "failed to encode"
        case .missingURL:
            return "url is missing"
        case .decodigFailed:
            return  "Failed to decode object"
        case .response(let error):
            return error.localizedDescription
        @unknown default:
            return localizedDescription
        }
    }
}
