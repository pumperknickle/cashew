import ArrayTrie
import CollectionConcurrencyKit

public extension Node {    
    func transform(transforms: ArrayTrie<Transform>) throws -> Self? {
        if transforms.isEmpty() { return self }
        switch transforms.get([]) {
            case .update(let newNodeString): return try Self(newNodeString)?.transformAterUpdate(transforms: transforms)
            default: return try transformAterUpdate(transforms: transforms)
        }
    }
    
    func transformAterUpdate(transforms: ArrayTrie<Transform>) throws -> Self? {
        var newProperties: [PathSegment: Address] = [:]
        
        let allChildKeys = Set<String>().union(transforms.getAllChildKeys()).union(properties())
        
        for childKey in allChildKeys {
            guard let address = get(property: childKey) else { throw TransformErrors.transformFailed }
            if let newTransforms = transforms.traverse([childKey]) {
                guard let newAddress = try address.transform(transforms: newTransforms) else { throw TransformErrors.transformFailed }
                newProperties[childKey] = newAddress
            }
            else {
                newProperties[childKey] = address
            }
        }
        
        return set(properties: newProperties)
    }
}
