//
//  MultipartData.swift
//  DINetwork
//
//  Created by Alexandr Lobanov on 22.03.2020.
//  Copyright © 2020 Alexandr Lobanov. All rights reserved.
//

import Foundation

public enum DIMimeType {
    case imagePNG
    case imageJPEG
    
    var name: String {
        switch self {
        case .imagePNG:
            return "image/png"
        case .imageJPEG:
            return "image/jpeg"
        }
    }
    
    var `extension`: String {
        switch self {
        case .imagePNG:
            return "png"
        case .imageJPEG:
            return "jpg"
        }
    }
}

public struct DIMultipartData {
    let fileName: String
    let type: DIMimeType
    let data: Data
    
    public init(fileName: String? = nil, type: DIMimeType, data: Data) {
        let name = fileName == nil ? "\(Date().timeIntervalSince1970)" : (fileName ?? "File")
        self.fileName = "\(name).\(type.extension)"
        self.type = type
        self.data = data
    }
}
