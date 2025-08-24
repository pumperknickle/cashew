import Foundation
import Multicodec

public struct HeaderImpl<NodeType: Node>: Header {
    public let rawCID: String
    public let rawNode: Box<NodeType>?
    
    public var node: NodeType? {
        return rawNode?.boxed
    }
    
    public init(rawCID: String) {
        self.rawCID = rawCID
        self.rawNode = nil
    }
    
    public init(rawCID: String, node: NodeType?) {
        self.rawCID = rawCID
        self.rawNode = node.map { Box($0) }
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

extension HeaderImpl: Codable where NodeType: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rawCID, forKey: .rawCID)
        try container.encodeIfPresent(rawNode?.boxed, forKey: .node)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rawCID = try container.decode(String.self, forKey: .rawCID)
        let nodeValue = try container.decodeIfPresent(NodeType.self, forKey: .node)
        rawNode = nodeValue.map { Box($0) }
    }
    
    private enum CodingKeys: String, CodingKey {
        case rawCID
        case node
    }
}


public final class Box<T: Sendable>: Sendable {
   let boxed: T
   init(_ thingToBox: T) { boxed = thingToBox }
}

extension Box: Codable where T: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(boxed)
    }
    
    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(T.self)
        self.init(value)
    }
}
