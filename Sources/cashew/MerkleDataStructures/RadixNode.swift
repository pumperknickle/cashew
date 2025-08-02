public protocol RadixNode: Node {
    associatedtype ChildType: RadixHeader where ChildType.NodeType == Self
    associatedtype ValueType: LosslessStringConvertible
    
    var prefix: String { get }
    var value: ValueType? { get }
    var children: [Character: ChildType] { get }
    
    init(prefix: String, value: ValueType?, children: [Character: ChildType])
}

extension RadixNode {
    
    func set(properties: [Character: ChildType]) -> Self {
        return Self(prefix: prefix, value: value, children: properties)
    }
    
    func get(property: PathSegment) -> ChildType {
        return children[Character(property)]!
    }
    
    func properties() -> Set<PathSegment> {
        return Set(children.keys.map({ character in String(character) }))
    }
}
