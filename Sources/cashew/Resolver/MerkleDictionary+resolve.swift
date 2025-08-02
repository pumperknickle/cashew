import ArrayTrie

extension MerkleDictionary {
    func resolve(paths: [[String]: ResolutionStrategy], fetcher: Fetcher) async throws -> Self {
        if paths.isEmpty { return self }
        var pathTrie = ArrayTrie<ResolutionStrategy>()
        for (path, strategy) in paths {
            pathTrie.set(path, value: strategy)
        }
        return try await resolve(paths: pathTrie, fetcher: fetcher)
    }
    
    func resolve(paths: ArrayTrie<ResolutionStrategy>, fetcher: Fetcher) async throws -> Self {
        return await Self(root: try root.resolve(paths: paths, fetcher: fetcher))
    }
    
    func resolveRecursive(fetcher: Fetcher) async throws -> Self {
        return await Self(root: try root.resolveRecursive(fetcher: fetcher))
    }
    
    func resolve(fetcher: Fetcher) async throws -> Self {
        return await Self(root: try root.resolve(fetcher: fetcher))
    }
}
