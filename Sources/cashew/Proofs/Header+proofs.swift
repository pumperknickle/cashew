import ArrayTrie

public extension Header {
    func proof(paths: [[String]: SparseMerkleProof], fetcher: Fetcher) async throws -> Self {
        var pathTrie = ArrayTrie<SparseMerkleProof>()
        for (path, proof) in paths {
            pathTrie.set(path, value: proof)
        }
        return try await proof(paths: pathTrie, fetcher: fetcher)
    }
    
    func proof(paths: ArrayTrie<SparseMerkleProof>, fetcher: Fetcher) async throws -> Self {
        // Check if paths is truly empty (no root value and no children)
        if paths.isEmpty() && paths.get([]) == nil { return self }
        if let node = node {
            let resolvedNode = try await node.proof(paths: paths, fetcher: fetcher)
            return Self(rawCID: rawCID, node: resolvedNode)
        }
        else {
            let fetchedData = try await fetcher.fetch(rawCid: rawCID)
            guard let newNode = NodeType(data: fetchedData) else { throw DecodingError.decodeFromDataError }
            let resolvedNode = try await newNode.proof(paths: paths, fetcher: fetcher)
            return Self(rawCID: rawCID, node: resolvedNode)
        }
    }
}
