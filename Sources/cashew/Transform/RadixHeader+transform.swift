public extension RadixHeader {
    func get(key: ArraySlice<Character>) throws -> NodeType.ValueType? {
        guard let node = node else { throw TransformErrors.missingData }
        return try node.get(key: key)
    }
    
    func deleting(key: ArraySlice<Character>) throws -> Self? {
        guard let node = node else { throw TransformErrors.missingData }
        if let newNode = try node.deleting(key: key) {
            return Self(node: newNode)
        }
        return nil
    }
    
    func inserting(key: ArraySlice<Character>, value: NodeType.ValueType) throws -> Self {
        guard let node = node else { throw TransformErrors.missingData }
        let newNode = try node.inserting(key: key, value: value)
        return Self(node: newNode)
    }
    
    func mutating(key: ArraySlice<Character>, value: NodeType.ValueType) throws -> Self {
        guard let node = node else { throw TransformErrors.missingData }
        let newNode = try node.mutating(key: key, value: value)
        return Self(node: newNode)
    }
}
