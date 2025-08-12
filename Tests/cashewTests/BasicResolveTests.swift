import Testing
import Foundation
import ArrayTrie
@preconcurrency import Multicodec
@testable import cashew

@Suite("Basic Resolve Functionality Tests")
struct BasicResolveTests {
    
    // Simple mock implementations that work well with LosslessStringConvertible
    struct SimpleNode: Node, Sendable {
        
        let id: String
        let isLeaf: Bool
        
        init(id: String, isLeaf: Bool = false) {
            self.id = id
            self.isLeaf = isLeaf
        }
        
        func get(property: PathSegment) -> Address? {
            if isLeaf { return nil }
            return SimpleHeader(rawCID: "\(id)-\(property)")
        }
        
        func properties() -> Set<PathSegment> {
            if isLeaf { return [] }
            return ["child1", "child2"]
        }
        
        func set(property: PathSegment, to child: Address) -> Self {
            return self // Simplified for testing
        }
        
        func set(properties: [PathSegment: Address]) -> Self {
            return self // Simplified for testing
        }
        
        // MARK: - Codable
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(isLeaf, forKey: .isLeaf)
        }
        
        enum CodingKeys: String, CodingKey {
            case id, isLeaf
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            isLeaf = try container.decodeIfPresent(Bool.self, forKey: .isLeaf) ?? false
        }
        
        // MARK: - LosslessStringConvertible
        var description: String {
            if isLeaf {
                return "SimpleNode(\(id),leaf)"
            }
            return "SimpleNode(\(id))"
        }
        
        init?(_ description: String) {
            if description.hasPrefix("SimpleNode(") && description.hasSuffix(")") {
                let content = String(description.dropFirst(11).dropLast(1))
                let parts = content.split(separator: ",")
                if parts.count >= 1 {
                    let id = String(parts[0])
                    let isLeaf = parts.count > 1 && parts[1] == "leaf"
                    self.init(id: id, isLeaf: isLeaf)
                } else {
                    return nil
                }
            } else {
                return nil
            }
        }
    }
    
    struct SimpleHeader: Header {
        let rawCID: String
        let node: SimpleNode?
        
        init(rawCID: String) {
            self.rawCID = rawCID
            self.node = nil
        }
        
        init(rawCID: String, node: SimpleNode?) {
            self.rawCID = rawCID
            self.node = node
        }
        
        init(node: SimpleNode) {
            self.node = node
            self.rawCID = Self.createSyncCID(for: node, codec: Self.defaultCodec)
        }
        
        init(node: SimpleNode, codec: Codecs) {
            self.node = node
            self.rawCID = Self.createSyncCID(for: node, codec: codec)
        }
    }
    
    final class SimpleFetcher: Fetcher, Sendable {
        private let responses: [String: String]
        
        init(responses: [String: String] = [:]) {
            self.responses = responses
        }
        
        func fetch(rawCid: String) async throws -> Data {
            let nodeDescription = responses[rawCid] ?? "SimpleNode(fetched-\(rawCid),leaf)"
            // Create SimpleNode from description and return its JSON data
            if let node = SimpleNode(nodeDescription) {
                return node.toData() ?? Data()
            }
            // Fallback: create a leaf node
            let leafNode = SimpleNode(id: "fetched-\(rawCid)", isLeaf: true)
            return leafNode.toData() ?? Data()
        }
    }
    
    // MARK: - Basic Resolve Tests
    
    @Test("Header resolve fetches and reconstructs node from CID")
    func testBasicHeaderResolve() async throws {
        let cid = "test-cid-123"
        let header = HeaderImpl<SimpleNode>(rawCID: cid)
        
        let fetcher = SimpleFetcher(responses: [cid: "SimpleNode(fetched-node,leaf)"])
        
        let resolvedHeader = try await header.resolve(fetcher: fetcher)
        
        #expect(resolvedHeader.rawCID == cid)
        #expect(resolvedHeader.node?.id == "fetched-node")
    }
    
    @Test("Header resolveRecursive fetches and processes node")
    func testHeaderResolveRecursive() async throws {
        let cid = "recursive-cid-456"
        let header = HeaderImpl<SimpleNode>(rawCID: cid)
        
        let fetcher = SimpleFetcher(responses: [cid: "SimpleNode(recursive-node,leaf)"])
        
        let resolvedHeader = try await header.resolveRecursive(fetcher: fetcher)
        
        #expect(resolvedHeader.rawCID == cid)
        #expect(resolvedHeader.node?.id == "recursive-node")
    }
    
    @Test("Header resolve with existing node doesn't fetch")
    func testHeaderResolveWithExistingNode() async throws {
        let node = SimpleNode(id: "existing")
        let header = HeaderImpl(node: node)
        let fetcher = SimpleFetcher() // Empty fetcher - should not be called
        
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["child1"], value: .targeted)
        
        let resolvedHeader = try await header.resolve(paths: paths, fetcher: fetcher)
        
        #expect(resolvedHeader.node?.id == "existing")
    }
    
    @Test("Content addressability verification")
    func testContentAddressability() async throws {
        // Create a node and get its CID
        let originalNode = SimpleNode(id: "content-test")
        let originalHeader = try await HeaderImpl.create(node: originalNode)
        let originalCID = originalHeader.rawCID
        
        // Simulate fetching from storage
        let fetcher = SimpleFetcher(responses: [originalCID: originalNode.description])
        
        // Create header with just CID and resolve
        let cidOnlyHeader = HeaderImpl<SimpleNode>(rawCID: originalCID)
        let resolvedHeader = try await cidOnlyHeader.resolve(fetcher: fetcher)
        
        // Verify content addressability
        #expect(resolvedHeader.rawCID == originalCID)
        #expect(resolvedHeader.node?.id == "content-test")
        
        // Verify we can recreate the same CID
        let recreatedCID = try await resolvedHeader.recreateCID()
        #expect(recreatedCID == originalCID)
    }
    
    @Test("Multiple resolve operations produce consistent results")
    func testResolveConsistency() async throws {
        let node = SimpleNode(id: "consistent")
        let header = try await HeaderImpl.create(node: node)
        let cid = header.rawCID
        
        let fetcher = SimpleFetcher(responses: [cid: node.description])
        
        // Perform multiple resolve operations
        let cidHeader1 = HeaderImpl<SimpleNode>(rawCID: cid)
        let cidHeader2 = HeaderImpl<SimpleNode>(rawCID: cid)
        
        let resolved1 = try await cidHeader1.resolve(fetcher: fetcher)
        let resolved2 = try await cidHeader2.resolve(fetcher: fetcher)
        
        // Both should produce the same results
        #expect(resolved1.rawCID == resolved2.rawCID)
        #expect(resolved1.node?.id == resolved2.node?.id)
        
        // Verify CID recreation is consistent
        let recreated1 = try await resolved1.recreateCID()
        let recreated2 = try await resolved2.recreateCID()
        #expect(recreated1 == recreated2)
        #expect(recreated1 == cid)
    }
    
    @Test("Node resolve processing")
    func testNodeResolve() async throws {
        let node = SimpleNode(id: "node-resolve-test")
        // Create a fetcher that returns leaf nodes to avoid infinite recursion
        let fetcher = SimpleFetcher(responses: [
            "node-resolve-test-child1": "SimpleNode(leaf1,leaf)"
        ])
        
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["child1"], value: .targeted)
        
        let resolvedNode = try await node.resolve(paths: paths, fetcher: fetcher)
        
        // Should return a processed version of the node
        #expect(resolvedNode.id == "node-resolve-test")
        #expect(resolvedNode.properties().contains("child1"))
        #expect(resolvedNode.properties().contains("child2"))
    }
    
    @Test("Node resolveRecursive processing")
    func testNodeResolveRecursive() async throws {
        let node = SimpleNode(id: "recursive-node-test")
        // Create a fetcher with leaf nodes to avoid infinite recursion
        let fetcher = SimpleFetcher(responses: [
            "recursive-node-test-child1": "SimpleNode(leaf1,leaf)",
            "recursive-node-test-child2": "SimpleNode(leaf2,leaf)"
        ])
        
        let resolvedNode = try await node.resolveRecursive(fetcher: fetcher)
        
        // Should return the same node since SimpleNode doesn't have complex children
        #expect(resolvedNode.id == "recursive-node-test")
    }
}
