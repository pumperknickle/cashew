import ArrayTrie

extension Node {
    func resolveRecursive(fetcher: Fetcher) async throws -> Self {
        var newProperties = ThreadSafeDictionary<PathSegment, Address>()
        
        try await properties().concurrentForEach { property in
            try await newProperties.set(property, value: get(property: property).resolveRecursive(fetcher: fetcher))
        }
        
        return await set(properties: newProperties.allKeyValuePairs())
    }
    
    func resolve(paths: ArrayTrie<ResolutionStrategy>, fetcher: Fetcher) async throws -> Self {
        var newProperties = ThreadSafeDictionary<PathSegment, Address>()
        
        try await properties().concurrentForEach { property in
            if paths.get([property]) == .recursive {
                try await newProperties.set(property, value: get(property: property).resolveRecursive(fetcher: fetcher))
            }
            else if let nextPaths = paths.traverse([property]) {
                if (!nextPaths.isEmpty()) {
                    try await newProperties.set(property, value: get(property: property).resolve(paths: nextPaths, fetcher: fetcher))
                }
                else if paths.get([property]) == .targeted {
                    try await newProperties.set(property, value: get(property: property).resolve(fetcher: fetcher))
                }
            }
        }
        
        return await set(properties: newProperties.allKeyValuePairs())
    }
}
