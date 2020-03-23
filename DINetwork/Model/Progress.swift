//
//  Progress.swift
//  DINetwork
//
//  Created by Alexandr Lobanov on 22.03.2020.
//  Copyright © 2020 Alexandr Lobanov. All rights reserved.
//

import Foundation

public struct Progress {
    let totalSize: Int64
    let bytesRecived: Int64
    let bytesExpexted: Int64
    
    let percentDone: Float
    
    var size: String {
        return ByteCountFormatter.string(fromByteCount: totalSize,
                                         countStyle: .file)
    }
}
