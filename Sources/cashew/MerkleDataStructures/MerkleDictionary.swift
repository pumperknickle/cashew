import ArrayTrie

public protocol MerkleDictionary: Node {
    associatedtype ValueType
    associatedtype RootType: RadixHeader where RootType.NodeType.ValueType == ValueType
    
    var root: RootType { get }
    
    init(root: RootType)
}
