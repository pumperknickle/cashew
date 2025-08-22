import ArrayTrie

public protocol Address: Sendable {
    func resolve(paths: ArrayTrie<ResolutionStrategy>, fetcher: Fetcher) async throws -> Self
    func resolveRecursive(fetcher: Fetcher) async throws -> Self
    func resolve(fetcher: Fetcher) async throws -> Self
    func proof(paths: ArrayTrie<SparseMerkleProof>, fetcher: Fetcher) async throws -> Self 
    func transform(transforms: ArrayTrie<Transform>) throws -> Self?
    func storeRecursively(storer: Storer) throws
    func removingNode() -> Self
}
