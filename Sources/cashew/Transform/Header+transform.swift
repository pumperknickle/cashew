import ArrayTrie

public extension Header {
    func transform(transforms: ArrayTrie<Transform>) throws -> Self {
        if transforms.isEmpty() { return self }
        guard let node = node else { throw DataErrors.nodeNotAvailable }
        guard let transformedNode = try node.transform(transforms: transforms) else { throw TransformErrors.transformFailed }
        return Self(node: transformedNode)
    }
}
