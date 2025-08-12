import Foundation
import Multicodec

public struct HeaderImpl<NodeType: Node>: Header {
    public let rawCID: String
    public let node: NodeType?
    
    public init(rawCID: String) {
        self.rawCID = rawCID
        self.node = nil
    }
    
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
