// Integration example showing how to update your existing RadixNodeImpl

import ArrayTrie

// 1. Keep your existing RadixNodeImpl for backward compatibility
// 2. Add a new witness-based version alongside it

// Protocol witness for resolution behavior
protocol ResolutionCapable {
    associatedtype Value: Codable & Sendable & LosslessStringConvertible
    
    static func resolveNode<Node: RadixNode>(
        _ node: Node,
        paths: ArrayTrie<ResolutionStrategy>,
        fetcher: Fetcher
    ) async throws -> Node where Node.ValueType == Value
    
    static func resolveRecursiveNode<Node: RadixNode>(
        _ node: Node,
        fetcher: Fetcher
    ) async throws -> Node where Node.ValueType == Value
}

// Address-capable witness
enum AddressCapable<V: Address & Codable & Sendable & LosslessStringConvertible>: ResolutionCapable {
    typealias Value = V
    
    static func resolveNode<Node: RadixNode>(
        _ node: Node,
        paths: ArrayTrie<ResolutionStrategy>,
        fetcher: Fetcher
    ) async throws -> Node where Node.ValueType == V {
        // Copy your existing Address-specific logic from lines 47-108 in RadixNodeImpl.swift
        let pathValuesAndTries = paths.getValuesAlongPath(node.prefix)
        if pathValuesAndTries.map({ $0.1 }).contains(.recursive) {
            return try await resolveRecursiveNode(node, fetcher: fetcher)
        }
        // ... rest of Address-specific logic
        return node // simplified for example
    }
    
    static func resolveRecursiveNode<Node: RadixNode>(
        _ node: Node,
        fetcher: Fetcher
    ) async throws -> Node where Node.ValueType == V {
        // Copy logic from resolveRecursive in your Address extension
        return node // simplified for example
    }
}

// General-capable witness  
enum GeneralCapable<V: Codable & Sendable & LosslessStringConvertible>: ResolutionCapable {
    typealias Value = V
    
    static func resolveNode<Node: RadixNode>(
        _ node: Node,
        paths: ArrayTrie<ResolutionStrategy>,
        fetcher: Fetcher
    ) async throws -> Node where Node.ValueType == V {
        // Copy your existing general logic from lines 162-200 in RadixNodeImpl.swift
        return node // simplified for example
    }
    
    static func resolveRecursiveNode<Node: RadixNode>(
        _ node: Node,
        fetcher: Fetcher
    ) async throws -> Node where Node.ValueType == V {
        // General recursive logic
        return node // simplified for example
    }
}

// Enhanced RadixNodeImpl that can work with witnesses
public struct SafeRadixNodeImpl<Value, Capability: ResolutionCapable>: RadixNode 
where Value: Codable, Value: Sendable, Value: LosslessStringConvertible, 
      Capability.Value == Value {
    
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
        let resolved = try await Capability.resolveNode(self, paths: paths, fetcher: fetcher)
        return resolved as! Self // Safe due to witness constraints
    }
}

// Type aliases for convenience and clarity
public typealias AddressRadixNode<V: Address & Codable & Sendable & LosslessStringConvertible> = SafeRadixNodeImpl<V, AddressCapable<V>>
public typealias GeneralRadixNode<V: Codable & Sendable & LosslessStringConvertible> = SafeRadixNodeImpl<V, GeneralCapable<V>>

// Usage examples:
/*

// For HeaderImpl<SomeNode> - automatically gets Address behavior
let headerNode: AddressRadixNode<HeaderImpl<SomeNode>> = SafeRadixNodeImpl(
    prefix: "test", 
    value: someHeaderImpl, 
    children: [:]
)

// For String values - gets General behavior  
let stringNode: GeneralRadixNode<String> = SafeRadixNodeImpl(
    prefix: "test",
    value: "some string",
    children: [:]
)

// The compiler enforces the right behavior at compile time!
try await headerNode.resolve(paths: somePaths, fetcher: fetcher) // Address logic
try await stringNode.resolve(paths: somePaths, fetcher: fetcher)  // General logic

*/