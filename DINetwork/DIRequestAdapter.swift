//
//  DIRequestAdapter.swift
//  DINetwork
//
//  Created by Alexandr Lobanov on 09.04.2020.
//  Copyright © 2020 Alexandr Lobanov. All rights reserved.
//

import Foundation

public protocol DIRequestAdapterProtocol {
    func adopt(_ urlRequest:  URLRequest) throws -> URLRequest
}

public protocol DIRequestRerierProtocol  {
    func retry(_ session: URLSession, request: URLRequest, response: URLResponse?, data: Data? ,error: Error?, completion: @escaping ((Bool, Error?) -> Void))
}
