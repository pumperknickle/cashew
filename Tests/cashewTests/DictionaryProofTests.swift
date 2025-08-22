import Testing
import Foundation
import ArrayTrie
@preconcurrency import Multicodec
@testable import cashew

@Suite("Dictionary Proof Tests")
struct DictionaryProofTests {
    
    // MARK: - Test Fixtures
    // Using TestStoreFetcher and MerkleDictionary for all tests
    
    // MARK: - Basic Dictionary Proof Tests
    
    @Test("Dictionary proof with empty paths returns self")
    func testDictionaryProofEmptyPaths() async throws {
        // Create MerkleDictionary
        let radixNode = RadixNodeImpl<String>(prefix: "test", value: "test-value", children: [:])
        let radixHeader = RadixHeaderImpl(node: radixNode)
        let children: [Character: RadixHeaderImpl<String>] = ["t": radixHeader]
        let dictionary = MerkleDictionaryImpl<String>(children: children, count: 1)
        let headerWithNode = HeaderImpl(node: dictionary)
        
        // Create header without node - will fetch from storage
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: headerWithNode.rawCID)
        let fetcher = TestStoreFetcher()
        try headerWithNode.storeRecursively(storer: fetcher)
        
        let emptyPaths = ArrayTrie<SparseMerkleProof>()
        let result = try await header.proof(paths: emptyPaths, fetcher: fetcher)
        
        #expect(result.rawCID == headerWithNode.rawCID)
        #expect(result.node == nil) // Empty paths should not fetch node
    }
    
    @Test("Dictionary proof validates existence on property")
    func testDictionaryProofExistenceProperty() async throws {
        // Create nested structure with child node
        let childNode = RadixNodeImpl<String>(prefix: "child", value: "child-value", children: [:])
        let childHeader = RadixHeaderImpl(node: childNode)
        
        let parentChildren: [Character: RadixHeaderImpl<String>] = ["c": childHeader]
        let parentNode = RadixNodeImpl<String>(prefix: "parent", value: "parent-value", children: parentChildren)
        let parentHeader = RadixHeaderImpl(node: parentNode)
        
        // Create MerkleDictionary containing the parent node
        let dictChildren: [Character: RadixHeaderImpl<String>] = ["p": parentHeader]
        let dictionary = MerkleDictionaryImpl<String>(children: dictChildren, count: 1)
        let headerWithNode = HeaderImpl(node: dictionary)
        
        // Create header without node - will fetch from storage
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: headerWithNode.rawCID)
        let fetcher = TestStoreFetcher()
        try headerWithNode.storeRecursively(storer: fetcher)
        
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["p", "parent", "c", "child"], value: .existence)
        
        let result = try await header.proof(paths: paths, fetcher: fetcher)
        
        #expect(result.rawCID == headerWithNode.rawCID)
        #expect(result.node?.count == 1)
    }
    
    @Test("Dictionary proof validates mutation on property")
    func testDictionaryProofMutationProperty() async throws {
        // Create MerkleDictionary with mutable key
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "mutable-prop", value: "original-value")
        let headerWithNode = HeaderImpl(node: dictionary)
        
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: headerWithNode.rawCID)
        let fetcher = TestStoreFetcher()
        try headerWithNode.storeRecursively(storer: fetcher)
        
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["mutable-prop"], value: .mutation)
        
        let result = try await header.proof(paths: paths, fetcher: fetcher)
        let resultAfterMutation = try result.node!.mutating(key: "mutable-prop", value: "new-value")
        
        
        #expect(result.rawCID == headerWithNode.rawCID)
        #expect(result.node?.count == 1)
        #expect(try resultAfterMutation.get(key: "mutable-prop") == "new-value")
    }
    
    @Test("Dictionary proof validates mutation on existing value")
    func testDictionaryProofMutationValidation() async throws {
        // Create dictionary with existing value that can be mutated
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "test", value: "existing-value")
        let headerWithNode = HeaderImpl(node: dictionary)
        
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: headerWithNode.rawCID)
        let fetcher = TestStoreFetcher()
        try headerWithNode.storeRecursively(storer: fetcher)
        
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["test"], value: .mutation)
        
        let result = try await header.proof(paths: paths, fetcher: fetcher)
        
        #expect(result.rawCID == headerWithNode.rawCID)
        #expect(result.node?.count == 1)
    }
    
    @Test("Dictionary proof insertion validation throws error for existing value")
    func testDictionaryProofInsertionValidation() async throws {
        // Create dictionary with existing value
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "test", value: "existing-value")
        let headerWithNode = HeaderImpl(node: dictionary)
        
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: headerWithNode.rawCID)
        let fetcher = TestStoreFetcher()
        try headerWithNode.storeRecursively(storer: fetcher)
        
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["test"], value: .insertion)
        
        await #expect(throws: ProofErrors.self) {
            _ = try await header.proof(paths: paths, fetcher: fetcher)
        }
    }
    
    @Test("Dictionary proof mutation validation throws error for nil value")
    func testDictionaryProofMutationValidationNilValue() async throws {
        // Create dictionary with nil value
        let node = RadixNodeImpl<String>(prefix: "test", value: nil, children: [:])
        let radixHeader = RadixHeaderImpl(node: node)
        let children: [Character: RadixHeaderImpl<String>] = ["t": radixHeader]
        let dictionary = MerkleDictionaryImpl<String>(children: children, count: 1)
        let headerWithNode = HeaderImpl(node: dictionary)
        
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: headerWithNode.rawCID)
        let fetcher = TestStoreFetcher()
        try headerWithNode.storeRecursively(storer: fetcher)
        
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["t", "test"], value: .mutation)
        
        await #expect(throws: ProofErrors.self) {
            _ = try await header.proof(paths: paths, fetcher: fetcher)
        }
    }
    
    @Test("Dictionary proof with children processing")
    func testDictionaryProofWithChildren() async throws {
        // Create nested dictionary structure
        let childNode = RadixNodeImpl<String>(prefix: "child", value: "child-value", children: [:])
        let childHeader = RadixHeaderImpl(node: childNode)
        
        let parentChildren: [Character: RadixHeaderImpl<String>] = ["c": childHeader]
        let parentNode = RadixNodeImpl<String>(prefix: "parent", value: "parent-value", children: parentChildren)
        let parentHeader = RadixHeaderImpl(node: parentNode)
        
        let dictChildren: [Character: RadixHeaderImpl<String>] = ["p": parentHeader]
        let dictionary = MerkleDictionaryImpl<String>(children: dictChildren, count: 1)
        let headerWithNode = HeaderImpl(node: dictionary)
        
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: headerWithNode.rawCID)
        let fetcher = TestStoreFetcher()
        try headerWithNode.storeRecursively(storer: fetcher)
        
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["p", "parent", "c", "child"], value: .existence)
        
        let result = try await header.proof(paths: paths, fetcher: fetcher)
        
        #expect(result.rawCID == headerWithNode.rawCID)
        #expect(result.node?.count == 1)
    }
    
    @Test("Dictionary proof deletion processing")
    func testDictionaryProofDeletion() async throws {
        // Create dictionary with deletable key
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "deletable", value: "to-delete")
        let headerWithNode = HeaderImpl(node: dictionary)
        
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: headerWithNode.rawCID)
        let fetcher = TestStoreFetcher()
        try headerWithNode.storeRecursively(storer: fetcher)
        
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["deletable"], value: .deletion)
        
        let result = try await header.proof(paths: paths, fetcher: fetcher)
        let resultAfterDeletion = try result.node!.deleting(key: "deletable")
        
        #expect(result.rawCID == headerWithNode.rawCID)
        #expect(result.node?.count == 1)
        #expect(resultAfterDeletion.count == 0)
        #expect(try resultAfterDeletion.get(key: "deletable") == nil)
    }
    
    @Test("Dictionary proof with missing data throws error")
    func testDictionaryProofMissingData() async throws {
        // Create dictionary structure
        let node = RadixNodeImpl<String>(prefix: "test", value: "test-value", children: [:])
        let radixHeader = RadixHeaderImpl(node: node)
        let children: [Character: RadixHeaderImpl<String>] = ["t": radixHeader]
        let dictionary = MerkleDictionaryImpl<String>(children: children, count: 1)
        let headerWithNode = HeaderImpl(node: dictionary)
        
        // Create header without node and empty fetcher
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: headerWithNode.rawCID)
        let fetcher = TestStoreFetcher() // Empty storage
        
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["t", "test"], value: .existence)
        
        await #expect(throws: Error.self) {
            _ = try await header.proof(paths: paths, fetcher: fetcher)
        }
    }
    
    // MARK: - Content Addressability Tests
    
    @Test("Dictionary CID is deterministic")
    func testDictionaryCIDDeterministic() async throws {
        // Create identical dictionaries
        let node1 = RadixNodeImpl<String>(prefix: "same", value: "same-value", children: [:])
        let radixHeader1 = RadixHeaderImpl(node: node1)
        let children1: [Character: RadixHeaderImpl<String>] = ["s": radixHeader1]
        let dictionary1 = MerkleDictionaryImpl<String>(children: children1, count: 1)
        
        let node2 = RadixNodeImpl<String>(prefix: "same", value: "same-value", children: [:])
        let radixHeader2 = RadixHeaderImpl(node: node2)
        let children2: [Character: RadixHeaderImpl<String>] = ["s": radixHeader2]
        let dictionary2 = MerkleDictionaryImpl<String>(children: children2, count: 1)
        
        let header1 = HeaderImpl(node: dictionary1)
        let header2 = HeaderImpl(node: dictionary2)
        
        #expect(header1.rawCID == header2.rawCID)
    }
    
    @Test("Dictionary CID differs for different content")
    func testDictionaryCIDDifferentContent() async throws {
        // Create different dictionaries
        let node1 = RadixNodeImpl<String>(prefix: "content1", value: "value1", children: [:])
        let radixHeader1 = RadixHeaderImpl(node: node1)
        let children1: [Character: RadixHeaderImpl<String>] = ["c": radixHeader1]
        let dictionary1 = MerkleDictionaryImpl<String>(children: children1, count: 1)
        
        let node2 = RadixNodeImpl<String>(prefix: "content2", value: "value2", children: [:])
        let radixHeader2 = RadixHeaderImpl(node: node2)
        let children2: [Character: RadixHeaderImpl<String>] = ["c": radixHeader2]
        let dictionary2 = MerkleDictionaryImpl<String>(children: children2, count: 1)
        
        let header1 = HeaderImpl(node: dictionary1)
        let header2 = HeaderImpl(node: dictionary2)
        
        #expect(header1.rawCID != header2.rawCID)
    }
    
    @Test("Dictionary proof maintains content addressability")
    func testDictionaryProofContentAddressability() async throws {
        // Create dictionary with content
        let node = RadixNodeImpl<String>(prefix: "content", value: "test-value", children: [:])
        let radixHeader = RadixHeaderImpl(node: node)
        let children: [Character: RadixHeaderImpl<String>] = ["c": radixHeader]
        let dictionary = MerkleDictionaryImpl<String>(children: children, count: 1)
        let originalHeader = HeaderImpl(node: dictionary)
        let originalCID = originalHeader.rawCID
        
        // Create header without node and fetch via proof
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: originalCID)
        let fetcher = TestStoreFetcher()
        try originalHeader.storeRecursively(storer: fetcher)
        
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["c", "content"], value: .existence)
        
        let result = try await header.proof(paths: paths, fetcher: fetcher)
        
        // CID should remain the same after proof
        #expect(result.rawCID == originalCID)
        #expect(result.node?.count == 1)
    }
}
