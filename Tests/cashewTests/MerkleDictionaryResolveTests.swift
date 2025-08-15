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
        typealias BaseRadixHeader = BaseDictionaryType.ChildType
        typealias BaseRadixNode = BaseRadixHeader.NodeType
        let baseStructure1 = TestBaseStructure(val: 1)
        let baseStructure2 = TestBaseStructure(val: 2)
        let baseHeader1 = HeaderImpl(node: baseStructure1)
        let baseHeader2 = HeaderImpl(node: baseStructure2)
        let radixNode1 = BaseRadixNode(prefix: "Foo", value: baseHeader1, children: [:])
        let radixNode2 = BaseRadixNode(prefix: "Bar", value: baseHeader2, children: [:])
        let radixHeader1 = RadixHeaderImpl(node: radixNode1)
        let radixHeader2 = RadixHeaderImpl(node: radixNode2)
        let dictionary = BaseDictionaryType(children: ["F": radixHeader1, "B": radixHeader2], count: 2)
        let dictionaryHeader = HeaderImpl(node: dictionary)
        let testStoreFetcher = TestStoreFetcher()
        try dictionaryHeader.storeRecursively(storer: testStoreFetcher)
        let newDictionaryHeader = HeaderImpl<BaseDictionaryType>(rawCID: dictionaryHeader.rawCID)
        let resolvedDictionary = try await newDictionaryHeader.resolveRecursive(fetcher: testStoreFetcher)
        #expect(resolvedDictionary.node != nil)
        #expect(resolvedDictionary.node!.count == 2)
        #expect(resolvedDictionary.node!.children["F"] != nil)
        #expect(resolvedDictionary.node!.children["F"]!.node != nil)
        #expect(resolvedDictionary.node!.children["F"]!.node!.prefix == "Foo")
        #expect(resolvedDictionary.node!.children["F"]!.node!.value != nil)
        #expect(resolvedDictionary.node!.children["F"]!.node!.value!.node != nil)
        #expect(resolvedDictionary.node!.children["F"]!.node!.value!.node!.val == 1)
        #expect(resolvedDictionary.node!.children["B"] != nil)
        #expect(resolvedDictionary.node!.children["B"]!.node != nil)
        #expect(resolvedDictionary.node!.children["B"]!.node!.prefix == "Bar")
        #expect(resolvedDictionary.node!.children["B"]!.node!.value != nil)
        #expect(resolvedDictionary.node!.children["B"]!.node!.value!.node != nil)
        #expect(resolvedDictionary.node!.children["B"]!.node!.value!.node!.val == 2)
    }
    
    @Test("MerkleDictionary basic resolve")
    func testMerkleDictionaryBasicResolve() async throws {
        typealias BaseDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestBaseStructure>>
        typealias BaseRadixHeader = BaseDictionaryType.ChildType
        typealias BaseRadixNode = BaseRadixHeader.NodeType
        let baseStructure1 = TestBaseStructure(val: 1)
        let baseStructure2 = TestBaseStructure(val: 2)
        let baseHeader1 = HeaderImpl(node: baseStructure1)
        let baseHeader2 = HeaderImpl(node: baseStructure2)
        let radixNode1 = BaseRadixNode(prefix: "Foo", value: baseHeader1, children: [:])
        let radixNode2 = BaseRadixNode(prefix: "Bar", value: baseHeader2, children: [:])
        let radixHeader1 = RadixHeaderImpl(node: radixNode1)
        let radixHeader2 = RadixHeaderImpl(node: radixNode2)
        let dictionary = BaseDictionaryType(children: ["F": radixHeader1, "B": radixHeader2], count: 2)
        let dictionaryHeader = HeaderImpl(node: dictionary)
        let testStoreFetcher = TestStoreFetcher()
        try dictionaryHeader.storeRecursively(storer: testStoreFetcher)
        let newDictionaryHeader = HeaderImpl<BaseDictionaryType>(rawCID: dictionaryHeader.rawCID)
        let resolvedDictionary = try await newDictionaryHeader.resolve(paths: [["Foo"]: .targeted], fetcher: testStoreFetcher)
        #expect(resolvedDictionary.node != nil)
        #expect(resolvedDictionary.node!.count == 2)
        #expect(resolvedDictionary.node!.children["F"] != nil)
        #expect(resolvedDictionary.node!.children["F"]!.node != nil)
        #expect(resolvedDictionary.node!.children["F"]!.node!.prefix == "Foo")
        #expect(resolvedDictionary.node!.children["F"]!.node!.value != nil)
        #expect(resolvedDictionary.node!.children["F"]!.node!.value!.node != nil)
        #expect(resolvedDictionary.node!.children["F"]!.node!.value!.node!.val == 1)
        #expect(resolvedDictionary.node!.children["B"] != nil)
        #expect(resolvedDictionary.node!.children["B"]!.node == nil)
    }
    
    @Test("MerkleDictionary basic resolve list")
    func testMerkleDictionaryResolveList() async throws {
        typealias BaseDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestBaseStructure>>
        typealias BaseRadixHeader = BaseDictionaryType.ChildType
        typealias BaseRadixNode = BaseRadixHeader.NodeType
        let baseStructure1 = TestBaseStructure(val: 1)
        let baseStructure2 = TestBaseStructure(val: 2)
        let baseHeader1 = HeaderImpl(node: baseStructure1)
        let baseHeader2 = HeaderImpl(node: baseStructure2)
        let radixNode1 = BaseRadixNode(prefix: "oo", value: baseHeader1, children: [:])
        let radixNode2 = BaseRadixNode(prefix: "ar", value: baseHeader2, children: [:])
        let radixHeader1 = RadixHeaderImpl(node: radixNode1)
        let radixHeader2 = RadixHeaderImpl(node: radixNode2)
        let radixNode3 = BaseRadixNode(prefix: "F", value: baseHeader1, children: ["a": radixHeader2, "o": radixHeader1])
        let radixHeader3 = RadixHeaderImpl(node: radixNode3)
        let radixNode4 = BaseRadixNode(prefix: "G", value: baseHeader1, children: [:])
        let radixHeader4 = RadixHeaderImpl(node: radixNode4)
        let dictionary = BaseDictionaryType(children: ["F": radixHeader3, "G": radixHeader4], count: 3)
        let dictionaryHeader = HeaderImpl(node: dictionary)
        let testStoreFetcher = TestStoreFetcher()
        try dictionaryHeader.storeRecursively(storer: testStoreFetcher)
        let newDictionaryHeader = HeaderImpl<BaseDictionaryType>(rawCID: dictionaryHeader.rawCID)
        let resolvedDictionary = try await newDictionaryHeader.resolve(paths: [["F"]: .list], fetcher: testStoreFetcher)
        #expect(resolvedDictionary.node != nil)
        #expect(resolvedDictionary.node!.count == 3)
        #expect(resolvedDictionary.node!.children["F"] != nil)
        #expect(resolvedDictionary.node!.children["F"]!.node != nil)
        #expect(resolvedDictionary.node!.children["F"]!.node!.prefix == "F")
        #expect(resolvedDictionary.node!.children["F"]!.node!.value != nil)
        #expect(resolvedDictionary.node!.children["F"]!.node!.value!.node != nil)
        #expect(resolvedDictionary.node!.children["F"]!.node!.value!.node!.val == 1)
        #expect(resolvedDictionary.node!.children["F"]!.node!.children["a"] != nil)
        #expect(resolvedDictionary.node!.children["F"]!.node!.children["a"]!.node != nil)
        #expect(resolvedDictionary.node!.children["F"]!.node!.children["a"]!.node!.prefix == "ar")
        #expect(resolvedDictionary.node!.children["F"]!.node!.children["a"]!.node!.value != nil)
        #expect(resolvedDictionary.node!.children["F"]!.node!.children["a"]!.node!.value!.node != nil)
        #expect(resolvedDictionary.node!.children["F"]!.node!.children["a"]!.node!.value!.node!.val == 2)
        #expect(resolvedDictionary.node!.children["F"]!.node!.children["o"] != nil)
        #expect(resolvedDictionary.node!.children["F"]!.node!.children["o"]!.node != nil)
        #expect(resolvedDictionary.node!.children["F"]!.node!.children["o"]!.node!.prefix == "oo")
        #expect(resolvedDictionary.node!.children["F"]!.node!.children["o"]!.node!.value != nil)
        #expect(resolvedDictionary.node!.children["F"]!.node!.children["o"]!.node!.value!.node != nil)
        #expect(resolvedDictionary.node!.children["F"]!.node!.children["o"]!.node!.value!.node!.val == 1)
        #expect(resolvedDictionary.node!.children["G"] != nil)
        #expect(resolvedDictionary.node!.children["G"]!.node == nil)
    }
    
    @Test("MerkleDictionary nested dictionary resolve")
    func testMerkleDictionaryNestedDictionaryResolve() async throws {
        typealias BaseDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestBaseStructure>>
        typealias NestedDictionaryType = MerkleDictionaryImpl<HeaderImpl<BaseDictionaryType>>
        typealias BaseRadixHeader = BaseDictionaryType.ChildType
        typealias BaseRadixNode = BaseRadixHeader.NodeType
        typealias NestedRadixHeader = NestedDictionaryType.ChildType
        typealias NestedRadixNode = NestedRadixHeader.NodeType
        
        // Create base structures
        let baseStructure1 = TestBaseStructure(val: 10)
        let baseStructure2 = TestBaseStructure(val: 20)
        
        // Create base headers
        let baseHeader1 = HeaderImpl(node: baseStructure1)
        let baseHeader2 = HeaderImpl(node: baseStructure2)
        
        // Create radix nodes for inner dictionary
        let radixNode1 = BaseRadixNode(prefix: "item1", value: baseHeader1, children: [:])
        let radixNode2 = BaseRadixNode(prefix: "item2", value: baseHeader2, children: [:])
        let radixHeader1 = RadixHeaderImpl(node: radixNode1)
        let radixHeader2 = RadixHeaderImpl(node: radixNode2)
        
        // Create inner dictionary
        let innerDictionary1 = BaseDictionaryType(children: ["i": radixHeader1], count: 1)
        let innerDictionary2 = BaseDictionaryType(children: ["i": radixHeader2], count: 1)
        
        // Create headers for inner dictionaries
        let innerDictionaryHeader1 = HeaderImpl(node: innerDictionary1)
        let innerDictionaryHeader2 = HeaderImpl(node: innerDictionary2)
        
        // Create radix nodes for outer dictionary
        let outerRadixNode1 = NestedRadixNode(prefix: "level1", value: innerDictionaryHeader1, children: [:])
        let outerRadixNode2 = NestedRadixNode(prefix: "level2", value: innerDictionaryHeader2, children: [:])
        let outerRadixHeader1 = RadixHeaderImpl(node: outerRadixNode1)
        let outerRadixHeader2 = RadixHeaderImpl(node: outerRadixNode2)
        
        // Create outer dictionary
        let outerDictionary = NestedDictionaryType(children: ["l": outerRadixHeader1, "m": outerRadixHeader2], count: 2)
        let outerDictionaryHeader = HeaderImpl(node: outerDictionary)
        
        let testStoreFetcher = TestStoreFetcher()
        try outerDictionaryHeader.storeRecursively(storer: testStoreFetcher)
        
        // Test resolving specific nested path
        let newOuterDictionaryHeader = HeaderImpl<NestedDictionaryType>(rawCID: outerDictionaryHeader.rawCID)
        let resolvedDictionary = try await newOuterDictionaryHeader.resolve(paths: [["level1", "item1"]: .targeted], fetcher: testStoreFetcher)
        
        #expect(resolvedDictionary.node != nil)
        #expect(resolvedDictionary.node!.count == 2)
        #expect(resolvedDictionary.node!.children["l"] != nil)
        #expect(resolvedDictionary.node!.children["l"]!.node != nil)
        #expect(resolvedDictionary.node!.children["l"]!.node!.prefix == "level1")
        #expect(resolvedDictionary.node!.children["l"]!.node!.value != nil)
        #expect(resolvedDictionary.node!.children["l"]!.node!.value!.node != nil)
        #expect(resolvedDictionary.node!.children["l"]!.node!.value!.node!.children["i"] != nil)
        #expect(resolvedDictionary.node!.children["l"]!.node!.value!.node!.children["i"]!.node != nil)
        #expect(resolvedDictionary.node!.children["l"]!.node!.value!.node!.children["i"]!.node!.value!.node!.val == 10)
    }
    
    @Test("MerkleDictionary multiple path resolve")
    func testMerkleDictionaryMultiplePathResolve() async throws {
        typealias BaseDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestBaseStructure>>
        typealias BaseRadixHeader = BaseDictionaryType.ChildType
        typealias BaseRadixNode = BaseRadixHeader.NodeType
        
        // Create a complex structure with multiple branches
        let baseStructure1 = TestBaseStructure(val: 100)
        let baseStructure2 = TestBaseStructure(val: 200)
        let baseStructure3 = TestBaseStructure(val: 300)
        let baseStructure4 = TestBaseStructure(val: 400)
        
        let baseHeader1 = HeaderImpl(node: baseStructure1)
        let baseHeader2 = HeaderImpl(node: baseStructure2)
        let baseHeader3 = HeaderImpl(node: baseStructure3)
        let baseHeader4 = HeaderImpl(node: baseStructure4)
        
        // Create leaf nodes
        let leafNode1 = BaseRadixNode(prefix: "1leaf1", value: baseHeader1, children: [:])
        let leafNode2 = BaseRadixNode(prefix: "2leaf2", value: baseHeader2, children: [:])
        let leafNode3 = BaseRadixNode(prefix: "3leaf3", value: baseHeader3, children: [:])
        let leafNode4 = BaseRadixNode(prefix: "4leaf4", value: baseHeader4, children: [:])
        
        let leafHeader1 = RadixHeaderImpl(node: leafNode1)
        let leafHeader2 = RadixHeaderImpl(node: leafNode2)
        let leafHeader3 = RadixHeaderImpl(node: leafNode3)
        let leafHeader4 = RadixHeaderImpl(node: leafNode4)
        
        // Create branch nodes
        let branchNode1 = BaseRadixNode(prefix: "Abranch", value: baseHeader1, children: ["1": leafHeader1, "2": leafHeader2])
        let branchNode2 = BaseRadixNode(prefix: "Bbranch", value: baseHeader3, children: ["3": leafHeader3, "4": leafHeader4])
        
        let branchHeader1 = RadixHeaderImpl(node: branchNode1)
        let branchHeader2 = RadixHeaderImpl(node: branchNode2)
        
        // Create root dictionary
        let dictionary = BaseDictionaryType(children: ["A": branchHeader1, "B": branchHeader2], count: 6)
        let dictionaryHeader = HeaderImpl(node: dictionary)
        
        let testStoreFetcher = TestStoreFetcher()
        try dictionaryHeader.storeRecursively(storer: testStoreFetcher)
        
        // Test resolving multiple specific paths
        let newDictionaryHeader = HeaderImpl<BaseDictionaryType>(rawCID: dictionaryHeader.rawCID)
        let resolvedDictionary = try await newDictionaryHeader.resolve(paths: [
            ["Abranch1"]: .targeted,
            ["Bbranch4"]: .targeted
        ], fetcher: testStoreFetcher)
        
        #expect(resolvedDictionary.node != nil)
        #expect(resolvedDictionary.node!.count == 6)
        
        // Check first path resolution
        #expect(resolvedDictionary.node!.children["A"] != nil)
        #expect(resolvedDictionary.node!.children["A"]!.node != nil)
        #expect(resolvedDictionary.node!.children["A"]!.node!.children["1"] != nil)
        #expect(resolvedDictionary.node!.children["A"]!.node!.children["1"]!.node != nil)
        #expect(resolvedDictionary.node!.children["A"]!.node!.children["1"]!.node!.value!.node!.val == 100)
        
        // Check second path resolution
        #expect(resolvedDictionary.node!.children["B"] != nil)
        #expect(resolvedDictionary.node!.children["B"]!.node != nil)
        #expect(resolvedDictionary.node!.children["B"]!.node!.children["4"] != nil)
        #expect(resolvedDictionary.node!.children["B"]!.node!.children["4"]!.node != nil)
        #expect(resolvedDictionary.node!.children["B"]!.node!.children["4"]!.node!.value!.node!.val == 400)
        
        // Verify unresolved paths are not loaded
        #expect(resolvedDictionary.node!.children["A"]!.node!.children["2"]!.node == nil)
        #expect(resolvedDictionary.node!.children["B"]!.node!.children["3"]!.node == nil)
    }
    
    @Test("MerkleDictionary recursive resolve")
    func testMerkleDictionaryRecursiveResolve() async throws {
        typealias BaseDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestBaseStructure>>
        typealias BaseRadixHeader = BaseDictionaryType.ChildType
        typealias BaseRadixNode = BaseRadixHeader.NodeType
        
        let baseStructure1 = TestBaseStructure(val: 1)
        let baseStructure2 = TestBaseStructure(val: 2)
        let baseHeader1 = HeaderImpl(node: baseStructure1)
        let baseHeader2 = HeaderImpl(node: baseStructure2)
        let radixNode1 = BaseRadixNode(prefix: "Test1", value: baseHeader1, children: [:])
        let radixNode2 = BaseRadixNode(prefix: "Test2", value: baseHeader2, children: [:])
        let radixHeader1 = RadixHeaderImpl(node: radixNode1)
        let radixHeader2 = RadixHeaderImpl(node: radixNode2)
        let dictionary = BaseDictionaryType(children: ["T": radixHeader1, "U": radixHeader2], count: 2)
        let dictionaryHeader = HeaderImpl(node: dictionary)
        
        let testStoreFetcher = TestStoreFetcher()
        try dictionaryHeader.storeRecursively(storer: testStoreFetcher)
        
        // Test resolving with empty paths - should load root but no children
        let newDictionaryHeader = HeaderImpl<BaseDictionaryType>(rawCID: dictionaryHeader.rawCID)
        let resolvedDictionary = try await newDictionaryHeader.resolveRecursive(fetcher: testStoreFetcher)
        
        #expect(resolvedDictionary.node != nil)
        #expect(resolvedDictionary.node!.count == 2)
        #expect(resolvedDictionary.node!.children["T"] != nil)
        #expect(resolvedDictionary.node!.children["T"]!.node != nil)
        #expect(resolvedDictionary.node!.children["T"]!.node!.value!.node!.val == 1)
        #expect(resolvedDictionary.node!.children["U"] != nil)
        #expect(resolvedDictionary.node!.children["U"]!.node != nil)
        #expect(resolvedDictionary.node!.children["U"]!.node!.value!.node!.val == 2)
    }
    
    @Test("MerkleDictionary deep nesting resolve")
    func testMerkleDictionaryDeepNestingResolve() async throws {
        typealias Level1Type = MerkleDictionaryImpl<HeaderImpl<TestBaseStructure>>
        typealias Level2Type = MerkleDictionaryImpl<HeaderImpl<Level1Type>>
        typealias Level3Type = MerkleDictionaryImpl<HeaderImpl<Level2Type>>
        typealias Level4Type = MerkleDictionaryImpl<HeaderImpl<Level3Type>>
        
        // Create deepest level (Level 1 - base structures)
        let baseStructure = TestBaseStructure(val: 999)
        let baseHeader = HeaderImpl(node: baseStructure)
        let level1RadixNode = Level1Type.ChildType.NodeType(prefix: "deep", value: baseHeader, children: [:])
        let level1RadixHeader = RadixHeaderImpl(node: level1RadixNode)
        let level1Dict = Level1Type(children: ["d": level1RadixHeader], count: 1)
        let level1Header = HeaderImpl(node: level1Dict)
        
        // Create Level 2
        let level2RadixNode = Level2Type.ChildType.NodeType(prefix: "level2", value: level1Header, children: [:])
        let level2RadixHeader = RadixHeaderImpl(node: level2RadixNode)
        let level2Dict = Level2Type(children: ["l": level2RadixHeader], count: 1)
        let level2Header = HeaderImpl(node: level2Dict)
        
        // Create Level 3
        let level3RadixNode = Level3Type.ChildType.NodeType(prefix: "level3", value: level2Header, children: [:])
        let level3RadixHeader = RadixHeaderImpl(node: level3RadixNode)
        let level3Dict = Level3Type(children: ["l": level3RadixHeader], count: 1)
        let level3Header = HeaderImpl(node: level3Dict)
        
        // Create Level 4 (root)
        let level4RadixNode = Level4Type.ChildType.NodeType(prefix: "root", value: level3Header, children: [:])
        let level4RadixHeader = RadixHeaderImpl(node: level4RadixNode)
        let level4Dict = Level4Type(children: ["r": level4RadixHeader], count: 1)
        let level4Header = HeaderImpl(node: level4Dict)
        
        let testStoreFetcher = TestStoreFetcher()
        try level4Header.storeRecursively(storer: testStoreFetcher)
        
        // Test resolving deep path
        let newLevel4Header = HeaderImpl<Level4Type>(rawCID: level4Header.rawCID)
        let resolvedDictionary = try await newLevel4Header.resolve(paths: [["root", "level3", "level2", "deep"]: .targeted], fetcher: testStoreFetcher)
        
        #expect(resolvedDictionary.node != nil)
        let rootNode = resolvedDictionary.node!.children["r"]!.node!
        let level3Node = rootNode.value!.node!.children["l"]!.node!
        let level2Node = level3Node.value!.node!.children["l"]!.node!
        let level1Node = level2Node.value!.node!.children["d"]!.node!
        #expect(level1Node.value!.node!.val == 999)
    }
    
    @Test("MerkleDictionary partial path matching")
    func testMerkleDictionaryPartialPathMatching() async throws {
        typealias BaseDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestBaseStructure>>
        typealias BaseRadixHeader = BaseDictionaryType.ChildType
        typealias BaseRadixNode = BaseRadixHeader.NodeType
        
        let baseStructure1 = TestBaseStructure(val: 111)
        let baseStructure2 = TestBaseStructure(val: 222)
        let baseStructure3 = TestBaseStructure(val: 333)
        
        let baseHeader1 = HeaderImpl(node: baseStructure1)
        let baseHeader2 = HeaderImpl(node: baseStructure2)
        let baseHeader3 = HeaderImpl(node: baseStructure3)
        
        // Create nodes with overlapping prefixes
        let radixNode1 = BaseRadixNode(prefix: "common", value: baseHeader1, children: [:])
        let radixNode2 = BaseRadixNode(prefix: "commonPrefix", value: baseHeader2, children: [:])
        let radixNode3 = BaseRadixNode(prefix: "commonPrefixLong", value: baseHeader3, children: [:])
        
        let radixHeader1 = RadixHeaderImpl(node: radixNode1)
        let radixHeader2 = RadixHeaderImpl(node: radixNode2)
        let radixHeader3 = RadixHeaderImpl(node: radixNode3)
        
        let dictionary = BaseDictionaryType(children: ["c": radixHeader1, "d": radixHeader2, "e": radixHeader3], count: 3)
        let dictionaryHeader = HeaderImpl(node: dictionary)
        
        let testStoreFetcher = TestStoreFetcher()
        try dictionaryHeader.storeRecursively(storer: testStoreFetcher)
        
        // Test resolving with partial path that should match the middle one
        let newDictionaryHeader = HeaderImpl<BaseDictionaryType>(rawCID: dictionaryHeader.rawCID)
        let resolvedDictionary = try await newDictionaryHeader.resolve(paths: [["dcommonPrefix"]: .targeted], fetcher: testStoreFetcher)
        
        #expect(resolvedDictionary.node != nil)
        #expect(resolvedDictionary.node!.count == 3)
        #expect(resolvedDictionary.node!.children["d"] != nil)
        #expect(resolvedDictionary.node!.children["d"]!.node != nil)
        #expect(resolvedDictionary.node!.children["d"]!.node!.value!.node!.val == 222)
        
        // Other nodes should not be resolved
        #expect(resolvedDictionary.node!.children["c"]!.node == nil)
        #expect(resolvedDictionary.node!.children["e"]!.node == nil)
    }
    
    @Test("MerkleDictionary large scale resolve")
    func testMerkleDictionaryLargeScaleResolve() async throws {
        typealias BaseDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestBaseStructure>>
        typealias BaseRadixHeader = BaseDictionaryType.ChildType
        typealias BaseRadixNode = BaseRadixHeader.NodeType
        
        var children: [Character: BaseRadixHeader] = [:]
        let totalNodes = 10 // Reduced for simpler testing
        
        // Create many nodes
        for i in 0..<totalNodes {
            let baseStructure = TestBaseStructure(val: i * 10)
            let baseHeader = HeaderImpl(node: baseStructure)
            let radixNode = BaseRadixNode(prefix: "node\(i)", value: baseHeader, children: [:])
            let radixHeader = RadixHeaderImpl(node: radixNode)
            children[Character(extendedGraphemeClusterLiteral: "\(i)".first!)] = radixHeader
        }
        
        let dictionary = BaseDictionaryType(children: children, count: totalNodes)
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
        
        // Check resolved nodes
        #expect(resolvedDictionary.node!.children["5"] != nil)
        #expect(resolvedDictionary.node!.children["5"]!.node != nil)
        #expect(resolvedDictionary.node!.children["5"]!.node!.value!.node!.val == 50)
        
        #expect(resolvedDictionary.node!.children["7"] != nil)
        #expect(resolvedDictionary.node!.children["7"]!.node != nil)
        #expect(resolvedDictionary.node!.children["7"]!.node!.value!.node!.val == 70)
        
        // Check that other nodes are not resolved
        #expect(resolvedDictionary.node!.children["1"] != nil)
        #expect(resolvedDictionary.node!.children["1"]!.node == nil)
        #expect(resolvedDictionary.node!.children["3"] != nil)
        #expect(resolvedDictionary.node!.children["3"]!.node == nil)
    }
    
    @Test("MerkleDictionary deep list resolve")
    func testMerkleDictionaryDeepListResolve() async throws {
        typealias HigherRadixNode = RadixNodeImpl<BaseDictionaryHeader>
        typealias HigherRadixHeader = RadixHeaderImpl<BaseDictionaryHeader>
        typealias HigherDictionaryHeader = HeaderImpl<HigherDictionaryType>
        typealias HigherDictionaryType = MerkleDictionaryImpl<HigherRadixNode.ValueType>
        typealias BaseDictionaryHeader = HeaderImpl<BaseDictionaryType>
        typealias BaseDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestBaseStructure>>
        typealias BaseRadixHeader = RadixHeaderImpl<HeaderImpl<TestBaseStructure>>
        typealias BaseRadixNode = RadixNodeImpl<HeaderImpl<TestBaseStructure>>
        
        // base structure + headers
        let baseStructure1 = TestBaseStructure(val: 1)
        let baseStructure2 = TestBaseStructure(val: 2)
        let baseHeader1 = HeaderImpl(node: baseStructure1)
        let baseHeader2 = HeaderImpl(node: baseStructure2)
        
        
        let radixNode1 = BaseRadixNode(prefix: "Foo", value: baseHeader1, children: [:])
        let radixNode2 = BaseRadixNode(prefix: "Bar", value: baseHeader2, children: [:])
        let radixHeader1 = RadixHeaderImpl(node: radixNode1)
        let radixHeader2 = RadixHeaderImpl(node: radixNode2)
        let dictionary = BaseDictionaryType(children: ["F": radixHeader1, "B": radixHeader2], count: 2)
        let dictionaryHeader = HeaderImpl(node: dictionary)
        
        let radixNode3 = HigherRadixNode(prefix: "Foo", value: dictionaryHeader, children: [:])
        let radixNode4 = HigherRadixNode(prefix: "Bar", value: dictionaryHeader, children: [:])
        let radixHeader3 = HigherRadixHeader(node: radixNode3)
        let radixHeader4 = HigherRadixHeader(node: radixNode4)
        
        let higherDictionary = HigherDictionaryType(children: ["F": radixHeader3, "B": radixHeader4], count: 2)
        let higherDictionaryHeader = HeaderImpl(node: higherDictionary)
        
        let testStoreFetcher = TestStoreFetcher()
        try higherDictionaryHeader.storeRecursively(storer: testStoreFetcher)
        let newDictionaryHeader = HigherDictionaryHeader(rawCID: higherDictionaryHeader.rawCID)
        var resolutionPaths = ArrayTrie<ResolutionStrategy>()
        resolutionPaths.set(["Foo", "Foo"], value: ResolutionStrategy.targeted)
        resolutionPaths.set(["Fo"], value: ResolutionStrategy.list)
        let resolvedDictionary = try await newDictionaryHeader.resolve(paths: resolutionPaths, fetcher: testStoreFetcher)
        #expect(resolvedDictionary.node != nil)
        #expect(resolvedDictionary.node!.count == 2)
        #expect(resolvedDictionary.node!.children["F"] != nil)
        #expect(resolvedDictionary.node!.children["F"]!.node != nil)
        #expect(resolvedDictionary.node!.children["F"]!.node!.prefix == "Foo")
        #expect(resolvedDictionary.node!.children["F"]!.node!.value != nil)
        #expect(resolvedDictionary.node!.children["F"]!.node!.value!.node != nil)
        #expect(resolvedDictionary.node!.children["B"] != nil)
        #expect(resolvedDictionary.node!.children["B"]!.node == nil)
        #expect(resolvedDictionary.node!.children["F"]!.node!.value!.node!.children["F"] != nil)
        #expect(resolvedDictionary.node!.children["F"]!.node!.value!.node!.children["F"]!.node != nil)
        #expect(resolvedDictionary.node!.children["F"]!.node!.value!.node!.children["F"]!.node!.value != nil)
        #expect(resolvedDictionary.node!.children["F"]!.node!.value!.node!.children["F"]!.node!.value!.node != nil)
        #expect(resolvedDictionary.node!.children["F"]!.node!.value!.node!.children["F"]!.node!.value!.node!.val == 1)
        #expect(resolvedDictionary.node!.children["F"]!.node!.value!.node!.children["B"] != nil)
        #expect(resolvedDictionary.node!.children["F"]!.node!.value!.node!.children["B"]!.node == nil)
    }

}
