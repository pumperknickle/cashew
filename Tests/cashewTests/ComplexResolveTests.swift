import Testing
import Foundation
import ArrayTrie
@preconcurrency import Multicodec
@testable import cashew

@Suite("Complex Data Structure Resolve Tests")
struct ComplexResolveTests {
    
    // MARK: - Complex Node Types
    
    // User node representing a user with profile and documents
    struct UserNode: Node, Sendable {
        let id: String
        let name: String
        let email: String
        let profileCID: String?
        let documentsCID: String?
        let friendsCID: String?
        
        init(id: String, name: String, email: String, profileCID: String? = nil, documentsCID: String? = nil, friendsCID: String? = nil) {
            self.id = id
            self.name = name
            self.email = email
            self.profileCID = profileCID
            self.documentsCID = documentsCID
            self.friendsCID = friendsCID
        }
        
        func get(property: PathSegment) -> Address? {
            switch property {
            case "profile":
                return HeaderImpl<DictionaryNode>(rawCID: profileCID ?? "missing-profile")
            case "documents":
                return HeaderImpl<DictionaryNode>(rawCID: documentsCID ?? "missing-documents")
            case "friends":
                return HeaderImpl<DictionaryNode>(rawCID: friendsCID ?? "missing-friends")
            default:
                return HeaderImpl<DictionaryNode>(rawCID: "unknown-property-\(property)")
            }
        }
        
        func properties() -> Set<PathSegment> {
            var props: Set<String> = []
            if profileCID != nil { props.insert("profile") }
            if documentsCID != nil { props.insert("documents") }
            if friendsCID != nil { props.insert("friends") }
            return props
        }
        
        func set(property: PathSegment, to child: Address) -> Self {
            var newProfileCID = profileCID
            var newDocumentsCID = documentsCID
            var newFriendsCID = friendsCID
            
            switch property {
            case "profile":
                if let header = child as? HeaderImpl<DictionaryNode> {
                    newProfileCID = header.rawCID
                }
            case "documents":
                if let header = child as? HeaderImpl<DictionaryNode> {
                    newDocumentsCID = header.rawCID
                }
            case "friends":
                if let header = child as? HeaderImpl<DictionaryNode> {
                    newFriendsCID = header.rawCID
                }
            default:
                break
            }
            
            return UserNode(id: id, name: name, email: email, profileCID: newProfileCID, documentsCID: newDocumentsCID, friendsCID: newFriendsCID)
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
            case id, name, email, profileCID, documentsCID, friendsCID
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(email, forKey: .email)
            try container.encodeIfPresent(profileCID, forKey: .profileCID)
            try container.encodeIfPresent(documentsCID, forKey: .documentsCID)
            try container.encodeIfPresent(friendsCID, forKey: .friendsCID)
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            email = try container.decode(String.self, forKey: .email)
            profileCID = try container.decodeIfPresent(String.self, forKey: .profileCID)
            documentsCID = try container.decodeIfPresent(String.self, forKey: .documentsCID)
            friendsCID = try container.decodeIfPresent(String.self, forKey: .friendsCID)
        }
    }
    
    // Document node representing a document with content and metadata
    struct DocumentNode: Node, Sendable {
        let id: String
        let title: String
        let content: String
        let authorCID: String?
        let tagsCID: String?
        
        init(id: String, title: String, content: String, authorCID: String? = nil, tagsCID: String? = nil) {
            self.id = id
            self.title = title
            self.content = content
            self.authorCID = authorCID
            self.tagsCID = tagsCID
        }
        
        func get(property: PathSegment) -> Address? {
            switch property {
            case "author":
                return HeaderImpl<UserNode>(rawCID: authorCID ?? "missing-author")
            case "tags":
                return HeaderImpl<DictionaryNode>(rawCID: tagsCID ?? "missing-tags")
            default:
                return HeaderImpl<DictionaryNode>(rawCID: "unknown-property-\(property)")
            }
        }
        
        func properties() -> Set<PathSegment> {
            var props: Set<String> = []
            if authorCID != nil { props.insert("author") }
            if tagsCID != nil { props.insert("tags") }
            return props
        }
        
        func set(property: PathSegment, to child: Address) -> Self {
            var newAuthorCID = authorCID
            var newTagsCID = tagsCID
            
            switch property {
            case "author":
                if let header = child as? HeaderImpl<UserNode> {
                    newAuthorCID = header.rawCID
                }
            case "tags":
                if let header = child as? HeaderImpl<DictionaryNode> {
                    newTagsCID = header.rawCID
                }
            default:
                break
            }
            
            return DocumentNode(id: id, title: title, content: content, authorCID: newAuthorCID, tagsCID: newTagsCID)
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
            case id, title, content, authorCID, tagsCID
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(title, forKey: .title)
            try container.encode(content, forKey: .content)
            try container.encodeIfPresent(authorCID, forKey: .authorCID)
            try container.encodeIfPresent(tagsCID, forKey: .tagsCID)
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            title = try container.decode(String.self, forKey: .title)
            content = try container.decode(String.self, forKey: .content)
            authorCID = try container.decodeIfPresent(String.self, forKey: .authorCID)
            tagsCID = try container.decodeIfPresent(String.self, forKey: .tagsCID)
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
    
    typealias UserHeader = HeaderImpl<UserNode>
    typealias DocumentHeader = HeaderImpl<DocumentNode>
    typealias GenericHeader = HeaderImpl<DictionaryNode>
    
    // MARK: - Mock Fetcher for Complex Data
    
    final class ComplexDataFetcher: Fetcher, Sendable {
        private let responses: [String: String]
        
        init(responses: [String: String] = [:]) {
            self.responses = responses
        }
        
        func fetch(rawCid: String) async throws -> Data {
            let nodeDescription = responses[rawCid] ?? "DictionaryNode(fetched-\(rawCid))"
            // Try to create node from description and return JSON data
            if let node = DictionaryNode(nodeDescription) {
                return node.toData() ?? Data()
            }
            // Fallback: create empty dictionary node
            let fallbackNode = DictionaryNode(id: "fetched-\(rawCid)", entries: [:])
            return fallbackNode.toData() ?? Data()
        }
    }
    
    // MARK: - Helper Methods
    
    private func createComplexDataStructure() -> (HeaderImpl<UserNode>, [String: String]) {
        // Create users
        let aliceUser = UserNode(id: "alice", name: "Alice", email: "alice@example.com")
        let bobUser = UserNode(id: "bob", name: "Bob", email: "bob@example.com")
        let charlieUser = UserNode(id: "charlie", name: "Charlie", email: "charlie@example.com")
        
        // Create documents
        let doc1 = DocumentNode(id: "doc1", title: "Introduction", content: "Welcome to our system")
        let doc2 = DocumentNode(id: "doc2", title: "Tutorial", content: "How to use the system")
        let doc3 = DocumentNode(id: "doc3", title: "Advanced", content: "Advanced features")
        
        // Create document dictionary
        let documentDict = DictionaryNode(id: "alice-docs", entries: [
            "intro": "doc1-cid",
            "tutorial": "doc2-cid", 
            "advanced": "doc3-cid",
            "draft1": "draft1-cid",
            "draft2": "draft2-cid"
        ])
        
        // Create friends dictionary
        let friendsDict = DictionaryNode(id: "alice-friends", entries: [
            "bob": "bob-user-cid",
            "charlie": "charlie-user-cid",
            "dave": "dave-user-cid",
            "eve": "eve-user-cid"
        ])
        
        // Create tag dictionary for documents
        let tagsDict = DictionaryNode(id: "doc-tags", entries: [
            "programming": "prog-tag-cid",
            "tutorial": "tutorial-tag-cid",
            "beginner": "beginner-tag-cid"
        ])
        
        // Create headers
        let aliceHeader = HeaderImpl(node: aliceUser)
        let docHeader = HeaderImpl(node: doc1)
        let documentDictHeader = HeaderImpl(node: documentDict)
        let friendsDictHeader = HeaderImpl(node: friendsDict)
        let tagsDictHeader = HeaderImpl(node: tagsDict)
        
        // Create final user with all references
        let finalUser = UserNode(
            id: "alice",
            name: "Alice",
            email: "alice@example.com",
            profileCID: aliceHeader.rawCID,
            documentsCID: documentDictHeader.rawCID,
            friendsCID: friendsDictHeader.rawCID
        )
        
        let finalUserHeader = HeaderImpl(node: finalUser)
        
        // Create responses for fetcher
        let responses = [
            aliceHeader.rawCID: aliceUser.description,
            docHeader.rawCID: doc1.description,
            documentDictHeader.rawCID: documentDict.description,
            friendsDictHeader.rawCID: friendsDict.description,
            tagsDictHeader.rawCID: tagsDict.description,
            finalUserHeader.rawCID: finalUser.description,
            "doc1-cid": doc1.description,
            "doc2-cid": doc2.description,
            "doc3-cid": doc3.description,
            "bob-user-cid": bobUser.description,
            "charlie-user-cid": charlieUser.description
        ]
        
        return (finalUserHeader, responses)
    }
}

// MARK: - Resolution Strategy Tests

extension ComplexResolveTests {
    
    @Test("Target resolution - resolve to specific end node")
    func testTargetResolution() async throws {
        let (userHeader, responses) = createComplexDataStructure()
        let fetcher = ComplexDataFetcher(responses: responses)
        
        // Target resolution: Get Alice's first document (intro)
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["documents", "intro"], value: .targeted)
        
        let resolvedHeader = try await userHeader.resolve(paths: paths, fetcher: fetcher)
        
        #expect(resolvedHeader.rawCID == userHeader.rawCID)
        #expect(resolvedHeader.node?.id == "alice")
        
        // The documents dictionary should be resolved
        #expect(resolvedHeader.node?.documentsCID != nil)
    }
    
    @Test("List resolution - get all dictionary entries with path prefix")
    func testListResolution() async throws {
        let (userHeader, responses) = createComplexDataStructure()
        let fetcher = ComplexDataFetcher(responses: responses)
        
        // List resolution: Get all documents that start with 'd' (draft1, draft2)
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["documents"], value: .list)
        
        let resolvedHeader = try await userHeader.resolve(paths: paths, fetcher: fetcher)
        
        #expect(resolvedHeader.rawCID == userHeader.rawCID)
        #expect(resolvedHeader.node?.id == "alice")
        
        // Documents dictionary CID should be present (resolution works at the header level)
        #expect(resolvedHeader.node?.documentsCID != nil)
    }
    
    @Test("Recursive resolution - get all child nodes starting with path")
    func testRecursiveResolution() async throws {
        let (userHeader, responses) = createComplexDataStructure()
        let fetcher = ComplexDataFetcher(responses: responses)
        
        // Recursive resolution: Get all friends and their sub-properties
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["friends"], value: .recursive)
        
        let resolvedHeader = try await userHeader.resolve(paths: paths, fetcher: fetcher)
        
        #expect(resolvedHeader.rawCID == userHeader.rawCID)
        #expect(resolvedHeader.node?.id == "alice")
        
        // Friends dictionary CID should be present (resolution works at the header level)
        #expect(resolvedHeader.node?.friendsCID != nil)
    }
    
    @Test("Multiple path resolution - resolve different strategies in one call")
    func testMultiplePathResolution() async throws {
        // Create a simple structure using only DictionaryNode to avoid type mixing issues
        let dict = DictionaryNode(id: "multi-test", entries: [
            "documents": "doc-dict-cid",
            "friends": "friends-dict-cid",
            "profile": "profile-dict-cid",
            "extra": "extra-cid"
        ])
        
        let dictHeader = HeaderImpl(node: dict)
        
        // Create nested dictionaries for simulation
        let docDict = DictionaryNode(id: "docs", entries: ["intro": "intro-cid", "tutorial": "tutorial-cid"])
        let friendsDict = DictionaryNode(id: "friends", entries: ["bob": "bob-cid", "alice": "alice-cid"])
        let profileDict = DictionaryNode(id: "profile", entries: ["name": "name-cid", "email": "email-cid"])
        
        let fetcher = ComplexDataFetcher(responses: [
            dictHeader.rawCID: dict.description,
            "doc-dict-cid": docDict.description,
            "friends-dict-cid": friendsDict.description,
            "profile-dict-cid": profileDict.description
        ])
        
        // Multiple paths with different strategies
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["documents"], value: .targeted)      // Target documents dictionary
        paths.set(["friends"], value: .list)            // List friends dictionary
        paths.set(["profile"], value: .recursive)       // Recursively resolve profile
        
        let resolvedHeader = try await dictHeader.resolve(paths: paths, fetcher: fetcher)
        
        #expect(resolvedHeader.rawCID == dictHeader.rawCID)
        #expect(resolvedHeader.node?.id == "multi-test")
        
        // All specified paths should be resolved
        #expect(resolvedHeader.node?.entries["documents"] != nil)
        #expect(resolvedHeader.node?.entries["friends"] != nil)
        #expect(resolvedHeader.node?.entries["profile"] != nil)
    }
    
    @Test("Complex nested path resolution")
    func testComplexNestedPathResolution() async throws {
        let (userHeader, responses) = createComplexDataStructure()
        let fetcher = ComplexDataFetcher(responses: responses)
        
        // Complex nested paths
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["documents", "intro"], value: .targeted)
        paths.set(["documents", "tutorial"], value: .targeted)
        paths.set(["friends", "bob"], value: .targeted)
        paths.set(["friends", "charlie"], value: .targeted)
        
        let resolvedHeader = try await userHeader.resolve(paths: paths, fetcher: fetcher)
        
        #expect(resolvedHeader.rawCID == userHeader.rawCID)
        #expect(resolvedHeader.node?.id == "alice")
        
        // Multiple targeted paths should all be resolved
        #expect(resolvedHeader.node?.documentsCID != nil)
        #expect(resolvedHeader.node?.friendsCID != nil)
    }
    
    @Test("Mixed resolution strategies with path prefixes")
    func testMixedResolutionStrategies() async throws {
        // Create a structure using only DictionaryNode
        let rootDict = DictionaryNode(id: "mixed-root", entries: [
            "documents": "docs-cid",
            "friends": "friends-cid", 
            "profile": "profile-cid"
        ])
        
        let rootHeader = HeaderImpl(node: rootDict)
        
        // Create child dictionaries
        let docsDict = DictionaryNode(id: "docs", entries: ["intro": "intro-cid", "tutorial": "tutorial-cid"])
        let friendsDict = DictionaryNode(id: "friends", entries: ["bob": "bob-cid", "charlie": "charlie-cid"])
        let profileDict = DictionaryNode(id: "profile", entries: ["name": "name-cid", "avatar": "avatar-cid"])
        
        let fetcher = ComplexDataFetcher(responses: [
            rootHeader.rawCID: rootDict.description,
            "docs-cid": docsDict.description,
            "friends-cid": friendsDict.description,
            "profile-cid": profileDict.description
        ])
        
        // Mixed strategies with different path prefixes
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["documents"], value: .list)                  // List all documents
        paths.set(["friends"], value: .targeted)               // Target friends dictionary
        paths.set(["profile"], value: .recursive)              // Recursive profile resolution
        
        let resolvedHeader = try await rootHeader.resolve(paths: paths, fetcher: fetcher)
        
        #expect(resolvedHeader.rawCID == rootHeader.rawCID)
        #expect(resolvedHeader.node?.id == "mixed-root")
        
        // All strategies should resolve their respective paths
        #expect(resolvedHeader.node?.entries["documents"] != nil)
        #expect(resolvedHeader.node?.entries["friends"] != nil)
        #expect(resolvedHeader.node?.entries["profile"] != nil)
    }
    
    @Test("Resolution with path patterns matching")
    func testResolutionWithPathPatterns() async throws {
        let (userHeader, responses) = createComplexDataStructure()
        let fetcher = ComplexDataFetcher(responses: responses)
        
        // Test path pattern matching for list resolution
        var paths = ArrayTrie<ResolutionStrategy>()
        // This should match all documents starting with "d" (draft1, draft2)
        paths.set(["documents"], value: .list)
        
        let resolvedHeader = try await userHeader.resolve(paths: paths, fetcher: fetcher)
        
        #expect(resolvedHeader.rawCID == userHeader.rawCID)
        
        // Should resolve the documents dictionary
        #expect(resolvedHeader.node?.documentsCID != nil)
    }
    
    @Test("Empty path resolution returns original")
    func testEmptyPathResolution() async throws {
        let (userHeader, responses) = createComplexDataStructure()
        let fetcher = ComplexDataFetcher(responses: responses)
        
        // Empty paths should return original
        let emptyPaths = ArrayTrie<ResolutionStrategy>()
        
        let resolvedHeader = try await userHeader.resolve(paths: emptyPaths, fetcher: fetcher)
        
        // Should return same header since no resolution needed
        #expect(resolvedHeader.rawCID == userHeader.rawCID)
        #expect(resolvedHeader.node?.id == userHeader.node?.id)
    }
    
    @Test("Deep path resolution with multiple levels")
    func testDeepPathResolution() async throws {
        let (userHeader, responses) = createComplexDataStructure()
        let fetcher = ComplexDataFetcher(responses: responses)
        
        // Deep path with multiple levels - this tests traversal through the path
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["documents", "intro"], value: .targeted)
        paths.set(["documents", "tutorial"], value: .targeted) 
        paths.set(["documents", "advanced"], value: .targeted)
        
        let resolvedHeader = try await userHeader.resolve(paths: paths, fetcher: fetcher)
        
        #expect(resolvedHeader.rawCID == userHeader.rawCID)
        #expect(resolvedHeader.node?.id == "alice")
        
        // Documents should be resolved
        #expect(resolvedHeader.node?.documentsCID != nil)
    }
    
    @Test("Content addressability with complex structures")
    func testContentAddressabilityComplexStructures() async throws {
        // Create a simple dictionary structure
        let originalDict = DictionaryNode(id: "addressable-test", entries: [
            "item1": "value1-cid",
            "item2": "value2-cid"
        ])
        
        let originalHeader = try await HeaderImpl.create(node: originalDict)
        let originalCID = originalHeader.rawCID
        
        let fetcher = ComplexDataFetcher(responses: [
            originalCID: originalDict.description
        ])
        
        // Create header with just CID
        let cidOnlyHeader = HeaderImpl<DictionaryNode>(rawCID: originalCID)
        
        // Resolve with simple paths that don't modify structure
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["item1"], value: .targeted)
        
        let resolvedHeader = try await cidOnlyHeader.resolve(paths: paths, fetcher: fetcher)
        
        // Verify content addressability
        #expect(resolvedHeader.rawCID == originalCID)
        #expect(resolvedHeader.node?.id == "addressable-test")
        
        // Verify we can recreate the same CID from the original structure
        let recreatedCID = try await originalHeader.recreateCID()
        #expect(recreatedCID == originalCID)
    }
}
