import ArrayTrie

public extension RadixNode {
    func resolve(paths: ArrayTrie<ResolutionStrategy>, fetcher: Fetcher) async throws -> Self {
        let newProperties = ThreadSafeDictionary<Character, ChildType>()
        
        // Check if root level has list or recursive strategy
        if let rootStrategy = paths.get([prefix]) {
            if rootStrategy == .list || rootStrategy == .recursive {
                return try await resolveRecursive(fetcher: fetcher)
            }
        }
        
        let pathValuesAndTries = paths.getValuesAlongPath(prefix)
        let pathValues = Set(pathValuesAndTries.map({ $0.1 }))
        if pathValues.contains(.recursive) || pathValues.contains(.list) {
            return try await resolveRecursive(fetcher: fetcher)
        }
        
        guard let traversalPaths = paths.traverse(path: prefix) else { return self }
        
        try await properties().concurrentForEach { property in
            if let finalTraversalPaths = traversalPaths.traverseChild(property.first!) {
                let childValue = try await getChild(property: property).resolve(paths: finalTraversalPaths, fetcher: fetcher)
                await newProperties.set(property.first!, value: childValue)
            }
            else {
                await newProperties.set(property.first!, value: getChild(property: property))
            }
        }
        
        return await set(properties: newProperties.allKeyValuePairs())
    }
    
    func resolveRecursiveCommon(fetcher: Fetcher) async throws -> Self {
        let newProperties = ThreadSafeDictionary<Character, ChildType>()
        
        try await properties().concurrentForEach { property in
            let childValue = try await getChild(property: property).resolveRecursive(fetcher: fetcher)
            await newProperties.set(property.first!, value: childValue)
        }
        
        return set(properties: await newProperties.allKeyValuePairs())
    }
    
    func resolveRecursive(fetcher: Fetcher) async throws -> Self {
        return try await resolveRecursiveCommon(fetcher: fetcher)
    }
    
    func resolveList(paths: ArrayTrie<ResolutionStrategy>, fetcher: Fetcher) async throws -> Self {
        return try await resolveRecursive(fetcher: fetcher)
    }
}

public extension RadixNode where ValueType: Address {
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
            let newProperties = ThreadSafeDictionary<Character, ChildType>()
            guard let traversalPaths = paths.traverse(path: prefix) else { return self }
            try await properties().concurrentForEach { property in
                if let propertyTraversal = traversalPaths.traverseChild(property.first!) {
                    let childValue = try await getChild(property: property).resolve(paths: propertyTraversal, fetcher: fetcher)
                    await newProperties.set(property.first!, value: childValue)
                }
                else {
                    await newProperties.set(property.first!, value: getChild(property: property))
                }
            }
            let resolved = await set(properties: newProperties.allKeyValuePairs())
            if let value = value {
                if let downstreamPaths = paths.traverse([prefix]) {
                    return await Self(prefix: resolved.prefix, value: try value.resolve(paths: downstreamPaths, fetcher: fetcher), children: resolved.children)
                }
                if paths.get([prefix]) == .targeted {
                    return await Self(prefix: resolved.prefix, value: try value.resolve(fetcher: fetcher), children: resolved.children)
                }
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
        let resolved = try await resolveList(paths: paths.traverse(path: prefix), nextPaths: traversalTrie, fetcher: fetcher)
        if let value = value {
            let resolvedValue = try await value.resolve(fetcher: fetcher)
            if let downstreamPaths = paths.traverse([prefix]) {
                let mergedDownstreamPaths = traversalTrie.merging(with: downstreamPaths, mergeRule: { leftStrategy, rightStrategy in
                    if leftStrategy == .recursive || rightStrategy == .recursive {
                        return .recursive
                    }
                    if leftStrategy == .list || rightStrategy == .list {
                        return .list
                    }
                    return .targeted
                })
                let newValue = try await resolvedValue.resolve(paths: mergedDownstreamPaths, fetcher: fetcher)
                return Self(prefix: resolved.prefix, value: newValue, children: resolved.children)
            }
            let newValue = try await resolvedValue.resolve(paths: traversalTrie, fetcher: fetcher)
            return Self(prefix: resolved.prefix, value: newValue, children: resolved.children)
        }
        return resolved
    }
    
    func resolveList(paths: ArrayTrie<ResolutionStrategy>?, nextPaths: ArrayTrie<ResolutionStrategy>, fetcher: Fetcher) async throws -> Self {
        let newProperties = ThreadSafeDictionary<Character, ChildType>()
        
        var traversalPaths: ArrayTrie<ResolutionStrategy>?
        var finalNextPaths = nextPaths
        
        if let paths = paths {
            let pathValuesAndTries = paths.getValuesAlongPath(prefix)
            if pathValuesAndTries.map({ $0.1 }).contains(.recursive) {
                return try await resolveRecursive(fetcher: fetcher)
            }
            let listTries = pathValuesAndTries.filter { $0.1 == .list }.map { $0.0 }
            if !listTries.isEmpty {
                finalNextPaths = ArrayTrie<ResolutionStrategy>.mergeAll(tries: listTries + [nextPaths]) { leftStrategy, rightStrategy in
                    if leftStrategy == .recursive || rightStrategy == .recursive {
                        return .recursive
                    }
                    if leftStrategy == .list || rightStrategy == .list {
                        return .list
                    }
                    return .targeted
                }
            }
            traversalPaths = paths.traverse(path: prefix)
        }
        
        try await properties().concurrentForEach { property in
            let childValue = try await getChild(property: property).resolveList(paths: traversalPaths?.traverseChild(property.first!), nextPaths: finalNextPaths, fetcher: fetcher)
            await newProperties.set(property.first!, value: childValue)
        }
        
        let resolved = await set(properties: newProperties.allKeyValuePairs())
        if let value = value {
            if let newTraversalPaths = traversalPaths?.traverse([""]) {
                let downstreamPaths = newTraversalPaths.merging(with: finalNextPaths, mergeRule: { leftStrategy, rightStrategy in
                    if leftStrategy == .recursive || rightStrategy == .recursive {
                        return .recursive
                    }
                    if leftStrategy == .list || rightStrategy == .list {
                        return .list
                    }
                    return .targeted
                })
                return await Self(prefix: resolved.prefix, value: try value.resolve(paths: downstreamPaths, fetcher: fetcher), children: resolved.children)
            }
            return await Self(prefix: resolved.prefix, value: try value.resolve(paths: finalNextPaths, fetcher: fetcher), children: resolved.children)
        }
        return resolved
    }
}
