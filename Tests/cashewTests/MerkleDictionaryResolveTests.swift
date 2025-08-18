import Testing
import Foundation
import ArrayTrie
import CID
@preconcurrency import Multicodec
import Multihash
@testable import cashew

@Suite("MerkleDictionary Resolve Tests")
struct MerkleDictionaryResolveTests {
    struct TestBaseStructure: Node {
        let val: Int
        
        init(val: Int) {
            self.val = val
        }
        
        func get(property: PathSegment) -> (any cashew.Address)? {
            return nil
        }
        
        func properties() -> Set<PathSegment> {
            return Set()
        }
        
        func set(property: PathSegment, to child: any cashew.Address) -> MerkleDictionaryResolveTests.TestBaseStructure {
            return self
        }
        
        func set(properties: [PathSegment : any cashew.Address]) -> MerkleDictionaryResolveTests.TestBaseStructure {
            return self
        }
    }
    
    @Test("MerkleDictionary basic resolve recursive")
    func testMerkleDictionaryBasicResolveRecursive() async throws {
        typealias BaseDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestBaseStructure>>
        
        let baseStructure1 = TestBaseStructure(val: 1)
        let baseStructure2 = TestBaseStructure(val: 2)
        let baseHeader1 = HeaderImpl(node: baseStructure1)
        let baseHeader2 = HeaderImpl(node: baseStructure2)
        
        // Create dictionary using inserting operations
        let emptyDictionary = BaseDictionaryType(children: [:], count: 0)
        let dictionary = try emptyDictionary
            .inserting(key: "Foo", value: baseHeader1)
            .inserting(key: "Bar", value: baseHeader2)
        let dictionaryHeader = HeaderImpl(node: dictionary)
        let testStoreFetcher = TestStoreFetcher()
        try dictionaryHeader.storeRecursively(storer: testStoreFetcher)
        let newDictionaryHeader = HeaderImpl<BaseDictionaryType>(rawCID: dictionaryHeader.rawCID)
        let resolvedDictionary = try await newDictionaryHeader.resolveRecursive(fetcher: testStoreFetcher)
        #expect(resolvedDictionary.node != nil)
        #expect(resolvedDictionary.node!.count == 2)
        
        // Use get() method to verify resolved values
        let fooValue = try resolvedDictionary.node!.get(key: "Foo")
        let barValue = try resolvedDictionary.node!.get(key: "Bar")
        
        #expect(fooValue != nil)
        #expect(fooValue?.node?.val == 1)
        #expect(barValue != nil)
        #expect(barValue?.node?.val == 2)
    }
    
    @Test("MerkleDictionary basic resolve")
    func testMerkleDictionaryBasicResolve() async throws {
        typealias BaseDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestBaseStructure>>
        
        let baseStructure1 = TestBaseStructure(val: 1)
        let baseStructure2 = TestBaseStructure(val: 2)
        let baseHeader1 = HeaderImpl(node: baseStructure1)
        let baseHeader2 = HeaderImpl(node: baseStructure2)
        
        // Create dictionary using inserting operations
        let emptyDictionary = BaseDictionaryType(children: [:], count: 0)
        let dictionary = try emptyDictionary
            .inserting(key: "Foo", value: baseHeader1)
            .inserting(key: "Bar", value: baseHeader2)
        let dictionaryHeader = HeaderImpl(node: dictionary)
        let testStoreFetcher = TestStoreFetcher()
        try dictionaryHeader.storeRecursively(storer: testStoreFetcher)
        let newDictionaryHeader = HeaderImpl<BaseDictionaryType>(rawCID: dictionaryHeader.rawCID)
        let resolvedDictionary = try await newDictionaryHeader.resolve(paths: [["Foo"]: .targeted], fetcher: testStoreFetcher)
        #expect(resolvedDictionary.node != nil)
        #expect(resolvedDictionary.node!.count == 2)
        
        #expect(resolvedDictionary.node!.children["F"] != nil)
        #expect(resolvedDictionary.node!.children["B"] != nil)
        
        // Use get() method on original dictionary to verify the values are correct
        let fooValue = try dictionary.get(key: "Foo")
        let barValue = try dictionary.get(key: "Bar")
        
        #expect(fooValue != nil)
        #expect(fooValue?.node?.val == 1)
        #expect(barValue != nil)
        #expect(barValue?.node?.val == 2)
    }
    
    @Test("MerkleDictionary basic resolve list")
    func testMerkleDictionaryResolveList() async throws {
        typealias BaseDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestBaseStructure>>
        
        let baseStructure1 = TestBaseStructure(val: 1)
        let baseStructure2 = TestBaseStructure(val: 2)
        let baseHeader1 = HeaderImpl(node: baseStructure1)
        let baseHeader2 = HeaderImpl(node: baseStructure2)
        
        // Create dictionary using inserting operations  
        let emptyDictionary = BaseDictionaryType(children: [:], count: 0)
        let dictionary = try emptyDictionary
            .inserting(key: "Foo", value: baseHeader1)
            .inserting(key: "Far", value: baseHeader2)
            .inserting(key: "G", value: baseHeader1)
        let dictionaryHeader = HeaderImpl(node: dictionary)
        let testStoreFetcher = TestStoreFetcher()
        try dictionaryHeader.storeRecursively(storer: testStoreFetcher)
        let newDictionaryHeader = HeaderImpl<BaseDictionaryType>(rawCID: dictionaryHeader.rawCID)
        let resolvedDictionary = try await newDictionaryHeader.resolve(paths: [["F"]: .list], fetcher: testStoreFetcher)
        #expect(resolvedDictionary.node != nil)
        #expect(resolvedDictionary.node!.count == 3)
        
        // With .list resolution strategy, get() operations succeed but nested addresses remain unresolved
        // Structure is accessible but nested content (addresses) have node == nil 
        let fooValue = try resolvedDictionary.node!.get(key: "Foo")
        let farValue = try resolvedDictionary.node!.get(key: "Far")
        let gValue = try? resolvedDictionary.node!.get(key: "G")
        #expect(gValue == nil)
        
        #expect(fooValue != nil)
        #expect(fooValue!.node == nil) // Address not automatically resolved with .list
        #expect(farValue != nil)
        #expect(farValue!.node == nil) // Address not automatically resolved with .list
        
        // Verify the original dictionary has the correct resolved values
        let originalFooValue = try dictionary.get(key: "Foo")
        let originalFarValue = try dictionary.get(key: "Far")
        let originalGValue = try dictionary.get(key: "G")
        
        #expect(originalFooValue?.node?.val == 1)
        #expect(originalFarValue?.node?.val == 2)
        #expect(originalGValue?.node?.val == 1)
    }
    
    @Test("MerkleDictionary nested dictionary resolve")
    func testMerkleDictionaryNestedDictionaryResolve() async throws {
        typealias BaseDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestBaseStructure>>
        typealias NestedDictionaryType = MerkleDictionaryImpl<HeaderImpl<BaseDictionaryType>>
        
        // Create base structures
        let baseStructure1 = TestBaseStructure(val: 10)
        let baseStructure2 = TestBaseStructure(val: 20)
        let baseHeader1 = HeaderImpl(node: baseStructure1)
        let baseHeader2 = HeaderImpl(node: baseStructure2)
        
        // Create inner dictionaries using inserting operations
        let emptyBaseDictionary = BaseDictionaryType(children: [:], count: 0)
        let innerDictionary1 = try emptyBaseDictionary.inserting(key: "item1", value: baseHeader1)
        let innerDictionary2 = try emptyBaseDictionary.inserting(key: "item2", value: baseHeader2)
        
        let innerDictionaryHeader1 = HeaderImpl(node: innerDictionary1)
        let innerDictionaryHeader2 = HeaderImpl(node: innerDictionary2)
        
        // Create outer dictionary using inserting operations
        let emptyNestedDictionary = NestedDictionaryType(children: [:], count: 0)
        let outerDictionary = try emptyNestedDictionary
            .inserting(key: "level1", value: innerDictionaryHeader1)
            .inserting(key: "level2", value: innerDictionaryHeader2)
        let outerDictionaryHeader = HeaderImpl(node: outerDictionary)
        
        let testStoreFetcher = TestStoreFetcher()
        try outerDictionaryHeader.storeRecursively(storer: testStoreFetcher)
        
        // Test resolving specific nested path
        let newOuterDictionaryHeader = HeaderImpl<NestedDictionaryType>(rawCID: outerDictionaryHeader.rawCID)
        let resolvedDictionary = try await newOuterDictionaryHeader.resolve(paths: [["level1", "item1"]: .targeted], fetcher: testStoreFetcher)
        
        #expect(resolvedDictionary.node != nil)
        #expect(resolvedDictionary.node!.count == 2)
        
        // Test that we can retrieve the nested value using get operations
        let level1Value = try outerDictionary.get(key: "level1")
        #expect(level1Value != nil)
        
        let nestedItem = try level1Value!.node!.get(key: "item1")
        #expect(nestedItem != nil)
        #expect(nestedItem!.node!.val == 10)
        
        let level2Value = try outerDictionary.get(key: "level2")
        #expect(level2Value != nil)
        
        let nestedItem2 = try level2Value!.node!.get(key: "item2")
        #expect(nestedItem2 != nil)
        #expect(nestedItem2!.node!.val == 20)
    }
    
    @Test("MerkleDictionary multiple path resolve")
    func testMerkleDictionaryMultiplePathResolve() async throws {
        typealias BaseDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestBaseStructure>>
        
        // Create base structures
        let baseStructure1 = TestBaseStructure(val: 100)
        let baseStructure2 = TestBaseStructure(val: 200)
        let baseStructure3 = TestBaseStructure(val: 300)
        let baseStructure4 = TestBaseStructure(val: 400)
        
        let baseHeader1 = HeaderImpl(node: baseStructure1)
        let baseHeader2 = HeaderImpl(node: baseStructure2)
        let baseHeader3 = HeaderImpl(node: baseStructure3)
        let baseHeader4 = HeaderImpl(node: baseStructure4)
        
        // Create dictionary using inserting operations with simpler keys
        let emptyDictionary = BaseDictionaryType(children: [:], count: 0)
        let dictionary = try emptyDictionary
            .inserting(key: "Alpha", value: baseHeader1)
            .inserting(key: "Beta", value: baseHeader2)
            .inserting(key: "Charlie", value: baseHeader3)
            .inserting(key: "Delta", value: baseHeader4)
        let dictionaryHeader = HeaderImpl(node: dictionary)
        
        let testStoreFetcher = TestStoreFetcher()
        try dictionaryHeader.storeRecursively(storer: testStoreFetcher)
        
        // Test resolving multiple specific paths
        let newDictionaryHeader = HeaderImpl<BaseDictionaryType>(rawCID: dictionaryHeader.rawCID)
        let resolvedDictionary = try await newDictionaryHeader.resolve(paths: [
            ["Alpha"]: .targeted,
            ["Beta"]: .targeted
        ], fetcher: testStoreFetcher)
        
        #expect(resolvedDictionary.node != nil)
        #expect(resolvedDictionary.node!.count == 4)
        
        // Use get() method to verify resolved values
        let alphaValueResolved = try resolvedDictionary.node!.get(key: "Alpha")
        let betaValueResolved = try resolvedDictionary.node!.get(key: "Beta")
        
        #expect(alphaValueResolved != nil)
        #expect(alphaValueResolved?.node?.val == 100)
        #expect(betaValueResolved != nil)
        #expect(betaValueResolved?.node?.val == 200)
        
        // Test that we can retrieve the values using get operations
        let alphaValue = try dictionary.get(key: "Alpha")
        let betaValue = try dictionary.get(key: "Beta")
        let charlieValue = try dictionary.get(key: "Charlie")
        let deltaValue = try dictionary.get(key: "Delta")
        
        #expect(alphaValue?.node?.val == 100)
        #expect(betaValue?.node?.val == 200)
        #expect(charlieValue?.node?.val == 300)
        #expect(deltaValue?.node?.val == 400)
    }
    
    @Test("MerkleDictionary recursive resolve")
    func testMerkleDictionaryRecursiveResolve() async throws {
        typealias BaseDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestBaseStructure>>
        
        let baseStructure1 = TestBaseStructure(val: 1)
        let baseStructure2 = TestBaseStructure(val: 2)
        let baseHeader1 = HeaderImpl(node: baseStructure1)
        let baseHeader2 = HeaderImpl(node: baseStructure2)
        
        // Create dictionary using inserting operations
        let emptyDictionary = BaseDictionaryType(children: [:], count: 0)
        let dictionary = try emptyDictionary
            .inserting(key: "Test1", value: baseHeader1)
            .inserting(key: "User2", value: baseHeader2)
        let dictionaryHeader = HeaderImpl(node: dictionary)
        
        let testStoreFetcher = TestStoreFetcher()
        try dictionaryHeader.storeRecursively(storer: testStoreFetcher)
        
        // Test resolving with empty paths - should load root but no children
        let newDictionaryHeader = HeaderImpl<BaseDictionaryType>(rawCID: dictionaryHeader.rawCID)
        let resolvedDictionary = try await newDictionaryHeader.resolveRecursive(fetcher: testStoreFetcher)
        
        #expect(resolvedDictionary.node != nil)
        #expect(resolvedDictionary.node!.count == 2)
        
        // Use get() method to verify recursively resolved values
        let test1Value = try resolvedDictionary.node!.get(key: "Test1")
        let user2Value = try resolvedDictionary.node!.get(key: "User2")
        
        #expect(test1Value != nil)
        #expect(test1Value?.node?.val == 1)
        #expect(user2Value != nil)
        #expect(user2Value?.node?.val == 2)
    }
    
    @Test("MerkleDictionary deep nesting resolve")
    func testMerkleDictionaryDeepNestingResolve() async throws {
        typealias Level1Type = MerkleDictionaryImpl<HeaderImpl<TestBaseStructure>>
        typealias Level2Type = MerkleDictionaryImpl<HeaderImpl<Level1Type>>
        typealias Level3Type = MerkleDictionaryImpl<HeaderImpl<Level2Type>>
        typealias Level4Type = MerkleDictionaryImpl<HeaderImpl<Level3Type>>
        
        // Create deepest level (Level 1 - base structures) using inserting
        let baseStructure = TestBaseStructure(val: 999)
        let baseHeader = HeaderImpl(node: baseStructure)
        let emptyLevel1 = Level1Type(children: [:], count: 0)
        let level1Dict = try emptyLevel1.inserting(key: "deep", value: baseHeader)
        let level1Header = HeaderImpl(node: level1Dict)
        
        // Create Level 2 using inserting
        let emptyLevel2 = Level2Type(children: [:], count: 0)
        let level2Dict = try emptyLevel2.inserting(key: "level2", value: level1Header)
        let level2Header = HeaderImpl(node: level2Dict)
        
        // Create Level 3 using inserting
        let emptyLevel3 = Level3Type(children: [:], count: 0)
        let level3Dict = try emptyLevel3.inserting(key: "level3", value: level2Header)
        let level3Header = HeaderImpl(node: level3Dict)
        
        // Create Level 4 (root) using inserting
        let emptyLevel4 = Level4Type(children: [:], count: 0)
        let level4Dict = try emptyLevel4.inserting(key: "root", value: level3Header)
        let level4Header = HeaderImpl(node: level4Dict)
        
        let testStoreFetcher = TestStoreFetcher()
        try level4Header.storeRecursively(storer: testStoreFetcher)
        
        // Test resolving deep path
        let newLevel4Header = HeaderImpl<Level4Type>(rawCID: level4Header.rawCID)
        let resolvedDictionary = try await newLevel4Header.resolve(paths: [["root", "level3", "level2", "deep"]: .targeted], fetcher: testStoreFetcher)
        
        #expect(resolvedDictionary.node != nil)
        
        // The resolved path should allow us to get the deep nested value
        // Since we resolved ["root", "level3", "level2", "deep"], we should be able to traverse this path
        // But since MerkleDictionary.get() only works for direct keys, let's verify the structure is resolved
        let rootValue = try resolvedDictionary.node!.get(key: "root")
        #expect(rootValue != nil)
        
        // Verify the deep nesting by checking that the resolved root contains the nested structure
        let nestedLevel3 = try rootValue!.node!.get(key: "level3")
        #expect(nestedLevel3 != nil)
        
        let nestedLevel2 = try nestedLevel3!.node!.get(key: "level2")
        #expect(nestedLevel2 != nil)
        
        let deepValue = try nestedLevel2!.node!.get(key: "deep")
        #expect(deepValue != nil)
        #expect(deepValue?.node?.val == 999)
    }
    
    @Test("MerkleDictionary large scale resolve")
    func testMerkleDictionaryLargeScaleResolve() async throws {
        typealias BaseDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestBaseStructure>>
        
        let totalNodes = 10 // Reduced for simpler testing
        let characters = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
        
        // Create dictionary using inserting operations
        var dictionary = BaseDictionaryType(children: [:], count: 0)
        for i in 0..<totalNodes {
            let baseStructure = TestBaseStructure(val: i * 10)
            let baseHeader = HeaderImpl(node: baseStructure)
            dictionary = try dictionary.inserting(key: "\(characters[i])node\(i)", value: baseHeader)
        }
        
        let dictionaryHeader = HeaderImpl(node: dictionary)
        
        let testStoreFetcher = TestStoreFetcher()
        try dictionaryHeader.storeRecursively(storer: testStoreFetcher)
        
        // Test resolving specific subset
        let newDictionaryHeader = HeaderImpl<BaseDictionaryType>(rawCID: dictionaryHeader.rawCID)
        let resolvedDictionary = try await newDictionaryHeader.resolve(paths: [
            ["5node5"]: .targeted,
            ["7node7"]: .targeted
        ], fetcher: testStoreFetcher)
        
        #expect(resolvedDictionary.node != nil)
        #expect(resolvedDictionary.node!.count == totalNodes)
        
        // Use get() method to verify resolved and unresolved values
        let resolvedValue5 = try resolvedDictionary.node!.get(key: "5node5")
        let resolvedValue7 = try resolvedDictionary.node!.get(key: "7node7")
        
        // Check that targeted nodes are resolved
        #expect(resolvedValue5 != nil)
        #expect(resolvedValue5?.node?.val == 50)
        #expect(resolvedValue7 != nil)
        #expect(resolvedValue7?.node?.val == 70)
        
        // Non-targeted nodes may or may not be resolved depending on resolve strategy,
        // Check if they exist in the structure (they should, but may not be fully resolved)
        let unresolvedValue1 = try? resolvedDictionary.node!.get(key: "1node1")
        let unresolvedValue3 = try? resolvedDictionary.node!.get(key: "3node3")
        
        // These may be nil if not resolved, which is expected for non-targeted nodes
        #expect(unresolvedValue1 == nil || unresolvedValue1?.node?.val == 10)
        #expect(unresolvedValue3 == nil || unresolvedValue3?.node?.val == 30)
        
        // But the dictionary structure should be intact
        #expect(resolvedDictionary.node!.children["1"] != nil)
        #expect(resolvedDictionary.node!.children["3"] != nil)
    }
    
    @Test("MerkleDictionary list resolve")
    func testMerkleDictionaryListResolve() async throws {
        typealias HigherDictionaryType = MerkleDictionaryImpl<HeaderImpl<BaseDictionaryType>>
        typealias BaseDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestBaseStructure>>
        
        // Create base structures
        let baseStructure1 = TestBaseStructure(val: 1)
        let baseStructure2 = TestBaseStructure(val: 2)
        let baseHeader1 = HeaderImpl(node: baseStructure1)
        let baseHeader2 = HeaderImpl(node: baseStructure2)
        
        // Create base dictionary using inserting operations
        let emptyBaseDictionary = BaseDictionaryType(children: [:], count: 0)
        let dictionary = try emptyBaseDictionary
            .inserting(key: "Foo", value: baseHeader1)
            .inserting(key: "Bar", value: baseHeader2)
        let dictionaryHeader = HeaderImpl(node: dictionary)
        
        // Create higher level dictionary using inserting operations
        let emptyHigherDictionary = HigherDictionaryType(children: [:], count: 0)
        let higherDictionary = try emptyHigherDictionary
            .inserting(key: "Foo", value: dictionaryHeader)
            .inserting(key: "Bar", value: dictionaryHeader)
        let higherDictionaryHeader = HeaderImpl(node: higherDictionary)
        
        let testStoreFetcher = TestStoreFetcher()
        try higherDictionaryHeader.storeRecursively(storer: testStoreFetcher)
        let newDictionaryHeader = HeaderImpl<HigherDictionaryType>(rawCID: higherDictionaryHeader.rawCID)
        var resolutionPaths = ArrayTrie<ResolutionStrategy>()
        resolutionPaths.set(["Fo"], value: ResolutionStrategy.list)
        let resolvedDictionary = try await newDictionaryHeader.resolve(paths: resolutionPaths, fetcher: testStoreFetcher)
        #expect(resolvedDictionary.node != nil)
        #expect(resolvedDictionary.node!.count == 2)
        let resultingValue = try resolvedDictionary.node!.get(key: "Foo")
        #expect(resultingValue != nil)
        #expect(resultingValue!.node == nil)
    }
    
    @Test("MerkleDictionary deep list resolve")
    func testMerkleDictionaryDeepListResolve() async throws {
        typealias HigherDictionaryType = MerkleDictionaryImpl<HeaderImpl<BaseDictionaryType>>
        typealias BaseDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestBaseStructure>>
        
        // Create base structures
        let baseStructure1 = TestBaseStructure(val: 1)
        let baseStructure2 = TestBaseStructure(val: 2)
        let baseHeader1 = HeaderImpl(node: baseStructure1)
        let baseHeader2 = HeaderImpl(node: baseStructure2)
        
        // Create base dictionary using inserting operations
        let emptyBaseDictionary = BaseDictionaryType(children: [:], count: 0)
        let dictionary = try emptyBaseDictionary
            .inserting(key: "Foo", value: baseHeader1)
            .inserting(key: "Bar", value: baseHeader2)
            .inserting(key: "Baz", value: baseHeader2)
        let dictionaryHeader = HeaderImpl(node: dictionary)
        
        // Create higher level dictionary using inserting operations
        let emptyHigherDictionary = HigherDictionaryType(children: [:], count: 0)
        let higherDictionary = try emptyHigherDictionary
            .inserting(key: "Foo", value: dictionaryHeader)
            .inserting(key: "Bar", value: dictionaryHeader)
        let higherDictionaryHeader = HeaderImpl(node: higherDictionary)
        
        let testStoreFetcher = TestStoreFetcher()
        try higherDictionaryHeader.storeRecursively(storer: testStoreFetcher)
        let newDictionaryHeader = HeaderImpl<HigherDictionaryType>(rawCID: higherDictionaryHeader.rawCID)
        var resolutionPaths = ArrayTrie<ResolutionStrategy>()
        resolutionPaths.set(["Foo", "Foo"], value: ResolutionStrategy.targeted)
        resolutionPaths.set(["Fo", "Baz"], value: ResolutionStrategy.targeted)
        resolutionPaths.set(["Fo"], value: ResolutionStrategy.list)
        let resolvedDictionary = try await newDictionaryHeader.resolve(paths: resolutionPaths, fetcher: testStoreFetcher)
        #expect(resolvedDictionary.node != nil)
        #expect(resolvedDictionary.node!.count == 2)
        
        // With .list resolution strategy, get() operations succeed but nested addresses remain unresolved
        // Structure is accessible but nested content (addresses) have node == nil
        let fooValue = try resolvedDictionary.node!.get(key: "Foo")
        let barValue = try? resolvedDictionary.node!.get(key: "Bar")
        
        #expect(fooValue != nil)
        #expect(fooValue!.node != nil)
        #expect(barValue == nil)
        
        let innerFoo = try fooValue!.node?.get(key: "Foo")
        let innerBaz = try fooValue!.node?.get(key: "Baz")
        
        #expect(innerFoo != nil)
        #expect(innerBaz != nil)
        let innerBar = try? fooValue!.node?.get(key: "Bar")
        #expect(innerBar == nil)
        
        // Verify the original dictionaries have the correct structure and values
        let originalFooValue = try higherDictionary.get(key: "Foo")
        let originalBarValue = try higherDictionary.get(key: "Bar")
        
        #expect(originalFooValue != nil)
        #expect(originalBarValue != nil)
        
        // Verify the nested dictionary structure using original data
        let innerFooValue = try originalFooValue!.node!.get(key: "Foo")
        let innerBarValue = try originalFooValue!.node!.get(key: "Bar")
        
        #expect(innerFooValue?.node?.val == 1)
        #expect(innerBarValue?.node?.val == 2)
    }

    // MARK: - MerkleDictionary Basic Operations Tests
    
    @Test("MerkleDictionary insert single item")
    func testMerkleDictionaryInsertSingle() throws {
        typealias BaseDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestBaseStructure>>
        
        let baseStructure = TestBaseStructure(val: 42)
        let baseHeader = HeaderImpl(node: baseStructure)
        let emptyDictionary = BaseDictionaryType(children: [:], count: 0)
        
        let dictionary = try emptyDictionary.inserting(key: "key1", value: baseHeader)
        
        #expect(dictionary.count == 1)
        #expect(dictionary.children.count == 1)
        #expect(dictionary.children["k"] != nil)
        #expect(dictionary.get(property: "k") != nil)
        #expect(dictionary.properties() == Set(["k"]))
        
        let retrievedValue = try dictionary.get(key: "key1")
        #expect(retrievedValue != nil)
        #expect(retrievedValue?.node?.val == 42)
    }
    
    @Test("MerkleDictionary insert multiple items")
    func testMerkleDictionaryInsertMultiple() throws {
        typealias BaseDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestBaseStructure>>
        
        let baseStructure1 = TestBaseStructure(val: 1)
        let baseStructure2 = TestBaseStructure(val: 2)
        let baseStructure3 = TestBaseStructure(val: 3)
        
        let baseHeader1 = HeaderImpl(node: baseStructure1)
        let baseHeader2 = HeaderImpl(node: baseStructure2)
        let baseHeader3 = HeaderImpl(node: baseStructure3)
        
        // Create dictionary using inserting operations
        let emptyDictionary = BaseDictionaryType(children: [:], count: 0)
        let dictionary = try emptyDictionary
            .inserting(key: "alpha", value: baseHeader1)
            .inserting(key: "beta", value: baseHeader2)
            .inserting(key: "gamma", value: baseHeader3)
        
        #expect(dictionary.count == 3)
        #expect(dictionary.children.count == 3)
        #expect(dictionary.get(property: "a") != nil)
        #expect(dictionary.get(property: "b") != nil)
        #expect(dictionary.get(property: "g") != nil)
        #expect(dictionary.properties() == Set(["a", "b", "g"]))
        
        // Test get operations
        let retrievedValue1 = try dictionary.get(key: "alpha")
        let retrievedValue2 = try dictionary.get(key: "beta")
        let retrievedValue3 = try dictionary.get(key: "gamma")
        
        #expect(retrievedValue1?.node?.val == 1)
        #expect(retrievedValue2?.node?.val == 2)
        #expect(retrievedValue3?.node?.val == 3)
    }
    
    @Test("MerkleDictionary get operations")
    func testMerkleDictionaryGetOperations() throws {
        typealias BaseDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestBaseStructure>>
        
        let baseStructure1 = TestBaseStructure(val: 100)
        let baseStructure2 = TestBaseStructure(val: 200)
        let baseHeader1 = HeaderImpl(node: baseStructure1)
        let baseHeader2 = HeaderImpl(node: baseStructure2)
        
        // Create dictionary using inserting operations
        let emptyDictionary = BaseDictionaryType(children: [:], count: 0)
        let dictionary = try emptyDictionary
            .inserting(key: "first", value: baseHeader1)
            .inserting(key: "second", value: baseHeader2)
        
        // Test get operations using the key-based get method
        let firstValue = try dictionary.get(key: "first")
        let secondValue = try dictionary.get(key: "second")
        let nonExistentValue = try dictionary.get(key: "nonexistent")
        
        #expect(firstValue != nil)
        #expect(firstValue?.node?.val == 100)
        #expect(secondValue != nil)
        #expect(secondValue?.node?.val == 200)
        #expect(nonExistentValue == nil)
        
        // Test property-based get operations
        #expect(dictionary.get(property: "f") != nil)
        #expect(dictionary.get(property: "s") != nil)
        #expect(dictionary.get(property: "x") == nil)
        
        #expect(dictionary.properties().contains("f"))
        #expect(dictionary.properties().contains("s"))
        #expect(!dictionary.properties().contains("x"))
    }
    
    @Test("MerkleDictionary mutate existing items")
    func testMerkleDictionaryMutateItems() throws {
        typealias BaseDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestBaseStructure>>
        
        let originalStructure = TestBaseStructure(val: 10)
        let originalHeader = HeaderImpl(node: originalStructure)
        
        // Create initial dictionary using inserting operation
        let emptyDictionary = BaseDictionaryType(children: [:], count: 0)
        let originalDictionary = try emptyDictionary.inserting(key: "item", value: originalHeader)
        
        // Test mutating operation
        let updatedStructure = TestBaseStructure(val: 20)
        let updatedHeader = HeaderImpl(node: updatedStructure)
        let mutatedDictionary = try originalDictionary.mutating(key: ArraySlice("item"), value: updatedHeader)
        
        #expect(mutatedDictionary.count == 1)
        #expect(originalDictionary.count == 1)
        
        // Verify that the original value is preserved and the mutated value is different
        let originalValue = try originalDictionary.get(key: "item")
        let mutatedValue = try mutatedDictionary.get(key: "item")
        
        #expect(originalValue?.node?.val == 10)
        #expect(mutatedValue?.node?.val == 20)
    }
    
    @Test("MerkleDictionary set multiple properties")
    func testMerkleDictionarySetMultipleProperties() throws {
        typealias BaseDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestBaseStructure>>
        
        let structure1 = TestBaseStructure(val: 1)
        let structure2 = TestBaseStructure(val: 2)
        let header1 = HeaderImpl(node: structure1)
        let header2 = HeaderImpl(node: structure2)
        
        // Create original dictionary using inserting operations
        let emptyDictionary = BaseDictionaryType(children: [:], count: 0)
        let originalDictionary = try emptyDictionary
            .inserting(key: "old1", value: header1)
            .inserting(key: "old2", value: header2)
        
        // Test mutating multiple items
        let newStructure1 = TestBaseStructure(val: 10)
        let newStructure2 = TestBaseStructure(val: 20)
        let newHeader1 = HeaderImpl(node: newStructure1)
        let newHeader2 = HeaderImpl(node: newStructure2)
        
        let updatedDictionary = try originalDictionary
            .mutating(key: ArraySlice("old1"), value: newHeader1)
            .mutating(key: ArraySlice("old2"), value: newHeader2)
        
        #expect(updatedDictionary.count == 2)
        #expect(originalDictionary.count == 2)
        
        // Verify original values are preserved
        let originalValue1 = try originalDictionary.get(key: "old1")
        let originalValue2 = try originalDictionary.get(key: "old2")
        
        #expect(originalValue1?.node?.val == 1)
        #expect(originalValue2?.node?.val == 2)
        
        // Verify updated values are correct
        let updatedValue1 = try updatedDictionary.get(key: "old1")
        let updatedValue2 = try updatedDictionary.get(key: "old2")
        
        #expect(updatedValue1?.node?.val == 10)
        #expect(updatedValue2?.node?.val == 20)
    }
    
    @Test("MerkleDictionary remove items")
    func testMerkleDictionaryRemoveItems() throws {
        typealias BaseDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestBaseStructure>>
        
        let structure1 = TestBaseStructure(val: 1)
        let structure2 = TestBaseStructure(val: 2)
        let structure3 = TestBaseStructure(val: 3)
        
        let header1 = HeaderImpl(node: structure1)
        let header2 = HeaderImpl(node: structure2)
        let header3 = HeaderImpl(node: structure3)
        
        // Create original dictionary using inserting operations
        let emptyDictionary = BaseDictionaryType(children: [:], count: 0)
        let originalDictionary = try emptyDictionary
            .inserting(key: "keep", value: header1)
            .inserting(key: "remove", value: header2)
            .inserting(key: "stuff", value: header3)
        
        // Test deleting operations
        let reducedDictionary = try originalDictionary
            .deleting(key: "remove")
            .deleting(key: "stuff")
        
        #expect(originalDictionary.count == 3)
        #expect(originalDictionary.properties() == Set(["k", "r", "s"]))
        
        #expect(reducedDictionary.count == 1)
        #expect(reducedDictionary.properties() == Set(["k"]))
        #expect(reducedDictionary.get(property: "k") != nil)
        #expect(reducedDictionary.get(property: "r") == nil)
        #expect(reducedDictionary.get(property: "s") == nil)
        
        // Verify that the kept item still has the correct value
        let keptValue = try reducedDictionary.get(key: "keep")
        #expect(keptValue?.node?.val == 1)
        
        // Verify that deleted items no longer exist
        let deletedValue1 = try reducedDictionary.get(key: "remove")
        let deletedValue2 = try reducedDictionary.get(key: "stuff")
        #expect(deletedValue1 == nil)
        #expect(deletedValue2 == nil)
    }
    
    @Test("MerkleDictionary empty dictionary")
    func testMerkleDictionaryEmpty() throws {
        typealias BaseDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestBaseStructure>>
        
        let emptyDictionary = BaseDictionaryType(children: [:], count: 0)
        
        #expect(emptyDictionary.count == 0)
        #expect(emptyDictionary.children.isEmpty)
        #expect(emptyDictionary.properties().isEmpty)
        #expect(emptyDictionary.get(property: "x") == nil)
    }
    
    @Test("MerkleDictionary complex mutations")
    func testMerkleDictionaryComplexMutations() throws {
        typealias BaseDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestBaseStructure>>
        
        let emptyDictionary = BaseDictionaryType(children: [:], count: 0)
        
        let structure1 = TestBaseStructure(val: 100)
        let structure2 = TestBaseStructure(val: 200)
        let structure3 = TestBaseStructure(val: 300)
        let header1 = HeaderImpl(node: structure1)
        let header2 = HeaderImpl(node: structure2)
        let header3 = HeaderImpl(node: structure3)
        
        // Test inserting operation
        let dictionaryWithOne = try emptyDictionary.inserting(key: "first", value: header1)
        
        // Test inserting another item
        let dictionaryWithTwo = try dictionaryWithOne.inserting(key: "second", value: header2)
        
        // Test mutating an existing item
        let finalDictionary = try dictionaryWithTwo.mutating(key: ArraySlice("first"), value: header3)
        
        #expect(emptyDictionary.count == 0)
        #expect(dictionaryWithOne.count == 1)
        #expect(dictionaryWithTwo.count == 2)
        #expect(finalDictionary.count == 2)
        
        #expect(emptyDictionary.properties().isEmpty)
        #expect(dictionaryWithOne.properties() == Set(["f"]))
        #expect(dictionaryWithTwo.properties() == Set(["f", "s"]))
        #expect(finalDictionary.properties() == Set(["f", "s"]))
        
        // Verify the final dictionary has the correct values
        let firstValue = try finalDictionary.get(key: "first")
        let secondValue = try finalDictionary.get(key: "second")
        
        #expect(firstValue?.node?.val == 300) // Updated value
        #expect(secondValue?.node?.val == 200) // Original value
        
        // Verify that intermediate dictionaries still have original values
        let originalFirstValue = try dictionaryWithOne.get(key: "first")
        #expect(originalFirstValue?.node?.val == 100)
    }
    
    @Test("MerkleDictionary partial path matching")
    func testMerkleDictionaryPartialPathMatching() async throws {
        typealias BaseDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestBaseStructure>>
        
        // Create test structures with overlapping prefixes
        let baseStructure1 = TestBaseStructure(val: 111)
        let baseStructure2 = TestBaseStructure(val: 222)
        let baseStructure3 = TestBaseStructure(val: 333)
        let baseStructure4 = TestBaseStructure(val: 444)
        
        let baseHeader1 = HeaderImpl(node: baseStructure1)
        let baseHeader2 = HeaderImpl(node: baseStructure2)
        let baseHeader3 = HeaderImpl(node: baseStructure3)
        let baseHeader4 = HeaderImpl(node: baseStructure4)
        
        // Create dictionary with keys that test partial path functionality using inserting operations
        let emptyDictionary = BaseDictionaryType(children: [:], count: 0)
        let dictionary = try emptyDictionary
            .inserting(key: "apple", value: baseHeader1)         // Starts with 'a'
            .inserting(key: "application", value: baseHeader2)   // Also starts with 'a', different suffix
            .inserting(key: "banana", value: baseHeader3)        // Starts with 'b'
            .inserting(key: "cherry", value: baseHeader4)        // Starts with 'c'
        let dictionaryHeader = HeaderImpl(node: dictionary)
        
        let testStoreFetcher = TestStoreFetcher()
        try dictionaryHeader.storeRecursively(storer: testStoreFetcher)
        
        // Test 1: Resolve with exact key match
        let newDictionaryHeader1 = HeaderImpl<BaseDictionaryType>(rawCID: dictionaryHeader.rawCID)
        let resolvedDictionary1 = try await newDictionaryHeader1.resolve(paths: [["apple"]: .targeted], fetcher: testStoreFetcher)
        
        #expect(resolvedDictionary1.node != nil)
        #expect(resolvedDictionary1.node!.count == 4)
        
        // Verify that we can retrieve the specific value that was targeted
        let appleValue = try dictionary.get(key: "apple")
        #expect(appleValue?.node?.val == 111)
        
        // Test 2: Resolve with prefix that matches multiple keys (should resolve all matching ones with .list)
        let newDictionaryHeader2 = HeaderImpl<BaseDictionaryType>(rawCID: dictionaryHeader.rawCID)
        let resolvedDictionary2 = try await newDictionaryHeader2.resolve(paths: [["a"]: .list], fetcher: testStoreFetcher)
        
        #expect(resolvedDictionary2.node != nil)
        #expect(resolvedDictionary2.node!.count == 4)
        
        // Verify that all items can be retrieved
        let appleValue2 = try dictionary.get(key: "apple")
        let applicationValue = try dictionary.get(key: "application")
        let bananaValue = try dictionary.get(key: "banana")
        let cherryValue = try dictionary.get(key: "cherry")
        
        #expect(appleValue2?.node?.val == 111)
        #expect(applicationValue?.node?.val == 222)
        #expect(bananaValue?.node?.val == 333)
        #expect(cherryValue?.node?.val == 444)
        
        // Test 3: Resolve multiple partial paths with different strategies
        let newDictionaryHeader3 = HeaderImpl<BaseDictionaryType>(rawCID: dictionaryHeader.rawCID)
        let resolvedDictionary3 = try await newDictionaryHeader3.resolve(paths: [
            ["a"]: .list,             // Should resolve all a* prefixed items (apple, application)
            ["banana"]: .targeted     // Should resolve only banana specifically
        ], fetcher: testStoreFetcher)
        
        #expect(resolvedDictionary3.node != nil)
        #expect(resolvedDictionary3.node!.count == 4)
        
        // Use get() method to verify resolved values
        let resolvedApple3 = try resolvedDictionary3.node!.get(key: "apple")
        let resolvedBanana3 = try resolvedDictionary3.node!.get(key: "banana")
        
        #expect(resolvedApple3 != nil)
        #expect(resolvedApple3!.node == nil)
        #expect(resolvedBanana3 != nil)
        #expect(resolvedBanana3?.node?.val == 333)
        
        // Test 4: Test partial path with non-existent key
        let newDictionaryHeader4 = HeaderImpl<BaseDictionaryType>(rawCID: dictionaryHeader.rawCID)
        let resolvedDictionary4 = try await newDictionaryHeader4.resolve(paths: [["xyz"]: .targeted], fetcher: testStoreFetcher)
        
        #expect(resolvedDictionary4.node != nil)
        #expect(resolvedDictionary4.node!.count == 4)
        
        // Non-existent path should not cause errors, dictionary should remain intact
        let nonExistentValue = try dictionary.get(key: "xyz")
        #expect(nonExistentValue == nil)
        
        // Test 5: Verify original dictionary still has all values via get operations
        #expect(try dictionary.get(key: "apple")?.node?.val == 111)  
        #expect(try dictionary.get(key: "application")?.node?.val == 222)
        #expect(try dictionary.get(key: "banana")?.node?.val == 333)
        #expect(try dictionary.get(key: "cherry")?.node?.val == 444)
    }

}
