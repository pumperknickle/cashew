import ArrayTrie

public extension RadixHeader {
    func resolveList(paths: ArrayTrie<ResolutionStrategy>, fetcher: Fetcher) async throws -> Self {
        if let node = node {
            return Self(rawCID: rawCID, node: try await node.resolveList(paths: paths, fetcher: fetcher))
        }
        else {
            let fetchedData = try await fetcher.fetch(rawCid: rawCID)
            guard let newNode = NodeType(data: fetchedData) else { throw DecodingError.decodeFromDataError }
            return Self(rawCID: rawCID, node: try await newNode.resolveList(paths: paths, fetcher: fetcher))
        }
    }
    
    func resolve(paths: ArrayTrie<ResolutionStrategy>, fetcher: Fetcher) async throws -> Self {
        // Check if paths is truly empty (no root value and no children)
        if paths.isEmpty() && paths.get([]) == nil { return self }
        if let node = node {
            let resolvedNode = try await node.resolve(paths: paths, fetcher: fetcher)
            return Self(rawCID: rawCID, node: resolvedNode)
        }
        else {
            let fetchedData = try await fetcher.fetch(rawCid: rawCID)
            guard let newNode = NodeType(data: fetchedData) else { throw DecodingError.decodeFromDataError }
            let resolvedNode = try await newNode.resolve(paths: paths, fetcher: fetcher)
            return Self(rawCID: rawCID, node: resolvedNode)
        }
    }
    
    func resolveRecursive(fetcher: Fetcher) async throws -> Self {
        if let node = node {
            let resolvedNode = try await node.resolveRecursive(fetcher: fetcher)
            return Self(rawCID: rawCID, node: resolvedNode)
        }
        else {
            let fetchedData = try await fetcher.fetch(rawCid: rawCID)
            guard let newNode = NodeType(data: fetchedData) else { throw DecodingError.decodeFromDataError }
            let resolvedNode = try await newNode.resolveRecursive(fetcher: fetcher)
            return Self(rawCID: rawCID, node: resolvedNode)
        }
    }
    
    func resolve(fetcher: Fetcher) async throws -> Self {
        if node != nil {
            return self
        }
        else {
            let fetchedData = try await fetcher.fetch(rawCid: rawCID)
            guard let newNode = NodeType(data: fetchedData) else { throw DecodingError.decodeFromDataError }
            return Self(rawCID: rawCID, node: newNode)
        }
    }
}

public extension RadixHeader where NodeType.ValueType: Address {
    func resolveList(paths: ArrayTrie<ResolutionStrategy>?, nextPaths: ArrayTrie<ResolutionStrategy>, fetcher: Fetcher) async throws -> Self {
        if let node = node {
            return Self(rawCID: rawCID, node: try await node.resolveList(paths: paths, nextPaths: nextPaths, fetcher: fetcher))
        }
        else {
            let fetchedData = try await fetcher.fetch(rawCid: rawCID)
            guard let newNode = NodeType(data: fetchedData) else { throw DecodingError.decodeFromDataError }
            return Self(rawCID: rawCID, node: try await newNode.resolveList(paths: paths, nextPaths: nextPaths, fetcher: fetcher))
        }
    }
}
