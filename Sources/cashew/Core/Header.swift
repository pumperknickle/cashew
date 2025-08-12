import Foundation
import ArrayTrie
import CID
import Multicodec
import Multihash
import Crypto

public protocol Header: Codable, Address, LosslessStringConvertible {
    associatedtype NodeType: Node
    
    var rawCID: String { get }
    var node: NodeType? { get }
    
    init(rawCID: String)
    init(node: NodeType)
    init(node: NodeType, codec: Codecs)
    
    init(rawCID: String, node: NodeType?)
}

public extension Header {
    init(rawCID: String) {
        self = Self(rawCID: rawCID, node: nil)
    }
    
    init(node: NodeType) {
        self = Self(rawCID: Self.createSyncCID(for: node, codec: Self.defaultCodec), node: node)
    }
    
    init(node: NodeType, codec: Codecs) {
        self = Self(rawCID: Self.createSyncCID(for: node, codec: codec), node: node)
    }
        
    static var defaultCodec: Codecs { .dag_json }
    
    static func create(node: NodeType, codec: Codecs = defaultCodec) async throws -> Self {
        let cid = try await createCID(for: node, codec: codec)
        return Self(rawCID: cid, node: node)
    }
    
    private static func createCID(for node: NodeType, codec: Codecs) async throws -> String {
        let data = try serializeNode(node, codec: codec)
        let multihash = try Multihash(raw: data, hashedWith: .sha2_256)
        let cid = try CID(version: .v1, codec: codec, multihash: multihash)
        return cid.toBaseEncodedString
    }
    
    static func createSyncCID(for node: NodeType, codec: Codecs) -> String {
        do {
            let data = try serializeNode(node, codec: codec)
            let multihash = try Multihash(raw: data, hashedWith: .sha2_256)
            let cid = try CID(version: .v1, codec: codec, multihash: multihash)
            return cid.toBaseEncodedString
        } catch {
            return "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
        }
    }
    
    private static func serializeNode(_ node: NodeType, codec: Codecs) throws -> Data {
        switch codec.name {
        case "dag-json":
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return try encoder.encode(node.toData())
        case "dag-cbor", "dag-pb", "raw":
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return try encoder.encode(node.toData())
        default:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return try encoder.encode(node.toData())
        }
    }
    
    func mapToData() throws -> Data {
        guard let node = self.node else {
            throw DataErrors.nodeNotAvailable
        }
        return try Self.serializeNode(node, codec: Self.defaultCodec)
    }
    
    func recreateCID() async throws -> String {
        guard let node = self.node else {
            return rawCID
        }
        return try await Self.createCID(for: node, codec: Self.defaultCodec)
    }
    
    func recreateCID(withCodec codec: Codecs) async throws -> String {
        guard let node = self.node else {
            throw DataErrors.nodeNotAvailable
        }
        return try await Self.createCID(for: node, codec: codec)
    }
    
    var description: String {
        return rawCID
    }
    
    init?(_ description: String) {
        self.init(rawCID: description)
    }
    
    func removingNode() -> Self {
        return Self(rawCID: rawCID)
    }
    
    func transform(transforms: ArrayTrie<Transform>) throws -> Self? {
        guard let node = node else { throw DataErrors.nodeNotAvailable }
        guard let result = try node.transform(transforms: transforms) else { return nil }
        return Self(node: node)
    }
}
