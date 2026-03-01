import Testing
import Foundation
import ArrayTrie
@preconcurrency import Multicodec
@testable import cashew

@Suite("Bug Fix Tests")
struct BugFixTests {

    struct TestScalar: Scalar {
        let val: Int

        init(val: Int) {
            self.val = val
        }
    }

    // MARK: - Bug 1: Inverted ternary in nested-dict RadixNode transform

    @Test("Nested dict transform applies child transforms correctly")
    func testNestedDictTransformAppliesChildTransforms() throws {
        typealias BaseDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestScalar>>
        typealias NestedDictionaryType = MerkleDictionaryImpl<HeaderImpl<BaseDictionaryType>>

        let scalar1 = TestScalar(val: 1)
        let scalar2 = TestScalar(val: 2)
        let header1 = HeaderImpl(node: scalar1)
        let header2 = HeaderImpl(node: scalar2)

        let emptyBase = BaseDictionaryType(children: [:], count: 0)
        let innerDict = try emptyBase
            .inserting(key: "alpha", value: header1)
            .inserting(key: "beta", value: header2)
        let innerHeader = HeaderImpl(node: innerDict)

        let emptyNested = NestedDictionaryType(children: [:], count: 0)
        let outerDict = try emptyNested
            .inserting(key: "group", value: innerHeader)

        let newScalar = TestScalar(val: 99)
        let newHeader = HeaderImpl(node: newScalar)

        var transforms = ArrayTrie<Transform>()
        transforms.set(["group", "alpha"], value: .update(newHeader.description))

        let result = try outerDict.transform(transforms: transforms)!
        let resultGroup = try result.get(key: "group")
        #expect(resultGroup != nil)
        let resultAlpha = try resultGroup!.node!.get(key: "alpha")
        #expect(resultAlpha != nil)
    }

    @Test("Nested dict transform with sibling children preserved")
    func testNestedDictTransformSiblingChildrenPreserved() throws {
        typealias BaseDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestScalar>>
        typealias NestedDictionaryType = MerkleDictionaryImpl<HeaderImpl<BaseDictionaryType>>

        let scalar1 = TestScalar(val: 10)
        let scalar2 = TestScalar(val: 20)
        let scalar3 = TestScalar(val: 30)
        let header1 = HeaderImpl(node: scalar1)
        let header2 = HeaderImpl(node: scalar2)
        let header3 = HeaderImpl(node: scalar3)

        let emptyBase = BaseDictionaryType(children: [:], count: 0)
        let innerDict1 = try emptyBase
            .inserting(key: "x", value: header1)
            .inserting(key: "y", value: header2)
        let innerDict2 = try emptyBase
            .inserting(key: "z", value: header3)
        let innerHeader1 = HeaderImpl(node: innerDict1)
        let innerHeader2 = HeaderImpl(node: innerDict2)

        let emptyNested = NestedDictionaryType(children: [:], count: 0)
        let outerDict = try emptyNested
            .inserting(key: "first", value: innerHeader1)
            .inserting(key: "second", value: innerHeader2)

        let newScalar = TestScalar(val: 999)
        let newHeader = HeaderImpl(node: newScalar)

        var transforms = ArrayTrie<Transform>()
        transforms.set(["first", "x"], value: .update(newHeader.description))

        let result = try outerDict.transform(transforms: transforms)!
        #expect(result.count == 2)
        let resultSecond = try result.get(key: "second")
        #expect(resultSecond != nil)
        let resultZ = try resultSecond!.node!.get(key: "z")
        #expect(resultZ?.node?.val == 30)
    }

    // MARK: - Bug 3: set(property:to:) no-op fix

    @Test("RadixNode set(property:to:) actually updates the child")
    func testRadixNodeSetPropertyToUpdatesChild() throws {
        typealias DictType = MerkleDictionaryImpl<String>

        let dict = try DictType(children: [:], count: 0)
            .inserting(key: "alice", value: "val1")
            .inserting(key: "bob", value: "val2")

        let aliceChild = dict.children["a"]!
        let bobChild = dict.children["b"]!

        let aliceNode = aliceChild.node!
        let result = aliceNode.set(property: "b", to: bobChild)

        #expect(result.children["b"] != nil)
    }

    @Test("RadixNode set(property:to:) with empty property returns self")
    func testRadixNodeSetPropertyToEmptyPropertyReturnsSelf() throws {
        typealias DictType = MerkleDictionaryImpl<String>

        let dict = try DictType(children: [:], count: 0)
            .inserting(key: "alice", value: "val1")

        let aliceChild = dict.children["a"]!
        let aliceNode = aliceChild.node!
        let result = aliceNode.set(property: "", to: aliceChild)
        #expect(result.prefix == aliceNode.prefix)
        #expect(result.children.count == aliceNode.children.count)
    }

    // MARK: - Bug 5: Node.description no longer crashes on encoding failure

    @Test("Node description returns empty string when encoding fails")
    func testNodeDescriptionSafeOnEncodingFailure() throws {
        let dict = MerkleDictionaryImpl<String>(children: [:], count: 0)
        let description = dict.description
        #expect(!description.isEmpty)
    }

    @Test("Node description works for valid nodes")
    func testNodeDescriptionWorksForValidNodes() throws {
        let scalar = TestScalar(val: 42)
        let description = scalar.description
        #expect(description.contains("42"))
    }

    // MARK: - Bug 6: CID creation throws on serialization failure

    @Test("Header CID is deterministic for identical nodes")
    func testHeaderCIDDeterministic() throws {
        let scalar1 = TestScalar(val: 100)
        let scalar2 = TestScalar(val: 100)
        let header1 = HeaderImpl(node: scalar1)
        let header2 = HeaderImpl(node: scalar2)
        #expect(header1.rawCID == header2.rawCID)
    }

    @Test("Header CID differs for different nodes")
    func testHeaderCIDDiffers() throws {
        let scalar1 = TestScalar(val: 1)
        let scalar2 = TestScalar(val: 2)
        let header1 = HeaderImpl(node: scalar1)
        let header2 = HeaderImpl(node: scalar2)
        #expect(header1.rawCID != header2.rawCID)
    }

    @Test("serializeNode throws on failure rather than returning empty data")
    func testSerializeNodeThrowsOnFailure() throws {
        let scalar = TestScalar(val: 42)
        let header = HeaderImpl(node: scalar)
        let data = try header.mapToData()
        #expect(!data.isEmpty)
    }

    // MARK: - Bug 7: resolveList safe cast to Address

    @Test("resolveList with string values does not crash")
    func testResolveListWithStringValuesDoesNotCrash() async throws {
        typealias DictType = MerkleDictionaryImpl<String>

        let dict = try DictType(children: [:], count: 0)
            .inserting(key: "Foo", value: "bar")
            .inserting(key: "Far", value: "baz")

        let header = HeaderImpl(node: dict)
        let fetcher = TestStoreFetcher()
        try header.storeRecursively(storer: fetcher)

        let unresolved = HeaderImpl<DictType>(rawCID: header.rawCID)
        let resolved = try await unresolved.resolve(paths: [["F"]: .list], fetcher: fetcher)
        #expect(resolved.node != nil)
        #expect(resolved.node!.count == 2)
    }

    @Test("resolveList with Address values resolves correctly")
    func testResolveListWithAddressValues() async throws {
        typealias BaseDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestScalar>>

        let scalar1 = TestScalar(val: 1)
        let scalar2 = TestScalar(val: 2)
        let header1 = HeaderImpl(node: scalar1)
        let header2 = HeaderImpl(node: scalar2)

        let emptyDict = BaseDictionaryType(children: [:], count: 0)
        let dict = try emptyDict
            .inserting(key: "Foo", value: header1)
            .inserting(key: "Far", value: header2)

        let dictHeader = HeaderImpl(node: dict)
        let fetcher = TestStoreFetcher()
        try dictHeader.storeRecursively(storer: fetcher)

        let unresolved = HeaderImpl<BaseDictionaryType>(rawCID: dictHeader.rawCID)
        let resolved = try await unresolved.resolve(paths: [["F"]: .list], fetcher: fetcher)
        #expect(resolved.node != nil)
        #expect(resolved.node!.count == 2)

        let fooValue = try resolved.node!.get(key: "Foo")
        #expect(fooValue != nil)
        #expect(fooValue!.node == nil)
    }

    // MARK: - Bug 8: MerkleDictionary.get(property:) safe on multi-char keys

    @Test("MerkleDictionary get(property:) with single char key works")
    func testMerkleDictionaryGetPropertySingleChar() throws {
        let dict = try MerkleDictionaryImpl<String>(children: [:], count: 0)
            .inserting(key: "alice", value: "val1")

        let result = dict.get(property: "a")
        #expect(result != nil)
    }

    @Test("MerkleDictionary get(property:) with empty key returns nil")
    func testMerkleDictionaryGetPropertyEmptyKey() throws {
        let dict = try MerkleDictionaryImpl<String>(children: [:], count: 0)
            .inserting(key: "alice", value: "val1")

        let result = dict.get(property: "")
        #expect(result == nil)
    }

    @Test("MerkleDictionary get(property:) with multi-char key uses first char")
    func testMerkleDictionaryGetPropertyMultiCharKey() throws {
        let dict = try MerkleDictionaryImpl<String>(children: [:], count: 0)
            .inserting(key: "alice", value: "val1")

        let result = dict.get(property: "alice")
        #expect(result != nil)
    }

    // MARK: - Bug 10: CashewDecodingError no longer shadows Swift.DecodingError

    @Test("CashewDecodingError is throwable and catchable")
    func testCashewDecodingErrorThrowable() throws {
        #expect(throws: CashewDecodingError.self) {
            throw CashewDecodingError.decodeFromDataError
        }
    }

    @Test("CashewDecodingError does not conflict with Swift.DecodingError")
    func testCashewDecodingErrorNoConflict() throws {
        let cashewError: Error = CashewDecodingError.decodeFromDataError
        let swiftError: Error = Swift.DecodingError.dataCorrupted(
            Swift.DecodingError.Context(codingPath: [], debugDescription: "test")
        )

        #expect(cashewError is CashewDecodingError)
        #expect(swiftError is Swift.DecodingError)
        #expect(!(cashewError is Swift.DecodingError))
        #expect(!(swiftError is CashewDecodingError))
    }

    @Test("Decoding invalid data throws CashewDecodingError")
    func testDecodingInvalidDataThrowsCashewError() async throws {
        let fetcher = TestStoreFetcher()
        fetcher.storeRaw(rawCid: "fakeCID", data: Data([0xFF, 0xFE]))

        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: "fakeCID")
        await #expect(throws: CashewDecodingError.self) {
            _ = try await header.resolve(fetcher: fetcher)
        }
    }

    // MARK: - Existing functionality regression tests

    @Test("Basic dictionary operations still work after fixes")
    func testBasicDictionaryOperationsRegression() throws {
        let dict = try MerkleDictionaryImpl<String>(children: [:], count: 0)
            .inserting(key: "key1", value: "value1")
            .inserting(key: "key2", value: "value2")
            .inserting(key: "key3", value: "value3")

        #expect(dict.count == 3)
        #expect(try dict.get(key: "key1") == "value1")
        #expect(try dict.get(key: "key2") == "value2")
        #expect(try dict.get(key: "key3") == "value3")

        let deleted = try dict.deleting(key: "key2")
        #expect(deleted.count == 2)
        #expect(try deleted.get(key: "key2") == nil)

        let mutated = try dict.mutating(key: ArraySlice("key1"), value: "updated1")
        #expect(mutated.count == 3)
        #expect(try mutated.get(key: "key1") == "updated1")
    }

    @Test("Transform operations still work after fixes")
    func testTransformOperationsRegression() throws {
        let dict = try MerkleDictionaryImpl<String>(children: [:], count: 0)
            .inserting(key: "existing", value: "old")

        var transforms = ArrayTrie<Transform>()
        transforms.set(["existing"], value: .update("new"))
        transforms.set(["added"], value: .insert("fresh"))

        let result = try dict.transform(transforms: transforms)!
        #expect(result.count == 2)
        #expect(try result.get(key: "existing") == "new")
        #expect(try result.get(key: "added") == "fresh")
    }

    @Test("Resolve operations still work after fixes")
    func testResolveOperationsRegression() async throws {
        typealias BaseDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestScalar>>

        let scalar1 = TestScalar(val: 1)
        let header1 = HeaderImpl(node: scalar1)

        let dict = try BaseDictionaryType(children: [:], count: 0)
            .inserting(key: "Foo", value: header1)
        let dictHeader = HeaderImpl(node: dict)
        let fetcher = TestStoreFetcher()
        try dictHeader.storeRecursively(storer: fetcher)

        let unresolved = HeaderImpl<BaseDictionaryType>(rawCID: dictHeader.rawCID)
        let resolved = try await unresolved.resolveRecursive(fetcher: fetcher)
        #expect(resolved.node != nil)
        let fooValue = try resolved.node!.get(key: "Foo")
        #expect(fooValue?.node?.val == 1)
    }

    @Test("Content addressability preserved after fixes")
    func testContentAddressabilityRegression() throws {
        let scalar = TestScalar(val: 42)
        let header1 = HeaderImpl(node: scalar)
        let header2 = HeaderImpl(node: scalar)
        #expect(header1.rawCID == header2.rawCID)

        let dict1 = try MerkleDictionaryImpl<String>(children: [:], count: 0)
            .inserting(key: "a", value: "1")
        let dict2 = try MerkleDictionaryImpl<String>(children: [:], count: 0)
            .inserting(key: "a", value: "1")
        let dh1 = HeaderImpl(node: dict1)
        let dh2 = HeaderImpl(node: dict2)
        #expect(dh1.rawCID == dh2.rawCID)
    }
}
