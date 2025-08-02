import ArrayTrie

extension Header {
    func transform(transforms: ArrayTrie<Transform>) throws -> Self {
        guard let node = node else { throw DataError.missingData }
        return Self(node: try node.transform(transforms: transforms))
    }
}
