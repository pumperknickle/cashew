import Testing
import Foundation
import ArrayTrie
@preconcurrency import Multicodec
@testable import cashew

@Suite("Dictionary Proof Tests")
struct DictionaryProofTests {
    // MARK: - Basic Dictionary Proof Tests
    
    @Test("Dictionary proof with empty paths returns self")
    func testDictionaryProofEmptyPaths() async throws {
        // Create MerkleDictionary using proper insert operation
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "test", value: "test-value")
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
        // Create MerkleDictionary using proper insert operations
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "parent", value: "parent-value")
        dictionary = try dictionary.inserting(key: "parentchild", value: "child-value")
        let headerWithNode = HeaderImpl(node: dictionary)
        
        // Create header without node - will fetch from storage
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: headerWithNode.rawCID)
        let fetcher = TestStoreFetcher()
        try headerWithNode.storeRecursively(storer: fetcher)
        
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["parentchild"], value: .existence)
        
        let result = try await header.proof(paths: paths, fetcher: fetcher)
        
        #expect(result.rawCID == headerWithNode.rawCID)
        #expect(result.node?.count == 2)
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
        let resultAfterMutation = try result.node!.mutating(key: "test", value: "new-value")
        
        #expect(result.rawCID == headerWithNode.rawCID)
        #expect(result.node?.count == 1)
        #expect(try resultAfterMutation.get(key: "test") == "new-value")
    }
    
    @Test("Dictionary proof validates insertion on new property")
    func testDictionaryProofInsertionProperty() async throws {
        // Create empty dictionary (insertion target doesn't exist yet)
        let dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        let headerWithNode = HeaderImpl(node: dictionary)
        
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: headerWithNode.rawCID)
        let fetcher = TestStoreFetcher()
        try headerWithNode.storeRecursively(storer: fetcher)
        
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["new-key"], value: .insertion)
        
        let result = try await header.proof(paths: paths, fetcher: fetcher)
        let resultAfterInsertion = try result.node!.inserting(key: "new-key", value: "new-value")
        
        #expect(result.rawCID == headerWithNode.rawCID)
        #expect(result.node?.count == 0)
        #expect(resultAfterInsertion.count == 1)
        #expect(try resultAfterInsertion.get(key: "new-key") == "new-value")
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
        // NOTE: This test manually creates RadixNodes to test edge case of nil values.
        // This cannot be easily replicated with MerkleDictionary.insert() which doesn't support nil values.
        // Manual creation is kept here to test this specific error condition.
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
            let header = try await header.proof(paths: paths, fetcher: fetcher)
            print(header)
        }
    }
    
    @Test("Dictionary proof with children processing")
    func testDictionaryProofWithChildren() async throws {
        // Create MerkleDictionary using proper insert operations
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "parent", value: "parent-value")
        dictionary = try dictionary.inserting(key: "parentchild", value: "child-value")
        let headerWithNode = HeaderImpl(node: dictionary)
        
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: headerWithNode.rawCID)
        let fetcher = TestStoreFetcher()
        try headerWithNode.storeRecursively(storer: fetcher)
        
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["parentchild"], value: .existence)
        
        let result = try await header.proof(paths: paths, fetcher: fetcher)
        
        #expect(result.rawCID == headerWithNode.rawCID)
        #expect(result.node?.count == 2)
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
        // Create MerkleDictionary using proper insert operation
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "test", value: "test-value")
        let headerWithNode = HeaderImpl(node: dictionary)
        
        // Create header without node and empty fetcher
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: headerWithNode.rawCID)
        let fetcher = TestStoreFetcher() // Empty storage
        
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["test"], value: .existence)
        
        await #expect(throws: Error.self) {
            _ = try await header.proof(paths: paths, fetcher: fetcher)
        }
    }
    
    // MARK: - Content Addressability Tests
    
    @Test("Dictionary CID is deterministic")
    func testDictionaryCIDDeterministic() async throws {
        // Create identical dictionaries using proper insert operations
        var dictionary1 = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary1 = try dictionary1.inserting(key: "same", value: "same-value")
        
        var dictionary2 = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary2 = try dictionary2.inserting(key: "same", value: "same-value")
        
        let header1 = HeaderImpl(node: dictionary1)
        let header2 = HeaderImpl(node: dictionary2)
        
        #expect(header1.rawCID == header2.rawCID)
    }
    
    @Test("Dictionary CID differs for different content")
    func testDictionaryCIDDifferentContent() async throws {
        // Create different dictionaries using proper insert operations
        var dictionary1 = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary1 = try dictionary1.inserting(key: "content1", value: "value1")
        
        var dictionary2 = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary2 = try dictionary2.inserting(key: "content2", value: "value2")
        
        let header1 = HeaderImpl(node: dictionary1)
        let header2 = HeaderImpl(node: dictionary2)
        
        #expect(header1.rawCID != header2.rawCID)
    }
    
    @Test("Dictionary proof maintains content addressability")
    func testDictionaryProofContentAddressability() async throws {
        // Create MerkleDictionary using proper insert operation
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "content", value: "test-value")
        let originalHeader = HeaderImpl(node: dictionary)
        let originalCID = originalHeader.rawCID
        
        // Create header without node and fetch via proof
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: originalCID)
        let fetcher = TestStoreFetcher()
        try originalHeader.storeRecursively(storer: fetcher)
        
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["content"], value: .existence)
        
        let result = try await header.proof(paths: paths, fetcher: fetcher)
        
        // CID should remain the same after proof
        #expect(result.rawCID == originalCID)
        #expect(result.node?.count == 1)
    }
    
    @Test("Dictionary proof validates multiple proof types in single call")
    func testDictionaryProofMultipleProofTypes() async throws {
        // Create dictionary with existing data for comprehensive testing
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "existing-key", value: "existing-value")
        dictionary = try dictionary.inserting(key: "mutable-key", value: "original-value")
        dictionary = try dictionary.inserting(key: "deletable-key", value: "to-be-deleted")
        let headerWithNode = HeaderImpl(node: dictionary)
        
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: headerWithNode.rawCID)
        let fetcher = TestStoreFetcher()
        try headerWithNode.storeRecursively(storer: fetcher)
        
        // Set up multiple proof types in a single call
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["existing-key"], value: .existence)      // Prove key exists
        paths.set(["mutable-key"], value: .mutation)        // Prove key can be mutated
        paths.set(["new-key"], value: .insertion)           // Prove new key can be inserted
        paths.set(["deletable-key"], value: .deletion)      // Prove key can be deleted
        
        let result = try await header.proof(paths: paths, fetcher: fetcher)
        
        // Verify original state
        #expect(result.rawCID == headerWithNode.rawCID)
        #expect(result.node?.count == 3)
        
        // Perform all operations on the proved dictionary
        var modifiedDict = result.node!
        
        // Verify existence proof - key should already exist
        #expect(try modifiedDict.get(key: "existing-key") == "existing-value")
        
        // Apply mutation proof
        modifiedDict = try modifiedDict.mutating(key: "mutable-key", value: "updated-value")
        #expect(try modifiedDict.get(key: "mutable-key") == "updated-value")
        
        // Apply insertion proof  
        modifiedDict = try modifiedDict.inserting(key: "new-key", value: "inserted-value")
        #expect(try modifiedDict.get(key: "new-key") == "inserted-value")
        
        // Apply deletion proof
        modifiedDict = try modifiedDict.deleting(key: "deletable-key")
        #expect(try modifiedDict.get(key: "deletable-key") == nil)
        
        // Verify final state - should have 3 keys (existing + new - deleted)
        #expect(modifiedDict.count == 3)
        #expect(try modifiedDict.get(key: "existing-key") == "existing-value")  // unchanged
        #expect(try modifiedDict.get(key: "mutable-key") == "updated-value")    // mutated
        #expect(try modifiedDict.get(key: "new-key") == "inserted-value")       // inserted
        #expect(try modifiedDict.get(key: "deletable-key") == nil)              // deleted
    }
}
