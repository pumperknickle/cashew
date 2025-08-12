import ArrayTrie

public extension Node {
    func resolveRecursive(fetcher: Fetcher) async throws -> Self {
        var newProperties: [PathSegment: Address] = [:]
        
        try await properties().concurrentForEach { property in
            if let address = get(property: property) {
                newProperties[property] = try await address.resolveRecursive(fetcher: fetcher)
            }
        }
        
        return set(properties: newProperties)
    }
    
    func resolve(paths: ArrayTrie<ResolutionStrategy>, fetcher: Fetcher) async throws -> Self {
        var newProperties: [PathSegment: Address] = [:]
        
        try await properties().concurrentForEach { property in
            guard let address = get(property: property) else { return }
            
            if paths.get([property]) == .recursive {
                newProperties[property] = try await address.resolveRecursive(fetcher: fetcher)
            }
            else if let nextPaths = paths.traverse([property]) {
                if (!nextPaths.isEmpty()) {
                    newProperties[property] = try await address.resolve(paths: nextPaths, fetcher: fetcher)
                }
                else if paths.get([property]) == .targeted {
                    newProperties[property] = try await address.resolve(fetcher: fetcher)
                }
                else {
                    newProperties[property] = address
                }
            }
            else {
                newProperties[property] = address
            }
        }
        
        return set(properties: newProperties)
    }
}
