import ArrayTrie

public extension Header {
    func transform(transforms: [[String]: Transform]) throws -> Self? {
        var trieRepresentation = ArrayTrie<Transform>()
        for path in transforms {
            trieRepresentation.set(path.key, value: path.value)
        }
        return try transform(transforms: trieRepresentation)
    }
    
    
    func transform(transforms: ArrayTrie<Transform>) throws -> Self? {
        if transforms.isEmpty() { return self }
        guard let node = node else { throw DataErrors.nodeNotAvailable }
        guard let result = try node.transform(transforms: transforms) else { return nil }
        return Self(node: result)
    }
}
