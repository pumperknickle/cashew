import ArrayTrie

// Phantom type markers
enum AddressCapability {}
enum GeneralCapability {}

// Protocol to mark capability
protocol Capability {}
extension AddressCapability: Capability {}
extension GeneralCapability: Capability {}

struct RadixNodeImpl<Value, C: Capability>: RadixNode 
where Value: Codable, Value: Sendable, Value: LosslessStringConvertible {
    
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
}

// Address-specific implementation
extension RadixNodeImpl where C == AddressCapability, Value: Address {
    func resolve(paths: ArrayTrie<ResolutionStrategy>, fetcher: Fetcher) async throws -> Self {
        print("DEBUG: Address-constrained RadixNodeImpl.resolve called for prefix: \(prefix)")
        // Address-specific logic
        let pathValuesAndTries = paths.getValuesAlongPath(prefix)
        if pathValuesAndTries.map({ $0.1 }).contains(.recursive) {
            return try await resolveRecursive(fetcher: fetcher)
        }
        // ... rest of Address-specific logic
        return self // simplified
    }
    
    func resolveRecursive(fetcher: Fetcher) async throws -> Self {
        // Address-specific recursive logic with value.resolveRecursive
        if let value = value {
            let resolvedValue = try await value.resolveRecursive(fetcher: fetcher)
            return Self(prefix: prefix, value: resolvedValue, children: children)
        }
        return self
    }
}

// General implementation
extension RadixNodeImpl where C == GeneralCapability {
    func resolve(paths: ArrayTrie<ResolutionStrategy>, fetcher: Fetcher) async throws -> Self {
        print("DEBUG: General RadixNodeImpl.resolve called for prefix: \(prefix)")
        // General logic without Address assumptions
        return self // simplified
    }
    
    func resolveRecursive(fetcher: Fetcher) async throws -> Self {
        // General recursive logic without calling value.resolveRecursive
        return self
    }
}

// Type aliases for convenience
typealias AddressRadixNodeImpl<V: Address & Codable & Sendable & LosslessStringConvertible> = RadixNodeImpl<V, AddressCapability>
typealias GeneralRadixNodeImpl<V: Codable & Sendable & LosslessStringConvertible> = RadixNodeImpl<V, GeneralCapability>

// Factory methods for type-safe construction
extension RadixNodeImpl {
    static func addressNode<V: Address & Codable & Sendable & LosslessStringConvertible>(
        prefix: String, 
        value: V?, 
        children: [Character: RadixHeaderImpl<V>]
    ) -> RadixNodeImpl<V, AddressCapability> {
        return RadixNodeImpl<V, AddressCapability>(prefix: prefix, value: value, children: children)
    }
    
    static func generalNode<V: Codable & Sendable & LosslessStringConvertible>(
        prefix: String, 
        value: V?, 
        children: [Character: RadixHeaderImpl<V>]
    ) -> RadixNodeImpl<V, GeneralCapability> {
        return RadixNodeImpl<V, GeneralCapability>(prefix: prefix, value: value, children: children)
    }
}