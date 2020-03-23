//
//  EndPointType.swift
//  DINetwork
//
//  Created by Alexandr Lobanov on 19.03.2020.
//  Copyright © 2020 Alexandr Lobanov. All rights reserved.
//

import Foundation

public protocol URLRequestConvertible {
    func asURLRequest() throws -> URLRequest
}

public typealias HTTPHeaders = [String: String]
public typealias Parameters = [String: Any]

public enum HTTPMethod: String {
    case get            = "GET"
    case post           = "POST"
    case put            = "PUT"
    case pathc          = "PATCH"
    case delete         = "DELETE"
}

public enum HTTPTask {
    case request
    case requestParameters(bodyParametrs: Parameters?, urlParametrs: Parameters?)
    case requestParametersAndHeaders(bodyParametrs: Parameters?, urlParametrs: Parameters?, additionalHeaders: HTTPHeaders?)
}

public protocol EndpointType: URLRequestConvertible {
    var baseURL: URL  { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var task: HTTPTask { get }
    var headers: HTTPHeaders { get }
}

public extension EndpointType {
    func asURLRequest() throws -> URLRequest {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent(path),
        cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
        timeoutInterval: 10)
        
        urlRequest.httpMethod = method.rawValue
        
        switch task {
        case .request:
            headers.forEach { (key, value) in
                urlRequest.setValue(value, forHTTPHeaderField: key)
            }
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        case .requestParameters(let bodyParametrs, let urlParametrs):
            try self.configureParametrs(bodyParametrs: bodyParametrs,
                                        urlParameters: urlParametrs,
                                        request: &urlRequest)
        case .requestParametersAndHeaders(let bodyParametrs, let urlParametrs, let additionalHeaders):
            self.addAdditionalHeaders(additionalHeaders, request: &urlRequest)
            try self.configureParametrs(bodyParametrs: bodyParametrs,
                                        urlParameters: urlParametrs,
                                        request: &urlRequest)
        }

        return urlRequest
    }
    
    private func addAdditionalHeaders(_ headers: HTTPHeaders?, request: inout URLRequest) {
        guard let headers = headers else {
            return
        }
        headers.forEach { (key, value) in
            request.setValue(value, forHTTPHeaderField: key)
        }
    }
    
    private func configureParametrs(bodyParametrs: Parameters?, urlParameters: Parameters?, request: inout URLRequest) throws {
        do {
            if let bodyParametrs = bodyParametrs {
                try JSONParameterEncoder.encode(urlRequest: &request, with: bodyParametrs)
            }
            
            if let urlParametrs = urlParameters {
                try URLParameterEncoder.encode(urlRequest: &request, with: urlParametrs)
            }
        } catch {
            throw error
        }
    }
}

