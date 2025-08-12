import Testing
import Foundation
import ArrayTrie
import CID
@preconcurrency import Multicodec
import Multihash
@testable import cashew

// Mock implementations for testing
struct MockHeader: Header, Sendable {
    typealias NodeType = MockNode

    var node: MockNode?
    var rawCID: String
    
    init(rawCID: String, node: MockNode?) {
        self.rawCID = rawCID
        self.node = node
    }
    
    func resolve(paths: ArrayTrie<ResolutionStrategy>, fetcher: Fetcher) async throws -> Self {
        return self
    }
    
    func resolveRecursive(fetcher: Fetcher) async throws -> Self {
        return self
    }
    
    func resolve(fetcher: Fetcher) async throws -> Self {
        return self
    }
    
    func transform(transforms: ArrayTrie<Transform>) throws -> Self {
        return self
    }
}

struct MockNode: Node, Sendable {
    let id: String
    let data: [String: String]
    
    init(id: String, data: [String: String] = [:]) {
        self.id = id
        self.data = data
    }
    
    func get(property: PathSegment) -> Address? {
        return MockHeader(rawCID: data[property] ?? "", node: nil)
    }
    
    func properties() -> Set<PathSegment> {
        return Set(data.keys)
    }
    
    func set(property: PathSegment, to child: Address) -> Self {
        var newData = data
        if let mockChild = child as? MockHeader {
            newData[property] = mockChild.rawCID
        }
        return MockNode(id: id, data: newData)
    }
    
    func set(properties: [PathSegment: Address]) -> Self {
        var newData = data
        for (key, address) in properties {
            if let mockAddress = address as? MockHeader {
                newData[key] = mockAddress.rawCID
            }
        }
        return MockNode(id: id, data: newData)
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, data
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        
        // Sort the dictionary keys to ensure deterministic encoding
        let sortedData = data.sorted { $0.key < $1.key }
        let orderedDict = Dictionary(uniqueKeysWithValues: sortedData)
        try container.encode(orderedDict, forKey: .data)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        data = try container.decode([String: String].self, forKey: .data)
    }
}

struct MockFetcher: Fetcher, Sendable {
    func fetch(rawCid cid: String) async throws -> Data {
        return Data("mock data".utf8)
    }
}

@Suite("HeaderImpl Tests")
struct HeaderImplTests {
    
    @Test("Initialize with rawCID only")
    func testInitWithRawCID() {
        let cid = "bafkreihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku"
        let header = HeaderImpl<MockNode>(rawCID: cid)
        
        #expect(header.rawCID == cid)
        #expect(header.node == nil)
    }
    
    @Test("Initialize with rawCID and node")
    func testInitWithRawCIDAndNode() {
        let cid = "bafkreihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku"
        let node = MockNode(id: "test-node", data: ["key1": "value1"])
        let header = HeaderImpl(rawCID: cid, node: node)
        
        #expect(header.rawCID == cid)
        #expect(header.node?.id == "test-node")
        #expect(header.node?.data == ["key1": "value1"])
    }
    
    @Test("Initialize with node only - uses placeholder CID")
    func testInitWithNodeOnly() {
        let node = MockNode(id: "test-node", data: ["key1": "value1"])
        let header = HeaderImpl(node: node)
        
        #expect(header.node?.id == "test-node")
        #expect(header.rawCID.hasPrefix("bagu") || header.rawCID.hasPrefix("bafy"))
        #expect(header.rawCID.count > 10)
    }
    
    @Test("Initialize with node and specific codec")
    func testInitWithNodeAndCodec() {
        let node = MockNode(id: "test-node", data: ["key1": "value1"])
        let header = HeaderImpl(node: node, codec: .dag_json)
        
        #expect(header.node?.id == "test-node")
        #expect(header.rawCID.hasPrefix("bagu") || header.rawCID.hasPrefix("bafy"))
    }
    
    @Test("Async create with proper CID generation")
    func testAsyncCreate() async throws {
        let node = MockNode(id: "test-node", data: ["key1": "value1"])
        let header = try await HeaderImpl.create(node: node, codec: .dag_json)
        
        #expect(header.node?.id == "test-node")
        #expect(header.rawCID.hasPrefix("bagu") || header.rawCID.hasPrefix("bafy"))
        #expect(header.rawCID != "bafyreigdhej4kdla7q2z5rnpfxqhj6c2wuutcka2rzkqxvmzq4f2j7kfgy")
    }
    
    @Test("CID creation is deterministic with async create")
    func testCIDCreationDeterministic() async throws {
        let node = MockNode(id: "test-node", data: ["key1": "value1"])
        let header1 = try await HeaderImpl.create(node: node, codec: .dag_json)
        let header2 = try await HeaderImpl.create(node: node, codec: .dag_json)
        
        #expect(header1.rawCID == header2.rawCID)
    }
    
    @Test("Different codecs produce different CIDs")
    func testDifferentCodecsProduceDifferentCIDs() async throws {
        let node = MockNode(id: "test-node", data: ["key1": "value1"])
        let headerCBOR = try await HeaderImpl.create(node: node, codec: .dag_cbor)
        let headerJSON = try await HeaderImpl.create(node: node, codec: .dag_json)
        
        #expect(headerCBOR.rawCID != headerJSON.rawCID)
    }
    
    @Test("Map node to data")
    func testMapToData() throws {
        let node = MockNode(id: "test-node", data: ["key1": "value1"])
        let header = HeaderImpl(node: node)
        
        let data = try header.mapToData()
        #expect(data.count > 0)
        
        // Verify it's valid JSON (since we're using JSONEncoder)
        let json = try JSONSerialization.jsonObject(with: data)
        #expect(json is [String: Any])
    }
    
    @Test("Map to data throws when no node")
    func testMapToDataThrowsWhenNoNode() {
        let header = HeaderImpl<MockNode>(rawCID: "test-cid")
        
        #expect(throws: DataErrors.self) {
            try header.mapToData()
        }
    }
    
    @Test("Recreate CID with async method")
    func testRecreateCID() async throws {
        let node = MockNode(id: "test-node", data: ["key1": "value1"])
        let header = try await HeaderImpl.create(node: node)
        let originalCID = header.rawCID
        
        let recreatedCID = try await header.recreateCID()
        #expect(recreatedCID == originalCID)
    }
    
    @Test("Recreate CID returns original when no node")
    func testRecreateCIDReturnsOriginalWhenNoNode() async throws {
        let originalCID = "bafkreihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku"
        let header = HeaderImpl<MockNode>(rawCID: originalCID)
        
        let recreatedCID = try await header.recreateCID()
        #expect(recreatedCID == originalCID)
    }
    
    @Test("LosslessStringConvertible description")
    func testLosslessStringConvertibleDescription() {
        let cid = "bafkreihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku"
        let header = HeaderImpl<MockNode>(rawCID: cid)
        
        #expect(header.description == cid)
    }
    
    @Test("LosslessStringConvertible init")
    func testLosslessStringConvertibleInit() {
        let cid = "bafkreihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku"
        let header = HeaderImpl<MockNode>(cid)
        
        #expect(header != nil)
        #expect(header?.rawCID == cid)
        #expect(header?.node == nil)
    }
    
    @Test("Recreate CID with specific codec")
    func testRecreateCIDWithCodec() async throws {
        let node = MockNode(id: "test-node", data: ["key1": "value1"])
        let header = try await HeaderImpl.create(node: node)
        
        let cidWithJSON = try await header.recreateCID(withCodec: .dag_json)
        let cidWithCBOR = try await header.recreateCID(withCodec: .dag_cbor)
        
        #expect(cidWithJSON != cidWithCBOR)
        #expect(cidWithJSON.hasPrefix("bagu") || cidWithJSON.hasPrefix("bafy"))
        #expect(cidWithCBOR.hasPrefix("bagu") || cidWithCBOR.hasPrefix("bafy"))
    }
    
    @Test("Recreate CID with codec throws when no node")
    func testRecreateCIDWithCodecThrowsWhenNoNode() async throws {
        let header = HeaderImpl<MockNode>(rawCID: "test-cid")
        
        await #expect(throws: DataErrors.self) {
            try await header.recreateCID(withCodec: .dag_json)
        }
    }
}
