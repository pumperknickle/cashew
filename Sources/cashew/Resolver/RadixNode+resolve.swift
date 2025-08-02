import ArrayTrie

extension RadixNode {
    func resolve(paths: ArrayTrie<ResolutionStrategy>, fetcher: Fetcher) async throws -> Self {
        var newProperties = ThreadSafeDictionary<Character, ChildType>()
        
        let pathValuesAndTries = paths.getValuesAlongPath(prefix)
        let pathValues = Set(pathValuesAndTries.map({ $0.1 }))
        if pathValues.contains(.recursive) || pathValues.contains(.list) {
            return try await resolveRecursive(fetcher: fetcher)
        }
        
        guard let traversalPaths = paths.traverse(path: prefix) else { return self }
        
        try await properties().concurrentForEach { property in
            try await newProperties.set(Character(property), value: get(property: property).resolve(paths: traversalPaths, fetcher: fetcher))
        }
        
        return await set(properties: newProperties.allKeyValuePairs())
    }
    
    func resolveRecursiveCommon(fetcher: Fetcher) async throws -> Self {
        var newProperties = ThreadSafeDictionary<Character, ChildType>()
        
        try await properties().concurrentForEach { property in
            try await newProperties.set(Character(property), value: get(property: property).resolveRecursive(fetcher: fetcher))
        }
        
        return await set(properties: newProperties.allKeyValuePairs())
    }
    
    func resolveRecursive(fetcher: Fetcher) async throws -> Self {
        return try await resolveRecursiveCommon(fetcher: fetcher)
    }
    
    func resolveList(paths: ArrayTrie<ResolutionStrategy>, fetcher: Fetcher) async throws -> Self {
        return try await resolveRecursive(fetcher: fetcher)
    }
}

extension RadixNode where ValueType: Address {
    func resolveRecursive(fetcher: Fetcher) async throws -> Self {
        let resolved = try await resolveRecursiveCommon(fetcher: fetcher)
        if let value = value {
            return Self(prefix: resolved.prefix, value: try await value.resolveRecursive(fetcher: fetcher), children: resolved.children)
        }
        return resolved
    }
    
    func resolve(paths: ArrayTrie<ResolutionStrategy>, fetcher: Fetcher) async throws -> Self {
        let pathValuesAndTries = paths.getValuesAlongPath(prefix)
        if pathValuesAndTries.map({ $0.1 }).contains(.recursive) {
            return try await resolveRecursive(fetcher: fetcher)
        }
        let listTries = pathValuesAndTries.filter { $0.1 == .list }.map { $0.0 }
        if listTries.isEmpty {
            var newProperties = ThreadSafeDictionary<Character, ChildType>()
            guard let traversalPaths = paths.traverse(path: prefix) else { return self }
            try await properties().concurrentForEach { property in
                try await newProperties.set(Character(property), value: get(property: property).resolve(paths: traversalPaths, fetcher: fetcher))
            }
            
            let resolved = await set(properties: newProperties.allKeyValuePairs())
            if let value = value, traversalPaths.get([]) == .targeted {
                return await Self(prefix: resolved.prefix, value: try value.resolve(fetcher: fetcher), children: resolved.children)
            }
            return resolved
        }
        let traversalTrie = ArrayTrie<ResolutionStrategy>.mergeAll(tries: listTries) { leftStrategy, rightStrategy in
            if leftStrategy == .recursive || rightStrategy == .recursive {
                return .recursive
            }
            if leftStrategy == .list || rightStrategy == .list {
                return .list
            }
            return .targeted
        }
        let traversalPaths = paths.traverse(path: prefix)
        return try await resolveList(paths: traversalTrie, fetcher: fetcher)
    }
    
    func resolveList(paths: ArrayTrie<ResolutionStrategy>?, nextPaths: ArrayTrie<ResolutionStrategy>, fetcher: Fetcher) async throws -> Self {
        var newProperties = ThreadSafeDictionary<Character, ChildType>()
        
        var traversalPaths: ArrayTrie<ResolutionStrategy>?
        
        if let paths = paths {
            let pathValuesAndTries = paths.getValuesAlongPath(prefix)
            if pathValuesAndTries.map({ $0.1 }).contains(.recursive) {
                return try await resolveRecursive(fetcher: fetcher)
            }
            traversalPaths = paths.traverse(path: prefix)
        }
        
        try await properties().concurrentForEach { property in
            try await newProperties.set(Character(property), value: get(property: property).resolveList(paths: traversalPaths, nextPaths: nextPaths, fetcher: fetcher))
        }
        
        let resolved = await set(properties: newProperties.allKeyValuePairs())
        if let value = value {
            return await Self(prefix: resolved.prefix, value: try value.resolve(fetcher: fetcher), children: resolved.children)
        }
        return resolved
    }
}
