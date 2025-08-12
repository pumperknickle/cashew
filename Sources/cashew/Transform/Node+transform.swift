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

        for property in properties() {
            guard let address = get(property: property) else { throw TransformErrors.transformFailed }
            if let newTransforms = transforms.traverse([property]) {
                guard let newAddress = try address.transform(transforms: newTransforms) else { throw TransformErrors.transformFailed }
                newProperties[property] = newAddress
            }
            else {
                newProperties[property] = address
            }
        }
        
        return set(properties: newProperties)
    }
}
