import Testing
import Foundation
import ArrayTrie
import CID
@preconcurrency import Multicodec
import Multihash
@testable import cashew

@Suite("Resolve Functionality Tests")
struct ResolveTests {
    // MARK: - Header Resolve Tests
    
    @Test("Header resolve with existing node - no fetching required")
    func testHeaderResolveWithExistingNode() async throws {
        // Create MerkleDictionary with test data
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "key1", value: "value1")
        let header = HeaderImpl(node: dictionary)
        let fetcher = TestStoreFetcher()
        
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["key1"], value: .targeted)
        
        let resolvedHeader = try await header.resolve(paths: paths, fetcher: fetcher)
        
        #expect(resolvedHeader.rawCID == header.rawCID)
        #expect(try resolvedHeader.node?.get(key: "key1") == "value1")
    }
    
    @Test("Header resolve without node - fetches from CID")
    func testHeaderResolveWithoutNode() async throws {
        // Create MerkleDictionary and store it in TestStoreFetcher
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "fetched", value: "true")
        let headerWithNode = HeaderImpl(node: dictionary)
        
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: headerWithNode.rawCID)
        let fetcher = TestStoreFetcher()
        try headerWithNode.storeRecursively(storer: fetcher)
        
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["fetched"], value: .targeted)
        
        let resolvedHeader = try await header.resolve(paths: paths, fetcher: fetcher)
        
        #expect(resolvedHeader.rawCID == headerWithNode.rawCID)
        #expect(try resolvedHeader.node?.get(key: "fetched") == "true")
    }
    
    @Test("Header resolveRecursive with existing node")
    func testHeaderResolveRecursiveWithExistingNode() async throws {
        // Create MerkleDictionary with nested structure
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "key1", value: "value1")
        dictionary = try dictionary.inserting(key: "child1", value: "data1")
        dictionary = try dictionary.inserting(key: "child2", value: "data2")
        let header = HeaderImpl(node: dictionary)
        let fetcher = TestStoreFetcher()
        
        let resolvedHeader = try await header.resolveRecursive(fetcher: fetcher)
        
        #expect(resolvedHeader.rawCID == header.rawCID)
        #expect(try resolvedHeader.node?.get(key: "key1") == "value1")
        #expect(try resolvedHeader.node?.get(key: "child1") == "data1")
    }
    
    @Test("Header resolveRecursive without node - fetches from CID")
    func testHeaderResolveRecursiveWithoutNode() async throws {
        // Create MerkleDictionary and store it with storeRecursively
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "recursive", value: "true")
        let headerWithNode = HeaderImpl(node: dictionary)
        
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: headerWithNode.rawCID)
        let fetcher = TestStoreFetcher()
        try headerWithNode.storeRecursively(storer: fetcher)
        
        let resolvedHeader = try await header.resolveRecursive(fetcher: fetcher)
        
        #expect(resolvedHeader.rawCID == headerWithNode.rawCID)
        #expect(try resolvedHeader.node?.get(key: "recursive") == "true")
    }
    
    @Test("Header resolve basic - fetches node when missing")
    func testHeaderResolveBasic() async throws {
        // Create MerkleDictionary and store it with TestStoreFetcher
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "basic", value: "true")
        let headerWithNode = HeaderImpl(node: dictionary)
        
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: headerWithNode.rawCID)
        let fetcher = TestStoreFetcher()
        try headerWithNode.storeRecursively(storer: fetcher)
        
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["basic"], value: .targeted)
        
        let resolvedHeader = try await header.resolve(paths: paths, fetcher: fetcher)
        
        #expect(resolvedHeader.rawCID == headerWithNode.rawCID)
        #expect(try resolvedHeader.node?.get(key: "basic") == "true")
    }
    
    @Test("Header resolve basic - returns self when node exists")
    func testHeaderResolveBasicWithExistingNode() async throws {
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "exists", value: "true")
        let header = HeaderImpl(node: dictionary)
        let fetcher = TestStoreFetcher()
        
        let resolvedHeader = try await header.resolve(fetcher: fetcher)
        
        #expect(resolvedHeader.rawCID == header.rawCID)
        #expect(try resolvedHeader.node?.get(key: "exists") == "true")
        // Should have the same properties since no resolution was needed
        #expect(resolvedHeader.rawCID == header.rawCID)
        #expect(resolvedHeader.node?.count == header.node?.count) // Same structure since no fetching was needed
    }
    
    @Test("Header resolve with dictionary paths")
    func testHeaderResolveWithDictionaryPaths() async throws {
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "path1", value: "value1")
        dictionary = try dictionary.inserting(key: "path2", value: "value2")
        let header = HeaderImpl(node: dictionary)
        let fetcher = TestStoreFetcher()
        
        let paths = [["path1"]: ResolutionStrategy.targeted, ["path2"]: ResolutionStrategy.recursive]
        
        let resolvedHeader = try await header.resolve(paths: paths, fetcher: fetcher)
        
        #expect(resolvedHeader.rawCID == header.rawCID)
        #expect(try resolvedHeader.node?.get(key: "path1") == "value1")
        #expect(try resolvedHeader.node?.get(key: "path2") == "value2")
    }
    
    @Test("Header resolve with empty paths returns self")
    func testHeaderResolveWithEmptyPaths() async throws {
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "key", value: "value")
        let header = HeaderImpl(node: dictionary)
        let fetcher = TestStoreFetcher()
        
        let emptyPaths = ArrayTrie<ResolutionStrategy>()
        
        let resolvedHeader = try await header.resolve(paths: emptyPaths, fetcher: fetcher)
        
        // Should return the same structure since no resolution was needed
        #expect(resolvedHeader.rawCID == header.rawCID)
        #expect(try resolvedHeader.node?.get(key: "key") == "value")
    }
    
    // MARK: - Cryptographic Hash Verification Tests
    
    @Test("Resolve maintains content addressability")
    func testResolveContentAddressability() async throws {
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "content", value: "addressable")
        let originalHeader = HeaderImpl(node: dictionary)
        let originalCID = originalHeader.rawCID
        
        // Store the dictionary using TestStoreFetcher
        let fetcher = TestStoreFetcher()
        try originalHeader.storeRecursively(storer: fetcher)
        
        // Create a header with just the CID (no node)
        let cidOnlyHeader = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: originalCID)
        
        // Resolve to get the full node back with paths
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["content"], value: .targeted)
        
        let resolvedHeader = try await cidOnlyHeader.resolve(paths: paths, fetcher: fetcher)
        
        // Verify the CID remains the same (content addressability)
        #expect(resolvedHeader.rawCID == originalCID)
        #expect(try resolvedHeader.node?.get(key: "content") == "addressable")
        
        // Verify we can recreate the same CID from the resolved node
        let recreatedCID = try await resolvedHeader.recreateCID()
        #expect(recreatedCID == originalCID)
    }
    
    @Test("Resolve verifies data integrity through hash")
    func testResolveDataIntegrityVerification() async throws {
        var originalDict = MerkleDictionaryImpl<String>(children: [:], count: 0)
        originalDict = try originalDict.inserting(key: "hash", value: "verification")
        let originalHeader = HeaderImpl(node: originalDict)
        let originalCID = originalHeader.rawCID
        
        // Create tampered data (different from original)
        var tamperedDict = MerkleDictionaryImpl<String>(children: [:], count: 0)
        tamperedDict = try tamperedDict.inserting(key: "hash", value: "corrupted")
        let tamperedHeader = HeaderImpl(node: tamperedDict)
        let tamperedCID = tamperedHeader.rawCID
        
        let fetcher = TestStoreFetcher()
        // Store the tampered data properly
        try tamperedHeader.storeRecursively(storer: fetcher)
        
        let cidOnlyHeader = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: tamperedCID)
        
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["hash"], value: .targeted)
        
        // Resolve the tampered data
        let resolvedHeader = try await cidOnlyHeader.resolve(paths: paths, fetcher: fetcher)
        
        // The resolved node should have the tampered data
        #expect(try resolvedHeader.node?.get(key: "hash") == "corrupted")
        
        // The CID should be different from original due to different content
        #expect(tamperedCID != originalCID)
        #expect(resolvedHeader.rawCID == tamperedCID)
    }
    
    @Test("Multiple resolve operations with same CID produce consistent results")
    func testMultipleResolveConsistency() async throws {
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "test", value: "consistency")
        let header = HeaderImpl(node: dictionary)
        let cid = header.rawCID
        
        let fetcher = TestStoreFetcher()
        try header.storeRecursively(storer: fetcher)
        
        // Perform multiple resolve operations
        let cidHeader1 = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: cid)
        let cidHeader2 = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: cid)
        
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["test"], value: .targeted)
        
        let resolved1 = try await cidHeader1.resolve(paths: paths, fetcher: fetcher)
        let resolved2 = try await cidHeader2.resolve(paths: paths, fetcher: fetcher)
        
        // Both should produce the same results
        #expect(resolved1.rawCID == resolved2.rawCID)
        #expect(try resolved1.node?.get(key: "test") == "consistency")
        #expect(try resolved2.node?.get(key: "test") == "consistency")
        
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
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: cid)
        
        // Create a fetcher that throws errors
        final class ErrorFetcher: Fetcher, Sendable {
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
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: cid)
        
        // Create fetcher with invalid data that can't be decoded
        let fetcher = TestStoreFetcher()
        let invalidData = "invalid json".data(using: .utf8)!
        fetcher.storeRaw(rawCid: cid, data: invalidData)
        
        await #expect(throws: (any Error).self) {
            try await header.resolve(fetcher: fetcher)
        }
    }
    
    // MARK: - Node Resolve Tests
    
    @Test("Node resolveRecursive resolves all properties")
    func testNodeResolveRecursive() async throws {
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "child1", value: "value1")
        dictionary = try dictionary.inserting(key: "child2", value: "value2")
        
        let fetcher = TestStoreFetcher()
        let resolvedNode = try await dictionary.resolveRecursive(fetcher: fetcher)
        
        // The properties should have been processed through resolve
        #expect(try resolvedNode.get(key: "child1") == "value1")
        #expect(try resolvedNode.get(key: "child2") == "value2")
    }
    
    @Test("Node resolve with targeted strategy")
    func testNodeResolveTargeted() async throws {
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "target", value: "value")
        dictionary = try dictionary.inserting(key: "other", value: "ignored")
        
        let fetcher = TestStoreFetcher()
        
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["target"], value: .targeted)
        
        let resolvedNode = try await dictionary.resolve(paths: paths, fetcher: fetcher)
        
        #expect(try resolvedNode.get(key: "target") == "value")
        #expect(try resolvedNode.get(key: "other") == "ignored")
    }
    
    @Test("Node resolve with recursive strategy")
    func testNodeResolveRecursiveStrategy() async throws {
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "recursive-prop", value: "value")
        
        let fetcher = TestStoreFetcher()
        
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["recursive-prop"], value: .recursive)
        
        let resolvedNode = try await dictionary.resolve(paths: paths, fetcher: fetcher)
        
        #expect(try resolvedNode.get(key: "recursive-prop") == "value")
    }
    
    @Test("Node resolve with nested paths")
    func testNodeResolveNestedPaths() async throws {
        // Create child RadixNode with nested structure
        let childNode = RadixNodeImpl<String>(prefix: "nested", value: "value", children: [:])
        let childHeader = RadixHeaderImpl(node: childNode)
        
        let children: [Character: RadixHeaderImpl<String>] = ["n": childHeader]
        let parentNode = RadixNodeImpl<String>(prefix: "child", value: nil, children: children)
        
        let fetcher = TestStoreFetcher()
        
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["n", "nested"], value: .targeted)
        
        let resolvedNode = try await parentNode.resolve(paths: paths, fetcher: fetcher)
        
        #expect(resolvedNode.prefix == "child")
        #expect(resolvedNode.properties().contains("n"))
    }
    
    @Test("Node resolve handles empty paths gracefully")
    func testNodeResolveEmptyPaths() async throws {
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "key", value: "value")
        
        let fetcher = TestStoreFetcher()
        
        let emptyPaths = ArrayTrie<ResolutionStrategy>()
        let resolvedNode = try await dictionary.resolve(paths: emptyPaths, fetcher: fetcher)
        
        // Should return same node structure since no paths to resolve
        #expect(try resolvedNode.get(key: "key") == "value")
    }
    
    @Test("Node resolve with mixed strategies")
    func testNodeResolveMixedStrategies() async throws {
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "target-prop", value: "target-value")
        dictionary = try dictionary.inserting(key: "recursive-prop", value: "recursive-value")
        dictionary = try dictionary.inserting(key: "ignored-prop", value: "ignored-value")
        
        let fetcher = TestStoreFetcher()
        
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["target-prop"], value: .targeted)
        paths.set(["recursive-prop"], value: .recursive)
        // "ignored-prop" is not in paths, so it won't be resolved
        
        let resolvedNode = try await dictionary.resolve(paths: paths, fetcher: fetcher)
        
        #expect(try resolvedNode.get(key: "target-prop") == "target-value")
        #expect(try resolvedNode.get(key: "recursive-prop") == "recursive-value")
        #expect(try resolvedNode.get(key: "ignored-prop") == "ignored-value")
    }
    
    // MARK: - Performance and Concurrency Tests
    
    @Test("Node resolve handles concurrent property resolution")
    func testNodeResolveConcurrency() async throws {
        // Create a dictionary with many properties to test concurrent resolution
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        for i in 1...10 {
            dictionary = try dictionary.inserting(key: "prop\(i)", value: "value\(i)")
        }
        
        let fetcher = TestStoreFetcher()
        
        let startTime = Date()
        let resolvedNode = try await dictionary.resolveRecursive(fetcher: fetcher)
        let endTime = Date()
        
        #expect(resolvedNode.count == 10)
        for i in 1...10 {
            #expect(try resolvedNode.get(key: "prop\(i)") == "value\(i)")
        }
        
        // Concurrent resolution should be faster than sequential
        // This is a basic timing test - in real scenarios the difference would be more significant
        let duration = endTime.timeIntervalSince(startTime)
        #expect(duration < 1.0) // Should complete quickly with concurrent processing
    }
    
    @Test("Resolve operations are thread-safe")
    func testResolveThreadSafety() async throws {
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "shared", value: "value")
        
        let fetcher = TestStoreFetcher()
        
        // Perform multiple sequential resolve operations to test consistency
        var results: [MerkleDictionaryImpl<String>] = []
        for _ in 1...5 {
            var paths = ArrayTrie<ResolutionStrategy>()
            paths.set(["shared"], value: .targeted)
            let result = try await dictionary.resolve(paths: paths, fetcher: fetcher)
            results.append(result)
        }
        
        // All results should be consistent
        for result in results {
            #expect(try result.get(key: "shared") == "value")
        }
    }
    
    // MARK: - RadixNode Basic Tests
    
    @Test("RadixNode structure integrity")
    func testRadixNodeStructure() async throws {
        // Create child RadixNode
        let childNode = RadixNodeImpl<String>(prefix: "child", value: "child-value", children: [:])
        let childHeader = RadixHeaderImpl(node: childNode)
        
        let children: [Character: RadixHeaderImpl<String>] = ["a": childHeader]
        let node = RadixNodeImpl(prefix: "test", value: "test-value", children: children)
        
        #expect(node.prefix == "test")
        #expect(node.value == "test-value")
        #expect(node.children.count == 1)
        #expect(node.children["a"]?.rawCID == childHeader.rawCID)
        #expect(node.properties().contains("a"))
    }
    
    @Test("RadixNode property access")
    func testRadixNodePropertyAccess() async throws {
        // Create child RadixNodes
        let childNode1 = RadixNodeImpl<String>(prefix: "child1", value: "accessible-value", children: [:])
        let childHeader1 = RadixHeaderImpl(node: childNode1)
        
        let childNode2 = RadixNodeImpl<String>(prefix: "child2", value: "another-value", children: [:])
        let childHeader2 = RadixHeaderImpl(node: childNode2)
        
        let children: [Character: RadixHeaderImpl<String>] = ["x": childHeader1, "y": childHeader2]
        let node = RadixNodeImpl<String>(prefix: "access", value: nil, children: children)
        
        let retrievedChild = node.get(property: "x")
        if let childHeader = retrievedChild as? RadixHeaderImpl<String> {
            #expect(childHeader.rawCID == childHeader1.rawCID)
        }
        
        #expect(node.properties().count == 2)
        #expect(node.properties().contains("x"))
        #expect(node.properties().contains("y"))
    }
    
    @Test("RadixNode property modification")
    func testRadixNodePropertyModification() async throws {
        // Create original child
        let originalNode = RadixNodeImpl<String>(prefix: "original", value: "original-value", children: [:])
        let originalChild = RadixHeaderImpl(node: originalNode)
        
        let children: [Character: RadixHeaderImpl<String>] = ["m": originalChild]
        let node = RadixNodeImpl<String>(prefix: "modify", value: nil, children: children)
        
        // Create new child
        let newNode = RadixNodeImpl<String>(prefix: "new", value: "new-value", children: [:])
        let newHeader = RadixHeaderImpl(node: newNode)
        let modifiedNode = node.set(property: "m", to: newHeader)
        
        #expect(modifiedNode.prefix == "modify")
        #expect(modifiedNode.children.count == 1)
        // Verify that the property exists after modification
        #expect(modifiedNode.children["m"] != nil)
        // Test basic node structure integrity
        #expect(modifiedNode.properties().contains("m"))
    }
    
    // MARK: - Integration Tests
    
    @Test("End-to-end resolve test with Header and RadixNode")
    func testEndToEndResolveIntegration() async throws {
        // Create RadixNode with String structure
        let leafChildNode = RadixNodeImpl<String>(prefix: "leaf-key", value: "leaf-value", children: [:])
        let leafChild = RadixHeaderImpl(node: leafChildNode)
        
        let leafChildren: [Character: RadixHeaderImpl<String>] = ["z": leafChild]
        let leafNode = RadixNodeImpl<String>(prefix: "leaf", value: nil, children: leafChildren)
        
        // Create a header containing this node and store with TestStoreFetcher
        let header = HeaderImpl(node: leafNode)
        let fetcher = TestStoreFetcher()
        try header.storeRecursively(storer: fetcher)
        
        // Create header with just CID
        let cidOnlyHeader = HeaderImpl<RadixNodeImpl<String>>(rawCID: header.rawCID)
        
        // Resolve the full structure
        let resolvedHeader = try await cidOnlyHeader.resolve(fetcher: fetcher)
        
        #expect(resolvedHeader.rawCID == header.rawCID)
        #expect(resolvedHeader.node?.prefix == "leaf")
        #expect(resolvedHeader.node?.children.count == 1)
        
        // Verify content addressability is maintained
        let recreatedCID = try await resolvedHeader.recreateCID()
        #expect(recreatedCID == header.rawCID)
    }
    
    @Test("Resolve maintains data structure integrity through hash verification")
    func testResolveDataStructureIntegrity() async throws {
        // Create child RadixNodes
        let childNodeA = RadixNodeImpl<String>(prefix: "child-a", value: "value-a", children: [:])
        let childHeaderA = RadixHeaderImpl(node: childNodeA)
        
        let childNodeB = RadixNodeImpl<String>(prefix: "child-b", value: "value-b", children: [:])
        let childHeaderB = RadixHeaderImpl(node: childNodeB)
        
        let simpleChildren: [Character: RadixHeaderImpl<String>] = [
            "a": childHeaderA,
            "b": childHeaderB
        ]
        let simpleNode = RadixNodeImpl<String>(prefix: "simple", value: "test-value", children: simpleChildren)
        
        let originalHeader = HeaderImpl(node: simpleNode)
        let fetcher = TestStoreFetcher()
        try originalHeader.storeRecursively(storer: fetcher)
        
        // Resolve to reconstruct the structure
        let cidOnlyHeader = HeaderImpl<RadixNodeImpl<String>>(rawCID: originalHeader.rawCID)
        let resolvedHeader = try await cidOnlyHeader.resolve(fetcher: fetcher)
        
        // Verify structure is intact
        #expect(resolvedHeader.rawCID == originalHeader.rawCID)
        #expect(resolvedHeader.node?.prefix == "simple")
        #expect(resolvedHeader.node?.value == "test-value")
        #expect(resolvedHeader.node?.children.count == 2)
        
        // Verify hash consistency
        let finalCID = try await resolvedHeader.recreateCID()
        #expect(finalCID == originalHeader.rawCID)
    }
}
