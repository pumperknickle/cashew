import Testing
import Foundation
import ArrayTrie
import CID
@preconcurrency import Multicodec
import Multihash
@testable import cashew


@Suite("HeaderImpl Tests")
struct HeaderImplTests {
    
    @Test("Initialize with rawCID only")
    func testInitWithRawCID() {
        let cid = "bafkreihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku"
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: cid)
        
        #expect(header.rawCID == cid)
        #expect(header.node == nil)
    }
    
    @Test("Initialize with rawCID and node")
    func testInitWithRawCIDAndNode() throws {
        let cid = "bafkreihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku"
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "key1", value: "value1")
        let header = HeaderImpl(rawCID: cid, node: dictionary)
        
        #expect(header.rawCID == cid)
        #expect(try header.node?.get(key: "key1") == "value1")
        #expect(header.node?.count == 1)
    }
    
    @Test("Initialize with node only - uses placeholder CID")
    func testInitWithNodeOnly() throws {
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "key1", value: "value1")
        let header = HeaderImpl(node: dictionary)
        
        #expect(try header.node?.get(key: "key1") == "value1")
        #expect(header.rawCID.hasPrefix("bagu") || header.rawCID.hasPrefix("bafy"))
        #expect(header.rawCID.count > 10)
    }
    
    @Test("Initialize with node and specific codec")
    func testInitWithNodeAndCodec() throws {
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "key1", value: "value1")
        let header = HeaderImpl(node: dictionary, codec: .dag_json)
        
        #expect(try header.node?.get(key: "key1") == "value1")
        #expect(header.rawCID.hasPrefix("bagu") || header.rawCID.hasPrefix("bafy"))
    }
    
    @Test("Async create with proper CID generation")
    func testAsyncCreate() async throws {
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "key1", value: "value1")
        let header = try await HeaderImpl.create(node: dictionary, codec: .dag_json)
        
        #expect(try header.node?.get(key: "key1") == "value1")
        #expect(header.rawCID.hasPrefix("bagu") || header.rawCID.hasPrefix("bafy"))
        #expect(header.rawCID != "bafyreigdhej4kdla7q2z5rnpfxqhj6c2wuutcka2rzkqxvmzq4f2j7kfgy")
    }
    
    @Test("CID creation is deterministic with async create")
    func testCIDCreationDeterministic() async throws {
        var dictionary1 = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary1 = try dictionary1.inserting(key: "key1", value: "value1")
        
        var dictionary2 = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary2 = try dictionary2.inserting(key: "key1", value: "value1")
        
        let header1 = try await HeaderImpl.create(node: dictionary1, codec: .dag_json)
        let header2 = try await HeaderImpl.create(node: dictionary2, codec: .dag_json)
        
        #expect(header1.rawCID == header2.rawCID)
    }
    
    @Test("Different codecs produce different CIDs")
    func testDifferentCodecsProduceDifferentCIDs() async throws {
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "key1", value: "value1")
        
        let headerCBOR = try await HeaderImpl.create(node: dictionary, codec: .dag_cbor)
        let headerJSON = try await HeaderImpl.create(node: dictionary, codec: .dag_json)
        
        #expect(headerCBOR.rawCID != headerJSON.rawCID)
    }
    
    @Test("Map node to data")
    func testMapToData() throws {
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "key1", value: "value1")
        let header = HeaderImpl(node: dictionary)
        
        let data = try header.mapToData()
        #expect(data.count > 0)
        
        // Verify it's valid JSON (since we're using JSONEncoder)
        let json = try JSONSerialization.jsonObject(with: data)
        #expect(json is [String: Any])
    }
    
    @Test("Map to data throws when no node")
    func testMapToDataThrowsWhenNoNode() {
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: "test-cid")
        
        #expect(throws: DataErrors.self) {
            try header.mapToData()
        }
    }
    
    @Test("Recreate CID with async method")
    func testRecreateCID() async throws {
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "key1", value: "value1")
        let header = try await HeaderImpl.create(node: dictionary)
        let originalCID = header.rawCID
        
        let recreatedCID = try await header.recreateCID()
        #expect(recreatedCID == originalCID)
    }
    
    @Test("Recreate CID returns original when no node")
    func testRecreateCIDReturnsOriginalWhenNoNode() async throws {
        let originalCID = "bafkreihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku"
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: originalCID)
        
        let recreatedCID = try await header.recreateCID()
        #expect(recreatedCID == originalCID)
    }
    
    @Test("LosslessStringConvertible description")
    func testLosslessStringConvertibleDescription() {
        let cid = "bafkreihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku"
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: cid)
        
        #expect(header.description == cid)
    }
    
    @Test("LosslessStringConvertible init")
    func testLosslessStringConvertibleInit() {
        let cid = "bafkreihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku"
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(cid)
        
        #expect(header != nil)
        #expect(header?.rawCID == cid)
        #expect(header?.node == nil)
    }
    
    @Test("Recreate CID with specific codec")
    func testRecreateCIDWithCodec() async throws {
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "key1", value: "value1")
        let header = try await HeaderImpl.create(node: dictionary)
        
        let cidWithJSON = try await header.recreateCID(withCodec: .dag_json)
        let cidWithCBOR = try await header.recreateCID(withCodec: .dag_cbor)
        
        #expect(cidWithJSON != cidWithCBOR)
        #expect(cidWithJSON.hasPrefix("bagu") || cidWithJSON.hasPrefix("bafy"))
        #expect(cidWithCBOR.hasPrefix("bagu") || cidWithCBOR.hasPrefix("bafy"))
    }
    
    @Test("Recreate CID with codec throws when no node")
    func testRecreateCIDWithCodecThrowsWhenNoNode() async throws {
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: "test-cid")
        
        await #expect(throws: DataErrors.self) {
            try await header.recreateCID(withCodec: .dag_json)
        }
    }
}
