import ArrayTrie
import CollectionConcurrencyKit

public protocol Node: LosslessStringConvertible {
    typealias PathSegment = String

    // traversal
    func get(property: PathSegment) -> Address
    func properties() -> Set<PathSegment>
    
    // update
    func set(property: PathSegment, to child: Address) -> Self
    func set(properties: [PathSegment: Address]) -> Self
}
