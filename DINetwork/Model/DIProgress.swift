//
//  Progress.swift
//  DINetwork
//
//  Created by Alexandr Lobanov on 22.03.2020.
//  Copyright © 2020 Alexandr Lobanov. All rights reserved.
//

import Foundation

public struct DIProgress {
    public let totalSize: Int64
    public let bytesRecived: Int64
    public let bytesExpexted: Int64
    
    public let percentDone: Float
    
    public var size: String {
        return ByteCountFormatter.string(fromByteCount: totalSize,
                                         countStyle: .file)
    }
}
