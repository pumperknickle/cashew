import Testing
import Foundation
import ArrayTrie
import CID
@preconcurrency import Multicodec
import Multihash
@testable import cashew

@Suite("Resolve Functionality Tests")
struct ResolveTests {
    
    // MARK: - Mock Implementations for Testing
    
    struct MockNode: Node, Sendable {
        let id: String
        
        init(id: String) {
            self.id = id
        }
        
        func get(property: PathSegment) -> Address? {
            return MockHeader(rawCID: "\(id)-\(property)")
        }
        
        func properties() -> Set<PathSegment> {
            return ["child1", "child2"]
        }
        
        func set(property: PathSegment, to child: Address) -> Self {
            return self
        }
        
        func set(properties: [PathSegment: Address]) -> Self {
            return self
        }
        
        // MARK: - Codable
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(id)
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            id = try container.decode(String.self)
        }
    }
    
    struct MockResolvedNode: Node, Sendable {
        let id: String
        let data: [String: String]
        let childNodes: [String: MockResolvedNode]
        
        init(id: String, data: [String: String] = [:], childNodes: [String: MockResolvedNode] = [:]) {
            self.id = id
            self.data = data
            self.childNodes = childNodes
        }
        
        func get(property: PathSegment) -> Address? {
            if let childNode = childNodes[property] {
                return HeaderImpl(node: childNode)
            }
            if let value = data[property] {
                return HeaderImpl<MockResolvedNode>(rawCID: value)
            }
            return nil
        }
        
        func properties() -> Set<PathSegment> {
            var props = Set(data.keys)
            props.formUnion(Set(childNodes.keys))
            return props
        }
        
        func set(property: PathSegment, to child: Address) -> Self {
            var newData = data
            let newChildNodes = childNodes
            
            if let mockHeader = child as? MockHeader {
                newData[property] = mockHeader.rawCID
            }
            
            return MockResolvedNode(id: id, data: newData, childNodes: newChildNodes)
        }
        
        func set(properties: [PathSegment: Address]) -> Self {
            var newData = data
            let newChildNodes = childNodes
            
            for (key, address) in properties {
                if let mockHeader = address as? MockHeader {
                    newData[key] = mockHeader.rawCID
                }
            }
            
            return MockResolvedNode(id: id, data: newData, childNodes: newChildNodes)
        }
        
        // MARK: - Codable
        enum CodingKeys: String, CodingKey {
            case id, data, childNodes
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(data, forKey: .data)
            try container.encode(childNodes, forKey: .childNodes)
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            data = try container.decode([String: String].self, forKey: .data)
            childNodes = try container.decode([String: MockResolvedNode].self, forKey: .childNodes)
        }
    }
    
    struct MockHeader: Header {
        let rawCID: String
        let node: MockNode?
        
        init(rawCID: String) {
            self.rawCID = rawCID
            self.node = nil
        }
        
        init(rawCID: String, node: MockNode?) {
            self.rawCID = rawCID
            self.node = node
        }
        
        init(node: MockNode) {
            self.node = node
            self.rawCID = Self.createSyncCID(for: node, codec: Self.defaultCodec)
        }
        
        init(node: MockNode, codec: Codecs) {
            self.node = node
            self.rawCID = Self.createSyncCID(for: node, codec: codec)
        }
    }
    
    final class MockFetcher: Fetcher, Sendable {
        private let responses: [String: Data]
        
        init(responses: [String: Data] = [:]) {
            self.responses = responses
        }
        
        func fetch(rawCid: String) async throws -> Data {
            if let data = responses[rawCid] {
                return data
            }
            
            // Default response for unregistered CIDs - return leaf node to prevent infinite recursion
            let mockResolvedNode = MockResolvedNode(id: "fetched-\(rawCid)", data: [:])
            return mockResolvedNode.toData() ?? Data()
        }
    }
    
    // MARK: - Header Resolve Tests
    
    @Test("Header resolve with existing node - no fetching required")
    func testHeaderResolveWithExistingNode() async throws {
        let node = MockResolvedNode(id: "test-node", data: ["key1": "value1"])
        let header = HeaderImpl(node: node)
        let fetcher = MockFetcher()
        
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["key1"], value: .targeted)
        
        let resolvedHeader = try await header.resolve(paths: paths, fetcher: fetcher)
        
        #expect(resolvedHeader.rawCID == header.rawCID)
        #expect(resolvedHeader.node?.id == "test-node")
    }
    
    @Test("Header resolve without node - fetches from CID")
    func testHeaderResolveWithoutNode() async throws {
        let cid = "bafkreihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku"
        let header = HeaderImpl<MockResolvedNode>(rawCID: cid)
        
        let mockNode = MockResolvedNode(id: "fetched-node", data: ["fetched": "true"])
        let mockData = mockNode.toData()!
        let fetcher = MockFetcher(responses: [cid: mockData])
        
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["fetched"], value: .targeted)
        
        let resolvedHeader = try await header.resolve(paths: paths, fetcher: fetcher)
        
        #expect(resolvedHeader.rawCID == cid)
        #expect(resolvedHeader.node?.id == "fetched-node")
        #expect(resolvedHeader.node?.data["fetched"] == "true")
    }
    
    @Test("Header resolveRecursive with existing node")
    func testHeaderResolveRecursiveWithExistingNode() async throws {
        let childNodes = [
            "child1": MockResolvedNode(id: "child1", data: ["nested": "data1"]),
            "child2": MockResolvedNode(id: "child2", data: ["nested": "data2"])
        ]
        let node = MockResolvedNode(id: "parent-node", data: ["key1": "value1"], childNodes: childNodes)
        let header = HeaderImpl(node: node)
        let fetcher = MockFetcher()
        
        let resolvedHeader = try await header.resolveRecursive(fetcher: fetcher)
        
        #expect(resolvedHeader.rawCID == header.rawCID)
        #expect(resolvedHeader.node?.id == "parent-node")
    }
    
    @Test("Header resolveRecursive without node - fetches from CID")
    func testHeaderResolveRecursiveWithoutNode() async throws {
        let cid = "bafkreihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku"
        let header = HeaderImpl<MockResolvedNode>(rawCID: cid)
        
        let mockNode = MockResolvedNode(id: "fetched-recursive", data: ["recursive": "true"])
        let mockData = mockNode.toData()!
        let fetcher = MockFetcher(responses: [cid: mockData])
        
        let resolvedHeader = try await header.resolveRecursive(fetcher: fetcher)
        
        #expect(resolvedHeader.rawCID == cid)
        #expect(resolvedHeader.node?.id == "fetched-recursive")
        #expect(resolvedHeader.node?.data["recursive"] == "true")
    }
    
    @Test("Header resolve basic - fetches node when missing")
    func testHeaderResolveBasic() async throws {
        let cid = "bafkreihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku"
        let header = HeaderImpl<MockResolvedNode>(rawCID: cid)
        
        let mockNode = MockResolvedNode(id: "basic-resolved", data: ["basic": "true"])
        let mockData = mockNode.toData()!
        let fetcher = MockFetcher(responses: [cid: mockData])
        
        let resolvedHeader = try await header.resolve(fetcher: fetcher)
        
        #expect(resolvedHeader.rawCID == cid)
        #expect(resolvedHeader.node?.id == "basic-resolved")
        #expect(resolvedHeader.node?.data["basic"] == "true")
    }
    
    @Test("Header resolve basic - returns self when node exists")
    func testHeaderResolveBasicWithExistingNode() async throws {
        let node = MockResolvedNode(id: "existing-node", data: ["exists": "true"])
        let header = HeaderImpl(node: node)
        let fetcher = MockFetcher()
        
        let resolvedHeader = try await header.resolve(fetcher: fetcher)
        
        #expect(resolvedHeader.rawCID == header.rawCID)
        #expect(resolvedHeader.node?.id == "existing-node")
        // Should have the same properties since no resolution was needed
        #expect(resolvedHeader.rawCID == header.rawCID)
        #expect(resolvedHeader.node?.id == header.node?.id)
    }
    
    @Test("Header resolve with dictionary paths")
    func testHeaderResolveWithDictionaryPaths() async throws {
        let node = MockResolvedNode(id: "dict-node", data: ["path1": "value1", "path2": "value2"])
        let header = HeaderImpl(node: node)
        let fetcher = MockFetcher()
        
        let paths = [["path1"]: ResolutionStrategy.targeted, ["path2"]: ResolutionStrategy.recursive]
        
        let resolvedHeader = try await header.resolve(paths: paths, fetcher: fetcher)
        
        #expect(resolvedHeader.rawCID == header.rawCID)
        #expect(resolvedHeader.node?.id == "dict-node")
    }
    
    @Test("Header resolve with empty paths returns self")
    func testHeaderResolveWithEmptyPaths() async throws {
        let node = MockResolvedNode(id: "empty-paths-node", data: ["key": "value"])
        let header = HeaderImpl(node: node)
        let fetcher = MockFetcher()
        
        let emptyPaths = ArrayTrie<ResolutionStrategy>()
        
        let resolvedHeader = try await header.resolve(paths: emptyPaths, fetcher: fetcher)
        
        // Should return the same structure since no resolution was needed
        #expect(resolvedHeader.rawCID == header.rawCID)
        #expect(resolvedHeader.node?.id == header.node?.id)
    }
    
    // MARK: - Cryptographic Hash Verification Tests
    
    @Test("Resolve maintains content addressability")
    func testResolveContentAddressability() async throws {
        let originalNode = MockResolvedNode(id: "original", data: ["content": "addressable"])
        let originalHeader = try await HeaderImpl.create(node: originalNode)
        let originalCID = originalHeader.rawCID
        
        // Serialize the node for fetching simulation
        let nodeData = originalNode.toData()!
        let fetcher = MockFetcher(responses: [originalCID: nodeData])
        
        // Create a header with just the CID (no node)
        let cidOnlyHeader = HeaderImpl<MockResolvedNode>(rawCID: originalCID)
        
        // Resolve to get the full node back
        let resolvedHeader = try await cidOnlyHeader.resolve(fetcher: fetcher)
        
        // Verify the CID remains the same (content addressability)
        #expect(resolvedHeader.rawCID == originalCID)
        #expect(resolvedHeader.node?.id == "original")
        #expect(resolvedHeader.node?.data["content"] == "addressable")
        
        // Verify we can recreate the same CID from the resolved node
        let recreatedCID = try await resolvedHeader.recreateCID()
        #expect(recreatedCID == originalCID)
    }
    
    @Test("Resolve verifies data integrity through hash")
    func testResolveDataIntegrityVerification() async throws {
        let originalNode = MockResolvedNode(id: "integrity-test", data: ["hash": "verification"])
        let originalHeader = try await HeaderImpl.create(node: originalNode, codec: .dag_json)
        let originalCID = originalHeader.rawCID
        
        // Create tampered data (different from original)
        let tamperedNode = MockResolvedNode(id: "tampered", data: ["hash": "corrupted"])
        let tamperedData = tamperedNode.toData()!
        
        let fetcher = MockFetcher(responses: [originalCID: tamperedData])
        let cidOnlyHeader = HeaderImpl<MockResolvedNode>(rawCID: originalCID)
        
        // Resolve with tampered data
        let resolvedHeader = try await cidOnlyHeader.resolve(fetcher: fetcher)
        
        // The resolved node should have the tampered data
        #expect(resolvedHeader.node?.id == "tampered")
        
        // But when we try to recreate the CID, it should be different
        // This demonstrates that content addressability helps detect tampering
        let newCID = try await resolvedHeader.recreateCID()
        #expect(newCID != originalCID)
    }
    
    @Test("Multiple resolve operations with same CID produce consistent results")
    func testMultipleResolveConsistency() async throws {
        let node = MockResolvedNode(id: "consistent", data: ["test": "consistency"])
        let header = try await HeaderImpl.create(node: node)
        let cid = header.rawCID
        
        let nodeData = node.toData()!
        let fetcher = MockFetcher(responses: [cid: nodeData])
        
        // Perform multiple resolve operations
        let cidHeader1 = HeaderImpl<MockResolvedNode>(rawCID: cid)
        let cidHeader2 = HeaderImpl<MockResolvedNode>(rawCID: cid)
        
        let resolved1 = try await cidHeader1.resolve(fetcher: fetcher)
        let resolved2 = try await cidHeader2.resolve(fetcher: fetcher)
        
        // Both should produce the same results
        #expect(resolved1.rawCID == resolved2.rawCID)
        #expect(resolved1.node?.id == resolved2.node?.id)
        #expect(resolved1.node?.data == resolved2.node?.data)
        
        // Verify CID recreation is consistent
        let recreated1 = try await resolved1.recreateCID()
        let recreated2 = try await resolved2.recreateCID()
        #expect(recreated1 == recreated2)
        #expect(recreated1 == cid)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Resolve handles fetcher errors gracefully")
    func testResolveHandlesFetcherErrors() async throws {
        let cid = "bafkreihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku"
        let header = HeaderImpl<MockResolvedNode>(rawCID: cid)
        
        // Create a fetcher that throws errors
        class ErrorFetcher: Fetcher {
            func fetch(rawCid: String) async throws -> Data {
                throw NSError(domain: "TestError", code: 404, userInfo: [NSLocalizedDescriptionKey: "CID not found"])
            }
        }
        
        let errorFetcher = ErrorFetcher()
        
        await #expect(throws: NSError.self) {
            try await header.resolve(fetcher: errorFetcher)
        }
    }
    
    @Test("Resolve handles invalid node data gracefully")
    func testResolveHandlesInvalidNodeData() async throws {
        let cid = "bafkreihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku"
        let header = HeaderImpl<MockResolvedNode>(rawCID: cid)
        
        // Return invalid JSON data that can't be decoded
        let invalidData = "invalid json".data(using: .utf8)!
        let fetcher = MockFetcher(responses: [cid: invalidData])
        
        await #expect(throws: (any Error).self) {
            try await header.resolve(fetcher: fetcher)
        }
    }
    
    // MARK: - Node Resolve Tests
    
    @Test("Node resolveRecursive resolves all properties")
    func testNodeResolveRecursive() async throws {
        let node = MockResolvedNode(id: "parent", data: ["child1": "address1", "child2": "address2"])
        // Provide leaf responses to prevent infinite recursion
        let leafNode1 = MockResolvedNode(id: "leaf1", data: [:])
        let leafNode2 = MockResolvedNode(id: "leaf2", data: [:])
        let fetcher = MockFetcher(responses: [
            "address1": leafNode1.toData()!,
            "address2": leafNode2.toData()!
        ])
        
        let resolvedNode = try await node.resolveRecursive(fetcher: fetcher)
        
        #expect(resolvedNode.id == "parent")
        // The properties should have been processed through resolve
        #expect(resolvedNode.properties().contains("child1"))
        #expect(resolvedNode.properties().contains("child2"))
    }
    
    @Test("Node resolve with targeted strategy")
    func testNodeResolveTargeted() async throws {
        let node = MockResolvedNode(id: "node-targeted", data: ["target": "value", "other": "ignored"])
        let leafNode = MockResolvedNode(id: "target-leaf", data: [:])
        let fetcher = MockFetcher(responses: [
            "value": leafNode.toData()!
        ])
        
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["target"], value: .targeted)
        
        let resolvedNode = try await node.resolve(paths: paths, fetcher: fetcher)
        
        #expect(resolvedNode.id == "node-targeted")
        #expect(resolvedNode.properties().contains("target"))
    }
    
    @Test("Node resolve with recursive strategy")
    func testNodeResolveRecursiveStrategy() async throws {
        let node = MockResolvedNode(id: "node-recursive", data: ["recursive-prop": "value"])
        let leafNode = MockResolvedNode(id: "recursive-leaf", data: [:])
        let fetcher = MockFetcher(responses: [
            "value": leafNode.toData()!
        ])
        
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["recursive-prop"], value: .recursive)
        
        let resolvedNode = try await node.resolve(paths: paths, fetcher: fetcher)
        
        #expect(resolvedNode.id == "node-recursive")
        #expect(resolvedNode.properties().contains("recursive-prop"))
    }
    
    @Test("Node resolve with nested paths")
    func testNodeResolveNestedPaths() async throws {
        let childNode = MockResolvedNode(id: "child", data: ["nested": "value"])
        let parentNode = MockResolvedNode(id: "parent", childNodes: ["child": childNode])
        let fetcher = MockFetcher()
        
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["child", "nested"], value: .targeted)
        
        let resolvedNode = try await parentNode.resolve(paths: paths, fetcher: fetcher)
        
        #expect(resolvedNode.id == "parent")
        #expect(resolvedNode.properties().contains("child"))
    }
    
    @Test("Node resolve handles empty paths gracefully")
    func testNodeResolveEmptyPaths() async throws {
        let node = MockResolvedNode(id: "empty-paths", data: ["key": "value"])
        let fetcher = MockFetcher()
        
        let emptyPaths = ArrayTrie<ResolutionStrategy>()
        let resolvedNode = try await node.resolve(paths: emptyPaths, fetcher: fetcher)
        
        // Should return same node structure since no paths to resolve
        #expect(resolvedNode.id == "empty-paths")
    }
    
    @Test("Node resolve with mixed strategies")
    func testNodeResolveMixedStrategies() async throws {
        let node = MockResolvedNode(id: "mixed", data: [
            "target-prop": "target-value",
            "recursive-prop": "recursive-value",
            "ignored-prop": "ignored-value"
        ])
        let fetcher = MockFetcher()
        
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["target-prop"], value: .targeted)
        paths.set(["recursive-prop"], value: .recursive)
        // "ignored-prop" is not in paths, so it won't be resolved
        
        let resolvedNode = try await node.resolve(paths: paths, fetcher: fetcher)
        
        #expect(resolvedNode.id == "mixed")
        #expect(resolvedNode.properties().contains("target-prop"))
        #expect(resolvedNode.properties().contains("recursive-prop"))
        #expect(resolvedNode.properties().contains("ignored-prop"))
    }
    
    // MARK: - Performance and Concurrency Tests
    
    @Test("Node resolve handles concurrent property resolution")
    func testNodeResolveConcurrency() async throws {
        // Create a node with many properties to test concurrent resolution
        var data: [String: String] = [:]
        for i in 1...10 {
            data["prop\(i)"] = "value\(i)"
        }
        
        let node = MockResolvedNode(id: "concurrent-test", data: data)
        let fetcher = MockFetcher()
        
        let startTime = Date()
        let resolvedNode = try await node.resolveRecursive(fetcher: fetcher)
        let endTime = Date()
        
        #expect(resolvedNode.id == "concurrent-test")
        #expect(resolvedNode.properties().count >= 10)
        
        // Concurrent resolution should be faster than sequential
        // This is a basic timing test - in real scenarios the difference would be more significant
        let duration = endTime.timeIntervalSince(startTime)
        #expect(duration < 1.0) // Should complete quickly with concurrent processing
    }
    
    @Test("Resolve operations are thread-safe")
    func testResolveThreadSafety() async throws {
        let node = MockResolvedNode(id: "thread-safe", data: ["shared": "value"])
        let fetcher = MockFetcher()
        
        // Perform multiple concurrent resolve operations
        try await withThrowingTaskGroup(of: MockResolvedNode.self) { group in
            for _ in 1...5 {
                group.addTask {
                    var paths = ArrayTrie<ResolutionStrategy>()
                    paths.set(["shared"], value: .targeted)
                    return try await node.resolve(paths: paths, fetcher: fetcher)
                }
            }
            
            var results: [MockResolvedNode] = []
            for try await result in group {
                results.append(result)
            }
            
            // All results should be consistent
            for result in results {
                #expect(result.id == "thread-safe")
                #expect(result.data["shared"] == "value")
            }
        }
    }
    
    // MARK: - RadixNode Mock Implementations
    
    struct MockRadixHeader: RadixHeader, Codable {
        let rawCID: String
        let node: MockRadixNodeType?
        
        init(rawCID: String) {
            self.rawCID = rawCID
            self.node = nil
        }
        
        init(rawCID: String, node: MockRadixNodeType?) {
            self.rawCID = rawCID
            self.node = node
        }
        
        init(node: MockRadixNodeType) {
            self.node = node
            self.rawCID = Self.createSyncCID(for: node, codec: Self.defaultCodec)
        }
        
        init(node: MockRadixNodeType, codec: Codecs) {
            self.node = node
            self.rawCID = Self.createSyncCID(for: node, codec: codec)
        }
        
        // MARK: - Codable
        enum CodingKeys: String, CodingKey {
            case rawCID, node
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(rawCID, forKey: .rawCID)
            try container.encodeIfPresent(node, forKey: .node)
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            rawCID = try container.decode(String.self, forKey: .rawCID)
            node = try container.decodeIfPresent(MockRadixNodeType.self, forKey: .node)
        }
    }
    
    struct MockRadixNodeType: RadixNode {
        typealias ChildType = MockRadixHeader
        typealias ValueType = String
        
        let prefix: String
        let value: String?
        let children: [Character: MockRadixHeader]
        
        init(prefix: String, value: String? = nil, children: [Character: MockRadixHeader] = [:]) {
            self.prefix = prefix
            self.value = value
            self.children = children
        }
        
        func get(property: PathSegment) -> Address? {
            guard let char = property.first, let child = children[char] else {
                return MockHeader(rawCID: "not-found")
            }
            return MockHeader(rawCID: child.rawCID)
        }
        
        func set(property: PathSegment, to child: Address) -> Self {
            guard let char = property.first else { return self }
            var newChildren = children
            if let mockHeader = child as? MockHeader {
                newChildren[char] = MockRadixHeader(rawCID: mockHeader.rawCID)
            }
            return MockRadixNodeType(prefix: prefix, value: value, children: newChildren)
        }
        
        func set(properties: [PathSegment: Address]) -> Self {
            var newChildren = children
            for (key, address) in properties {
                guard let char = key.first else { continue }
                if let mockHeader = address as? MockHeader {
                    newChildren[char] = MockRadixHeader(rawCID: mockHeader.rawCID)
                }
            }
            return MockRadixNodeType(prefix: prefix, value: value, children: newChildren)
        }
        
        // MARK: - Codable
        enum CodingKeys: String, CodingKey {
            case prefix, value, children
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(prefix, forKey: .prefix)
            try container.encodeIfPresent(value, forKey: .value)
            
            // Convert Character keys to String for encoding
            let stringKeyChildren = Dictionary(uniqueKeysWithValues: children.map { (String($0.key), $0.value) })
            try container.encode(stringKeyChildren, forKey: .children)
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            prefix = try container.decode(String.self, forKey: .prefix)
            value = try container.decodeIfPresent(String.self, forKey: .value)
            
            // Convert String keys back to Character
            let stringKeyChildren = try container.decode([String: MockRadixHeader].self, forKey: .children)
            children = Dictionary(uniqueKeysWithValues: stringKeyChildren.compactMap { key, value in
                guard let char = key.first else { return nil }
                return (char, value)
            })
        }
        
        // MARK: - LosslessStringConvertible
        var description: String {
            let jsonData = (try? JSONEncoder().encode(self)) ?? Data()
            return String(data: jsonData, encoding: .utf8) ?? "MockRadixNodeType(invalid)"
        }
        
        init?(_ description: String) {
            guard let data = description.data(using: .utf8),
                  let node = try? JSONDecoder().decode(MockRadixNodeType.self, from: data) else {
                return nil
            }
            self = node
        }
    }
    
    // MARK: - RadixNode Basic Tests
    
    @Test("RadixNode structure integrity")
    func testRadixNodeStructure() async throws {
        let childHeader = MockRadixHeader(rawCID: "child-cid")
        let children: [Character: MockRadixHeader] = ["a": childHeader]
        let node = MockRadixNodeType(prefix: "test", value: "test-value", children: children)
        
        #expect(node.prefix == "test")
        #expect(node.value == "test-value")
        #expect(node.children.count == 1)
        #expect(node.children["a"]?.rawCID == "child-cid")
        #expect(node.properties().contains("a"))
    }
    
    @Test("RadixNode property access")
    func testRadixNodePropertyAccess() async throws {
        let childHeader = MockRadixHeader(rawCID: "accessible-child")
        let children: [Character: MockRadixHeader] = ["x": childHeader, "y": MockRadixHeader(rawCID: "another-child")]
        let node = MockRadixNodeType(prefix: "access", children: children)
        
        let retrievedChild = node.get(property: "x")
        #expect((retrievedChild as? MockHeader)?.rawCID == "accessible-child")
        
        #expect(node.properties().count == 2)
        #expect(node.properties().contains("x"))
        #expect(node.properties().contains("y"))
    }
    
    @Test("RadixNode property modification")
    func testRadixNodePropertyModification() async throws {
        let originalChild = MockRadixHeader(rawCID: "original-child")
        let children: [Character: MockRadixHeader] = ["m": originalChild]
        let node = MockRadixNodeType(prefix: "modify", children: children)
        
        let newHeader = MockHeader(rawCID: "new-child")
        let modifiedNode = node.set(property: "m", to: newHeader)
        
        #expect(modifiedNode.prefix == "modify")
        #expect(modifiedNode.children.count == 1)
        #expect(modifiedNode.children["m"]?.rawCID == "new-child")
    }
    
    // MARK: - Integration Tests
    
    @Test("End-to-end resolve test with Header and RadixNode")
    func testEndToEndResolveIntegration() async throws {
        // Create a RadixNode with some structure
        let leafChild = MockRadixHeader(rawCID: "leaf-cid")
        let leafChildren: [Character: MockRadixHeader] = ["z": leafChild]
        let leafNode = MockRadixNodeType(prefix: "leaf", children: leafChildren)
        
        // Create a header containing this node
        let header = try await HeaderImpl.create(node: leafNode)
        let originalCID = header.rawCID
        
        // Serialize for fetching simulation
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let nodeData = try! encoder.encode(leafNode)
        let fetcher = MockFetcher(responses: [originalCID: nodeData])
        
        // Create header with just CID
        let cidOnlyHeader = HeaderImpl<MockRadixNodeType>(rawCID: originalCID)
        
        // Resolve the full structure
        let resolvedHeader = try await cidOnlyHeader.resolve(fetcher: fetcher)
        
        #expect(resolvedHeader.rawCID == originalCID)
        #expect(resolvedHeader.node?.prefix == "leaf")
        #expect(resolvedHeader.node?.children.count == 1)
        
        // Verify content addressability is maintained
        let recreatedCID = try await resolvedHeader.recreateCID()
        #expect(recreatedCID == originalCID)
    }
    
    @Test("Resolve maintains data structure integrity through hash verification")
    func testResolveDataStructureIntegrity() async throws {
        // Create a simple RadixNode structure without circular references
        let simpleChildren: [Character: MockRadixHeader] = [
            "a": MockRadixHeader(rawCID: "child-a-cid"),
            "b": MockRadixHeader(rawCID: "child-b-cid")
        ]
        let simpleNode = MockRadixNodeType(prefix: "simple", value: "test-value", children: simpleChildren)
        
        let originalHeader = try await HeaderImpl.create(node: simpleNode)
        let originalCID = originalHeader.rawCID
        
        // Simulate fetching from storage
        let nodeData = simpleNode.toData()!
        
        let fetcher = MockFetcher(responses: [
            originalCID: nodeData
        ])
        
        // Resolve to reconstruct the structure
        let cidOnlyHeader = HeaderImpl<MockRadixNodeType>(rawCID: originalCID)
        let resolvedHeader = try await cidOnlyHeader.resolve(fetcher: fetcher)
        
        // Verify structure is intact
        #expect(resolvedHeader.rawCID == originalCID)
        #expect(resolvedHeader.node?.prefix == "simple")
        #expect(resolvedHeader.node?.value == "test-value")
        #expect(resolvedHeader.node?.children.count == 2)
        
        // Verify hash consistency
        let finalCID = try await resolvedHeader.recreateCID()
        #expect(finalCID == originalCID)
    }
}
