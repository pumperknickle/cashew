import ArrayTrie

public extension MerkleDictionary {
    func transform(transforms: ArrayTrie<Transform>) throws -> Self? {
        let values = transforms.getValuesOneLevelDeep()
        var delta = 0
        for value in values {
            switch value {
                case .delete: delta -= 1
                case .insert(_): delta += 1
                default: continue
            }
        }
        var newChildren = [Character: ChildType]()
        let allChildChars = Set().union(transforms.getAllChildCharacters()).union(properties().map { $0.first! })
        for childChar in allChildChars {
            if let existingChild = children[childChar] {
                if let traversal = transforms.traverseChild(childChar) {
                    if let traversedChild = try existingChild.transform(transforms: traversal) {
                        newChildren[childChar] = traversedChild
                    }
                    else {
                        newChildren.removeValue(forKey: childChar)
                    }
                }
                else {
                    newChildren[childChar] = existingChild
                }
            }
            else {
                guard let traversal = transforms.traverseChild(childChar) else { throw TransformErrors.transformFailed }
                if !traversal.isEmpty() {
                    let newChild = try ChildType.NodeType.insertAll(childChar: childChar, transforms: traversal)
                    newChildren[childChar] = ChildType(node: newChild)
                }
            }
        }
        return Self(children: newChildren, count: count + delta)
    }
    
    func get(key: String) throws -> ValueType? {
        guard let firstChar = key.first else { return nil }
        guard let existingChild = children[firstChar] else { return nil }
        return try existingChild.get(key: ArraySlice(key))
    }
    
    func deleting(key: String) throws -> Self {
        guard let firstChar = key.first else { throw TransformErrors.invalidKey }
        if let existingChild = children[firstChar] {
            if let updatedChild = try existingChild.deleting(key: ArraySlice(key)) {
                var newChildren = children
                newChildren[firstChar] = updatedChild
                return Self(children: newChildren, count: count - 1)
            }
            var newChildren = children
            newChildren.removeValue(forKey: firstChar)
            return Self(children: newChildren, count: count - 1)
        }
        else {
            throw TransformErrors.invalidKey
        }
    }
    
    func inserting(key: String, value: ValueType) throws -> Self {
        if key == "" { throw TransformErrors.invalidKey }
        return try inserting(key: ArraySlice(key), value: value)
    }
    
    func inserting(key: ArraySlice<Character>, value: ValueType) throws -> Self {
        guard let firstChar = key.first else { throw TransformErrors.invalidKey }
        if let existingChild = children[firstChar] {
            let updatedChild = try existingChild.inserting(key: key, value: value)
            var newChildren = children
            newChildren[firstChar] = updatedChild
            return Self(children: newChildren, count: count + 1)
        } else {
            let newChild = ChildType(node: ChildType.NodeType(prefix: String(key), value: value, children: [:]))
            var newChildren = children
            newChildren[firstChar] = newChild
            return Self(children: newChildren, count: count + 1)
        }
    }
    
    func mutating(key: String, value: ValueType) throws -> Self {
        return try mutating(key: ArraySlice(key), value: value)
    }
    
    func mutating(key: ArraySlice<Character>, value: ValueType) throws -> Self {
        guard let firstChar = key.first else { throw TransformErrors.invalidKey }
        if let existingChild = children[firstChar] {
            let updatedChild = try existingChild.mutating(key: key, value: value)
            var newChildren = children
            newChildren[firstChar] = updatedChild
            return Self(children: newChildren, count: count)
        } else {
            throw TransformErrors.invalidKey
        }
    }

}
