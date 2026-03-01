import Testing
import Foundation
import ArrayTrie
@preconcurrency import Multicodec
@testable import cashew

@Suite("Complex Edge Case Tests")
struct ComplexEdgeCaseTests {

    struct TestScalar: Scalar {
        let val: Int
        init(val: Int) { self.val = val }
    }

    // MARK: - Three-level nested dictionary structures

    typealias LeafDict = MerkleDictionaryImpl<String>
    typealias MidDict = MerkleDictionaryImpl<HeaderImpl<LeafDict>>
    typealias TopDict = MerkleDictionaryImpl<HeaderImpl<MidDict>>

    @Test("Three-level nested dictionary: build, store, resolve, verify")
    func testThreeLevelNestedBuildStoreResolve() async throws {
        let leaf1 = try LeafDict(children: [:], count: 0)
            .inserting(key: "color", value: "red")
            .inserting(key: "size", value: "large")
        let leaf2 = try LeafDict(children: [:], count: 0)
            .inserting(key: "color", value: "blue")
            .inserting(key: "weight", value: "10kg")
            .inserting(key: "material", value: "steel")

        let mid = try MidDict(children: [:], count: 0)
            .inserting(key: "itemA", value: HeaderImpl(node: leaf1))
            .inserting(key: "itemB", value: HeaderImpl(node: leaf2))

        let top = try TopDict(children: [:], count: 0)
            .inserting(key: "warehouse1", value: HeaderImpl(node: mid))

        let topHeader = HeaderImpl(node: top)
        let fetcher = TestStoreFetcher()
        try topHeader.storeRecursively(storer: fetcher)

        let unresolved = HeaderImpl<TopDict>(rawCID: topHeader.rawCID)
        let resolved = try await unresolved.resolveRecursive(fetcher: fetcher)

        #expect(resolved.rawCID == topHeader.rawCID)
        let w1 = try resolved.node!.get(key: "warehouse1")
        #expect(w1 != nil)
        let itemA = try w1!.node!.get(key: "itemA")
        #expect(itemA != nil)
        #expect(try itemA!.node!.get(key: "color") == "red")
        #expect(try itemA!.node!.get(key: "size") == "large")
        let itemB = try w1!.node!.get(key: "itemB")
        #expect(try itemB!.node!.get(key: "material") == "steel")
    }

    @Test("Three-level nested dictionary: content addressability across levels")
    func testThreeLevelContentAddressability() throws {
        let leaf = try LeafDict(children: [:], count: 0)
            .inserting(key: "x", value: "1")
            .inserting(key: "y", value: "2")
        let leafHeader = HeaderImpl(node: leaf)

        let mid1 = try MidDict(children: [:], count: 0)
            .inserting(key: "shared", value: leafHeader)
        let mid2 = try MidDict(children: [:], count: 0)
            .inserting(key: "shared", value: leafHeader)

        let midH1 = HeaderImpl(node: mid1)
        let midH2 = HeaderImpl(node: mid2)
        #expect(midH1.rawCID == midH2.rawCID)

        let top1 = try TopDict(children: [:], count: 0)
            .inserting(key: "branch", value: midH1)
        let top2 = try TopDict(children: [:], count: 0)
            .inserting(key: "branch", value: midH2)
        let topH1 = HeaderImpl(node: top1)
        let topH2 = HeaderImpl(node: top2)
        #expect(topH1.rawCID == topH2.rawCID)
    }

    @Test("Three-level nested: transform at leaf level, verify CID change propagates")
    func testThreeLevelTransformCIDPropagation() throws {
        let leaf = try LeafDict(children: [:], count: 0)
            .inserting(key: "key1", value: "val1")
            .inserting(key: "key2", value: "val2")
        let leafHeader = HeaderImpl(node: leaf)

        let mid = try MidDict(children: [:], count: 0)
            .inserting(key: "child", value: leafHeader)
        let midHeader = HeaderImpl(node: mid)

        let top = try TopDict(children: [:], count: 0)
            .inserting(key: "root", value: midHeader)
        let topHeader = HeaderImpl(node: top)

        let newLeaf = try LeafDict(children: [:], count: 0)
            .inserting(key: "key1", value: "CHANGED")
            .inserting(key: "key2", value: "val2")
        let newLeafHeader = HeaderImpl(node: newLeaf)

        let newMid = try MidDict(children: [:], count: 0)
            .inserting(key: "child", value: newLeafHeader)
        let newMidHeader = HeaderImpl(node: newMid)

        let newTop = try TopDict(children: [:], count: 0)
            .inserting(key: "root", value: newMidHeader)
        let newTopHeader = HeaderImpl(node: newTop)

        #expect(leafHeader.rawCID != newLeafHeader.rawCID)
        #expect(midHeader.rawCID != newMidHeader.rawCID)
        #expect(topHeader.rawCID != newTopHeader.rawCID)
    }

    // MARK: - Store/resolve round-trip fidelity

    @Test("Store and resolve round-trip preserves all data in nested structure")
    func testStoreResolveRoundTripNested() async throws {
        typealias InnerDict = MerkleDictionaryImpl<HeaderImpl<TestScalar>>

        let s1 = TestScalar(val: 42)
        let s2 = TestScalar(val: 99)
        let s3 = TestScalar(val: 7)

        let inner = try InnerDict(children: [:], count: 0)
            .inserting(key: "alpha", value: HeaderImpl(node: s1))
            .inserting(key: "beta", value: HeaderImpl(node: s2))
            .inserting(key: "gamma", value: HeaderImpl(node: s3))

        let outerDict = try MerkleDictionaryImpl<HeaderImpl<InnerDict>>(children: [:], count: 0)
            .inserting(key: "group1", value: HeaderImpl(node: inner))

        let header = HeaderImpl(node: outerDict)
        let fetcher = TestStoreFetcher()
        try header.storeRecursively(storer: fetcher)

        let unresolved = HeaderImpl<MerkleDictionaryImpl<HeaderImpl<InnerDict>>>(rawCID: header.rawCID)
        let resolved = try await unresolved.resolveRecursive(fetcher: fetcher)

        #expect(resolved.rawCID == header.rawCID)
        let g1 = try resolved.node!.get(key: "group1")!
        #expect(g1.node!.count == 3)
        #expect(try g1.node!.get(key: "alpha")!.node!.val == 42)
        #expect(try g1.node!.get(key: "beta")!.node!.val == 99)
        #expect(try g1.node!.get(key: "gamma")!.node!.val == 7)
    }

    @Test("Store/resolve round-trip with targeted resolution only resolves requested paths")
    func testTargetedResolutionSelectivity() async throws {
        typealias DictType = MerkleDictionaryImpl<HeaderImpl<TestScalar>>

        let dict = try DictType(children: [:], count: 0)
            .inserting(key: "Foo", value: HeaderImpl(node: TestScalar(val: 1)))
            .inserting(key: "Bar", value: HeaderImpl(node: TestScalar(val: 2)))
            .inserting(key: "Baz", value: HeaderImpl(node: TestScalar(val: 3)))

        let header = HeaderImpl(node: dict)
        let fetcher = TestStoreFetcher()
        try header.storeRecursively(storer: fetcher)

        let unresolved = HeaderImpl<DictType>(rawCID: header.rawCID)
        let resolved = try await unresolved.resolve(
            paths: [["F"]: .targeted],
            fetcher: fetcher
        )

        let foo = try resolved.node!.get(key: "Foo")
        #expect(foo != nil)
        #expect(foo!.rawCID == HeaderImpl(node: TestScalar(val: 1)).rawCID)

        #expect(throws: TransformErrors.self) {
            _ = try resolved.node!.get(key: "Bar")
        }
    }

    @Test("List resolution resolves dictionary structure but not nested addresses")
    func testListResolutionDepth() async throws {
        typealias InnerDict = MerkleDictionaryImpl<HeaderImpl<TestScalar>>
        typealias OuterDict = MerkleDictionaryImpl<HeaderImpl<InnerDict>>

        let inner = try InnerDict(children: [:], count: 0)
            .inserting(key: "x", value: HeaderImpl(node: TestScalar(val: 10)))
            .inserting(key: "y", value: HeaderImpl(node: TestScalar(val: 20)))
        let innerH = HeaderImpl(node: inner)

        let outer = try OuterDict(children: [:], count: 0)
            .inserting(key: "Group", value: innerH)

        let outerH = HeaderImpl(node: outer)
        let fetcher = TestStoreFetcher()
        try outerH.storeRecursively(storer: fetcher)

        let unresolved = HeaderImpl<OuterDict>(rawCID: outerH.rawCID)
        let resolved = try await unresolved.resolve(
            paths: [["G"]: .list],
            fetcher: fetcher
        )

        #expect(resolved.node != nil)
        #expect(resolved.node!.count == 1)
        let group = try resolved.node!.get(key: "Group")
        #expect(group != nil)
        #expect(group!.node == nil)
    }

    // MARK: - Transform then verify content addressability

    @Test("Transform produces deterministic CIDs regardless of operation order")
    func testTransformDeterministicCIDs() throws {
        let dict = try MerkleDictionaryImpl<String>(children: [:], count: 0)
            .inserting(key: "a", value: "1")
            .inserting(key: "b", value: "2")
            .inserting(key: "c", value: "3")

        var transforms1 = ArrayTrie<Transform>()
        transforms1.set(["a"], value: .update("10"))
        transforms1.set(["b"], value: .delete)
        transforms1.set(["d"], value: .insert("4"))

        let result1 = try dict.transform(transforms: transforms1)!
        let header1 = HeaderImpl(node: result1)

        let manualResult = try dict
            .mutating(key: ArraySlice("a"), value: "10")
            .deleting(key: "b")
            .inserting(key: "d", value: "4")
        let header2 = HeaderImpl(node: manualResult)

        #expect(header1.rawCID == header2.rawCID)
    }

    @Test("Repeated transform + CID verification cycle")
    func testRepeatedTransformCIDCycle() throws {
        var dict = try MerkleDictionaryImpl<String>(children: [:], count: 0)
            .inserting(key: "counter", value: "0")
            .inserting(key: "log", value: "initial")

        var previousCIDs: [String] = []

        for i in 1...10 {
            var transforms = ArrayTrie<Transform>()
            transforms.set(["counter"], value: .update("\(i)"))
            transforms.set(["log"], value: .update("step_\(i)"))
            if i % 3 == 0 {
                transforms.set(["marker_\(i)"], value: .insert("milestone"))
            }
            dict = try dict.transform(transforms: transforms)!

            let cid = HeaderImpl(node: dict).rawCID
            #expect(!previousCIDs.contains(cid))
            previousCIDs.append(cid)
        }

        #expect(try dict.get(key: "counter") == "10")
        #expect(try dict.get(key: "log") == "step_10")
        #expect(try dict.get(key: "marker_3") == "milestone")
        #expect(try dict.get(key: "marker_6") == "milestone")
        #expect(try dict.get(key: "marker_9") == "milestone")
    }

    // MARK: - Radix trie splitting edge cases

    @Test("Keys that force deep radix splitting and collapsing")
    func testDeepRadixSplittingAndCollapsing() throws {
        var dict = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dict = try dict.inserting(key: "abcdefghij", value: "long1")
        dict = try dict.inserting(key: "abcdefghik", value: "long2")
        dict = try dict.inserting(key: "abcdefgxyz", value: "mid_split")
        dict = try dict.inserting(key: "abcXYZ", value: "early_split")
        dict = try dict.inserting(key: "aZZZ", value: "very_early_split")

        #expect(dict.count == 5)
        #expect(try dict.get(key: "abcdefghij") == "long1")
        #expect(try dict.get(key: "abcdefghik") == "long2")
        #expect(try dict.get(key: "abcdefgxyz") == "mid_split")
        #expect(try dict.get(key: "abcXYZ") == "early_split")
        #expect(try dict.get(key: "aZZZ") == "very_early_split")

        let deleted = try dict
            .deleting(key: "abcdefghik")
            .deleting(key: "abcdefgxyz")
        #expect(deleted.count == 3)
        #expect(try deleted.get(key: "abcdefghij") == "long1")
        #expect(try deleted.get(key: "abcXYZ") == "early_split")

        var transforms = ArrayTrie<Transform>()
        transforms.set(["abcdefghij"], value: .update("updated_long"))
        transforms.set(["abcMNO"], value: .insert("new_mid"))
        let result = try deleted.transform(transforms: transforms)!
        #expect(result.count == 4)
        #expect(try result.get(key: "abcdefghij") == "updated_long")
        #expect(try result.get(key: "abcMNO") == "new_mid")
        #expect(try result.get(key: "abcXYZ") == "early_split")
        #expect(try result.get(key: "aZZZ") == "very_early_split")
    }

    @Test("Single-character keys and two-character keys coexist")
    func testShortKeyCoexistence() throws {
        var dict = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dict = try dict.inserting(key: "a", value: "just_a")
        dict = try dict.inserting(key: "ab", value: "a_then_b")
        dict = try dict.inserting(key: "abc", value: "a_then_b_then_c")
        dict = try dict.inserting(key: "b", value: "just_b")
        dict = try dict.inserting(key: "ba", value: "b_then_a")

        #expect(dict.count == 5)
        #expect(try dict.get(key: "a") == "just_a")
        #expect(try dict.get(key: "ab") == "a_then_b")
        #expect(try dict.get(key: "abc") == "a_then_b_then_c")
        #expect(try dict.get(key: "b") == "just_b")
        #expect(try dict.get(key: "ba") == "b_then_a")

        let deleted = try dict.deleting(key: "ab")
        #expect(deleted.count == 4)
        #expect(try deleted.get(key: "a") == "just_a")
        #expect(try deleted.get(key: "ab") == nil)
        #expect(try deleted.get(key: "abc") == "a_then_b_then_c")
    }

    @Test("Transform on keys that are strict prefixes of each other")
    func testTransformOnPrefixKeys() throws {
        var dict = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dict = try dict.inserting(key: "pre", value: "v1")
        dict = try dict.inserting(key: "prefix", value: "v2")
        dict = try dict.inserting(key: "prefixed", value: "v3")
        dict = try dict.inserting(key: "premium", value: "v4")

        var transforms = ArrayTrie<Transform>()
        transforms.set(["pre"], value: .update("updated_v1"))
        transforms.set(["prefix"], value: .delete)
        transforms.set(["prefixed"], value: .update("updated_v3"))
        transforms.set(["premium"], value: .update("updated_v4"))

        let result = try dict.transform(transforms: transforms)!
        #expect(result.count == 3)
        #expect(try result.get(key: "pre") == "updated_v1")
        #expect(try result.get(key: "prefix") == nil)
        #expect(try result.get(key: "prefixed") == "updated_v3")
        #expect(try result.get(key: "premium") == "updated_v4")
    }

    // MARK: - Large-scale operations

    @Test("100-key dictionary: bulk insert, transform, verify allKeys")
    func test100KeyBulkOperations() throws {
        var dict = MerkleDictionaryImpl<String>(children: [:], count: 0)
        for i in 0..<100 {
            dict = try dict.inserting(key: "key_\(String(format: "%03d", i))", value: "val_\(i)")
        }
        #expect(dict.count == 100)

        let allKeys = try dict.allKeys()
        #expect(allKeys.count == 100)
        for i in 0..<100 {
            #expect(allKeys.contains("key_\(String(format: "%03d", i))"))
        }

        var transforms = ArrayTrie<Transform>()
        for i in stride(from: 0, to: 100, by: 2) {
            transforms.set(["key_\(String(format: "%03d", i))"], value: .update("updated_\(i)"))
        }
        for i in stride(from: 1, to: 50, by: 2) {
            transforms.set(["key_\(String(format: "%03d", i))"], value: .delete)
        }
        for i in 100..<120 {
            transforms.set(["key_\(String(format: "%03d", i))"], value: .insert("new_\(i)"))
        }

        let result = try dict.transform(transforms: transforms)!
        let expectedCount = 100 - 25 + 20
        #expect(result.count == expectedCount)

        #expect(try result.get(key: "key_000") == "updated_0")
        #expect(try result.get(key: "key_001") == nil)
        #expect(try result.get(key: "key_050") == "updated_50")
        #expect(try result.get(key: "key_051") == "val_51")
        #expect(try result.get(key: "key_100") == "new_100")
        #expect(try result.get(key: "key_119") == "new_119")
    }

    @Test("100-key dictionary: allKeysAndValues round-trip through store/resolve")
    func test100KeyStoreResolveAllKeysAndValues() async throws {
        var dict = MerkleDictionaryImpl<String>(children: [:], count: 0)
        for i in 0..<100 {
            dict = try dict.inserting(key: "k\(i)", value: "v\(i)")
        }

        let header = HeaderImpl(node: dict)
        let fetcher = TestStoreFetcher()
        try header.storeRecursively(storer: fetcher)

        let unresolved = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: header.rawCID)
        let resolved = try await unresolved.resolveRecursive(fetcher: fetcher)

        #expect(resolved.rawCID == header.rawCID)
        let kvPairs = try resolved.node!.allKeysAndValues()
        #expect(kvPairs.count == 100)
        for i in 0..<100 {
            #expect(kvPairs["k\(i)"] == "v\(i)")
        }
    }

    // MARK: - Nested transforms through headers

    @Test("Transform nested dictionary via header with multi-level path")
    func testNestedDictTransformViaHeader() async throws {
        typealias Inner = MerkleDictionaryImpl<String>
        typealias Outer = MerkleDictionaryImpl<HeaderImpl<Inner>>

        let inner = try Inner(children: [:], count: 0)
            .inserting(key: "name", value: "Alice")
            .inserting(key: "role", value: "engineer")
        let innerHeader = HeaderImpl(node: inner)

        let outer = try Outer(children: [:], count: 0)
            .inserting(key: "user1", value: innerHeader)

        let outerHeader = HeaderImpl(node: outer)

        let updatedInner = try Inner(children: [:], count: 0)
            .inserting(key: "name", value: "Bob")
            .inserting(key: "role", value: "manager")
        let updatedInnerHeader = HeaderImpl(node: updatedInner)

        var transforms = ArrayTrie<Transform>()
        transforms.set(["user1"], value: .update(updatedInnerHeader.description))

        let result = try outerHeader.transform(transforms: transforms)!
        #expect(result.rawCID != outerHeader.rawCID)

        let fetcher = TestStoreFetcher()
        try updatedInnerHeader.storeRecursively(storer: fetcher)
        try result.storeRecursively(storer: fetcher)
        let resolved = try await HeaderImpl<Outer>(rawCID: result.rawCID).resolveRecursive(fetcher: fetcher)
        let user1 = try resolved.node!.get(key: "user1")!
        #expect(try user1.node!.get(key: "name") == "Bob")
        #expect(try user1.node!.get(key: "role") == "manager")
    }

    @Test("Transform nested dict: insert new inner dict alongside existing")
    func testTransformInsertNewInnerDict() async throws {
        typealias Inner = MerkleDictionaryImpl<String>
        typealias Outer = MerkleDictionaryImpl<HeaderImpl<Inner>>

        let inner1 = try Inner(children: [:], count: 0)
            .inserting(key: "a", value: "1")
        let h1 = HeaderImpl(node: inner1)

        let outer = try Outer(children: [:], count: 0)
            .inserting(key: "existing", value: h1)

        let inner2 = try Inner(children: [:], count: 0)
            .inserting(key: "b", value: "2")
            .inserting(key: "c", value: "3")
        let h2 = HeaderImpl(node: inner2)

        var transforms = ArrayTrie<Transform>()
        transforms.set(["added"], value: .insert(h2.description))

        let result = try outer.transform(transforms: transforms)!
        #expect(result.count == 2)

        let fetcher = TestStoreFetcher()
        try h1.storeRecursively(storer: fetcher)
        try h2.storeRecursively(storer: fetcher)
        let resultHeader = HeaderImpl(node: result)
        try resultHeader.storeRecursively(storer: fetcher)
        let resolved = try await HeaderImpl<Outer>(rawCID: resultHeader.rawCID)
            .resolveRecursive(fetcher: fetcher)

        let existingVal = try resolved.node!.get(key: "existing")!
        #expect(try existingVal.node!.get(key: "a") == "1")

        let addedVal = try resolved.node!.get(key: "added")!
        #expect(try addedVal.node!.get(key: "b") == "2")
        #expect(try addedVal.node!.get(key: "c") == "3")
    }

    // MARK: - Proof operations on complex structures

    @Test("Proof on nested dictionary: existence at multiple levels")
    func testProofNestedExistence() async throws {
        typealias Inner = MerkleDictionaryImpl<String>
        typealias Outer = MerkleDictionaryImpl<HeaderImpl<Inner>>

        let inner = try Inner(children: [:], count: 0)
            .inserting(key: "deepKey", value: "deepVal")
            .inserting(key: "otherKey", value: "otherVal")
        let innerH = HeaderImpl(node: inner)

        let outer = try Outer(children: [:], count: 0)
            .inserting(key: "container", value: innerH)
            .inserting(key: "sibling", value: HeaderImpl(node:
                try Inner(children: [:], count: 0).inserting(key: "z", value: "26")
            ))

        let outerH = HeaderImpl(node: outer)
        let fetcher = TestStoreFetcher()
        try outerH.storeRecursively(storer: fetcher)

        let unresolved = HeaderImpl<Outer>(rawCID: outerH.rawCID)
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["container"], value: .existence)

        let proofResult = try await unresolved.proof(paths: paths, fetcher: fetcher)
        #expect(proofResult.rawCID == outerH.rawCID)
        #expect(proofResult.node != nil)
        let container = try proofResult.node!.get(key: "container")
        #expect(container != nil)
    }

    @Test("Mutation proof then mutate preserves content addressability")
    func testMutationProofThenMutate() async throws {
        let dict = try MerkleDictionaryImpl<String>(children: [:], count: 0)
            .inserting(key: "mutableKey", value: "original")
            .inserting(key: "immutableKey", value: "fixed")

        let header = HeaderImpl(node: dict)
        let fetcher = TestStoreFetcher()
        try header.storeRecursively(storer: fetcher)

        let unresolved = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: header.rawCID)
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["mutableKey"], value: .mutation)

        let proofResult = try await unresolved.proof(paths: paths, fetcher: fetcher)
        let mutated = try proofResult.node!.mutating(key: "mutableKey", value: "changed")

        #expect(try mutated.get(key: "mutableKey") == "changed")
        #expect(mutated.count == 2)

        let mutatedHeader = HeaderImpl(node: mutated)
        #expect(mutatedHeader.rawCID != header.rawCID)
    }

    @Test("Deletion proof then delete then verify CID")
    func testDeletionProofFullCycle() async throws {
        let dict = try MerkleDictionaryImpl<String>(children: [:], count: 0)
            .inserting(key: "keep", value: "kept")
            .inserting(key: "remove", value: "doomed")

        let header = HeaderImpl(node: dict)
        let fetcher = TestStoreFetcher()
        try header.storeRecursively(storer: fetcher)

        let unresolved = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: header.rawCID)
        var paths = ArrayTrie<SparseMerkleProof>()
        paths.set(["remove"], value: .deletion)

        let proofResult = try await unresolved.proof(paths: paths, fetcher: fetcher)
        let afterDelete = try proofResult.node!.deleting(key: "remove")
        #expect(afterDelete.count == 1)

        let sameDict = try MerkleDictionaryImpl<String>(children: [:], count: 0)
            .inserting(key: "keep", value: "kept")
        let sameHeader = HeaderImpl(node: sameDict)
        #expect(HeaderImpl(node: afterDelete).rawCID == sameHeader.rawCID)
    }

    // MARK: - Concurrent resolution stress tests

    @Test("Concurrent resolution of many independent paths")
    func testConcurrentResolutionManyPaths() async throws {
        typealias DictType = MerkleDictionaryImpl<HeaderImpl<TestScalar>>

        var dict = DictType(children: [:], count: 0)
        for i in 0..<26 {
            let letter = String(Character(UnicodeScalar(65 + i)!))
            let key = "\(letter)item\(i)"
            dict = try dict.inserting(key: key, value: HeaderImpl(node: TestScalar(val: i)))
        }
        #expect(dict.count == 26)

        let header = HeaderImpl(node: dict)
        let fetcher = TestStoreFetcher()
        try header.storeRecursively(storer: fetcher)

        let unresolved = HeaderImpl<DictType>(rawCID: header.rawCID)
        let resolved = try await unresolved.resolveRecursive(fetcher: fetcher)

        #expect(resolved.rawCID == header.rawCID)
        #expect(resolved.node!.count == 26)

        for i in 0..<26 {
            let letter = String(Character(UnicodeScalar(65 + i)!))
            let key = "\(letter)item\(i)"
            let val = try resolved.node!.get(key: key)
            #expect(val?.node?.val == i)
        }
    }

    @Test("Resolve, transform, re-store, re-resolve cycle")
    func testResolveTransformReStoreReResolveCycle() async throws {
        let dict = try MerkleDictionaryImpl<String>(children: [:], count: 0)
            .inserting(key: "version", value: "1")
            .inserting(key: "data", value: "initial")

        let header = HeaderImpl(node: dict)
        let fetcher = TestStoreFetcher()
        try header.storeRecursively(storer: fetcher)

        let unresolved1 = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: header.rawCID)
        let resolved1 = try await unresolved1.resolveRecursive(fetcher: fetcher)

        var transforms = ArrayTrie<Transform>()
        transforms.set(["version"], value: .update("2"))
        transforms.set(["data"], value: .update("modified"))
        transforms.set(["newField"], value: .insert("added"))

        let transformed = try resolved1.node!.transform(transforms: transforms)!
        let transformedHeader = HeaderImpl(node: transformed)
        try transformedHeader.storeRecursively(storer: fetcher)

        let unresolved2 = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: transformedHeader.rawCID)
        let resolved2 = try await unresolved2.resolveRecursive(fetcher: fetcher)

        #expect(resolved2.rawCID == transformedHeader.rawCID)
        #expect(resolved2.rawCID != header.rawCID)
        #expect(try resolved2.node!.get(key: "version") == "2")
        #expect(try resolved2.node!.get(key: "data") == "modified")
        #expect(try resolved2.node!.get(key: "newField") == "added")
        #expect(resolved2.node!.count == 3)
    }

    // MARK: - Content addressable structural sharing

    @Test("Two dictionaries sharing a subtree have same CID for shared part")
    func testStructuralSharingCIDs() throws {
        typealias Inner = MerkleDictionaryImpl<String>
        typealias Outer = MerkleDictionaryImpl<HeaderImpl<Inner>>

        let shared = try Inner(children: [:], count: 0)
            .inserting(key: "shared1", value: "s1")
            .inserting(key: "shared2", value: "s2")
        let sharedHeader = HeaderImpl(node: shared)

        let unique1 = try Inner(children: [:], count: 0)
            .inserting(key: "unique", value: "u1")
        let unique2 = try Inner(children: [:], count: 0)
            .inserting(key: "unique", value: "u2")

        let outer1 = try Outer(children: [:], count: 0)
            .inserting(key: "common", value: sharedHeader)
            .inserting(key: "specific", value: HeaderImpl(node: unique1))
        let outer2 = try Outer(children: [:], count: 0)
            .inserting(key: "common", value: sharedHeader)
            .inserting(key: "specific", value: HeaderImpl(node: unique2))

        let h1 = HeaderImpl(node: outer1)
        let h2 = HeaderImpl(node: outer2)

        #expect(h1.rawCID != h2.rawCID)

        let common1 = try outer1.get(key: "common")!
        let common2 = try outer2.get(key: "common")!
        #expect(common1.rawCID == common2.rawCID)
        #expect(common1.rawCID == sharedHeader.rawCID)
    }

    @Test("Store shared subtree once, resolve from two parents")
    func testSharedSubtreeStoreOnceResolveTwice() async throws {
        typealias Inner = MerkleDictionaryImpl<String>
        typealias Outer = MerkleDictionaryImpl<HeaderImpl<Inner>>

        let shared = try Inner(children: [:], count: 0)
            .inserting(key: "data", value: "shared_data")
        let sharedH = HeaderImpl(node: shared)

        let parent1 = try Outer(children: [:], count: 0)
            .inserting(key: "ref", value: sharedH)
        let parent2 = try Outer(children: [:], count: 0)
            .inserting(key: "ref", value: sharedH)

        let fetcher = TestStoreFetcher()
        let p1h = HeaderImpl(node: parent1)
        let p2h = HeaderImpl(node: parent2)
        try p1h.storeRecursively(storer: fetcher)

        let r1 = try await HeaderImpl<Outer>(rawCID: p1h.rawCID).resolveRecursive(fetcher: fetcher)
        let r2 = try await HeaderImpl<Outer>(rawCID: p2h.rawCID).resolveRecursive(fetcher: fetcher)

        let val1 = try r1.node!.get(key: "ref")!.node!.get(key: "data")
        let val2 = try r2.node!.get(key: "ref")!.node!.get(key: "data")
        #expect(val1 == "shared_data")
        #expect(val2 == "shared_data")
    }

    // MARK: - Edge case: empty and minimal structures

    @Test("Empty dictionary round-trip through store/resolve")
    func testEmptyDictRoundTrip() async throws {
        let dict = MerkleDictionaryImpl<String>(children: [:], count: 0)
        let header = HeaderImpl(node: dict)
        let fetcher = TestStoreFetcher()
        try header.storeRecursively(storer: fetcher)

        let resolved = try await HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: header.rawCID)
            .resolveRecursive(fetcher: fetcher)
        #expect(resolved.node!.count == 0)
        #expect(resolved.rawCID == header.rawCID)
    }

    @Test("Single-entry dictionary survives full lifecycle")
    func testSingleEntryFullLifecycle() async throws {
        let dict = try MerkleDictionaryImpl<String>(children: [:], count: 0)
            .inserting(key: "only", value: "one")
        let header = HeaderImpl(node: dict)
        let fetcher = TestStoreFetcher()
        try header.storeRecursively(storer: fetcher)

        let resolved = try await HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: header.rawCID)
            .resolveRecursive(fetcher: fetcher)
        #expect(try resolved.node!.get(key: "only") == "one")

        var transforms = ArrayTrie<Transform>()
        transforms.set(["only"], value: .update("updated"))
        let transformed = try resolved.node!.transform(transforms: transforms)!

        #expect(try transformed.get(key: "only") == "updated")
        #expect(transformed.count == 1)

        let tHeader = HeaderImpl(node: transformed)
        #expect(tHeader.rawCID != header.rawCID)

        try tHeader.storeRecursively(storer: fetcher)
        let reresolved = try await HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: tHeader.rawCID)
            .resolveRecursive(fetcher: fetcher)
        #expect(try reresolved.node!.get(key: "only") == "updated")
    }

    @Test("Delete all entries via transform results in empty dictionary")
    func testDeleteAllViaTransform() throws {
        let dict = try MerkleDictionaryImpl<String>(children: [:], count: 0)
            .inserting(key: "a", value: "1")
            .inserting(key: "b", value: "2")
            .inserting(key: "c", value: "3")

        var transforms = ArrayTrie<Transform>()
        transforms.set(["a"], value: .delete)
        transforms.set(["b"], value: .delete)
        transforms.set(["c"], value: .delete)

        let result = try dict.transform(transforms: transforms)!
        #expect(result.count == 0)
        #expect(try result.get(key: "a") == nil)
        #expect(try result.get(key: "b") == nil)
        #expect(try result.get(key: "c") == nil)

        let emptyDict = MerkleDictionaryImpl<String>(children: [:], count: 0)
        #expect(HeaderImpl(node: result).rawCID == HeaderImpl(node: emptyDict).rawCID)
    }

    @Test("Insert into empty dict via transform then delete all back to empty")
    func testInsertThenDeleteBackToEmpty() throws {
        let empty = MerkleDictionaryImpl<String>(children: [:], count: 0)
        let emptyCID = HeaderImpl(node: empty).rawCID

        var inserts = ArrayTrie<Transform>()
        inserts.set(["x"], value: .insert("1"))
        inserts.set(["y"], value: .insert("2"))
        let withEntries = try empty.transform(transforms: inserts)!
        #expect(withEntries.count == 2)

        var deletes = ArrayTrie<Transform>()
        deletes.set(["x"], value: .delete)
        deletes.set(["y"], value: .delete)
        let backToEmpty = try withEntries.transform(transforms: deletes)!
        #expect(backToEmpty.count == 0)
        #expect(HeaderImpl(node: backToEmpty).rawCID == emptyCID)
    }

    // MARK: - Scalar in nested structures

    @Test("Scalar values in nested dict: full lifecycle with store/resolve/transform")
    func testScalarNestedLifecycle() async throws {
        typealias ScalarDict = MerkleDictionaryImpl<HeaderImpl<TestScalar>>

        var dict = ScalarDict(children: [:], count: 0)
        for i in 1...20 {
            dict = try dict.inserting(
                key: "item_\(String(format: "%02d", i))",
                value: HeaderImpl(node: TestScalar(val: i * 10))
            )
        }
        #expect(dict.count == 20)

        let header = HeaderImpl(node: dict)
        let fetcher = TestStoreFetcher()
        try header.storeRecursively(storer: fetcher)

        let resolved = try await HeaderImpl<ScalarDict>(rawCID: header.rawCID)
            .resolveRecursive(fetcher: fetcher)

        for i in 1...20 {
            let key = "item_\(String(format: "%02d", i))"
            let val = try resolved.node!.get(key: key)
            #expect(val?.node?.val == i * 10)
        }

        let newScalar = TestScalar(val: 999)
        let newHeader = HeaderImpl(node: newScalar)

        var transforms = ArrayTrie<Transform>()
        transforms.set(["item_05"], value: .update(newHeader.description))
        transforms.set(["item_10"], value: .delete)
        transforms.set(["item_21"], value: .insert(HeaderImpl(node: TestScalar(val: 210)).description))

        let transformed = try resolved.node!.transform(transforms: transforms)!
        #expect(transformed.count == 20)

        let item05 = try transformed.get(key: "item_05")
        #expect(item05 != nil)

        #expect(try transformed.get(key: "item_10") == nil)

        let item15 = try transformed.get(key: "item_15")
        #expect(item15?.node?.val == 150)
    }

    // MARK: - CID determinism with different construction paths

    @Test("Same logical structure built in different order produces same CID")
    func testInsertionOrderIndependentCID() throws {
        let dict1 = try MerkleDictionaryImpl<String>(children: [:], count: 0)
            .inserting(key: "alpha", value: "1")
            .inserting(key: "beta", value: "2")
            .inserting(key: "gamma", value: "3")

        let dict2 = try MerkleDictionaryImpl<String>(children: [:], count: 0)
            .inserting(key: "gamma", value: "3")
            .inserting(key: "alpha", value: "1")
            .inserting(key: "beta", value: "2")

        let dict3 = try MerkleDictionaryImpl<String>(children: [:], count: 0)
            .inserting(key: "beta", value: "2")
            .inserting(key: "gamma", value: "3")
            .inserting(key: "alpha", value: "1")

        let h1 = HeaderImpl(node: dict1)
        let h2 = HeaderImpl(node: dict2)
        let h3 = HeaderImpl(node: dict3)

        #expect(h1.rawCID == h2.rawCID)
        #expect(h2.rawCID == h3.rawCID)
    }

    @Test("Transform result matches manual construction CID")
    func testTransformMatchesManualCID() throws {
        let dict = try MerkleDictionaryImpl<String>(children: [:], count: 0)
            .inserting(key: "a", value: "old")

        var transforms = ArrayTrie<Transform>()
        transforms.set(["a"], value: .update("new"))
        transforms.set(["b"], value: .insert("added"))

        let transformResult = try dict.transform(transforms: transforms)!
        let manualResult = try MerkleDictionaryImpl<String>(children: [:], count: 0)
            .inserting(key: "a", value: "new")
            .inserting(key: "b", value: "added")

        #expect(HeaderImpl(node: transformResult).rawCID == HeaderImpl(node: manualResult).rawCID)
    }
}
