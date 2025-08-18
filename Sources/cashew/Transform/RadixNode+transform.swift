import ArrayTrie

public extension RadixNode {
    func transform(transforms: ArrayTrie<Transform>) throws -> Self? {
        return self
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
            return childNode.value
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
    
    @inline(__always)
    private func compareSlices(_ slice1: ArraySlice<Character>, _ slice2: ArraySlice<Character>) -> Int {
        if (slice1.elementsEqual(slice2)) { return 0 }
        if (slice1.starts(with: slice2)) { return 1 }
        if (slice2.starts(with: slice1)) { return 2 }
        else { return 3 }
    }
    
    @inline(__always)
    private func commonPrefixString(_ slice1: ArraySlice<Character>, _ slice2: ArraySlice<Character>) -> String {
        return commonPrefix(slice1, slice2)
    }
    
    private func commonPrefix(_ slice1: ArraySlice<Character>, _ slice2: ArraySlice<Character>) -> String {
        // Optimize: Pre-allocate string capacity and avoid repeated memory allocations
        let maxLength = min(slice1.count, slice2.count)
        var result = ""
        result.reserveCapacity(maxLength)
        
        let pairs = zip(slice1, slice2)
        for (char1, char2) in pairs {
            if char1 == char2 {
                result.append(char1)
            } else {
                break
            }
        }
        
        return result
    }
}
