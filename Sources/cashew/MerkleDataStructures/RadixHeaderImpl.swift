import Foundation
import Multicodec

public struct RadixHeaderImpl<Value>: RadixHeader where Value: Codable, Value: Sendable, Value: LosslessStringConvertible {
    public typealias NodeType = RadixNodeImpl<Value>
    
    public let rawCID: String
    public let rawNode: Box<NodeType>?
    
    public var node: NodeType? {
        return rawNode?.boxed
    }
    
    public init(rawCID: String, node: NodeType?) {
        self.rawCID = rawCID
        self.rawNode = node == nil ? nil : Box(node!)
    }
    
    public init(node: NodeType) {
        self.rawNode = Box(node)
        self.rawCID = Self.createSyncCID(for: node, codec: Self.defaultCodec)
    }
    
    public init(node: NodeType, codec: Codecs) {
        self.rawNode = Box(node)
        self.rawCID = Self.createSyncCID(for: node, codec: codec)
    }
}

// MARK: - Codable
extension RadixHeaderImpl: Codable {
    enum CodingKeys: String, CodingKey {
        case rawCID, node
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rawCID, forKey: .rawCID)
        try container.encodeIfPresent(node, forKey: .node)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rawCID = try container.decode(String.self, forKey: .rawCID)
        let nodeValue = try container.decodeIfPresent(NodeType.self, forKey: .node)
        rawNode = nodeValue.map { Box($0) }    }
}
