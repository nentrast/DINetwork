//
//  DICache.swift
//  DINetwork
//
//  Created by Alexandr Lobanov on 31.03.2020.
//  Copyright © 2020 Alexandr Lobanov. All rights reserved.
//

import Foundation

public final class DICache<Key: Hashable & Codable, Value: Codable> {
    private let wrapped = NSCache<WrappedKey, DICache.Entry>()
    private let dateProvider: () -> Date
    private var entryLifetime: TimeInterval = 0.0
    private var keyTracker = KeyTracker()
    
    public init(name: String = "temporary", dateProvider: @escaping () -> Date = Date.init,
         entryLifetime: TimeInterval = 12 * 60 * 60,
         maximumCount: Int = 50) {
        
        self.dateProvider = dateProvider
        self.entryLifetime = entryLifetime
        wrapped.countLimit = maximumCount
        wrapped.delegate = keyTracker
        wrapped.name = name
        
        try? loadSavedCache(name: name)
    }
    
    deinit {
        try? saveToDisk(withName: wrapped.name)
    }
    
    public func insert(_ value: Value, forKey key: Key) {
        let date = dateProvider().addingTimeInterval(entryLifetime)
        let entry = Entry.init(key, value: value, expirationDate: date)
        
        wrapped.setObject(entry, forKey: WrappedKey(key))
        keyTracker.keys.insert(key)
    }
    
    public func value(forKey key: Key) -> Value? {
        guard let entry = wrapped.object(forKey: WrappedKey(key)) else {
            return nil
        }
        
        guard dateProvider() < entry.expirationDate else {
            // Discard values that have expired
            removeValue(forKey: key)
            return nil
        }
        
        return entry.value
    }
    
    public func removeValue(forKey key: Key) {
        wrapped.removeObject(forKey: WrappedKey(key))
    }
}


extension DICache: Codable where Key: Codable, Value: Codable {
    convenience public init(from decoder: Decoder) throws {
        self.init()
        
        let container = try decoder.singleValueContainer()
        let entries = try container.decode([DICache.Entry].self)
        
        entries.forEach({ self.insert($0)})
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(keyTracker.keys.compactMap(entry))
    }
}

extension DICache {
    func entry(forKey key: Key) -> DICache.Entry? {
        guard let entry = wrapped.object(forKey: DICache.WrappedKey(key)) else {
            return nil
        }
        
        guard dateProvider() < entry.expirationDate else {
            removeValue(forKey: key)
            return nil
        }
        
        return entry
    }
    
    func insert(_ entry: DICache.Entry) {
        wrapped.setObject(entry, forKey: DICache.WrappedKey(entry.key))
        keyTracker.keys.insert(entry.key)
    }
}

public extension DICache where Key: Codable, Value: Codable {
    func saveToDisk(withName name: String, using fileManager: FileManager = .default) throws {
        let folderURLs = fileManager.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )
        
        let fileURL = folderURLs[0].appendingPathComponent(name + ".cache")
        let data = try JSONEncoder().encode(self)
        try data.write(to: fileURL)
    }
    
    func loadSavedCache(name: String, using fileManager: FileManager = .default) throws {
        let folder = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let fileURL = folder[0].appendingPathComponent(name + ".cache")
        
        let data = try Data(contentsOf: fileURL)
        let cache = try JSONDecoder().decode(DICache.self, from: data)
        self.keyTracker = cache.keyTracker
    }
}

public extension DICache {
    subscript(key: Key) -> Value? {
        get { return value(forKey: key) }
        set {
            guard let value = newValue else {
                // If nil was assigned using this subscript,
                // then we remove any value for that key:
                removeValue(forKey: key)
                return
            }
            
            insert(value, forKey: key)
        }
    }
}

public extension DICache {
    final class Entry {
        let key: Key
        let value: Value
        let expirationDate: Date
        
        init(_ key: Key, value: Value, expirationDate: Date) {
            self.value = value
            self.expirationDate = expirationDate
            self.key = key
        }
    }
}

extension DICache.Entry: Codable where Key: Codable, Value: Codable {}

public extension DICache {
    final class KeyTracker: NSObject, NSCacheDelegate {
        var keys = Set<Key>()
        
        public func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
            guard let entry = obj as? Entry else {
                return
            }
            keys.remove(entry.key)
        }
    }
}

public extension DICache {
    final class WrappedKey: NSObject {
        let key: Key
        
        init(_ key: Key) {
            self.key = key
        }
        
        override public var hash: Int {
            return key.hashValue
        }
        
        public override func isEqual(_ object: Any?) -> Bool {
            guard let value = object as? WrappedKey else {
                return false
            }
            
            return value.key == key
            
        }
    }
}
