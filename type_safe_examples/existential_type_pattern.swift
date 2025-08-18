import ArrayTrie

// Protocol composition for different value capabilities
protocol RadixValue: Codable, Sendable, LosslessStringConvertible {}
protocol AddressRadixValue: RadixValue, Address {}

// Extend existing types to conform
extension HeaderImpl: AddressRadixValue where NodeType: Node {}

struct RadixNodeImpl<Value: RadixValue>: RadixNode {
    public typealias ValueType = Value
    public typealias ChildType = RadixHeaderImpl<Value>
    
    public var prefix: String
    public var value: ValueType?
    public var children: [Character : ChildType]
    
    public init(prefix: String, value: ValueType?, children: [Character: ChildType]) {
        self.prefix = prefix
        self.value = value
        self.children = children
    }
    
    public func resolve(paths: ArrayTrie<ResolutionStrategy>, fetcher: Fetcher) async throws -> Self {
        // Use existential type checking
        if let addressValue = value as? any AddressRadixValue {
            return try await resolveWithAddress(addressValue: addressValue, paths: paths, fetcher: fetcher)
        } else {
            return try await resolveGeneral(paths: paths, fetcher: fetcher)
        }
    }
    
    private func resolveWithAddress(
        addressValue: any AddressRadixValue,
        paths: ArrayTrie<ResolutionStrategy>,
        fetcher: Fetcher
    ) async throws -> Self {
        print("DEBUG: Address-constrained RadixNodeImpl.resolve called for prefix: \(prefix)")
        
        let pathValuesAndTries = paths.getValuesAlongPath(prefix)
        if pathValuesAndTries.map({ $0.1 }).contains(.recursive) {
            return try await resolveRecursiveWithAddress(fetcher: fetcher)
        }
        
        // Address-specific logic
        return self // simplified
    }
    
    private func resolveGeneral(
        paths: ArrayTrie<ResolutionStrategy>,
        fetcher: Fetcher
    ) async throws -> Self {
        print("DEBUG: General RadixNodeImpl.resolve called for prefix: \(prefix)")
        
        // General logic
        return self // simplified
    }
    
    private func resolveRecursiveWithAddress(fetcher: Fetcher) async throws -> Self {
        if let addressValue = value as? any AddressRadixValue {
            let resolvedValue = try await addressValue.resolveRecursive(fetcher: fetcher)
            return Self(prefix: prefix, value: resolvedValue as? Value, children: children)
        }
        return self
    }
}

// Type-safe factory methods
extension RadixNodeImpl {
    static func withAddress<V: AddressRadixValue>(
        prefix: String,
        value: V?,
        children: [Character: RadixHeaderImpl<V>]
    ) -> RadixNodeImpl<V> {
        return RadixNodeImpl<V>(prefix: prefix, value: value, children: children)
    }
    
    static func withGeneral<V: RadixValue>(
        prefix: String,
        value: V?,
        children: [Character: RadixHeaderImpl<V>]
    ) -> RadixNodeImpl<V> {
        return RadixNodeImpl<V>(prefix: prefix, value: value, children: children)
    }
}

// Convenience type aliases
typealias AddressRadixNode<V: AddressRadixValue> = RadixNodeImpl<V>
typealias GeneralRadixNode<V: RadixValue> = RadixNodeImpl<V>