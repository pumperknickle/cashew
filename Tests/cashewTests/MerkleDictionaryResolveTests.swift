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
}
