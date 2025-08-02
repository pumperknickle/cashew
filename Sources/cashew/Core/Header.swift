import Foundation
import ArrayTrie

public protocol Header: Address, LosslessStringConvertible {
    associatedtype NodeType: Node
    
    var rawCID: String { get }
    var node: NodeType? { get }
    
    init(rawCID: String)
    init(rawCID: String, node: NodeType)
    init(node: NodeType)
}
