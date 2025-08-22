import Testing
import Foundation
import ArrayTrie
@preconcurrency import Multicodec
@testable import cashew

@Suite("Merkle Dictionary Proof Tests")
struct MerkleDictionaryProofTests {
    // MARK: - Deletion Proof Tests
    
    @Test("MerkleDictionary deletion proof validates removal of existing key")
    func testMerkleDictionaryDeletionProof() async throws {
        // Create dictionary with deletable key
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "test", value: "to-be-deleted")
        let dictHeader = HeaderImpl(node: dictionary)
        
        // Create header without node - will fetch from storage
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: dictHeader.rawCID)
        let fetcher = TestStoreFetcher()
        try dictHeader.storeRecursively(storer: fetcher)
        
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["test"], value: .deletion)
        
        let result = try await header.proof(paths: paths, fetcher: fetcher)
        let resultAfterDeletion = try result.node!.deleting(key: "test")
        
        #expect(result.rawCID == dictHeader.rawCID)
        #expect(result.node?.count == 1) // Count remains same during proof
        #expect(resultAfterDeletion.count == 0)
        #expect(try resultAfterDeletion.get(key: "test") == nil)
    }
    
    @Test("MerkleDictionary deletion proof fails for non-existing key")
    func testMerkleDictionaryDeletionProofFailsForNonExisting() async throws {
        // Create dictionary with one key
        let radixNode = RadixNodeImpl<String>(prefix: "existing-key", value: "value", children: [:])
        let radixHeader = RadixHeaderImpl(node: radixNode)
        let children: [Character: RadixHeaderImpl<String>] = ["e": radixHeader]
        let dictionary = MerkleDictionaryImpl<String>(children: children, count: 1)
        let dictHeader = HeaderImpl(node: dictionary)
        
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: dictHeader.rawCID)
        let fetcher = TestStoreFetcher()
        try dictHeader.storeRecursively(storer: fetcher)
        
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["n", "non-existing-key"], value: .deletion)
        
        await #expect(throws: ProofErrors.self) {
            _ = try await header.proof(paths: paths, fetcher: fetcher)
        }
    }
    
    @Test("MerkleDictionary deletion proof with nested radix structure")
    func testMerkleDictionaryDeletionProofNested() async throws {
        // Create dictionary with multiple keys
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "common-suffix1", value: "value1")
        dictionary = try dictionary.inserting(key: "common-suffix2", value: "value2")
        let dictHeader = HeaderImpl(node: dictionary)
        
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: dictHeader.rawCID)
        let fetcher = TestStoreFetcher()
        try dictHeader.storeRecursively(storer: fetcher)
        
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["common-suffix1"], value: .deletion)
        
        let result = try await header.proof(paths: paths, fetcher: fetcher)
        
        #expect(result.rawCID == dictHeader.rawCID)
        #expect(result.node?.count == 2)
    }
    
    // MARK: - Insertion Proof Tests
    
    @Test("MerkleDictionary insertion proof validates adding new key")
    func testMerkleDictionaryInsertionProof() async throws {
        // Create empty dictionary (insertion target doesn't exist yet)
        let dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        let dictHeader = HeaderImpl(node: dictionary)
        
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: dictHeader.rawCID)
        let fetcher = TestStoreFetcher()
        try dictHeader.storeRecursively(storer: fetcher)
        
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["test"], value: .insertion)
        
        let result = try await header.proof(paths: paths, fetcher: fetcher)
        let resultAfterInsertion = try result.node!.inserting(key: "test", value: "inserted-value")
        
        #expect(result.rawCID == dictHeader.rawCID)
        #expect(result.node?.count == 0)
        #expect(resultAfterInsertion.count == 1)
        #expect(try resultAfterInsertion.get(key: "test") == "inserted-value")
    }
    
    @Test("MerkleDictionary insertion proof fails for existing key")
    func testMerkleDictionaryInsertionProofFailsForExisting() async throws {
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "existing-key", value: "value")
        let dictHeader = HeaderImpl(node: dictionary)
        
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: dictHeader.rawCID)
        let fetcher = TestStoreFetcher()
        try dictHeader.storeRecursively(storer: fetcher)
        
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["existing-key"], value: .insertion)
        
        await #expect(throws: ProofErrors.self) {
            _ = try await header.proof(paths: paths, fetcher: fetcher)
        }
    }
    
    @Test("MerkleDictionary insertion proof with complex radix splitting")
    func testMerkleDictionaryInsertionProofRadixSplit() async throws {
        // Create a radix node that will need to split when inserting
        let existingNode = RadixNodeImpl<String>(prefix: "commonprefix", value: "existing-value", children: [:])
        let existingHeader = RadixHeaderImpl(node: existingNode)
        
        let children: [Character: RadixHeaderImpl<String>] = ["c": existingHeader]
        let dictionary = MerkleDictionaryImpl<String>(children: children, count: 1)
        let dictHeader = HeaderImpl(node: dictionary)
        
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: dictHeader.rawCID)
        let fetcher = TestStoreFetcher()
        try dictHeader.storeRecursively(storer: fetcher)
        
        // Try to insert a key that shares a prefix but differs
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["c", "commondifferent"], value: .insertion)
        
        let result = try await header.proof(paths: paths, fetcher: fetcher)
        
        #expect(result.rawCID == dictHeader.rawCID)
        #expect(result.node?.count == 1)
    }
    
    // MARK: - Mutation Proof Tests
    
    @Test("MerkleDictionary mutation proof validates updating existing key")
    func testMerkleDictionaryMutationProof() async throws {
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "mutable-key", value: "original-value")
        let dictHeader = HeaderImpl(node: dictionary)
        
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: dictHeader.rawCID)
        let fetcher = TestStoreFetcher()
        try dictHeader.storeRecursively(storer: fetcher)
        
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["mutable-key"], value: .mutation)
        
        let result = try await header.proof(paths: paths, fetcher: fetcher)
        let resultAfterMutation = try result.node!.mutating(key: "mutable-key", value: "updated-value")
        
        #expect(result.rawCID == dictHeader.rawCID)
        #expect(result.node?.count == 1)
        #expect(try resultAfterMutation.get(key: "mutable-key") == "updated-value")
    }
    
    @Test("MerkleDictionary mutation proof fails for non-existing key")
    func testMerkleDictionaryMutationProofFailsForNonExisting() async throws {
        let existingNode = RadixNodeImpl<String>(prefix: "existing", value: "value", children: [:])
        let existingHeader = RadixHeaderImpl(node: existingNode)
        
        let children: [Character: RadixHeaderImpl<String>] = ["e": existingHeader]
        let dictionary = MerkleDictionaryImpl<String>(children: children, count: 1)
        let dictHeader = HeaderImpl(node: dictionary)
        
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: dictHeader.rawCID)
        let fetcher = TestStoreFetcher()
        try dictHeader.storeRecursively(storer: fetcher)
        
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["n", "non-existing"], value: .mutation)
        
        await #expect(throws: ProofErrors.self) {
            _ = try await header.proof(paths: paths, fetcher: fetcher)
        }
    }
    
    @Test("MerkleDictionary mutation proof with deep nesting")
    func testMerkleDictionaryMutationProofDeepNesting() async throws {
        // Create dictionary with nested key structure
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "deep-nested-key", value: "deep-value")
        let dictHeader = HeaderImpl(node: dictionary)
        
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: dictHeader.rawCID)
        let fetcher = TestStoreFetcher()
        try dictHeader.storeRecursively(storer: fetcher)
        
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["deep-nested-key"], value: .mutation)
        
        let result = try await header.proof(paths: paths, fetcher: fetcher)
        
        #expect(result.rawCID == dictHeader.rawCID)
        #expect(result.node?.count == 1)
    }
    
    // MARK: - Existence Proof Tests
    
    @Test("MerkleDictionary existence proof validates present key")
    func testMerkleDictionaryExistenceProof() async throws {
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "existing-key", value: "existing-value")
        let dictHeader = HeaderImpl(node: dictionary)
        
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: dictHeader.rawCID)
        let fetcher = TestStoreFetcher()
        try dictHeader.storeRecursively(storer: fetcher)
        
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["existing-key"], value: .existence)
        
        let result = try await header.proof(paths: paths, fetcher: fetcher)
        
        #expect(result.rawCID == dictHeader.rawCID)
        #expect(result.node?.count == 1)
        #expect(try result.node!.get(key: "existing-key") == "existing-value")
    }
    
    @Test("MerkleDictionary existence proof with multiple concurrent validations")
    func testMerkleDictionaryExistenceProofMultiple() async throws {
        // Create multiple keys
        let node1 = RadixNodeImpl<String>(prefix: "key1", value: "value1", children: [:])
        let header1 = RadixHeaderImpl(node: node1)
        
        let node2 = RadixNodeImpl<String>(prefix: "key2", value: "value2", children: [:])
        let header2 = RadixHeaderImpl(node: node2)
        
        let node3 = RadixNodeImpl<String>(prefix: "key3", value: "value3", children: [:])
        let header3 = RadixHeaderImpl(node: node3)
        
        let children: [Character: RadixHeaderImpl<String>] = [
            "k": header1,  // This will be overwritten by subsequent assignments in real usage
            "l": header2,  // Different first characters for proper testing
            "m": header3
        ]
        let dictionary = MerkleDictionaryImpl<String>(children: children, count: 3)
        let dictHeader = HeaderImpl(node: dictionary)
        
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: dictHeader.rawCID)
        let fetcher = TestStoreFetcher()
        try dictHeader.storeRecursively(storer: fetcher)
        
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["k", "key1"], value: .existence)
        paths.set(["l", "key2"], value: .existence)
        paths.set(["m", "key3"], value: .existence)
        
        let result = try await header.proof(paths: paths, fetcher: fetcher)
        
        #expect(result.rawCID == dictHeader.rawCID)
        #expect(result.node?.count == 3)
    }
    
    // MARK: - Mixed Proof Type Tests
    
    @Test("MerkleDictionary mixed proof types in single validation")
    func testMerkleDictionaryMixedProofTypes() async throws {
        // Create dictionary with multiple keys for different proof types
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "existing", value: "value")
        dictionary = try dictionary.inserting(key: "mutable", value: "original")
        dictionary = try dictionary.inserting(key: "deletable", value: "to-delete")
        // Note: "new-insertion" key is not pre-inserted for insertion proof
        let dictHeader = HeaderImpl(node: dictionary)
        
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: dictHeader.rawCID)
        let fetcher = TestStoreFetcher()
        try dictHeader.storeRecursively(storer: fetcher)
        
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["existing"], value: .existence)      // Validate existence
        paths.set(["mutable"], value: .mutation)        // Validate mutation
        paths.set(["deletable"], value: .deletion)      // Validate deletion
        paths.set(["new-insertion"], value: .insertion) // Validate insertion
        
        let result = try await header.proof(paths: paths, fetcher: fetcher)
        
        #expect(result.rawCID == dictHeader.rawCID)
        #expect(result.node?.count == 3)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("MerkleDictionary proof with missing storage data throws error")
    func testMerkleDictionaryProofMissingData() async throws {
        let node = RadixNodeImpl<String>(prefix: "test", value: "value", children: [:])
        let radixHeader = RadixHeaderImpl(node: node)
        
        let children: [Character: RadixHeaderImpl<String>] = ["t": radixHeader]
        let dictionary = MerkleDictionaryImpl<String>(children: children, count: 1)
        let dictHeader = HeaderImpl(node: dictionary)
        
        // Create header without node and empty fetcher
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: dictHeader.rawCID)
        let fetcher = TestStoreFetcher() // Empty storage
        
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["t", "test"], value: .existence)
        
        await #expect(throws: Error.self) {
            _ = try await header.proof(paths: paths, fetcher: fetcher)
        }
    }
    
    // MARK: - Content Addressability Tests
    
    @Test("MerkleDictionary proof maintains content addressability")
    func testMerkleDictionaryProofContentAddressability() async throws {
        let node = RadixNodeImpl<String>(prefix: "content-test", value: "test-value", children: [:])
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
        paths.set(["c", "content-test"], value: .existence)
        
        let result = try await header.proof(paths: paths, fetcher: fetcher)
        
        // CID should remain the same after proof
        #expect(result.rawCID == originalCID)
        #expect(result.node?.count == 1)
    }
}
