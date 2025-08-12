import Foundation
import Multicodec

public struct RadixHeaderImpl<Value>: RadixHeader where Value: Codable, Value: Sendable, Value: LosslessStringConvertible {
    public typealias NodeType = RadixNodeImpl<Value>
    
    public var rawCID: String
    public var node: NodeType?
    
    public init(rawCID: String, node: NodeType?) {
        self.rawCID = rawCID
        self.node = node
    }
    
    public init(node: NodeType) {
        self.node = node
        self.rawCID = Self.createSyncCID(for: node, codec: Self.defaultCodec)
    }
    
    public init(node: NodeType, codec: Codecs) {
        self.node = node
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
        node = try container.decodeIfPresent(NodeType.self, forKey: .node)
    }
}
