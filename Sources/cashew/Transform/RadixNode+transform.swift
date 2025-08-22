import ArrayTrie

public extension RadixNode {
    static func insertAll(childChar: Character, transforms: ArrayTrie<Transform>) throws -> Self {
        guard let childPrefix = transforms.getChildPrefix(char: childChar) else { throw TransformErrors.transformFailed }
        guard let traversedTransforms = transforms.traverse(path: childPrefix) else { throw TransformErrors.transformFailed }
        let childChars = traversedTransforms.getAllChildCharacters()
        var newProperties = [Character: ChildType]()
        for childChar in childChars {
            guard let traversedChild = traversedTransforms.traverseChild(childChar) else { throw TransformErrors.transformFailed }
            if traversedChild.isEmpty() { throw TransformErrors.transformFailed }
            let newChildAfterInsertion = try insertAll(childChar: childChar, transforms: traversedChild)
            let newChild = ChildType(node: newChildAfterInsertion)
            newProperties[childChar] = newChild
        }
        let transform = traversedTransforms.get([""])
        if let transform = transform {
            switch transform {
            case .insert(let newValue):
                guard let newValue = ValueType(newValue) else { throw TransformErrors.transformFailed }
                return Self(prefix: childPrefix, value: newValue, children: newProperties)
            default:
                throw TransformErrors.transformFailed
            }
        }
        return Self(prefix: childPrefix, value: nil, children: newProperties)
    }
    
    func transform(transforms: ArrayTrie<Transform>) throws -> Self? {
        guard let childPrefix = transforms.getChildPrefix(char: prefix.first!) else { throw TransformErrors.transformFailed }
        let childPrefixSlice = ArraySlice(childPrefix)
        let prefixSlice = ArraySlice(prefix)
        let comparison = compareSlices(childPrefixSlice, prefixSlice)
        if comparison == 0 {
            guard let traversedChild = transforms.traverse(path: childPrefix) else { throw TransformErrors.transformFailed }
            if traversedChild.isEmpty() { throw TransformErrors.transformFailed }
            if let transform = traversedChild.get([""]) {
                switch transform {
                case .update(let newValue):
                    let newChildren = try transformChildren(transforms: traversedChild)
                    guard let newValue = ValueType(newValue) else { throw TransformErrors.transformFailed }
                    return Self(prefix: prefix, value: newValue, children: newChildren)
                case .delete:
                    let newChildren = try transformChildren(transforms: traversedChild)
                    if newChildren.count == 0 {
                        return nil
                    }
                    if newChildren.count == 1 {
                        guard let childValue = newChildren.first?.value.node else { throw TransformErrors.transformFailed }
                        return Self(prefix: prefix + childValue.prefix, value: childValue.value, children: childValue.children)
                    }
                    return Self(prefix: prefix, value: nil, children: newChildren)
                default:
                    throw TransformErrors.transformFailed
                }
            }
            let newChildren = try transformChildren(transforms: traversedChild)
            if value != nil {
                return Self(prefix: prefix, value: value, children: newChildren)
            }
            if newChildren.count == 0 {
                return nil
            }
            if newChildren.count == 1 {
                guard let childValue = newChildren.first?.value.node else { throw TransformErrors.transformFailed }
                return Self(prefix: prefix + childValue.prefix, value: childValue.value, children: childValue.children)
            }
            return Self(prefix: prefix, value: nil, children: newChildren)
        }
        if comparison == 1 {
            let remainingChildPrefix = childPrefixSlice.dropFirst(prefix.count)
            guard let traversedChild = transforms.traverse(path: prefix) else { throw TransformErrors.transformFailed }
            let childChar = remainingChildPrefix.first!
            if let child = children[childChar] {
                guard let childNode = child.node else { throw TransformErrors.missingData }
                if let newChild = try childNode.transform(transforms: traversedChild) {
                    var newChildren = children
                    newChildren[childChar] = ChildType(node: newChild)
                    return Self(prefix: prefix, value: value, children: newChildren)
                }
                else {
                    var newChildren = children
                    newChildren.removeValue(forKey: childChar)
                    if value != nil {
                        return Self(prefix: prefix, value: value, children: newChildren)
                    }
                    if newChildren.count == 0 {
                        return nil
                    }
                    if newChildren.count == 1 {
                        guard let childValue = newChildren.first?.value.node else { throw TransformErrors.transformFailed }
                        return Self(prefix: prefix + childValue.prefix, value: childValue.value, children: childValue.children)
                    }
                    return Self(prefix: prefix, value: nil, children: newChildren)
                }
            }
            else {
                let newChild = try Self.insertAll(childChar: childChar, transforms: traversedChild)
                var newChildren = children
                newChildren[childChar] = ChildType(node: newChild)
                return Self(prefix: prefix, value: value, children: newChildren)
            }
        }
        if comparison == 2 {
            let remainingPrefix = prefixSlice.dropFirst(childPrefix.count)
            guard let traversedChild = transforms.traverse(path: childPrefix) else { throw TransformErrors.transformFailed }
            var newChildren = [Character: ChildType]()
            for childChar in traversedChild.getAllChildCharacters() {
                if childChar == remainingPrefix.first! {
                    guard let childTransform = traversedChild.traverseChild(childChar) else { throw TransformErrors.transformFailed }
                    if let newChild = try Self(prefix: String(remainingPrefix), value: value, children: children).transform(transforms: childTransform) {
                        newChildren[childChar] = ChildType(node: newChild)
                    }
                }
                else {
                    guard let childTransform = traversedChild.traverseChild(childChar) else { throw TransformErrors.transformFailed }
                    let newChild = try Self.insertAll(childChar: childChar, transforms: childTransform)
                    newChildren[childChar] = ChildType(node: newChild)
                }
            }
            if let newValue = traversedChild.get([""]) {
                switch newValue {
                case .insert(let newValue):
                    guard let newValue = ValueType(newValue) else { throw TransformErrors.transformFailed }
                    return Self(prefix: childPrefix, value: newValue, children: newChildren)
                default: throw TransformErrors.transformFailed
                }
            }
            if newChildren.count == 0 {
                return nil
            }
            if newChildren.count == 1 {
                guard let childValue = newChildren.first?.value.node else { throw TransformErrors.transformFailed }
                return Self(prefix: childPrefix + childValue.prefix, value: childValue.value, children: childValue.children)
            }
            return Self(prefix: childPrefix, value: nil, children: newChildren)
        }
        let common = commonPrefixString(prefixSlice, childPrefixSlice)
        let prefixSliceRemainder = String(prefixSlice.dropFirst(common.count))
        let childPrefixSliceRemainder = String(childPrefixSlice.dropFirst(common.count))
        guard let childTransforms = transforms.traverse(path: common)?.traverseChild(childPrefixSliceRemainder.first!) else { throw TransformErrors.transformFailed }
        let newChild = try Self.insertAll(childChar: childPrefixSliceRemainder.first!, transforms: childTransforms)
        var newChildren = [Character: ChildType]()
        newChildren[childPrefixSliceRemainder.first!] = ChildType(node: newChild)
        newChildren[prefixSliceRemainder.first!] = ChildType(node: Self(prefix: String(prefixSliceRemainder), value: value, children: children))
        return Self(prefix: common, value: nil, children: newChildren)
    }
    
    func transformChildren(transforms: ArrayTrie<Transform>) throws -> [Character: ChildType] {
        var newChildren = [Character: ChildType]()
        let allChildChars = Set().union(transforms.getAllChildCharacters()).union(children.keys)
        for childChar in allChildChars {
            if let transformChild = transforms.traverseChild(childChar) {
                if let currentChild = children[childChar] {
                    if let transformedChild = try currentChild.transform(transforms: transformChild) {
                        newChildren[childChar] = transformedChild
                    }
                    else {
                        newChildren.removeValue(forKey: childChar)
                    }
                }
                else {
                    let newChild = try Self.insertAll(childChar: childChar, transforms: transformChild)
                    newChildren[childChar] = ChildType(node: newChild)
                }
            }
            else {
                if let currentChild = children[childChar] {
                    newChildren[childChar] = currentChild
                }
                else {
                    throw TransformErrors.transformFailed
                }
            }
        }
        return newChildren
    }
    
    func get(key: ArraySlice<Character>) throws -> ValueType? {
        let prefixSlice = ArraySlice(prefix)

        if key.elementsEqual(prefixSlice) {
            return value
        }
        
        // If the remaining key starts with the compressed path, consume it
        if key.starts(with: prefixSlice) {
            let newKey = key.dropFirst(prefixSlice.count)
            guard let childChar = newKey.first else { return value }
            guard let child = children[childChar] else { return nil }
            guard let childNode = child.node else { throw TransformErrors.missingData }
            return try childNode.get(key: newKey)
        }
        
        // Otherwise, no match
        return nil
    }
    
    func deleting(key: ArraySlice<Character>) throws -> Self? {
        let prefixSlice = ArraySlice(prefix)
        let comparison = compareSlices(key, prefixSlice)
        if comparison == 0 {
            if children.count == 0 {
                return nil
            }
            if children.count == 1 {
                guard let childNode = children.first!.value.node else { throw TransformErrors.missingData }
                return Self(prefix: prefix + childNode.prefix, value: childNode.value, children: childNode.children)
            }
            return Self(prefix: prefix, value: nil, children: children)
        }
        if comparison == 1 {
            let newKey = key.dropFirst(prefixSlice.count)
            let childChar = newKey.first!
            guard let child = children[childChar] else { throw TransformErrors.invalidKey }
            let newChild = try child.deleting(key: newKey)
            if let newChild = newChild {
                var newChildren = children
                newChildren[childChar] = newChild
                return Self(prefix: prefix, value: value, children: newChildren)
            }
            if children.count == 1 && value == nil { return nil  }
            var newChildren = children
            newChildren.removeValue(forKey: childChar)
            if newChildren.count == 1 && value == nil {
                guard let childNode = newChildren.first?.value.node else { throw TransformErrors.missingData }
                return Self(prefix: prefix + childNode.prefix, value: childNode.value, children: childNode.children)
            }
            return Self(prefix: prefix, value: value, children: newChildren)
        }
        throw TransformErrors.invalidKey
    }
    
    func mutating(key: ArraySlice<Character>, value: ValueType) throws -> Self {
        let selfPathSlice = ArraySlice(prefix)
        let comparison = compareSlices(key, selfPathSlice)
        if comparison == 0 {
            if self.value == nil { throw TransformErrors.invalidKey }
            return Self(prefix: prefix, value: value, children: children)
        }
        if comparison == 1 {
            let keyRemainder = key.dropFirst(selfPathSlice.count)
            let keyChar = keyRemainder.first!
            if let child = children[keyChar] {
                let updatedChild = try child.mutating(key: keyRemainder, value: value)
                var newChildren = children
                newChildren[keyChar] = updatedChild
                return Self(prefix: prefix, value: self.value, children: newChildren)
            } else {
                throw TransformErrors.invalidKey
            }
        }
        throw TransformErrors.invalidKey
    }

    
    func inserting(key: ArraySlice<Character>, value: ValueType) throws -> Self {
        let selfPathSlice = ArraySlice(prefix)
        let comparison = compareSlices(key, selfPathSlice)
        if comparison == 0 {
            if self.value != nil { throw TransformErrors.invalidKey }
            return Self(prefix: prefix, value: value, children: children)
        }
        if comparison == 1 {
            let keyRemainder = key.dropFirst(selfPathSlice.count)
            let keyChar = keyRemainder.first!
            if let child = children[keyChar] {
                let updatedChild = try child.inserting(key: keyRemainder, value: value)
                var newChildren = children
                newChildren[keyChar] = updatedChild
                return Self(prefix: prefix, value: self.value, children: newChildren)
            } else {
                let newChild = ChildType(node: Self(prefix: String(keyRemainder), value: value, children: [:]))
                var newChildren = children
                newChildren[keyChar] = newChild
                return Self(prefix: prefix, value: self.value, children: newChildren)
            }
        }
        if comparison == 2 {
            let remainingPath = String(selfPathSlice.dropFirst(key.count))
            let existingChild = ChildType(node: Self(prefix: remainingPath, value: self.value, children: children))
            let newChildren = [remainingPath.first!:existingChild]
            return Self(prefix: String(key), value: value, children: newChildren)
        }
        // Paths diverge, need to split at common prefix
        let common = commonPrefixString(key, selfPathSlice)
        let keyRemainder = String(key.dropFirst(common.count))
        let pathRemainder = String(selfPathSlice.dropFirst(common.count))
        
        // Create child for existing path
        let existingChild = ChildType(node: Self(prefix: pathRemainder, value: self.value, children: children))
        let newChild = ChildType(node: Self(prefix: keyRemainder, value: value, children: [:]))
        let newChildren = [pathRemainder.first!: existingChild, keyRemainder.first!: newChild]
        
        return Self(prefix: common, value: nil, children: newChildren)
    }
}
