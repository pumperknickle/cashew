import ArrayTrie

// Base protocol for resolution strategies
protocol ResolutionStrategy_Protocol {
    func resolve<Node: RadixNode>(
        node: Node,
        paths: ArrayTrie<ResolutionStrategy>,
        fetcher: Fetcher
    ) async throws -> Node
}

struct RadixNodeImpl<Value>: RadixNode 
where Value: Codable, Value: Sendable, Value: LosslessStringConvertible {
    
    public typealias ValueType = Value
    public typealias ChildType = RadixHeaderImpl<Value>
    
    public var prefix: String
    public var value: ValueType?
    public var children: [Character : ChildType]
    private let resolutionStrategy: ResolutionStrategy_Protocol
    
    private init(
        prefix: String, 
        value: ValueType?, 
        children: [Character: ChildType],
        resolutionStrategy: ResolutionStrategy_Protocol
    ) {
        self.prefix = prefix
        self.value = value
        self.children = children
        self.resolutionStrategy = resolutionStrategy
    }
    
    public func resolve(paths: ArrayTrie<ResolutionStrategy>, fetcher: Fetcher) async throws -> Self {
        return try await resolutionStrategy.resolve(node: self, paths: paths, fetcher: fetcher) as! Self
    }
}

// Address-specific resolution strategy
private struct AddressResolutionStrategy<V: Address & Codable & Sendable & LosslessStringConvertible>: ResolutionStrategy_Protocol {
    func resolve<Node: RadixNode>(
        node: Node,
        paths: ArrayTrie<ResolutionStrategy>,
        fetcher: Fetcher
    ) async throws -> Node {
        guard let addressNode = node as? RadixNodeImpl<V> else {
            fatalError("Type mismatch in resolution strategy")
        }
        
        // Address-specific logic
        let pathValuesAndTries = paths.getValuesAlongPath(addressNode.prefix)
        if pathValuesAndTries.map({ $0.1 }).contains(.recursive) {
            return try await resolveRecursive(node: addressNode, fetcher: fetcher) as! Node
        }
        
        // Implement full Address-specific logic here
        return node // simplified
    }
    
    private func resolveRecursive(node: RadixNodeImpl<V>, fetcher: Fetcher) async throws -> RadixNodeImpl<V> {
        if let value = node.value {
            let resolvedValue = try await value.resolveRecursive(fetcher: fetcher)
            return RadixNodeImpl<V>(
                prefix: node.prefix,
                value: resolvedValue,
                children: node.children,
                resolutionStrategy: self
            )
        }
        return node
    }
}

// General resolution strategy  
private struct GeneralResolutionStrategy<V: Codable & Sendable & LosslessStringConvertible>: ResolutionStrategy_Protocol {
    func resolve<Node: RadixNode>(
        node: Node,
        paths: ArrayTrie<ResolutionStrategy>,
        fetcher: Fetcher
    ) async throws -> Node {
        // General resolution logic without Address assumptions
        return node // simplified
    }
}

// Public factory methods for type-safe construction
extension RadixNodeImpl {
    // Specialized initializer for Address types
    public init<V: Address & Codable & Sendable & LosslessStringConvertible>(
        prefix: String, 
        value: V?, 
        children: [Character: RadixHeaderImpl<V>]
    ) where V == Value {
        self.init(
            prefix: prefix,
            value: value,
            children: children,
            resolutionStrategy: AddressResolutionStrategy<V>()
        )
    }
    
    // Specialized initializer for HeaderImpl specifically
    public init<NodeType: Node>(
        prefix: String,
        value: HeaderImpl<NodeType>?,
        children: [Character: RadixHeaderImpl<HeaderImpl<NodeType>>]
    ) where HeaderImpl<NodeType> == Value {
        self.init(
            prefix: prefix,
            value: value,
            children: children,
            resolutionStrategy: AddressResolutionStrategy<HeaderImpl<NodeType>>()
        )
    }
    
    // General initializer (fallback)
    public static func general<V: Codable & Sendable & LosslessStringConvertible>(
        prefix: String,
        value: V?,
        children: [Character: RadixHeaderImpl<V>]
    ) -> RadixNodeImpl<V> {
        return RadixNodeImpl<V>(
            prefix: prefix,
            value: value,
            children: children,
            resolutionStrategy: GeneralResolutionStrategy<V>()
        )
    }
}