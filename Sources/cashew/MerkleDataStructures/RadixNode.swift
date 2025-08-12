public protocol RadixNode: Node {
    associatedtype ChildType: RadixHeader where ChildType.NodeType == Self
    associatedtype ValueType: LosslessStringConvertible
    
    var prefix: String { get }
    var value: ValueType? { get }
    var children: [Character: ChildType] { get }
    
    init(prefix: String, value: ValueType?, children: [Character: ChildType])
}

public extension RadixNode {
    
    func set(properties: [PathSegment : any Address]) -> Self {
        var newProperties = [Character: ChildType]()
        for property in properties.keys {
            newProperties.updateValue(properties[property] as! ChildType, forKey: property.first!)
        }
        return Self(prefix: prefix, value: value, children: newProperties)
    }
    
    func set(properties: [Character: ChildType]) -> Self {
        return Self(prefix: prefix, value: value, children: properties)
    }
    
    func get(property: PathSegment) -> Address? {
        guard let char = property.first else { return nil }
        return children[char]
    }
    
    func getChild(property: PathSegment) -> ChildType {
        return children[property.first!]!
    }
    
    func properties() -> Set<PathSegment> {
        return Set(children.keys.map({ character in String(character) }))
    }
    
    func set(property: PathSegment, to child: any Address) -> Self {
        return self
    }
}
