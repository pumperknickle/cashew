import Testing
import Foundation
import ArrayTrie
@testable import cashew

@Suite("Header Transform Tests")
struct HeaderTransformTests {
    
    // MARK: - Dictionary Interface Transform Tests
    
    @Test("Dictionary interface - minimal test")
    func testDictionaryInterfaceMinimal() throws {
        let dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        let header = HeaderImpl(node: dictionary)
        
        let transforms: [[String]: Transform] = [:]
        _ = try header.transform(transforms: transforms)
    }
    
    @Test("Dictionary interface - single key insert test")
    func testDictionaryInterfaceSingleKeyInsert() throws {
        let dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        let header = HeaderImpl(node: dictionary)
        
        // Test the dictionary transform directly to debug
        var trieTransforms = ArrayTrie<Transform>()
        trieTransforms.set(["newkey"], value: .insert("newvalue"))
        let dictResult = try dictionary.transform(transforms: trieTransforms)!
        #expect(try dictResult.get(key: "newkey") == "newvalue")
        
        // Now test header transform with ArrayTrie
        let trieResult: HeaderImpl<MerkleDictionaryImpl<String>> = try header.transform(transforms: trieTransforms)!
        #expect(try trieResult.node?.get(key: "newkey") == "newvalue")
        
        // Test dictionary interface
        let transforms: [[String]: Transform] = [
            ["newkey"]: .insert("newvalue")
        ]
        let result = try header.transform(transforms: transforms)
        #expect(try result?.node?.get(key: "newkey") == "newvalue")
    }
    
    @Test("Dictionary interface - single insert transform")
    func testDictionaryInterfaceSingleInsert() throws {
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "existing", value: "value")
        let header = HeaderImpl(node: dictionary)
        
        let transforms: [[String]: Transform] = [
            ["newkey"]: .insert("newvalue")
        ]
        
        let result = try header.transform(transforms: transforms)!
        #expect(try result.node?.get(key: "newkey") == "newvalue")
        #expect(try result.node?.get(key: "existing") == "value")
        #expect(result.node?.count == 2)
    }
    
    @Test("Dictionary interface - single update transform")
    func testDictionaryInterfaceSingleUpdate() throws {
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "existing", value: "oldvalue")
        let header = HeaderImpl(node: dictionary)
        
        let transforms: [[String]: Transform] = [
            ["existing"]: .update("newvalue")
        ]
        
        let result = try header.transform(transforms: transforms)!
        #expect(try result.node?.get(key: "existing") == "newvalue")
        #expect(result.node?.count == 1)
    }
    
    @Test("Dictionary interface - single delete transform")
    func testDictionaryInterfaceSingleDelete() throws {
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "toDelete", value: "value")
        dictionary = try dictionary.inserting(key: "toKeep", value: "keepValue")
        let header = HeaderImpl(node: dictionary)
        
        let transforms: [[String]: Transform] = [
            ["toDelete"]: .delete
        ]
        
        let result = try header.transform(transforms: transforms)!
        #expect(try result.node?.get(key: "toDelete") == nil)
        #expect(try result.node?.get(key: "toKeep") == "keepValue")
        #expect(result.node?.count == 1)
    }
    
    @Test("Dictionary interface - multiple transforms")
    func testDictionaryInterfaceMultipleTransforms() throws {
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "update", value: "oldvalue")
        dictionary = try dictionary.inserting(key: "delete", value: "deletevalue")
        let header = HeaderImpl(node: dictionary)
        
        let transforms: [[String]: Transform] = [
            ["update"]: .update("newvalue"),
            ["delete"]: .delete,
            ["insert"]: .insert("insertvalue")
        ]
        
        let result = try header.transform(transforms: transforms)!
        #expect(try result.node?.get(key: "update") == "newvalue")
        #expect(try result.node?.get(key: "delete") == nil)
        #expect(try result.node?.get(key: "insert") == "insertvalue")
        #expect(result.node?.count == 2)
    }
    
    @Test("Dictionary interface - empty transforms preserves data")
    func testDictionaryInterfaceEmptyTransforms() throws {
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "key1", value: "value1")
        dictionary = try dictionary.inserting(key: "key2", value: "value2")
        let header = HeaderImpl(node: dictionary)
        
        let transforms: [[String]: Transform] = [:]
        
        let result = try header.transform(transforms: transforms)!
        #expect(try result.node?.get(key: "key1") == "value1")
        #expect(try result.node?.get(key: "key2") == "value2")
        #expect(result.node?.count == 2)
    }
    
    // MARK: - Error Cases
    
    @Test("Dictionary interface - throws when node not available")
    func testDictionaryInterfaceThrowsWhenNodeNotAvailable() {
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: "test-cid")
        
        let transforms: [[String]: Transform] = [
            ["key"]: .insert("value")
        ]
        
        #expect(throws: DataErrors.self) {
            try header.transform(transforms: transforms)
        }
    }
    
    @Test("Dictionary interface - handles failed node transform")
    func testDictionaryInterfaceHandlesFailedNodeTransform() throws {
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "key1", value: "value1")
        let header = HeaderImpl(node: dictionary)
        
        // Create a transform that would cause the node transform to fail
        // Updating a non-existent key should throw a TransformErrors.transformFailed
        let transforms: [[String]: Transform] = [
            ["nonexistent"]: .update("value") // Updating non-existent key should fail
        ]
        
        // Since the signature changed from Self? to Self, failed transforms now throw
        #expect(throws: TransformErrors.self) {
            try header.transform(transforms: transforms)
        }
    }
    
    // MARK: - Equivalence Tests Between Dictionary and ArrayTrie Interfaces
    
    @Test("Dictionary and ArrayTrie interfaces produce equivalent results - insert")
    func testInterfaceEquivalenceInsert() throws {
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "existing", value: "value")
        
        let headerForDict = HeaderImpl(node: dictionary)
        let headerForTrie = HeaderImpl(node: dictionary)
        
        // Dictionary interface
        let dictTransforms: [[String]: Transform] = [
            ["newkey"]: .insert("newvalue")
        ]
        let dictResult = try headerForDict.transform(transforms: dictTransforms)!
        
        // ArrayTrie interface
        var trieTransforms = ArrayTrie<Transform>()
        trieTransforms.set(["newkey"], value: .insert("newvalue"))
        let trieResult: HeaderImpl<MerkleDictionaryImpl<String>> = try headerForTrie.transform(transforms: trieTransforms)!
        
        let dictNewKey = try dictResult.node?.get(key: "newkey")
        let trieNewKey = try trieResult.node?.get(key: "newkey")
        #expect(dictNewKey == trieNewKey)
        let dictExisting = try dictResult.node?.get(key: "existing")
        let trieExisting = try trieResult.node?.get(key: "existing")
        #expect(dictExisting == trieExisting)
        #expect(dictResult.node?.count == trieResult.node?.count)
    }
    
    @Test("Dictionary and ArrayTrie interfaces produce equivalent results - update")
    func testInterfaceEquivalenceUpdate() throws {
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "update", value: "oldvalue")
        
        let headerForDict = HeaderImpl(node: dictionary)
        let headerForTrie = HeaderImpl(node: dictionary)
        
        // Dictionary interface
        let dictTransforms: [[String]: Transform] = [
            ["update"]: .update("newvalue")
        ]
        let dictResult = try headerForDict.transform(transforms: dictTransforms)!
        
        // ArrayTrie interface
        var trieTransforms = ArrayTrie<Transform>()
        trieTransforms.set(["update"], value: .update("newvalue"))
        let trieResult: HeaderImpl<MerkleDictionaryImpl<String>> = try headerForTrie.transform(transforms: trieTransforms)!
        
        let dictUpdate = try dictResult.node?.get(key: "update")
        let trieUpdate = try trieResult.node?.get(key: "update")
        #expect(dictUpdate == trieUpdate)
        #expect(dictResult.node?.count == trieResult.node?.count)
    }
    
    @Test("Dictionary and ArrayTrie interfaces produce equivalent results - delete")
    func testInterfaceEquivalenceDelete() throws {
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "delete", value: "value")
        dictionary = try dictionary.inserting(key: "keep", value: "keepvalue")
        
        let headerForDict = HeaderImpl(node: dictionary)
        let headerForTrie = HeaderImpl(node: dictionary)
        
        // Dictionary interface
        let dictTransforms: [[String]: Transform] = [
            ["delete"]: .delete
        ]
        let dictResult = try headerForDict.transform(transforms: dictTransforms)!
        
        // ArrayTrie interface
        var trieTransforms = ArrayTrie<Transform>()
        trieTransforms.set(["delete"], value: .delete)
        let trieResult: HeaderImpl<MerkleDictionaryImpl<String>> = try headerForTrie.transform(transforms: trieTransforms)!
        
        let dictDelete = try dictResult.node?.get(key: "delete")
        let trieDelete = try trieResult.node?.get(key: "delete")
        #expect(dictDelete == trieDelete)
        let dictKeep = try dictResult.node?.get(key: "keep")
        let trieKeep = try trieResult.node?.get(key: "keep")
        #expect(dictKeep == trieKeep)
        #expect(dictResult.node?.count == trieResult.node?.count)
    }
    
    @Test("Dictionary and ArrayTrie interfaces produce equivalent results - complex")
    func testInterfaceEquivalenceComplex() throws {
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "update", value: "oldvalue")
        dictionary = try dictionary.inserting(key: "delete", value: "deletevalue")
        dictionary = try dictionary.inserting(key: "keep", value: "keepvalue")
        
        let headerForDict = HeaderImpl(node: dictionary)
        let headerForTrie = HeaderImpl(node: dictionary)
        
        // Dictionary interface
        let dictTransforms: [[String]: Transform] = [
            ["update"]: .update("newvalue"),
            ["delete"]: .delete,
            ["insert"]: .insert("insertvalue")
        ]
        let dictResult = try headerForDict.transform(transforms: dictTransforms)!
        
        // ArrayTrie interface
        var trieTransforms = ArrayTrie<Transform>()
        trieTransforms.set(["update"], value: .update("newvalue"))
        trieTransforms.set(["delete"], value: .delete)
        trieTransforms.set(["insert"], value: .insert("insertvalue"))
        let trieResult: HeaderImpl<MerkleDictionaryImpl<String>> = try headerForTrie.transform(transforms: trieTransforms)!
        
        let dictUpdate = try dictResult.node?.get(key: "update")
        let trieUpdate = try trieResult.node?.get(key: "update")
        #expect(dictUpdate == trieUpdate)
        let dictDelete = try dictResult.node?.get(key: "delete")
        let trieDelete = try trieResult.node?.get(key: "delete")
        #expect(dictDelete == trieDelete)
        let dictInsert = try dictResult.node?.get(key: "insert")
        let trieInsert = try trieResult.node?.get(key: "insert")
        #expect(dictInsert == trieInsert)
        let dictKeep = try dictResult.node?.get(key: "keep")
        let trieKeep = try trieResult.node?.get(key: "keep")
        #expect(dictKeep == trieKeep)
        #expect(dictResult.node?.count == trieResult.node?.count)
    }
    
    // MARK: - ArrayTrie Interface Tests (for completeness)
    
    @Test("ArrayTrie interface - throws when node not available")
    func testArrayTrieInterfaceThrowsWhenNodeNotAvailable() {
        let header = HeaderImpl<MerkleDictionaryImpl<String>>(rawCID: "test-cid")
        
        var transforms = ArrayTrie<Transform>()
        transforms.set(["key"], value: .insert("value"))
        
        #expect(throws: DataErrors.self) {
            try header.transform(transforms: transforms)
        }
    }
    
    @Test("ArrayTrie interface - empty transforms returns same instance")
    func testArrayTrieInterfaceEmptyTransforms() throws {
        var dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "key1", value: "value1")
        let header = HeaderImpl(node: dictionary)
        
        let emptyTransforms = ArrayTrie<Transform>()
        let result: HeaderImpl<MerkleDictionaryImpl<String>> = try header.transform(transforms: emptyTransforms)!
        
        #expect(try result.node?.get(key: "key1") == "value1")
        #expect(result.node?.count == 1)
    }
    
    // MARK: - UInt64 Value Transform Tests
    
    @Test("MerkleDictionary with UInt64 values - insert transform")
    func testUInt64DictionaryInsertTransform() throws {
        let dictionary = MerkleDictionaryImpl<UInt64>(children: [:], count: 0)
        let header = HeaderImpl(node: dictionary)
        
        let transforms: [[String]: Transform] = [
            ["count"]: .insert("42")
        ]
        
        let result = try header.transform(transforms: transforms)!
        #expect(try result.node?.get(key: "count") == 42)
        #expect(result.node?.count == 1)
    }
    
    @Test("MerkleDictionary with UInt64 values - update transform")
    func testUInt64DictionaryUpdateTransform() throws {
        var dictionary = MerkleDictionaryImpl<UInt64>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "counter", value: 100)
        let header = HeaderImpl(node: dictionary)
        
        let transforms: [[String]: Transform] = [
            ["counter"]: .update("200")
        ]
        
        let result = try header.transform(transforms: transforms)!
        #expect(try result.node?.get(key: "counter") == 200)
        #expect(result.node?.count == 1)
    }
    
    @Test("MerkleDictionary with UInt64 values - delete transform")
    func testUInt64DictionaryDeleteTransform() throws {
        var dictionary = MerkleDictionaryImpl<UInt64>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "toDelete", value: 123)
        dictionary = try dictionary.inserting(key: "toKeep", value: 456)
        let header = HeaderImpl(node: dictionary)
        
        let transforms: [[String]: Transform] = [
            ["toDelete"]: .delete
        ]
        
        let result = try header.transform(transforms: transforms)!
        #expect(try result.node?.get(key: "toDelete") == nil)
        #expect(try result.node?.get(key: "toKeep") == 456)
        #expect(result.node?.count == 1)
    }
    
    @Test("MerkleDictionary with UInt64 values - multiple transforms")
    func testUInt64DictionaryMultipleTransforms() throws {
        var dictionary = MerkleDictionaryImpl<UInt64>(children: [:], count: 0)
        dictionary = try dictionary.inserting(key: "update", value: 10)
        dictionary = try dictionary.inserting(key: "delete", value: 20)
        let header = HeaderImpl(node: dictionary)
        
        let transforms: [[String]: Transform] = [
            ["update"]: .update("30"),
            ["delete"]: .delete,
            ["insert"]: .insert("40")
        ]
        
        let result = try header.transform(transforms: transforms)!
        #expect(try result.node?.get(key: "update") == 30)
        #expect(try result.node?.get(key: "delete") == nil)
        #expect(try result.node?.get(key: "insert") == 40)
        #expect(result.node?.count == 2)
    }
}
