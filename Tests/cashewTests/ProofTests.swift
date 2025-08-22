import Testing
import Foundation
import ArrayTrie
@preconcurrency import Multicodec
@testable import cashew

@Suite("Sparse Merkle Proof Tests")
struct ProofTests {
    
    // MARK: - Test Fixtures
    // Using MerkleDictionaryImpl and TestStoreFetcher for all tests
    
    // MARK: - SparseMerkleProof Enum Tests
    
    @Test("SparseMerkleProof enum has correct cases")
    func testSparseMerkleProofCases() {
        #expect(SparseMerkleProof.insertion.rawValue == 1)
        #expect(SparseMerkleProof.mutation.rawValue == 2)
        #expect(SparseMerkleProof.deletion.rawValue == 3)
        #expect(SparseMerkleProof.existence.rawValue == 4)
    }
    
    @Test("SparseMerkleProof is codable")
    func testSparseMerkleProofCodable() throws {
        let proofs: [SparseMerkleProof] = [.insertion, .mutation, .deletion, .existence]
        
        for proof in proofs {
            let encoded = try JSONEncoder().encode(proof)
            let decoded = try JSONDecoder().decode(SparseMerkleProof.self, from: encoded)
            #expect(decoded == proof)
        }
    }
    
    // MARK: - ProofErrors Tests
    
    @Test("ProofErrors enum has correct cases")
    func testProofErrorsCases() {
        let invalidType = ProofErrors.invalidProofType
        let proofFailed = ProofErrors.proofFailed
        
        #expect(invalidType as Error is ProofErrors)
        #expect(proofFailed as Error is ProofErrors)
    }
    
    // MARK: - Header Proof Tests
    
    @Test("Header proof with empty paths returns self unchanged")
    func testHeaderProofEmptyPaths() async throws {
        // Create a MerkleDictionary with test data
        let radixNode = RadixNodeImpl<String>(prefix: "test", value: "test-value", children: [:])
        let radixHeader = RadixHeaderImpl(node: radixNode)
        let children: [Character: RadixHeaderImpl<String>] = ["t": radixHeader]
        let dictionary = MerkleDictionaryImpl<String>(children: children, count: 1)
        let headerWithNode = HeaderImpl(node: dictionary)
        
        // Create header without node and store data using storeRecursively
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: headerWithNode.rawCID)
        let fetcher = TestStoreFetcher()
        try headerWithNode.storeRecursively(storer: fetcher)
        
        let emptyPaths = ArrayTrie<SparseMerkleProof>()
        let result = try await header.proof(paths: emptyPaths, fetcher: fetcher)
        
        // With empty paths, should return original header unchanged (no fetching)
        #expect(result.rawCID == headerWithNode.rawCID)
        #expect(result.node == nil) // Node should not be fetched for empty paths
    }
    
    @Test("Header proof validates existing property")
    func testHeaderProofExistingProperty() async throws {
        // Create MerkleDictionary with existing key
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "existing-prop", value: "test-value")
        let headerWithNode = HeaderImpl(node: dictionary)
        
        // Create header without node - will fetch from storage
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: headerWithNode.rawCID)
        let fetcher = TestStoreFetcher()
        try headerWithNode.storeRecursively(storer: fetcher)
        
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["existing-prop"], value: .existence)
        
        let result = try await header.proof(paths: paths, fetcher: fetcher)
        
        #expect(result.rawCID == headerWithNode.rawCID)
        #expect(result.node?.count == 1)
    }
    
    @Test("Header proof validates mutation on property")
    func testHeaderProofMutationProperty() async throws {
        // Create MerkleDictionary using proper insertion
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
    
    @Test("Header proof succeeds for non-existing property with existence proof")
    func testHeaderProofNonExistingProperty() async throws {
        // Create MerkleDictionary with one key
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "existing-prop", value: "value")
        let headerWithNode = HeaderImpl(node: dictionary)
        
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: headerWithNode.rawCID)
        let fetcher = TestStoreFetcher()
        try headerWithNode.storeRecursively(storer: fetcher)
        
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["non-existing-prop"], value: .existence)
        
        // Should succeed - existence proofs prove whether key exists or not
        let result = try await header.proof(paths: paths, fetcher: fetcher)
        #expect(result.rawCID == headerWithNode.rawCID)
    }
    
    @Test("Header proof with nested properties")
    func testHeaderProofNestedProperties() async throws {
        // Create nested MerkleDictionary structure
        let leafNode = RadixNodeImpl<String>(prefix: "leaf", value: "leaf-value", children: [:])
        let leafHeader = RadixHeaderImpl(node: leafNode)
        
        let branchChildren: [Character: RadixHeaderImpl<String>] = ["l": leafHeader]
        let branchNode = RadixNodeImpl<String>(prefix: "branch", value: nil, children: branchChildren)
        let branchHeader = RadixHeaderImpl(node: branchNode)
        
        let rootChildren: [Character: RadixHeaderImpl<String>] = ["b": branchHeader]
        let dictionary = MerkleDictionaryImpl<String>(children: rootChildren, count: 1)
        let headerWithNode = HeaderImpl(node: dictionary)
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: headerWithNode.rawCID)
        
        let fetcher = TestStoreFetcher()
        try headerWithNode.storeRecursively(storer: fetcher)
        
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["b", "branch"], value: .existence)
        paths.set(["b", "branch", "l", "leaf"], value: .existence)
        
        let result = try await header.proof(paths: paths, fetcher: fetcher)
        
        #expect(result.rawCID == headerWithNode.rawCID)
        #expect(result.node?.count == 1)
    }
    
    @Test("Header proof with missing fetcher data throws error")
    func testHeaderProofMissingDataThrows() async throws {
        // Create MerkleDictionary
        let radixNode = RadixNodeImpl<String>(prefix: "test", value: "value", children: [:])
        let radixHeader = RadixHeaderImpl(node: radixNode)
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
    
    @Test("Header proof with dictionary paths")
    func testHeaderProofWithDictionary() async throws {
        // Create MerkleDictionary with specific key
        let radixNode = RadixNodeImpl<String>(prefix: "key1", value: "dict-value", children: [:])
        let radixHeader = RadixHeaderImpl(node: radixNode)
        let children: [Character: RadixHeaderImpl<String>] = ["k": radixHeader]
        let dictionary = MerkleDictionaryImpl<String>(children: children, count: 1)
        let headerWithNode = HeaderImpl(node: dictionary)
        
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: headerWithNode.rawCID)
        let fetcher = TestStoreFetcher()
        try headerWithNode.storeRecursively(storer: fetcher)
        
        let paths = [["k", "key1"]: SparseMerkleProof.existence]
        let result = try await header.proof(paths: paths, fetcher: fetcher)
        
        #expect(result.rawCID == headerWithNode.rawCID)
        #expect(result.node?.count == 1)
    }
    
    // MARK: - Content Addressability Tests
    
    @Test("Header CID is deterministic")
    func testHeaderCIDDeterministic() async throws {
        // Create identical MerkleDictionaries
        let radixNode1 = RadixNodeImpl<String>(prefix: "same", value: "same-value", children: [:])
        let radixHeader1 = RadixHeaderImpl(node: radixNode1)
        let children1: [Character: RadixHeaderImpl<String>] = ["s": radixHeader1]
        let dictionary1 = MerkleDictionaryImpl<String>(children: children1, count: 1)
        
        let radixNode2 = RadixNodeImpl<String>(prefix: "same", value: "same-value", children: [:])
        let radixHeader2 = RadixHeaderImpl(node: radixNode2)
        let children2: [Character: RadixHeaderImpl<String>] = ["s": radixHeader2]
        let dictionary2 = MerkleDictionaryImpl<String>(children: children2, count: 1)
        
        let header1 = HeaderImpl(node: dictionary1)
        let header2 = HeaderImpl(node: dictionary2)
        
        #expect(header1.rawCID == header2.rawCID)
    }
    
    @Test("Header CID differs for different content")
    func testHeaderCIDDifferentContent() async throws {
        // Create different MerkleDictionaries
        let radixNode1 = RadixNodeImpl<String>(prefix: "content1", value: "value1", children: [:])
        let radixHeader1 = RadixHeaderImpl(node: radixNode1)
        let children1: [Character: RadixHeaderImpl<String>] = ["c": radixHeader1]
        let dictionary1 = MerkleDictionaryImpl<String>(children: children1, count: 1)
        
        let radixNode2 = RadixNodeImpl<String>(prefix: "content2", value: "value2", children: [:])
        let radixHeader2 = RadixHeaderImpl(node: radixNode2)
        let children2: [Character: RadixHeaderImpl<String>] = ["c": radixHeader2]
        let dictionary2 = MerkleDictionaryImpl<String>(children: children2, count: 1)
        
        let header1 = HeaderImpl(node: dictionary1)
        let header2 = HeaderImpl(node: dictionary2)
        
        #expect(header1.rawCID != header2.rawCID)
    }
    
    @Test("Header proof maintains content addressability")
    func testHeaderProofContentAddressability() async throws {
        // Create MerkleDictionary with content
        let radixNode = RadixNodeImpl<String>(prefix: "test-prop", value: "test-value", children: [:])
        let radixHeader = RadixHeaderImpl(node: radixNode)
        let children: [Character: RadixHeaderImpl<String>] = ["t": radixHeader]
        let dictionary = MerkleDictionaryImpl<String>(children: children, count: 1)
        let originalHeader = HeaderImpl(node: dictionary)
        let originalCID = originalHeader.rawCID
        
        // Create header without node and fetch via proof
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: originalCID)
        let fetcher = TestStoreFetcher()
        try originalHeader.storeRecursively(storer: fetcher)
        
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["t", "test-prop"], value: .existence)
        
        let result = try await header.proof(paths: paths, fetcher: fetcher)
        
        // CID should remain the same after proof
        #expect(result.rawCID == originalCID)
        #expect(result.node?.count == 1)
    }
    
    // MARK: - Additional Proof Type Tests
    
    @Test("Header proof validates deletion on property")
    func testHeaderProofDeletionProperty() async throws {
        // Create MerkleDictionary with deletable key
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "deletable", value: "to-delete")
        let headerWithNode = HeaderImpl(node: dictionary)
        
        // Create header without node - will fetch from storage
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
    
    @Test("Header proof validates insertion on property")
    func testHeaderProofInsertionProperty() async throws {
        // Create empty MerkleDictionary (insertion target doesn't exist yet)
        let dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        let headerWithNode = HeaderImpl(node: dictionary)
        
        // Create header without node - will fetch from storage
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: headerWithNode.rawCID)
        let fetcher = TestStoreFetcher()
        try headerWithNode.storeRecursively(storer: fetcher)
        
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["insertable"], value: .insertion)
        
        let result = try await header.proof(paths: paths, fetcher: fetcher)
        let resultAfterInsertion = try result.node!.inserting(key: "insertable", value: "inserted-value")
        
        #expect(result.rawCID == headerWithNode.rawCID)
        #expect(result.node?.count == 0)
        #expect(resultAfterInsertion.count == 1)
        #expect(try resultAfterInsertion.get(key: "insertable") == "inserted-value")
    }
    
    @Test("Header proof mixed proof types on same header")
    func testHeaderProofMixedTypes() async throws {
        // Create MerkleDictionary with multiple keys for different proof types
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "existing", value: "existing-value")
        dictionary = try dictionary.inserting(key: "mutable", value: "original-value")
        dictionary = try dictionary.inserting(key: "deletable", value: "to-delete")
        // Note: "insertable" key is not pre-inserted for insertion proof
        let headerWithNode = HeaderImpl(node: dictionary)
        
        // Create header without node - will fetch from storage
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: headerWithNode.rawCID)
        let fetcher = TestStoreFetcher()
        try headerWithNode.storeRecursively(storer: fetcher)
        
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["existing"], value: .existence)
        paths.set(["mutable"], value: .mutation)
        paths.set(["deletable"], value: .deletion)
        paths.set(["insertable"], value: .insertion)
        
        let result = try await header.proof(paths: paths, fetcher: fetcher)
        
        #expect(result.rawCID == headerWithNode.rawCID)
        #expect(result.node?.count == 3)
    }
}