import ArrayTrie

// Type-erased resolver protocol
private protocol _RadixValueResolver {
    func resolve(
        prefix: String,
        value: Any?,
        children: [Character: Any],
        paths: ArrayTrie<ResolutionStrategy>,
        fetcher: Fetcher
    ) async throws -> (Any?, [Character: Any])
    
    func resolveRecursive(
        prefix: String,
        value: Any?,
        children: [Character: Any],
        fetcher: Fetcher
    ) async throws -> (Any?, [Character: Any])
}

// Concrete resolver for Address types
private struct _AddressResolver<V: Address & Codable & Sendable & LosslessStringConvertible>: _RadixValueResolver {
    
    func resolve(
        prefix: String,
        value: Any?,
        children: [Character: Any],
        paths: ArrayTrie<ResolutionStrategy>,
        fetcher: Fetcher
    ) async throws -> (Any?, [Character: Any]) {
        
        let typedValue = value as? V
        let typedChildren = children as! [Character: RadixHeaderImpl<V>]
        
        print("DEBUG: Address-constrained resolve called for prefix: \(prefix)")
        
        // Address-specific logic
        let pathValuesAndTries = paths.getValuesAlongPath(prefix)
        if pathValuesAndTries.map({ $0.1 }).contains(.recursive) {
            return try await resolveRecursive(prefix: prefix, value: value, children: children, fetcher: fetcher)
        }
        
        // Implement full Address resolution logic
        if let typedValue = typedValue {
            let resolvedValue = try await typedValue.resolve(paths: paths, fetcher: fetcher)
            return (resolvedValue, children)
        }
        
        return (typedValue, children)
    }
    
    func resolveRecursive(
        prefix: String,
        value: Any?,
        children: [Character: Any],
        fetcher: Fetcher
    ) async throws -> (Any?, [Character: Any]) {
        
        let typedValue = value as? V
        
        if let typedValue = typedValue {
            let resolvedValue = try await typedValue.resolveRecursive(fetcher: fetcher)
            return (resolvedValue, children)
        }
        
        return (typedValue, children)
    }
}

// Concrete resolver for general types
private struct _GeneralResolver<V: Codable & Sendable & LosslessStringConvertible>: _RadixValueResolver {
    
    func resolve(
        prefix: String,
        value: Any?,
        children: [Character: Any],
        paths: ArrayTrie<ResolutionStrategy>,
        fetcher: Fetcher
    ) async throws -> (Any?, [Character: Any]) {
        
        print("DEBUG: General resolve called for prefix: \(prefix)")
        // General resolution logic without Address assumptions
        return (value, children)
    }
    
    func resolveRecursive(
        prefix: String,
        value: Any?,
        children: [Character: Any],
        fetcher: Fetcher
    ) async throws -> (Any?, [Character: Any]) {
        
        // General recursive logic
        return (value, children)
    }
}

// Type-erased wrapper
struct AnyRadixValueResolver {
    private let _resolver: _RadixValueResolver
    
    init<V: Address & Codable & Sendable & LosslessStringConvertible>(_ type: V.Type) {
        self._resolver = _AddressResolver<V>()
    }
    
    init<V: Codable & Sendable & LosslessStringConvertible>(general type: V.Type) {
        self._resolver = _GeneralResolver<V>()
    }
    
    func resolve(
        prefix: String,
        value: Any?,
        children: [Character: Any],
        paths: ArrayTrie<ResolutionStrategy>,
        fetcher: Fetcher
    ) async throws -> (Any?, [Character: Any]) {
        return try await _resolver.resolve(
            prefix: prefix,
            value: value,
            children: children,
            paths: paths,
            fetcher: fetcher
        )
    }
    
    func resolveRecursive(
        prefix: String,
        value: Any?,
        children: [Character: Any],
        fetcher: Fetcher
    ) async throws -> (Any?, [Character: Any]) {
        return try await _resolver.resolveRecursive(
            prefix: prefix,
            value: value,
            children: children,
            fetcher: fetcher
        )
    }
}

// Enhanced RadixNodeImpl with type erasure
struct RadixNodeImpl<Value>: RadixNode 
where Value: Codable, Value: Sendable, Value: LosslessStringConvertible {
    
    public typealias ValueType = Value
    public typealias ChildType = RadixHeaderImpl<Value>
    
    public var prefix: String
    public var value: ValueType?
    public var children: [Character : ChildType]
    private let resolver: AnyRadixValueResolver
    
    // Private initializer
    private init(
        prefix: String, 
        value: ValueType?, 
        children: [Character: ChildType],
        resolver: AnyRadixValueResolver
    ) {
        self.prefix = prefix
        self.value = value
        self.children = children
        self.resolver = resolver
    }
    
    public func resolve(paths: ArrayTrie<ResolutionStrategy>, fetcher: Fetcher) async throws -> Self {
        let (newValue, newChildren) = try await resolver.resolve(
            prefix: prefix,
            value: value,
            children: children,
            paths: paths,
            fetcher: fetcher
        )
        
        return Self(
            prefix: prefix,
            value: newValue as? Value,
            children: newChildren as! [Character: ChildType],
            resolver: resolver
        )
    }
    
    public func resolveRecursive(fetcher: Fetcher) async throws -> Self {
        let (newValue, newChildren) = try await resolver.resolveRecursive(
            prefix: prefix,
            value: value,
            children: children,
            fetcher: fetcher
        )
        
        return Self(
            prefix: prefix,
            value: newValue as? Value,
            children: newChildren as! [Character: ChildType],
            resolver: resolver
        )
    }
}

// Type-safe factory methods
extension RadixNodeImpl {
    static func withAddress<V: Address & Codable & Sendable & LosslessStringConvertible>(
        prefix: String,
        value: V?,
        children: [Character: RadixHeaderImpl<V>]
    ) -> RadixNodeImpl<V> {
        return RadixNodeImpl<V>(
            prefix: prefix,
            value: value,
            children: children,
            resolver: AnyRadixValueResolver(V.self)
        )
    }
    
    static func withGeneral<V: Codable & Sendable & LosslessStringConvertible>(
        prefix: String,
        value: V?,
        children: [Character: RadixHeaderImpl<V>]
    ) -> RadixNodeImpl<V> {
        return RadixNodeImpl<V>(
            prefix: prefix,
            value: value,
            children: children,
            resolver: AnyRadixValueResolver(general: V.self)
        )
    }
    
    // Convenience initializer that auto-detects Address conformance
    public init(prefix: String, value: ValueType?, children: [Character: ChildType]) {
        self.prefix = prefix
        self.value = value
        self.children = children
        
        // Use runtime check to determine resolver type, but in type-safe way
        if Value.self is any Address.Type {
            self.resolver = AnyRadixValueResolver(Value.self as! (any Address & Codable & Sendable & LosslessStringConvertible).Type)
        } else {
            self.resolver = AnyRadixValueResolver(general: Value.self)
        }
    }
}