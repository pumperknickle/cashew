import ArrayTrie

public protocol MerkleDictionary: Node {
    associatedtype ValueType
    associatedtype ChildType: RadixHeader where ChildType.NodeType.ValueType == ValueType
    
    var children: [Character: ChildType] { get }
    var count: Int { get }
    
    init(children: [Character: ChildType], count: Int)
}

public extension MerkleDictionary {
    func get(property: PathSegment) -> Address? {
        return children[Character(property)]
    }
    
    func properties() -> Set<PathSegment> {
        return Set(children.keys.map { String($0) })
    }
    
    func set(properties: [PathSegment: Address]) -> Self {
        var newProperties = [Character: ChildType]()
        for property in properties {
            newProperties[property.key.first!] = property.value as? ChildType
        }
        return Self(children: newProperties, count: count)
    }
    
    func set(properties: [Character: ChildType]) -> Self {
        return Self(children: properties, count: count)
    }
}
