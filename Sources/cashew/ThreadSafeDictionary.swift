import Foundation

actor ThreadSafeDictionary<Key: Hashable, Value>: Sendable {
    private var storage: [Key: Value] = [:]
    
    func set(_ key: Key, value: Value) {
        storage[key] = value
    }
    
    func allKeyValuePairs() -> [Key: Value] {
        return storage
    }
}
