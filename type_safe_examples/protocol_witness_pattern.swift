import ArrayTrie

// Protocol witness for resolution behavior
protocol ResolutionWitness {
    associatedtype Value: Codable & Sendable & LosslessStringConvertible
    
    func resolve<Node: RadixNode>(
        _ node: Node,
        paths: ArrayTrie<ResolutionStrategy>,
        fetcher: Fetcher
    ) async throws -> Node where Node.ValueType == Value
}

// Witness for Address-conforming values
struct AddressResolutionWitness<V: Address & Codable & Sendable & LosslessStringConvertible>: ResolutionWitness {
    typealias Value = V
    
    func resolve<Node: RadixNode>(
        _ node: Node,
        paths: ArrayTrie<ResolutionStrategy>,
        fetcher: Fetcher
    ) async throws -> Node where Node.ValueType == Value {
        // Address-specific logic here
        let pathValuesAndTries = paths.getValuesAlongPath(node.prefix)
        if pathValuesAndTries.map({ $0.1 }).contains(.recursive) {
            return try await node.resolveRecursive(fetcher: fetcher)
        }
        // ... rest of Address-specific logic
        return node // simplified
    }
}

// Witness for general values
struct GeneralResolutionWitness<V: Codable & Sendable & LosslessStringConvertible>: ResolutionWitness {
    typealias Value = V
    
    func resolve<Node: RadixNode>(
        _ node: Node,
        paths: ArrayTrie<ResolutionStrategy>,
        fetcher: Fetcher
    ) async throws -> Node where Node.ValueType == Value {
        // General resolution logic
        return node // simplified
    }
}

// Enhanced RadixNodeImpl with witness
struct RadixNodeImpl<Value, Witness: ResolutionWitness>: RadixNode 
where Value: Codable, Value: Sendable, Value: LosslessStringConvertible, 
      Witness.Value == Value {
    
    public typealias ValueType = Value
    public typealias ChildType = RadixHeaderImpl<Value>
    
    public var prefix: String
    public var value: ValueType?
    public var children: [Character : ChildType]
    private let witness: Witness
    
    public init(prefix: String, value: ValueType?, children: [Character: ChildType], witness: Witness) {
        self.prefix = prefix
        self.value = value
        self.children = children
        self.witness = witness
    }
    
    public func resolve(paths: ArrayTrie<ResolutionStrategy>, fetcher: Fetcher) async throws -> Self {
        let resolved = try await witness.resolve(self, paths: paths, fetcher: fetcher)
        return resolved as! Self // Safe cast due to witness type constraints
    }
}

// Convenience factory methods
extension RadixNodeImpl {
    static func forAddress<V: Address & Codable & Sendable & LosslessStringConvertible>(
        prefix: String, 
        value: V?, 
        children: [Character: RadixHeaderImpl<V>]
    ) -> RadixNodeImpl<V, AddressResolutionWitness<V>> {
        return RadixNodeImpl(
            prefix: prefix, 
            value: value, 
            children: children, 
            witness: AddressResolutionWitness<V>()
        )
    }
    
    static func forGeneral<V: Codable & Sendable & LosslessStringConvertible>(
        prefix: String, 
        value: V?, 
        children: [Character: RadixHeaderImpl<V>]
    ) -> RadixNodeImpl<V, GeneralResolutionWitness<V>> {
        return RadixNodeImpl(
            prefix: prefix, 
            value: value, 
            children: children, 
            witness: GeneralResolutionWitness<V>()
        )
    }
}