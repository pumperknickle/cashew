import ArrayTrie

extension MerkleDictionary {
    func transform(transforms: ArrayTrie<Transform>) -> Self {
        Self(root: root.transform(transforms: transforms))
    }
}
