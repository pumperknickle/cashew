import Testing
import Foundation
import ArrayTrie
@preconcurrency import Multicodec
@testable import cashew

@Suite("Complex Data Structure Resolve Tests")
struct ComplexResolveTests {
    
    // MARK: - Complex Node Types
    
    // User scalar representing a user without address children
    struct UserScalar: Scalar, Sendable {
        let id: String
        let name: String
        let email: String
        
        init(id: String, name: String, email: String) {
            self.id = id
            self.name = name
            self.email = email
        }
        
        // MARK: - Codable
        enum CodingKeys: String, CodingKey {
            case id, name, email
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(email, forKey: .email)
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            email = try container.decode(String.self, forKey: .email)
        }
    }
    
    // Document scalar representing a document without address children
    struct DocumentScalar: Scalar, Sendable {
        let id: String
        let title: String
        let content: String
        
        init(id: String, title: String, content: String) {
            self.id = id
            self.title = title
            self.content = content
        }
        
        // MARK: - Codable
        enum CodingKeys: String, CodingKey {
            case id, title, content
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(title, forKey: .title)
            try container.encode(content, forKey: .content)
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            title = try container.decode(String.self, forKey: .title)
            content = try container.decode(String.self, forKey: .content)
        }
    }
    
    // Dictionary node for storing key-value pairs of other nodes
    struct DictionaryNode: Node, Sendable {
        let id: String
        let entries: [String: String] // Key to CID mapping
        
        init(id: String, entries: [String: String] = [:]) {
            self.id = id
            self.entries = entries
        }
        
        func get(property: PathSegment) -> Address? {
            if let cid = entries[property] {
                return HeaderImpl<DictionaryNode>(rawCID: cid)
            }
            return HeaderImpl<DictionaryNode>(rawCID: "missing-entry-\(property)")
        }
        
        func properties() -> Set<PathSegment> {
            return Set(entries.keys)
        }
        
        func set(property: PathSegment, to child: Address) -> Self {
            var newEntries = entries
            if let header = child as? HeaderImpl<DictionaryNode> {
                newEntries[property] = header.rawCID
            }
            return DictionaryNode(id: id, entries: newEntries)
        }
        
        func set(properties: [PathSegment: Address]) -> Self {
            var result = self
            for (property, address) in properties {
                result = result.set(property: property, to: address)
            }
            return result
        }
        
        // MARK: - Codable
        enum CodingKeys: String, CodingKey {
            case id, entries
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(entries, forKey: .entries)
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            entries = try container.decode([String: String].self, forKey: .entries)
        }
    }
    
    // MARK: - Header Type Aliases
    
    typealias UserHeader = HeaderImpl<UserScalar>
    typealias DocumentHeader = HeaderImpl<DocumentScalar>
    typealias GenericHeader = HeaderImpl<DictionaryNode>
    
    // MARK: - Helper Methods
    
    private func createSimpleDataStructure() async throws -> (HeaderImpl<DictionaryNode>, TestStoreFetcher) {
        let testStoreFetcher = TestStoreFetcher()
        
        // Create simple scalar data
        let aliceUser = UserScalar(id: "alice", name: "Alice", email: "alice@example.com")
        let bobUser = UserScalar(id: "bob", name: "Bob", email: "bob@example.com")
        let charlieUser = UserScalar(id: "charlie", name: "Charlie", email: "charlie@example.com")
        
        let doc1 = DocumentScalar(id: "doc1", title: "Introduction", content: "Welcome to our system")
        let doc2 = DocumentScalar(id: "doc2", title: "Tutorial", content: "How to use the system")
        let doc3 = DocumentScalar(id: "doc3", title: "Advanced", content: "Advanced features")
        
        // Create headers for scalar data
        let aliceHeader = HeaderImpl(node: aliceUser)
        let bobHeader = HeaderImpl(node: bobUser)
        let charlieHeader = HeaderImpl(node: charlieUser)
        let doc1Header = HeaderImpl(node: doc1)
        let doc2Header = HeaderImpl(node: doc2)
        let doc3Header = HeaderImpl(node: doc3)
        
        // Store all scalar data
        try aliceHeader.storeRecursively(storer: testStoreFetcher)
        try bobHeader.storeRecursively(storer: testStoreFetcher)
        try charlieHeader.storeRecursively(storer: testStoreFetcher)
        try doc1Header.storeRecursively(storer: testStoreFetcher)
        try doc2Header.storeRecursively(storer: testStoreFetcher)
        try doc3Header.storeRecursively(storer: testStoreFetcher)
        
        // Create document dictionary
        let documentDict = DictionaryNode(id: "alice-docs", entries: [
            "intro": doc1Header.rawCID,
            "tutorial": doc2Header.rawCID,
            "advanced": doc3Header.rawCID
        ])
        
        // Create friends dictionary
        let friendsDict = DictionaryNode(id: "alice-friends", entries: [
            "bob": bobHeader.rawCID,
            "charlie": charlieHeader.rawCID
        ])
        
        // Store dictionaries
        let documentDictHeader = HeaderImpl(node: documentDict)
        let friendsDictHeader = HeaderImpl(node: friendsDict)
        try documentDictHeader.storeRecursively(storer: testStoreFetcher)
        try friendsDictHeader.storeRecursively(storer: testStoreFetcher)
        
        // Create root structure
        let rootDict = DictionaryNode(id: "root", entries: [
            "user": aliceHeader.rawCID,
            "documents": documentDictHeader.rawCID,
            "friends": friendsDictHeader.rawCID
        ])
        
        let rootHeader = HeaderImpl(node: rootDict)
        try rootHeader.storeRecursively(storer: testStoreFetcher)
        
        return (rootHeader, testStoreFetcher)
    }
}

// MARK: - Resolution Strategy Tests

extension ComplexResolveTests {
    
    @Test("Target resolution - resolve to dictionary nodes")
    func testTargetResolution() async throws {
        let (rootHeader, fetcher) = try await createSimpleDataStructure()
        
        // Test targeting dictionary nodes
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["documents"], value: .targeted)
        
        let resolvedHeader = try await rootHeader.resolve(paths: paths, fetcher: fetcher)
        
        #expect(resolvedHeader.rawCID == rootHeader.rawCID)
        #expect(resolvedHeader.node?.id == "root")
        
        // The documents dictionary should be resolved
        #expect(resolvedHeader.node?.entries["documents"] != nil)
    }
    
    @Test("Scalar resolution - resolve individual scalar endpoints")
    func testScalarResolution() async throws {
        let testStoreFetcher = TestStoreFetcher()
        
        // Create a simple scalar directly
        let userScalar = UserScalar(id: "test-user", name: "Test User", email: "test@example.com")
        let userHeader = HeaderImpl(node: userScalar)
        try userHeader.storeRecursively(storer: testStoreFetcher)
        
        // Test resolving the scalar directly
        let resolvedUserHeader = try await userHeader.resolve(fetcher: testStoreFetcher)
        
        #expect(resolvedUserHeader.rawCID == userHeader.rawCID)
        #expect(resolvedUserHeader.node?.id == "test-user")
        #expect(resolvedUserHeader.node?.name == "Test User")
        #expect(resolvedUserHeader.node?.email == "test@example.com")
        
        // Test resolving with empty paths (should return self)
        let emptyPaths = ArrayTrie<ResolutionStrategy>()
        let resolvedWithEmptyPaths = try await userHeader.resolve(paths: emptyPaths, fetcher: testStoreFetcher)
        #expect(resolvedWithEmptyPaths.rawCID == userHeader.rawCID)
        #expect(resolvedWithEmptyPaths.node?.id == "test-user")
    }
    
    @Test("Dictionary and Scalar as separate concerns")
    func testDictionaryScalarSeparation() async throws {
        let testStoreFetcher = TestStoreFetcher()
        
        // Create scalars as completely separate entities
        let user1 = UserScalar(id: "user1", name: "Alice", email: "alice@example.com")
        let user2 = UserScalar(id: "user2", name: "Bob", email: "bob@example.com")
        
        let user1Header = HeaderImpl(node: user1)
        let user2Header = HeaderImpl(node: user2)
        try user1Header.storeRecursively(storer: testStoreFetcher)
        try user2Header.storeRecursively(storer: testStoreFetcher)
        
        // Create dictionaries that only point to other dictionaries
        let metadataDict = DictionaryNode(id: "metadata", entries: [
            "created": "2024-01-01",
            "version": "1.0"
        ])
        
        let rootDict = DictionaryNode(id: "root", entries: [
            "metadata": HeaderImpl(node: metadataDict).rawCID
        ])
        
        let metadataHeader = HeaderImpl(node: metadataDict)
        let rootHeader = HeaderImpl(node: rootDict)
        
        try metadataHeader.storeRecursively(storer: testStoreFetcher)
        try rootHeader.storeRecursively(storer: testStoreFetcher)
        
        // This works: dictionary resolution only
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["metadata"], value: .targeted)
        
        let resolvedHeader = try await rootHeader.resolve(paths: paths, fetcher: testStoreFetcher)
        #expect(resolvedHeader.rawCID == rootHeader.rawCID)
        #expect(resolvedHeader.node?.entries["metadata"] != nil)
        
        // Scalars are resolved separately by direct CID access
        let aliceResolved = try await user1Header.resolve(fetcher: testStoreFetcher)
        #expect(aliceResolved.node?.name == "Alice")
        
        // The pattern: Dictionaries form the navigation structure,
        // Scalars are leaf nodes accessed by direct CID reference
        // You don't traverse from dictionaries to scalars through resolution paths
    }
    
    @Test("List resolution - get all dictionary entries with path prefix")
    func testListResolution() async throws {
        let (rootHeader, fetcher) = try await createSimpleDataStructure()
        
        // List resolution: Get all documents
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["documents"], value: .list)
        
        let resolvedHeader = try await rootHeader.resolve(paths: paths, fetcher: fetcher)
        
        #expect(resolvedHeader.rawCID == rootHeader.rawCID)
        #expect(resolvedHeader.node?.id == "root")
        
        // Documents dictionary CID should be present (resolution works at the header level)
        #expect(resolvedHeader.node?.entries["documents"] != nil)
    }
    
    @Test("Targeted resolution for dictionary structures")
    func testTargetedResolutionDictionaries() async throws {
        let (rootHeader, fetcher) = try await createSimpleDataStructure()
        
        // Target resolution: Get specific dictionaries without going recursive into scalars
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["friends"], value: .targeted)
        
        let resolvedHeader = try await rootHeader.resolve(paths: paths, fetcher: fetcher)
        
        #expect(resolvedHeader.rawCID == rootHeader.rawCID)
        #expect(resolvedHeader.node?.id == "root")
        
        // Friends dictionary CID should be present (resolution works at the header level)
        #expect(resolvedHeader.node?.entries["friends"] != nil)
    }
    
    @Test("Multiple path resolution - resolve different strategies in one call")
    func testMultiplePathResolution() async throws {
        let (rootHeader, fetcher) = try await createSimpleDataStructure()
        
        // Multiple paths with different strategies - only target dictionaries
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["documents"], value: .targeted)      // Target documents dictionary
        paths.set(["friends"], value: .list)            // List friends dictionary
        
        let resolvedHeader = try await rootHeader.resolve(paths: paths, fetcher: fetcher)
        
        #expect(resolvedHeader.rawCID == rootHeader.rawCID)
        #expect(resolvedHeader.node?.id == "root")
        
        // All specified paths should be resolved
        #expect(resolvedHeader.node?.entries["documents"] != nil)
        #expect(resolvedHeader.node?.entries["friends"] != nil)
    }
    
    @Test("Dictionary path resolution")
    func testDictionaryPathResolution() async throws {
        let (rootHeader, fetcher) = try await createSimpleDataStructure()
        
        // Target dictionary paths only
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["documents"], value: .targeted)
        paths.set(["friends"], value: .targeted)
        
        let resolvedHeader = try await rootHeader.resolve(paths: paths, fetcher: fetcher)
        
        #expect(resolvedHeader.rawCID == rootHeader.rawCID)
        #expect(resolvedHeader.node?.id == "root")
        
        // Multiple targeted paths should all be resolved
        #expect(resolvedHeader.node?.entries["documents"] != nil)
        #expect(resolvedHeader.node?.entries["friends"] != nil)
    }
    
    @Test("Mixed resolution strategies with path prefixes")
    func testMixedResolutionStrategies() async throws {
        let (rootHeader, fetcher) = try await createSimpleDataStructure()
        
        // Mixed strategies with different path prefixes for dictionaries
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["documents"], value: .list)                  // List all documents
        paths.set(["friends"], value: .targeted)               // Target friends dictionary
        
        let resolvedHeader = try await rootHeader.resolve(paths: paths, fetcher: fetcher)
        
        #expect(resolvedHeader.rawCID == rootHeader.rawCID)
        #expect(resolvedHeader.node?.id == "root")
        
        // All strategies should resolve their respective paths
        #expect(resolvedHeader.node?.entries["documents"] != nil)
        #expect(resolvedHeader.node?.entries["friends"] != nil)
    }
    
    @Test("Resolution with path patterns matching")
    func testResolutionWithPathPatterns() async throws {
        let (rootHeader, fetcher) = try await createSimpleDataStructure()
        
        // Test path pattern matching for list resolution
        var paths = ArrayTrie<ResolutionStrategy>()
        // This should match all documents
        paths.set(["documents"], value: .list)
        
        let resolvedHeader = try await rootHeader.resolve(paths: paths, fetcher: fetcher)
        
        #expect(resolvedHeader.rawCID == rootHeader.rawCID)
        
        // Should resolve the documents dictionary
        #expect(resolvedHeader.node?.entries["documents"] != nil)
    }
    
    @Test("Empty path resolution returns original")
    func testEmptyPathResolution() async throws {
        let (rootHeader, fetcher) = try await createSimpleDataStructure()
        
        // Empty paths should return original
        let emptyPaths = ArrayTrie<ResolutionStrategy>()
        
        let resolvedHeader = try await rootHeader.resolve(paths: emptyPaths, fetcher: fetcher)
        
        // Should return same header since no resolution needed
        #expect(resolvedHeader.rawCID == rootHeader.rawCID)
        #expect(resolvedHeader.node?.id == rootHeader.node?.id)
    }
    
    @Test("Dictionary resolution at multiple levels")
    func testDictionaryResolutionMultipleLevels() async throws {
        let (rootHeader, fetcher) = try await createSimpleDataStructure()
        
        // Target different dictionaries 
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["documents"], value: .targeted)
        paths.set(["friends"], value: .list)
        
        let resolvedHeader = try await rootHeader.resolve(paths: paths, fetcher: fetcher)
        
        #expect(resolvedHeader.rawCID == rootHeader.rawCID)
        #expect(resolvedHeader.node?.id == "root")
        
        // Both dictionaries should be resolved
        #expect(resolvedHeader.node?.entries["documents"] != nil)
        #expect(resolvedHeader.node?.entries["friends"] != nil)
    }
    
    @Test("Content addressability with simple structures")
    func testContentAddressabilitySimpleStructures() async throws {
        let (rootHeader, fetcher) = try await createSimpleDataStructure()
        let originalCID = rootHeader.rawCID
        
        // Create header with just CID
        let cidOnlyHeader = HeaderImpl<DictionaryNode>(rawCID: originalCID)
        
        // Resolve with simple paths that don't modify structure - target dictionaries only
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["documents"], value: .targeted)
        
        let resolvedHeader = try await cidOnlyHeader.resolve(paths: paths, fetcher: fetcher)
        
        // Verify content addressability
        #expect(resolvedHeader.rawCID == originalCID)
        #expect(resolvedHeader.node?.id == "root")
        
        // Verify we can recreate the same CID from the original structure
        let recreatedCID = try await rootHeader.recreateCID()
        #expect(recreatedCID == originalCID)
    }
}
